# Hybrid stack implementation — 6 September 2026

Work folder: D:\projects\comment x cognitive version

## Implemented
- Flutter patient UI and Dart cognitive logic; Kotlin remains the Android system bridge, including validated internet detection.
- Drift/SQLite local repositories and transactional legacy JSON import. Source JSON files remain recovery copies. Malformed legacy data blocks import instead of silently replacing patient data.
- UUID exercise records; repeated writes of identical records are idempotent. Video recall waits five minutes, retains pending videos, and presents successive immediate questions.
- Android's standard Google speech recognizer handles English (UK) speech-to-text with the offline preference enabled. If the phone has no offline pack, Google may process speech remotely. Piper speech generation remains in a worker isolate. Tap-to-speak, a stop-speaking control and background cancellation are included.
- Deterministic offline assistant with screen navigation and selected Passport facts. Gemini uses Firebase AI Logic with separate online consent, small context selection, timeout fallback and visible mode.
- Separate cloud-upload consent, durable SQLite outbox, owner-bound Firestore writes and periodic WorkManager retries. Photos and microphone audio are excluded from the upload payload.

## Cloud setup still required
The checked-in default build is offline. No Firebase project was selected or provisioned.
1. Register Android package org.saathi.patient_app in your chosen Firebase project.
2. Enable Anonymous Authentication and Firebase AI Logic with the Gemini developer backend.
3. Configure App Check: debug registration for development and Play Integrity for distribution; enforce protection in Firebase.
4. Create Firestore and review/deploy firebase/firestore.rules with your project selected explicitly.
5. Copy patient_app/cloud-config.example.json to cloud-config.local.json, fill the Firebase app's public configuration, and build using --dart-define-from-file=cloud-config.local.json.
6. Enable online replies and/or cloud backup separately in Talk to Saathi.

Never include a Gemini secret or service-account credential in the mobile app.
Live Gemini, App Check, WorkManager uploads and Firestore rules have not been verified against a configured project. The uploader is outbound only; cross-device restore and caregiver account linking are not implemented. Anonymous identity is tied to the app installation. Disabling backup clears pending local uploads; it cannot recall requests already sent or remove existing cloud copies.

## Model assets
The TTS model folder is under patient_app/assets/models. Speech-to-text uses the phone's offline recognizer, so its language pack is managed in Android settings. See MODEL_ASSETS.md for model provenance and release constraints. Do not claim the suggested RAM or latency targets without device profiling.

## Remaining release validation
- Real microphone recognition and spoken reply quality, lifecycle behavior, memory and latency measurements on the target phone.
- Firebase project integration and rules/emulator checks.
- Voice-model and dependency licensing review before redistribution.
- Medical-topic keyword screening is a limited product guardrail, not a clinical safety guarantee.
- New settings are English only. No new clinical scoring, caregiver dashboard or medication features were added.

