import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

/**
 * One Drizzle client per process. prepare:false is REQUIRED against Neon's
 * pooled endpoint (PgBouncer protocol limitations).
 */
export function createDb(url: string) {
  const client = postgres(url, { prepare: false, max: 10 });
  return { db: drizzle(client), client };
}

export type Db = ReturnType<typeof createDb>;
