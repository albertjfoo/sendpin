# SendPin

Send a destination from your iPhone to a **Hammerhead Karoo 2**, and navigate to it.

Share a place from Apple Maps, and the Karoo opens its native Map Pin screen
ready to navigate. Takes about two seconds. No internet on the Karoo, no
account, no cloud.

The Karoo 3 does this natively. The Karoo 2 never got it.

---

## How it works

```
Apple Maps  ──share──▶  Shortcut  ──▶  SendPin (iPhone)
                                            │
                                     Bluetooth LE
                                            ▼
                                   SendPin (Karoo 2)  ──▶  native navigation
```

The iPhone advertises a destination over Bluetooth. A small extension on the
Karoo is listening for it, reads the coordinates, and hands them to the Karoo's
own navigation. Nothing is touched on the head unit — you share from your
phone and the pin appears.

Your data never leaves the two devices.

## What you need

- A **Karoo 2** (the Karoo 3 already does this natively)
- An **iPhone**
- A **computer with a USB cable**, once, to install the Karoo half —
  see [the friction warning](#installing-on-the-karoo-is-awkward)

## Installing

Three pieces, in any order.

| | |
|---|---|
| **iPhone app** | *App Store link — coming* |
| **Shortcut** | *iCloud link — coming* |
| **Karoo extension** | [Latest release](https://github.com/albertjfoo/sendpin/releases/latest) |

### Installing on the Karoo is awkward

Being straight about this: the Karoo 2 has no supported way to install a
third-party app without a computer.

- Hammerhead's Companion app sideloading is **Karoo 3 only**
- There is nothing on the Hammerhead dashboard for it
- The Karoo's own browser exists but is not reachable from its launcher

So the Karoo half needs `adb` over USB, once:

```sh
adb install -r sendpin.apk
adb shell pm grant com.albert.sendpin android.permission.ACCESS_FINE_LOCATION
```

That second line is **not optional**. Android 8.1 returns no Bluetooth scan
results at all without location permission, and the app will sit there looking
perfectly healthy while finding nothing. The app asks for it on first launch
too, so granting it on the device works just as well.

This applies to every Karoo 2 extension, not just this one — it is the device,
not the app.

## Using it

1. Find a place in **Apple Maps**
2. **Share** → **Send to Karoo**
3. SendPin opens and starts broadcasting — leave it on screen
4. The Karoo beeps and shows the pin, ready to navigate

The iPhone stops broadcasting by itself once the Karoo has the destination.

### Things worth knowing

- **The app must be on screen while sending.** iPhones hide Bluetooth service
  UUIDs from non-Apple devices the moment an app goes to the background. This
  is an iOS rule and cannot be worked around.
- **The Karoo needs a GPS fix** to navigate, and the relevant **offline map
  region** downloaded. Indoors you will get the pin and a "GPS required".
- **It is one tap on the phone, one confirm on the Karoo.** The Karoo's pin
  screen asks before it reroutes you, which is probably what you want mid-ride.
- **Google Maps is not supported.** Its share links contain no coordinates —
  see [PROTOCOL.md](PROTOCOL.md) for what was tried.

## Building it yourself

```sh
# iPhone
cd ios && xcodebuild build -scheme SendPin -destination 'id=<your-iphone-udid>'

# Karoo
cd karoo && ./gradlew :app:assembleDebug
```

Needs Xcode 26+, JDK 17, and the Android SDK. `karoo-ext` resolves from
JitPack, so no GitHub Packages token is required.

## Documentation

| | |
|---|---|
| [PROTOCOL.md](PROTOCOL.md) | the Bluetooth contract between the two halves |
| [RISKS.md](RISKS.md) | what was uncertain, what was proven, and how |
| [HANDOFF.md](HANDOFF.md) | developer notes, dead ends, and why things are the way they are |

## Status

Working end to end on real hardware. Tested on one Karoo 2 on firmware
`1.613.2351.12` and one iPhone — other firmware versions are unverified.

Not affiliated with or endorsed by Hammerhead or SRAM.
