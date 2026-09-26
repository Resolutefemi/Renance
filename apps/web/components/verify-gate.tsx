'use client';

/**
 * VerifyGate - the strict email check. A manual (non-Google) signup
 * cannot reach the dashboard until the address is confirmed: every
 * gated page renders this screen instead while the entitlement says
 * unverified. Google accounts arrive pre-verified and sail through.
 * The resend button hits the server's one-minute-cooldown endpoint and
 * the sign-out link hands the desk back cleanly.
 */

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { clearSession, getToken } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

export function useEmailVerified(): boolean | null {
  const [verified, setVerified] = useState<boolean | null>(null);
  useEffect(() => {
    let alive = true;
    if (!getToken()) {
      setVerified(true); // the page's own auth guard handles the redirect
      return;
    }
    api<{ entitlement?: { emailVerified?: boolean } }>('/me')
      .then((r) => alive && setVerified(r.entitlement?.emailVerified !== false))
      .catch(() => alive && setVerified(true)); // API down: never lock the desk
    return () => {
      alive = false;
    };
  }, []);
  return verified;
}

export default function VerifyGate({ children }: { children: React.ReactNode }) {
  const verified = useEmailVerified();
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  if (verified !== false) return <>{children}</>;

  const resend = async () => {
    setBusy(true);
    setError('');
    try {
      await api('/auth/resend-verification', { method: 'POST' });
      setSent(true);
    } catch (e) {
      setError(
        e instanceof ApiError ? e.message : 'The mail could not be sent, try again in a minute.',
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-surface-container-lowest px-6">
      <div className="w-full max-w-md rounded-xl bg-card p-8 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-surface-container">
          <span className="material-symbols-outlined text-[26px] text-on-surface">mark_email_unread</span>
        </div>
        <h1 className="mt-4 text-xl font-bold tracking-tight text-on-surface">
          Confirm your email to continue
        </h1>
        <p className="mt-2 text-sm leading-6 text-on-surface-variant">
          We sent a confirmation link to your inbox. Open it and your desk
          unlocks. Students who sign up with Google skip this step because
          Google already vouched for them.
        </p>
        <div className="mt-6 flex flex-col gap-2">
          <button
            type="button"
            onClick={resend}
            disabled={busy}
            className="flex h-11 w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
          >
            {busy ? 'Sending…' : sent ? 'Confirmation sent, check the inbox' : 'Resend the confirmation mail'}
          </button>
          <button
            type="button"
            onClick={() => {
              clearSession();
              router.replace('/login');
            }}
            className="flex h-11 w-full items-center justify-center rounded-[10px] border border-outline text-sm font-semibold text-on-surface transition hover:bg-surface-container"
          >
            Sign out
          </button>
        </div>
        {error && <p className="mt-3 text-[12.5px] text-error">{error}</p>}
        <p className="mt-4 text-[11.5px] text-outline">
          Wrong address?{' '}
          <Link href="/register" className="underline underline-offset-2 hover:text-on-surface">
            Sign up again
          </Link>
        </p>
        <div className="mt-4 flex justify-center opacity-40">
          <RenanceMark size={28} />
        </div>
      </div>
    </main>
  );
}
