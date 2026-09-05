# Renance Roadmap — Feature Status Map

Last updated: 2026-09-05 (career bridge #18 shipped end-to-end with a curated
Nigerian scholarship + JAMB course-path catalogue; offline share #16 shipped
its real file slice; study-plan screens read the live backends; #8 flipped
LIVE).

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
| Android OAuth client | Google Console → OAuth client (type **Android**). | Values fixed and documented — package `dev.renance.renance`, SHA-1 `6E:A1:3C:4A:0C:70:4E:28:1A:77:00:3A:4B:F4:9A:7A:25:5B:F0:95` (committed release keystore). Create the client, no code change needed. |

### Keystore note (Android Google sign-in — RESOLVED)

Google requires a **stable SHA-1** for the Android OAuth client. CI runners
generate a fresh debug keystore on every build, so its SHA-1 rotates — that
would silently break Google sign-in in CI-built APKs. **Fixed:** a dedicated
release keystore is committed to the repo with a documented password
(acceptable pre-launch; rotate before Play Store distribution), and
`build.gradle.kts` signs every release APK with it. The SHA-1 is therefore
permanent — register it once in Google Console and every future APK keeps
Google sign-in working.

## G4+ feature board (the 19-item list)

Ordered by **value ÷ effort** within each dependency class. "Pure" features
need no external services — they ship fastest.

### Class A — Pure Go/Flutter/Next.js (no external dependencies)

| # | Feature | Plan sketch | Status |
| --- | --- | --- | --- |
| 1 | **CLI bulk test builder** (`cmd/qbuild`) | Go CLI: YAML/CSV in → validated exam packs + answer keys out, `check` lints, `build` writes pack+key+manifest and boot-verifies with the real loader. Loader for the 8,679 real questions (G2). | **LIVE** (2026-09-03) |
| 2 | **Gamification** (streaks, XP, badges) | Migration 0003 (`study.streaks`, `study.awards`), `ApplyGrade` wired into the grading worker (best-effort), `GET /me/gamification` (zero state on first launch), 8 badge codes, unit-tested pure rules. | **LIVE** (2026-09-03, backend + endpoint; app UI surfaces via gamification_hub designs) |
| 3 | **Spaced repetition** | SM-2 scheduling on attempt topics; migration 0005 `study.review_queue`; nightly-friendly job endpoint; app + web "Review due today". | **LIVE** (2026-09-03 — migration 0005, pure SM-2 with tests, grading-worker wiring, `GET /me/review` + admin tick, app review tab hero/queue preview + web /review queue landing) |
| 4 | **Syllabus mapping** | `data/syllabus/{jamb,waec,university-modules}.json` topic trees; boot-validated against every pack topic (cbtdata refuses unknown tags); `GET /syllabus/{body}` overlays the student's SM-2 mastery per topic; score report weak-topic chips + syllabus map screens (app + web). | **LIVE** (2026-09-04) |
| 5 | **Adaptive UI** | `POST /attempts {adaptive:true}` ranks the pack weak-topic-first from the review queue's SM-2 state (ease, lapses, last accuracy, due-ness) — pure `store.AdaptiveOrder`, persisted on `attempts.question_order` (migration 0006); mobile Smart-order toggle + web switch; qbuild lint rejects topics outside the syllabus tree. | **LIVE** (2026-09-04) |
| 6 | **Fatigue monitoring** | Pure `fatigue.Assess` (latency drift + sitting length) mirrored in Dart + TS; `POST /me/sessions` re-computes and logs to `study.sessions` (migration 0007), `GET /me/fatigue` powers the home banner; exam players show the fatigue_nudge overlay (Take 5 pauses the clock) and fire-and-forget telemetry. | **LIVE** (2026-09-04) |
| 7 | **Voice flashcards** | `data/flashcards/*.json` decks boot-validated in cbtdata; `GET /flashcards[/code]`, `POST /me/cards/progress` Leitner boxes (pure, mirrored on all clients) + `study.card_progress` (0007); app player with flutter_tts + offline deck cache + pending-grade queue; web player with speechSynthesis. | **LIVE** (2026-09-04) |
| 8 | **MDX conversion** | `cmd/mdx`: rich lesson content → validated JSON bundles under `data/lessons`, boot-loaded into the API like exam packs (`GET /lessons`, `GET /lessons/{slug}`), rendered by the app player (offline cache) and the web reader (static export for SEO). Pure Go. | **LIVE** (2026-09-04) |

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
| 16 | **Bluetooth mesh** (offline sharing) | A pack is a sealed questions-only bundle, so the offline slice ships as FILES: Send Pack writes `{code}.renance-pack.json` and opens the OS share sheet (Bluetooth, Xender, ShareIT, Nearby, any pipe students already use); Receive imports through the same strict validation the API boot applies (counts, marks, ids, thin MCQs) and keeps a sha256 integrity key. Pure `pack_share` codec, unit-tested. The phone-to-phone radio channel (nearby_connections) is a later slice once device testing is possible. | **LIVE** (2026-09-05, file slice) |
| 17 | **Smart-contract certificates** | Achievement certificates minted on a testnet (Base/Scroll sepolia), wallet optional. Needs testnet RPC + contract + wallet UX decisions. | NEEDS DEP — testnet choice; park until core learning loop is deep |
| 18 | **Career bridge** | `data/career/{scholarships,paths}.json`: curated catalogue (9 real Nigerian scholarship programs with honest windows + official domains, 13 JAMB course paths with subject combinations, typical competitive aggregates and universities); boot-validated join, every path topic must exist in a syllabus tree; `GET /career` (E2E-asserted); app screen reads it live and opens provider pages; web `/career-bridge/` bakes the same files, public with SEO metadata + sitemap. | **LIVE** (2026-09-05) |
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
