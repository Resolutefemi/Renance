#!/usr/bin/env node
/*
 * Move the lesson cache #2 -> #1 VIA DBLINK (server-to-server inside
 * Insforge's own network - the sandbox link proved far too slow).
 * Runs the INSERT on #1, PULLing the newest N rows from #2 in chunks.
 * Then drops the 887 MB table off #2.
 */
const { Client } = require('pg');

const DST = 'postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require';
const SRC_HOST = '6zctb6jv.us-east.database.insforge.app';
const SRC_PASS = '887095676c6726afd1fe5a5371a27e5d';
const BUDGET_MB = 370;             // lessons table ceiling on #1
const CHUNK = 4000;
const mb = (b) => (Number(b) / 1048576).toFixed(1) + 'MB';

(async () => {
  const dst = new Client({ connectionString: DST });
  await dst.connect();
  await dst.query(`CREATE EXTENSION IF NOT EXISTS dblink`);
  const connStr = `host=${SRC_HOST} port=5432 dbname=insforge user=postgres password=${SRC_PASS} sslmode=require`;
  await dst.query(`SELECT dblink_connect('src', $1)`, [connStr]);
  console.log('dblink #1 -> #2 connected');

  // Target table (FK-free: learn.topics lives only on #2; boot
  // migrations recreate empty catalog scaffolding on their own).
  await dst.query(`
    CREATE TABLE IF NOT EXISTS learn.lessons (
      topic_id     TEXT PRIMARY KEY,
      title        TEXT NOT NULL DEFAULT '',
      summary      TEXT NOT NULL DEFAULT '',
      notes        JSONB NOT NULL DEFAULT '[]',
      key_points   JSONB NOT NULL DEFAULT '[]',
      quiz         JSONB NOT NULL DEFAULT '[]',
      drawings     JSONB NOT NULL DEFAULT '[]',
      source       TEXT NOT NULL DEFAULT 'zai-glm',
      generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      hit_count    INT NOT NULL DEFAULT 0
    )`);

  const srcTotal = await dst.query(`SELECT count(*)::int AS n FROM dblink('src', 'SELECT count(*) FROM learn.lessons') AS t(n int)`);
  console.log('source lessons rows:', srcTotal.rows[0].n);

  let copied = 0;
  for (let off = 0; ; off += CHUNK) {
    const r = await dst.query(
      `INSERT INTO learn.lessons (topic_id, title, summary, notes, key_points, quiz, drawings, source, generated_at, hit_count)
       SELECT topic_id, title, summary, notes, key_points, quiz, drawings, source, generated_at, hit_count
       FROM dblink('src',
         'SELECT topic_id, title, summary, notes, key_points, quiz, drawings, source, generated_at, hit_count
          FROM learn.lessons ORDER BY generated_at DESC LIMIT ${CHUNK} OFFSET ${off}')
       AS t(topic_id text, title text, summary text, notes jsonb, key_points jsonb, quiz jsonb, drawings jsonb, source text, generated_at timestamptz, hit_count int)
       ON CONFLICT (topic_id) DO NOTHING`,
    );
    copied += r.rowCount;
    const size = await dst.query(`SELECT pg_total_relation_size('learn.lessons') AS b`);
    const tableMB = Number(size.rows[0].b) / 1048576;
    console.log(`chunk @${off}: +${r.rowCount} rows, table ${mb(size.rows[0].b)}`);
    if (r.rowCount === 0) break;
    if (tableMB >= BUDGET_MB) { console.log('budget reached'); break; }
  }

  await dst.query(`ANALYZE learn.lessons`);
  const fin = await dst.query(`SELECT count(*)::int AS n, pg_total_relation_size('learn.lessons') AS t FROM learn.lessons`);
  const db1 = await dst.query(`SELECT pg_database_size(current_database()) AS b`);
  console.log(`#1 final: ${fin.rows[0].n} lessons, table ${mb(fin.rows[0].t)}, db ${mb(db1.rows[0].b)}`);

  // sanity: notes/quiz arrays parse on samples
  const sample = await dst.query(`SELECT topic_id, jsonb_array_length(notes) AS n, jsonb_array_length(quiz) AS q FROM learn.lessons ORDER BY generated_at DESC LIMIT 3`);
  for (const s of sample.rows) console.log(`  sample ${s.topic_id}: ${s.n} notes / ${s.q} quiz`);

  // Free #2: the cache no longer lives there.
  const drop = await dst.query(`SELECT dblink_exec('src', 'DROP TABLE IF EXISTS learn.lessons')`);
  console.log('drop on #2:', drop.rows[0].dblink_exec);
  const srcAfter = await dst.query(`SELECT pg_database_size(current_database())::text FROM dblink('src', 'SELECT pg_database_size(current_database())') AS t(x bigint)`);
  console.log(`#2 db after drop: ${mb(srcAfter.rows[0].x)}`);

  await dst.query(`SELECT dblink_disconnect('src')`);
  await dst.end();
  console.log('MOVE COMPLETE');
})().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
