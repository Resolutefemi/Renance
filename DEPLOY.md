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
3. Vercel reads `vercel.json` automatically. Configure exactly this:
   - **Framework Preset:** `Other` (it will preselect it once vercel.json is
     detected — if it says Next.js, switch it to `Other` so the custom
     build command and `apps/web/out` output directory win).
   - **Root Directory:** leave **empty** (repo root — the build command
     needs `scripts/web_bundles.py`).
   - Everything else (install / build / output) is already in vercel.json.
4. Press **Deploy**. First build takes ~4–6 minutes (it bakes the whole
   question bank into the export).

That's it — no environment variables required in the dashboard, because
vercel.json ships sane defaults:

| Variable | Default | Meaning |
|---|---|---|
| `NEXT_PUBLIC_BASE_PATH` | *(empty)* | Vercel serves at the root, unlike GitHub Pages' `/Renance/` |
| `NEXT_PUBLIC_API_BASE` | `/api` | **API proxy.** Vercel rewrites `/api/*` to the Render study API (`renance-api.onrender.com`) server-side — same-origin calls, **zero CORS configuration, no Render `WEB_ORIGIN` edit needed** |
| `NEXT_PUBLIC_SITE_URL` | `https://renance.vercel.app` | Used for canonical/OG/sitemap URLs. **Change this** in Vercel → Project → Settings → Environment Variables after you know the final domain (the `*.vercel.app` name Vercel assigns, or your custom domain). Dashboard values override the vercel.json defaults. |

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
  for the site itself — only the `/api` proxy talks to Render.
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
