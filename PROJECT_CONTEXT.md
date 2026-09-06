# AI Cognitive Companion — Complete Project Context

Last updated: 6 September 2026

This document is the working handoff for the AI Cognitive Companion project. Read `docs/PRD.md` as the product source of truth and use this file for implementation status, decisions, environment details, known issues, validation, and the next steps.

## 1. Product goal

Build **Saathi**, an Android cognitive launcher for elderly people living with dementia. The launcher becomes a simple phone home screen and turns familiar daily activities into personalized memory support.

The north star is:

> Turn daily life itself into memory therapy.

The patient experience should be elderly-friendly, privacy-first, voice-first, offline-first, and designed initially for North-East India. The system is a support and behavioural-trend tool. It must never claim to diagnose dementia or determine that dementia is worsening.

## 2. Source documents

- Full current PRD: `docs/PRD.md`
- Current developer and testing notes: `README.md`
- This implementation handoff: `PROJECT_CONTEXT.md`
- Original referenced ChatGPT conversation: **Summarize Dementia App Request**, conversation ID `6a9c6a00-f7c4-83e8-acf9-5e352c97267a`

If this file and the PRD differ on product requirements, follow `docs/PRD.md`. This file records the actual implementation state.

## 3. Required technical architecture

Use Flutter and Dart for patient screens, application logic, localization, cognition features, and local data. Use Kotlin only when Android system access requires native code.

```text
Flutter UI and product logic
        │
        │ Flutter Platform Channel
        ▼
Kotlin Android bridge
        ├── HOME launcher role
        ├── Android intents
        ├── Installed-app discovery and launching
        ├── UsageStats, if added later
        ├── Android permissions
        └── Required Android services, if added later
```

Normal screens must stay in Flutter. Kotlin must remain a small Android system bridge.

The MVP must not use continuous screen recording, message reading, call recording, continuous microphone recording, password capture, banking-data collection, unrelated-content uploads, GPS surveillance, wearables, hospital integration, blockchain, iOS/desktop launchers, complex clinical prediction, or a continuously running large language model.

## 4. Project location and structure

Project root:

```text
D:\projects\comment x cognitive version
```

Current important paths:

```text
comment x cognitive version/
├── .tools/flutter/                    Local Flutter SDK
├── .pub-cache/                        Project-local Dart package cache
├── docs/PRD.md                        Full current product requirements
├── patient_app/
│   ├── android/
│   │   └── app/src/main/kotlin/org/saathi/patient_app/MainActivity.kt
│   ├── lib/
│   │   ├── launcher/launcher_bridge.dart
│   │   ├── memory_passport/
│   │   │   ├── passport.dart
│   │   │   ├── passport_store.dart
│   │   │   └── passport_screen.dart
│   │   ├── l10n/app_en.arb
│   │   └── main.dart
│   ├── test/
│   │   ├── widget_test.dart
│   │   ├── passport_store_test.dart
│   │   └── passport_screen_test.dart
│   ├── pubspec.yaml
│   └── run-on-phone.ps1
├── README.md
└── PROJECT_CONTEXT.md
```

Future PRD directories such as `caregiver_dashboard/` and `firebase/` have not been created because they are later increments.

## 5. Toolchain and phone setup

- Flutter: `3.47.2`, installed locally at `.tools/flutter`
- Dart: `3.13.2`
- Android SDK: `C:\Users\ADMIN\AppData\Local\Android\Sdk`
- Android SDK level detected: `36`
- Required NDK installed: `28.2.13676358`
- Test phone used: Android device reported as `RMX3868`
- Package/application ID: `org.saathi.patient_app`
- Debug APK: `patient_app/build/app/outputs/flutter-apk/app-debug.apk`

Flutter and Dart were deliberately not added to the global Windows PATH. Run the project through the included script or through the local binaries.

The project uses `.pub-cache` because Android compilation could not read several dependencies from the global cache at `C:\Users\ADMIN\AppData\Local\Pub\Cache`. Always preserve the local cache setting when running Flutter commands.

From PowerShell:

```powershell
cd 'D:\projects\comment x cognitive version\patient_app'
.\run-on-phone.ps1
```

Equivalent manual commands:

```powershell
cd 'D:\projects\comment x cognitive version\patient_app'
$env:PUB_CACHE = 'D:\projects\comment x cognitive version\.pub-cache'
& '..\.tools\flutter\bin\flutter.bat' pub get
& '..\.tools\flutter\bin\flutter.bat' analyze
& '..\.tools\flutter\bin\flutter.bat' test
& '..\.tools\flutter\bin\flutter.bat' run
```

Phone connection check:

```powershell
& 'C:\Users\ADMIN\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices
```

The phone must show `device`, not `unauthorized`. Enable Developer Options and USB debugging, select a data-capable USB mode, unlock the phone, and accept the phone's USB-debugging prompt.

The newest Android CLI reports that `sdkmanager --licenses` is obsolete. Flutter may consequently show Android license status as unknown even with a working SDK. This warning did not prevent the verified APK build. Chrome and Visual Studio warnings are irrelevant because this repository currently targets Android only.

## 6. Completed increment 1 — Flutter project and launcher

The Flutter Android project is created with Kotlin as the Android language. The patient home screen uses large controls, high contrast, large text, minimal wording, scrolling for accessibility, and a narrow maximum content width.

Current launcher actions:

- Talk to Saathi — placeholder until the voice milestone
- Memory Passport — working
- Watch — placeholder until video recall
- Family — placeholder until Family Recognition
- Photos — placeholder
- Medicine — placeholder; no reminder is active
- My Day — placeholder
- Open phone — opens the system dialer without inventing or embedding a family number
- Phone apps — lists installed launchable apps and opens the selected app
- Choose home screen — opens Android's system-controlled default HOME selection

The displayed greeting changes by time of day. The displayed patient name comes from the saved Memory Passport. Demo data is clearly marked as a demo profile.

## 7. Completed increment 2 — Android HOME integration

`AndroidManifest.xml` registers the main activity for both normal LAUNCHER access and the Android HOME category. Android itself asks the user whether Saathi should become the default home app.

The Kotlin bridge implements:

- `isDefaultHome`
- `requestHome`
- `listApps`
- `openApp`
- `openDialer`
- HOME-intent notification back to Flutter

The Android activity uses `singleTask`. When the user presses the physical/system Home button, Flutter returns to the first launcher route, including when an unfinished caregiver editor is open. Unsaved edits are discarded in that HOME-button case; normal back/cancel navigation asks before discarding them.

The user tested the launcher on the connected phone and confirmed that everything in this launcher slice worked correctly.

## 8. Completed increment 3 — Flutter/Kotlin platform channel

Flutter communicates with Kotlin through:

```text
org.saathi/launcher
```

Native errors are propagated to Flutter and shown as a simple retry message. Kotlin contains no patient-facing product screens.

## 9. Completed increment 4 — Memory Passport

Memory Passport is implemented in Flutter and installed on the phone.

It contains:

- Patient name, age, region, and explicit demo/personal-profile status
- Family members
- Family photographs
- Relationships
- Visit patterns
- Shared activities
- Important places
- Important memories
- Daily routines
- Medicine reference information
- Favourite activities

Caregivers can enter edit mode, update the patient profile, add/edit/remove entries, and select photos from the Android photo picker. Required fields are validated. Routine times use 24-hour `HH:MM` format. Medicine text is reference information only; the application does not currently schedule reminders, test medicine recall, or record adherence.

The current seeded demo profile is:

```text
Patient: Mr. Bora
Age: 72
Region: Assam

Family:
- Rahul — Son; visits Sunday; shared activity Cricket
- Ananya — Daughter
- Meera — Wife

Routine:
- 08:00 Breakfast
- 09:00 Medicine
- 17:00 Walk
- 20:00 Medicine

Favourite activity:
- Gardening
```

## 10. Current offline storage design

Memory Passport currently uses a small storage adapter that writes a versioned JSON snapshot into the app-private documents directory. This is a deliberate temporary implementation that preserves the required working vertical slice before the PRD's Drift/SQLite milestone.

Storage behaviour:

- Seeds the demo only when no passport exists
- Uses schema version `1`
- Serializes writes so concurrent initial loads cannot race
- Writes to a pending file and then renames it into place
- Keeps edits visible after a failed save so the caregiver can retry
- Preserves corrupt or unknown-version data and displays a load error instead of silently replacing it with demo data
- Copies selected photographs into app-private storage
- Never modifies or deletes the original gallery photograph
- Deletes obsolete private photo copies after a saved entry/photo is removed
- Allows all patient features in this increment to work without internet

Android automatic application backup is disabled to keep current passport data from being copied into cloud backup by the operating system.

The UI and models are separated from `PassportStore`, so Drift/SQLite can replace the adapter later without rewriting the screens.

Current minor limitation: cancelling after importing a brand-new photo can leave an unused private copy. Clearing the app's data removes it. A future maintenance pass can garbage-collect unreferenced files.

## 11. Dependency decision that must be preserved

The project currently constrains these implementations:

```yaml
path_provider_android: '>=2.2.5 <2.3.0'
path_provider_foundation: '>=2.3.2 <2.6.0'
```

Newer releases introduced native build hooks that failed on this Windows machine because the Flutter SDK path contains spaces. Do not casually remove these constraints or delete `pubspec.lock`. The current versions build successfully.

## 12. Verification status

Latest completed verification:

- `flutter test`: **44 tests passed** (100% passing across all modules)
- `flutter analyze`: **No issues found**
- `flutter build apk --debug`: **Succeeded**
- APK installed onto the connected phone: **Succeeded**
- Application process started on the phone: **Succeeded**
- Family Recognition with progressive hints & adaptive difficulty: **Verified on device**
- Video Recall with real videos, immediate & delayed recall: **Verified on device by user**
- Cognitive Records store (`record_store.dart`): **Active & recording metrics offline**

Tests cover:

- Large-text launcher layout
- Default-home bridge dispatch
- Installed-app opening bridge dispatch
- Native error propagation
- Demo seeding
- Persistence after reopening
- Empty passport persistence without accidental reseeding
- Corrupt data preservation
- Unknown schema preservation
- Private photo copying
- Removal of obsolete private photo copies without deleting gallery originals
- Serialized concurrent initial reads
- Required family-entry validation
- Failed-save retry without falsely committing data
- Large-text Memory Passport navigation
- HOME-button escape from a dirty editor

## 13. Manual Memory Passport acceptance check

On the phone:

1. Open **Memory Passport**.
2. Tap **Edit with caregiver**.
3. Edit Rahul and choose a photo.
4. Save, close, and reopen Memory Passport.
5. Confirm Rahul's text and photo remain.
6. Open **About me** and change the name, age, or region.
7. Confirm the launcher greeting updates to the saved name.
8. Add a place, memory, routine, and favourite activity.
9. Turn on airplane mode, restart Saathi, and confirm the data remains usable.
10. Confirm Medicine is described as reference information and that no reminder claims to be active.

## 14. Privacy and safety decisions already applied

- No screen recording or screen-content monitoring
- No WhatsApp/message access
- No call recording
- No microphone permission or continuous recording
- No UsageStats permission yet
- No location permission
- No Firebase or cloud transmission
- No authentication yet; **Edit with caregiver** is a visible UI boundary, not an access-control mechanism
- No medical diagnosis claims
- No medicine delay or recall test implemented in this increment
- Photo selection uses the system picker and private app copies
- Android backup disabled

## 15. Build order and current position

The latest user-requested first steps were completed in this order:

```text
1. Flutter project setup                         COMPLETE
2. Android HOME launcher integration in Kotlin  COMPLETE
3. Flutter launcher home UI                     COMPLETE
4. Flutter ↔ Kotlin bridge                      COMPLETE
5. Memory Passport                              COMPLETE
6. Family Recognition                           COMPLETE
7. Video Recall Module                          COMPLETE
8. Progressive Hints                            COMPLETE
9. Rule-based Cognitive Engine                  COMPLETE
10. Drift / SQLite                              NEXT
11. Medicine + My Day
12. Voice
13. Firebase
14. Caregiver Dashboard
15. Assamese localization
16. Optional Object Recognition
```

Each increment must keep the launcher and existing cognitive flow working.

## 16. Next implementation — Family Recognition

The next vertical slice should open from the existing **Family** launcher button and use saved `MemoryKind.family` entries.

Minimum behaviour from the PRD:

```text
Show one saved family photo
        ↓
Ask “Who is this?”
        ↓
Allow an answer
        ↓
Offer progressive hints when needed
        ↓
Record correct/incorrect, response time, hint count,
difficulty, question type, and timestamp
```

Recommended incremental boundary:

- Require at least one family entry with a saved photo
- Explain clearly when no usable family photo exists and link back to Memory Passport
- Use touch input first; voice comes at the later voice milestone
- Avoid exposing the correct answer before the patient commits or requests a hint
- Keep scoring deterministic and explainable
- Store results through a narrow repository interface so the later Drift/SQLite step can replace temporary storage
- Keep the medicine safety rule unrelated to this exercise
- Do not add Firebase, LLM calls, UsageStats, or dashboard work in this increment

The exact progressive-hint example is:

```text
Hint 1: He is from your family.
Hint 2: He is your son.
Hint 3: His name starts with R.
```

Use the actual saved relationship, name, and other Memory Passport details instead of hardcoding Rahul in the feature.

## 17. Later product behaviour

After Family Recognition, implement the controlled video module with immediate and delayed recall, then progressive hints and the rule-based cognitive engine. The engine uses the last five answers:

```text
More than 80% correct → increase difficulty
40–80% correct        → maintain difficulty
Below 40% correct     → reduce difficulty or provide more hints
```

Every cognitive interaction eventually stores:

- Question type
- Correct or incorrect
- Response time
- Hints required
- Difficulty
- Timestamp

The main longitudinal metrics are recall accuracy, hint dependency, response time, delayed recall, and routine completion. A later Cognitive Stability Indicator may summarize changes, but it must be presented as a personal behavioural trend and never a medical diagnosis.

Voice should eventually use Android TextToSpeech and SpeechRecognizer with Flutter controls and a touch fallback. Offline language support must be tested on the exact demonstration device before making claims. English exists now; Assamese is the planned MVP regional language milestone.

Firebase is a later sync layer for authentication, patient/caregiver linkage, Memory Passport synchronization, and cognitive summaries. Patient features must remain usable whenever Firebase or the internet is unavailable.

## 18. Main demo target

The final demonstration should tell one continuous story:

```text
Saathi Android cognitive launcher
        ↓
Mr. Bora opens Family
        ↓
Recognizes a family photograph
        ↓
Hints and response are recorded
        ↓
Mr. Bora opens Watch
        ↓
Watches a controlled gardening video
        ↓
Completes immediate and later recall
        ↓
Completes safe medicine routine recall
        ↓
Metrics remain available offline
        ↓
Firebase later synchronizes summaries
        ↓
Caregiver dashboard shows trends
```

The launcher and Memory Passport already provide the beginning of this story.

## 19. Working principles for future implementation

- Read `docs/PRD.md` before changing architecture.
- Keep Flutter responsible for UI and product logic.
- Add Kotlin only for genuine Android system requirements.
- Build one working slice at a time.
- Preserve working modules and device behaviour.
- Use the simplest design that supports the defined requirements.
- Avoid unnecessary state-management frameworks, services, databases, or AI infrastructure.
- Keep privacy statements and medical wording accurate to what has actually been tested.
- Run tests, analysis, an Android debug build, and a phone smoke test after each meaningful increment.
- Update this file and `README.md` when implementation status changes.


## 6 September 2026 — hybrid stack implementation
See STACK_IMPLEMENTATION.md and MODEL_ASSETS.md for the current implementation and remaining setup. Validation: 56 tests passed, analyzer clean, debug build successful, installed on RMX3868 and process running. Cloud project is unconfigured; live voice and cloud validation remain pending. Offline stack changes are local and have not been pushed to GitHub.

