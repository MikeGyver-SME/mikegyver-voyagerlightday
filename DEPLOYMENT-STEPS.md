# Voyager Light-Day iOS v1.0.0 — TestFlight Deployment

Bundle ID: `studio.mikegyver.voyagerlightday`
iOS 17.0+ · SwiftUI · No server, no third-party deps
Repo: `MikeGyver-SME/mikegyver-voyagerlightday`
Pipeline: GitHub Actions → fastlane → TestFlight (same proven pipeline as SSTV Studio / PodMix)

## What is in this zip

- `README.md` — what the app does
- `DEPLOYMENT-STEPS.md` — this file
- `VoyagerLightDay/` — the 4 Swift files, Info.plist, AppIcon set
- `VoyagerLightDay.xcodeproj/project.pbxproj` — hand-written project, single app target
- `.github/workflows/testflight.yml` — already in place, no separate deploy pack needed
- `scripts/push-voyagerlightday.ps1` — PowerShell push + tag script

## 0. Prep on your Windows machine

Extract `voyager-lightday-ios-v1.0.0.zip` to your Downloads folder, so
you have `E:\Downloads\voyager-lightday-ios-v1.0.0\voyager-lightday-ios`
(E:\Downloads is your permanent Downloads folder; fall back to the
shell Downloads folder if E: is not there.)

## 1. Apple — App ID and App Store Connect record

Do this first. The workflow uploads by bundle ID and fails when no
record exists, even when the portal App IDs and GitHub secrets are
already in place.

1. developer.apple.com → Certificates, Identifiers & Profiles →
   Identifiers → + → App IDs → App
   - Description: `Voyager Light-Day`
   - Bundle ID: Explicit, `studio.mikegyver.voyagerlightday`
   - No capabilities needed. Continue → Register.
2. appstoreconnect.apple.com → Apps → + → New App → iOS
   - Name: `Voyager Light-Day`
   - Primary language: English (U.S.)
   - Bundle ID: select `studio.mikegyver.voyagerlightday`
   - SKU: `voyagerlightday-001`
   - User Access: Full Access. Create.

## 2. GitHub — create the repo

Create an empty repo (no README, no .gitignore — the push script
copies the source in):

```powershell
gh repo create MikeGyver-SME/mikegyver-voyagerlightday --public --description "Voyager Light-Day - countdown to Voyager 1 one light-day away, flashes V-G-R in Morse at T-0"
```

Or create it on github.com the same way. Do not put any files in it
by hand.

## 3. GitHub — add the four Actions secrets

Repo → Settings → Secrets and variables → Actions → New repository
secret. Same four as SSTV Studio / PodMix / TowerLog / WalkLog.

- `TEAM_ID` — your Apple Developer Team ID
- `ASC_KEY_ID` — App Store Connect API key ID
- `ASC_ISSUER_ID` — Issuer ID (UUID from the API key page)
- `ASC_KEY_P8` — full contents of the downloaded `AuthKey_XXXX.p8`
  file, including the BEGIN PRIVATE KEY / END PRIVATE KEY lines

Use the Team ID, Key ID, and Issuer ID you supplied for the other
deploys. For the .p8, paste the file contents into the secret on
GitHub — do not paste the key into chat or email.

Note on certificates: Apple allows a limited number of Distribution
certificates per team. This workflow best-effort revokes orphaned
distribution certs from previous ephemeral runners before minting a
fresh one. If a run ever fails with a maximum-certificates error,
revoke only one Distribution certificate in the portal, then re-run
the workflow with no code change.

## 4. Push and tag — this starts the build

```powershell
powershell -ExecutionPolicy Bypass -File .\push-voyagerlightday.ps1
```

Defaults: source `E:\Downloads\voyager-lightday-ios-v1.0.0\voyager-lightday-ios`,
local clone `~\source\repos\mikegyver-voyagerlightday`, tag `v1.0.0`.

What the script does:
1. Clones `MikeGyver-SME/mikegyver-voyagerlightday` if needed, else pulls `main`
2. Copies the source in (excluding `.git`), commits, pushes `main`
3. Creates and pushes tag `v1.0.0` — the tag push triggers the
   "Build and upload Voyager Light-Day to TestFlight" workflow

Watch it at: https://github.com/MikeGyver-SME/mikegyver-voyagerlightday/actions

## 5. After the workflow goes green

1. Give Apple a few minutes to process the build.
2. App Store Connect → TestFlight → check the build is Ready to Test,
   not Missing Compliance. The ITS flag in Info.plist should clear
   compliance automatically.
3. TestFlight → Internal Testing → add yourself to the internal test
   group for this app (internal groups do not cross apps — confirm it
   belongs to `studio.mikegyver.voyagerlightday`).
4. Open the TestFlight invite on your iPhone and install. The torch
   needs a real device, not the simulator.

## 6. First-run checklist — do this Tuesday night, Nov 17

- Open the app, allow notifications when asked.
- Tap **Play V-G-R Now** once: torch should flash V ...- G --.
  R .-. , the 620 Hz tone should beep in sync, and the screen
  should flash white with each letter. Then your message
  `CQ VOYAGER KJ5SES 73` plays after it (about 61 seconds total).
- Leave **Stay awake overnight** on, leave the app open and the
  phone plugged in. At 4:16:07 AM CST Wednesday it flashes V-G-R +
  your message by itself.
- If you open the app after T-0 (within the hour), it fires once on
  launch — same flash, same message.

## Version bumps

Edit `VoyagerLightDay.xcodeproj/project.pbxproj`: bump
`MARKETING_VERSION` (e.g. `1.0.1`) and `CURRENT_PROJECT_VERSION`
(build number must be higher than every build already uploaded for
this version — TestFlight rejects a duplicate version + build pair).
Then:

```powershell
powershell -ExecutionPolicy Bypass -File .\push-voyagerlightday.ps1 -Tag v1.0.1
```

## If the first build fails

Copy the failing step's log from the Actions run and send it back.
Do not guess at three fixes — read the log, fix the one step it
names. Common first-run suspects, in order: missing App Store
Connect record, a secret pasted with extra whitespace or a missing
.p8 footer, no free Distribution certificate slot, or a Swift
compile error in the hand-written project (never compiled before
this run).
