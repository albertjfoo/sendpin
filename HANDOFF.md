# karoo2-send — handoff to the MacBook

Self-contained context for continuing on the Mac. Written 2026-08-05 after the
NUC de-risk session; updated 2026-08-06 on the Mac.

> **Current state (2026-08-06):** the iOS app now exists and builds clean — see
> [Where the code is](#where-the-code-is) and [Status](#status). It has **never
> been run on a device**, because Xcode has to be updated first. Milestone 1 is
> written but unproven.

## The project

One-tap iPhone → Karoo 2 destination sending. Share a restaurant from Maps on the
phone, get turn-by-turn on the Karoo — the thing Karoo 3 and modern Wahoos do
natively and the Karoo 2 doesn't.

- **iOS app** (Swift/CoreBluetooth): receives a Maps share via a Shortcut + custom
  URL scheme, resolves it to `{lat, lng, name}`, advertises as a BLE peripheral.
  Foreground-only is acceptable.
- **Karoo extension** (Kotlin, karoo-ext): BLE central, reads the payload, launches
  native Karoo navigation via the same intent Waypoints/CupRoute use.
- No internet on the Karoo, no cloud relay. Rejected: hotspot (friction), SIM (cost).

## What the NUC session established

**✅ Proven — native nav launch works.** Sideloaded `dimskiy/WaypointsKaroo` v0.93
(note: **not** timklge, the original brief had this wrong) and its POI search
launched real native turn-by-turn. This was the risk that could have killed the
project. Read that repo's source, and `nairdam88/cuproute`, for the nav intent.

**✅ Root-caused — why the Karoo never saw the iPhone.** LightBlue advertises only a
local name, never the `180D` service UUID. Karoo filters scans by service UUID, so
there was nothing to match. Verified by scanning the phone from the NUC:

```
Device 48:88:D3:CC:8B:4E  Name: Heart Rate  RSSI: -55  ManufacturerData: 0x004c (Apple)
```

No `UUIDs:` field — while a different device in the same scan did report one.

The distinction that matters: the **GATT database** (services/characteristics) is
only visible *after* connecting. The **advertisement packet** is a separate ~31-byte
broadcast, and scan filters match against *that*.

**⚠️ Constraint — Hammerhead gatekeeps the BLE radio.** A custom `BluetoothCoordinator`
in `io.hammerhead.sensorservice` tracks named clients (e.g. `ble_scanner`). Any
third-party app calling `BluetoothAdapter.enable()` gets overridden ~300ms later.
Watch it with:

```
adb logcat | grep -i "BluetoothCoordinator\|SensorPairing"
```

**✅ …but karoo-ext has the sanctioned way in.** Found by reading the SDK source:

```kotlin
data class RequestBluetooth(val resourceId: String) : KarooEffect()
data class ReleaseBluetooth(val resourceId: String) : KarooEffect()
data class LaunchPinDrop(val pin: Symbol.POI) : KarooEffect()   // @since 1.1.3

data class POI(val id: String, val lat: Double, val lng: Double,
               val type: String = Types.GENERIC, val name: String? = null, ...)
```

`RequestBluetooth(resourceId)` maps one-to-one onto the `BluetoothCoordinator:
request ble <client>` lines in the logs, and `Symbol.POI` is exactly the
`{lat, lng, name}` payload this project was designed around. **Neither is verified
on-device yet** — that is now the top open risk.

**Consequence: the phantom-paired-sensor plan is dead** (and with it the iOS
address-rotation problem that threatened it). The iPhone does not need to masquerade
as a heart rate monitor in production.

**See [RISKS.md](RISKS.md) for the full, current risk register.**

## Why BLE (settled — don't re-litigate)

BLE is not being repurposed here; small structured payloads over a custom GATT
characteristic is its core use, and the Bluetooth SIG reserves 128-bit UUIDs for exactly
this. Supporting evidence:

- **Hammerhead ships this same feature on Karoo 3 over the same radio** — their docs say
  the app and Karoo "transfer data over the Bluetooth channel," no internet needed on the
  head unit.
- **karoo-ext treats third-party BLE as a first-class extension category** — the official
  sample scans BLE for HR sensors; `valterc/ki2` holds live groupset connections.
- **`RequestBluetooth` exists in the SDK**, which only makes sense if extensions using
  Bluetooth is an expected case.

Every obstacle encountered is a *policy* constraint with a documented path around it, not
a protocol limitation: Hammerhead's `BluetoothCoordinator`, Apple's background-advertising
rules, and firmware version gating.

Alternatives, closed off: WiFi hotspot (rejected on friction, and still needs a receiver
on the Karoo); ANT+ (Karoo has it, iPhone can't speak it without a dongle); QR code (no
camera on Karoo 2); anything cloud-based (reintroduces the internet dependency that is the
entire point of avoiding).

**Untested lead:** the Hammerhead Companion app already pairs to the Karoo 2 over Bluetooth
for uploads and notifications. If you ride with it connected, Hammerhead's own client may
hold the radio on already — which would demote `RequestBluetooth` from hard dependency to
belt-and-braces. Was step 4 of the original de-risk plan; never tested.

## Target design

iPhone advertises the custom waypoint service UUID (short local name, or none — a
128-bit UUID eats 16 of the advertisement's 31 bytes) → extension dispatches
`RequestBluetooth`, scans **by service UUID, never by cached MAC address** (iOS
rotates its address ~every 15 min) → connects, reads `{lat, lng, name}` over GATT
(iOS cannot put payload in the advertisement) → builds `Symbol.POI` → dispatches
`LaunchPinDrop` → `ReleaseBluetooth`.

The UUIDs, payload format and URL scheme are now pinned in **[PROTOCOL.md](PROTOCOL.md)**
and implemented on the iOS side. Write the Kotlin against that document.

## Where the code is

The working copy moved off the USB stick on 2026-08-06:

```
~/Developer/karoo2-send        ← build here (APFS, git repo)
/Volumes/USB Drive/karoo2-send ← archive + vendor-apks/ only
```

**Do not build on the USB drive.** It is exFAT: no POSIX permissions, no extended
attributes. Code signing and DerivedData both misbehave there. `vendor-apks/` stays
on the stick; it is Karoo-only.

```
ios/KarooSend.xcodeproj        hand-written, file-system-synchronized groups
ios/KarooSend-Info.plist       outside the sync group on purpose — inside, it would
                               be swept into Copy Bundle Resources and collide
ios/KarooSend/
  KarooSendApp.swift           @main, karoosend:// intake, keeps the screen awake
  ContentView.swift            status, mode picker, manual entry, on-screen log
  KarooSendPeripheral.swift    the BLE peripheral
  Waypoint.swift               the payload + URL parsing
PROTOCOL.md                    the iPhone ↔ Karoo wire contract
```

Build from the command line without touching `xcode-select`:

```
cd ~/Developer/karoo2-send/ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme KarooSend -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

That only proves it compiles. The Simulator cannot advertise, so it can never prove
anything about BLE.

## Status — end to end on hardware, 2026-08-06

**The core works.** A destination set on the iPhone appears on the Karoo's native
pin-drop screen by itself, with nothing touched on the head unit.

```
18:35:43.822  scan hit rssi=-22
18:35:43.834  matched peripheral, connecting immediately
18:35:45.496  mtu=185, discovering services
18:35:45.554  parsed Waypoint(lat=51.0, lng=-0.12, name=...)
              -> LaunchPinDrop -> native pin drop UI on the Karoo
```

| | |
|---|---|
| iOS app builds, installs, advertises | ✅ |
| Karoo discovers + connects to the iPhone | ✅ |
| Waypoint JSON transferred over GATT | ✅ ~1.9s, MTU 185, single read |
| `RequestBluetooth` holds the radio | ✅ `request ble karoo2send` in the coordinator log |
| `LaunchPinDrop` opens native navigation | ✅ confirmed on screen |
| Duplicate suppression | ✅ re-reads are ignored for 2 min |
| Apple Maps → Shortcut → `karoosend://` | ✅ verified with Apple's own share URL |
| Real turn-by-turn navigation | ✅ outdoors, once the Karoo has a GPS fix |
| Extension screen + off switch on the Karoo | ✅ in the app list |
| Google Maps sharing | ⏸️ tabled — see PROTOCOL.md |

**The project works.** Share a place from Apple Maps and the Karoo opens its
native pin drop, then navigates. Roughly two seconds from tapping share.

Known limits, none of them unknowns:

- The phone app must be **open and on screen** when sending (R3, unfixable).
- `LaunchPinDrop` is confirm-then-navigate, so it is one tap on the phone and
  one confirm on the head unit (R9).
- Navigation needs a **GPS fix** and the relevant **offline map region**. Indoors
  the pin arrives and the Karoo says GPS is required — that is not a fault.
- Battery is unmeasured. Scanning is `SCAN_MODE_LOW_POWER` (~10% duty) and the
  extension holds the radio on via `RequestBluetooth`, overriding the
  coordinator's habit of powering Bluetooth down. Measure with:
  `adb shell dumpsys batterystats --charged com.albert.karoosend`

## ⛔ Blocker: Xcode is too old for the phone

`/Applications/Xcode.app` is **16.4**, which ships the **iOS 18.5** SDK. The iPhone
(`iPhone18,1`) runs **iOS 26.4.2**. Xcode 16.4 cannot install or debug on an iOS 26
device — nothing can be tested on hardware until Xcode 26.x is installed from the
Mac App Store (~10GB+, slow).

Everything else is ready and waiting for that.

Also note: `xcode-select` still points at `/Library/Developer/CommandLineTools`, so
`xcodebuild` and `devicectl` are not on `PATH`. Either use the explicit paths above,
or fix it once with:

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Milestone 1 — no Kotlin required

Get the iPhone to appear in the Karoo's **native Add Sensor list** as a heart rate
sensor. That single observable proves BLE discovery end-to-end using Hammerhead's own
UI as the test harness — no extension, no coordinator fight, no sideloading.

The app ships this as the **HR test harness** mode (the default). Run it, tap Start,
then on the Karoo: Settings → Sensors → Add Sensor → Heart Rate. Look for `KarooSend`.

Watch the **on-screen log**, not the Xcode console — you will be standing over the
bike with the phone in your hand. `SUBSCRIBED to 2A37` is the win condition.

⚠️ **The heart-rate service is a test harness, not the product.** It exists so Karoo's
own sensor UI can act as a detector, and it is only added to the GATT database in that
mode. The shipping app advertises the custom waypoint service alone.

## Other Mac setup notes

1. **CoreBluetooth does not work in the iOS Simulator.** You must run on a physical
   iPhone. The Simulator reports `.unsupported` and nothing else happens.
2. **`Info.plist` needs `NSBluetoothAlwaysUsageDescription`** — already set. Without it
   iOS 13+ refuses Bluetooth and the peripheral silently fails as `.unauthorized`.
3. **A free Apple ID is enough** to run on your own device — but the build expires
   after **7 days** and must be re-signed. The paid Developer Program ($99/yr) gives
   a year. Free is fine to start; the expiry gets annoying during iteration.
   Set the Signing team in Xcode: sign in under Settings → Accounts, then pick your
   personal team on the KarooSend target. `PRODUCT_BUNDLE_IDENTIFIER` is
   `com.albert.karoosend` — change it if it collides.
4. **adb on the Mac** (optional): `brew install android-platform-tools`, if you want
   Karoo logs from the same machine instead of hopping back to the NUC. Milestone 1
   doesn't need it — you just look at the Karoo's screen.

## Building both halves

```
# iOS  (Xcode 26.6, iOS 26.5 SDK, team JJ9P8ZLMH3 already in the project)
cd ~/Developer/karoo2-send/ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme KarooSend -destination 'id=00008150-001674E10C69401C' \
  -allowProvisioningUpdates -derivedDataPath ./build
xcrun devicectl device install app --device 00008150-001674E10C69401C \
  build/Build/Products/Debug-iphoneos/KarooSend.app

# Karoo
cd ~/Developer/karoo2-send/karoo
JAVA_HOME=/opt/homebrew/opt/openjdk@17 \
ANDROID_HOME=/opt/homebrew/share/android-commandlinetools \
./gradlew :app:assembleDebug --no-daemon
adb install -r app/build/outputs/apk/debug/app-debug.apk
# REQUIRED after every install — API 27 returns no scan results without it,
# and the app has no UI to request it:
adb shell pm grant com.albert.karoosend android.permission.ACCESS_FINE_LOCATION
```

`karoo-ext` comes from **JitPack**, not GitHub Packages — the latter demands a
token even for public packages (401 vs 200, checked 2026-08-06).

## Debugging

```
adb logcat -s KarooSend:V                                    # the extension's own log
adb logcat -d | grep -iE "BluetoothCoordinator|request ble"  # radio claims
adb shell dumpsys activity services com.albert.karoosend     # is it bound?
```

The iPhone app keeps its own on-screen log — use that rather than the Xcode
console, since testing means standing over the bike with the phone in hand.

## Ideas not pursued

- **Ride-only scanning.** Watch `RideState` and claim the radio only while
  recording. Bigger battery win than the scan mode, at the cost of not being
  able to send a destination before setting off.
- **`PerformHardwareAction`** to synthesise the confirm press and close R9's
  gap to true one-tap. Present in the firmware; be careful with it.
- **`InRideAlert`** is wired up for failures but has never actually fired.

## Continuing with Claude Code

This conversation and the agent's memory files **do not transfer between machines** —
memory is machine-local and keyed to a directory path. These documents are the
replacement: point a new session at `~/Developer/karoo2-send`.

The two memory files this was originally built from live on the NUC at:
`~/.claude/projects/-home-albert-foo-iphone-photos/memory/`

## Keeping the USB copy in sync

The stick is now an archive, not the working copy. To refresh the docs on it:

```
rsync -a --delete --exclude vendor-apks --exclude .git \
  ~/Developer/karoo2-send/ "/Volumes/USB Drive/karoo2-send/"
```

For a real backup, prefer `git init` plus a private GitHub repo over the stick
(note: `gh` was not installed on the NUC as of the 2026-08-05 session).
