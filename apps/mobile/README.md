# Renance Mobile (Flutter)

Target surface of Phase 2 CBT/Study MVP (see docs/ACTIVE_PHASE.md).
The folder is intentionally thin in Phase 0 — Flutter scaffolding is done by
the official generator so you always start from an up-to-date template.

## Bootstrap (one-time)

Prereqs: Flutter SDK stable channel + Android Studio/Xcode toolchains.
Run `flutter doctor` first; fix anything red.

```bash
cd apps/mobile
flutter create . \
  --org com.renance \
  --project-name renance \
  --platforms android,ios
flutter run
```

Then `flutter pub add dio` (API client) when Phase 2 coding starts.

## Hard constraints carried from PRD / roadmap

- Install size budgets: Android < 55MB, iOS < 65MB.
  - no bundled question banks — pull from api + cache
  - images go through Cloudflare R2 public bucket, never assets/
- Auth must reuse Core identity tokens (Phase 1), no parallel auth system.
- Deep links (`renance://` scheme) arrive with Phase 2 exam sharing.
