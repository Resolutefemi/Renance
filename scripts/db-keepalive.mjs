#!/usr/bin/env node
// db-keepalive.mjs - one authenticated action on EVERY fallback
// database so no free-tier project is ever idle long enough to be
// paused (founder directive 2026-10-15: "make sure Supabase and
// insforge are not inactive, make sure an action is taken every 6
// days, so that they will not be paused").
//
// Per provider it does:
//   1. Postgres wire ping: SELECT 1 + CREATE TABLE IF NOT EXISTS
//      public.db_keepalive + INSERT a heartbeat row (the row is VISIBLE
//      in the Supabase table editor - "I can't find anything in
//      Supabase table yet" - and on InsForge).
//   2. Supabase only: an authenticated REST request (API-side activity
//      counts toward the free project's activity metric too).
//
// Env (GitHub Actions secrets):
//   SUPABASE_DATABASE_URL  - pooled DSN (aws-1-eu-west-3…:5432)
//   SUPABASE_URL           - https://zfxrmcwdnmmxjawmsiyp.supabase.co
//   SUPABASE_SECRET_KEY    - sb_secret_… (REST ping)
//   INSFORGE_DATABASE_URL  - the lesson cache DSN (the founder's
//                            first InsForge, dbeqj4dx - since the
//                            2026-10-16 cache move the cache and the
//                            user mirror share this database)
//   INSFORGE_MIRROR_DATABASE_URL - the user mirror DSN (the first
//                            InsForge, dbeqj4dx) - optional; when set
//                            both InsForge projects get their wire
//                            ping every run
//   KEEPALIVE_OUT          - where to write last-run.json
//                            (default: <cwd>/supabase/keepalive/last-run.json)
//
// A missing secret for ONE provider is a warning; the run fails only
// when ZERO databases answered. Neon is NEVER contacted - the script
// has no Neon credential and no path to one.

import pg from 'pg';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const out = process.env.KEEPALIVE_OUT
  ? resolve(process.env.KEEPALIVE_OUT)
  : resolve(process.cwd(), 'supabase/keepalive/last-run.json');

const ranAt = new Date().toISOString();
const results = [];
const log = (...a) => console.log(...a);

async function wirePing(provider, dsn) {
  if (!dsn) {
    log(`SKIP  ${provider}: DSN secret not set`);
    results.push({ provider, via: 'postgres-wire', ok: false, skipped: true, note: 'DSN not set' });
    return;
  }
  // Strip any sslmode=… from the DSN: node-pg 8.16+ maps 'require' to
  // verify-full and the supavisor pooler presents a chain node does not
  // trust ("self-signed certificate in certificate chain"), which would
  // kill the ping. The explicit ssl option below governs TLS instead.
  const bare = dsn.replace(/[?&]sslmode=[^&]*/g, '');
  const client = new pg.Client({
    connectionString: bare,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 20000,
  });
  try {
    await client.connect();
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.db_keepalive (
        id        bigserial PRIMARY KEY,
        provider  text        NOT NULL,
        via       text        NOT NULL,
        ok        boolean     NOT NULL,
        note      text,
        pinged_at timestamptz NOT NULL DEFAULT now()
      )`);
    const v = await client.query('SELECT version()');
    const note = String(v.rows[0].version).split(' ').slice(0, 2).join(' ');
    await client.query(
      'INSERT INTO public.db_keepalive (provider, via, ok, note) VALUES ($1, $2, true, $3)',
      [provider, 'postgres-wire', note],
    );
    await client.end();
    log(`OK    ${provider}: wire ping + heartbeat row (${note})`);
    results.push({ provider, via: 'postgres-wire', ok: true, note });
  } catch (e) {
    try { await client.end(); } catch { /* already closed */ }
    log(`FAIL  ${provider}: ${String(e.message).slice(0, 140)}`);
    results.push({ provider, via: 'postgres-wire', ok: false, note: String(e.message).slice(0, 140) });
  }
}

async function supabaseRestPing() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) {
    log('SKIP  supabase REST: SUPABASE_URL / SUPABASE_SECRET_KEY not set');
    results.push({ provider: 'supabase', via: 'rest', ok: false, skipped: true, note: 'secrets not set' });
    return;
  }
  try {
    const res = await fetch(`${url.replace(/\/+$/, '')}/rest/v1/`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
    });
    log(`OK    supabase REST: HTTP ${res.status}`);
    results.push({ provider: 'supabase', via: 'rest', ok: res.ok, note: `HTTP ${res.status}` });
  } catch (e) {
    log(`FAIL  supabase REST: ${String(e.message).slice(0, 140)}`);
    results.push({ provider: 'supabase', via: 'rest', ok: false, note: String(e.message).slice(0, 140) });
  }
}

await wirePing('supabase', process.env.SUPABASE_DATABASE_URL);
await supabaseRestPing();
await wirePing('insforge-cache', process.env.INSFORGE_DATABASE_URL);
await wirePing('insforge-mirror', process.env.INSFORGE_MIRROR_DATABASE_URL);

try {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, `${JSON.stringify({ ran_at: ranAt, results }, null, 2)}\n`);
  log(`heartbeat file: ${out}`);
} catch (e) {
  log(`WARN  could not write the heartbeat file: ${e.message}`);
}

const answered = results.filter((r) => r.ok).length;
const providersOk = new Set(results.filter((r) => r.ok).map((r) => r.provider));
log(`RESULT: ${answered}/${results.length} checks ok - providers alive: ${[...providersOk].join(', ') || 'NONE'}`);
process.exit(providersOk.size > 0 ? 0 : 1);
