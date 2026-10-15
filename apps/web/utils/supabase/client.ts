'use client';

/**
 * Supabase browser client (founder directive 2026-10-15: "install the
 * Supabase packages, add the env variables and the client helpers").
 *
 * STATIC-EXPORT NOTE: apps/web builds with `output: 'export'` — there
 * is no server runtime and no middleware at deploy time, so the
 * server-side half of the standard Supabase snippet
 * (utils/supabase/server.ts with next/headers cookies) and a
 * middleware.ts session refresher CANNOT run in this app (a root
 * middleware.ts would fail the static build outright). The browser
 * client below is the static-export-safe half; the app's authoritative
 * data path stays the Go study-api, which talks to Supabase directly
 * as the fallback database (see render.yaml → SUPABASE_DATABASE_URL).
 */

import { createBrowserClient } from '@supabase/ssr';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

let cached: ReturnType<typeof createBrowserClient> | null = null;

/** The shared browser client (anon/publishable key, RLS-scoped). */
export function createClient() {
  if (cached) return cached;
  if (!supabaseUrl || !supabaseKey) {
    throw new Error(
      'Supabase is not configured: set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    );
  }
  cached = createBrowserClient(supabaseUrl, supabaseKey);
  return cached;
}

/**
 * Fire-and-forget REST activity ping (founder directive 2026-10-15:
 * "make sure Supabase is not inactive"). One authenticated REST request
 * per page load counts as project activity on the free tier, so real
 * student traffic keeps the project awake between the scheduled
 * db-keepalive workflow runs. Never throws, never blocks rendering,
 * 4s budget. Returns true when Supabase answered 2xx.
 */
export async function pingSupabase(): Promise<boolean> {
  if (!supabaseUrl || !supabaseKey) return false;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 4000);
    try {
      const res = await fetch(`${supabaseUrl}/rest/v1/`, {
        headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` },
        signal: controller.signal,
      });
      return res.ok;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return false;
  }
}
