'use client';

/**
 * bundle-crypto.ts - the client half of the static-bundle shield
 * (founder directive 2026-10-11: "no agentic AI may scrape my
 * 200,000+ past questions").
 *
 * The web export no longer ships readable JSON question banks. Each
 * /bundles/<code>.json on the CDN is AES-256-GCM ciphertext keyed per
 * bank code (scripts/web_bundles.py + the study API derive the same
 * key from the BUNDLE_MASTER_KEY deployment secret). This module:
 *
 *   1. fetches the encrypted file same-origin,
 *   2. obtains the ONE bank's key from GET /bundles/key?code=…
 *      - signed-in: the JWT rides the request, per-account daily quota
 *        applies server-side;
 *      - signed-out: a proof-of-work challenge is solved right here
 *        (~0.3s of hashing), then per-IP limits apply;
 *   3. decrypts with WebCrypto, returns the plain bundle object.
 *
 * Keys are cached per (code, kid) in sessionStorage for the tab
 * session only. Decrypted bundles keep flowing into the existing
 * IndexedDB cache (browser-local, same as before).
 *
 * Legacy fallback: a bundle file that is NOT the encrypted shape
 * (deployed before the shield, or a plain local dev bake) passes
 * through untouched, so the site never breaks mid-rollout.
 */

import { API_BASE } from './api';
import { getToken } from './session';

export interface EncryptedBundleFile {
  v: number;
  kid: string;
  alg: 'A256GCM';
  n: string; // base64 12-byte IV
  ct: string; // base64 ciphertext+tag
}

export function isEncryptedBundleFile(x: unknown): x is EncryptedBundleFile {
  if (!x || typeof x !== 'object') return false;
  const o = x as Record<string, unknown>;
  return o.v === 1 && typeof o.kid === 'string' && o.alg === 'A256GCM' &&
    typeof o.n === 'string' && typeof o.ct === 'string' && !Array.isArray((x as { questions?: unknown }).questions);
}

/* ------------------------------------------------------------------ */
/* key acquisition                                                     */
/* ------------------------------------------------------------------ */

interface KeyEnvelope {
  kid: string;
  code: string;
  alg: string;
  key: string; // 64 hex chars
}

interface PowEnvelope {
  code: string;
  challenge: { nonce: string; difficulty: number; algo: string; hint?: string };
}

const BKEY_NS = 'renance.bkey.';

function keyCacheName(code: string, kid: string): string {
  return `${BKEY_NS}${code}.${kid}`;
}

/** Hex string -> Uint8Array. */
function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

/** Fetch this bank's AES key, cache it for the tab session. */
export async function acquireBundleKey(code: string): Promise<CryptoKey> {
  // 1. session cache (per code+kid; kid unknown until first response,
  //    so probe existing entries for this code).
  if (typeof sessionStorage !== 'undefined') {
    for (let i = 0; i < sessionStorage.length; i++) {
      const k = sessionStorage.key(i);
      if (k && k.startsWith(`${BKEY_NS}${code}.`)) {
        const hex = sessionStorage.getItem(k) ?? '';
        if (hex.length === 64) {
          try {
            return importAesKey(hexToBytes(hex));
          } catch {
            sessionStorage.removeItem(k);
          }
        }
      }
    }
  }

  // 2. ask the API. Signed-in = JWT path; anonymous = PoW path.
  let env = await requestKey(code, undefined, undefined);
  if (isPow(env)) {
    const { suffix } = await solvePow(env.challenge.nonce, env.challenge.difficulty);
    env = await requestKey(code, env.challenge.nonce, suffix);
  }
  if (!isKeyEnvelope(env)) {
    throw new Error('bundle key unavailable');
  }
  if (typeof sessionStorage !== 'undefined') {
    try {
      sessionStorage.setItem(keyCacheName(env.code, env.kid), env.key);
    } catch {
      /* private mode: just don't cache */
    }
  }
  return importAesKey(hexToBytes(env.key));
}

async function importAesKey(raw: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', raw.buffer as ArrayBuffer, 'AES-GCM', false, ['decrypt']);
}

async function requestKey(
  code: string,
  nonce?: string,
  pow?: string
): Promise<KeyEnvelope | PowEnvelope> {
  const qs = new URLSearchParams({ code });
  if (nonce !== undefined) qs.set('nonce', nonce);
  if (pow !== undefined) qs.set('pow', pow);
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}/bundles/key?${qs.toString()}`, { headers });
  const text = await res.text();
  let payload: unknown = null;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    payload = null;
  }
  if (res.status === 401 && payload && isPow(payload)) return payload; // the challenge
  if (!res.ok) {
    const err = (payload as { error?: { message?: string; code?: string } } | null)?.error;
    throw new Error(err?.message ?? `bundle key: HTTP ${res.status}`);
  }
  return payload as KeyEnvelope;
}

function isKeyEnvelope(x: unknown): x is KeyEnvelope {
  return !!x && typeof x === 'object' &&
    typeof (x as KeyEnvelope).key === 'string' &&
    (x as KeyEnvelope).key.length === 64;
}

function isPow(x: unknown): x is PowEnvelope {
  return !!x && typeof x === 'object' && !!(x as PowEnvelope).challenge &&
    typeof (x as PowEnvelope).challenge.nonce === 'string';
}

/* ------------------------------------------------------------------ */
/* proof-of-work solver                                                */
/* ------------------------------------------------------------------ */

/**
 * Solve the server's challenge: find a hex suffix so that
 * sha256(nonce || suffix) begins with difficulty/4 zero hex chars.
 * Uses a compact synchronous SHA-256 (~1M hashes/sec) so 18 bits
 * costs a real browser ~0.3s once per bank - and an agentic scraper
 * the same, every single time, through the same rate limits.
 */
async function solvePow(nonce: string, difficulty: number): Promise<{ suffix: string }> {
  const zeroChars = Math.ceil(difficulty / 4);
  const prefix = '0'.repeat(zeroChars);
  // Candidate suffixes are hex counters: deterministic work, unique
  // per attempt, no crypto strength needed (the server validates).
  let counter = Math.floor(Math.random() * 0xffff);
  for (let i = 0; i < 1 << 24; i++) {
    const suffix = counter.toString(16).padStart(8, '0');
    const digest = sha256Hex(nonce + suffix);
    if (digest.startsWith(prefix)) {
      return { suffix };
    }
    counter = (counter + 1) >>> 0;
    // yield to the event loop every 4k hashes so the UI never freezes
    if ((i & 0xfff) === 0xfff) await new Promise((r) => setTimeout(r, 0));
  }
  throw new Error('proof-of-work exhausted');
}

/* ------------------------------------------------------------------ */
/* decryption                                                          */
/* ------------------------------------------------------------------ */

export async function decryptBundleFile(file: EncryptedBundleFile, code: string): Promise<string> {
  const key = await acquireBundleKey(code);
  const iv = b64ToBytes(file.n);
  const ct = b64ToBytes(file.ct);
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: iv.buffer as ArrayBuffer },
    key,
    ct.buffer as ArrayBuffer
  );
  return new TextDecoder().decode(plain);
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/* ------------------------------------------------------------------ */
/* compact SHA-256 (RFC 6234), synchronous                             */
/* ------------------------------------------------------------------ */

const K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

/** SHA-256 of an ASCII string, hex digest. */
export function sha256Hex(msg: string): string {
  const bytes = new Uint8Array(msg.length);
  for (let i = 0; i < msg.length; i++) bytes[i] = msg.charCodeAt(i) & 0xff;

  const h = new Uint32Array([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  const withPad = new Uint8Array(((bytes.length + 8) >> 6 << 6) + 64);
  withPad.set(bytes);
  withPad[bytes.length] = 0x80;
  const bitLen = bytes.length * 8;
  const dv = new DataView(withPad.buffer);
  dv.setUint32(withPad.length - 4, bitLen >>> 0, false);
  dv.setUint32(withPad.length - 8, Math.floor(bitLen / 0x100000000), false);

  const w = new Uint32Array(64);
  for (let off = 0; off < withPad.length; off += 64) {
    for (let i = 0; i < 16; i++) w[i] = dv.getUint32(off + i * 4, false);
    for (let i = 16; i < 64; i++) {
      const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
    }
    let [a, b, c, d, e, f, g, hh] = [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]];
    for (let i = 0; i < 64; i++) {
      const S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      const ch = (e & f) ^ (~e & g);
      const t1 = (hh + S1 + ch + K[i] + w[i]) >>> 0;
      const S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const t2 = (S0 + maj) >>> 0;
      hh = g; g = f; f = e; e = (d + t1) >>> 0;
      d = c; c = b; b = a; a = (t1 + t2) >>> 0;
    }
    h[0] = (h[0] + a) >>> 0; h[1] = (h[1] + b) >>> 0; h[2] = (h[2] + c) >>> 0; h[3] = (h[3] + d) >>> 0;
    h[4] = (h[4] + e) >>> 0; h[5] = (h[5] + f) >>> 0; h[6] = (h[6] + g) >>> 0; h[7] = (h[7] + hh) >>> 0;
  }
  return Array.from(h, (x) => x.toString(16).padStart(8, '0')).join('');
}

function rotr(x: number, n: number): number {
  return ((x >>> n) | (x << (32 - n))) >>> 0;
}
