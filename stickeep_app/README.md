# stickeep_app

The Flutter app half of Stickeep — an accessible seat-reservation
system for Technion classrooms. Deployed at
[stickeep.web.app](https://stickeep.web.app).

See the repo root [`README.md`](../README.md) and
[`../Documentation/`](../Documentation) for the full project
description, architecture, and connection diagram — this file only
covers running the app itself.

## Running locally

```
flutter pub get
flutter run -d chrome
```

## Building/deploying

```
flutter build web
firebase deploy --only hosting
```

## Structure

- `lib/screens/student/` — booking flow, QR/NFC arrival confirmation,
  reservation history.
- `lib/screens/admin/` — classroom/seat management, user search,
  approvals.
- `lib/screens/settings/` — accessibility settings (dark mode, high
  contrast, colorblind-safe palette, text size).
- `lib/theme/` — `AppColors`/`AppTheme` (all screens read colors
  through these instead of hardcoding them, so accessibility toggles
  apply app-wide) and `AccessibilityController`.
- `functions/` — Cloud Functions the ESP32 hardware calls (it has no
  Firebase Auth of its own).
