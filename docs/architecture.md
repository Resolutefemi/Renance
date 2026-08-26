# Renance Architecture — Developer Rules

Source of truth for how the monorepo is wired. The PRD (v0.4) describes WHAT;
this file describes HOW the code is organised. When the two disagree after a
decision meeting, update this file first, then code.

## Deployable units

| Unit | Stack | Notes |
|------|-------|-------|
| `apps/api` | NestJS modular monolith | ONE deployment; modules are internal boundaries |
| `apps/web` | Next.js 15 | Admin console now, public site later |
| `apps/mobile` | Flutter | CBT/Study first (renancecbt lineage) |
| Database | Neon Postgres | schema-per-module |
| Cache/queues | Redis (managed or compose) | Phase 3+ |
| Files | Cloudflare R2 | images, exports (Phase 2+) |

```
Flutter ─┐                                  ┌─ Neon Postgres (8 schemas)
         ├─▶ apps/api (modules) ────────────┼─ Redis
Next.js ─┘        │                         └─ Cloudflare R2
                  └─ FCM push (Phase 2+)
Payments: Paystack → Flutterwave fallback (Phase 3)
```

## Module Boundary Contract

1. **Ownership.** Each module exclusively owns:
   - its Postgres schema (`core`, `cbt`, `school`, `sme`, `skills`,
     `utilities`, `payroll`);
   - its code folder `apps/api/src/modules/<name>`.
2. **Cross-module access.** A module NEVER reads another module's tables and
   never imports another feature module's internal services. Anything shared
   must be exported deliberately from `CoreModule` (facade) or delivered as an
   event (Phase 3 outbox).
3. **IDs over joins.** Modules share UUIDs, not foreign keys across schemas.
4. **DDL discipline.** Tables are created only through Drizzle migrations
   (`pnpm db:migrate`). Hand-written SQL beyond `db/sql/*.sql` bootstrapping is
   forbidden.
5. **Adding a module** = run `bash scripts/new-module.sh <name>`, register in
   `app.module.ts`, apply its schema SQL, then implement inside its folder.

## Environments

| Env | Database | Purpose |
|-----|----------|---------|
| local dev | Neon dev branch | day-to-day work |
| preview | Neon branch per PR | integration checks (Phase 1+) |
| production | Neon main branch | real users |

Install-size budgets carried from PRD: Android < 55MB, iOS < 65MB,
Windows < 90MB — enforced by shipping modules on demand.
