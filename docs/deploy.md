# Deploying Renance — API (Render) + Database (Neon)

This is the 10-minute path from "repo" to "students can actually register".
Do the steps in order; each one feeds the next.

## Architecture in one paragraph

The Flutter app and the Next.js web app are **clients**. All accounts, exam
content delivery and grading live in the **Go study-api**, which talks to a
**Neon Postgres** over the pooled connection string. The API embeds its own
migrations — on boot it creates `study.users`, `study.profiles`,
`study.attempts`, … and seeds answer keys — so the database needs zero
manual setup. The API is stateless; Render runs it in a Docker container
built from `apps/study-api/Dockerfile`.

```
GitHub Pages (web) ─┐
                    ├─►  study-api on Render  ─►  Neon Postgres (pooler)
Android APK ────────┘        (this guide)
```

## 0. Prerequisites

- A [Render.com](https://render.com) account (free plan is fine to start).
- Your Neon **pooled** connection string — Neon console → project →
  **Connection string** → choose the **Pooled** toggle. It looks like:
  `postgresql://neondb_owner:***@ep-…-pooler…neon.tech/neondb?sslmode=require&channel_binding=require`
  The API strips `channel_binding` itself (pgx has no support for it), so
  you can paste the URI exactly as Neon hands it to you.

## 1. Create the API service on Render

1. Push this branch to GitHub (already done if CI is green).
2. Render dashboard → **New +** → **Blueprint** → pick the
   `Resolutefemi/Renance` repo. Render reads `render.yaml` at the repo root
   and proposes one web service: `renance-api` (Docker runtime,
   `healthCheckPath: /healthz`).
3. When prompted, fill the sync-false variables:
   - `DATABASE_URL` — paste the **Neon pooled URI** from step 0.
   - `GOOGLE_CLIENT_ID` — BOTH OAuth clients, comma-separated (the API
     accepts ID tokens minted for either):
     `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com,850087098854-5rj3vig6fpm4k2jie4najsoq6tpcdm6f.apps.googleusercontent.com`
   - `JWT_SECRET` is auto-generated; leave it.
4. **Apply** → wait for the first build (~3–5 min). The deploy only goes
   live when `/healthz` returns `200 {"db":"ok"}` — a bad Neon password
   fails the deploy loudly instead of shipping an auth-dead API.
5. Note the service URL, e.g. `https://renance-api.onrender.com`.
   Sanity-check it: `curl https://renance-api.onrender.com/healthz`.

> **Free plan note:** the service sleeps after ~15 min idle; the first
> request wakes it in ~30–50 s. Upgrade any time for always-on.

## 2. Point the web app at the API

GitHub repo → **Settings → Secrets and variables → Actions → Variables**:

| Variable                    | Value                                        |
| --------------------------- | -------------------------------------------- |
| `PUBLIC_API_BASE`           | `https://renance-api.onrender.com` (step 1)  |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com` |

Both are **Variables** (not secrets) — they are baked into the public
web bundle and the APK, so they are not sensitive.

Then re-run the deploy workflows (**Actions → web-deploy → Run workflow**,
same for `mobile-apk`). From now on every push to `main` builds the web
and APK against the real API.

## 3. Google OAuth client configuration

Renance uses two OAuth clients; both are registered in Google Cloud
Console → APIs & Services → Credentials:

| Client | ID |
| --- | --- |
| Web application | `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com` |
| Android | `850087098854-5rj3vig6fpm4k2jie4najsoq6tpcdm6f.apps.googleusercontent.com` |

The **web** client ID is what the Pages site renders with and what the
mobile app passes as `serverClientId` (so ID tokens carry a predictable
`aud`). The server accepts tokens minted for either client
(`GOOGLE_CLIENT_ID` is a comma-separated list on Render).

The **web** client must have these Authorized JavaScript origins:

- `https://resolutefemi.github.io`
- `http://localhost:3000` (local dev)

For the **Android** app, google_sign_in needs its own OAuth client
(_type: Android_) with:

- Package name: `dev.renance.renance`
- SHA-1: `6E:A1:3C:4A:0C:70:4E:28:1A:77:00:3A:4B:F4:9A:7A:25:5B:F0:95`

(The APK is signed with the committed `renance.keystore`, so this SHA-1 is
stable across all CI builds. Verify any time with:
`keytool -list -v -keystore apps/mobile/android/app/renance.keystore -alias renance -storepass renance-keystore`)

The Android client does **not** need the API to know its client ID —
google_sign_in takes `serverClientId` (the **web** client ID) and returns
an ID token whose `aud` matches what the API verifies. The API's secret is
never used anywhere; the whole flow is public-client.

## 4. Local development

```bash
cp apps/study-api/.env.example apps/study-api/.env   # point at local PG or Neon
(cd apps/study-api && go run ./cmd/api)               # http://127.0.0.1:3990
(cd apps/web && pnpm dev)                             # http://localhost:3000
```

Full student-flow smoke test (health → register → login → profile → exam →
grading):

```bash
bash scripts/api-e2e.sh http://127.0.0.1:3990
```

CI runs the same script against a disposable Postgres 16 on every push.

## 5. Operational notes

- **Migrations** are embedded and applied at boot in filename order
  (`internal/store/migrations/*.sql`), journaled in `study.schema_migrations`.
  Never hand-ALTER the production schema — add a migration file.
- **pgx runs in simple-protocol mode** — required for Neon's transaction
  pooler, which breaks prepared-statement caching.
- **CORS** is controlled by `WEB_ORIGIN` (comma-separated allowlist).
  `*` keeps dev wide open; production pins the GitHub Pages origin.
- **Rotating the Neon password:** reset it in the Neon console, then update
  `DATABASE_URL` on Render and restart. Old sessions survive (JWTs are
  self-contained); only new DB connections need the new URI.
- **Test-data hygiene:** `go run ./cmd/e2eclean -prefix e2e` (with
  `DATABASE_URL` set) deletes every throwaway user created by E2E runs.
