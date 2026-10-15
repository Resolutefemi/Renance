# Supabase — the first fallback database

Project: `zfxrmcwdnmmxjawmsiyp` (https://zfxrmcwdnmmxjawmsiyp.supabase.co),
verified live on 2026-10-15 (REST + auth health probes passed).

## How the fallback works

Renance's database chain (founder directive 2026-10-15 — *"can the
project share two databases, or use another database as a backup when
the first one's free trial ends?"*):

```
DATABASE_URL (Neon, primary)
   └─ unreachable at boot? → SUPABASE_DATABASE_URL   ← this project
          └─ unreachable too? → INSORGE_DATABASE_URL
```

- **At boot** (`apps/study-api/internal/store/fallback.go`): the first
  DSN that connects AND pings wins. Migrations run on the winner, and
  the boot path (curriculum seed + premium backfill) provisions a
  fresh database automatically.
- **At runtime** (`apps/study-api/internal/httpapi/dbwatch.go`): the
  CU-aware watchdog counts 5xx responses and only probes the pool
  after a real failure burst — never on a schedule, so a fallback
  setup can never keep the Neon compute awake (the 100 CU-hour
  budget). A database that fails both probes exits the process so
  Render's restart re-runs the boot chain onto a live DSN.

## Where the migrations live

**Not in this directory.** The schema is owned by the Go service's
embedded, ordered, journaled migration set:

```
apps/study-api/internal/store/migrations/0001…0030*.sql
```

There is deliberately no duplicated `supabase/migrations/` baseline —
one source of truth. To prepare this Supabase project ahead of the
first failover (optional; a failover boot provisions it anyway):

```sh
cd apps/study-api
go run ./cmd/dbapply -dsn "$SUPABASE_DATABASE_URL"
```

`cmd/dbapply` structurally refuses any `neon.tech` DSN unless
`-force-neon` is passed — the Neon compute budget (19% CU left,
2026-10-15) can never be spent by accident from a tool run.

## The one missing credential

`SUPABASE_DATABASE_URL` — from the Supabase dashboard:
**Project → Settings → Database → Connection string → Connection
pooler (port 6543)**, shape:

```
postgresql://postgres.zfxrmcwdnmmxjawmsiyp:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres
```

Set it on Render (the `SUPABASE_DATABASE_URL` env var is already
declared in `render.yaml`). The Go service speaks the Postgres
simple-protocol, which is safe behind Supabase's transaction-mode
pooler; `channel_binding` and other pgx-unsupported parameters are
stripped automatically at connect time.

## Verified credentials (2026-10-15 connection tests)

- `sb_secret_…` server key — **works** (HTTP 200, full admin REST
  access). The legacy `service_role` JWT pasted in chat is corrupted
  (401 — malformed `MTc5IwAzMjIs` segment); re-copy it fresh from the
  dashboard if you ever need that exact key form.
- `anon` JWT and `publishable` key — valid (RLS-scoped / restricted).
- The Postgres **wire** connection could not be tested without the
  dashboard password — that's the missing DSN above. InsForge (the
  second fallback) is fully wire-verified.

None of the REST keys are needed by the fallback itself: the study-api
connects as a plain Postgres client. Keep the dashboard credentials
out of the repo.
