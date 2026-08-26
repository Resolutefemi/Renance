import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema/index.ts',
  out: './drizzle',
  dbCredentials: {
    url:
      process.env.DATABASE_DIRECT_URL ??
      process.env.DATABASE_URL ??
      'postgresql://localhost:5432/renance',
  },
  // Table definitions themselves declare pgSchema('module'), so DDL lands in
  // the right schema automatically. Containers are made by db/sql bootstrap.
});
