# sendpin — wire protocol

The contract between the iPhone app and the Karoo extension. Pinned 2026-08-06.
Both sides must change together; nothing else in either codebase should hardcode
these values.

Implemented on the iOS side in [`ios/SendPin/SendPinPeripheral.swift`](ios/SendPin/SendPinPeripheral.swift)
(`enum SendPinBLE`) and [`ios/SendPin/Waypoint.swift`](ios/SendPin/Waypoint.swift).

## UUIDs

| Role | UUID |
|---|---|
| Waypoint service | `4B027EEA-0001-45A6-AB37-310A7471C7DC` |
| Waypoint characteristic | `4B027EEA-0002-45A6-AB37-310A7471C7DC` |

Random 128-bit, deliberately **not** built on the Bluetooth SIG base
(`XXXXXXXX-0000-1000-8000-00805F9B34FB`). A UUID on the SIG base gets silently
shortened to its 16-bit form by both CoreBluetooth and Android's `ParcelUuid`,
which makes scan filters compare unequal things. The starter file carried a
hybrid `…-4000-8000-00805F9B34FB` UUID; it was replaced for this reason.

The heart rate service `180D` / characteristic `2A37` appear in the GATT
database **only** in test-harness mode. They are not part of the product.

## Advertisement

iOS `startAdvertising` accepts exactly two keys — local name and service UUIDs.
No manufacturer data, no service data. So the payload can never ride in the
advertisement (R4); the Karoo must connect and read.

| Mode | Advertised |
|---|---|
| Waypoint (product) | service UUID only, **no local name** |
| HR test harness (milestone 1) | `180D` + local name `SendPin` |

The advertisement is ~31 bytes and a 128-bit UUID consumes 16 of them. Adding a
local name alongside it pushes data into Apple's "overflow area", which only
Apple centrals can read — the Karoo would go blind (R5). Hence: UUID only.

## Payload

Compact UTF-8 JSON on the waypoint characteristic, keys sorted so the bytes are
stable and hex dumps stay comparable across runs:

```json
{"lat":51.50072,"lng":-0.12462,"name":"Big Ben"}
```

- `lat` / `lng` — `Double`, validated to ±90 / ±180 before it is ever served.
- `name` — non-empty, trimmed, truncated to 64 characters.

Typical size is ~48 bytes. **This exceeds the 20 usable bytes of a default-MTU
ATT read**, so the central fetches it as a series of blob reads with an
increasing offset. The peripheral honours `request.offset`; a central that
ignores it will reassemble garbage. Either negotiate a larger MTU or implement
the blob loop on the Kotlin side.

The bytes are pinned when advertising starts, so a payload swap mid-read cannot
tear. `send(_:)` re-pins them and pushes to subscribers via notify.

## Karoo extension flow

Not yet written. Constraints confirmed on the actual unit 2026-08-06:

- **`minSdk` ≤ 27** — the Karoo 2 runs Android 8.1.0. Not negotiable.
- **`RequestBluetooth` is mandatory, not optional.** The coordinator revokes any
  radio claim it doesn't recognise within ~4 seconds (see RISKS.md R2). An
  extension that skips it will find the adapter switched off underneath it.
- **Never bond, and never cache an address.** A hand-driven bond attempt wedged
  the Karoo's stack badly enough to need a Bluetooth process restart, because
  iOS rotated its address mid-pairing.
- **Connect immediately on scan match.** Minutes-old scan results point at
  addresses that no longer exist.

Target sequence:

1. `RequestBluetooth("sendpin")` — claim the radio from Hammerhead's
   `BluetoothCoordinator`. **Unverified on device (R2).**
2. Scan filtered on the waypoint service UUID. **Never cache a MAC address** —
   iOS rotates its resolvable private address roughly every 15 minutes (R6).
   Treat every send as a fresh discovery.
3. Connect on match, discover services, read the waypoint characteristic
   (blob-aware). Connect promptly rather than waiting for the scan to finish.
4. Decode JSON → `Symbol.POI(id:, lat:, lng:, name:)`.
5. `LaunchPinDrop(poi)` — requires karoo-ext ≥ 1.1.3, gated on host firmware.
   **Unverified (R1).**
6. `ReleaseBluetooth("sendpin")` — don't hold the radio for a whole ride.

## URL intake (iPhone side)

The Shortcut that receives a Maps share opens:

```
sendpin://send?lat=51.50072&lng=-0.12462&name=Big%20Ben
```

Accepted variants: `sendpin:?…` with no host; `lon` or `long` as aliases for
`lng`; any case of scheme and parameter names. A URL missing `lat` or `lng`, or
carrying an out-of-range coordinate, is **rejected outright** and reported
on screen — a partial parse would silently navigate you to null island.

### Apple Maps — works

A Shortcut named *Send To Karoo*, set to receive URLs from the share sheet,
regexes the coordinates straight out of the shared URL:

```
(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)     -> group 1 lat, group 2 lng
[?&](?:name|q)=([^&]+)                -> place name, then + replaced with %20
```

Deliberately matches any `number,number` pair rather than a named parameter, so
it survives Apple using `coordinate=`, `ll=` or `sll=`. Verified end to end
2026-08-06 with Apple's own share URL.

### Google Maps — tabled, and here is why

Google shares an opaque short link with no coordinates in it:

```
https://maps.app.goo.gl/6ifNBn5C44pAZmYF8
```

Investigated 2026-08-06; two routes ruled out empirically:

- **Following the redirect** yields `maps.google.com/maps?q=<address>&ftid=<id>`.
  No lat/lng — just an address string and Google's internal place id.
- **Scraping the page** is hopeless: 793 KB of JavaScript shell, `<title>` empty,
  all `og:` meta tags empty, and no coordinate pattern anywhere in the body.

The one surviving idea: if Google's share sheet also passes the place name and
address as *text*, feed that to Shortcuts' built-in geocoder (`Get Locations
from Input` → `Get Details of Location`) and skip Google entirely. Untested —
it needs someone to check what the share actually contains.

Costs to weigh if it is ever picked up: a geocoded address returns Apple's
coordinates for that address, which may not match Google's pin for a car park
entrance or an unnamed trailhead; and it needs phone signal at share time.

## Range limit

The Karoo's own resources carry the string:

```
rideapp_pin_out_of_range   "Pin must be within %s for nav."
```

so pin navigation is distance-limited. The Karoo handles routes up to roughly
**500 miles (800 km)**, which is the practical ceiling here too.

Not worth engineering around: a destination further away than that is not a
place you are about to cycle to. The payload is unaffected either way — the
coordinates transfer fine and the pin appears; only the Karoo's routing
declines. Noted so it is not rediscovered as a bug.
