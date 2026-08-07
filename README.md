# SendPin

Look up a café on your phone, send it to your Karoo 2, and let the bike computer
do the navigating.

---

## Who this is for

You:

- Have a **Hammerhead Karoo 2**, and don't want to upgrade to a Karoo 3 just to
  get this one feature from its companion app.
- Don't want to pay for a SIM card, and don't find the Waypoints extension all
  that useful.
- Are savvy enough around a computer to solve a problem whose effort-to-payoff
  ratio is, frankly, questionable.

That last one deserves honesty: getting this onto a Karoo 2 needs a computer, a
USB cable, and a couple of `adb` commands. It's a faff. Whether that's worth it
for a feature you might use a handful of times a month is genuinely your call.

## The problem

Often when I go on a ride, especially somewhere I don't know well, I look up a
café or somewhere to eat on my phone — Apple or Google Maps. Even when I have a
set route, I usually don't have that destination picked in advance; I just find a
spot as I'm rolling through a town.

Which leaves me riding one-handed with my phone out, or trying to memorise four
turns and inevitably pulling my phone back out to check. That's how I lead my
group ride astray, make everyone U-turn, and annoy drivers in the process.

Meanwhile I have a bike computer I specifically bought *for navigation*.
Whenever I actually use it, I come off as a local and get promoted to ride
leader — for a few blocks, at least, until we reach the pitstop.

So what I want is simple: look something up in Google or Apple Maps, send it to
my bike computer, and let the Karoo take it from there. Maps has the best search
experience by a mile. But unless you've got a bulky phone mount on your bars,
searching on the phone and navigating on the phone are two different things.

To be clear: **this is already a solved problem** via the companion apps on
Hammerhead, Garmin and Wahoo. Just not on the Karoo 2. See the *who this is for*
section.

## How it works

Your phone advertises the destination over Bluetooth Low Energy, and the Karoo
picks it up — much the same way your power meter broadcasts numbers to your head
unit. There's no cloud, no account, no internet needed on the Karoo, and the two
devices never even pair.

```
Apple Maps ──share──▶ Shortcut ──▶ SendPin (iPhone)
                                        │
                                 Bluetooth LE
                                        ▼
                              SendPin (Karoo 2) ──▶ navigation
```

In slightly more detail:

1. A **Shortcut** pulls the latitude, longitude and place name out of the Maps
   share link and hands them to the iPhone app.
2. The **iPhone app** starts broadcasting a custom Bluetooth service, with the
   destination sitting in it as a tiny piece of JSON — about 48 bytes.
3. A small **extension on the Karoo** is always listening for that particular
   service. It connects, reads the coordinates, and disconnects. Takes about two
   seconds.
4. It hands the destination to the Karoo's **own navigation**, which opens its
   normal Map Pin screen — the same one you'd get from dropping a pin by hand.

The phone stops broadcasting as soon as the Karoo has taken the destination, so
nothing is left chattering in your pocket.

## Installing

Three pieces, in any order.

| | |
|---|---|
| **iPhone app** | *App Store link — coming* |
| **Shortcut** | *iCloud link — coming* |
| **Karoo extension** | [Latest release](https://github.com/albertjfoo/sendpin/releases/latest) |

### The Karoo half needs a computer, once

There's no way around this, and it isn't specific to this app — it's every
Karoo 2 extension. Hammerhead's Companion app sideloading is Karoo 3 only,
there's nothing on the dashboard for it, and the Karoo's own browser isn't
reachable from its launcher.

So, with the Karoo plugged in over USB:

```sh
adb install -r sendpin.apk
adb shell pm grant com.albert.sendpin android.permission.ACCESS_FINE_LOCATION
```

That second line is **not optional**. Android 8.1 returns no Bluetooth scan
results at all without location permission, and the extension will sit there
looking perfectly healthy while finding absolutely nothing. The app also asks for
it on first launch, so granting it on the device works just as well.

## Using it

1. Find a place in **Apple Maps**
2. **Share** → **Send to Karoo**
3. SendPin opens and starts broadcasting — leave it on screen
4. The Karoo beeps and shows the pin, ready to navigate

## Worth knowing

- **Keep the app on screen while sending.** iPhones hide Bluetooth service UUIDs
  from non-Apple devices the moment an app goes to the background. That's an iOS
  rule, not something an app can work around.
- **The Karoo needs a GPS fix**, and the relevant offline map region downloaded.
  Indoors you'll get the pin and a "GPS required" — that's the Karoo being
  sensible, not a bug.
- **It's one tap on the phone and one confirm on the Karoo.** The pin screen asks
  before it reroutes you, which is probably what you want mid-ride.
- **Google Maps isn't supported yet.** Its share links are short redirects that
  contain no coordinates at all — see [PROTOCOL.md](PROTOCOL.md) for what was
  tried and why it's parked.

## Why I built this

I thought it would be a fun project, given how good the AI tooling has got, and
because doing it over Bluetooth Low Energy seemed like an interesting challenge.

I should caveat all of this: **I'm not a software engineer.** I work in tech, but
I was focused far more on *what* I wanted to solve than on *how* to solve it. At
the end of the day, all that's happening is an iOS app sending a message over
Bluetooth — much like your power meter does — carrying a latitude and longitude,
and your Karoo reading it.

I built it in an afternoon. Given how niche this is — Hammerheads aren't as
common as Wahoos or Garmins, and the Karoo 3 already solves this — I'm not sure
I'll take it much further. It already scratches the itch I built it for.

If it scratches yours too, brilliant. If something's broken,
[open an issue](https://github.com/albertjfoo/sendpin/issues), just don't expect
enterprise support.

## Building it yourself

```sh
# iPhone
cd ios && xcodebuild build -scheme SendPin -destination 'id=<your-iphone-udid>'

# Karoo
cd karoo && ./gradlew :app:assembleDebug
```

Needs Xcode 26+, JDK 17 and the Android SDK. `karoo-ext` resolves from JitPack,
so you don't need a GitHub Packages token.

| | |
|---|---|
| [PROTOCOL.md](PROTOCOL.md) | the Bluetooth contract between the two halves |
| [RISKS.md](RISKS.md) | what was uncertain, what got proven, and how |
| [HANDOFF.md](HANDOFF.md) | developer notes, dead ends, and why things are the way they are |

## Status

Works end to end on real hardware. Tested on exactly one Karoo 2 running firmware
`1.613.2351.12` and one iPhone — other firmware versions are unverified, so your
mileage may genuinely vary.

MIT licensed. Not affiliated with or endorsed by Hammerhead or SRAM.
