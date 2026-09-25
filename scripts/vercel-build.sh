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
set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

: "${NEXT_PUBLIC_BASE_PATH:=}"
: "${NEXT_PUBLIC_API_BASE:=https://renance-api.onrender.com}"
: "${NEXT_PUBLIC_GOOGLE_CLIENT_ID:=850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com}"
: "${NEXT_PUBLIC_SITE_URL:=https://renance-edtech.vercel.app}"
export NEXT_PUBLIC_BASE_PATH NEXT_PUBLIC_API_BASE NEXT_PUBLIC_GOOGLE_CLIENT_ID NEXT_PUBLIC_SITE_URL

python3 scripts/web_bundles.py
pnpm --filter @renance/web exec next build
rm -rf apps/web/out/pdfs
