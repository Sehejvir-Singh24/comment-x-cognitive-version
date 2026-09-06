# Saathi — AI Cognitive Companion

Android cognitive launcher built in Flutter/Dart, with Kotlin for Android system integration.

Current features: HOME launcher, installed-app navigation, editable local Memory Passport, Family Recognition, Video Recall, and Talk to Saathi. The September stack update adds Drift persistence, English offline speech, deterministic offline replies, and optional Firebase AI Logic and background uploads.

See [STACK_IMPLEMENTATION.md](STACK_IMPLEMENTATION.md) for current scope, setup and known limitations. Earlier milestones in PROJECT_CONTEXT.md are historical; the latest addendum takes precedence. The original PRD remains in docs/PRD.md.

## Run
From patient_app, use the project-local Flutter executable:
```powershell
& '..\.tools\flutter\bin\flutter.bat' pub get
& '..\.tools\flutter\bin\flutter.bat' analyze
& '..\.tools\flutter\bin\flutter.bat' test
& '.\run-on-phone.ps1'
```

A fresh checkout needs English model assets first: run scripts/fetch-voice-models.ps1 from the repository. See MODEL_ASSETS.md before redistribution.

Cloud features default off and need Firebase configuration. Use run-on-phone.ps1 -CloudConfig cloud-config.local.json after following STACK_IMPLEMENTATION.md. Do not supply a raw Gemini secret.

## Latest validation
6 September 2026: 56 tests passed; Flutter analysis clean; Android debug APK built and installed on authorized RMX3868. App process remained running and no matching startup fatal error appeared in the sampled logs. Live voice quality, performance and configured Firebase integration remain to be verified. Universal debug APK is 384,564,959 bytes, including voice assets and multiple native architectures; this is not a release-size benchmark.

## Device checks
- Confirm HOME navigation, Passport data and existing photos still work.
- In Talk to Saathi, keep online replies off. Tap to speak, allow microphone access and say “Open Family”; tap Finish speaking. Check recognition and navigation.
- Ask a saved-family question and check the spoken reply. Stop speaking should interrupt playback.
- Background the app during speech and verify microphone/playback stop.
- Complete a video and both immediate questions; delayed recall should become available after five minutes.
- Check large system text and airplane-mode operation.

