# renance-mobile (Flutter)

The offline-first mobile shell of the Renance study OS (ERA-2 Gate G3).
Talks to the same Go study-api as the web app — same JWT, same doctrine.

## What it does

1. **Splash** — animated Renance logomark (CustomPainter: breathing tile +
   chasing orbit arcs). No spinners anywhere in this app, per founder rule.
2. **Register** — STRICTLY username + password (two fields, matching the
   current product doctrine; the old email-field mockups are superseded).
3. **Profile modal** — non-dismissable sheet: full name, target institution,
   grade level, active examinations (JAMB / WAEC / NECO / University Modules).
4. **Silent asset sync** — the moment the profile lands, the app pulls the
   packs matching the student's exams into **local SQLite** (`packs` table,
   sha-pinned so republished versions refresh). Founder rule honored:
   *the phone downloads only what you need; the web has everything.*
5. **Offline CBT** — timer, palette, flags; works in airplane mode from the
   cached bundle. Submitting offline stores the paper in a
   `pending_submissions` queue; `SyncController.retryPending()` flushes it
   on app resume (and via the banner's Retry button). Server keys stay
   sealed — grading is always server-side.
6. **Results** — percentage + per-topic breakdown bars.

## Run it

```bash
# from repo root: start the Go API
pnpm api:dev

# Android emulator (10.0.2.2 = your host machine)
flutter run --dart-define=RENANCE_API_BASE=http://10.0.2.2:3990

# iOS simulator
flutter run --dart-define=RENANCE_API_BASE=http://localhost:3990

# release binary (needs the Android SDK on your machine)
flutter build apk --release --dart-define=RENANCE_API_BASE=https://api.renance.dev
```

## Layout

```
lib/
  config.dart      api base via --dart-define (default: emulator loopback)
  models.dart      API contract mirrors (defensive parsing)
  api_client.dart  http client; injectable Client for tests
  storage.dart     SessionStore (prefs) + DbPackStore (sqflite) + memory fake
  controllers.dart SyncController + ExamController (pure, testable)
  ui/              theme (founder mockup palette), logo, splash, auth,
                   onboarding sheet, home, exam player
```

## Verification

```bash
flutter analyze   # 0 issues
flutter test      # 26 tests: models, API client (MockClient), sync
                  # need-based filter, offline queue, exam state machine
```

Device runs and Play Store builds happen on the founder's machine (the
paired sandbox has no Android SDK); `flutter create` already generated the
android/ and ios/ platforms.
