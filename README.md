# HLA (Hyper Local Audio)

## Overview

HLA is a high-performance, local-first music player built with Flutter. It is designed to provide a seamless and visually engaging experience for managing and playing local audio libraries. The application focuses on automated metadata enhancement, synced lyrics integration, and a modern user interface.

## AI Development Note

This project was developed with significant assistance from Artificial Intelligence (I used Gemini Cli). The architecture, logic implementation, and UI components were generated and refined through AI-driven development processes, emphasizing modern Flutter best practices and efficient system design.

## Features

### Library Management
* Automated Local Scanning: Uses high-performance queries to index local audio files.
* Bento-Style UI: A unique staggered grid layout for the music library providing a dense yet organized visual hierarchy.
* Smart Categorization: Automatically groups music by artist, album, and folder structures.

### Audio Playback
* Background Execution: Full integration with system-level audio services for persistent playback.
* Gapless Playback: High-fidelity audio transitions.
* Simulated Crossfade: Custom volume ramping logic to smooth transitions between tracks.
* Native Equalizer Integration: Direct access to system-level audio effects and equalization.

### Metadata and Lyrics
* Automated Metadata Sync: Integrates with MusicBrainz and CoverArtArchive APIs to fetch missing album artwork and track information.
* Lyrics Integration: Support for both plain text and synchronized (LRC) lyrics fetched from lrclib.net.
* Local Caching: Metadata and lyrics are cached locally to ensure offline availability and reduced API overhead.

### UI/UX Design
* Multi-Directional Navigation: A custom navigation system allowing horizontal and vertical transitions between major application sections.
* Global Mini-Player: A persistent playback controller that transitions into a full-screen Now Playing view via gesture-based interactions.
* Theme Support: Comprehensive light and dark mode implementations.

## Platform Support

### Android
* Fully tested and functional.
* Target API level: 34 (Android 14).

### iOS
* Configuration files (Info.plist, Background Modes) are implemented.
* Note: The iOS version is currently **untested** as development was performed without access to physical iOS hardware.

## Downloads

### Stable Releases
For the most stable version of HLA, visit the [Releases](https://github.com/batchnode/hla-music-player/releases) page. From there, you can download the latest production-ready APK for Android.

### Development Builds
You can also access the latest automated builds through GitHub Actions:
1. Navigate to the [Actions](https://github.com/batchnode/hla-music-player/actions) tab.
2. Select the most recent successful "Android CI" workflow run.
3. Scroll down to the **Artifacts** section at the bottom of the page to download the `app-release-apk`.

## Technical Architecture

### Framework and State Management
* Flutter SDK: The core framework for cross-platform deployment.
* Provider: Used for reactive state management across the music library, player state, and user settings.

### Audio Engineering
* just_audio: Used as the primary audio engine for its feature-rich API and performance.
* audio_service: Implemented to handle background tasks, media notifications, and lock screen controls.

### Data Persistence
* sqflite: A local SQLite database manages song metadata, play statistics, and cached resource paths.
* shared_preferences: Handles lightweight user configuration and application settings.

### API Integrations
* MusicBrainz: Primary source for track and album metadata.
* CoverArtArchive: Source for high-resolution album artwork.
* LRCLIB: Provider for synchronized and plain-text lyrics.

## Getting Started

### Prerequisites
* Flutter SDK (Stable channel)
* Android SDK (for Android builds)
* Xcode (for iOS/macOS builds)

### Installation
1. Clone the repository:
   git clone https://github.com/dodo/hla-music-player.git

2. Navigate to the project directory:
   cd hla-music-player

3. Install dependencies:
   flutter pub get

4. Run the application:
   flutter run

## Building for Production

### Android
To generate an optimized Release APK or App Bundle:
flutter build apk --release
or
flutter build appbundle --release

### iOS
To prepare the iOS build:
flutter build ios --release

## License

This project is licensed under the MIT License - see the LICENSE file for details.
