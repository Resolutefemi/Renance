#!/bin/sh
# vercel-build.sh - the one build command the Vercel deployment runs.
#
# Why this exists: a static export bakes NEXT_PUBLIC_* variables into the
# client bundle at compile time, so they must be present in the build
# environment. vercel.json has no modern, schema-valid way to declare
# build-time env (the old "build.env" block was rejected as an unknown
# top-level key and the deployment failed config validation), so this
# wrapper exports the values itself. Defaults keep the zero-dashboard
# deploy promise; anything already set in the Vercel dashboard wins.
#
# The script is cwd agnostic: it resolves the repo root whether the
# project runs from the repo root (root vercel.json) or from apps/web
# (its own vercel.json), then builds exactly what CI builds.
#
# GitHub Pages retired (founder directive, 2026-09-30): the site and the
# 2,000+ university past-question PDFs both ship from THIS deployment.
# The old `rm -rf apps/web/out/pdfs` + proxy-rewrite to
# resolutefemi.github.io left every /pdfs/ link 404 once Pages went
# dark; the PDFs now ride the static export directly.
set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

: "${NEXT_PUBLIC_BASE_PATH:=}"
: "${NEXT_PUBLIC_API_BASE:=https://renance-api.onrender.com}"
: "${NEXT_PUBLIC_GOOGLE_CLIENT_ID:=850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com}"
: "${NEXT_PUBLIC_SITE_URL:=https://renance.app}"
export NEXT_PUBLIC_BASE_PATH NEXT_PUBLIC_API_BASE NEXT_PUBLIC_GOOGLE_CLIENT_ID NEXT_PUBLIC_SITE_URL

# 2026-10-11 SHIELD: bundles bake plain then get AES-256-GCM encrypted
# in place with the per-bank key derived from BUNDLE_MASTER_KEY (same
# secret as the Render API env). Fail-closed: no secret = no deploy.
#
# 2026-10-11 ACTIVATION (founder directive: "put it yourself in
# render.yaml" - i.e. no manual dashboard step anywhere): the master
# key defaults HERE too, identical to the value in render.yaml. A
# dashboard-set BUNDLE_MASTER_KEY (if one is ever added) still wins,
# same as the NEXT_PUBLIC_* defaults above. The repo is public: no key lives here any more.
# Set BUNDLE_MASTER_KEY in the Vercel dashboard; the old committed
# value was exposed and must be rotated.
: "${BUNDLE_MASTER_KEY:?BUNDLE_MASTER_KEY is not set - add it in the Vercel dashboard (same rotated value as the Render API env)}"
: "${BUNDLE_KEY_ID:=k1}"
export BUNDLE_MASTER_KEY BUNDLE_KEY_ID
python3 scripts/web_bundles.py
node scripts/encrypt_bundles.mjs
# 2026-10-12 STATIC ASSET SHIELD (founder directive: "I told someone my
# past questions on the web have no rate limit - is that true? work on
# it"): the /pdfs shelf (2,026 past-question PDFs, 322MB) and the
# school-corpus schemes/notes ship as AES-256-GCM ciphertext too, keyed
# per path, keys delivered through the SAME metered /bundles/key route.
# Fails the build (exit 3) if the walked file set drifted from the
# committed data/static_registry.json - no asset can ship whose key the
# API would refuse. Regenerate with: node scripts/encrypt_pdfs.mjs
# --refresh (then commit the registry).
node scripts/encrypt_pdfs.mjs
pnpm --filter @renance/web exec next build
