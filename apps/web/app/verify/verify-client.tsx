'use client';

/**
 * VerifyClient - the email confirmation landing. The mailed link points
 * here with the token and the place the signup happened (web or app):
 * the token is consumed against the API, the student sees the verdict,
 * and the "back to the app" hop fires the renance:// deep link when the
 * signup came from the app. A web signup simply gets the continue link.
 */

import { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { RenanceMark } from '@/components/renance-logo';

type State = 'verifying' | 'verified' | 'failed';

export default function VerifyClient() {
  const params = useSearchParams();
  const [state, setState] = useState<State>('verifying');
  const [message, setMessage] = useState('');
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
      .then(() => {
        setState('verified');
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
              Your account is fully unlocked. Head back to where you started
              {fromApp ? ' and continue in the app.' : ' and keep studying.'}
            </p>
            {fromApp && (
              <p className="mt-3 text-[12px] text-on-surface-variant">
                If the app did not open by itself, switch to it manually.
              </p>
            )}
            <div className="mt-6 flex flex-col gap-2">
              <Link
                href="/dashboard"
                className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90"
              >
                Continue to Renance
              </Link>
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
