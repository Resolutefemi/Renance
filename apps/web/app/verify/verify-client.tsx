'use client';

/**
 * VerifyClient - the email confirmation landing. The mailed link points
 * here with the token and the place the signup happened (web or app):
 * the token is consumed against the API, the student sees the verdict,
 * and - when a restricted session is sitting in this browser (signup or
 * blocked sign-in) - the session is refreshed into a fully seated one
 * right away, so "Continue" opens the desk. An app signup additionally
 * fires the renance:// deep link so the app returns to the foreground
 * and unlocks itself.
 */

import { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { getToken, setSession } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

type State = 'verifying' | 'verified' | 'failed';

export default function VerifyClient() {
  const params = useSearchParams();
  const [state, setState] = useState<State>('verifying');
  const [message, setMessage] = useState('');
  // True when a restricted session was upgraded: Continue goes straight
  // to the desk. False (no session in this browser): Continue is a
  // sign-in hop.
  const [seated, setSeated] = useState(false);
  const firedRef = useRef(false);

  useEffect(() => {
    document.title = 'Confirm your email · Renance';
  }, []);

  useEffect(() => {
    if (firedRef.current) return;
    firedRef.current = true;
    const token = params.get('token') ?? '';
    const ret = params.get('return') ?? 'web';
    if (!token) {
      setState('failed');
      setMessage('This link carries no confirmation token. Sign in and resend the confirmation mail.');
      return;
    }
    api<{ verified: boolean }>('/auth/verify-email', {
      method: 'POST',
      body: { token },
      auth: false,
      noRedirect: true,
    })
      .then(async () => {
        setState('verified');
        // Upgrade the restricted session (web signup or blocked sign-in
        // parked one here): /auth/refresh re-mints the token without the
        // unverified claim, so the study surface opens with zero extra
        // sign-ins. A browser without a session (app signup, another
        // device) simply keeps the sign-in hop.
        if (getToken()) {
          try {
            const refreshed = await api<{ token: string; user: { id: string; username: string; profileCompleted: boolean } }>(
              '/auth/refresh',
              { method: 'POST', noRedirect: true },
            );
            setSession(refreshed.token, refreshed.user);
            setSeated(true);
          } catch {
            // Keep the sign-in hop - the account itself is confirmed.
          }
        }
        // Return-to-app: the signup started on a phone. The custom
        // scheme hop opens the app when it is installed; otherwise the
        // fallback text below keeps the student unstuck.
        if (ret === 'app') {
          window.location.href = 'renance://verified';
        }
      })
      .catch((err: { message?: string }) => {
        setState('failed');
        setMessage(err.message ?? 'This link is not valid any more.');
      });
  }, [params]);

  const fromApp = params.get('return') === 'app';

  return (
    <main className="flex min-h-dvh w-full flex-col items-center justify-center bg-surface-container px-4 py-10">
      <div className="renance-rise w-full max-w-sm rounded-xl bg-surface-container-lowest p-8 text-center shadow-md">
        <div className="mb-5 flex justify-center">
          <RenanceMark size={56} state={state === 'verifying' ? 'busy' : undefined} />
        </div>

        {state === 'verifying' && (
          <>
            <h1 className="text-xl font-semibold tracking-tight text-on-surface">
              Confirming your email…
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant">One moment.</p>
          </>
        )}

        {state === 'verified' && (
          <>
            <h1 className="text-xl font-semibold tracking-tight text-on-surface">
              Email confirmed
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
              Your account is fully unlocked.{' '}
              {fromApp
                ? 'Head back to the app and keep studying.'
                : seated
                  ? 'Welcome to Renance - your studies continue from here.'
                  : 'Sign in to continue studying.'}
            </p>
            {fromApp && (
              <p className="mt-3 text-[12px] text-on-surface-variant">
                If the app did not open by itself, switch to it manually.
              </p>
            )}
            <div className="mt-6 flex flex-col gap-2">
              {fromApp ? (
                <a
                  href="renance://verified"
                  className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90"
                >
                  Open the app
                </a>
              ) : (
                <Link
                  href={seated ? '/dashboard' : '/login'}
                  className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90"
                >
                  {seated ? 'Continue to Renance' : 'Sign in to continue'}
                </Link>
              )}
              <Link
                href="/pricing"
                className="flex h-12 items-center justify-center rounded-full text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD]"
              >
                See premium plans
              </Link>
            </div>
          </>
        )}

        {state === 'failed' && (
          <>
            <h1 className="text-xl font-semibold tracking-tight text-on-surface">
              This link did not work
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">{message}</p>
            <div className="mt-6 flex flex-col gap-2">
              <Link
                href="/login"
                className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90"
              >
                Sign in and resend
              </Link>
              <Link
                href="/register"
                className="flex h-12 items-center justify-center rounded-full text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD]"
              >
                Back to sign up
              </Link>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
