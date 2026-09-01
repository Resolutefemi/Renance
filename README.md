# Renance — the global student study OS

One repository, one product. Students register with **username + password
only**, tell us who they're studying for in a 30-second profile modal, and
Renance silently syncs past questions, notes and syllabi to their device,
then grades their mock exams server-side on a goroutine engine.

| Piece | Where | Status |
|---|---|---|
| Go study API (`apps/study-api`) | auth · profiles · pack manifest · goroutine CBT grading · background sync worker | **ACTIVE** |
| Web app (`apps/web`) | onboarding · dashboard · CBT player · Renance logomark animation | **ACTIVE** |
| Flutter shell (`apps/mobile`) | offline-first mobile client (packs into local SQLite) | G3 — APK built in CI |
| Legacy NestJS monolith (`legacy/nestjs-monolith/`) | ERA-1 code, frozen, pending extraction to vertical repos | read-only |

Stack: Go 1.27 · pgx/v5 · Neon Postgres (`study` schema) · Next.js 15 ·
Tailwind 4 · Flutter 3.47/Dart 3.13 · Python content pipeline ·
GitHub Actions (APK builds + GitHub Pages deploys).

**Standing law — ADR-0003 content split:** question bundles never contain
answer material; answer keys are server-only (`study.answer_keys` +
gitignored `data/answer-keys/`); `data/manifest.json` carries sha256
fingerprints verified at boot; explanations surface only after grading.

## Quickstart

Prereqs: Go 1.27+, Node 22+, pnpm 10, Python 3 (content rebuilds only).

```bash
# 1) web deps
pnpm install

# 2) database — paste your Neon connection string (or any Postgres)
export DATABASE_URL="postgresql://…/renance?sslmode=require"

# 3) Go API on :3990 (migrates the study schema on first boot)
pnpm api:dev

# 4) web on :3000
pnpm web:dev
```

Register → complete the profile modal → watch the sync strip fill →
open a pack and sit the mock. That's the whole loop.

## View it — no local setup

Both clients ship through GitHub Actions on every push to `main`.

**Website (GitHub Pages):** https://resolutefemi.github.io/Renance/

One-time enablement if Pages has never been used on the repo:
`Settings → Pages → Build and deployment → Source: GitHub Actions`.
The `web-deploy` workflow then publishes the static export on the next
push (or re-run it from the Actions tab).

**Android app (APK):** open the repo's **Actions** tab → pick the latest
**mobile-apk (Android)** run → under **Artifacts** download
**renance-android-apk** → sideload it on the phone (allow installs from
that source). Pushing a tag like `v0.1.0` additionally attaches the APK
to a GitHub Release.

**Pointing both clients at a live API:** the website and APK read the API
address from the repo variable `PUBLIC_API_BASE`
(`Settings → Secrets and variables → Actions → Variables → New repository
variable`). Set it to your deployed Go study API URL — it must be
**https** for the Pages site (browsers block http from an https origin).
Until then the site renders and the app defaults to the Android-emulator
loopback (`http://10.0.2.2:3990`), which reaches a locally running
`pnpm api:dev`.

## Content pipeline (mock now, real banks in G2)

```bash
pnpm content:build      # data/src/mock/*.json → bundles + keys + manifest
go -C apps/study-api test ./...
```

Source banks (with answers) live in `data/src/`; the build emits
student-safe bundles to `data/questions/`, keys to
`data/answer-keys/` (gitignored except the mock set), and fingerprints
everything into `data/manifest.json`. When the real 8,679-question banks
arrive they drop into `data/src/real/` (never committed) and the same
command does the rest — adapters cover every shape found in the wild.

## Docs

`docs/ACTIVE_PHASE.md` is the single source of progress. Decisions live in
`docs/decisions/` (ADR-0003 content doctrine, ADR-0004 Go pivot). ERA-1
history: `docs/ACTIVE_PHASE.md` header + `legacy/nestjs-monolith/`.
