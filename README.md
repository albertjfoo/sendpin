# SendPin

**[albertjfoo.github.io/sendpin](https://albertjfoo.github.io/sendpin/)** —
install guide, troubleshooting, and the app itself.

---

## Who this is for

You:

- Have a **Hammerhead Karoo 2**, and don't want to upgrade to a Karoo 3 just to
  get this one feature from its companion app.
- Don't want to pay for a SIM card, and therefore can't use the Waypoints
  extension.

## The problem

Often when I go on a ride, especially somewhere I don't know well, I look up a
café or somewhere to eat on my phone. Even when I have a set route, I usually
don't have that destination picked in advance; I just find a spot as I'm rolling
through a town.

Which leaves me riding one-handed with my phone out, or trying to memorise the
route and inevitably pulling my phone back out to check.

Meanwhile I have a bike computer I specifically bought *for navigation*. It's
great, but its search experience will never match what I get on my phone — the
keyboard alone.

So what I wanted was simple: look up a place on my phone, send it to my bike
computer, and let my bike computer navigate me from there.

Having seen others build out their own Karoo extension, I thought it would be
fun to build one myself — one you might find useful too. This isn't the only
way to solve it; see the site for the alternatives and why I built this one
anyway.

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

## Getting it

- **iPhone** — *App Store link, coming*
- **Karoo extension** — install, with the Karoo plugged into a computer over
  USB, straight from the browser: no `adb` needed. Same page also covers the
  command-line route if you'd rather. Once installed, updates land on the
  Karoo itself via long-press → Update, no cable required.

Both at **[albertjfoo.github.io/sendpin](https://albertjfoo.github.io/sendpin/)**.

Once both are in: find a place in Apple Maps, **Share → SendPin**, leave the
card on screen for a second or two, and the Karoo beeps and shows the pin,
ready to navigate. You never leave Maps.

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

Something not working, or an idea or feedback? Troubleshooting lives on the
site, and I'd love to hear from you either way —
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
