'use client';

import { clearSession, getToken } from './session';

// The API base must be baked at build time (NEXT_PUBLIC_API_BASE). When a
// production build ships without it, fall back to the live Render service
// instead of localhost: a static export that asks the visitor's own machine
// for the API is exactly how sign-in silently died on the first Vercel
// deploy. Local dev keeps the local study API.
export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  (process.env.NODE_ENV === 'production'
    ? 'https://renance-api.onrender.com'
    : 'http://localhost:3990');

// GitHub Pages serves the app under /<repo>/, raw redirects must respect it.
const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

/**
 * Prefix an app-internal path with the deploy base path. ONLY needed for
 * surfaces Next.js does not touch automatically: raw <a> anchors that
 * must leave the SPA (PDF downloads, new tabs) and window.location
 * assignments. next/link and router.push/get apply the base path on
 * their own, and double-prefixing breaks them, so never wrap those.
 */
export function withBase(path: string): string {
  if (!path.startsWith('/')) return path;
  return `${BASE_PATH}${path}`;
}

export class ApiError extends Error {
  status: number;
  code: string;
  /** The raw error envelope's extra fields (e.g. the free-cap 402's
   *  limit/answered/saved) so specific failures can drive specific UI. */
  data: Record<string, unknown> | null;

  constructor(status: number, code: string, message: string, data: Record<string, unknown> | null = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.data = data;
  }
}

export interface AuthResponse {
  token: string;
  user: { id: string; username: string; profileCompleted: boolean };
}

// Exchanges a Google ID token (from the GIS button) for a Renance session.
// The backend verifies the token against Google's JWKS, no client secret
// involved anywhere.
export async function authWithGoogle(credential: string): Promise<AuthResponse> {
  return api<AuthResponse>('/auth/google', {
    method: 'POST',
    body: { credential },
    auth: false,
  });
}

interface Options {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  auth?: boolean;
  /** Swallow the 401 (throw it) instead of bouncing the whole page to
   *  /login. Content endpoints with a local fallback (question bundles)
   *  must never kick a student out of what they were doing. */
  noRedirect?: boolean;
  /** Opt-in single retry for IDEMPOTENT mutations when the connection
   *  itself dies (timeout / dead socket). Render's free-plan cold start
   *  outruns even 45s, and the desk save died exactly there (founder
   *  report 2026-10-14: "not saved, try again" on every first pick
   *  after a break). Only calls whose server side re-validates and
   *  refuses a double apply (desk upsert, PK-guarded claims, guarded
   *  wallet buys) may set this - retrying a fresh exam submit here
   *  would double-count it, so the default stays NO retry. */
  idempotentRetry?: boolean;
}

/**
 * Client timeout. The old 12s guard predated the Render free-tier reality:
 * a cold-spun service often needs 30-50s just to accept the first
 * connection, so 12s fired mid-cold-start and every first tap on a fresh
 * session died with "check your connection" (founder bug report
 * 2026-10-14: tapping an institution threw exactly that). 45s covers the
 * worst honest cold start plus the server's own 30s write budget; past
 * it the call throws and callers fall back to cache / friendly notices.
 */
const FETCH_TIMEOUT_MS = 45_000;

export async function api<T>(path: string, opts: Options = {}): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (opts.auth !== false) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }
  // Dead-API guard (founder report 2026-10-14: "the new pages are still
  // not loading"): when the study API hangs (Render restart, free-plan
  // cold start, dead network) an untimed fetch holds every page on its
  // skeletons for minutes. 45s is past any honest cold start; past it
  // the call throws and every caller's catch falls back to the device
  // cache / friendly notice instead of an eternal spinner.
  // GETs retry once automatically: a cold-start connection that dies
  // mid-warm-up is the most common first-tap failure, and a read is
  // always safe to re-issue. Mutating methods stay single-shot UNLESS
  // the caller opts in with idempotentRetry (server-guarded upserts
  // and PK-guarded claims only).
  const canRetry = (opts.method ?? 'GET') === 'GET' || opts.idempotentRetry === true;
  let res: Response | null = null;
  let lastErr: unknown = null;
  for (let attempt = 0; attempt < (canRetry ? 2 : 1); attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      res = await fetch(`${API_BASE}${path}`, {
        method: opts.method ?? 'GET',
        headers,
        body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
        signal: controller.signal,
      });
      lastErr = null;
      break;
    } catch (err) {
      lastErr = err;
      // Only connection-level failures (timeout, dead socket) retry;
      // anything the browser threw for another reason surfaces now.
      if (!controller.signal.aborted && attempt === 0 && !(err instanceof TypeError)) throw err;
    } finally {
      clearTimeout(timer);
    }
  }
  if (res === null) {
    if (lastErr instanceof Error && lastErr.name !== 'AbortError' && !(lastErr instanceof TypeError) && !(lastErr as { message?: string })?.message?.includes('aborted')) {
      throw lastErr;
    }
    throw new ApiError(0, 'timeout', 'The study API is not answering right now - try again shortly.');
  }

  if (res.status === 401 && opts.auth !== false && !opts.noRedirect) {
    clearSession();
    if (typeof window !== 'undefined') {
      const loginPath = `${BASE_PATH}/login`;
      const here = window.location.pathname.replace(/\/+$/, '') || '/';
      if (!here.endsWith(loginPath)) {
        window.location.href = loginPath;
      }
    }
    throw new ApiError(401, 'unauthorized', 'Session expired, sign in again.');
  }

  const text = await res.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
  }
  if (!res.ok) {
    const err = (payload as { error?: { code?: string; message?: string } } | null)?.error;
    // A restricted (unverified-signup) session only opens the
    // confirmation surface. Any other endpoint answering 403
    // email_unverified means the student slipped past the confirm
    // screen (deep link, stale tab): hand them back to sign-in, where
    // the blocked login re-sends the confirmation mail.
    if (
      res.status === 403 &&
      err?.code === 'email_unverified' &&
      opts.auth !== false &&
      !opts.noRedirect
    ) {
      if (typeof window !== 'undefined') {
        const loginPath = `${BASE_PATH}/login`;
        const here = window.location.pathname.replace(/\/+$/, '') || '/';
        if (!here.endsWith(loginPath)) {
          window.location.href = loginPath;
        }
      }
    }
    // School workspace DB separation (founder directive 2026-10-05):
    // a student session that somehow lands on a /school page (stale tab
    // after the server started refusing student tokens) gets bounced to
    // the sign-in screen instead of a wall of failed requests.
    if (
      res.status === 403 &&
      err?.code === 'not_school_account' &&
      opts.auth !== false &&
      !opts.noRedirect
    ) {
      if (typeof window !== 'undefined') {
        const loginPath = `${BASE_PATH}/login`;
        const here = window.location.pathname.replace(/\/+$/, '') || '/';
        if (!here.endsWith(loginPath)) {
          window.location.href = loginPath;
        }
      }
    }
    // The FULL payload rides the error (not just the extra fields):
    // the blocked login's 403 carries the restricted token + the
    // signup address, and the sign-in screen needs both to drive the
    // confirm card.
    const data =
      payload && typeof payload === 'object' ? (payload as Record<string, unknown>) : null;
    throw new ApiError(res.status, err?.code ?? 'error', err?.message ?? `Request failed (${res.status})`, data);
  }
  return payload as T;
}
