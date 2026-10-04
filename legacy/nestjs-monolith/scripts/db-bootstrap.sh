#!/usr/bin/env bash
# Applies every db/sql/*.sql file, in order, to your Neon database.
# Uses DATABASE_URL from the environment or from .env at repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

DB_URL="${DATABASE_URL:-}"
if [ -z "$DB_URL" ]; then
  echo "ERROR: DATABASE_URL is not set."
  echo "  1) create a free project at https://neon.tech"
  echo "  2) copy the POOLED connection string into .env as DATABASE_URL"
  echo "  3) re-run: bash scripts/db-bootstrap.sh"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Manual path:"
  echo "  Open the Neon Console -> SQL Editor -> paste the contents of:"
  for f in "$ROOT"/db/sql/*.sql; do
    echo "    - ${f#$ROOT/}"
  done
  exit 0
fi

for f in "$ROOT"/db/sql/*.sql; do
  echo "[bootstrap] applying ${f#$ROOT/}"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done

echo "[bootstrap] done - schemas core/cbt/school/sme/skills/utilities/payroll/audit ready."
