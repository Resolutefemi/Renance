'use client';

import { FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { nextPath, setSession } from '@/lib/session';
import { schoolRegister, setActiveSchool } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import ConfirmEmailCard from '@/components/confirm-email-card';
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
  // Founder directive 2026-10-05: account creation is gated on the
  // terms + privacy consent. Unchecked by default, required for BOTH
  // audiences and for the Google sign-up hop (its callback re-checks).
  const [accepted, setAccepted] = useState(false);
  // onGoogleCredential is memoized with [router] only, so it reads the
  // consent through a ref: the check always sees the CURRENT box, not
  // the one captured at memoization time.
  const acceptedRef = useRef(accepted);
  acceptedRef.current = accepted;
  // Post-signup confirmation stop (founder directive 2026-09-30): a
  // manual signup does NOT enter the desk until the mailed link is
  // consumed - the session the API returned is restricted to the
  // confirmation surface only. This card carries the resend and the
  // wrong-email rescue.
  const [verifySent, setVerifySent] = useState(false);
  const [signedEmail, setSignedEmail] = useState('');
  const [mailFailed, setMailFailed] = useState(false);

  // Founder directive (2026-10-02, restored): the appearance popup
  // fires right after a first signup (or a first login on a device that
  // never met the picker), before whatever comes next (verify notice or
  // dashboard). afterAppearance holds the pending continuation so the
  // flow resumes the moment the student closes the dialog.

  const finishStudentSignup = (next: () => void) => {
    next();
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
      // Consent travels with the Google hop too: no checkbox, no account.
      if (!acceptedRef.current) {
        setError('Please accept the Terms of Service and Privacy Policy first.');
        return;
      }
      setError(null);
      setBusy(true);
      try {
        const res = await authWithGoogle(credential);
        setSession(res.token, res.user);
        // A brand-new Google account IS a first signup: the appearance
        // popup fires once, then the desk opens - or the paper the
        // visitor came from, when PracticeGate sent them here.
        finishStudentSignup(() => router.replace(nextPath()));
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
    if (!accepted) {
      setError('Please accept the Terms of Service and Privacy Policy.');
      return;
    }
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
        // Founder directive 2026-10-05: the appearance popup waits until
        // the 6-digit code is verified - the confirm card calls onVerified
        // and the flow (appearance intro, then the desk) resumes there.
        setSignedEmail(email.trim());
        setMailFailed(res.emailVerification?.sent === false);
        setVerifySent(true);
        setBusy(false);
        return;
      }
      finishStudentSignup(() => router.replace(nextPath()));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  const field = 'h-12 w-full rounded-lg bg-surface-container pl-11 pr-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary';

  if (verifySent) {
    return (
      <>
        <ConfirmEmailCard
          email={signedEmail}
          mailFailed={mailFailed}
          onVerified={() => finishStudentSignup(() => router.replace(nextPath()))}
        />
      </>
    );
  }

  return (
    // my-auto (not justify-center) keeps the card visually centred while
    // letting the page grow: on small phones the For Schools form is taller
    // than the viewport, and justify-center would clip the unreachable top
    // of the card. Everything wraps: break-words guards the headings even
    // when Android font scaling inflates the text past the card edge.
    <main className="flex min-h-dvh w-full flex-col items-center bg-surface-container px-4 py-10">
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
                ? 'The educational app for your whole school: management, teachers and students.'
                : 'Join the global student educational app.'}
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
                  placeholder="e.g. Living Grace Academy"
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
                  placeholder="e.g. Mr Kelvin O."
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

          {/* Founder directive 2026-10-05: the consent checkbox rides
              under both signup forms (students and For Schools). The
              submit stays dead until it is ticked, and the Privacy
              Policy opens the public /privacy page in a new tab. */}
          <label className="flex cursor-pointer items-start gap-2.5 select-none">
            <input
              type="checkbox"
              checked={accepted}
              onChange={(e) => setAccepted(e.target.checked)}
              required
              style={{ accentColor: 'var(--color-primary)', marginTop: 2 }}
              className="h-4 w-4 shrink-0"
            />
            <span className="text-xs leading-relaxed text-on-surface-variant">
              I accept the Terms of Service and{' '}
              <a
                href="/privacy/"
                target="_blank"
                rel="noopener noreferrer"
                className="font-medium text-primary underline underline-offset-2"
              >
                Privacy Policy
              </a>
              .
            </span>
          </label>

          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              {error}
            </p>
          )}

          {/* Mockup: black pill button, press scale */}
          <button
            type="submit"
            disabled={busy || mismatch || !accepted}
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

          {/* Google sign-up (students only), hidden unless the client ID is
              baked in. onGoogleCredential re-checks the consent through
              the ref, so a Google hop can never create an unchecked
              account. */}
          {audience === 'students' && <GoogleSignIn onCredential={onGoogleCredential} />}
        </form>

        <p className="mt-6 text-center text-sm text-on-surface-variant">
          Already have an account?{' '}
          {/* Event-time href so a ?next= return path survives the hop
              without a hydration mismatch on the prerendered page. The
              FOR SCHOOLS tab travels along (founder bugfix 2026-10-05):
              a school sign-up's Log In opens the school sign-in. */}
          <button
            type="button"
            onClick={() =>
              router.push(
                `/login/?next=${encodeURIComponent(nextPath('/dashboard'))}${
                  audience === 'schools' ? '&audience=school' : ''
                }`,
              )
            }
            className="font-medium text-primary underline-offset-4 hover:underline"
          >
            Log In
          </button>
        </p>
      </div>
    </main>
  );
}
