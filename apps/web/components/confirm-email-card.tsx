'use client';

/**
 * ConfirmEmailCard - the one confirmation surface every entry point
 * shares. FOUNDER DIRECTIVE 2026-10-05: email confirmation is a 6-digit
 * CODE typed in here, not a mailed link ("don't use confirmation link
 * anymore to verify email, let's use confirmation code, a 6 digit code
 * - do this update on both the mobile app and website").
 *
 * Signup (register) and a blocked sign-in both land on this card: the
 * account exists but its email is unconfirmed, and the study desk stays
 * closed until the mailed code is entered. The card verifies the code,
 * upgrades the restricted session server-side (/auth/refresh re-mints
 * the token without the unverified claim) and offers the resend (server
 * cooldown: one mail a minute), the wrong-email rescue and a sign-out.
 */

import { useState } from 'react';
import Link from 'next/link';
import { ApiError, api } from '@/lib/api';
import { getToken, setSession } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

interface ConfirmEmailCardProps {
  /** The signup address the code was mailed to (when known). */
  email?: string;
  /** True when the mail transport refused the send (Brevo hiccup):
   * the student is told to retry the resend instead of waiting. */
  mailFailed?: boolean;
  /** Where the "sign out" hop goes (login for web signups). */
  onSignOut?: () => void;
  /** Called the moment the code verifies and the session is seated -
   * the parent takes over routing (and any post-verify popup). */
  onVerified?: () => void;
}

export default function ConfirmEmailCard({
  email,
  mailFailed,
  onSignOut,
  onVerified,
}: ConfirmEmailCardProps) {
  const [code, setCode] = useState('');
  const [verifyState, setVerifyState] = useState<'idle' | 'busy' | 'done'>('idle');
  const [seated, setSeated] = useState(false);
  const [error, setError] = useState('');
  const [resendState, setResendState] = useState<'idle' | 'busy' | 'sent'>('idle');
  const [changing, setChanging] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [changedTo, setChangedTo] = useState('');
  const [busy, setBusy] = useState(false);

  const verify = async () => {
    const entered = code.replace(/\D/g, '');
    if (entered.length !== 6) {
      setError('Enter the 6-digit code from your mail.');
      return;
    }
    setVerifyState('busy');
    setError('');
    try {
      await api<{ verified: boolean }>('/auth/verify-email', {
        method: 'POST',
        body: { code: entered },
        auth: false,
        noRedirect: true,
      });
      setVerifyState('done');
      // Upgrade the restricted session (web signup or blocked sign-in
      // parked one here): /auth/refresh re-mints the token without the
      // unverified claim, so the study surface opens with zero extra
      // sign-ins.
      if (getToken()) {
        try {
          const refreshed = await api<{
            token: string;
            user: { id: string; username: string; profileCompleted: boolean };
          }>('/auth/refresh', { method: 'POST', noRedirect: true });
          setSession(refreshed.token, refreshed.user);
          setSeated(true);
        } catch {
          // The account is confirmed anyway - sign-in still works.
        }
      }
      onVerified?.();
    } catch (e) {
      setVerifyState('idle');
      setError(
        e instanceof ApiError
          ? e.message
          : 'That code did not verify - check it and try again.',
      );
    }
  };

  const resend = async () => {
    setResendState('busy');
    setError('');
    try {
      const res = await api<{ verified?: boolean }>('/auth/resend-verification', {
        method: 'POST',
        noRedirect: true,
      });
      if (res?.verified) {
        // Already confirmed: sign in again to get the seated session.
        setError('This email is already confirmed - sign in again below.');
        setResendState('idle');
        return;
      }
      setResendState('sent');
    } catch (e) {
      setResendState('idle');
      setError(
        e instanceof ApiError ? e.message : 'The mail could not be sent, try again in a minute.',
      );
    }
  };

  const changeEmail = async () => {
    setError('');
    setBusy(true);
    try {
      await api('/me/change-email', {
        method: 'POST',
        body: { email: newEmail.trim() },
        noRedirect: true,
      });
      setChangedTo(newEmail.trim());
      setChanging(false);
      setResendState('idle');
    } catch (e) {
      setError(
        e instanceof ApiError ? e.message : 'The email could not be changed, try again.',
      );
    } finally {
      setBusy(false);
    }
  };

  if (verifyState === 'done') {
    return (
      <main className="flex min-h-dvh w-full flex-col items-center justify-center bg-surface-container px-4 py-10">
        <div className="renance-rise w-full max-w-sm rounded-xl bg-surface-container-lowest p-8 text-center shadow-md">
          <div className="mb-5 flex justify-center">
            <RenanceMark size={56} />
          </div>
          <h1 className="text-xl font-semibold tracking-tight text-on-surface">
            Email confirmed
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
            Your account is fully unlocked.{' '}
            {seated
              ? 'Welcome to Renance - your studies continue from here.'
              : 'Sign in to continue studying.'}
          </p>
          <div className="mt-6 flex flex-col gap-2">
            {onVerified ? null : (
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
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4 py-10">
      <div className="renance-rise my-auto flex w-full max-w-sm flex-col rounded-xl bg-surface-container-lowest p-8 text-center shadow-md">
        <div className="mb-5 flex justify-center">
          <RenanceMark size={56} />
        </div>
        <h1 className="text-xl font-semibold tracking-tight text-on-surface">
          Confirm your email
        </h1>
        <p className="mt-3 text-sm leading-relaxed text-on-surface-variant">
          We sent a <b className="text-on-surface">6-digit confirmation code</b> to{' '}
          <span className="font-semibold text-on-surface">{changedTo || email || 'your email'}</span>.
          Type it below to unlock your account.
        </p>
        {/* Spam-folder hint (founder directive 2026-10-02): the sending
            domain is new, so Gmail/Outlook may initially file Renance mail
            under spam - telling students where to look saves the signup. */}
        <p className="mt-3 rounded-lg bg-surface-container px-3 py-2 text-[12.5px] leading-relaxed text-on-surface-variant">
          Nothing yet? Check your <b className="text-on-surface">spam folder</b> - if the mail
          landed there, open it and mark it <b className="text-on-surface">Not spam</b> so
          future Renance mails reach your main inbox.
        </p>
        {mailFailed && (
          <p className="mt-3 rounded-lg bg-error-container px-3 py-2 text-[12.5px] text-on-error-container">
            The mail service is slow right now - if nothing arrives, tap resend below in a
            minute or change the address.
          </p>
        )}
        {changedTo && (
          <p className="mt-3 rounded-lg bg-surface-container px-3 py-2 text-[12.5px] text-on-surface-variant">
            The signup email is now <b className="text-on-surface">{changedTo}</b> - the old
            address was removed and a fresh code is on its way there.
          </p>
        )}

        {/* The code entry: one numeric field, digits spaced so it reads
            like the mail's big code block. Enter submits. */}
        <div className="mt-5 flex flex-col items-center gap-3">
          <input
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="[0-9]*"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && verifyState !== 'busy') void verify();
            }}
            placeholder="000000"
            aria-label="6-digit confirmation code"
            className="h-14 w-56 rounded-xl border border-outline bg-surface-container-lowest text-center text-2xl font-semibold tracking-[0.5em] text-on-surface outline-none focus:ring-2 focus:ring-primary [text-indent:0.5em]"
          />
          <button
            type="button"
            onClick={() => void verify()}
            disabled={verifyState === 'busy' || code.replace(/\D/g, '').length !== 6}
            className="flex h-12 w-full items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
          >
            {verifyState === 'busy' ? 'Verifying…' : 'Confirm my email'}
          </button>
        </div>

        <div className="mt-4 flex flex-col gap-2">
          <button
            type="button"
            onClick={() => void resend()}
            disabled={resendState === 'busy'}
            className="flex h-11 items-center justify-center rounded-full border border-outline text-sm font-semibold text-on-surface transition hover:bg-surface-container disabled:opacity-50"
          >
            {resendState === 'busy'
              ? 'Sending…'
              : resendState === 'sent'
                ? 'Code sent, check the inbox'
                : 'Resend the code'}
          </button>
          {onSignOut ? (
            <button
              type="button"
              onClick={onSignOut}
              className="flex h-11 items-center justify-center rounded-full text-sm font-semibold text-on-surface-variant transition hover:text-on-surface"
            >
              Sign out
            </button>
          ) : (
            <Link
              href="/login"
              className="flex h-11 items-center justify-center rounded-full text-sm font-semibold text-on-surface-variant transition hover:text-on-surface"
            >
              Sign out
            </Link>
          )}
        </div>

        {changing ? (
          <div className="mt-4 flex flex-col gap-2 text-left">
            <label htmlFor="confirm-new-email" className="text-[12px] font-medium text-on-surface-variant">
              The correct email address (replaces the mistaken one)
            </label>
            <input
              id="confirm-new-email"
              type="email"
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              placeholder="you@example.com"
              autoComplete="email"
              className="h-11 w-full rounded-[10px] border border-outline bg-surface-container-lowest px-3 text-sm text-on-surface outline-none focus:ring-2 focus:ring-primary"
            />
            <button
              type="button"
              onClick={() => void changeEmail()}
              disabled={busy || !newEmail.trim()}
              className="flex h-11 w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
            >
              {busy ? 'Saving…' : 'Save and send the code there'}
            </button>
          </div>
        ) : (
          !changedTo && (
            <button
              type="button"
              onClick={() => setChanging(true)}
              className="mt-3 text-[12.5px] text-on-surface-variant underline underline-offset-2 hover:text-on-surface"
            >
              Typed a wrong email? Change it
            </button>
          )
        )}
        {error && <p className="mt-3 text-[12.5px] text-error">{error}</p>}
        <p className="mt-4 text-[11.5px] leading-relaxed text-on-surface-variant">
          The code works once and expires in 24 hours - a resend issues a fresh one any time.
        </p>
      </div>
    </main>
  );
}
