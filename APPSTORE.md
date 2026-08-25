# App Store listing

Copy for App Store Connect. Character limits are Apple's and are enforced.

---

## Name (30 max)

```
SendPin
```

⚠️ Must be unique across the whole App Store. Check availability when creating
the app record — if taken, `SendPin for Karoo` (18) is the fallback, though it
puts a trademark in the name, which is the thing we avoided in the product name.

## Subtitle (30 max)

```
Destinations to your Karoo 2
```
28 characters.

## Promotional text (170 max, editable without a new build)

```
Look up a cafe on your phone, send it to your Karoo 2, and let the bike computer do the navigating. No internet needed on the Karoo.
```
131 characters.

## Keywords (100 max, comma separated, no spaces after commas)

```
karoo,hammerhead,cycling,bike,computer,navigation,route,destination,bluetooth,waypoint,gps,ride
```
95 characters. Do not repeat words already in the name or subtitle — Apple
indexes those anyway, and duplicates waste the budget.

## Description (4000 max)

```
SendPin sends a destination from your iPhone to a Hammerhead Karoo 2 over
Bluetooth, so your bike computer can navigate you there.

Find a place in Apple Maps, share it to SendPin, and it appears on the Karoo's
own Map Pin screen ready to navigate. It takes about two seconds. Nothing is
uploaded anywhere — the destination goes straight from your phone to the bike
computer over Bluetooth Low Energy, the same radio your power meter uses.

WHAT YOU NEED

• A Hammerhead Karoo 2
• The free SendPin extension installed on it

The Karoo extension is a separate free download, and installing it requires a
computer once. Full instructions are linked from inside the app.

The newer Karoo 3 already does this through Hammerhead's own companion app.
SendPin exists for the Karoo 2, which never got the feature.

HOW IT WORKS

1. Find a place in Apple Maps
2. Share it to SendPin
3. Keep the app on screen for a moment while it sends
4. The Karoo shows the pin, ready to navigate

WORTH KNOWING

• Keep SendPin on screen while sending. iPhones stop broadcasting to non-Apple
  devices as soon as an app goes to the background.
• Your Karoo needs a GPS fix and the offline map region for the area, the same
  as any navigation on the device.
• Google Maps is not supported. Its share links do not contain coordinates.

PRIVACY

No account, no analytics, no network requests. SendPin has no servers. The only
thing it ever transmits is a latitude, longitude, place name, and a random ID
for your phone, over Bluetooth, to a device within a few metres of you. The ID
is generated on your device, is not linked to you, and exists so your Karoo can
tell your phone from someone else's.

Not affiliated with or endorsed by Hammerhead or SRAM.
```

## Category

Primary: **Navigation**. Secondary: **Sports**.

Navigation over Sports because the function is sending a destination; someone
browsing Sports is looking for training apps.

## Age rating

4+. No objectionable content, no user-generated content, no web views.

## Privacy — App Privacy section

**Data Not Collected.** True without qualification: no analytics SDK, no
crash reporter, no network calls of any kind. The privacy manifest declares
`NSPrivacyTracking: false`, an empty collected-data list, and one
required-reason API (`UserDefaults`, CA92.1, for the "seen the welcome screen"
flag).

## Support URL

⚠️ Required to submit, and Apple checks that it resolves. Currently blocked:
the repo is private, so `github.com/albertjfoo/sendpin` returns 404 to anyone
who is not signed in as the owner. Decide before submitting — see
[HANDOFF.md](HANDOFF.md).

---

## Review notes

This matters more than usual here. A reviewer without a Karoo sees a status
screen and two links, which is exactly the shape of a 4.2 minimum-functionality
rejection. Say plainly what the app is and what they can verify without the
hardware.

```
SendPin is a companion app for the Hammerhead Karoo 2, a cycling GPS computer.

It sends a destination from the iPhone to that device over Bluetooth Low
Energy. The iPhone acts as a BLE peripheral: it advertises a custom service and
holds the destination in a GATT characteristic. A free open-source extension on
the Karoo reads it and hands the coordinates to the Karoo's built-in
navigation.

WITHOUT A KAROO, YOU CAN VERIFY:

• Setup and How to use screens explain the full flow
• Sharing a place from Apple Maps opens the app with the destination shown
• The app begins advertising over Bluetooth, shown on the main screen
• Connection details shows the live Bluetooth log, including the advertisement
  starting and the payload being served
• After about 25 seconds with nothing reading it, the app reports that nothing
  picked up the destination — the expected result with no Karoo present

The receiving half cannot be simulated without the hardware. If it would help,
we can provide a video of the end-to-end flow with the bike computer.

The app has no accounts, no servers and makes no network requests. The Karoo
extension is a free download and is not sold or promoted through the app.
```

## Screenshots

Required: 6.9" and 6.5". Take them on the phone — the Simulator cannot run
CoreBluetooth, so the sending states cannot be staged there.

Capture in this order. The order is the argument: this app is a share
extension with a list attached, so lead with the thing it does, not the thing
it looks like.

1. **The share card, mid-send** — SendPin's sheet over Apple Maps, showing the
   place name and "Sending". This is the whole product in one image, and it is
   the only screenshot that shows the app doing work inside another app.
2. **The share card, sent** — same sheet reading "Sent". Proves the round trip
   completed, which is exactly what a reviewer without a Karoo will doubt.
3. **Home with history** — several real places, one pinned. Shows the app has
   persistent state and a reason to open it.
4. **Welcome screen** — what the app is, for anyone reading the listing rather
   than the app.

One and two matter most. A reviewer's 4.2 concern is "this is a thin wrapper
with nothing in it", and a card actively sending a destination from inside Maps
is the most direct answer to that.

**Set the phone up first**, or the shots will be thin: send four or five real
places beforehand so the list looks lived-in, pin one, and pick somewhere with
a recognisable name. Do not screenshot an empty state.

⚠️ Do **not** reuse the old plan's "Set up" and "How to use" pages — both
screens were deleted. The app is now home / recents / settings, and everything
those pages explained lives on the site.

## Before submitting — checklist

- [ ] Support URL that resolves
- [ ] App name available in App Store Connect
- [ ] Screenshots at both required sizes
- [ ] Archive from Xcode, uploaded, processed
- [ ] Privacy answers set to Data Not Collected
- [ ] Review notes pasted in
- [ ] Consider attaching a demo video — the strongest defence against 4.2
