'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ApiError, api, authWithGoogle } from '@/lib/api';
import { setSession } from '@/lib/session';
import { schoolRegister, setActiveSchool } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { GoogleSignIn } from '@/components/google-signin';
import { AudienceToggle, type Audience } from '@/components/audience-toggle';
import { MailIcon, LockIcon, EyeIcon } from '@/components/icons';

export default function RegisterPage() {
  const router = useRouter();
  const [audience, setAudience] = useState<Audience>('students');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // school-only fields
  const [schoolName, setSchoolName] = useState('');
  const [schoolType, setSchoolType] = useState('secondary');
  const [fullName, setFullName] = useState('');

  const mismatch = confirmPassword.length > 0 && password !== confirmPassword;

  useEffect(() => {
    document.title = 'Create your account · Renance';
  }, []);

  // Stable identity for the GIS callback, never re-initialize mid-signup.
  const onGoogleCredential = useCallback(
    async (credential: string) => {
      setError(null);
      setBusy(true);
      try {
        const res = await authWithGoogle(credential);
        setSession(res.token, res.user);
        router.replace('/dashboard');
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'Google sign-in failed, check the connection.');
        setBusy(false);
      }
    },
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
      const res = await api<{ token: string; user: { id: string; username: string; profileCompleted: boolean } }>(
        '/auth/register',
        { method: 'POST', body: { email, password }, auth: false },
      );
      setSession(res.token, res.user);
      router.replace('/dashboard');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Network error, is the study API running?');
      setBusy(false);
    }
  }

  const field = 'h-12 w-full rounded-lg bg-surface-container pl-11 pr-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary';

  return (
    <main className="flex min-h-dvh w-full flex-col items-center justify-center bg-surface-container px-4 py-10">
      <div className="renance-rise flex w-full max-w-sm flex-col rounded-xl bg-surface-container-lowest p-6 shadow-md">
        {/* Logo block, mockup: logo, headline, sub */}
        <div className="mb-5 flex flex-col items-center gap-3 text-center">
          <RenanceMark size={64} />
          <div>
            <h1 className="text-2xl font-semibold tracking-tight text-on-surface">
              {audience === 'schools' ? 'Register your school' : 'Create your account'}
            </h1>
            <p className="mt-1 text-sm text-on-surface-variant">
              {audience === 'schools'
                ? 'The study OS for your whole school — management, teachers and students.'
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
