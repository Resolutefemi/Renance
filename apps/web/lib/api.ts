'use client';

import { clearSession, getToken } from './session';

export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ?? 'http://localhost:3990';

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

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
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
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: unknown;
  auth?: boolean;
  /** Swallow the 401 (throw it) instead of bouncing the whole page to
   *  /login. Content endpoints with a local fallback (question bundles)
   *  must never kick a student out of what they were doing. */
  noRedirect?: boolean;
}

export async function api<T>(path: string, opts: Options = {}): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (opts.auth !== false) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${API_BASE}${path}`, {
    method: opts.method ?? 'GET',
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });

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
    throw new ApiError(res.status, err?.code ?? 'error', err?.message ?? `Request failed (${res.status})`);
  }
  return payload as T;
}
