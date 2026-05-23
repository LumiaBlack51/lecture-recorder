# Lecture Recorder

Lecture Recorder is a Flutter app for Android, Windows, and Linux that provides one-tap course-based recording, automatic segmentation, bilingual Chinese and English UI, and a recordings manager for playback, sharing, deletion, and folder access.

## Highlights
- One-tap recording from customizable course buttons.
- Android background recording through a foreground service notification.
- Automatic segmentation:
  - Android by file size.
  - Desktop by segment duration.
- Settings for language, audio quality, segmentation, and course management.
- Recordings list with playback, sharing, deletion, refresh, and open-location actions.
- Public Android storage under `Music/Recordings/Lecture Recorder`.
- English and Simplified Chinese user interface.

## Default Sample Data

The public repository uses neutral sample course names:
- `Course 01`
- `Course 02`
- `Course 03`
- `Course 04`
- `Course 05`

You can rename or replace them from the in-app settings screen.

## Platform Behavior

### Android
- Records to AAC/M4A.
- Uses a native `MediaRecorder` implementation.
- Keeps recording in the background with a foreground-service notification.
- Requests microphone, notification, and storage-related permissions as needed.
- Notification shows recording progress and exposes pause and stop actions.

### Windows and Linux
- Records to AAC/M4A through the desktop recording backend.
- Supports time-based segmentation.
- Can open the recording folder directly in the platform file manager.

## Storage
- Android: `Music/Recordings/Lecture Recorder/<course-name>/`
- Windows/Linux: app documents directory under `recordings/<course-name>/`

## Tech Stack
- Flutter
- Riverpod
- Native Android `MethodChannel` and `EventChannel`
- Shared preferences for settings persistence

## Development

### Requirements
- Flutter stable `3.41.4` or later
- Dart `3.11`
- Android SDK
- Windows or Linux desktop Flutter tooling
- Linux packaging tools: `libgtk-3-dev`, `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`, `libpulse-dev`, `libasound2-dev`, `lld`, and `fakeroot`

### Setup
```bash
flutter pub get
flutter doctor
```

### Run
```bash
flutter run -d windows
flutter run -d linux
flutter run -d <android-device-id>
```

### Build
```bash
flutter build windows
flutter build linux --release
flutter build apk --release
```

### Linux Debian Package
```bash
scripts/package_deb.sh
```

## Validation

Recommended checks:

```bash
flutter analyze
flutter test
```

The app has also been verified on a connected OnePlus Android device for:
- app launch
- permission flow
- start and stop recording
- background recording continuity
- foreground notification display
- recordings visibility in shared storage

## Repository Notes
- Source code, identifiers, and implementation are English-only.
- User-facing copy is localized through ARB resources.
- The public repository intentionally uses neutral sample course names and excludes local prompt files, personal paths, and test recordings.
