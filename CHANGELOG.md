# Changelog

All notable changes to **Aura Music** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-26

### Added

- **Folder-based offline library:** Automatic scanning of `Music/AuraMusic` on Android (`~/Music/AuraMusic` on Linux) where each subfolder becomes a playlist with emoji support, plus creating folders, picking a custom root directory, and manual library rescanning.
- **Home screen:** Paginated 3 × 3 quick-access grid (Liked Music, folder playlists, *Recently Added*, *Most Played*, and top-artist mixes), quick playlist chips, and *Recently Played* horizontal strip.
- **Search:** Instant accent- and case-insensitive search across songs, artists, folders, and playlists, with persistent recent searches (up to 10) and shortcuts to auto-generated playlists.
- **Library & Songs views:** List and grid layouts for playlists, sorting by name or track count, full-width 2 × 2 playlist collage header with play/shuffle/enqueue/delete folder actions, and *Songs* view with real folder filter chips and sorting by title, artist, or duration.
- **Liked Music:** Persistent *Música que te gustó* playlist stored locally (`LibraryStateStore`) with folder filter chips.
- **Fullscreen player & mini player:** Background gradient derived from track cover art (`artworkBackgroundColor`), *Me gusta* and *Guardar* pill actions, shuffle, repeat / repeat one, interactive progress bar, *Up Next* queue management, and persistent mini player above the bottom navigation bar.
- **Synchronized lyrics:** Local `.lrc` / `_private.lrc` loading (with fuzzy folder matching) plus automatic LRCLIB lookup (`LrclibFetcher`), offline caching, active-line highlighting, and tap-to-seek.
- **YouTube downloads:** Link analysis for individual tracks and public/unlisted playlists (`PlaylistFetcher`), destination folder selector, FIFO `DownloadJob` queue with progress tracking, cancel, retry failed, clear finished, and background lyrics prefetching.
- **Filename & tag parsing:** Automatic `Artist - Title (Official Video) ft. X` separation and UTF-16BE ID3 mojibake repair (`MetadataTextFixer`).
- **Background playback & desktop support:** Android `MediaSession` foreground notification (`AuraAudioHandler` with cover art, seek bar, repeat, and favorite controls) and Linux desktop playback via GStreamer (`gst-play-1.0`) with MPRIS D-Bus controls (`LinuxMprisService`).
- **A·Play brand & release readiness:** Custom *A·Play* logo, adaptive/monochrome Android 13+ launcher and notification icons, `AppTheme` OLED dark design tokens, release APK signing configuration, and GPLv3 licensing.

### Fixed

- **Letterbox bars on cover art:** Automatically crops black top and bottom bars from 4:3 YouTube thumbnails when saving new downloads and normalizing existing cached covers (`removeLetterbox` / `normalizeArtworkDirectory`).
- **Lost likes on restart:** Persisted favorites, play counts, play timestamps, and recent searches atomically in `library_state.json` so *Liked Music* survives app restarts.
- **«Artista desconocido» in the UI:** Removed unknown-artist fallback labels from player, mini player, tiles, and home cards using `song.hasKnownArtist` and parsed filename artists.
- **Playback CPU performance:** Reduced CPU usage while playing audio from 86% to ~13–24% by isolating position updates in `ValueListenable`, caching derived playlists, scanning tags/covers in a background isolate, decoding covers at display size, and removing redundant per-second `MediaSession` broadcasts.
- **Duplicate songs in auto playlists:** Deduplicated repeated tracks (by YouTube video ID across folders) in *Recently Played*, *Most Played*, and *Recently Added* lists.
