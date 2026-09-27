# Deploying Renance - API (Render) + Database (Neon)

This is the 10-minute path from "repo" to "students can actually register".
Do the steps in order; each one feeds the next.

## Architecture in one paragraph

The Flutter app and the Next.js web app are **clients**. All accounts, exam
content delivery and grading live in the **Go study-api**, which talks to a
**Neon Postgres** over the pooled connection string. The API embeds its own
migrations - on boot it creates `study.users`, `study.profiles`,
`study.attempts`, … and seeds answer keys - so the database needs zero
manual setup. The API is stateless; Render runs it in a Docker container
built from `apps/study-api/Dockerfile`.

```
GitHub Pages (web) ─┐
                    ├─►  study-api on Render  ─►  Neon Postgres (pooler)
Android APK ────────┘        (this guide)
```

## 0. Prerequisites

- A [Render.com](https://render.com) account (free plan is fine to start).
- Your Neon **pooled** connection string - Neon console → project →
  **Connection string** → choose the **Pooled** toggle. It looks like:
  `postgresql://neondb_owner:***@ep-…-pooler…neon.tech/neondb?sslmode=require&channel_binding=require`
  The API strips `channel_binding` itself (pgx has no support for it), so
  you can paste the URI exactly as Neon hands it to you.

## 1. Create the API service on Render

> **Done & verified (2026-09-07):** the Blueprint is applied and the live
> service answers `https://renance-api.onrender.com/healthz` with
> `{"db":"ok"}`. `scripts/api-e2e.sh` runs green against production end to
> end (auth → profile → exam → grading → review → syllabus → adaptive →
> fatigue → flashcards → lessons → career → tutor → arena → rate limit).
> The steps below remain as the re-creation runbook.

1. Push this branch to GitHub (already done if CI is green).
2. Render dashboard → **New +** → **Blueprint** → pick the
   `Resolutefemi/Renance` repo. Render reads `render.yaml` at the repo root
   and proposes one web service: `renance-api` (Docker runtime,
   `healthCheckPath: /healthz`).
3. When prompted, fill the sync-false variables:
   - `DATABASE_URL` - paste the **Neon pooled URI** from step 0.
   - `GOOGLE_CLIENT_ID` - BOTH OAuth clients, comma-separated (the API
     accepts ID tokens minted for either):
     `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com,850087098854-5rj3vig6fpm4k2jie4najsoq6tpcdm6f.apps.googleusercontent.com`
   - `JWT_SECRET` is auto-generated; leave it.
4. **Apply** → wait for the first build (~3-5 min). The deploy only goes
   live when `/healthz` returns `200 {"db":"ok"}` - a bad Neon password
   fails the deploy loudly instead of shipping an auth-dead API.
5. Note the service URL, e.g. `https://renance-api.onrender.com`.
   Sanity-check it: `curl https://renance-api.onrender.com/healthz`.

> **Free plan note:** the service sleeps after ~15 min idle; the first
> request wakes it in ~30-50 s. Upgrade any time for always-on.

## 2. Point the web app at the API

GitHub repo → **Settings → Secrets and variables → Actions → Variables**:

| Variable                    | Value                                        |
| --------------------------- | -------------------------------------------- |
| `PUBLIC_API_BASE`           | `https://renance-api.onrender.com` (step 1)  |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com` |

Both are **Variables** (not secrets) - they are baked into the public
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

- `https://renance.app` (production, the domain students actually use)
- `https://renance-edtech.vercel.app` (Vercel default domain, kept for fallback)
- `https://resolutefemi.github.io` (legacy Pages deploy)
- `http://localhost:3000` (local dev)

⚠️ **Origins, not redirect URIs.** The web flow is Google Identity
Services: the browser gets the ID token in-page and POSTs it to the API.
There is **no redirect step**, so `Authorized redirect URIs` is never
consulted. Buying a custom domain and only updating the redirect URIs
(and/or setting them to `https://renance.app/**`) changes nothing - the
sign-in keeps failing until the origin itself is added to **Authorized
JavaScript origins**. Redirect URIs on the web client can stay empty.

### Getting the Android client right, step by step

The **Android** app fails Google sign-in with `ApiException: 10`
(DEVELOPER_ERROR) when no OAuth client of type _Android_ in the SAME
Google Cloud project matches the installed app's package name AND
signing certificate. Creating one takes two minutes:

1. **Google Cloud Console** → open the project that owns
   `850087098854-...` (the same project as the web client - a client in a
   different project will not work) → **APIs & Services → Credentials**.
2. **+ Create credentials → OAuth client ID → Application type:
   Android.**
3. **Package name**: `dev.renance.renance` (the `applicationId` in
   `apps/mobile/android/app/build.gradle.kts`).
4. **SHA-1 certificate fingerprint** - paste the fingerprint of the key
   that actually signed the APK you installed:
   - Release/shipped builds are signed with the committed
     `renance.keystore`, whose SHA-1 is
     `6E:A1:3C:4A:0C:70:4E:28:1A:77:00:3A:4B:F4:9A:7A:25:5B:F0:95`.
     Re-verify any time with:
     `keytool -list -v -keystore apps/mobile/android/app/renance.keystore -alias renance -storepass renance-keystore`
   - `flutter run` debug builds are signed with the COMMITTED shared debug
     key `apps/mobile/android/app/debug.keystore` (gradle pins
     `signingConfigs.debug` to it, overriding `~/.android/debug.keystore`),
     so the fingerprint is the SAME on every machine:
     `C3:B9:E5:1E:C9:1B:79:7D:B1:F7:07:6B:26:13:7E:B6:0B:11:86:5F`
     Re-verify any time with:
     `keytool -list -v -keystore apps/mobile/android/app/debug.keystore -alias androiddebugkey -storepass android`
     Google allows one SHA-1 per Android client, so create a SECOND
     Android client (same package name) for this debug fingerprint.
     (On machines that have NOT pulled the commit adding the shared key,
     `flutter run` still signs with `~/.android/debug.keystore`; its
     fingerprint, if ever needed, comes from:
     `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`.)
   - If the app ships through Google Play, Play re-signs every build. Add
     a THIRD Android client whose SHA-1 comes from Play Console →
     Release → Setup → App signing → SHA-1 (the App signing key).
5. **Create**, then wait about 5 minutes for the change to propagate.
6. Reinstall/restart the app (a stale Google Play Services cache keeps
   failing for minutes) and tap the Google button again.

No code change and no API change is needed on the app side:
google_sign_in is called with `serverClientId` = the **web** client ID
(`GOOGLE_WEB_CLIENT_ID` dart-define) and returns an ID token whose `aud`
is the web client, which the API already verifies
(`GOOGLE_CLIENT_ID` on Render lists both clients, comma-separated). The
Android client's own ID value never needs to be embedded anywhere - its
existence (package + SHA-1 match) is all Google checks.

If `flutter run` builds keep failing while the shipped APK works, it is
almost always the missing debug-SHA-1 client from step 4, not the web
client.

### Troubleshooting: `Error 401: invalid_client` (flowName=GeneralOAuthFlow)

Google shows this exact page - listing the project's web and Android
client IDs - when the **web** client cannot serve the origin the button
was clicked on. The web client ID baked into the bundle is correct; the
fix lives entirely in Google Cloud Console → APIs & Services:

1. **Credentials → the Web application client → Authorized JavaScript
   origins** must contain the EXACT origin (scheme + host, no path):
   `https://renance.app`, `https://renance-edtech.vercel.app`,
   `https://resolutefemi.github.io` and `http://localhost:3000`. A missing
   or typo'd origin is the #1 cause. Save, then wait ~5 minutes for the
   change to propagate. (Adding the domain under *Authorized redirect
   URIs* instead does NOT help - see the origins-vs-redirect-URIs note
   above.)
2. **OAuth consent screen** (Google Auth Platform → Audience): Brand
   (app name, support email) configured and Publishing status set to
   **In production** - a brand-less or testing-only project rejects
   GeneralOAuthFlow requests with invalid_client too.
3. The client must be type **Web application** (not Desktop/Android) -
   GSI only speaks to web clients from a browser.
4. After saving, hard-refresh the site (Ctrl+Shift+R) - GSI caches client
   config per session.

The sign-in button itself now carries a "Google sign-in showing an
error?" disclosure that renders the current page origin so anyone hitting
this can self-diagnose.

## 4. AI (tutor + question generator)

The Socratic tutor (`/review`), Renance AI (`/ai`) and the AI Generator
(`/ai-generator`) all run through ONE OpenAI-compatible endpoint that the
study API owns. Founder directive: **Z.ai ONLY** - Groq's key was
revoked (live probes answered 403 Forbidden) and the provider is
removed; Gemini is gone. `AI_API_KEY` is the Z.ai key, now baked
directly into `render.yaml` per founder instruction, so a Blueprint
deploy boots into AI mode with no manual env step. The key is read only
by the study API server and never reaches a client bundle:

```bash
AI_PROVIDER=zai   # the one provider; retired names fall back to zai
AI_API_KEY=…      # the Z.ai key (glm-4.5-flash, free) - already in render.yaml
AI_THINKING=disabled  # default; GLM-4.5 answers directly, no reasoning delay
```

Resolved endpoint (base URL + model come along automatically;
explicit `AI_BASE_URL` / `AI_MODEL` still win over the preset):

| Provider | Base URL | Model |
| --- | --- | --- |
| Z.ai (the only one) | `https://api.z.ai/api/paas/v4` | `glm-4.5-flash` (free) |

Notes:
- **The key never rides a client bundle.** The web is a static export:
  any `NEXT_PUBLIC_` variable is shipped to every visitor, so no
  `NEXT_PUBLIC_AI_*` variable may exist anywhere (the deploy workflow
  deliberately passes none).
- **Thinking switch**: GLM-4.5 is a reasoning model; with
  `AI_THINKING=disabled` (default) it answers directly, which keeps the
  tutor's short replies fast and inside the token budget.
- When the provider fails the tutor degrades to deterministic hint mode
  (`mode:"hint"`, never a crash), Renance AI answers in study-guide
  mode and the generator returns a 502 with an honest error.
  `GET /tutor/status` → `{aiEnabled, provider}` badges the client.
- Existing service from before the key-in-blueprint change? Render
  dashboard → Blueprint → Apply re-syncs `AI_API_KEY` from render.yaml
  (or paste it once into Environment); the service restarts with the
  tutor in AI mode.

## 5. Content layout (answers live inside the banks)

Since 2026-09 the founder's doctrine supersedes the old ADR-0003
split: `data/questions/**.json` carry `answer` / `explanation` per
question and `data/answer-keys/` is gone. The API harvests those fields
at boot (server-only key map) and **serves students sanitized bundles**
- the answer fields never reach a client. Boot seeds the key store from
the banks; a legacy `answer-keys/` tree is still honored if present.

## 6. Local development

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

## 7. Operational notes

- **Migrations** are embedded and applied at boot in filename order
  (`internal/store/migrations/*.sql`), journaled in `study.schema_migrations`.
  Never hand-ALTER the production schema - add a migration file.
- **pgx runs in simple-protocol mode** - required for Neon's transaction
  pooler, which breaks prepared-statement caching.
- **CORS** is controlled by `WEB_ORIGIN` (comma-separated allowlist).
  `*` keeps dev wide open; production pins the GitHub Pages origin.
- **Rotating the Neon password:** reset it in the Neon console, then update
  `DATABASE_URL` on Render and restart. Old sessions survive (JWTs are
  self-contained); only new DB connections need the new URI.
- **Production smoke test:** `bash scripts/api-e2e.sh
  https://renance-api.onrender.com` - the same E2E CI runs, pointed at the
  live service. It creates throwaway users prefixed `e2e` (including the
  two arena students) so one `e2eclean -prefix e2e` pass (with
  `DATABASE_URL` set) purges every one of them.
- **Test-data hygiene:** `go run ./cmd/e2eclean -prefix e2e` (with
  `DATABASE_URL` set) deletes every throwaway user created by E2E runs.
