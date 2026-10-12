#!/usr/bin/env node
// verify_client_flow.mjs - end-to-end check that mirrors the BROWSER
// flow exactly (lib/asset-crypto.ts): parse the RNP1 envelope, derive
// the key the way the Go API does, decrypt with WebCrypto.
import { createHmac, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';

const path = process.argv[2] ?? 'pdfs/futa/cos101.pdf';
const MASTER = Buffer.from(process.env.BUNDLE_MASTER_KEY, 'hex');
const buf = readFileSync(`apps/web/out/${path}`);

const RNP1 = [0x52, 0x4e, 0x50, 0x31];
if (!(buf[0] === RNP1[0] && buf[1] === RNP1[1] && buf[2] === RNP1[2] && buf[3] === RNP1[3])) {
  console.log('FAIL: not RNP1'); process.exit(1);
}
const kidLen = buf[4];
const off = 5 + kidLen;
const iv = buf.subarray(off, off + 12);
const ct = buf.subarray(off + 12);

const keyHex = createHmac('sha256', MASTER).update(`renance-static/v1|${path}`).digest('hex');
const key = await webcrypto.subtle.importKey(
  'raw', new Uint8Array(Buffer.from(keyHex, 'hex')), 'AES-GCM', false, ['decrypt']);

const plain = await webcrypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct);
const bytes = new Uint8Array(plain);
const isPdf = bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46;
console.log(`decrypted ${bytes.length} bytes from ${path}`);
console.log(isPdf ? 'PDF magic OK (%PDF) - browser flow verified' : 'NOT a PDF!');
if (!isPdf) process.exit(1);
