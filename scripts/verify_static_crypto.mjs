#!/usr/bin/env node
// verify_static_crypto.mjs - standalone round-trip check for the RNP1
// static shield: decrypt 3 sample files and compare sha256 to the
// registry. Usage: BUNDLE_MASTER_KEY=... node scripts/verify_static_crypto.mjs
import { createHmac, createDecipheriv, createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const MASTER = Buffer.from(process.env.BUNDLE_MASTER_KEY, 'hex');
const reg = JSON.parse(readFileSync(join(ROOT, 'data', 'static_registry.json'), 'utf8'));

function deriveKey(path) {
  return createHmac('sha256', MASTER).update(`renance-static/v1|${path}`).digest();
}

const paths = Object.keys(reg.files).slice(0, 3);
let ok = 0;
for (const path of paths) {
  const buf = readFileSync(join(ROOT, 'apps', 'web', 'public', path));
  if (buf.subarray(0, 4).toString('ascii') !== 'RNP1') { console.log(path, ': NOT ENCRYPTED'); continue; }
  const kidLen = buf[4];
  const iv = buf.subarray(5 + kidLen, 5 + kidLen + 12);
  const body = buf.subarray(5 + kidLen + 12); // ct+tag
  const tag = body.subarray(body.length - 16);
  const ct = body.subarray(0, body.length - 16);
  const d = createDecipheriv('aes-256-gcm', deriveKey(path), iv);
  d.setAuthTag(tag);
  const plain = Buffer.concat([d.update(ct), d.final()]);
  const sha = createHash('sha256').update(plain).digest('hex');
  const match = sha === reg.files[path].sha256 && plain.length === reg.files[path].bytes;
  console.log(path, match ? 'OK' : 'MISMATCH', `${plain.length}/${reg.files[path].bytes}B`);
  if (match) ok++;
}
console.log(ok === paths.length ? 'ALL ROUND-TRIPS PASS' : 'FAILED');
