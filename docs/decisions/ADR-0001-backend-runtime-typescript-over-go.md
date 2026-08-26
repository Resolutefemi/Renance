# ADR-0001: TypeScript backend instead of Go

Status: ACCEPTED (2026-08)

## Context
PRD v0.4 lists Go as the reference backend language. The build reality:
one solo developer, ~20 focused hours/week, paired continuously with AI
assistants.

## Decision
apps/api uses TypeScript (NestJS) so the entire JS-side stack shares one
language: API, Next.js web, packages, CI scripts, tooling.

## Rationale
- context switching between Go/TS/Dart costs scarce hours;
- AI pair quality is highest where examples are most abundant (TS/Nest);
- hiring/outsourcing pool for future maintenance is larger;
- NestJS module system maps 1:1 onto the modular-monolith boundary contract.

## Escape hatch (revisit triggers)
Re-evaluate Go when ANY becomes true:
1. CPU-bound scoring/analytics engine emerges (Phase 3+) that TS serves poorly;
2. team grows past 2 backend engineers;
3. sustained p95 latency problems at api layer.

Until then the boundary contract keeps each module portable enough that a
single module could be rewritten in Go later without systemic change.
