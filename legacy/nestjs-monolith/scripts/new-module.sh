#!/usr/bin/env bash
# Creates the skeleton for a FUTURE Renance module (used from Phase 3 onward):
#   bash scripts/new-module.sh <name>
set -euo pipefail

MOD="${1:-}"
if [ -z "$MOD" ]; then
  echo "usage: bash scripts/new-module.sh <module-name>   e.g. school"
  exit 1
fi
case "$MOD" in
  *[!a-z0-9-]*|"") echo "module name must be lowercase kebab-case" ; exit 1 ;;
esac

CLASS="$(printf '%s' "$MOD" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"

mkdir -p "apps/api/src/modules/${MOD}" "packages/db/src/schema"

cat > "apps/api/src/modules/${MOD}/${MOD}.module.ts" <<MOD_TS_EOF
import { Module } from '@nestjs/common';

@Module({
  controllers: [],
  providers: [],
  exports: [],
})
export class ${CLASS}Module {}
MOD_TS_EOF

cat > "packages/db/src/schema/${MOD}.ts" <<TS_EOF
import { pgSchema } from 'drizzle-orm/pg-core';

export const ${MOD} = pgSchema('${MOD}');
TS_EOF

BARREL="packages/db/src/schema/index.ts"
grep -q "./${MOD}" "$BARREL" || \
  printf "export * from './%s';\n" "$MOD" >> "$BARREL"

echo "module '${MOD}' created:"
echo "  - apps/api/src/modules/${MOD}/${MOD}.module.ts   (wire into app.module.ts imports[])"
echo "  - packages/db/src/schema/${MOD}.ts               (tables via Drizzle only)"
echo "checklist before coding:"
echo "  [ ] define tables in packages/db/src/schema/${MOD}.ts -> pnpm db:generate -> pnpm db:migrate (Drizzle emits CREATE SCHEMA itself)"
echo "  [ ] add ${CLASS}Module to apps/api/src/app.module.ts imports[]"
echo "  [ ] read docs/architecture.md boundary contract (2 min)"
