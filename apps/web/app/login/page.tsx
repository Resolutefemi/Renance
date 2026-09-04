'use client';

import { FormEvent, useCallback, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { setSession } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import { PersonIcon, LockIcon, ArrowIcon, EyeIcon } from '@/components/icons';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Stable identity for the GIS callback, never re-initialize mid-session.
  const onGoogleCredential = useCallback(
    async (credential: string) => {
      setError(null);
      setBusy(true);
      try {
        const res = await authWithGoogle(credential);
        setSession(res.token, res.user);
        router.replace('/dashboard');
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'Google sign-in failed, check the connection.');
        setBusy(false);
      }
    },
    [router],
  );

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
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-dvh w-full flex-col items-center justify-center bg-surface-container px-4">
      <div className="flex w-full max-w-sm flex-col items-center">
        {/* Logo block, mockup: logo, h1, subtitle, centered */}
        <div className="mb-10 flex flex-col items-center">
          <div className="mb-4">
            <RenanceMark size={64} />
          </div>
          <h1 className="text-center text-2xl font-semibold tracking-tight text-on-surface">
            Welcome back
          </h1>
          <p className="mt-1 text-center text-sm text-on-surface-variant">
            Sign in to continue to Renance.
          </p>
        </div>

        {/* Card, mockup: surface-container-lowest, rounded-xl, shadow-sm */}
        <form
          onSubmit={onSubmit}
          className="flex w-full flex-col gap-4 rounded-xl bg-surface-container-lowest p-6 shadow-sm"
        >
          <div className="flex flex-col gap-1.5">
            <label htmlFor="username" className="text-sm text-on-surface-variant">
              Username
            </label>
            <div className="group relative flex items-center">
              <PersonIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
              <input
                id="username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                autoComplete="username"
                required
                placeholder="yourusername"
                className="h-12 w-full rounded-lg bg-surface-container-low pl-11 pr-3 text-sm text-on-surface transition-all placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="password" className="text-sm text-on-surface-variant">
              Password
            </label>
            <div className="group relative flex items-center">
              <LockIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
                placeholder="••••••••"
                className="h-12 w-full rounded-lg bg-surface-container-low pl-11 pr-12 text-sm text-on-surface transition-all placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
              />
              <button
                type="button"
                aria-label="Toggle password visibility"
                onClick={() => setShowPassword((s) => !s)}
                className="absolute right-2 rounded-full p-2 text-on-surface-variant transition-colors hover:text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <EyeIcon off={showPassword} className="h-5 w-5" />
              </button>
            </div>
          </div>

          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              {error}
            </p>
          )}

          {/* Mockup: black primary button, arrow, press scale */}
          <button
            type="submit"
            disabled={busy}
            className="mt-1 flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-primary text-on-primary transition-all hover:bg-on-background hover:shadow-md active:scale-[0.98] disabled:opacity-60"
          >
            {busy ? (
              <>
                <RenanceMark size={22} state="busy" />
                Signing in…
              </>
            ) : (
              <>
                Sign In
                <ArrowIcon className="h-5 w-5" />
              </>
            )}
          </button>

          {/* Google sign-in, hidden unless the client ID is baked in */}
          <GoogleSignIn onCredential={onGoogleCredential} />
        </form>

        <p className="mt-10 text-center text-sm text-on-surface-variant">
          Don&apos;t have an account?{' '}
          <Link
            href="/register"
            className="ml-1 font-medium text-primary underline-offset-4 hover:underline"
          >
            Sign up
          </Link>
        </p>
      </div>
    </main>
  );
}
