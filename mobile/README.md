# Grandvoice (Flutter app, Android + iOS)

Speak your day. Family stays close.

## Run

```bash
flutter pub get
flutter run            # with an Android phone plugged in (USB debugging on)
```

Speech-to-text uses the phone's own recognizer, so test talking on a **real phone**.
Emulators usually have no working microphone.

iOS builds need a Mac with Xcode (`flutter run` on an iPhone from macOS).

## Demo tips

- Sign in with any password. `rosa.m@example.com` opens Rosa's diary,
  `david.m@example.com` opens the family app.
- The `...` button on Rosa's Home and David's People screen switches phones,
  shows each lock screen, or resets the demo data.
- Everything is saved on the phone (shared_preferences), so Rosa's and David's
  screens stay in sync on one device.

## What is real

- Live speech-to-text while talking (`lib/services/speech_service.dart`). It keeps
  listening through pauses until "I'm done".
- Journal entries saved with their real date and time, grouped by day, searchable,
  share/private toggle, delete (`lib/screens/diary/journal_tab.dart`).
- Medicine and calendar updates picked out of what she said by keyword rules
  (`lib/services/extractor.dart`). Swap in a FastAPI + Claude call later.
- Life Story recordings saved to "My book", read-aloud (TTS) and voice replies from family.

## Layout

```
lib/
  main.dart               app start
  theme.dart              colours, fonts, shared widgets
  models.dart             data classes
  state/app_state.dart    all data + saving (replace with API calls for a backend)
  services/               speech, text-to-speech, extractor
  screens/onboarding.dart splash, sign in, sign up (diary + family)
  screens/diary/          Rosa: Talk, Listening, Review, Journal, Today, Circle, Life Story
  screens/family/         David: People, Updates, Health
  screens/demo/           lock-screen notification previews
```
