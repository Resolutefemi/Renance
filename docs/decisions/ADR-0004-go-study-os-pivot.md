# ADR-0004: Go Study OS pivot — monolith disbanded, micro-app architecture

Date: 2026-09-02 · Status: ACCEPTED · Supersedes: ADR-0001

## Context

ERA 1 shipped a NestJS modular monolith whose scope covered the study OS
plus school management, SME tools, and payroll verticals (Gates 1.1→2.0,
all green). The founder has decided the product thesis changed: Renance is
**only** the global student study operating system, and every other
business vertical becomes an independent repository / standalone micro-app.

The founder explicitly chose a Go backend for the study OS.

## Decision

1. The Renance repository is dedicated to the study OS: Go backend
   (`apps/study-api`), Next.js web (`apps/web`), Flutter shell (`apps/mobile`).
2. The NestJS monolith is disbanded: code preserved read-only under
   `legacy/nestjs-monolith/` (git history intact via renames) until it is
   extracted into independent vertical repositories by the founder.
3. The study API is Go: goroutines + channels are the native fit for the
   concurrent CBT engine (thousands of simultaneous submissions), deploys
   are a single static binary, and the runtime aligns with the founder's
   direction. ADR-0001's TypeScript-over-Go call is reversed for this service.
4. Neon database: the Go service owns a dedicated `study` schema and does
   not share table models with any vertical. ERA-1 `core.*`/`cbt.*` tables
   stay in place, untouched, owned by the legacy codebase.
5. Doctrine continuity: ADR-0003's bundle/key/manifest split is the law of
   the new stack — bundles never carry answer material, keys are
   server-only, manifests carry sha256 fingerprints, mock packs are
   committed until the real banks arrive in G2.

## Consequences

- Era-1 NestJS gates stop receiving code; tests/deploy for the monolith are
  frozen, not maintained.
- The Go service re-implements auth/profile/CBT concerns from ERA 1 with
  the simplified credential flow (username + password only) and adds the
  profile-modal onboarding and background asset-sync worker patterns.
- `tools/cbt-build` (Python) replaces the ERA-1 Node CLI as the content
  pipeline, porting its normalize variants so the founder's real banks
  ingest without reshape work.
- Vertical extraction repos remain a founder-driven future action; nothing
  in this repo depends on legacy code.
