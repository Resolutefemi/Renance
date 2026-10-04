import { customType } from 'drizzle-orm/pg-core';

/**
 * citext — case-insensitive text. Backed by the citext extension our Neon
 * bootstrap SQL enables (db/sql/00_bootstrap_schemas.sql).
 *
 * Why citext instead of lower(email) tricks: uniqueness becomes case-
 * insensitive AT THE DATABASE, so Ada@X.com and ada@x.com can never both
 * exist even under concurrent inserts.
 */
export const citext = customType<{ data: string; driverData: string }>({
  dataType() {
    return 'citext';
  },
});
