# Cloudflare R2 - the lesson blob home

Founder directive 2026-10-17: move the lesson cache to Cloudflare R2.

## Why

`learn.lessons` (the whole lesson document: 10 long note parts + 20 quiz
items + drawings per topic) rides the InsForge Postgres "cache database",
which has a hard storage ceiling (~430 MB free tier / ~1 GB paid). Every
new topic the students open adds to it; the ceiling is the storage
problem, not the code. Cloudflare R2 lifts it:

|                     | InsForge cache DB | Cloudflare R2 free tier |
|---------------------|-------------------|-------------------------|
| capacity            | ~430 MB           | 10 GB                   |
| egress              | metered           | **free (always)**       |
| reads (Class B)     | -                 | 10M / month             |
| writes/lists (Class A) | -              | 1M / month              |
| lesson doc (~40 KB) | ~36k rows = ~1.5 GB | fits with room to spare |

## Architecture (the zero-risk cut)

The bucket is the **durable home**; the cache database stays the
**index**. Nothing is removed, everything falls back:

- **Read** a lesson: bucket first -> cache database -> generation.
  Three tiers, no dead end.
- **Write** a lesson (generated or healed): dual - bucket PUT + the
  existing database upsert. A bucket failure is a log line, never a
  failed lesson.
- **Review sets / arena pools / prefetch probe** keep reading the
  database index (batch queries with ordering stay SQL); the prefetch
  probe additionally checks the bucket so a lesson that lives only in
  the bucket never regenerates.
- **Rollback** = unset the four R2_* variables on Render and redeploy.
  The API reverts to the single-home posture instantly; the bucket just
  stops being read.

Object shape: one JSON envelope per topic at `lessons/<topic_id>.json`
(`learn.LessonBlob` in `internal/learn/blobs.go`) - title, summary,
notes, key_points, quiz, drawings, source, generated_at. The same
envelope the operator commands below read and write.

## Step 1 - Cloudflare console (one time, ~3 minutes)

1. Sign in at dash.cloudflare.com (any plan; R2 has its own free tier).
2. Left sidebar: **R2 Object Storage** -> if asked, click
   **Purchase R2** / activate the free tier (needs a payment card on
   file for identity, but nothing is charged inside the free numbers
   above).
3. **Create bucket** -> name it `renance-lessons` -> Location:
   *Automatic* -> Create.
4. Account id: it is visible on the R2 overview page (right sidebar,
   "Account details") and inside the bucket's S3 API endpoint. Copy it.
5. Create the S3 credentials: R2 overview -> **Manage R2 API Tokens**
   (or Account > API Tokens > Create Token > "Create Custom Token"):
   - Permission: **Object Read & Write**
   - Scope: **Apply to specific buckets only** -> `renance-lessons`
   - Create, then copy **Access Key ID** and **Secret Access Key**
     (the secret is shown ONCE).

## Step 2 - Render environment (the API service)

Add four variables to the `study-api` service (Dashboard -> service ->
Environment):

```
R2_ACCOUNT_ID      = <your cloudflare account id>
R2_BUCKET          = renance-lessons
R2_ACCESS_KEY_ID   = <access key id>
R2_SECRET_ACCESS_KEY = <secret access key>
```

Optional: `R2_PREFIX` (default `lessons/`) if you ever want the bucket
sectioned.

Deploy. Verify from any browser, zero database cost:

```
https://renance-api.onrender.com/healthz
```

The response gains `"blobs":"r2"` when the bucket is attached
(`"off"` = variables unset). The boot log carries the same news:
`lesson blobs: cloudflare r2 attached - the bucket is the durable lesson home`.

## Step 3 - backfill the existing cache into the bucket (one time)

Run the operator tool from any machine with Go (it needs the cache
database DSN and the same four R2 variables):

```bash
export CACHE_DATABASE_URL="<the CACHE_DATABASE_URL value from Render>"
export R2_ACCOUNT_ID=... R2_BUCKET=renance-lessons \
       R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=...

cd apps/study-api

dbsplit r2-status          # ledger: database rows vs bucket objects
go run ./cmd/dbsplit r2-push   # streams every learn.lessons row into R2
go run ./cmd/dbsplit r2-status # re-check - "backfill complete"
```

Notes:

- `r2-push` is **resumable**: objects already in the bucket skip, so a
  half-finished run continues where it stopped. `--force` rewrites
  everything.
- ~36k objects land as ~1.5 GB; the run takes minutes, not hours.
- While the push runs, the live API keeps serving exactly as before
  (bucket misses fall through to the database).

## Day-to-day after cutover

Nothing changes operationally. Every newly generated lesson dual-writes
(bucket + database), every open serves from the bucket when present,
and the database ceiling stops being a threat: even if the cache
database were wiped entirely, `r2-restore` rebuilds `learn.lessons`
from the bucket:

```bash
go run ./cmd/dbsplit r2-restore --yes   # rebuild the index from R2
```

(hit_count restarts at zero - it is a serving statistic, not content.)

## Costs

Free tier covers this deployment many times over: 10 GB storage
(~1.5 GB used at cutover), 10M reads/month (a lesson open is one GET),
1M writes/month (one PUT per generated lesson, ~36k at backfill). Egress
is never billed. If the catalogue someday outgrows 10 GB, the paid tier
is $0.015/GB-month - about 20 cents at 15 GB.

## Code map

| piece | file |
|---|---|
| SigV4 client (stdlib, no AWS SDK) | `internal/r2store/r2store.go` |
| envelope + read/write glue | `internal/learn/blobs.go` |
| R2-first read tier | `internal/learn/engine.go` `cachedLesson` |
| dual write | `internal/learn/engine.go` `persistLesson` |
| prefetch bucket probe | `internal/learn/splitq.go` `cachedTopicSet` |
| boot wiring + `/healthz` blobs field | `internal/httpapi/server.go`, `health.go` |
| operator commands | `cmd/dbsplit/main.go` (`r2-status`, `r2-push`, `r2-restore`) |
