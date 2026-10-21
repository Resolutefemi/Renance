'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { RenanceMark } from '@/components/renance-logo';
import { MailIcon } from '@/components/icons';

// Forgot password (founder directive 2026-10-02): enter the account
// email (or username) and a single-use reset link is mailed - it opens
// the /reset-password page, which works in any browser. The response is
// intentionally uniform whether or not the account exists, so this
// surface can never be used to enumerate accounts.

export default function ForgotPasswordPage() {
  const [identifier, setIdentifier] = useState('');
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Forgot password · Renance';
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api('/auth/forgot-password', {
        method: 'POST',
        body: { identifier: identifier.trim(), return: 'web' },
        auth: false,
      });
      setSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Network error, is the study API running?');
    } finally {
      setBusy(false);
    }
  }

  const field = 'h-12 w-full rounded-lg bg-surface-container pl-11 pr-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary';

  return (
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4">
      <div className="my-auto flex w-full max-w-sm min-w-0 flex-col rounded-xl bg-surface-container-lowest p-6 shadow-md">
        <div className="mb-6 flex min-w-0 flex-col items-center gap-3 text-center">
          <RenanceMark size={56} />
          <div className="min-w-0">
            <h1 className="break-words text-2xl font-semibold tracking-tight text-on-surface">
              Forgot password
            </h1>
            <p className="mt-1 break-words text-sm text-on-surface-variant">
              {sent ? 'Check your inbox.' : 'Enter your email and we will send a reset link.'}
            </p>
          </div>
        </div>

        {sent ? (
          <div className="flex flex-col gap-4">
            <p className="rounded-lg bg-surface-container px-4 py-3 text-sm text-on-surface">
              If <span className="font-medium">{identifier.trim()}</span> belongs to a Renance
              account, a password reset link is on its way. The link works once and expires in 30
              minutes.
            </p>
            {/* Spam-folder hint (founder directive 2026-10-02): new sending
                domain, providers may file Renance mail under spam at first. */}
            <p className="rounded-lg bg-surface-container px-4 py-3 text-[13px] leading-relaxed text-on-surface-variant">
              Nothing in your inbox? Check your <b className="text-on-surface">spam folder</b> -
              marking the Renance mail <b className="text-on-surface">Not spam</b> keeps future
              mails in your main inbox.
            </p>
            <p className="text-center text-sm text-on-surface-variant">
              Remembered it?{' '}
              <Link href="/login" className="font-medium text-primary underline-offset-4 hover:underline">
                Sign in
              </Link>
            </p>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="identifier" className="text-sm text-on-surface-variant">
                Email address
              </label>
              <div className="group relative flex items-center">
                <MailIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
                <input
                  id="identifier"
                  type="text"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  required
                  autoComplete="email"
                  placeholder="you@example.com"
                  className={field}
                />
              </div>
              <p className="text-xs text-on-surface-variant">
                School accounts: enter the school email. Your username also works.
              </p>
            </div>

            {error && (
              <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={busy}
              className="mt-1 flex h-12 w-full items-center justify-center gap-2 rounded-full bg-primary text-on-primary transition-all hover:opacity-90 hover:shadow-md active:scale-[0.98] disabled:opacity-60"
            >
              {busy ? (
                <>
                  <RenanceMark size={22} state="busy" />
                  Sending…
                </>
              ) : (
                'Send reset link'
              )}
            </button>

            <p className="text-center text-sm text-on-surface-variant">
              Remembered it?{' '}
              <Link href="/login" className="font-medium text-primary underline-offset-4 hover:underline">
                Sign in
              </Link>
            </p>
          </form>
        )}
      </div>
    </main>
  );
}
