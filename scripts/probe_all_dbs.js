#!/usr/bin/env node
/* Probe all four Renance databases: sizes, schemas, lesson cache state. */
const { Client } = require('pg');

const DBS = {
  neon: 'postgresql://neondb_owner:npg_siaeB4m7IMUZ@ep-snowy-base-axf83q3b-pooler.c-4.us-east-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require',
  insforge1: 'postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require',
  insforge2: 'postgresql://postgres:887095676c6726afd1fe5a5371a27e5d@6zctb6jv.us-east.database.insforge.app:5432/insforge?sslmode=require',
};

async function probe(name, dsn) {
  const c = new Client({ connectionString: dsn, ssl: { rejectUnauthorized: false } });
  const out = { name };
  try {
    await c.connect();
    const size = await c.query(`SELECT pg_size_pretty(pg_database_size(current_database())) AS s, pg_database_size(current_database()) AS b`);
    out.size = size.rows[0].s;
    out.bytes = Number(size.rows[0].b);
    const schemas = await c.query(`SELECT nspname FROM pg_namespace WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast') ORDER BY 1`);
    out.schemas = schemas.rows.map((r) => r.nspname).join(',');
    const tables = await c.query(`SELECT schemaname, relname, pg_total_relation_size(schemaname||'.'||relname) AS sz FROM pg_stat_user_tables ORDER BY pg_total_relation_size(schemaname||'.'||relname) DESC LIMIT 8`);
    out.top_tables = tables.rows.map((r) => `${r.schemaname}.${r.relname}=${(Number(r.sz) / 1048576).toFixed(1)}MB`);
    // lessons specifics
    try {
      const l = await c.query(`SELECT count(*) AS n, pg_total_relation_size('learn.lessons') AS sz FROM learn.lessons`);
      out.lessons = `${l.rows[0].n} rows, ${(Number(l.rows[0].sz) / 1048576).toFixed(1)}MB`;
      const newest = await c.query(`SELECT created_at FROM learn.lessons ORDER BY created_at DESC LIMIT 1`);
      out.newest_lesson = newest.rows[0]?.created_at ?? null;
    } catch (e) { out.lessons = 'n/a (' + e.message.split('\n')[0] + ')'; }
    const users = await c.query(`SELECT count(*) AS n FROM public.users`).catch(() => null);
    if (users) out.users = users.rows[0].n;
    // largest table total size vs plan hints
    const total = await c.query(`SELECT pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||relname))::bigint) AS t FROM pg_stat_user_tables`);
    out.user_tables_total = total.rows[0].t;
  } catch (e) {
    out.error = e.message.split('\n')[0];
  } finally {
    try { await c.end(); } catch {}
  }
  return out;
}

(async () => {
  for (const [name, dsn] of Object.entries(DBS)) {
    const r = await probe(name, dsn);
    console.log('=== ' + name.toUpperCase() + ' ===');
    for (const [k, v] of Object.entries(r)) {
      if (k !== 'name') console.log(`  ${k}: ${Array.isArray(v) ? '\n    ' + v.join('\n    ') : v}`);
    }
  }
})();
