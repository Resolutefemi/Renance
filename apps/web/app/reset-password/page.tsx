'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { RenanceMark } from '@/components/renance-logo';
import { LockIcon, EyeIcon } from '@/components/icons';

// Forgot password (founder directive 2026-10-02): this page consumes the
// single-use reset link. The mailed URL lands here with ?token= (and
// return=web|app - the app's in-app browser opens the same page); the
// student sets a new password and returns to sign-in. Works for student
// accounts and school (management/teacher) accounts alike.

export default function ResetPasswordPage() {
  const [token, setToken] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Reset password · Renance';
    try {
      const q = new URLSearchParams(window.location.search);
      setToken(q.get('token') ?? '');
    } catch {
      /* private mode */
    }
  }, []);

  const mismatch = confirmPassword.length > 0 && password !== confirmPassword;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    setBusy(true);
    try {
      await api('/auth/reset-password', {
        method: 'POST',
        body: { token, password },
        auth: false,
      });
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Network error, is the study API running?');
    } finally {
      setBusy(false);
    }
  }

  const field = 'h-12 w-full rounded-lg bg-surface-container pl-11 pr-12 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary';

  return (
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4">
      <div className="my-auto flex w-full max-w-sm min-w-0 flex-col rounded-xl bg-surface-container-lowest p-6 shadow-md">
        <div className="mb-6 flex min-w-0 flex-col items-center gap-3 text-center">
          <RenanceMark size={56} />
          <div className="min-w-0">
            <h1 className="break-words text-2xl font-semibold tracking-tight text-on-surface">
              {done ? 'Password updated' : 'Set a new password'}
            </h1>
            <p className="mt-1 break-words text-sm text-on-surface-variant">
              {done
                ? 'Your new password is live.'
                : 'Pick a password you have not used on Renance before.'}
            </p>
          </div>
        </div>

        {done ? (
          <div className="flex flex-col gap-4">
            <p className="rounded-lg bg-surface-container px-4 py-3 text-sm text-on-surface">
              Password reset complete. Sign in with your email (or username) and the new
              password - on the website or in the app.
            </p>
            <Link
              href="/login"
              className="flex h-12 w-full items-center justify-center rounded-full bg-primary text-on-primary transition-all hover:opacity-90 active:scale-[0.98]"
            >
              Go to sign in
            </Link>
          </div>
        ) : !token ? (
          <div className="flex flex-col gap-4">
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              This page needs a reset link. Open the link from your email, or request a
              fresh one.
            </p>
            <Link
              href="/forgot-password"
              className="flex h-12 w-full items-center justify-center rounded-full bg-primary text-on-primary transition-all hover:opacity-90 active:scale-[0.98]"
            >
              Request a reset link
            </Link>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="password" className="text-sm text-on-surface">
                New password
              </label>
              <div className="group relative flex items-center">
                <LockIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={8}
                  maxLength={72}
                  autoComplete="new-password"
                  placeholder="At least 8 characters"
                  className={field}
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

            <div className="flex flex-col gap-1.5">
              <label htmlFor="confirm-password" className="text-sm text-on-surface">
                Confirm password
              </label>
              <div className="group relative flex items-center">
                <LockIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
                <input
                  id="confirm-password"
                  type={showPassword ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  minLength={8}
                  maxLength={72}
                  autoComplete="new-password"
                  placeholder="Type it again"
                  className={`${field} ${mismatch ? 'ring-2 ring-error' : ''}`}
                />
              </div>
              {mismatch && <p className="text-xs text-error">Passwords do not match.</p>}
            </div>

            {error && (
              <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={busy || mismatch || password.length < 8}
              className="mt-1 flex h-12 w-full items-center justify-center gap-2 rounded-full bg-primary text-on-primary transition-all hover:opacity-90 hover:shadow-md active:scale-[0.98] disabled:opacity-60"
            >
              {busy ? (
                <>
                  <RenanceMark size={22} state="busy" />
                  Saving…
                </>
              ) : (
                'Save new password'
              )}
            </button>
          </form>
        )}
      </div>
    </main>
  );
}
