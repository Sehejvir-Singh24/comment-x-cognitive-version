# English development models

The app bundles an English speech-generation model. Fetch it locally with scripts/fetch-voice-models.ps1 before building a fresh checkout. It comes from the k2-fsa/sherpa-onnx TTS release:
- tts-models/vits-piper-en_US-lessac-medium.tar.bz2

scripts/model-checksums.json records SHA-256 checksums of every bundled asset from the development download. The script validates the extracted files against that manifest. This verifies reproducibility; it does not establish upstream licensing or authenticity independently.

Speech-to-text uses Android's on-device recognizer with an offline language pack. pubspec.yaml includes the TTS model/support files. Git ignores downloaded model folders. Runtime copies TTS assets to private app storage on first voice reply.

Keep the upstream MODEL_CARD, model configuration and license notices with any redistributed model. The Lessac model card links to the Blizzard 2013 dataset license: https://www.cstr.ed.ac.uk/projects/blizzard/2013/lessac_blizzard2013/license.html . Redistribution and commercial suitability have not been cleared. Review model, dataset, eSpeak and native dependency licenses before a release. These models are development choices; no Indic pack has been added.

The selected TTS model is approximately 63 MB before support data and native libraries. Android manages the speech-recognition language pack separately. APK size, RAM usage and recognition latency require measurement on the target phone.

