'use client';

/**
 * asset-crypto.ts - the client half of the STATIC asset shield
 * (founder directive 2026-10-12: "I told someone my past questions on
 * the web have no rate limit and can be scraped - is that true? work
 * on it").
 *
 * The audit answer: the /bundles/*.json question banks were already
 * AES-256-GCM ciphertext, but /pdfs/** (2,026 past-question PDFs,
 * 322MB) and /school-corpus/** shipped PLAIN on the CDN. A static file
 * has no rate limit - anyone could wget the whole shelf. They now ship
 * as a binary envelope:
 *
 *   "RNP1" | kidLen u8 | kid utf8 | nonce 12B | AES-256-GCM ct+tag
 *
 * keyed per asset path (scripts/encrypt_pdfs.mjs, key domain
 * "renance-static/v1|<path>"). This module fetches the encrypted
 * bytes, obtains the ONE asset's key from GET /bundles/key?code=
 * static:<path> (the same metered route the question banks use:
 * signed-in = per-account speed cap, anonymous = proof-of-work +
 * per-IP caps), decrypts with WebCrypto, and hands back bytes.
 *
 * Legacy fallback: a file that does NOT start with the RNP1 magic (a
 * stale deploy baked before the shield) passes through untouched, so
 * the site never breaks mid-rollout.
 */

import { acquireBundleKey } from './bundle-crypto';

const RNP1 = [0x52, 0x4e, 0x50, 0x31]; // "RNP1"
const IV_LEN = 12;

function isRnp1(buf: Uint8Array): boolean {
  return buf.length > 24 &&
    buf[0] === RNP1[0] && buf[1] === RNP1[1] && buf[2] === RNP1[2] && buf[3] === RNP1[3];
}

/** Site-root-relative path (e.g. "/pdfs/futa/cos101.pdf") ->
 * the key-route code ("static:pdfs/futa/cos101.pdf"). */
export function staticCodeFor(path: string): string {
  return 'static:' + path.replace(/^\/+/, '');
}

/**
 * Fetch a shielded static asset and return its PLAIN bytes. Plain
 * (pre-shield) files pass through so stale deploys keep working.
 */
export async function fetchStaticAsset(path: string): Promise<Uint8Array> {
  const base = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
  const res = await fetch(`${base}${path}`);
  if (!res.ok) throw new Error(`asset ${path}: HTTP ${res.status}`);
  const buf = new Uint8Array(await res.arrayBuffer());
  if (!isRnp1(buf)) return buf; // legacy plain asset
  if (typeof crypto === 'undefined' || !crypto.subtle) {
    throw new Error('decryption requires a secure context (https)');
  }
  const kidLen = buf[4];
  const off = 5 + kidLen;
  const iv = buf.subarray(off, off + IV_LEN);
  const ct = buf.subarray(off + IV_LEN); // ciphertext+tag (WebCrypto shape)
  const key = await acquireBundleKey(staticCodeFor(path));
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    ct
  );
  return new Uint8Array(plain);
}

/** Fetch + decrypt a static text asset (JSON corpus files). */
export async function fetchStaticAssetText(path: string): Promise<string> {
  const bytes = await fetchStaticAsset(path);
  return new TextDecoder().decode(bytes);
}

/**
 * Open a shielded PDF for the student: fetch -> decrypt -> Blob ->
 * new tab, with a download fallback when the popup is blocked. The
 * plain bytes never touch the DOM; the blob URL is revoked after the
 * viewer has had time to latch it.
 */
export async function openPdfAsset(path: string): Promise<void> {
  const bytes = await fetchStaticAsset(path);
  // Copy into a standalone ArrayBuffer so the BlobPart typing and the
  // view offsets are both exact, whichever path produced the bytes.
  const part = bytes.slice().buffer as ArrayBuffer;
  const blob = new Blob([part], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const filename = path.split('/').pop() || 'renance.pdf';
  const win = window.open(url, '_blank');
  if (!win) {
    // Popup blocked (or a WebView): fall back to a direct download via
    // a temporary anchor. Same blob, same bytes, no server round-trip.
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  }
  setTimeout(() => URL.revokeObjectURL(url), 120_000);
}
