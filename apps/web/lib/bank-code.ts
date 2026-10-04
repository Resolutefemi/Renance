/**
 * Bundle code for a body × subject bank - server-safe (no 'use client',
 * no Node APIs) so the static SEO pages and the client readers share
 * ONE bank-code builder.
 *
 * The URL slug and the bundle prefix disagree for exactly one body:
 * /practice/post-utme/ pages must read the `post_utme-<subject>-bank`
 * packs (the vault's grouped layout uses POST_UTME, the manifest the
 * underscore form); every other body is a plain `<body>-<subject>-bank`.
 * A new body only ever needs one more row here.
 */
const BANK_CODE_PREFIX: Record<string, string> = {
  'post-utme': 'post_utme',
};

export function bankCode(body: string, subjectSlug: string): string {
  return `${BANK_CODE_PREFIX[body] ?? body}-${subjectSlug}-bank`;
}
