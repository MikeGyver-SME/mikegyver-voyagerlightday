# Voyager Light-Day — iOS app (v1.0.3)

A native iOS countdown to the moment Voyager 1 becomes the first
human-made object one light-day from Earth — **Wed, Nov 18, 2026 at
4:16:07 AM CST (10:16:07 UTC), 16.1 billion miles out** — and at T-0
it flashes **V-G-R in Morse** from the phone itself.

Bundle ID: `studio.mikegyver.voyagerlightday` · iOS 17.0+ · SwiftUI ·
no server, no third-party dependencies.

## What it does

- **Live countdown** — days / hours / minutes / seconds to the fixed
  UTC instant, ticking once a second. The date is a fixed UTC instant
  in code, never a local-time guess.
- **At T-0, it flashes V-G-R by itself** — V `...-`, G `--.`, R `.-.`
  — three ways at once, in sync:
  - the camera torch (flashlight),
  - a 620 Hz tone through the speaker,
  - a full-screen white flash showing the letter being sent.
  If the app is opened after T-0 (within the hour), it fires once on
  launch instead. A toggle turns the automatic T-0 flash off.
- **Play V-G-R Now** — test the whole thing any time before Tuesday
  night: torch + tone + screen flash, same as T-0.
- **Your message to Voyager** — an optional message, sent in Morse
  right after V-G-R. Limit is **20 characters**, shown as a live
  counter, enforced as you type (letters, numbers and spaces only —
  anything Morse can't send is dropped). Pre-filled with Mike's
  message: `CQ VOYAGER KJ5SES 73` (exactly 20/20). Leave it blank to
  send just V-G-R. Full send (V-G-R + that message) takes about
  61 seconds; V-G-R alone is about 8 seconds.
- **Stay awake overnight** — on by default; keeps the screen on so
  the app is still in the foreground at 4:16 AM. Turn it off in the
  morning and the idle timer goes back to normal.
- **Reminders** — notifications at T-5 minutes and at T-0 (on by
  default; the app asks for notification permission once).

## Morse timing

One unit = 0.25 s. Dit = 1 unit, dah = 3 units, gap inside a letter
= 1 unit, between letters = 3 units, between words = 7 units. That
reads clearly on a phone torch and on camera, at the same proportions
NASA describes for Shine Bright.

## Files

| File | What it does |
| --- | --- |
| `VoyagerLightDay/ContentView.swift` | Countdown, T-0 auto-fire, message field, toggles, links |
| `VoyagerLightDay/MorseCode.swift` | Morse table, timing, 20-char sanitiser |
| `VoyagerLightDay/MorsePlayer.swift` | Torch + 620 Hz tone + screen flash, in sync; notifications |
| `VoyagerLightDay/VoyagerLightDayApp.swift` | App entry point |
| `VoyagerLightDay/Info.plist` | Display name, `ITSAppUsesNonExemptEncryption = NO`, audio background mode, camera (torch) usage text |
| `VoyagerLightDay.xcodeproj/project.pbxproj` | Hand-written project, single app target |
| `.github/workflows/testflight.yml` | GitHub Actions → fastlane → TestFlight (same proven pipeline as SSTV Studio / PodMix) |
| `scripts/push-voyagerlightday.ps1` | PowerShell push + tag script |

## Building

1. Open `VoyagerLightDay.xcodeproj` in Xcode.
2. Select your development team under Signing & Capabilities (signing
   is Automatic; the bundle ID is already
   `studio.mikegyver.voyagerlightday`).
3. Build and run on your iPhone — the torch needs a real device, not
   the simulator (the simulator still shows the screen flash and
   plays the tone). For TestFlight, use `DEPLOYMENT-STEPS.md`.

## What I could not verify here

This was built on a Linux machine with no Xcode, so the project was
**not compiled** here. The project file is internally consistent
(all IDs resolve, braces balanced), the icon set is complete (all 9
sizes + the 1024 marketing icon in both the `ios-marketing` and
`universal` slots), and the Swift files are balanced — but the first
Xcode / Actions build is the real test. If it throws a build error,
paste it back and I'll fix it the same turn.

## Changelog

- **v1.0.0** — First build. Countdown, T-0 auto-flash, Play V-G-R
  Now, 20-char custom message, stay-awake, T-5 / T-0 reminders.
- **v1.0.1** (build 2) — Fix: on Xcode 26, scheduling a notification
  is `async throws`, so the reminder call is now `try? await`. Also
  removed a stray unassigned icon file that actool warned about.
  No behavior change.
- **v1.0.2** (build 3) — The on-screen letter is now steady for the
  whole letter instead of blinking once per dit/dah; only the white
  flash pulses per element. No change to the torch, the tone, or the
  Morse timing.
- **v1.0.3** (build 4) — Tone diagnosis: a Test Tone button plays a
  1-second 620 Hz beep on demand, and the app now shows the tone
  engine's status — a failed audio session or engine start used to
  fail silently, leaving torch + flash with no sound and no clue.
  Also calls `prepare()` and sets the mixer volume explicitly.
