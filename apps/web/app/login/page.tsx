'use client';

import { FormEvent, useCallback, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { setSession } from '@/lib/session';
import { chooseSchool, schoolMe } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import { AudienceToggle, type Audience } from '@/components/audience-toggle';
import { MailIcon, LockIcon, ArrowIcon, EyeIcon } from '@/components/icons';

export default function LoginPage() {
  const router = useRouter();
  const [audience, setAudience] = useState<Audience>('students');
  const [email, setEmail] = useState('');
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
        { method: 'POST', body: { email, password }, auth: false },
      );
      setSession(res.token, res.user);

      if (audience === 'schools') {
        // Route school members into the school workspace; everyone else
        // gets a friendly nudge instead of a dead end.
        try {
          const me = await schoolMe();
          const active = chooseSchool(me.schools ?? []);
          if (active) {
            router.replace('/school');
            return;
          }
          setError('This account is not linked to a school. Sign in under For Students, or register the school first.');
          setBusy(false);
          return;
        } catch {
          setError('Signed in, but the school workspace could not be loaded.');
          setBusy(false);
          return;
        }
      }
      router.replace('/dashboard');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  return (
    // my-auto (not justify-center) keeps the block visually centred while
    // letting the page grow: on small phones the For Schools form is taller
    // than the viewport, and justify-center would clip the unreachable top.
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4">
      <div className="my-auto flex w-full max-w-sm min-w-0 flex-col items-center">
        {/* Logo block, mockup: logo, h1, subtitle, centered */}
        <div className="mb-8 flex min-w-0 flex-col items-center">
          <div className="mb-4">
            <RenanceMark size={64} />
          </div>
          <h1 className="break-words text-center text-2xl font-semibold tracking-tight text-on-surface">
            Welcome back
          </h1>
          <p className="mt-1 break-words text-center text-sm text-on-surface-variant">
            Sign in to continue to Renance.
          </p>
        </div>

        {/* Audience switch - students by default, schools for management + teachers */}
        <div className="mb-5 w-full">
          <AudienceToggle audience={audience} onChange={setAudience} mode="login" />
        </div>

        {/* Card, mockup: surface-container-lowest, rounded-xl, shadow-sm */}
        <form
          onSubmit={onSubmit}
          className="flex w-full flex-col gap-4 rounded-xl bg-surface-container-lowest p-6 shadow-sm"
        >
          <div className="flex flex-col gap-1.5">
            <label htmlFor="email" className="text-sm text-on-surface-variant">
              {audience === 'schools' ? 'School email' : 'Email address'}
            </label>
            <div className="group relative flex items-center">
              <MailIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                required
                placeholder="you@example.com"
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
                {audience === 'schools' ? 'Open School Workspace' : 'Sign In'}
                <ArrowIcon className="h-5 w-5" />
              </>
            )}
          </button>

          {/* Google sign-in (students), hidden unless the client ID is baked in */}
          {audience === 'students' && <GoogleSignIn onCredential={onGoogleCredential} />}
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
