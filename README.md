# SendPin

Look up a café on your phone, send it to your Karoo 2, and let the bike computer
do the navigating.

---

## Who this is for

You:

- Have a **Hammerhead Karoo 2**, and don't want to upgrade to a Karoo 3 just to
  get this one feature from its companion app.
- Don't want to pay for a SIM card, and therefore can't use the Waypoints
  extension.
- Are savvy enough to sideload an Android app.

## The problem

Often when I go on a ride, especially somewhere I don't know well, I look up a
café or somewhere to eat on my phone. Even when I have a set route, I usually
don't have that destination picked in advance; I just find a spot as I'm rolling
through a town.

Which leaves me riding one-handed with my phone out, or trying to memorise the
route and inevitably pulling my phone back out to check.

Meanwhile I have a bike computer I specifically bought for navigation. It's
great, but its search experience will never match what I get on my phone.

So what I want is simple: look up a place on my phone, send it to my bike
computer, and let the Karoo take it from there.

To be clear: **this is already a solved problem** via the companion apps on the
Hammerhead Karoo 3, Garmin and Wahoo. Just not on the Karoo 2. See the *who this
is for* section.

## How it works

Your phone advertises the destination over Bluetooth Low Energy, and the Karoo
picks it up — much the same way your power meter broadcasts numbers to your head
unit. There's no cloud, no account, and no internet needed on the Karoo. The
Karoo does pair to the first phone it hears — logically, not a Bluetooth bond —
so a second SendPin user nearby can't land pins on the wrong head unit.

```
Apple Maps ──share──▶ SendPin (iPhone)
                            │
                     Bluetooth LE
                            ▼
                  SendPin (Karoo 2) ──▶ navigation
```

In slightly more detail:

1. Sharing to SendPin hands the app an **MKMapItem** — Apple's own place
   object, with the latitude, longitude and name already in it. Nothing is
   parsed out of a URL, so nothing can be misread.
2. A small card appears over Maps and starts broadcasting a custom Bluetooth
   service, with the destination sitting in it as a tiny piece of JSON — about
   72 bytes.
3. A small **extension on the Karoo** is always listening for that particular
   service. It connects, reads the coordinates, and disconnects. Takes about two
   seconds.
4. It hands the destination to the Karoo's **own navigation**, which opens its
   normal Map Pin screen — the same one you'd get from dropping a pin by hand.

The phone stops broadcasting as soon as the Karoo has taken the destination, and
the card closes itself. You never leave Maps.

## Installing

1. **Install the iOS app** — *App Store link, coming*

   That is the whole phone side. SendPin appears in the Maps share sheet by
   itself; there is no Shortcut to add.

2. **Install the Karoo extension** —
   [albertjfoo.github.io/sendpin](https://albertjfoo.github.io/sendpin/)

   The site walks through it with the Karoo plugged into a computer over
   USB — no `adb` install needed, it talks to the device straight from the
   browser (Chrome, Edge or Opera). Once installed, updates land on the Karoo
   itself via long-press → Update, no cable required.

   Prefer the command line? Same thing, by hand:

   ```sh
   adb install -r sendpin.apk
   adb shell pm grant app.sendpin android.permission.ACCESS_FINE_LOCATION
   ```

   That second line is **not optional**. Android 8.1 returns no Bluetooth scan
   results at all without location permission, and the extension will sit there
   looking perfectly healthy while finding absolutely nothing. The app also asks
   for it on first launch, so granting it on the device works just as well.

## Using it

1. Find a place in **Apple Maps** (Google Maps isn't available yet)
2. **Share** → **SendPin**
3. A card appears over Maps and starts broadcasting — leave it on screen for a
   second or two
4. The Karoo beeps and shows the pin, ready to navigate

You never leave Maps, and you never need to open the SendPin app. The app is
there for setup, for troubleshooting, and to tell you what the Bluetooth side is
actually doing.

## Worth knowing

- **Keep the card on screen while sending.** iPhones hide Bluetooth service
  UUIDs from non-Apple devices the moment an app goes to the background. That's
  an iOS rule, not something an app can work around — which is why the card
  waits for the Karoo rather than dismissing straight away.
- **The Karoo needs a GPS fix**, and the relevant offline map region downloaded.
  Indoors you'll get the pin and a "GPS required".
- **Destinations have to be within range.** The Karoo handles routes up to about
  500 miles (800 km), so anywhere you could plausibly ride to is fine. Send it
  somewhere across the country and the pin arrives but the Karoo declines to
  route to it.

## Troubleshooting

**"SendPin" isn't in the share sheet.** Scroll the row of app icons to the end,
tap **More**, and switch SendPin on. iOS often doesn't surface a newly installed
share extension until you enable it once.

**The phone says it sent, but nothing happens on the Karoo.** Open SendPin on the
Karoo — the status line tells you which of these it is:

| status | what it means |
|---|---|
| *Location needed — tap to grant* | tap it and allow. Android returns no Bluetooth scan results at all without it, and nothing works until it's granted |
| *Off* | the **Enabled** switch is off |
| *Starting…* | normal for a second or two right after enabling. If it doesn't move past this, restart the Karoo — a fresh install doesn't always start listening until the next boot |
| *Waiting for Bluetooth* | the Karoo has taken the radio back, usually for its own sensors. It keeps asking for it and recovers on its own; if it persists, restart the Karoo |
| *Listening* | the Karoo is fine — check the phone is still on the SendPin screen and unlocked |

**The pin appears but the Karoo says GPS is required.** Working as intended — it
can't route from *here* to *there* without knowing where *here* is. Take it
outside and let it get a fix.

**Sending the same place twice in quick succession does nothing.** Intended, but
only just. The Karoo ignores a destination identical to the last one for about
ten seconds, so the repeated sightings within one send can't open the pin screen
twice. Wait a moment and the same place goes through again.

Note the phone can't tell the difference: it reports **Sent** because the Karoo
genuinely connected and read the waypoint. What it can't know is that the Karoo
then discarded it. Nothing is sent back the other way.

**The card says nothing picked this up.** The Karoo never connected. Open SendPin
on the Karoo and check the status line — the table above says what each state
means. The usual causes are the extension being switched off, or location
permission never having been granted.

If you report a problem, include what the Karoo's status line says and anything
red in **Connection details** on the phone. Those two together explain almost
every failure.

## Why I built this

I thought it would be a fun project, given how good the AI tooling has got, and
because doing it over Bluetooth Low Energy seemed like an interesting challenge.

I should caveat all of this: **I'm not a software engineer.** I work in tech, but
I was focused far more on *what* I wanted to solve than on *how* to solve it. At
the end of the day, all that's happening is an iOS app sending a message over
Bluetooth — much like your power meter does — carrying a latitude and longitude,
and your Karoo reading it.

I built it in an afternoon. Given how niche this is — Hammerheads aren't as
common as Wahoos or Garmins, and the Karoo 3 already solves this — how much more
I add to it is TBD. As of right now, it simply solves what I originally intended.

If something's broken or you have ideas or feedback, I'd love to hear them —
[leave a note](https://forms.gle/1TU9ZwDXzMth9HCL8).

## Building it yourself

```sh
# iPhone
cd ios && xcodebuild build -scheme SendPin -destination 'id=<your-iphone-udid>'

# Karoo
cd karoo && ./gradlew :app:assembleDebug
```

Needs Xcode 26+, JDK 17 and the Android SDK. `karoo-ext` resolves from JitPack,
so you don't need a GitHub Packages token.

Touching `Destination.swift` or `Waypoint.swift`? Run `ios/Tests/run.sh` —
twelve checks on Apple Maps share-link parsing, no simulator or Xcode project
needed. A pre-commit hook runs it automatically on those files, but it isn't
version-controlled (`.git/hooks/` never is), so it won't follow the repo to a
fresh clone.

| | |
|---|---|
| [PROTOCOL.md](PROTOCOL.md) | the Bluetooth contract between the two halves |
| [RISKS.md](RISKS.md) | what was uncertain, what got proven, and how |

## Status

Works end to end on real hardware. Tested on exactly one Karoo 2 running firmware
`1.613.2351.12` and one iPhone — other firmware versions are unverified, so your
mileage may genuinely vary.

MIT licensed. Not affiliated with or endorsed by Hammerhead or SRAM.
