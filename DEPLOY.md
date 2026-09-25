# Deploying the Renance website

Two supported targets. Both build the same static export — the site is a
Next.js app compiled to plain files (`apps/web/out/`), so hosting is a
copy operation and nothing can "run" wrongly on the server.

---

## Vercel (recommended for launch)

Zero-dashboard setup: everything the deploy needs already lives in
`vercel.json` at the repo root.

### One-time setup (~2 minutes)

1. Go to [vercel.com/new](https://vercel.com/new) and sign in with GitHub.
2. **Import** the `Resolutefemi/Renance` repository.
3. Vercel reads `vercel.json` automatically. Both dashboard shapes now work:
   - **Framework Preset:** `Other` is declared in `vercel.json`
     (`"framework": null`), so the static export is uploaded as plain
     files and the Next.js builder never runs. If the dashboard still
     shows `Next.js` explicitly set, switch it to `Other` once.
   - **Root Directory:** either leave it **empty** (repo root, the
     root `vercel.json` applies) or set it to `apps/web` (its own
     `vercel.json` applies). Both carry the same settings; the only
     difference is the paths inside the build command.
   - Everything else (install / build / output) is already in vercel.json.
4. Press **Deploy**. First build takes ~4–6 minutes (it bakes the whole
   question bank into the export).

#### Why the build used to fail on Vercel (fixed)

The site is a static export (`output: 'export'`), so `next build` writes
plain files into `apps/web/out/`. Vercel's Next.js preset ends every
build by reading `<outputDirectory>/routes-manifest.json`, a file a
static export never produces, so the deploy died with
`The file ".../out/routes-manifest.json" couldn't be found` even though
the build itself was green. Two fixes landed together:

- `vercel.json` declares `"framework": null`: the export is deployed as
  static files, no Next.js builder involved.
- `scripts/web_bundles.py` bakes a minimal `public/routes-manifest.json`
  which the export copies into `out/`, so even a project still pinned to
  the Next.js preset finds the manifest and deploys fine.

That's it — no environment variables required in the dashboard, because
vercel.json ships sane defaults:

| Variable | Default | Meaning |
|---|---|---|
| `NEXT_PUBLIC_BASE_PATH` | *(empty)* | Vercel serves at the root, unlike GitHub Pages' `/Renance/` |
| `NEXT_PUBLIC_API_BASE` | `https://renance-api.onrender.com` | The web app talks to the Render study API **directly**. The Render `WEB_ORIGIN` allowlist carries `https://renance-edtech.vercel.app`, so CORS answers every call. The old same-origin `/api` rewrite is gone on purpose: with `trailingSlash: true` every extension-less path gets redirected to its trailing-slash form, the rewrite never fired, and the Go router 404s trailing slashes anyway. |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | `850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4...` | The web OAuth client. Baked at build time so the Google button renders on `/login` and `/register`. One manual step lives in Google Cloud Console: the deployment origin (`https://renance-edtech.vercel.app`) must be listed under the client's **Authorized JavaScript origins**, or Google shows its own `Error 401: invalid_client`. |
| `NEXT_PUBLIC_SITE_URL` | `https://renance-edtech.vercel.app` | Used for canonical/OG/sitemap URLs. Change it once a custom domain exists. |

These ride a small build wrapper, `scripts/vercel-build.sh`: it exports the
four variables (with these exact defaults) before running the same build CI
runs, so the values are baked into the client bundle at compile time.
vercel.json itself stays schema clean: its top level forbids unknown keys,
and the deprecated `build.env` block is rejected as an unknown top-level
key, which is exactly how the second deploy died in config validation.
Anything set in the Vercel dashboard overrides the wrapper defaults, so the
dashboard remains the place for future overrides.

### Optional (recommended before sharing publicly)

Add these in Vercel → Settings → Environment Variables so AI features
(Explanations, AI Generator, Tutor) work from the browser:

- `NEXT_PUBLIC_AI_API_KEY` — the Gemini provider key (same one the study
  API uses). Without it every AI surface degrades gracefully; the core
  CBT/Study/Review app does not depend on it.
- `NEXT_PUBLIC_AI_BASE_URL` / `NEXT_PUBLIC_AI_MODEL` — only if you rotated
  providers; defaults already match the study API.

### Custom domain

Vercel → Settings → Domains → add the domain, follow the DNS instructions,
then set `NEXT_PUBLIC_SITE_URL` to `https://<your-domain>` and redeploy once.

### Why this shape is hard to break

- The build is the **exact same command CI runs** (`web_bundles.py` +
  `next build`); if GitHub Pages builds green, Vercel builds green.
- Static export means no server runtime, no Node process, no cold starts
  for the site itself — the browser calls the Render API directly and the
  Render `WEB_ORIGIN` allowlist answers the CORS handshake.
- Every GitHub Pages push stays untouched; both deploys can run in
  parallel from the same `main` branch.

---

## GitHub Pages (status quo, unchanged)

Already automated: `.github/workflows/web-deploy.yml` builds and publishes
on every push to `main` that touches `apps/web/**`. Source must be
"GitHub Actions" in repo Settings → Pages. Repo variables:
`PUBLIC_API_BASE` (the https study API), optional `NEXT_PUBLIC_GOOGLE_CLIENT_ID`,
`AI_API_KEY`.

---

## Local production check (run before pushing)

```bash
pnpm install --frozen-lockfile
python3 scripts/web_bundles.py
cd apps/web && NEXT_PUBLIC_API_BASE=https://renance-api.onrender.com pnpm exec next build
npx serve out   # or any static file server
```
