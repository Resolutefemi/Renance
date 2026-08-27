# ADR-0003: Offline-first CBT content delivery

Date: 2026-08-27 · Status: ACCEPTED · Owner: @Resolutefemi

## Context

Exams must survive Nigerian network reality: students take CBT offline
(airplane mode, dead zones, exhausted data). Meanwhile exam integrity is the
product: answer keys must NEVER be extractable from any client — mobile APK,
browser devtools, or leaked content packs. The founder's existing banks
(8,600+ questions across 21 JSON files in renancecbt / jamb-cbt-web) all have
answers embedded, so shipping them as-is would leak every exam.

Also per PRD: the Play Store app ships as a small shell; after install it
downloads ONLY what the signed-in student's org assigns. The web console is
online-first and carries the full library for management/authoring.

## Decision

1. **Questions never live in Neon. Answer keys live only in Neon. Answer
   keys never touch any client** (mobile or web — devtools make browsers the
   easier inspection target, so the rule applies doubly there).
2. One bank builds into TWO artifacts (`packages/cbt-content`):
   - `bundle.json` — questions, options, marks, version fingerprint. Student-
     safe; this is what devices/browsers download.
   - `key.json` — correct answers + explanations. Server-only; explanations
     deliberately live here because they restate answers and may only be
     revealed after grading.
3. Grading is **server-side on submission**: devices send responses only;
   scores return. Offline exams sync when connectivity returns.
4. Delivery model: APK/web shell → login → **manifest** (assigned bundles
   only) → scoped bundle download (sha256-pinned) → fully offline exam →
   sync → **bundle auto-deleted** from device. Blast radius of any leak: one
   exam, one school, one version.
5. Storage ladder: v1 bundles live as JSON in this repo (private); v2 moves
   to R2+CDN with the API serving signed manifest entries; images/diagrams
   go to R2 from the start (10GB free, zero egress).
6. `cbt.bundles` rows in Neon hold metadata + payload + key (jsonb). Payload
   and key are NEVER returned together by any endpoint: manifest = metadata;
   bundle fetch = payload without key; grading reads key server-side only.

## Consequences

- Offline-first holds without compromise: zero network during exams.
- Content updates are bundle republishes with version bumps; attempts pin
  the version they answered (fingerprint via sha256 at publish).
- The pipeline normalizes the 6 known legacy bank shapes (bare array /
  {course,questions[]} wrapper / option record a-d or A-D / options array
  with correct flag / answer letter / answers[] text with case variants),
  strips BOMs, dedupes, and reports drops — evidence-based on the founder's
  21 real banks.
- Text questions (CVE105-style accepted-answers arrays) grade as
  case-insensitive trimmed exact match against the accepted list.
- Neon stays relational-tiny: attempts/responses/scores are the growth data,
  at kilobytes per exam sitting — years of free-tier runway.
