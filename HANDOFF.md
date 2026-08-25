# sendpin — handoff to the MacBook

Self-contained context for continuing on the Mac. Written 2026-08-05 after the
NUC de-risk session; updated 2026-08-06 on the Mac.

> **Current state (2026-08-25):** ready to submit to the App Store, blocked on
> one switch. See [Submitting](#submitting--where-this-stopped-2026-08-25).
>
> Working end to end on hardware since 2026-08-06 — share a place from Apple
> Maps and the Karoo 2 opens its native pin drop and navigates. See
> [Status](#status--end-to-end-on-hardware-2026-08-06).
>
> This file is the developer's notebook: history, dead ends, and the reasoning
> behind decisions. For what the project *is*, read the README.

## Submitting — where this stopped, 2026-08-25

Everything code-side is done, committed and pushed. `main` is in sync with
GitHub. **The whole remaining path is gated on making the repo public**, which
is deliberately left as a human action.

Why that one switch gates so much: GitHub Pages needs a public repo on the free
plan, and Pages is simultaneously the App Store **support URL**, the target of
the app's own in-app links (`ios/SendPin/Setup.swift`), the host of the WebUSB
installer, and the host of `manifest.json` for Karoo auto-update. Nothing
downstream works until it resolves.

A full history scan for secrets was run on 2026-08-25 and came back clean: no
sensitive filenames in any commit or tag, no literal passwords (every hit was
the code *reading* `keystoreProps`), no keystore blobs by magic bytes, and no
personal paths. The only identifier present is the Apple team ID, which is
public in every signed binary. **Nothing blocks publishing.**

```
1. gh repo edit albertjfoo/sendpin --visibility public \
     --accept-visibility-change-consequences
2. Settings → Pages → source main, folder /docs
3. Confirm both load:
     https://albertjfoo.github.io/sendpin/
     https://albertjfoo.github.io/sendpin/manifest.json
4. Archive from main (NOT an older build — the in-app link fix and the
   tagline change are recent commits), upload, wait for processing
5. Screenshots on device, 6.9" and 6.5" — see APPSTORE.md for which four
   and in what order. Send a few real places first so the list is not empty.
6. App Store Connect record, reserve "SendPin", paste copy from APPSTORE.md
7. Support URL → the Pages URL. Privacy → Data Not Collected.
   Review notes → paste from APPSTORE.md; they are the 4.2 defence.
8. Submit.
```

### Open, not blocking

- **A fresh Karoo install does not bind until the head unit reboots.**
  Observed 2026-08-25: `dumpsys activity services app.sendpin` was empty after
  installing, and the service only appeared after a restart. The site's install
  flow never says to reboot, so a first-timer can sit on a green dot with
  nothing running. Confirm on a clean run, then add it to Step 4 on the site.
- **The status line still lies in one case.** `Prefs.status()` returning null
  means "watcher has gone quiet", and `MainActivity` reads that optimistically
  as green *Listening* — so a watcher that never started shows as healthy. That
  is the same failure the amber work removed, relocated. Fix: treat null while
  enabled and located as *Starting…*, since a live watcher writes within ~2s.
- **Karoo auto-update is untested.** It cannot be tested until Pages is live.
  Once it is: install, bump to `versionCode = 3`, push, then long-press →
  Update on the head unit. That also answers whether the head unit polls on its
  own or only checks when asked — currently unknown.
- **Clean-device first-run test.** Every test so far has run on a phone with
  history and a Karoo with a prior pairing. Best done just before submitting,
  on the build being submitted.
- **awesome-karoo listing** — deliberately held until after dogfooding.
- **Launch day:** the site's QR code is decorative and resolves to nothing, and
  the page says "Coming to the App Store". Both need replacing with a real
  link. So does step 1 of *Get the iPhone app*, which already says "Download
  SendPin from the App Store".

## The project

One-tap iPhone → Karoo 2 destination sending. Share a restaurant from Maps on the
phone, get turn-by-turn on the Karoo — the thing Karoo 3 and modern Wahoos do
natively and the Karoo 2 doesn't.

- **iOS app** (Swift/CoreBluetooth): receives a Maps share via the share extension,
  resolves it to `{lat, lng, name}`, advertises as a BLE peripheral.
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

The UUIDs and payload format are pinned in **[PROTOCOL.md](PROTOCOL.md)** and
implemented on the iOS side. Write the Kotlin against that document.

## Where the code is

The working copy moved off the USB stick on 2026-08-06:

```
~/Developer/sendpin        ← build here (APFS, git repo)
/Volumes/USB Drive/sendpin ← archive + vendor-apks/ only
```

**Do not build on the USB drive.** It is exFAT: no POSIX permissions, no extended
attributes. Code signing and DerivedData both misbehave there. `vendor-apks/` stays
on the stick; it is Karoo-only.

```
ios/SendPin.xcodeproj        hand-written, file-system-synchronized groups
ios/SendPin-Info.plist       outside the sync group on purpose — inside, it would
                               be swept into Copy Bundle Resources and collide
ios/SendPin/
  SendPinApp.swift           @main, keeps the screen awake
  ContentView.swift            send status, destination, details sheet
  Setup.swift                  first-run onboarding and outbound links
ios/SendPinShare/
  ShareViewController.swift  the share sheet entry — where sends actually start
  Destination.swift            parses Apple Maps share links
ios/Shared/                  compiled into both targets
  SendPinPeripheral.swift      the BLE peripheral
  Waypoint.swift               the payload
ios/Tests/run.sh             URL-parsing checks — see Tests below
PROTOCOL.md                    the iPhone ↔ Karoo wire contract
```

Build from the command line without touching `xcode-select`:

```
cd ~/Developer/sendpin/ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme SendPin -sdk iphonesimulator \
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
| `RequestBluetooth` holds the radio | ✅ `request ble sendpin` in the coordinator log |
| `LaunchPinDrop` opens native navigation | ✅ confirmed on screen |
| Duplicate suppression | ✅ re-reads are ignored for 2 min |
| Apple Maps → share extension → send | ✅ verified with Apple's own share URL |
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
  `adb shell dumpsys batterystats --charged app.sendpin`

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
then on the Karoo: Settings → Sensors → Add Sensor → Heart Rate. Look for `SendPin`.

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
   personal team on the SendPin target. `PRODUCT_BUNDLE_IDENTIFIER` is
   `app.sendpin` — change it if it collides.
4. **adb on the Mac** (optional): `brew install android-platform-tools`, if you want
   Karoo logs from the same machine instead of hopping back to the NUC. Milestone 1
   doesn't need it — you just look at the Karoo's screen.

## Building both halves

```
# iOS  (Xcode 26.6, iOS 26.5 SDK, team JJ9P8ZLMH3 already in the project)
cd ~/Developer/sendpin/ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme SendPin -destination 'id=<your-iphone-udid>' \
  -allowProvisioningUpdates -derivedDataPath ./build
xcrun devicectl device install app --device <your-iphone-udid> \
  build/Build/Products/Debug-iphoneos/SendPin.app

# Karoo
cd ~/Developer/sendpin/karoo
JAVA_HOME=/opt/homebrew/opt/openjdk@17 \
ANDROID_HOME=/opt/homebrew/share/android-commandlinetools \
./gradlew :app:assembleDebug --no-daemon
adb install -r app/build/outputs/apk/debug/app-debug.apk
# REQUIRED after every install — API 27 returns no scan results without it,
# and the app has no UI to request it:
adb shell pm grant app.sendpin android.permission.ACCESS_FINE_LOCATION
```

`karoo-ext` comes from **JitPack**, not GitHub Packages — the latter demands a
token even for public packages (401 vs 200, checked 2026-08-06).

## Tests

```
ios/Tests/run.sh
```

Twelve checks on Apple Maps share-link parsing — `swiftc` compiles three files
and runs them, about two seconds. No simulator, no Xcode project, no test
target, deliberately: this needs none of that, and adding a target would mean
project surgery for a job a shell script does.

They cover exactly one thing, and it is the right thing. Parsing fails
*quietly* — a wrong coordinate still looks like a successful send, right up
until the Karoo routes you somewhere else. Everything else in this project
fails loudly.

**A pre-commit hook runs these automatically** whenever a commit touches
`Destination.swift`, `Waypoint.swift` or `Tests/main.swift`, and blocks the
commit if any fail. Commits that touch nothing else skip it entirely, so
committing docs stays instant. `git commit --no-verify` bypasses it when you
mean to.

⚠️ **The hook is not version-controlled.** It lives in `.git/hooks/pre-commit`,
which is outside the repo, so it does **not** survive a fresh clone and will not
appear on another machine. If the checks ever stop running, that is why —
recreate it, or run `run.sh` by hand. It was written 2026-08-25; if this project
ever gains a second contributor, replace it with CI, because a local hook cannot
enforce anything on a machine you do not control.

## Debugging

```
adb logcat -s SendPin:V                                    # the extension's own log
adb logcat -d | grep -iE "BluetoothCoordinator|request ble"  # radio claims
adb shell dumpsys activity services app.sendpin     # is it bound?
```

The iPhone app keeps its own on-screen log — use that rather than the Xcode
console, since testing means standing over the bike with the phone in hand.

## Parked, waiting on the repo going public

The repo stays private until the iOS app ships. Publishing sooner would offer
someone the Karoo half of a system whose other half they cannot get.

Three things unblock the moment it is public, and none get harder for waiting:

- **Auto-update.** karoo-ext defines `io.hammerhead.karooext.MANIFEST_URL`, and
  karoo-ext's own release ships a `manifest.json` carrying `latestVersionCode`
  and `latestApkUrl`. Declare that meta-data, host the manifest, and long-press
  → Update works on the device — awesome-karoo confirms that works on Karoo 2.
  Needs a public fetch, so a private repo 404s. This is the biggest remaining
  friction win: it makes the painful install a one-time cost.
- **App Store support URL.** Required to submit, not to draft.
- **A listing in [awesome-karoo](https://github.com/timklge/awesome-karoo)** —
  a README pull request, and where Karoo owners actually look.
- **Hosting the WebUSB installer.** `docs/index.html` installs the extension
  from a browser over WebUSB, using push + `pm install` rather than the
  streaming session API that fails on Android 8.1. GitHub Pages would serve it
  at `albertjfoo.github.io/sendpin/`, and the HTTPS it provides is required —
  WebUSB refuses to run outside a secure context.

  One decision outstanding: **where the APK comes from.** `docs/sendpin.apk` is
  currently gitignored, so Pages would 404 on it. Either commit the binary into
  `docs/` — certain to work, same-origin, but roughly 2.8 MB of repo per release
  forever — or fetch it from the GitHub release, which is cleaner but depends on
  release assets sending permissive CORS headers. Untested, because a private
  repo's assets are not publicly fetchable. Try the fetch first; committing is
  the fallback and is a one-line change either way.

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
replacement: point a new session at `~/Developer/sendpin`.

The two memory files this was originally built from live on the NUC at:
`~/.claude/projects/-home-albert-foo-iphone-photos/memory/`

## Keeping the USB copy in sync

The stick is now an archive, not the working copy. To refresh the docs on it:

```
rsync -a --delete --exclude vendor-apks --exclude .git \
  ~/Developer/sendpin/ "/Volumes/USB Drive/sendpin/"
```

For a real backup, prefer `git init` plus a private GitHub repo over the stick
(note: `gh` was not installed on the NUC as of the 2026-08-05 session).
