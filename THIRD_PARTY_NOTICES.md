# Bundled Android runtime

- youtubedl-android library/FFmpeg 0.18.1: https://github.com/yausername/youtubedl-android/tree/0.18.1 (GPL-3.0; license included in APK assets).
- yt-dlp zipapp: official release URL and SHA-256 in tools/bundled-engine.json. https://github.com/yt-dlp/yt-dlp (Unlicense; license included in APK assets). The upstream bundled Python, QuickJS and FFmpeg payloads retain their upstream licensing; corresponding source/build information is linked from the Android wrapper repository.
- WebP compatibility payload: libwebp 1.6.0, https://chromium.googlesource.com/webm/libwebp/+/refs/tags/v1.6.0. Source archive and SHA-256 pinned in tools/rebuild_webp.py. Built with Android NDK 28.2.13676358, ARM64 Android API26, Release shared libraries and max-page-size=16384. COPYING and PATENTS are included in APK assets. These five replacement libraries are unmodified upstream source, relinked for 16 KB memory pages.

Reproduction commands are documented in README.md. Runtime assets are binaries, not generated artwork.
