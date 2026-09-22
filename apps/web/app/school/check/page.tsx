'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { checkResultByPin, termLabel, type ResultSheet } from '@/lib/school';
import { RenanceMark } from '@/components/renance-logo';
import { ResultSheetView } from '@/components/result-sheet-view';

// PUBLIC result checker (ggportal pattern): the 6-digit PIN issued at
// finalize is the student's credential. No sign-in required.

export default function SchoolCheckPage() {
  const [pin, setPin] = useState('');
  const [term, setTerm] = useState(1);
  const [session, setSession] = useState('2025/2026');
  const [sheet, setSheet] = useState<ResultSheet | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setSheet(null);
    setBusy(true);
    try {
      const res = await checkResultByPin(pin.trim(), term, session.trim());
      setSheet(res.result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not check the result.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-dvh flex-col items-center bg-surface-container px-4 py-12">
      <div className="w-full max-w-lg">
        <div className="mb-8 flex flex-col items-center text-center">
          <RenanceMark size={48} />
          <h1 className="mt-4 text-2xl font-semibold tracking-tight text-on-surface">Check a result</h1>
          <p className="mt-1 text-sm text-on-surface-variant">
            Enter the result-check PIN from your school, the term and the session.
          </p>
        </div>

        <form onSubmit={onSubmit} className="grid gap-3 rounded-xl bg-surface-container-lowest p-6 shadow-sm">
          <input
            className="h-12 rounded-lg border border-outline-variant bg-surface-container-low px-4 text-center font-mono text-lg tracking-[0.4em] text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            placeholder="••••••"
            maxLength={6}
            minLength={6}
            value={pin}
            onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
            required
            inputMode="numeric"
            aria-label="6-digit result PIN"
          />
          <div className="grid grid-cols-2 gap-3">
            <select
              className="h-12 rounded-lg border border-outline-variant bg-surface-container-low px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              value={term}
              onChange={(e) => setTerm(parseInt(e.target.value, 10))}
              aria-label="Term"
            >
              {[1, 2, 3].map((t) => (
                <option key={t} value={t}>
                  {termLabel(t)}
                </option>
              ))}
            </select>
            <input
              className="h-12 rounded-lg border border-outline-variant bg-surface-container-low px-3 text-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              value={session}
              onChange={(e) => setSession(e.target.value)}
              placeholder="Session (2025/2026)"
              aria-label="Session"
              required
            />
          </div>
          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">{error}</p>
          )}
          <button
            type="submit"
            disabled={busy}
            className="flex h-12 items-center justify-center rounded-lg bg-primary text-sm font-medium text-on-primary transition-all hover:opacity-90 active:scale-[0.98] disabled:opacity-60"
          >
            {busy ? 'Checking…' : 'Check result'}
          </button>
        </form>

        {sheet && (
          <div className="mt-6 rounded-xl bg-surface-container-lowest p-6 shadow-sm">
            <h2 className="mb-4 text-lg font-semibold text-on-surface">
              {sheet.studentName} — {sheet.className}
            </h2>
            <ResultSheetView sheet={sheet} />
          </div>
        )}

        <p className="mt-10 text-center text-sm text-on-surface-variant">
          <Link href="/" className="font-medium text-primary underline-offset-4 hover:underline">
            Back to Renance
          </Link>
        </p>
      </div>
    </main>
  );
}
