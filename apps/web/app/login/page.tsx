'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { clearSession, nextPath, setSession } from '@/lib/session';
import { stampWhatsAppPrompt } from '@/components/whatsapp-channel-modal';
import { chooseSchool, schoolMe } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import ConfirmEmailCard from '@/components/confirm-email-card';
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

  // Founder directive (2026-10-14): the appearance POPUP is retired
  // completely. Students who want to change how Renance looks go to
  // Settings → Appearance themselves; sign-in flows straight through.

  // Deep link (founder bugfix 2026-10-05): /login/?audience=school opens
  // the For Schools form - the register page's Log In hop carries the
  // tab across, so a school manager never lands back on the student
  // sign-in.
  useEffect(() => {
    try {
      const q = new URLSearchParams(window.location.search);
      const a = q.get('audience');
      if (a === 'school' || a === 'schools') setAudience('schools');
    } catch {
      /* private mode: default to students */
    }
  }, []);

  const finishLogin = (next: () => void) => {
    // Founder directive 2026-10-17: every login pings the WhatsApp
    // channel sheet (until the student actually joins - the Join button
    // is the only thing that silences it forever).
    stampWhatsAppPrompt();
    next();
  };

  // Founder directive (2026-09-30): a login whose signup email was never
  // confirmed does not open the desk. The API answers 403
  // email_unverified with a fresh confirmation mail and a restricted
  // session; this screen becomes the confirm card (resend + wrong-email
  // rescue) until the link is consumed.
  const [confirmEmail, setConfirmEmail] = useState<string | null>(null);
  const [confirmMailFailed, setConfirmMailFailed] = useState(false);

  // Stable identity for the GIS callback, never re-initialize mid-session.
  const onGoogleCredential = useCallback(
    async (credential: string) => {
      setError(null);
      setBusy(true);
      try {
        const res = await authWithGoogle(credential);
        setSession(res.token, res.user);
        finishLogin(() => router.replace(nextPath()));
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
    setBusy(true);
    try {
      const res = await api<{ token: string; user: { id: string; username: string; profileCompleted: boolean } }>(
        '/auth/login',
        {
          method: 'POST',
          // Audience (founder directive 2026-10-02): school workplace
          // accounts and student accounts are separate. The server
          // refuses a student account under For Schools (and a school
          // account under For Students) before any session is seated.
          body: { email, password, audience },
          auth: false,
        },
      );
      setSession(res.token, res.user);

      if (audience === 'schools') {
        // Route school members into the school workspace. The audience
        // gate already refused student accounts server-side; the me()
        // lookup here only picks the active membership.
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
      // ?next= (built by PracticeGate) sends the student straight back
      // to the paper they came for; default stays the desk.
      finishLogin(() => router.replace(nextPath()));
    } catch (err) {
      // Blocked sign-in: the signup email is still unconfirmed. The 403
      // carries a restricted session (drives the resend + wrong-email
      // rescue) and the address the fresh confirmation mail went to.
      if (err instanceof ApiError && err.code === 'email_unverified' && err.data) {
        const token = err.data.token as string | undefined;
        const user = err.data.user as { id: string; username: string; profileCompleted: boolean } | undefined;
        const verify = err.data.emailVerification as
          | { sent?: boolean; email?: string }
          | undefined;
        if (token && user) setSession(token, user);
        setConfirmMailFailed(verify?.sent === false);
        setConfirmEmail((verify?.email as string) || email.trim());
        setBusy(false);
        return;
      }
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  // The blocked-login confirm card replaces the form: the account is
  // real but locked until the emailed 6-digit code is typed in (founder
  // directive 2026-10-05). Verification seats the session and the
  // normal post-login flow (appearance intro on first login, then the
  // desk) resumes from there.
  if (confirmEmail) {
    return (
      <>
        <ConfirmEmailCard
          email={confirmEmail}
          mailFailed={confirmMailFailed}
          onVerified={() => finishLogin(() => router.replace(nextPath()))}
          onSignOut={() => {
            clearSession();
            setConfirmEmail(null);
            setPassword('');
          }}
        />
      </>
    );
  }

  return (
    // my-auto (not justify-center) keeps the block visually centred while
    // letting the page grow: on small phones the For Schools form is taller
    // than the viewport, and justify-center would clip the unreachable top.
    // Round 8 (Task 4-d): duolingo.com/log-in restyle - white page, one
    // centered 24px card, chunky 3D buttons, 2px-border inputs. Handlers,
    // state, POST bodies and session flow are untouched.
    <main className="flex min-h-dvh w-full flex-col items-center bg-background px-4">
      <div className="my-auto flex w-full max-w-md min-w-0 flex-col items-center py-10">
        {/* Keycap + heading, Duolingo-style centered intro */}
        <div className="mb-6 flex min-w-0 flex-col items-center">
          <RenanceMark size={64} />
          <h1 className="mt-4 break-words text-center text-[32px] font-extrabold leading-tight tracking-tight text-on-surface">
            Log in
          </h1>
          <p className="mt-1 break-words text-center text-sm text-on-surface-variant">
            Sign in to continue to Renance.
          </p>
        </div>

        {/* Audience switch - students by default, schools for management + teachers */}
        <div className="duo-audience mb-5 w-full">
          <AudienceToggle audience={audience} onChange={setAudience} mode="login" />
        </div>

        {/* Card: white, 24px radius, 2px swan border, extruded edge */}
        <form
          onSubmit={onSubmit}
          className="flex w-full flex-col gap-4 rounded-[24px] border-2 border-outline-variant bg-card p-6 shadow-[0_3px_0_0_var(--color-outline-variant)]"
        >
          {/* Google sign-in (students), hidden unless the client ID is baked in.
              The .duo-social wrapper flips GoogleSignIn's internal divider so
              the card reads [CONTINUE WITH GOOGLE] / [or] / [email form] - the
              component internals are untouched. */}
          {audience === 'students' && (
            <div className="duo-social w-full">
              <GoogleSignIn onCredential={onGoogleCredential} />
            </div>
          )}

          <div className="flex flex-col gap-1.5">
            <label htmlFor="email" className="text-[13px] font-bold text-on-surface">
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
                className="input-duo input-duo-icon"
              />
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="password" className="text-[13px] font-bold text-on-surface">
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
                className="input-duo input-duo-icon input-duo-eye"
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

          {/* Forgot password (founder directive 2026-10-02): works for
              student and school accounts - the reset link mails to the
              address on the account. */}
          <div className="-mt-1 flex justify-end">
            <Link
              href="/forgot-password"
              className="text-sm font-semibold text-on-surface-variant underline-offset-4 hover:text-on-surface hover:underline"
            >
              Forgot password?
            </Link>
          </div>

          {/* Chunky 3D submit (Round 8): green face, extruded edge, presses
              down on click. Labels stay LOG IN / OPEN SCHOOL WORKSPACE via
              the uppercase transform. */}
          <button
            type="submit"
            disabled={busy}
            className="btn-3d mt-1 w-full"
          >
            {busy ? (
              <>
                <RenanceMark size={22} state="busy" />
                Signing in…
              </>
            ) : (
              <>
                {audience === 'schools' ? 'Open School Workspace' : 'Log in'}
                <ArrowIcon className="h-5 w-5" />
              </>
            )}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-on-surface-variant">
          Don&apos;t have an account?{' '}
          {/* Event-time href so a ?next= return path survives the hop
              without a hydration mismatch on the prerendered page. The
              FOR SCHOOLS tab travels along (founder bugfix 2026-10-05):
              Sign up for school opens the school sign-up form. */}
          <button
            type="button"
            onClick={() =>
              router.push(
                `/register/?next=${encodeURIComponent(nextPath('/dashboard'))}${
                  audience === 'schools' ? '&audience=school' : ''
                }`,
              )
            }
            className="ml-1 font-extrabold text-primary underline-offset-4 hover:underline"
          >
            Sign up
          </button>
        </p>
      </div>
    </main>
  );
}
