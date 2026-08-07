# karoo2-send — risk register

Last updated 2026-08-06. Built on the NUC de-risk session and a review of the
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
| C4 | The Karoo cannot discover and connect to the iPhone | **Closed empirically 2026-08-06.** The KarooSend app advertised `180D` in the advertisement packet; the Karoo listed it under Add Sensor, connected, and bonded. The failure C3 diagnosed on paper is fixed in practice. |
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

### ~~R2. `RequestBluetooth` is unverified in practice~~ — the API is CONFIRMED present; runtime behaviour still untested

*Its existence on this firmware is no longer in doubt. What remains unknown is how
long the claim persists, whether it survives backgrounding, and whether it works
outside a ride — all cheap to answer once the extension exists.*
The API exists and its semantics match the coordinator's client model exactly, but we
have not seen an extension actually hold the radio with it. Unknowns: whether it works
on Karoo 2 firmware, how long the claim persists, whether it survives backgrounding,
and whether it works outside a ride.

**Action:** first Kotlin milestone — dispatch `RequestBluetooth("karoo2send")` and watch
for `BluetoothCoordinator: request ble karoo2send` via
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
