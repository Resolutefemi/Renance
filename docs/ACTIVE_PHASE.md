# ACTIVE PHASE — single source of progress

Update this file at the END of every coding session. Completion gates, not
dates. Rule: do not open the next gate until this one's exit criteria pass.

---

## ERA 1 — Thin Core Service (NestJS monolith)   [CLOSED 2026-09-02]

Gates 1.1 → 2.0 shipped: auth/JWT, organizations+memberships, RBAC guard
matrices, verification state machine, ownership transfer, change-password,
cbt:build content pipeline (ADR-0003), publish/manifest/fetch, server-side
grading + attempts. 79 unit + 40/40 consolidated E2E green at exit.

**DISBANDED by founder decision (ADR-0004).** The multi-module monolith
scope (school mgmt / SME / payroll verticals) moves to separate independent
repositories. Code preserved read-only under `legacy/nestjs-monolith/`
pending extraction. Neon `core.*`/`cbt.*` tables remain in place, untouched.

---

## ERA 2 — Renance Study OS (Go backend)         [ACTIVE]

One repository, one product: the global student study operating system.
Go service (`apps/study-api`) + Next.js web (`apps/web`) + Flutter shell
(`apps/mobile`, G3). Every other business vertical lives in its own repo.

Standing doctrine (carried from ERA 1, still law):
- **ADR-0003 content split**: bundles (students) never contain answer
  material; keys are server-only (DB or gitignored `data/answer-keys/`);
  manifest carries sha256 fingerprints; explanations surface only AFTER grading.
- **DDL**: structure changes land as ordered SQL migrations in
  `apps/study-api/internal/store/migrations/` — never hand-ALTER prod.
- **Offline-first**: phones download packs on demand, exam in airplane mode,
  sync + server-side grading when back online. Web loads full packs online.
- Mock sample questions are committed until the founder uploads the real
  8,679-question banks (G2).

### Gate G1 — Go walking skeleton               [CODE COMPLETE 2026-09-02]
- Go 1.27 service `apps/study-api`: stdlib mux (Go 1.22+ routing), pgx/v5
  (simple protocol, pooler-safe), bcrypt cost 12, hand-rolled HS256 JWT (12h).
- Minimal credential flow: POST /auth/register + /auth/login capture ONLY
  username + password. Contextual profile arrives post-auth via
  PUT /me/profile (full name, institution, grade level, active exams).
- `study` schema (migration 0001): users, profiles, answer_keys, attempts,
  attempt_answers, results, sync_jobs. Boot-time embedded-SQL migrator.
- cbtdata loader: manifest sha256 verification at boot; refuses to serve a
  bundle containing answer-material keys (recursive scan).
- Goroutine CBT engine: buffered job channel + worker pool grades attempts
  off-request-path (202 Accepted → poll). Retake allowed, resubmit rejected.
- Background sync worker: profile completion kicks a per-user goroutine job
  (study.sync_jobs progress rows) — the web silent-asset-sync pattern.
- Mock packs: 5 banks / 80 questions under `data/`, built by
  `tools/cbt-build/build.py` (ports ERA-1 normalize variants: BOM, 6 bank
  shapes, answer-as-letter|text, options array|record|[{letter,text,correct}]).
- Web: register/login (2 fields), non-dismissable onboarding modal, dashboard
  with live sync strip, CBT player (timer, palette, flags), results breakdown;
  Renance logomark animation replaces every spinner (Bybit-style states).
- Tests: Go unit 15 green (jwt ×5, grading ×5, cbtdata ×5) + go vet clean;
  live E2E 32/32 assertions (boot → register → onboarding → sync → manifest
  → bundle doctrine → goroutine grading EXACT score → guards → retake).
EXIT: green build + green E2E + pushed main.   [EXITED 2026-09-02]

### Gate G2 — Real content ingestion            [PENDING]
Founder uploads real banks to `data/src/real/` (never committed). cbt-build
adapters run over all 21 ERA-1-discovered shapes; keys seeded to Neon
`study.answer_keys`; bundles pushed to R2/CDN with manifest versioning;
retries + drift report. CLI bulk builder hardening (multi-threaded compile,
randomize, push — the "CLI-Driven Bulk Test Builder" feature lands here).

### Gate G3 — Flutter mobile shell              [PENDING]
Register/login → profile modal → manifest → on-demand pack download into
local SQLite → offline CBT (airplane mode) → sync queue → server grading.
Logomark animation states during fetch/grade. Play Store binary.

### Gate G4 — Learning intelligence             [PENDING]
Attempt event stream (dwell time, hesitation, revision loops) →
micro-behavioral exam forensics + score prediction; spaced-repetition
forgetting-curve scheduler for missed questions.

### Gate G5 — AI layer                          [PENDING]
Socratic logic guide (no direct answers), dynamic regional analogies engine,
automated MDX study transformer, vision-based script OCR grader.

### Gate G6 — Live layer                        [PENDING]
Goroutine WebSocket multiplayer mock arenas + global leaderboards,
voice-first hands-free flashcards, in-browser polyglot sandboxes.

### Gate G7 — Ecosystem                         [PENDING]
Sponsor & guardian read-only ROI portal, gamified deep-work streaks,
posture/opt-in fatigue monitor, curriculum-to-career bridge,
syllabus-to-university cross-mapping.

### Research spikes (no gate commitment)
Peer-to-peer Bluetooth mesh sync for low-connectivity regions;
smart-contract credential stamping (Solidity/Vyper) for mock certificates;
bandwidth-adaptive ultra-low-bitrate audio summaries.

### Standing ops notes
- Go toolchain in paired sandbox: `export PATH=/home/z/go-dist/go/bin:$PATH`.
- Sandbox DNS allowlist blocks `api.neon.tech` — Neon connection URI must be
  supplied by founder (Neon console → connection string) or run E2E against
  userspace PostgreSQL locally; the service is DATABASE_URL-agnostic.
- GitHub PAT rotation due at sprint end (standing security item).
