# Supabase - the first fallback database

Project: `zfxrmcwdnmmxjawmsiyp` (https://zfxrmcwdnmmxjawmsiyp.supabase.co),
**FULLY PROVISIONED AND E2E-VERIFIED 2026-10-15**: schema (30
migrations) + the complete curriculum seed - 293 departments, 10,725
courses, 130,275 topics - plus the full student desk flow (institution
pick → department pick → course shelf) tested end-to-end through the
pooler DSN. The same seed runs on Neon, so this project now carries
the same curriculum data as the primary.

## How the fallback works

Renance's database chain (founder directive 2026-10-15 - *"can the
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
  after a real failure burst - never on a schedule, so a fallback
  setup can never keep the Neon compute awake (the 100 CU-hour
  budget). A database that fails both probes exits the process so
  Render's restart re-runs the boot chain onto a live DSN.
- The verified DSNs are baked into `render.yaml` (private-repo
  practice), so a Render deploy boots with the whole chain armed.

## The connection string (VERIFIED)

```
postgresql://postgres.zfxrmcwdnmmxjawmsiyp:PASSWORD@aws-1-eu-west-3.pooler.supabase.com:5432/postgres?sslmode=require
```

- **aws-1-eu-west-3.pooler.supabase.com** - the project's supavisor
  **session-mode pooler** (port 5432). Use the POOLER, never the
  direct `db.zfxrmcwdnmmxjawmsiyp.supabase.co` host: the direct host
  is **IPv6-only**, and IPv4-only runtimes (Render egress, GitHub
  Actions runners, most CI) cannot reach it at all.
- The real password lives in `apps/study-api/.env` (gitignored) and in
  `render.yaml`. A `#` in a password must be URL-encoded (`%23`) in
  the DSN.
- The Go service speaks the Postgres simple-protocol, which is safe
  behind poolers; `channel_binding` and other pgx-unsupported
  parameters are stripped automatically at connect time.
- Rotate the password any time: update `render.yaml` + the GitHub
  Actions secret `SUPABASE_DATABASE_URL` + `apps/study-api/.env`.

## Where the migrations live

**Not in this directory.** The schema is owned by the Go service's
embedded, ordered, journaled migration set:

```
apps/study-api/internal/store/migrations/0001…0030*.sql
```

There is deliberately no duplicated `supabase/migrations/` baseline  - 
one source of truth. To re-apply / verify the schema:

```sh
cd apps/study-api
go run ./cmd/dbapply -dsn "$SUPABASE_DATABASE_URL"
```

`cmd/dbapply` structurally refuses any `neon.tech` DSN unless
`-force-neon` is passed - the Neon compute budget can never be spent
by accident from a tool run.

## Keeping the project unpaused

Supabase pauses free projects after ~7 days without activity. Three
independent lines hold it awake:

1. **`/.github/workflows/db-keepalive.yml`** - fires on days
   1, 7, 13, 19, 25, 31 (max gap 6 days), pings the Postgres wire +
   REST, inserts a heartbeat row into `public.db_keepalive` (visible
   in the dashboard's table editor), and commits
   `supabase/keepalive/last-run.json` to the `chore/db-keepalive`
   branch (which also keeps the repository itself active so GitHub
   never disables the schedule). Credentials ride GitHub Actions
   secrets (`SUPABASE_DATABASE_URL`, `SUPABASE_URL`,
   `SUPABASE_SECRET_KEY`, `INSFORGE_DATABASE_URL`).
2. **Real student traffic** - `apps/web` fires one authenticated REST
   ping per production page load (`utils/supabase/client.ts` →
   `pingSupabase()`, mounted in `components/sw-register.tsx`).
3. **Any failover boot** - the Go API connects as a plain Postgres
   client the moment it ever needs this database.

## Copying the LIVE user data from Neon (optional, one command)

The seed above replicates the **curriculum** (departments, courses,
topics - the data the desk, lessons and practice read). Live **student
rows** (accounts, progress, XP) still live only on Neon. To snapshot
them into this project, run once from any machine with the Neon DSN
(from the Render dashboard, `DATABASE_URL`):

```sh
# schema + data of the app schemas, into the Supabase pooler:
pg_dump "$NEON_DSN" --schema=study --schema=learn \
  | psql "$SUPABASE_DATABASE_URL"
```

Run it before a planned Neon migration, or after any incident - the
tables are keyed the same, so the copy lands cleanly. (Neon is never
contacted by anything in this repo on its own; running pg_dump is a
manual, deliberate founder action, exactly like a manual backup.)

## Verified credentials (2026-10-15)

- `sb_secret_…` server key - **works** (HTTP 200, full admin REST
  access). The legacy `service_role` JWT pasted in chat is corrupted
  (401 - malformed `MTc5IwAzMjIs` segment); re-copy it fresh from the
  dashboard if you ever need that exact key form.
- `anon` JWT and `publishable` key - valid (RLS-scoped / restricted).
- Postgres **wire**: verified through the session pooler (PostgreSQL
  17.11) - migrations, seed and the desk-flow E2E all ran on it.
- None of the REST keys are needed by the fallback itself: the
  study-api connects as a plain Postgres client. The secret key powers
  the keepalive REST ping only.
