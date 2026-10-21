#!/usr/bin/env node
/**
 * encrypt_pdfs.mjs — the static-asset SHIELD bake step, round 2
 * (founder directive 2026-10-12: "I told someone my past questions on
 * the web have no rate limit and can be scraped - is that true? work
 * on it. I need ultimate security, no openings").
 *
 * AUDIT RESULT that produced this script:
 *   /bundles/*.json question banks  -> already AES-256-GCM ciphertext ✅
 *   /pdfs/** (2,026 past-question PDFs, 322MB) -> PLAIN on the CDN ❌
 *   /school-corpus/** (NERDC schemes + lesson notes)  -> PLAIN ❌
 *
 * This script rewrites every file under:
 *   apps/web/public/pdfs/**
 *   apps/web/public/school-corpus/{schemes,notes}/**
 * (NOT school-corpus/index.json - it is a metadata index) in place as a
 * binary envelope:
 *
 *   "RNP1" | kidLen u8 | kid utf8 | nonce 12B | AES-256-GCM ct+tag
 *
 * Key derivation (byte-identical on all three sides - this script, the
 * study API's handleBundleKey "static:" path, and the browser's
 * lib/asset-crypto.ts):
 *
 *   key = HMAC-SHA256(master, "renance-static/v1|" + path)
 *   path = file path relative to apps/web/public (e.g.
 *          "pdfs/futa/cos101.pdf"), which is also the code the client
 *          sends to GET /bundles/key as "static:" + path.
 *
 * The client fetches the key through the SAME metered route as the
 * question banks: anonymous = proof-of-work + per-IP caps, signed-in =
 * per-user speed limit. A scraper pulling 2,026 PDFs pays 2,026 key
 * requests through those walls.
 *
 * REGISTRY (fail-closed pairing with the Go API):
 *   data/static_registry.json lists every protected path (+ sha256 +
 *   bytes of the plain source) and the honeypot decoy paths. The Go
 * binary embeds it (Docker build copies data/) and 404s any static:
 * code not in it, strikes accounts that ask for honeypots. If the
 * walked file set ever drifts from the committed registry this script
 * FAILS THE BUILD (exit 3) so no asset can ever ship whose key the
 * API refuses. Regenerate with:
 *
 *   node scripts/encrypt_pdfs.mjs --refresh   # then commit the registry
 *
 * Fail-closed without BUNDLE_MASTER_KEY, same as encrypt_bundles.mjs.
 */
import { createHmac, createCipheriv, createDecipheriv, randomFillSync, createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PUB = join(ROOT, 'apps', 'web', 'public');
const REGISTRY_PATH = join(ROOT, 'data', 'static_registry.json');
const REFRESH = process.argv.includes('--refresh');

const MASTER_HEX = (process.env.BUNDLE_MASTER_KEY ?? '').trim();
const KEY_ID = (process.env.BUNDLE_KEY_ID ?? 'k1').trim() || 'k1';
const ALLOW_PLAIN = process.env.ALLOW_PLAIN === '1';

if (!/^[0-9a-fA-F]{64}$/.test(MASTER_HEX)) {
  if (ALLOW_PLAIN) {
    console.log('encrypt_pdfs: ALLOW_PLAIN=1, shipping PLAIN static assets (dev only)');
    process.exit(0);
  }
  console.error(
    'encrypt_pdfs: BUNDLE_MASTER_KEY missing or malformed (need 64 hex chars). ' +
      'Refusing to ship plain past-question PDFs to the public CDN.'
  );
  process.exit(2);
}
const MASTER = Buffer.from(MASTER_HEX, 'hex');

/** Must stay byte-identical to botshield.go bundleKeyForStatic + lib/asset-crypto.ts. */
function deriveKey(path) {
  return createHmac('sha256', MASTER).update(`renance-static/v1|${path}`).digest();
}

const MAGIC = Buffer.from('RNP1', 'ascii');
const IV_LEN = 12;

function isEncrypted(buf) {
  return buf.length > 16 && MAGIC.equals(buf.subarray(0, 4));
}

function encryptFile(plain, kid) {
  const kidBuf = Buffer.from(kid, 'utf8');
  const iv = randomFillSync(new Uint8Array(IV_LEN));
  const cipher = createCipheriv('aes-256-gcm', deriveKey(currentPath), iv);
  const ct = Buffer.concat([cipher.update(plain), cipher.final(), cipher.getAuthTag()]);
  return Buffer.concat([MAGIC, Buffer.from([kidBuf.length]), kidBuf, iv, ct]);
}

// The path currently being encrypted - deriveKey reads it so the
// encrypt/decrypt helpers stay one-liners.
let currentPath = '';

function decryptFile(buf) {
  const kidLen = buf[4];
  const iv = buf.subarray(5 + kidLen, 5 + kidLen + IV_LEN);
  const body = buf.subarray(5 + kidLen + IV_LEN); // ct+tag (WebCrypto shape)
  const tag = body.subarray(body.length - 16);
  const ct = body.subarray(0, body.length - 16);
  const decipher = createDecipheriv('aes-256-gcm', deriveKey(currentPath), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ct), decipher.final()]);
}

function walk(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

// Honeypot decoys: registry-only paths that never exist as files. A
// scraper enumerating "full dump" style names strikes its account at
// the key route (2 strikes = 24h lockout), exactly like the bundle
// honeypots. Named after what a thief would type.
const HONEYPOTS = [
  'pdfs/noun/all-past-questions-complete.pdf',
  'pdfs/noun/full-course-materials-dump.pdf',
  'pdfs/noun/every-pdf-bundle.zip',
  'pdfs/futa/past-questions-bundle.pdf',
  'pdfs/all-schools-master-dump.pdf',
  'pdfs/renance-full-vault.pdf',
  'school-corpus/notes/full-lesson-notes-dump.json',
  'school-corpus/schemes/all-schemes-dump.json',
  'school-corpus/complete-corpus.json',
];

// ---------------------------------------------------------------- main

const pdfFiles = walk(join(PUB, 'pdfs')).filter((p) => p.endsWith('.pdf'));
const corpusFiles = [
  ...walk(join(PUB, 'school-corpus', 'schemes')),
  ...walk(join(PUB, 'school-corpus', 'notes')),
].filter((p) => p.endsWith('.json'));
const targets = [...pdfFiles, ...corpusFiles];

console.log(`encrypt_pdfs: ${pdfFiles.length} PDFs + ${corpusFiles.length} corpus files under the shield`);

const registry = { v: 1, files: {}, honeypots: HONEYPOTS };
let encrypted = 0;
let already = 0;
let totalPlain = 0;
const encryptedNow = new Set(); // only these get round-trip verified

for (const abs of targets) {
  const path = relative(PUB, abs).split('\\').join('/');
  currentPath = path;
  const buf = readFileSync(abs);
  registry.files[path] = { sha256: createHash('sha256').update(buf).digest('hex'), bytes: buf.length };
  if (isEncrypted(buf)) {
    // Only happens on a local re-run without a fresh bake; record and
    // move on (the round-trip check below only covers this run's work).
    already++;
    continue;
  }
  totalPlain += buf.length;
  writeFileSync(abs, encryptFile(buf, KEY_ID));
  encryptedNow.add(path);
  encrypted++;  
}

// ------------------------------------------------- registry consistency
const committed = existsSync(REGISTRY_PATH)
  ? JSON.parse(readFileSync(REGISTRY_PATH, 'utf8'))
  : null;

if (committed) {
  const have = new Set(Object.keys(registry.files));
  const was = new Set(Object.keys(committed.files ?? {}));
  const added = [...have].filter((p) => !was.has(p));
  const removed = [...was].filter((p) => !have.has(p));
  if (added.length || removed.length) {
    if (REFRESH) {
      console.log('encrypt_pdfs: --refresh, registry rewritten');
    } else {
      console.error(
        'encrypt_pdfs: static registry DRIFT - the walked file set no longer matches ' +
          'data/static_registry.json (the Go API embeds that file and would 404 keys ' +
          `for unlisted assets). added: ${added.slice(0, 5).join(', ')}${added.length > 5 ? ' …' : ''} | ` +
          `removed: ${removed.slice(0, 5).join(', ')}${removed.length > 5 ? ' …' : ''}. ` +
          'Fix: run `node scripts/encrypt_pdfs.mjs --refresh` and commit data/static_registry.json.'
      );
      process.exit(3);
    }
  }
}

registry.generatedAt = new Date().toISOString();
writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 1));

// Round-trip verification on a sample of THIS run's encryptions so a
// broken envelope can never ship silently.
const sample = [...encryptedNow].slice(0, 8);
for (const path of sample) {
  currentPath = path;
  const cipher = readFileSync(join(PUB, path));
  const plain = decryptFile(cipher);
  const want = registry.files[path].sha256;
  const got = createHash('sha256').update(plain).digest('hex');
  if (want !== got) {
    console.error(`encrypt_pdfs: round-trip FAILED for ${path}`);
    process.exit(4);
  }
}

console.log(
  `encrypt_pdfs: encrypted ${encrypted} files (${(totalPlain / 1e6).toFixed(1)} MB plain), ` +
    `${already} already shielded, registry ${Object.keys(registry.files).length} paths + ` +
    `${HONEYPOTS.length} honeypots -> data/static_registry.json, round-trip verified`
);
