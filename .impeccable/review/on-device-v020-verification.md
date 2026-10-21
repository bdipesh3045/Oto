# On-device Android verification — v0.2.0

The user approved the standalone Android plan and instructed implementation. This supersedes the Flask-dependent mobile builds; backend/ remains independent.

## Automated evidence

- Dart analysis: no issues.
- Flutter unit/widget suite: 18 pass, including composed library filters and compact 360dp light/dark layouts at 130% text scale.
- Real Android network integration: passes with the bundled yt-dlp 2026.08.19 and source-built libwebp 1.6.0 compatibility payload. No Flask initialization or HTTP server is used. A public short clip becomes a complete MP3; header bytes are ID3, Android's audio decoder reports a positive duration, and the library imports it.
- Android lifecycle integration: passes. Older queued server records migrate to interrupted jobs, legacy HTTP DB is retired, native URL boundaries reject non-YouTube/file/playlist URLs, invalid quality is rejected, cancellation persists, and dismissed history stays dismissed after reinitialization. Engine update check returns the current version.
- Android offline integration: passes. Synthetic local MP3 playback/seeking/pausing, SQLite edits/categories/favorites, themes, import receipts and deletion remain functional.
- Device: Pixel 9 ARM64 emulator, Android 37.1 with 16 KB memory pages. Physical hardware gestures and refresh performance are outside this evidence.
- Binary checks: all five source-built ARM64 WebP ELF LOAD segments meet 16 KB alignment and congruence. Bundled engine SHA-256 matches its manifest. Source/build scripts and license notices are present.

## Release verification

- ARM64 release APK builds and installs, 63,863,917 bytes (63.9 MB decimal).
- SHA-256: `bf95b6a40f6efe412fb41e8740830741bfce36b7aa94cdcd3f08a2ab6ce69f9f`.
- Initial R8 ZIP-constructor failure was traced to Commons Compress reflection and fixed with ZIP keep rules. Library initialization is now independent of engine startup; recoverable native initialization errors return through the method channel instead of crashing the app.
- Corrected release cold launch and Home rendering pass on the 16 KB emulator. Bundled yt-dlp is present in the optimized APK and its byte hash matches the official manifest. APK ABI inventory is ARM64 only.
- Release metadata lookup succeeds with real title/artist/duration. Starting Download MP3 then pressing Android Home leaves a real data-sync foreground service running (Android diagnostics: isForeground=true, foregroundId=42). The notification shows the real clip title, Downloading audio, progress and Cancel. Returning from Android Home shows the completed 192 kbps MP3 in Downloads and Library. The release player decodes it and reaches its 19-second duration. Settings reports engine2026.08.19 and the actual update check reports up to date. Both settings themes render at130% text scale. With Wi-Fi and mobile data disabled, force-stopping and cold-launching the release still loads the saved song/artwork. Tapping it produces an Android media-session state of PLAYING with advancing position (10,890 ms observed). Connectivity, text scale1.0 and the original dark appearance were restored afterward. Screenshots from earlier Flask versions are historical, not evidence for this architecture.

## Native capture set

All captures are adb screenshots of the installed release on the same1080×2424 Pixel9 phone emulator. Opened and validated before handoff. Settings use130% text scale; other app screens use100%.

- on-device-v020-home-dark.png — fresh Home, honest empty recent list.
- on-device-v020-preview-dark.png — actual metadata and download quality.
- on-device-v020-background-notification.png — real foreground download while app is outside the foreground.
- on-device-v020-downloads-dark.png — completed local download.
- on-device-v020-library-dark.png — imported real song.
- on-device-v020-player-dark.png — actual local MP3, seek, repeat/shuffle/queue and completed Play control.
- on-device-v020-settings-dark-large.png — local engine controls and version at130%.
- on-device-v020-settings-light-large.png — actual up-to-date result in light mode at130%.
- on-device-v020-library-light-offline.png — persisted library/artwork after an offline process restart.

Fresh independent finish-review disposition: **ship**, scoped to the nine supplied phone captures, sampled source and supplied verification evidence. No material UI fixes required. Documentation handoff is complete: the surface brief now records current local release evidence and explicitly marks Flask notes historical. Product/design documents and schema-2 sidecar validate; runtime source and APK are unchanged. No HTML/CSS detector ran because this is native Android.
