# Renance Platform — Monorepo

Solo-built modular platform: education (CBT/School), commerce (SME/Skills),
utilities and payroll on one core. Stack: TypeScript everywhere
(NestJS api · Next.js web) + Flutter mobile + Neon Postgres
(schema-per-module) + Redis + Cloudflare R2.

Start here: `docs/ACTIVE_PHASE.md`, then `docs/architecture.md`.

## Quickstart (first day)

```bash
# 0) prerequisites: Node 22+, pnpm 10+ (corepack enable), Docker optional
corepack enable

# 1) install
pnpm install

# 2) environment
cp .env.example .env         # then paste your Neon DATABASE_URL values

# 3) database schemas (Neon)
bash scripts/db-bootstrap.sh # or paste db/sql/00_bootstrap_schemas.sql into the Neon SQL editor

# 4) local redis (optional now, needed Phase 3)
docker compose up -d redis

# 5) run everything
pnpm dev                     # api -> http://localhost:3001, web -> http://localhost:3000

# verify
curl http://localhost:3001/api/v1/health
curl -X POST http://localhost:3001/api/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"you@example.com","password":"Passw0rd1","displayName":"You"}'
```

Mobile comes later: `apps/mobile/README.md`.

## Daily loop

```bash
pnpm sync          # match GitHub before working   (= git-sync.sh)
# ...code...
git commit -am "feat(core): ..."
pnpm sync --push   # publish at session end
```

Full protocol incl. AI-agent token handoff: `docs/git-workflow.md`.

## Layout

| Path | Purpose |
|------|---------|
| `apps/api` | NestJS modular monolith (single deploy unit) |
| `apps/web` | Next.js admin console |
| `apps/mobile` | Flutter (created via `flutter create`) |
| `packages/db` | Drizzle client + per-module pgSchema definitions |
| `packages/shared` | zod contracts shared across TS surfaces |
| `db/sql` | Neon bootstrap SQL (schemas live there, tables come from Drizzle) |
| `docs` | architecture rules, git workflow, ADRs, active phase |
| `scripts` | db-bootstrap · git-sync · new-module |

## Commands

| command | what it does |
|---------|--------------|
| `pnpm dev` | run api + web concurrently |
| `pnpm typecheck` | strict types across every workspace |
| `pnpm test` | vitest suites |
| `pnpm db:bootstrap` | apply `db/sql/*.sql` to Neon |
| `pnpm db:generate` | drizzle-kit: generate SQL migrations |
| `pnpm db:migrate` | drizzle-kit: apply migrations |
| `pnpm module:new <name>` | scaffold a future module (Phase 3+) |
