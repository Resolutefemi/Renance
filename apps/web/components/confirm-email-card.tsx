'use client';

/**
 * ConfirmEmailCard - the one confirmation surface every entry point
 * shares. Signup (register) and a blocked sign-in both land here: the
 * account exists but its email is unconfirmed, and the study desk
 * stays closed until the mailed link is consumed. The card offers the
 * resend (server cooldown: one mail a minute), the wrong-email rescue
 * (the API swaps the address and re-mails) and a sign-out. It polls
 * nothing: the /verify landing page completes the flow and refreshes
 * the session.
 */

import { useState } from 'react';
import Link from 'next/link';
import { ApiError, api } from '@/lib/api';
import { RenanceMark } from '@/components/renance-logo';

interface ConfirmEmailCardProps {
  /** The signup address the confirmation link went to. */
  email: string;
  /** True when the mail transport refused the send (Brevo hiccup):
   * the student is told to retry the resend instead of waiting. */
  mailFailed?: boolean;
  /** Where the "sign out" hop goes (login for web signups). */
  onSignOut?: () => void;
}

export default function ConfirmEmailCard({ email, mailFailed, onSignOut }: ConfirmEmailCardProps) {
  const [resendState, setResendState] = useState<'idle' | 'busy' | 'sent'>('idle');
  const [resendError, setResendError] = useState('');
  const [changing, setChanging] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [changedTo, setChangedTo] = useState('');
  const [busy, setBusy] = useState(false);

  const resend = async () => {
    setResendState('busy');
    setResendError('');
    try {
      const res = await api<{ verified?: boolean }>('/auth/resend-verification', {
        method: 'POST',
        noRedirect: true,
      });
      if (res?.verified) {
        // The link was already consumed: sign in again to get the
        // seated session.
        setResendError('This email is already confirmed - sign in again below.');
        return;
      }
      setResendState('sent');
    } catch (e) {
      setResendState('idle');
      setResendError(
        e instanceof ApiError ? e.message : 'The mail could not be sent, try again in a minute.',
      );
    }
  };

  const changeEmail = async () => {
    setResendError('');
    setBusy(true);
    try {
      await api('/me/change-email', {
        method: 'POST',
        body: { email: newEmail.trim(), return: 'web' },
        noRedirect: true,
      });
      setChangedTo(newEmail.trim());
      setChanging(false);
      setResendState('idle');
    } catch (e) {
      setResendError(
        e instanceof ApiError ? e.message : 'The email could not be changed, try again.',
      );
    } finally {
      setBusy(false);
    }
  };

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
          We sent a confirmation link to{' '}
          <span className="font-semibold text-on-surface">{changedTo || email}</span>. Your
          account stays locked until you confirm - open the link to unlock your studies.
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
            address was removed and a fresh link is on its way there.
          </p>
        )}

        <div className="mt-6 flex flex-col gap-2">
          <button
            type="button"
            onClick={resend}
            disabled={resendState === 'busy'}
            className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
          >
            {resendState === 'busy'
              ? 'Sending…'
              : resendState === 'sent'
                ? 'Confirmation sent, check the inbox'
                : 'Resend the confirmation mail'}
          </button>
          {onSignOut ? (
            <button
              type="button"
              onClick={onSignOut}
              className="flex h-12 items-center justify-center rounded-full border border-outline text-sm font-semibold text-on-surface transition hover:bg-surface-container"
            >
              Sign out
            </button>
          ) : (
            <Link
              href="/login"
              className="flex h-12 items-center justify-center rounded-full border border-outline text-sm font-semibold text-on-surface transition hover:bg-surface-container"
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
              onClick={changeEmail}
              disabled={busy || !newEmail.trim()}
              className="flex h-11 w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
            >
              {busy ? 'Saving…' : 'Save and send the link there'}
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
        {resendError && <p className="mt-3 text-[12.5px] text-error">{resendError}</p>}
        <p className="mt-4 text-[11.5px] leading-relaxed text-on-surface-variant">
          Confirmed on another device? Sign in again - the mail link unlocks the account
          everywhere.
        </p>
      </div>
    </main>
  );
}
