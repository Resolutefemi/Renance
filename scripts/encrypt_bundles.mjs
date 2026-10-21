#!/usr/bin/env node
/**
 * encrypt_bundles.mjs — the static-bundle SHIELD bake step (founder
 * directive 2026-10-11: "no agentic AI may scrape my 200,000+ past
 * questions").
 *
 * Runs right after scripts/web_bundles.py and rewrites every plain
 * bundle in apps/web/public/bundles/ IN PLACE as:
 *
 *   { "v":1, "kid":<id>, "alg":"A256GCM", "n":<b64 iv>, "ct":<b64 ct+tag> }
 *
 * Key derivation is IDENTICAL on all three sides (this script, the
 * study API's internal/httpapi/botshield.go bundleKeyFor, and the
 * browser's lib/bundle-crypto.ts via GET /bundles/key?code=):
 *
 *   key = HMAC-SHA256(master, "renance-bundle/v1|" + code)
 *
 * The master secret arrives via the BUNDLE_MASTER_KEY env var (64 hex
 * chars). It is NEVER committed: Vercel build env / GitHub Actions
 * secret on the web side, Render env on the API side.
 *
 * Fail-closed: without the secret the script exits non-zero BEFORE
 * any deploy can ship plain question JSON (set ALLOW_PLAIN=1 for local
 * dev to skip encryption).
 *
 * Also plants the honeypot listing (bundles/index.json) that only an
 * enumerator would ever read: every code in it is a decoy that strikes
 * the requesting account at the API (see botshield.go honeypotCodes).
 */
import { createHmac, createCipheriv, createDecipheriv, randomFillSync } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, existsSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'apps', 'web', 'public', 'bundles');

const MASTER_HEX = (process.env.BUNDLE_MASTER_KEY ?? '').trim();
const KEY_ID = (process.env.BUNDLE_KEY_ID ?? 'k1').trim() || 'k1';
const ALLOW_PLAIN = process.env.ALLOW_PLAIN === '1';

if (!/^[0-9a-fA-F]{64}$/.test(MASTER_HEX)) {
  if (ALLOW_PLAIN) {
    console.log('encrypt_bundles: ALLOW_PLAIN=1, shipping PLAIN bundles (dev only)');
    process.exit(0);
  }
  console.error(
    'encrypt_bundles: BUNDLE_MASTER_KEY missing or malformed (need 64 hex chars). ' +
      'Refusing to ship plain question JSON to the public CDN. ' +
      'Set the secret in the build environment (same value as the Render API env).'
  );
  process.exit(2);
}
const MASTER = Buffer.from(MASTER_HEX, 'hex');

/** Must stay byte-identical to botshield.go bundleKeyFor + the API. */
function deriveKey(code) {
  return createHmac('sha256', MASTER).update(`renance-bundle/v1|${code}`).digest();
}

function encrypt(plainText, code) {
  const key = deriveKey(code);
  const iv = Buffer.alloc(12);
  cryptoFill(iv);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ct = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    v: 1,
    kid: KEY_ID,
    alg: 'A256GCM',
    n: iv.toString('base64'),
    ct: Buffer.concat([ct, tag]).toString('base64'),
  };
}

function decrypt(blob, code) {
  const key = deriveKey(code);
  const buf = Buffer.from(blob.ct, 'base64');
  const iv = Buffer.from(blob.n, 'base64');
  const tag = buf.subarray(buf.length - 16);
  const ct = buf.subarray(0, buf.length - 16);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ct), decipher.final()]).toString('utf8');
}

/** Random 12-byte IV. */
function cryptoFill(buf) {
  randomFillSync(buf);
}

// ---------------------------------------------------------------- run

const manifest = JSON.parse(readFileSync(join(OUT, 'manifest.json'), 'utf8'));
let encrypted = 0;
let bytesPlain = 0;
let bytesCipher = 0;
const missing = [];

for (const exam of manifest.exams) {
  const code = exam.code;
  const file = join(OUT, `${code}.json`);
  if (!existsSync(file)) {
    missing.push(code);
    continue;
  }
  const plain = readFileSync(file, 'utf8');
  const blob = JSON.stringify(encrypt(plain, code));
  writeFileSync(file, blob);
  encrypted += 1;
  bytesPlain += Buffer.byteLength(plain);
  bytesCipher += Buffer.byteLength(blob);
}

if (encrypted === 0) {
  console.error('encrypt_bundles: nothing to encrypt - did web_bundles.py run?');
  process.exit(2);
}

// Round-trip verification on the first bank: a bake that cannot decrypt
// itself must never deploy.
const sample = manifest.exams[0].code;
const blob = JSON.parse(readFileSync(join(OUT, `${sample}.json`), 'utf8'));
const roundTrip = JSON.parse(decrypt(blob, sample));
if (!Array.isArray(roundTrip.questions) || roundTrip.questions.length === 0) {
  console.error(`encrypt_bundles: round-trip verification FAILED on ${sample}`);
  process.exit(2);
}
console.log(
  `encrypt_bundles: ${encrypted} bundles encrypted (kid=${KEY_ID}), ` +
    `round-trip OK on ${sample} (${roundTrip.questions.length} questions), ` +
    `${(bytesPlain / 1e6).toFixed(1)} MB plain -> ${(bytesCipher / 1e6).toFixed(1)} MB ciphertext`
);

// Honeypot listing: a "hidden" index no legitimate client ever reads
// (the app navigates via manifest.json). Scrapers that enumerate
// directory listings find it, ask the API for its decoy codes, and get
// poisoned canary banks + account strikes (botshield.go honeypotCodes).
const DECOYS = [
  'jamb-english-x9',
  'jamb-maths-superset',
  'waec-physics-2015-all',
  'neco-biology-complete',
  'all-questions-dump',
  'renance-full-bank',
  'jamb-questions-master',
  'waec-answers-key-all',
  'uniosun-mth106-bank',
  'unical-gst112-key',
];
writeFileSync(
  join(OUT, 'index.json'),
  JSON.stringify({ generatedAt: new Date().toISOString(), bundles: DECOYS })
);

// Sweep any pre-shield plain leftovers that are NOT in the manifest
// (stale files from older bakes must never ship readable).
for (const f of readdirSync(OUT)) {
  if (!f.endsWith('.json') || f === 'manifest.json' || f === 'index.json') continue;
  const code = f.replace(/\.json$/, '');
  if (!manifest.exams.some((e) => e.code === code)) {
    rmSync(join(OUT, f));
    console.log(`encrypt_bundles: swept stale plain file ${f}`);
  }
}

if (missing.length) {
  console.error('encrypt_bundles: MISSING bundles for:', missing.join(', '));
  process.exit(2);
}
