'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { setSession } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await api<{ token: string; user: { id: string; username: string; profileCompleted: boolean } }>(
        '/auth/login',
        { method: 'POST', body: { username, password }, auth: false },
      );
      setSession(res.token, res.user);
      router.replace('/dashboard');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Network error — is the study API running?');
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center px-6">
      <div className="renance-rise">
        <div className="mb-8 flex items-center gap-3">
          <RenanceMark size={48} />
          <div>
            <h1 className="text-xl font-semibold tracking-tight">Welcome back</h1>
            <p className="text-sm text-neutral-500">Sign in to continue your streak.</p>
          </div>
        </div>

        <form onSubmit={onSubmit} className="space-y-4">
          <label className="block">
            <span className="mb-1.5 block text-sm text-neutral-400">Username</span>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              required
              className="w-full rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-3 text-sm outline-none transition focus:border-emerald-500"
            />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm text-neutral-400">Password</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
              className="w-full rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-3 text-sm outline-none transition focus:border-emerald-500"
            />
          </label>

          {error && (
            <p className="rounded-lg border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={busy}
            className="flex w-full items-center justify-center gap-3 rounded-lg bg-emerald-500 px-4 py-3 text-sm font-semibold text-black transition hover:bg-emerald-400 disabled:opacity-60"
          >
            {busy && <RenanceMark size={22} state="busy" />}
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-neutral-500">
          New to Renance?{' '}
          <Link href="/register" className="text-emerald-400 underline-offset-4 hover:underline">
            Create an account
          </Link>
        </p>
      </div>
    </main>
  );
}
