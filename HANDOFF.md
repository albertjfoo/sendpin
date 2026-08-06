# karoo2-send — handoff to the MacBook

Self-contained context for continuing on the Mac. Written 2026-08-05 after the
NUC de-risk session.

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

## Milestone 1 on the Mac — no Kotlin required

Get the iPhone to appear in the Karoo's **native Add Sensor list** as a heart rate
sensor. That single observable proves BLE discovery end-to-end using Hammerhead's own
UI as the test harness — no extension, no coordinator fight, no sideloading.

`ios/KarooSendPeripheral.swift` in this folder is a complete, commented starter that
does exactly this. Drop it into a new Xcode iOS App project and call `start()`.

⚠️ **The heart-rate service in that file is a test harness, not the product.** It
exists so you can use Karoo's own sensor UI as a detector. Once `RequestBluetooth` is
verified, the shipping app advertises only the custom waypoint service.

## Mac setup gotchas

1. **CoreBluetooth does not work in the iOS Simulator.** You must run on a physical
   iPhone. The Simulator reports `.unsupported` and nothing else happens.
2. **`Info.plist` needs `NSBluetoothAlwaysUsageDescription`** (any string). Without it
   iOS 13+ refuses Bluetooth and the peripheral silently fails as `.unauthorized`.
3. **A free Apple ID is enough** to run on your own device — but the build expires
   after **7 days** and must be re-signed. The paid Developer Program ($99/yr) gives
   a year. Free is fine to start; the expiry gets annoying during iteration.
4. **Xcode** from the Mac App Store, ~10GB+. Sign in under Settings → Accounts, then
   set the project's Signing team to your personal team.
5. **adb on the Mac** (optional): `brew install android-platform-tools`, if you want
   Karoo logs from the same machine instead of hopping back to the NUC. Milestone 1
   doesn't need it — you just look at the Karoo's screen.

## Continuing with Claude Code on the Mac

Claude Code runs on macOS (CLI, desktop app, and IDE extensions). This conversation
and the agent's memory files **do not transfer** — memory is machine-local and keyed
to a directory path. This file is the replacement: point the new session at it.

The two memory files it was built from live on the NUC at:
`~/.claude/projects/-home-albert-foo-iphone-photos/memory/`

## Moving this folder to the Mac

Only `HANDOFF.md` and `ios/` matter — `vendor-apks/` is Karoo-only and can stay.
Any of: AirDrop, a USB stick, a cloud folder, or `git init` here plus a private
GitHub repo (note: `gh` was not installed on the NUC as of this session).
