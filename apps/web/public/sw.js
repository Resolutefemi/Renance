/* sw.js - the Renance offline navigation shield (founder bug report
 * 2026-10-15: "when the app is offline it falls back to a raw text
 * page like renance.app/courses/index.txt").
 *
 * Root cause: the site is a Next.js STATIC EXPORT, and the App Router
 * ships each route's RSC flight payload as /<route>/index.txt. When
 * the connection drops mid-navigation the router's hard-navigation
 * fallback can land the browser on that payload - raw RSC text.
 *
 * This worker is deliberately MINIMAL and network-first:
 *   - Navigations: network first. Success streams straight through
 *     (zero staleness). Failure -> the last runtime-cached copy of
 *     that page, else the precached /offline/ state - NEVER raw text.
 *   - Same-origin GET assets (styles, chunks, fonts): network first,
 *     cached on success, served from cache only when the network
 *     fails - so a visited page keeps rendering offline.
 *   - Everything else (the study API, cross-origin, POSTs, the RSC
 *     data fetches) passes through untouched.
 */
const OFFLINE_URL = '/offline/';
const RUNTIME_CACHE = 'renance-runtime-v1';
const OFFLINE_CACHE = 'renance-offline-v1';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(OFFLINE_CACHE)
      .then((cache) => cache.add(new Request(OFFLINE_URL, { cache: 'reload' })))
      .catch(() => {
        /* the offline page itself missing never blocks install */
      }),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => k !== RUNTIME_CACHE && k !== OFFLINE_CACHE)
            .map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  /* Only same-origin. The study API (renance-api.onrender.com), Clarity
   * and every other cross-origin call never touch this worker. */
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  /* Never intercept non-GET or the Next router's RSC data fetches
   * (they carry the RSC request header and expect raw payloads). */
  if (req.method !== 'GET' || req.headers.get('RSC') || url.searchParams.has('_rsc')) {
    return;
  }

  if (req.mode === 'navigate') {
    /* A page navigation: network first; on failure the runtime copy of
     * that very page, else the clean offline state. */
    event.respondWith(
      fetch(req)
        .then((res) => {
          stash(req, res.clone());
          return res;
        })
        .catch(() =>
          caches
            .open(RUNTIME_CACHE)
            .then((cache) => cache.match(req, { ignoreSearch: true }))
            .then((hit) => hit || caches.open(OFFLINE_CACHE).then((c) => c.match(OFFLINE_URL)))
            .then(
              (page) =>
                page ||
                new Response(
                  '<!doctype html><meta charset="utf-8"><title>You are offline</title><body style="font-family:sans-serif;padding:2rem">You appear to be offline. Reconnect and try again.</body>',
                  { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
                ),
            ),
        ),
    );
    return;
  }

  /* Static asset: network first, cache on success, cache only as the
   * offline fallback. */
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) stash(req, res.clone());
        return res;
      })
      .catch(() => caches.open(RUNTIME_CACHE).then((cache) => cache.match(req))),
  );
});

function stash(req, res) {
  if (!res || !res.ok) return;
  caches
    .open(RUNTIME_CACHE)
    .then((cache) => cache.put(req, res))
    .catch(() => {
      /* quota or private mode: the cache is best effort */
    });
}
