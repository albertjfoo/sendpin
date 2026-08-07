# karoo2-send — wire protocol

The contract between the iPhone app and the Karoo extension. Pinned 2026-08-06.
Both sides must change together; nothing else in either codebase should hardcode
these values.

Implemented on the iOS side in [`ios/KarooSend/KarooSendPeripheral.swift`](ios/KarooSend/KarooSendPeripheral.swift)
(`enum KarooSendBLE`) and [`ios/KarooSend/Waypoint.swift`](ios/KarooSend/Waypoint.swift).

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
| HR test harness (milestone 1) | `180D` + local name `KarooSend` |

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

1. `RequestBluetooth("karoo2send")` — claim the radio from Hammerhead's
   `BluetoothCoordinator`. **Unverified on device (R2).**
2. Scan filtered on the waypoint service UUID. **Never cache a MAC address** —
   iOS rotates its resolvable private address roughly every 15 minutes (R6).
   Treat every send as a fresh discovery.
3. Connect on match, discover services, read the waypoint characteristic
   (blob-aware). Connect promptly rather than waiting for the scan to finish.
4. Decode JSON → `Symbol.POI(id:, lat:, lng:, name:)`.
5. `LaunchPinDrop(poi)` — requires karoo-ext ≥ 1.1.3, gated on host firmware.
   **Unverified (R1).**
6. `ReleaseBluetooth("karoo2send")` — don't hold the radio for a whole ride.

## URL intake (iPhone side)

The Shortcut that receives a Maps share opens:

```
karoosend://send?lat=51.50072&lng=-0.12462&name=Big%20Ben
```

Accepted variants: `karoosend:?…` with no host; `lon` or `long` as aliases for
`lng`; any case of scheme and parameter names. A URL missing `lat` or `lng`, or
carrying an out-of-range coordinate, is **rejected outright** and reported
on screen — a partial parse would silently navigate you to null island.
