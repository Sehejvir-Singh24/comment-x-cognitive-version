# AI Cognitive Companion — Saathi

Launcher foundation and Memory Passport increment from the latest Flutter PRD in `docs/PRD.md`.
The current user instruction overrides steps 2–3 in the PRD: project setup, Android HOME integration, Flutter home UI, then platform bridge.

## Implemented

- Android-only Flutter/Dart patient app; Kotlin contains only Android system integration.
- HOME and LAUNCHER intent registration. Android's own consent UI selects the home app.
- Large, scrolling, high-contrast Flutter home screen with Mr. Bora's explicitly labelled demo profile.
- Installed launchable app list, app opening, and a blank phone dialer (no invented family numbers or direct calls).
- HOME intent returns to the first Flutter route. Default-home status refreshes when resuming.
- English ARB localization and Flutter localization generation; Assamese remains the later PRD milestone.
- Memory Passport with editable profile, family relationships and photos, places, memories, routines, medicine reference notes, and favourite activities.
- Explicit caregiver edit mode, confirmed removal, required-field validation, and local save/error states. This edit mode is a UI boundary, not authentication.
- Photos are selected through Android's picker and copied into app-private storage. No cloud services, microphone access, usage access, or background services. Android automatic backup is disabled.
- Watch, Family, Photos, Medicine, My Day, and voice buttons explicitly explain that those later modules are unavailable. No medication reminders are active.

## Development

Flutter 3.47.2 / Dart 3.13.2 was installed locally under `.tools/flutter` without changing the global PATH.
From PowerShell in this folder:

```powershell
cd patient_app
$env:PUB_CACHE = 'D:\projects\comment x cognitive version\.pub-cache'
& '..\.tools\flutter\bin\flutter.bat' pub get
& '..\.tools\flutter\bin\flutter.bat' analyze
& '..\.tools\flutter\bin\flutter.bat' test
& '.\run-on-phone.ps1'
```

The Android debug APK builds successfully with Android SDK 36 and NDK 28.2.13676358. A project-local package cache is used because this machine's global Dart cache was unreadable during Android compilation. Android CLI's current license check may remain marked "unknown" in Flutter even after the tools are installed.

## Device acceptance check

1. Build/install the debug APK on an Android phone or emulator.
2. Open Saathi from the existing launcher. Confirm all controls remain reachable at maximum system font size.
3. Tap Choose home screen; cancel. Confirm Saathi does not claim to be the default.
4. Choose Saathi using the Android prompt; press HOME. Confirm Saathi appears.
5. Open Phone apps and another installed app; press HOME. Confirm the main Saathi screen returns.
6. Open phone and return without making a call.
7. Repeat with airplane mode enabled. No network should be needed.
8. Restore the prior launcher via Android Settings > Apps > Default apps > Home app.

Host-side tests cover large-text navigation, bridge dispatch for role selection and app opening, and native error propagation. They mock Android calls and do not establish native-device correctness.

## Next increment

Launcher device checks were confirmed by the user. Next is Family Recognition in the PRD's order. UsageStats is optional and intentionally not requested yet.

## Memory Passport checks

Open Memory Passport, then Edit with caregiver. Edit Rahul's details and choose a photo; save and reopen the screen. Confirm the details persist after restarting Saathi and with the network off. Check About me to edit the name, age and region. Routine times use 24-hour HH:MM. Medicines are reference notes only; this increment schedules no reminders and records no adherence.

The provisional storage adapter writes a versioned JSON snapshot atomically in the app-private documents directory. UI/models are separate so Drift/SQLite can replace this adapter at the PRD's database milestone. Corrupt or newer-format files are preserved and shown as an error, never silently reset to the demo. Imported photos have private copies; original gallery photos are never modified. Removing a saved photo removes its private copy. Cancelled imports can leave unused local copies until later cleanup; clearing app data removes them along with the passport.

Path-provider platform implementations are constrained to Android 2.2.x and Foundation 2.5.x because newer native build hooks fail when the Windows Flutter SDK path includes spaces. Keep the lockfile and use run-on-phone.ps1 to preserve the project-local dependency cache.
