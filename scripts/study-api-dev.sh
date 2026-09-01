#!/usr/bin/env bash
# Renance study-api dev boot. Usage: pnpm api:dev  (from repo root)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DATABASE_URL:?set DATABASE_URL (Neon console → connection string, or local Postgres)}"
export PORT="${PORT:-3990}"
export JWT_SECRET="${JWT_SECRET:-dev-only-secret-change-me}"
export DATA_DIR="${DATA_DIR:-$(pwd)/data}"

exec go run -C apps/study-api ./cmd/api
