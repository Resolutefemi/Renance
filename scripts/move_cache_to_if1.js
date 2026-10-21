#!/usr/bin/env node
/*
 * Move the lesson cache off InsForge #2 (6zctb6jv, free 500 MB tier,
 * currently 901 MB - over the line) onto InsForge #1 (dbeqj4dx, the
 * user mirror, ~28 MB used), bounded so #1 stays comfortably inside
 * its own free tier. Newest lessons first (generated_at DESC), stop at
 * the byte budget, then drop the 887 MB table off #2.
 *
 * Founder directives 2026-10-16:
 *   "don't use insforge #2 for lesson cache only use #1"
 *   "that insforge #2 is free tier 500MB I'm wondering how it stored 900MB"
 */
const { Client } = require('pg');

const SRC = 'postgresql://postgres:887095676c6726afd1fe5a5371a27e5d@6zctb6jv.us-east.database.insforge.app:5432/insforge?sslmode=require';
const DST = 'postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require';
const BUDGET_BYTES = 370 * 1048576; // lessons table+toast+idx ceiling on #1
const BATCH = 80;

const mb = (b) => (Number(b) / 1048576).toFixed(1) + 'MB';

(async () => {
  const src = new Client({ connectionString: SRC });
  const dst = new Client({ connectionString: DST });
  await src.connect();
  await dst.connect();

  // 0. Facts
  const srcSize = await src.query(`SELECT pg_database_size(current_database()) AS b`);
  const total = await src.query(`SELECT count(*)::int AS n, coalesce(sum(pg_column_size((notes,quiz,drawings,key_points,summary,title,topic_id,source,generated_at,hit_count)::text)::bigint),0) AS est FROM learn.lessons`);
  console.log(`source db: ${mb(srcSize.rows[0].b)} | lessons rows: ${total.rows[0].n}`);

  // 1. Target table, FK-free (learn.topics was reaped off #1; the cache
  //    engine never needed the FK - the API boot migration recreates
  //    empty catalog scaffolding itself).
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

  const existing = await dst.query(`SELECT count(*)::int AS n FROM learn.lessons`);
  let size = await dst.query(`SELECT pg_total_relation_size('learn.lessons') AS b`);
  console.log(`target pre-state: ${existing.rows[0].n} rows, ${mb(size.rows[0].b)}`);

  if (Number(size.rows[0].b) < BUDGET_BYTES) {
    // 2. Stream newest-first, batch-insert until the budget bites.
    const cur = await src.query(`SELECT topic_id, title, summary, notes, key_points, quiz, drawings, source, generated_at, hit_count FROM learn.lessons ORDER BY generated_at DESC`);
    const rows = cur.rows;
    console.log(`copying newest-first until ${mb(BUDGET_BYTES)}...`);
    let copied = 0, skippedConflict = 0;
    const cols = ['topic_id', 'title', 'summary', 'notes', 'key_points', 'quiz', 'drawings', 'source', 'generated_at', 'hit_count'];
    for (let i = 0; i < rows.length; i += BATCH) {
      const batch = rows.slice(i, i + BATCH);
      const values = [];
      const params = [];
      batch.forEach((r, j) => {
        const base = j * cols.length;
        values.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},$${base + 8},$${base + 9},$${base + 10})`);
        params.push(r.topic_id, r.title, r.summary, JSON.stringify(r.notes ?? []), JSON.stringify(r.key_points ?? []), JSON.stringify(r.quiz ?? []), JSON.stringify(r.drawings ?? []), r.source, r.generated_at, r.hit_count);
      });
      const res = await dst.query(
        `INSERT INTO learn.lessons (${cols.join(',')}) VALUES ${values.join(',')}
         ON CONFLICT (topic_id) DO NOTHING`,
        params,
      );
      copied += res.rowCount;
      skippedConflict += batch.length - res.rowCount;
      if ((i / BATCH) % 40 === 0) {
        const s = await dst.query(`SELECT pg_total_relation_size('learn.lessons') AS b`);
        process.stdout.write(`  ${i + batch.length}/${rows.length} rows, table ${mb(s.rows[0].b)}\n`);
      }
      const s2 = await dst.query(`SELECT pg_total_relation_size('learn.lessons') AS b`);
      if (Number(s2.rows[0].b) >= BUDGET_BYTES) {
        console.log(`budget reached at row ${i + batch.length}`);
        break;
      }
    }
    console.log(`copied ${copied} rows (skipped ${skippedConflict} existing)`);
  } else {
    console.log('budget already satisfied - skipping copy (resumable run)');
  }

  await dst.query(`ANALYZE learn.lessons`);
  const fin = await dst.query(`SELECT count(*)::int AS n, pg_total_relation_size('learn.lessons') AS t FROM learn.lessons`);
  const db1 = await dst.query(`SELECT pg_database_size(current_database()) AS b`);
  console.log(`target final: ${fin.rows[0].n} lessons, table ${mb(fin.rows[0].t)}, db ${mb(db1.rows[0].b)}`);

  // 3. Sanity: sample lessons parse (notes/quiz are valid JSON arrays)
  const sample = await dst.query(`SELECT topic_id, jsonb_array_length(notes) AS n, jsonb_array_length(quiz) AS q FROM learn.lessons ORDER BY generated_at DESC LIMIT 5`);
  for (const r of sample.rows) console.log(`  sample ${r.topic_id}: ${r.n} notes, ${r.q} quiz`);

  // 4. Free #2: drop the 887 MB table (the API no longer points here).
  const srcCount = await src.query(`SELECT count(*)::int AS n FROM learn.lessons`);
  console.log(`source still holds ${srcCount.rows[0].n} rows - dropping learn.lessons on #2...`);
  await src.query(`DROP TABLE IF EXISTS learn.lessons`);
  const srcAfter = await src.query(`SELECT pg_database_size(current_database()) AS b`);
  console.log(`source db after drop: ${mb(srcAfter.rows[0].b)}`);

  await src.end();
  await dst.end();
  console.log('MOVE COMPLETE');
})().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
