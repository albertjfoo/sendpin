# App Store listing

Copy for App Store Connect. Character limits are Apple's and are enforced.

---

## Name (30 max)

```
SendPin
```

Confirmed available and in use — the App Store Connect record was created
under this exact name (app id `6807948060`). `SendPin for Karoo` (18) was the
planned fallback if it had been taken, kept here in case a future app under a
different account ever needs it — it puts a trademark in the name, which is
the thing the product name was chosen to avoid.

## Subtitle (30 max)

```
Location pins to your Karoo 2
```
29 characters. Carries "location pin", the same phrase the app's welcome screen
and the site's tagline both use, so the three read as one product.

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

```
https://albertjfoo.github.io/sendpin/
```

Live, and already used in the actual submission. Apple checks it resolves.

## Privacy Policy URL

Separate from the App Privacy answers below, and easy to miss — the first
submission attempt was rejected specifically for not having filled this in,
even with "Data Not Collected" already answered correctly. Apple requires it
for every app, including ones that collect nothing.

```
https://albertjfoo.github.io/sendpin/privacy.html
```

`docs/privacy.html` reuses the same privacy language as the description below
rather than drafting new claims.

## Pricing

**Free.** Every app needs an explicit tier chosen under Pricing and
Availability in App Store Connect — it does not default, and submission is
blocked until it's set, same as the two items above.

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

• The empty state and welcome screen explain the full flow in plain text
• Sharing a place from Apple Maps → SendPin opens a card directly over Maps
  and begins advertising the destination over Bluetooth immediately
• After about 25 seconds with nothing reading it, the card reports that
  nothing picked up the destination — the expected result with no Karoo
  present
• The shared place is saved in the app's history. Opening SendPin and
  tapping it resends the same destination the same way, and this time the
  live Bluetooth log is visible under Settings → Connection details

The receiving half cannot be simulated without the hardware, so a short video
of the end-to-end flow with the bike computer is attached to this submission.

The app has no accounts, no servers and makes no network requests. The Karoo
extension is a free download and is not sold or promoted through the app.
```

### Guideline 2.1 info request — first submission, 2026-09-04

Standard for accounts with no App Review history; not a rejection. Apple asks
for a screen recording plus five specific questions, both in a reply and in
the Notes field "for reference on future submissions" — so this answer is
durable, reusable for every version after this one too.

**The video from the first submission does not satisfy the recording ask.**
It's real footage of two physical devices side by side, not an iOS Control
Center screen recording of the phone's own screen, which is specifically
what's requested. Re-record: launch the app first (required), then Share →
SendPin from Apple Maps, ideally with a Karoo present so it resolves to
**Sent** rather than the 25-second timeout.

```
1. Screen recording

A screen recording is attached demonstrating the app's functionality, starting
with launching the app. The only part of the flow it cannot show is the Karoo
bicycle computer itself — a separate physical device — receiving the location
and confirming the pin was picked up, since that happens on hardware outside
the iPhone. The recording does show the iPhone side completing successfully:
the destination is picked up and sent.

- No account registration, login, or account deletion — the app has no
  accounts of any kind.
- No user-generated content.
- No paid content or features — the app is free with no in-app purchases.

2. Description of the app's purpose and target audience

SendPin sends a destination from an iPhone to a Hammerhead Karoo cycling GPS
computer over Bluetooth Low Energy. Hammerhead officially supports third-party
extensions on its Karoo devices, and SendPin's Karoo-side component uses that
sanctioned extension framework (karoo-ext). The audience is cyclists who own a
Hammerhead Karoo and want to search for a destination using their phone rather
than the Karoo's own limited on-device search and keyboard.

The problem: cyclists often want to find somewhere to go — a café, a shop, a
place a friend recommended — while already out riding, especially somewhere
unfamiliar. Doing that safely is hard: checking a phone one-handed while
riding is dangerous, and a bike computer's small keyboard and limited search
make it a poor tool to look something up in the moment.

The value: SendPin makes it easy to search for a destination on the iPhone —
Apple Maps reviews, a larger screen, or simply opening a pin a friend sent
over iMessage — and then navigate to it on the bike computer, instead of
riding one-handed with the phone out to check it.

3. Instructions for setup and accessing the app's main features

No login, account, or credentials of any kind — there is nothing to
provision for review.

1. Install SendPin.
2. Find a place in Apple Maps, tap Share, select SendPin.
3. A card appears over Maps and begins advertising the destination over
   Bluetooth Low Energy immediately. This much is fully testable without
   any additional hardware — see the review notes above for exactly what
   is observable at this point.
4. A Hammerhead Karoo 2 running the free, open-source SendPin extension
   receives it within about two seconds and shows the pin, ready to
   navigate. This half requires hardware Apple does not have, which is
   what the attached recording demonstrates.

4. External services, tools, or platforms used

None. SendPin makes no network requests of any kind — no analytics, no
crash reporting, no authentication service, no payment processor, no AI
service, no data provider, no backend of any kind. The only communication
it performs is a direct, local Bluetooth Low Energy transmission from the
iPhone to a Karoo 2 within a few metres — the same category of connection a
power meter or heart rate strap uses. There is nothing external to list.

5. Regional differences

None. There is no server-side component, no geofencing, no region-specific
content or feature gating anywhere in the app. It functions identically in
every region.

6. Regulated industry or protected third-party material

Not applicable. SendPin does not operate in a regulated industry and
includes no protected or licensed third-party material. It uses only
Apple's own frameworks (MapKit, CoreBluetooth) and displays only content
the user has personally selected in Apple Maps.
```

## Screenshots

Required: one size class, not both. Apple's own spec says 6.9" screenshots
auto-scale down through 6.5"/6.3"/6.1", and 6.5" alone satisfies the
requirement if 6.9" isn't provided — confirmed by checking the spec directly
rather than assuming, since the obvious guess (both are required) is wrong.
We shipped 6.5" only, shot on a real device.

Take them on the phone regardless of size — the Simulator cannot run
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

Written before the first submission as a plan; kept afterward as the real
list, since three of these weren't obvious until Apple's own rejection named
them. Useful again for every future version.

- [ ] Support URL that resolves
- [ ] **Privacy Policy URL filled in** — separate field from the Data Not
      Collected answers, and Apple blocks submission without it even when
      those answers are already correct
- [ ] App name available in App Store Connect
- [ ] Screenshots — one size class is enough, not both
- [ ] Archive from current `main`, uploaded, processed, **attached to the
      version** (a successful upload doesn't attach itself — Build still
      says "Add Build" until you pick it explicitly, and Save it)
- [ ] Privacy answers set to Data Not Collected, and **Publish clicked** —
      correct-looking answers alone don't count as submitted
- [ ] **Pricing tier chosen** under Pricing and Availability — Free doesn't
      default, submission is blocked without an explicit choice
- [ ] Review notes pasted in
- [ ] Demo video attached — turned out to be the real defence against 4.2,
      not just worth considering. Apple's Attachment field doesn't accept
      `.gif`; convert to `.mp4` first
- [ ] Clean-device first-run test on the exact build being submitted — this
      is what caught a real bug (stale device pairing after reinstall) the
      first time around
