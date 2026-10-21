# oto for Android

Paste a YouTube or YouTube Music video link, save an MP3 on the phone, and listen offline. The Flutter app now runs extraction and conversion entirely on Android. No Flask server address is needed.

- Home, Downloads and Library, with a native background-download notification.
- 128/192 kbps MP3, progress, cancellation, retry and persistent job history.
- Offline player with Android media controls, a queue, shuffle and repeat.
- Search, favorites, custom categories, artist/date/duration filters and sorting.
- Light, dark and system themes; MP3 export through Android's document picker.

## Build and run

Use Flutter 3.44+/Dart 3.12+, JDK/Android SDK and an **ARM64 Android 8.0+** device.

```sh
flutter pub get
flutter run -d <android-device-id>
flutter build apk --release --split-per-abi --target-platform android-arm64
```

Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. This personal build uses the local development signing key; keep that key to install future updates over the same app. Existing phone songs, categories and favorites stay in their current SQLite library. If engine initialization fails, saved music can still open and play. Older pending server downloads become interrupted jobs that can be retried locally.

The first launch unpacks the bundled runtime into private storage. New downloads need internet, but saved music plays offline. Videos must have a known duration up to 20 minutes; playlists, live/upcoming streams and sign-in-restricted videos are unsupported. Source availability can change.

## Background behavior and storage

An Android foreground service owns the download queue, independently of Flutter screens. You can leave oto while a download runs. Allow notifications to see progress and cancel from the notification. Normal app navigation or dismissing its recent-app card does not intentionally cancel the queue. Android force-stop, reboot, process death or service limits can interrupt work; open oto and tap Retry. Interrupted partial files are removed on recovery; downloads retry from the start.

MP3s become library items only after successful conversion and final local-file rename. Library import receipts prevent deleted songs from reappearing from old history. Dismissing completed download history keeps the library file. Files stay private unless exported; uninstalling oto deletes its private library.

## Engine updates

Settings → Downloads on this phone shows the installed engine version and **Check for engine updates**. The app checks the official yt-dlp stable release, downloads its published SHA-256 checksum and verifies the zipapp before atomically replacing the installed engine. Connection/read timeouts and size bounds protect the update path, and active downloads must finish or be cancelled before updating. Runtime/FFmpeg updates still require a new APK.

The current official yt-dlp release is also bundled so a fresh install can start without a preliminary update. To refresh that packaged release before building:

```sh
python3 tools/bundle_engine.py
```

## Native runtime and 16 KB pages

`youtubedl-android` library/FFmpeg 0.18.1 supplies Python, QuickJS and FFmpeg. Its five bundled WebP libraries need rebuilding for newer Android devices with 16 KB memory pages. This app includes ARM64 libwebp 1.6.0 replacements built from pinned official source; initialization copies them into FFmpeg's private library directory before conversion.

Rebuild those five files with Python 3.12+, Android NDK 28.2.13676358 and SDK CMake 3.22.1:

```sh
python3 tools/rebuild_webp.py --sdk /path/to/android/sdk
```

The script verifies the archive SHA-256 and every ELF LOAD segment's alignment/congruence. Source URLs, checksums, options and license notices are included in `tools/` and `android/app/src/main/assets/licenses/`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The APK is ARM64 only; other ABIs need their own compatible runtime builds and verification.

## Source and checks

- `lib/data/download_bridge.dart`: typed Flutter method-channel client and one-time server-history migration.
- `lib/data/repository.dart`: local library and transactional import receipts.
- `lib/controller.dart`, `lib/ui/`: existing player/library plus native engine controls.
- `android/app/src/main/kotlin/com/oto/oto/`: engine, persistent job store, foreground download service and document export.

```sh
flutter analyze
flutter test
flutter test integration_test/youtube_test.dart -d <android-device-id>
flutter test integration_test/download_lifecycle_test.dart -d <android-device-id>
flutter test integration_test/offline_test.dart -d <android-device-id>
```

The network test downloads a short public clip without a backend, verifies its MP3 header, lets Android decode it and imports it into the library. Override the clip using `--dart-define=OTO_TEST_URL=<video-url>`. Lifecycle tests cover URL validation at the native boundary, legacy migration, cancellation and dismissal; offline tests use explicitly synthetic audio for persistence/player checks. Test fixtures do not ship in the normal APK.
# Oto
