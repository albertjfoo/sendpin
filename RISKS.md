# sendpin — risk register

Last updated 2026-08-25. Built on the NUC de-risk session and a review of the
karoo-ext source. Supersedes all earlier risk notes.

**2026-08-06 — the iOS-side mitigations are now implemented** (see
[PROTOCOL.md](PROTOCOL.md)). None of them are *verified*: the app has not run on
hardware yet, and R1/R2 are untouched.

| Risk | iOS-side mitigation, as built |
|---|---|
| R3 foreground-only | screen kept awake while the app is open; status and log rendered on screen |
| R4 payload can't ride in the advertisement | payload served over GATT; blob reads honour `request.offset` |
| R5 31-byte advertisement | waypoint mode advertises the service UUID alone, no local name |
| R6 address rotation | nothing to do on iOS — the *extension* must scan by service UUID and never cache a MAC |

---

## Headline change

Two official karoo-ext APIs were found late in the session that collapse the two
biggest risks. Both were verified by reading the SDK source directly:

```kotlin
// Claim the Bluetooth radio the sanctioned way
data class RequestBluetooth(val resourceId: String) : KarooEffect()
data class ReleaseBluetooth(val resourceId: String) : KarooEffect()

// Hand a lat/lng/name to Karoo's own navigation UI
data class LaunchPinDrop(val pin: Symbol.POI) : KarooEffect()   // @since 1.1.3

data class POI(
    val id: String, val lat: Double, val lng: Double,
    val type: String = Types.GENERIC, val name: String? = null, ...
)
```

`Symbol.POI` is literally `{lat, lng, name}` — the exact payload this project was
designed around. And `RequestBluetooth(resourceId)` maps one-to-one onto the
`BluetoothCoordinator: request ble <client>` lines observed in logcat.

**Consequence: the phantom-paired-sensor plan is abandoned.** There is no need to
masquerade the iPhone as a heart rate monitor in production. That plan existed only
to trick the radio into staying on, and it carried two nasty problems of its own
(address rotation, and a perpetually-absent sensor). Both now moot.

---

## CLOSED

| # | Risk | Evidence |
|---|---|---|
| C1 | Extension cannot trigger native turn-by-turn | **Closed twice over.** Empirically: sideloaded WaypointsKaroo v0.93 launched real native nav on the Karoo 2. Officially: `LaunchPinDrop` is a supported karoo-ext effect, so no undocumented intent is needed. |
| C2 | Karoo 2 cannot see BLE peripherals at all | Closed. nRF Connect on the Karoo listed many nearby devices — whenever the radio was on. |
| C3 | Unexplained discovery failure against the iPhone | Closed, root-caused. LightBlue advertises only a local name and never the `180D` service UUID; Karoo filters scans by service UUID. Confirmed by scanning the phone from a Linux box: `Name: Heart Rate` with no `UUIDs:` field, while another device in the same scan did report one. Not a Karoo defect. |
| C4 | The Karoo cannot discover and connect to the iPhone | **Closed empirically 2026-08-06.** The SendPin app advertised `180D` in the advertisement packet; the Karoo listed it under Add Sensor, connected, and bonded. The failure C3 diagnosed on paper is fixed in practice. |
| C5 | R1 + R2 — firmware too old for `LaunchPinDrop`; `RequestBluetooth` unverified | **Closed 2026-08-06 by inspecting the device itself.** See below. |

---

## R1 + R2 — CLOSED 2026-08-06, on the actual device

The Karoo 2 was connected to the Mac over adb and its firmware inspected directly,
which settled both risks without writing a line of Kotlin.

```
ro.hh.build.version   1.613.2351.12     (Ki2's documented floor: 1.527.2014)
Android               8.1.0, API 27     ← extension must build for minSdk ≤ 27
built                 2026-01-28        ← Karoo 2 still receiving firmware
system apps           4.197.1
```

Every Hammerhead system APK was pulled and its dex string pool searched. The
extension host is **`io.hammerhead.appstore`**, and it contains all three effects
the design depends on:

```
io.hammerhead.karooext.models.LaunchPinDrop
io.hammerhead.karooext.models.RequestBluetooth
io.hammerhead.karooext.models.ReleaseBluetooth

LaunchPinDrop(pin=          ← Kotlin data class toString templates, i.e. the
RequestBluetooth(resourceId=   compiled implementations are present, not just
ReleaseBluetooth(resourceId=   names carried in by a client library
```

`io.hammerhead.karooext.models.Symbol.POI` is present too. So the payload type,
the pin-drop effect and the Bluetooth claim all exist on **this** unit's firmware.

**Useful surface found alongside them**, worth designing around:

| Model | Why it matters here |
|---|---|
| `InRideAlert` | confirm a received destination on screen mid-ride |
| `PlayBeepPattern` | audible confirmation, so you needn't look down |
| `OnNavigationState.NavigatingToDestination` | observe whether nav actually started |
| `OnGlobalPOIs` | read existing POIs |
| `PerformHardwareAction.*` | synthesise button presses, e.g. to dismiss the pin dialog |

`PerformHardwareAction` is interesting against R9 — if `LaunchPinDrop` really is
confirm-then-navigate, a synthesised press might close the gap to true one-tap.
Unverified, and worth being careful with.

**Also learned:** WaypointsKaroo (`de.dimskiy.waypoints` v0.93, minSdk 23) declares
no extension service at all — only a launcher activity. So the native nav launch
proven on the NUC went through a raw intent, not karoo-ext. The intent path is
`io.hammerhead.intent.action.MAP_PIN` → `io.hammerhead.rideapp/.mapPin.MapPinActivity`,
which gives the project a **second, independent route** if the SDK one disappoints.

---

## OPEN — HIGH

### ~~R1. Host firmware may be too old for these APIs~~ — CLOSED, see above

*Original text retained for context.*
`LaunchPinDrop` requires karoo-ext **≥ 1.1.3**; `distancesAlongRoute` arrived in 1.1.6.
karoo-ext features are gated on the **host Karoo firmware**, not just the library you
compile against. The Karoo 2 is the older generation and no longer Hammerhead's focus,
so it may not carry a new enough system version.

*This is now the single most important thing to verify, and it is cheap.* If the
Karoo 2's firmware predates `LaunchPinDrop`, the whole approach reverts to the
undocumented-intent path that Waypoints/CupRoute use.

**Action:** check the Karoo's system version, and confirm the minimum firmware
karoo-ext 1.1.3+ requires. Ki2 documents a floor of `1.527.2014` for its own features —
a useful reference point.

### ~~R2. `RequestBluetooth` is unverified in practice~~ — API confirmed, and the mechanism it plugs into was observed directly

**2026-08-06, from the Karoo's own logs.** Third-party radio control is not merely
discouraged, it is actively revoked within seconds:

```
17:42:53  Enabled by no.nordicsemi.android.mcp          (nRF Connect)
17:42:57  BluetoothCoordinator: State(clients=[], bluetoothState=STATE_TURNING_OFF)
17:42:58  BluetoothCoordinator: State(clients=[], bluetoothState=STATE_OFF)
```

`adb shell svc bluetooth disable/enable` is ignored for the same reason. The
adapter history separates sanctioned from unsanctioned callers cleanly:

```
Enabled by io.hammerhead.sensorservice   <- persists
Enabled by no.nordicsemi.android.mcp     <- revoked in ~4s
```

**`clients=[]` is the list `RequestBluetooth(resourceId)` populates.** So the effect
is not optional garnish — without it an extension simply cannot keep the radio on.
Corollary for hand-testing: nRF Connect can only be used while some Hammerhead
client already holds the radio, e.g. during a ride or with the Add Sensor screen
open. That, not any defect in the peripheral, is what blocked the waypoint read.

*Its existence on this firmware is no longer in doubt. What remains unknown is how
long the claim persists, whether it survives backgrounding, and whether it works
outside a ride — all cheap to answer once the extension exists.*
The API exists and its semantics match the coordinator's client model exactly, but we
have not seen an extension actually hold the radio with it. Unknowns: whether it works
on Karoo 2 firmware, how long the claim persists, whether it survives backgrounding,
and whether it works outside a ride.

**Action:** first Kotlin milestone — dispatch `RequestBluetooth("sendpin")` and watch
for `BluetoothCoordinator: request ble sendpin` via
`adb logcat | grep -i "BluetoothCoordinator\|SensorPairing"`. Confirm the radio stays on.
Pair with `ReleaseBluetooth` so you are not holding the radio (and draining battery)
for an entire ride.

### R3. iOS advertises only in the foreground
Backgrounded or screen-locked, iOS moves service UUIDs into an "overflow area" readable
only by Apple devices — the Karoo goes blind. Accepted by design ("foreground only —
that's fine"), but it constrains the product: **the app must be open on screen at the
moment you send.**

Now that the phantom-sensor plan is dead, this is much less damaging than it was — you
only need a few seconds of foreground advertising per send, not a persistent connection
across a whole ride.

**Action:** confirm the end-to-end send completes fast enough to feel like one tap, with
the phone awake and the app foregrounded.

---

## OPEN — MEDIUM

### R4. Payload cannot ride in the advertisement
iOS `startAdvertising` supports only two keys — local name and service UUIDs. No
manufacturer data, no service data. The waypoint therefore **cannot** be broadcast
passively; the Karoo must connect and read a GATT characteristic. That adds a
connect → discover → read round trip.

**Mitigation:** likely fine (seconds), but design the extension to connect promptly on
match rather than waiting for a scan to complete.

### R5. Advertisement is 31 bytes, and a 128-bit UUID eats 16 of them
Advertising a custom 128-bit service UUID leaves roughly 8 characters for a local name
once flags are accounted for. Overflow gets pushed to the Apple-only overflow area,
i.e. invisible to the Karoo.

**Mitigation:** advertise the custom service UUID with a very short local name, or no
name at all. Do not advertise a second 128-bit UUID.

### R6. Address rotation makes reconnect-by-address unreliable
iOS uses a resolvable private address that rotates roughly every 15 minutes — directly
observed (`48:88:D3:CC:8B:4E` → `52:6F:94:E3:41:38` across two scans, ~2 minutes apart).

Severity has dropped from HIGH to MEDIUM now that the phantom-sensor plan is gone.

**Mitigation:** the extension must **scan by service UUID, never cache a MAC address.**
Treat every send as a fresh discovery.

### R7. Platform drift
The Karoo 2 is the previous generation under SRAM ownership. `BluetoothCoordinator`
behavior, the extensions framework, and karoo-ext support could all change or stop
receiving updates. Hammerhead ships this exact feature natively on Karoo 3 and
explicitly excludes Karoo 2, so there is no incentive for them to backport.

**Mitigation:** pin what works, keep the sideloaded APK, and be cautious about firmware
updates once you have a working build.

---

## OPEN — LOW

### R8. Distribution is manual
No app store for Karoo extensions; installation is `adb install` over USB. Fine for
personal use. Becomes a real constraint only if you decide to share this with others.

### R9. `LaunchPinDrop` is confirm-then-navigate, not instant
Its documented behavior is to "allow user the choice to navigate to this point or save
this point as a POI" — so it opens a pin activity rather than starting navigation
outright. One extra tap on the Karoo.

Arguably desirable mid-ride (you probably want to confirm before it reroutes you), but
it does mean "one-tap" is really "one tap on the phone, one confirm on the head unit."
Set expectations accordingly.

---

## Security and privacy

Numbered separately from R1–R9 because these are a different axis: none of them stop
the product working, and all of them are **accepted, not open**. They are written down
because the design makes deliberate tradeoffs that look like oversights if undocumented,
and the next person to read this code will ask about every one of them.

The threat model throughout: an attacker within Bluetooth range (roughly 10 m, line of
sight) of a cyclist, during the few seconds per send that the phone actually advertises.
Nothing here is reachable over the internet — there is no server, no account and no
network call in either half of the product.

### S1. The link is unencrypted and unbonded, on purpose
Nothing is paired, nothing is encrypted, and the waypoint characteristic is world-readable
while advertising. Any BLE central in range can read the destination.

This is a deliberate reversal of the obvious choice. Bonding was tried on 2026-08-06 and
wedged the Karoo's Bluetooth stack badly enough to need the process restarted, because
iOS rotated its address mid-pairing (see the `WaypointClient` header comment). The
encryption that bonding would buy protects a single lat/lng that the rider chose to send
and is about to be navigated to in public anyway.

**Accepted.** The exposure is one destination, to someone already standing next to you,
for a couple of seconds. Revisit only if the payload ever carries something that is not
a destination.

### S2. `DeviceID` is a stable identifier broadcast in the clear
`ios/Shared/DeviceID.swift` mints 8 random bytes, persists them in the App Group, and
`Waypoint.wireData` puts them in every payload. It is stable for the life of the install
and readable by anything that connects.

Tracking surface is genuinely small — it is only observable while advertising, which is
seconds per send, and it identifies an install rather than a person. It is not the
`identifierForVendor`, deliberately, so it is not correlatable with any other app.

**Accepted.** Two cheap improvements exist if this ever matters: shorten the advertising
window further, or rotate the ID whenever the Karoo is re-paired.

### S3. Pairing is trust-on-first-use, and spoofable
`SendPinExtension.acceptFromPairedPhone()` pairs with the first phone it hears and then
accepts only that ID. There is no authentication: the ID is a plaintext value in a
readable characteristic, so anyone who has observed one send can replay that ID and push
arbitrary destinations to that Karoo.

The feature was never a security control — it exists so two SendPin users at the same
café do not land pins on each other's head unit, which is a collision problem, not an
attack. It solves that completely.

The worst outcome of a successful spoof is an unwanted pin-drop dialog on the head unit,
which the rider must still confirm before anything reroutes (R9 turns out to be a
mitigation). No silent redirect is possible.

**Accepted.** Real authentication would need a shared secret established out of band —
a pairing code typed on the Karoo — which is a lot of friction to prevent a prank that
requires physical proximity and produces a dialog the victim can dismiss.

### S4. The web installer trusts HTTPS and same-origin, and nothing else
`docs/index.html` fetches `sendpin.apk` from its own origin and pushes it to the Karoo
over WebUSB, then runs `pm install -r`. There is no signature check or hash pinning in
the page.

The trust anchor is HTTPS to GitHub Pages plus same-origin: an attacker who could swap
the APK has already compromised the repository or the host, at which point the page
serving the check would be compromised too, so a hash in the page proves nothing. The
APK is signed with the release key, and Android enforces signature continuity on update
(see `karoo/app/build.gradle.kts`), so a substituted APK cannot masquerade as an update
to an existing install — it can only fail to install.

**Accepted.** Publishing a checksum in the README would let a careful user verify out of
band, and costs nothing. Worth doing if the project gets meaningful adoption.

### S5. The extension service is exported without a permission guard
`android:exported="true"` on `SendPinExtension` is required — the Karoo system
(`io.hammerhead.appstore`) binds it from another process. But there is no
`android:permission`, so any app on the head unit could bind it too.

The Karoo is a closed appliance with no app store of consequence and a sideload-only
install path, so "another malicious app is already on the device" is a scenario where
this service is far from the weakest link. The bindable surface is one bonus action that
triggers a BLE read.

**Accepted, low confidence that it matters either way.** If it is ever worth closing,
a custom signature-level permission is a few lines of manifest.

---

## Design consequences

1. **Drop the HR masquerade from the product.** It remains useful as a *test harness* —
   getting the iPhone into the Karoo's native Add Sensor list still proves discovery
   with zero Kotlin written — but it is not the shipping design.
2. **Production design:** iPhone advertises the custom waypoint service UUID (short name
   or none) → extension dispatches `RequestBluetooth`, scans by service UUID, connects,
   reads `{lat, lng, name}` → constructs `Symbol.POI` → dispatches `LaunchPinDrop` →
   releases Bluetooth.
3. **Verify R1 before writing significant Kotlin.** Everything above assumes the Karoo 2's
   firmware is new enough to expose these effects.
