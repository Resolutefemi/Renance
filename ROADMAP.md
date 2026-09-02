# Renance Roadmap — Feature Status Map

Last updated: 2026-09-02 (after the auth + deploy sprint, commit `e1aff61`).

Status legend: **LIVE** (in main, verified) · **NEXT** (designed, no blockers) ·
**NEEDS INPUT** (blocked on a decision/asset) · **NEEDS DEP** (needs an
external service/key/infra decision) · each row lists what unblocks it.

## Shipped — the spine

| Milestone | What it means | Status |
| --- | --- | --- |
| Go study-api | Single Go binary: auth, profiles, exam delivery, async grading, silent sync. Migrations embedded, pgx simple-protocol (Neon-pooler safe), JWT 12 h sessions. | **LIVE** |
| Accounts that work | Register / login (bcrypt), **Google sign-in** (web + Android → `POST /auth/google`, JWKS-verified), profile completion gate, silent background sync. | **LIVE** |
| Web app (GitHub Pages) | Next.js static export, mockup-faithful UI, dashboard, exam runner, results. Google button appears when the client ID is baked. | **LIVE** |
| Android APK (CI) | Flutter offline-first shell; Actions builds + publishes a rolling "latest" APK on every push. Google sign-in wired (hidden until client ID baked). | **LIVE** |
| Production deploy kit | `Dockerfile` + `render.yaml` Blueprint + `/healthz` DB probe + CORS allowlist + `docs/deploy.md` runbook + `.env.example`. | **LIVE** |
| CI with real Postgres | Every push: Go build/vet/test + **full student-flow E2E on Postgres 16** + web typecheck/build + mobile analyze/test + APK build. | **LIVE** |
| Neon production DB | Migrations + answer-key seeding verified against the real Neon project; E2E ran green and test users were purged. | **LIVE** |

## Immediate (this week, no code needed)

| Item | What it is | Blocker |
| --- | --- | --- |
| Render deploy | Apply the Blueprint → get `https://renance-api.onrender.com`. | You paste the Neon URI (docs/deploy.md §1). |
| `PUBLIC_API_BASE` variable | Point web + APK at the Render URL, re-run deploys. | Render URL from the step above. |
| Android OAuth client | Google Console → OAuth client (type **Android**) with package `com.renance.app` (confirm) + SHA-1. | **NEEDS INPUT** — the screenshot never arrived; send package name + SHA-1 (see §Keystore below). |

### Keystore note (unblocks Android Google sign-in)

Google requires a **stable SHA-1** for the Android OAuth client. CI runners
generate a fresh debug keystore on every build, so its SHA-1 rotates — that
would silently break Google sign-in in CI-built APKs. Fix (planned next
commit): generate one Renance release keystore, commit it to the repo with a
documented password (acceptable pre-launch; rotate at Play Store launch),
point `build.gradle.kts` at it, and register its SHA-1 once. One setup, then
every CI APK keeps Google sign-in working forever.

## G4+ feature board (the 19-item list)

Ordered by **value ÷ effort** within each dependency class. "Pure" features
need no external services — they ship fastest.

### Class A — Pure Go/Flutter/Next.js (no external dependencies)

| # | Feature | Plan sketch | Status |
| --- | --- | --- | --- |
| 1 | **CLI bulk test builder** (`tools/qbuild`) | Go CLI: YAML/CSV in → validated exam packs + answer keys out, `--check` lints, `--import` writes into `data/`. This is also the loader for your 8,679 real questions (G2). | **NEXT** — next coding session |
| 2 | **Gamification** (streaks, XP, badges) | Migration 0003 (`study.streaks`, `study.awards`), events from grading pipeline, badges computed on grade. Pure Postgres + existing handlers. | NEXT |
| 3 | **Spaced repetition** | SM-2 scheduling on attempt topics; migration 0004 `study.review_queue`; nightly-friendly job endpoint; app + web "Review due today". | NEXT (after gamification schema) |
| 4 | **Syllabus mapping** | Tag `data/questions/*.json` with syllabus nodes (WAEC/JAMB topic trees as static JSON); API exposes `/syllabus/{exam}`; results screen links weak topics. | NEXT |
| 5 | **Adaptive UI** | Difficulty weighting from graded attempts already in DB; order question bundles by weak-topic-first. Pure server logic on existing tables. | NEXT |
| 6 | **Fatigue monitoring** | Client-side session telemetry (answer latency drift, session length) → gentle "take a break" nudge + server-side `study.sessions` log. No PII beyond timing. | NEXT |
| 7 | **Voice flashcards** | Flutter TTS reads card fronts/backs; recording-free (no mic permission needed); works offline. Mobile-first. | NEXT |
| 8 | **MDX conversion** | `tools/mdx`: rich lesson content pipeline → static content bundles served by the API like exam packs. Pure Go. | NEXT |

### Class B — Needs an AI provider key (one key unblocks five features)

| # | Feature | Plan sketch | Status |
| --- | --- | --- | --- |
| 9 | **Socratic AI tutor** | "Why is this wrong?" chat anchored to the graded attempt. API proxies the provider; prompt embeds the question + picked answer + key. | **NEEDS DEP** — AI API key (OpenAI / Gemini / OpenRouter). Cheapest first slice: hint-only mode with capped tokens. |
| 10 | **Analogy engine** | Local-context analogies for hard concepts (generated per topic, cached in `study.analogies` so we pay once, not per student). | NEEDS DEP — same key |
| 11 | **Audio summaries** | Topic summaries → TTS. Either provider TTS or on-device TTS first, AI narration later. | NEEDS DEP — TTS provider (or ship on-device TTS slice first) |
| 12 | **OCR grading** ("scan & mark") | Photo of handwritten working → marks. Vision model required; start with printed MCQ bubble sheets (deterministic CV) before handwriting. | NEEDS DEP — vision API; biggest build of the AI class |
| 13 | **Adaptive exam generation** (AI flavor) | AI generates fresh practice items per weak topic, tagged + human-reviewable before release. | NEEDS DEP — same key; gated behind review queue |

### Class C — Needs infrastructure decisions

| # | Feature | Plan sketch | Status |
| --- | --- | --- | --- |
| 14 | **Multiplayer arena** | Live head-to-head quizzes. Render supports WebSockets; needs a presence layer (in-process hub first, Redis later) + matchmaker tables. | **NEEDS DEP** — decide always-on Render plan vs. separate WS host when we ship it |
| 15 | **Code sandbox** | Students run small code challenges. Needs an isolated runner (Firecracker/Nscale-style or a SaaS like Piston) — never run untrusted code in the study-api container. | NEEDS DEP — sandbox provider choice |
| 16 | **Bluetooth mesh** (offline sharing) | Flutter + `nearby_connections`-style plugin: share question packs between phones offline. No server work; platform permissions + testing matrix. | NEXT (mobile slice) — schedule after APK pipeline is stable |
| 17 | **Smart-contract certificates** | Achievement certificates minted on a testnet (Base/Scroll sepolia), wallet optional. Needs testnet RPC + contract + wallet UX decisions. | NEEDS DEP — testnet choice; park until core learning loop is deep |
| 18 | **Career bridge** | Scholarships/jamb-path content + partner links; mostly content + curation UI. | NEXT after syllabus mapping (reuses topic graph) |
| 19 | **Patron portal** | Sponsors fund exam fees/data for students. Needs payments (Paystack for NG first) + ledger tables + privacy boundary design. | **NEEDS DEP** — payment provider account |

## Explicitly parked (your call, already agreed)

- **G2 — real question banks**: the 8,679 uploaded questions. Loader is item
  #1 (CLI builder); the moment you upload the files, `tools/qbuild --import`
  lands them. Nothing else blocks.
- Desktop installers (Windows/macOS/Linux): Flutter desktop is supported by
  the codebase, but store/packaging work is deferred until mobile is live.

## Sequencing proposal (next 3 sessions)

1. **Session A**: `tools/qbuild` CLI (#1) + gamification (#2) — both pure.
2. **Session B**: stable keystore + Android OAuth config test with you; spaced repetition (#3) + syllabus mapping (#4).
3. **Session C**: adaptive UI (#5) + review-queue surfacing; then AI class once a key is chosen (Socratic first).
