# Agent Guide

## Product Scope
- Build and maintain a practical lecture recorder MVP for Android and Windows.
- Preserve one-tap recording, automatic segmentation, course management, and bilingual UX as the core product.
- Keep code, identifiers, comments, and architecture names in English only.

## Engineering Style
- Use Riverpod for app state and keep side effects in controllers or services.
- Keep UI code thin. Business rules belong in feature services, repositories, or controllers.
- Prefer immutable models with explicit copy methods and JSON helpers where needed.
- Keep platform-specific behavior behind `RecorderService` abstractions and platform channels.
- Choose stable, readable solutions over clever abstractions.

## Project Structure
- `lib/app`: app bootstrap, theme, routing, localization wiring.
- `lib/features/recorder`: recording session domain, services, controllers, and home UI.
- `lib/features/recordings`: file discovery, playback, deletion, and recordings UI.
- `lib/features/settings`: settings models, persistence, and settings UI.
- `lib/services`: cross-feature platform bridges and filesystem helpers.
- `lib/shared`: reusable widgets, constants, formatting helpers, and dialogs.

## UX Guidelines
- The home screen should remain focused on large course actions and clear recording status.
- Settings should expose platform-appropriate controls without overwhelming the user.
- Every destructive action needs confirmation.
- Errors should be phrased in a calm, actionable way.

## Native Integration Rules
- Android recording logic owns file-size segmentation and emits state events to Flutter.
- Windows recording uses a dedicated implementation path for time-based segmentation.
- Method and event channel payloads should be explicit maps with stable keys.
- Guard all native entry points against duplicate start and stop calls.

## Localization Rules
- User-facing strings must live in ARB files.
- Support English and Simplified Chinese.
- Keep model values and code enums language-neutral; map them to localized labels in the UI.

## Testing Expectations
- Run `flutter analyze` and relevant tests after meaningful changes.
- Validate Android behavior on the connected physical device when native recording changes.
- Validate Windows desktop build behavior locally when desktop code changes.

## Documentation
- Update `README.md` when setup, permissions, architecture, or known limitations change.
- Document platform tradeoffs honestly, especially around background recording and segmentation.
