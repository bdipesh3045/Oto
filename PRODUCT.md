# oto for Android
<!-- impeccable:product-schema 1 -->

## Platform
android

## Stack
Flutter and Dart for Android. Kotlin runs a bundled yt-dlp/Python/QuickJS extractor and FFmpeg locally through youtubedl-android. An Android data-sync foreground service owns the persistent download queue; native SQLite stores jobs and Flutter SQLite stores the music library. No Flask connection is used by the app.

## Users
One personal Android user saving YouTube audio as MP3 and listening offline.

## Product Purpose
Paste a YouTube link, download an MP3, find it in the app library, and play offline without a YouTube player.

## Capabilities and Constraints
Home, Downloads, Library. Search, custom categories, favorites, artist/date/duration filters and sorting. A compact player opens full playback with a queue, shuffle and repeat. Light, dark and system appearance. The library is inside the app, not a home-screen widget. The user approved switching to entirely on-device downloads and conversion after using Flask. Downloads continue in a foreground service when the user leaves oto; cancellation, retry and durable job history are supported. Android force-stop/reboot/process death can interrupt a job; reopen and Retry. Existing local songs/categories/import receipts remain compatible, and pending server history migrates to retryable interrupted jobs. Completed MP3s/artwork play offline. New downloads and engine updates need internet. Settings offers default quality, storage information and an engine updater with SHA-256 verification. Individual videos up to 20 minutes, 128/192 kbps MP3, no playlists/live/restricted sign-in videos. Export MP3 uses Android's document picker. Personal APK targets ARM64 Android 8.0+; bundled WebP libraries are built for 16 KB memory pages.

## Brand Commitments
Inherit the existing oto identity from ../backend/templates/index.html and ../backend/static/style.css: quiet typography, warm light surfaces, indigo dark surfaces, red accent. Adapt the system to Material 3 Android controls.

## Accessibility & Inclusion
System font scaling, 48dp touch targets, accessible control labels, reduced motion, system Back, and safe insets.
