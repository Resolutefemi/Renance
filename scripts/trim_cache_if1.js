#!/usr/bin/env node
/* Trim the lesson cache on InsForge #1 so the DATABASE size sits
 * comfortably under the new 430 MB cap (the guard probes
 * pg_database_size, so the whole db counts, not just the table).
 * Oldest lessons go first; VACUUM FULL returns the bytes to the OS. */
const { Client } = require('pg');
const mb = (b) => (Number(b) / 1048576).toFixed(1) + 'MB';
const TARGET_DROP = 5200; // ~60 MB of rows

(async () => {
  const c = new Client({ connectionString: 'postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require' });
  await c.connect();
  const before = await c.query(`SELECT (SELECT count(*)::int FROM learn.lessons) AS n, pg_database_size(current_database()) AS db, pg_total_relation_size('learn.lessons') AS t`);
  console.log(`before: ${before.rows[0].n} lessons, table ${mb(before.rows[0].t)}, db ${mb(before.rows[0].db)}`);

  const del = await c.query(
    `DELETE FROM learn.lessons WHERE topic_id IN (
       SELECT topic_id FROM learn.lessons ORDER BY generated_at ASC LIMIT $1)`, [TARGET_DROP]);
  console.log('dropped rows:', del.rowCount);

  console.log('vacuum full (may take a minute)...');
  await c.query(`VACUUM (FULL, ANALYZE) learn.lessons`);

  const after = await c.query(`SELECT (SELECT count(*)::int FROM learn.lessons) AS n, pg_database_size(current_database()) AS db, pg_total_relation_size('learn.lessons') AS t`);
  console.log(`after: ${after.rows[0].n} lessons, table ${mb(after.rows[0].t)}, db ${mb(after.rows[0].db)}`);
  await c.end();
})().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
