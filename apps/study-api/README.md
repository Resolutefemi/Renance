# renance-study-api

Go backend of the Renance study OS (ADR-0004). One binary, stdlib HTTP
routing, pgx/v5 in simple-protocol mode (pooler-safe), bcrypt cost 12,
hand-rolled HS256 JWT (12h), embedded-SQL migrations for the `study` schema.

```
cmd/api/            entrypoint: config → content → db → keys → engine → http
internal/config/    env loading
internal/jwtx/      dependency-free HS256 (sign/verify/expiry)
internal/store/     every SQL query + migrations/*.sql (embedded, ordered)
internal/cbtdata/   content loader: sha256 manifest verification + REFUSES
                    TO BOOT if any answer material appears in a bundle
internal/grading/   goroutine engine: buffered channel → worker pool;
                    pure Score() unit-tested; panic isolation per job
internal/syncer/    per-user background asset-sync worker (sync_jobs rows)
internal/httpapi/   handlers, CORS, bearer auth middleware
```

## Run

```bash
export DATABASE_URL="postgresql://…"    # Neon or local Postgres
pnpm api:dev                            # :3990, migrates on first boot
```

## API surface

```
GET    /healthz
POST   /auth/register          {username, password}      ← ONLY these fields
POST   /auth/login             {username, password}
GET    /me
PUT    /me/profile             {fullName, institution, gradeLevel, exams[]}
GET    /manifest               sha256-fingerprinted pack list
GET    /bundles/{code}         student-safe bundle (doctrine-enforced)
POST   /attempts               {code}
POST   /attempts/{id}/submit   {answers:[{questionId,selected}], durationMs?}
GET    /attempts/{id}          poll → grading → graded + result
GET    /sync/status            silent asset-sync job progress
```

Grading is asynchronous: submit returns **202** and the goroutine pool does
the rest; clients poll the attempt. Retakes allowed, resubmits are 409,
foreign attempts are 404, answer keys never leave the server.

## Tests

```bash
go test ./...        # jwt, grading matrices, content-doctrine loader
```
