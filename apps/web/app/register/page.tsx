'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { setSession } from '@/lib/session';
import { schoolRegister, setActiveSchool } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import AppearanceModal, { needsAppearanceIntro } from '@/components/appearance-modal';
import { AudienceToggle, type Audience } from '@/components/audience-toggle';
import { MailIcon, LockIcon, EyeIcon } from '@/components/icons';

export default function RegisterPage() {
  const router = useRouter();
  const [audience, setAudience] = useState<Audience>('students');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [referral, setReferral] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // Post-signup confirmation notice: manual signups confirm their email
  // through the mailed link. SIGNUP-ONLY - the desk never blocks on it;
  // this screen just offers resend and the wrong-email rescue.
  const [verifySent, setVerifySent] = useState(false);
  const [signedEmail, setSignedEmail] = useState('');
  const [mailFailed, setMailFailed] = useState(false);
  const [resendState, setResendState] = useState<'idle' | 'busy' | 'sent'>('idle');
  const [resendError, setResendError] = useState('');
  // Wrong-email rescue: students who typo'd their signup address swap it
  // here. The API overwrites the old address in the database (it is
  // gone, not deactivated) and re-mails the confirmation to the new one.
  const [changing, setChanging] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [changedTo, setChangedTo] = useState('');

  // Founder directive (2026-09-28): the appearance popup fires right
  // after a first signup, before whatever comes next (verify notice or
  // dashboard). afterAppearance holds the pending continuation so the
  // flow resumes the moment the student closes the dialog.
  const [showAppearance, setShowAppearance] = useState(false);
  const [afterAppearance, setAfterAppearance] = useState<(() => void) | null>(null);

  const finishStudentSignup = (next: () => void) => {
    if (needsAppearanceIntro()) {
      setAfterAppearance(() => next);
      setShowAppearance(true);
      return;
    }
    next();
  };

  const closeAppearance = () => {
    setShowAppearance(false);
    const next = afterAppearance;
    setAfterAppearance(null);
    next?.();
  };

  // school-only fields
  const [schoolName, setSchoolName] = useState('');
  const [schoolType, setSchoolType] = useState('secondary');
  const [fullName, setFullName] = useState('');

  const mismatch = confirmPassword.length > 0 && password !== confirmPassword;

  useEffect(() => {
    document.title = 'Create your account · Renance';
  }, []);

  // Deep link: /register/?audience=school opens the For Schools form
  // (the landing page "Register your school" button lands here);
  // /register/?ref=CODE pre-fills the referral field.
  useEffect(() => {
    try {
      const q = new URLSearchParams(window.location.search);
      const a = q.get('audience');
      if (a === 'school' || a === 'schools') setAudience('schools');
      const ref = q.get('ref');
      if (ref) setReferral(ref.toUpperCase());
    } catch {
      /* private mode: default to students */
    }
  }, []);

  // Stable identity for the GIS callback, never re-initialize mid-signup.
  const onGoogleCredential = useCallback(
    async (credential: string) => {
      setError(null);
      setBusy(true);
      try {
        const res = await authWithGoogle(credential);
        setSession(res.token, res.user);
        // A brand-new Google account IS a first signup: the appearance
        // popup fires once, then the desk opens.
        finishStudentSignup(() => router.replace('/dashboard'));
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'Google sign-in failed, check the connection.');
        setBusy(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [router],
  );

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    if (audience === 'schools' && schoolName.trim().length < 3) {
      setError('Enter the school name.');
      return;
    }
    if (audience === 'schools' && fullName.trim().length < 3) {
      setError('Enter your full name (the management account holder).');
      return;
    }
    setBusy(true);
    try {
      if (audience === 'schools') {
        const res = await schoolRegister({
          schoolName: schoolName.trim(),
          schoolType,
          fullName: fullName.trim(),
          email: email.trim(),
          password,
        });
        setSession(res.token, res.user);
        setActiveSchool({
          schoolId: res.school.id,
          schoolName: res.school.name,
          role: 'management',
          memberId: res.school.memberId,
          fullName: fullName.trim(),
        });
        router.replace('/school');
        return;
      }
      const res = await api<{
        token: string;
        user: { id: string; username: string; profileCompleted: boolean };
        emailVerification?: { required?: boolean; sent?: boolean };
      }>('/auth/register', {
        method: 'POST',
        body: {
          email,
          password,
          verifyReturn: 'web',
          ...(referral.trim() ? { referral: referral.trim().toUpperCase() } : {}),
        },
        auth: false,
      });
      setSession(res.token, res.user);
      if (res.emailVerification?.required) {
        finishStudentSignup(() => {
          setSignedEmail(email.trim());
          setMailFailed(res.emailVerification?.sent === false);
          setVerifySent(true);
          setBusy(false);
        });
        return;
      }
      finishStudentSignup(() => router.replace('/dashboard'));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  const resend = async () => {
    setResendState('busy');
    setResendError('');
    try {
      await api('/auth/resend-verification', { method: 'POST' });
      setResendState('sent');
    } catch (e) {
      setResendState('idle');
      setResendError(
        e instanceof ApiError ? e.message : 'The mail could not be sent, try again in a minute.',
      );
    }
  };

  const changeEmail = async () => {
    setResendState('idle');
    setResendError('');
    setBusy(true);
    try {
      await api('/me/change-email', {
        method: 'POST',
        body: { email: newEmail.trim(), return: 'web' },
      });
      setChangedTo(newEmail.trim());
      setSignedEmail(newEmail.trim());
      setChanging(false);
      setMailFailed(false);
    } catch (e) {
      setResendError(
        e instanceof ApiError ? e.message : 'The email could not be changed, try again.',
      );
    } finally {
      setBusy(false);
    }
  };

  const field = 'h-12 w-full rounded-lg bg-surface-container pl-11 pr-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary';

  if (verifySent) {
    return (
      <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4 py-10">
        <AppearanceModal open={showAppearance} onClose={closeAppearance} />
        <div className="renance-rise my-auto flex w-full max-w-sm flex-col rounded-xl bg-surface-container-lowest p-8 text-center shadow-md">
          <div className="mb-5 flex justify-center">
            <RenanceMark size={56} />
          </div>
          <h1 className="text-xl font-semibold tracking-tight text-on-surface">
            Check your inbox
          </h1>
          <p className="mt-3 text-sm leading-relaxed text-on-surface-variant">
            We sent a confirmation link to{' '}
            <span className="font-semibold text-on-surface">{signedEmail}</span>. Confirm
            whenever you like - you can keep studying right away.
          </p>
          {mailFailed && (
            <p className="mt-3 rounded-lg bg-error-container px-3 py-2 text-[12.5px] text-on-error-container">
              The mail service is slow right now - if nothing arrives, tap
              resend below in a minute or change the address.
            </p>
          )}
          {changedTo && (
            <p className="mt-3 rounded-lg bg-surface-container px-3 py-2 text-[12.5px] text-on-surface-variant">
              The signup email is now <b className="text-on-surface">{changedTo}</b> - the
              old address was removed and a fresh link is on its way there.
            </p>
          )}
          <div className="mt-6 flex flex-col gap-2">
            <button
              onClick={() => router.replace('/dashboard')}
              className="flex h-12 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary transition hover:opacity-90"
            >
              Continue to dashboard
            </button>
            <button
              type="button"
              onClick={resend}
              disabled={resendState === 'busy'}
              className="flex h-12 items-center justify-center rounded-full border border-outline text-sm font-semibold text-on-surface transition hover:bg-surface-container disabled:opacity-50"
            >
              {resendState === 'busy'
                ? 'Sending…'
                : resendState === 'sent'
                  ? 'Confirmation sent, check the inbox'
                  : 'Resend the confirmation mail'}
            </button>
            <Link
              href="/login"
              className="flex h-12 items-center justify-center rounded-full text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD]"
            >
              Go to sign in
            </Link>
          </div>
          {changing ? (
            <div className="mt-4 flex flex-col gap-2 text-left">
              <label htmlFor="register-new-email" className="text-[12px] font-medium text-on-surface-variant">
                The correct email address (replaces the mistaken one)
              </label>
              <input
                id="register-new-email"
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
        </div>
      </main>
    );
  }

  return (
    // my-auto (not justify-center) keeps the card visually centred while
    // letting the page grow: on small phones the For Schools form is taller
    // than the viewport, and justify-center would clip the unreachable top
    // of the card. Everything wraps: break-words guards the headings even
    // when Android font scaling inflates the text past the card edge.
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4 py-10">
      <AppearanceModal open={showAppearance} onClose={closeAppearance} />
      <div className="renance-rise my-auto flex w-full max-w-sm min-w-0 flex-col rounded-xl bg-surface-container-lowest p-6 shadow-md">
        {/* Logo block, mockup: logo, headline, sub */}
        <div className="mb-5 flex min-w-0 flex-col items-center gap-3 text-center">
          <RenanceMark size={64} />
          <div className="min-w-0">
            <h1 className="break-words text-2xl font-semibold tracking-tight text-on-surface">
              {audience === 'schools' ? 'Register your school' : 'Create your account'}
            </h1>
            <p className="mt-1 break-words text-sm text-on-surface-variant">
              {audience === 'schools'
                ? 'The study OS for your whole school: management, teachers and students.'
                : 'Join the global student study OS.'}
            </p>
          </div>
        </div>

        <div className="mb-5">
          <AudienceToggle audience={audience} onChange={setAudience} mode="register" />
        </div>

        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          {audience === 'schools' && (
            <>
              <div className="flex flex-col gap-1.5">
                <label htmlFor="school-name" className="text-sm text-on-surface">
                  School name
                </label>
                <input
                  id="school-name"
                  type="text"
                  value={schoolName}
                  onChange={(e) => setSchoolName(e.target.value)}
                  required
                  maxLength={120}
                  placeholder="e.g. God Generals Standard Academy"
                  className={`${field} pl-4`}
                />
              </div>
              <div className="flex flex-col gap-1.5">
                <label htmlFor="school-type" className="text-sm text-on-surface">
                  School type
                </label>
                <select
                  id="school-type"
                  value={schoolType}
                  onChange={(e) => setSchoolType(e.target.value)}
                  className={`${field} pl-4`}
                >
                  <option value="primary">Primary school</option>
                  <option value="secondary">Secondary school</option>
                  <option value="both">Both (primary + secondary)</option>
                </select>
              </div>
              <div className="flex flex-col gap-1.5">
                <label htmlFor="full-name" className="text-sm text-on-surface">
                  Your full name (management)
                </label>
                <input
                  id="full-name"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  required
                  maxLength={120}
                  placeholder="e.g. Mrs. Ariyo O."
                  className={`${field} pl-4`}
                />
              </div>
            </>
          )}

          <div className="flex flex-col gap-1.5">
            <label htmlFor="email" className="text-sm text-on-surface">
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
                maxLength={254}
                placeholder="you@example.com"
                className={field}
              />
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="password" className="text-sm text-on-surface">
              Password
            </label>
            <div className="group relative flex items-center">
              <LockIcon className="pointer-events-none absolute left-3 h-5 w-5 text-on-surface-variant transition-colors group-focus-within:text-primary" />
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                required
                minLength={6}
                placeholder="••••••••"
                className="h-12 w-full rounded-lg bg-surface-container pl-11 pr-12 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
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
            <p className="text-xs text-on-surface-variant">
              At least 8 characters. We ask for the rest after you&apos;re in.
            </p>
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
                autoComplete="new-password"
                required
                placeholder="••••••••"
                className={`h-12 w-full rounded-lg bg-surface-container pl-11 pr-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 ${
                  mismatch ? 'ring-2 ring-error' : 'focus:ring-primary'
                }`}
              />
            </div>
            {mismatch && <p className="text-xs text-error">Passwords do not match.</p>}
          </div>

          {/* Referral (students): a friend's REN code earns them 3 REN. */}
          {audience === 'students' && (
            <div className="flex flex-col gap-1.5">
              <label htmlFor="referral" className="text-sm text-on-surface">
                Referral code <span className="text-on-surface-variant">(optional)</span>
              </label>
              <input
                id="referral"
                type="text"
                value={referral}
                onChange={(e) => setReferral(e.target.value)}
                maxLength={16}
                placeholder="REN..."
                className={`${field} pl-4 uppercase`}
              />
              <p className="text-xs text-on-surface-variant">
                Your friend earns 3 REN coins when you join.
              </p>
            </div>
          )}

          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              {error}
            </p>
          )}

          {/* Mockup: black pill button, press scale */}
          <button
            type="submit"
            disabled={busy || mismatch}
            className="mt-1 flex h-12 w-full items-center justify-center gap-2 rounded-full bg-primary text-on-primary transition-all hover:opacity-90 hover:shadow-md active:scale-[0.98] disabled:opacity-60"
          >
            {busy ? (
              <>
                <RenanceMark size={22} state="busy" />
                {audience === 'schools' ? 'Setting up school…' : 'Creating account…'}
              </>
            ) : audience === 'schools' ? (
              'Create School Workspace'
            ) : (
              'Create Account'
            )}
          </button>

          {/* Google sign-up (students only), hidden unless the client ID is baked in */}
          {audience === 'students' && <GoogleSignIn onCredential={onGoogleCredential} />}
        </form>

        <p className="mt-6 text-center text-sm text-on-surface-variant">
          Already have an account?{' '}
          <Link
            href="/login"
            className="font-medium text-primary underline-offset-4 hover:underline"
          >
            Log In
          </Link>
        </p>
      </div>
    </main>
  );
}
