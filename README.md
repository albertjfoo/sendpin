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

The phone stops broadcasting as soon as the Karoo has taken the destination.

## Installing

1. **Install the iOS app** — *App Store link, coming*
2. **Install the iOS Shortcut** — *iCloud link, coming*
3. **Install the Karoo extension** —
   [latest release](https://github.com/albertjfoo/sendpin/releases/latest)

   This is the most challenging part. With the Karoo plugged in over USB:

   ```sh
   adb install -r sendpin.apk
   adb shell pm grant com.albert.sendpin android.permission.ACCESS_FINE_LOCATION
   ```

   That second line is **not optional**. Android 8.1 returns no Bluetooth scan
   results at all without location permission, and the extension will sit there
   looking perfectly healthy while finding absolutely nothing. The app also asks
   for it on first launch, so granting it on the device works just as well.

## Using it

1. Find a place in **Apple Maps** (Google Maps isn't available yet)
2. **Share** → **Send to Karoo**
3. SendPin opens and starts broadcasting — leave it on screen
4. The Karoo beeps and shows the pin, ready to navigate

## Worth knowing

- **Keep the app on screen while sending.** iPhones hide Bluetooth service UUIDs
  from non-Apple devices the moment an app goes to the background. That's an iOS
  rule, not something an app can work around.
- **The Karoo needs a GPS fix**, and the relevant offline map region downloaded.
  Indoors you'll get the pin and a "GPS required".

## Troubleshooting

**"Send to Karoo" isn't in the share sheet.** The Shortcut either isn't installed
or isn't enabled for sharing. Scroll to the bottom of the share sheet, tap
**Edit Actions…**, and switch it on.

**The phone says it sent, but nothing happens on the Karoo.** Open SendPin on the
Karoo — the status line tells you which of these it is:

| status | what it means |
|---|---|
| *Location permission is required* | tap to grant it. Android returns no Bluetooth scan results at all without it, and nothing works until it's granted |
| *off* | the **Listen for destinations** switch is off |
| *waiting for Bluetooth* | the Karoo hasn't handed over the radio yet. It retries every few seconds; if it persists, restart the Karoo |
| *listening* | the Karoo is fine — check the phone is still on the SendPin screen and unlocked |

**The pin appears but the Karoo says GPS is required.** Working as intended — it
can't route from *here* to *there* without knowing where *here* is. Take it
outside and let it get a fix.

**Sending the same place twice does nothing the second time.** Also intended. The
Karoo ignores a destination identical to the last one for two minutes, so a phone
left broadcasting doesn't reopen the pin screen over and over. Wait it out, or
send somewhere else.

**Nothing happens at all when you share.** The Shortcut probably built a bad URL.
Open SendPin on the phone and tap **Connection details** — a red
`could not parse` line means the Shortcut sent something malformed, usually
because the place had no coordinates in its Maps link.

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

If something's broken, [open an issue](https://github.com/albertjfoo/sendpin/issues).
If you have other ideas or feedback, I'd love to hear them.

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
