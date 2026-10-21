# Verification record — Flask architecture

Current product: Flutter Android frontend + Flask backend. The user explicitly chose this architecture on 2026-10-20. The old on-device conversion implementation and its bundled Python/FFmpeg dependencies were removed.

- Flutter 3.44.6 / Dart 3.12.2; Android SDK 36.1; Pixel 9 ARM64 emulator on Android 37.1.
- `dart analyze`: no issues after the HTTP client/settings changes.
- `pytest -q`: 41 backend tests pass. Includes legacy website regression tests, v1 metadata/URL validation, optional bearer auth, real FFmpeg conversion of synthetic audio, cancellation and SQLite restart recovery.
- `flutter test`: 18 unit/widget tests pass, including URL host validation, serialization, combined library filters, duration/date boundaries, navigation, search/categories, and large-text light/dark layouts.
- `integration_test/youtube_test.dart`: passes. Android Flutter HTTP client connects to Flask at emulator host 10.0.2.2:5051, fetches a real public clip, queues server conversion, streams MP3 and verifies the complete file on the phone.
- `integration_test/offline_test.dart`: passes with the new backend client. Library opens with no active server jobs, edits/categories/import receipts persist, a real local MP3 plays/seeks/pauses, themes switch, and deletion cannot be undone by repeated history imports.
- Flask is running locally on port 5051. A pre-existing service on port 5050 was left running.
- The release build preserves JNI coroutine classes used by the settings plugin. Release first launch, real lookup, MP3 download and durable library import pass. A release-only playback notification resource issue was found during manual verification; `res/raw/keep.xml` now retains the dynamically named music icon, per the [audio_service setup documentation](https://pub.dev/documentation/audio_service/latest/index.html). The rebuilt release plays the local downloaded MP3 successfully; Android media-session diagnostics report PLAYING, correct title/artist and a valid notification. A final replay-state adjustment now displays Play after completion and restarts the current song; its final release screenshot confirms the completed-state Play control. Pressing Play successfully restarts the same local file; Android media diagnostics again report PLAYING with advancing position.
- Screenshots are captured using adb from Android, never from a browser. Old startup-error captures are diagnostics of previous builds, not approval evidence.

## Deliverable — v0.1.0 historical build

- ARM64 Android 8.0+ personal release APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 20,166,724 bytes (20.2 MB decimal). Development signing key, documented in mobile README.
- SHA-256: `afe9812885efd49d4d9692ea6d36714dba8391d9b12b4533221b7fedcc9a9a17`.
- Native APK library inventory contains Flutter, Dart JNI and settings datastore libraries only; no bundled Python/yt-dlp/FFmpeg engine.
- After the replay-state adjustment, all 18 Flutter tests pass again and Dart analysis is clean.
- Native captures inspect Pixel 9 phone size in both themes, real downloaded content, mini/full players and settings/server controls at 130% text scale. No tablet/hardware performance claim is made.
- Design documentation handoff completed: actual native tokens in DESIGN.md and schemaVersion 2 sidecar, PRODUCT.md and surface brief aligned with Flask architecture.

## Finish review

- Independent reviewer disposition: **ship**, scoped to the nine Pixel 9 native phone captures, sampled Flutter code and supplied test evidence. No material fixes required. Physical-device gestures/refresh performance were not independently measured.
- Final replay capture is `player-dark.png`; completed position shows Play. Emulator display recovery required a cold restart with software rendering; persisted library remained intact. Font scale restored to 1.0.

## Settings refinement — v0.1.1+2

- Flask API backend now leads Settings, with Flask API URL clipboard paste, base-URL guidance, optional key and Save & test connection. Keyboard insets keep the form scrollable; connection status is an accessibility live region.
- 18 Flutter tests pass and Dart analysis is clean after the change. Release APK builds and installs successfully.
- Actual release Settings → Save & test connection reports Connected · MP3 conversion is ready against the existing Flask server. Dark/light screenshots: backend-settings-v011-dark.png, backend-connection-v011-dark.png, backend-settings-v011-light.png. This narrow refinement does not claim a fresh independent whole-app review.
- Current APK SHA-256: `6819a17c78b94b39dcf2f58fd8df90027ddd8f0945574b3cbe41db1fbc430e86`. Current deliverable remains `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
