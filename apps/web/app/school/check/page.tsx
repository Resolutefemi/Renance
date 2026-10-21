'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { checkResultByPin, termLabel, type ResultSheet } from '@/lib/school';
import { downloadReportCardPDF } from '@/lib/report-pdf';
import { RenanceMark } from '@/components/renance-logo';
import { ResultSheetView } from '@/components/result-sheet-view';

// PUBLIC result checker (ggportal pattern): the 6-digit PIN issued at
// finalize is the student's credential. No sign-in required. Wears the
// GGSA landing look (founder directive 2026-10-04): purple-900 →
// purple-800 → amber-800 hero gradient, gold accents, PIN input set in
// wide-tracked numerals.

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
    <main className="school-ggsa flex min-h-dvh flex-col items-center bg-surface-container px-4 py-12">
      <div className="w-full max-w-lg">
        {/* GGSA landing hero band */}
        <section className="relative mb-8 overflow-hidden rounded-2xl bg-gradient-to-br from-purple-900 via-purple-800 to-amber-800 p-6 text-center text-white shadow-2xl sm:rounded-3xl sm:p-8">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_30%,white_2px,transparent_2px)] [background-size:24px_24px] opacity-20" />
          <div className="relative flex flex-col items-center">
            <span className="mb-3 rounded-full bg-amber-400 px-3 py-1 text-xs font-bold uppercase tracking-wider text-purple-900">
              Result Portal
            </span>
            <RenanceMark size={44} inverse />
            <h1 className="mt-3 text-2xl font-extrabold tracking-tight">Check your result</h1>
            <p className="mt-1 text-sm text-purple-100">
              Enter the result-check PIN from your school, the term and the session.
            </p>
          </div>
        </section>

        <form onSubmit={onSubmit} className="grid gap-3 rounded-xl border border-purple-200 bg-surface-container-lowest p-6 shadow-xl">
          <input
            className="h-12 rounded-lg border border-outline-variant bg-surface-container-low px-4 text-center font-mono text-2xl font-bold tracking-[0.4em] text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            placeholder="••••••"
            maxLength={6}
            minLength={6}
            value={pin}
            onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
            required
            inputMode="numeric"
            aria-label="6-digit result PIN"
          />
          <p className="text-center text-[11px] text-on-surface-variant">
            Each result has its own unique PIN. Different terms have different PINs.
          </p>
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
            className="flex h-12 items-center justify-center rounded-lg bg-ggsa-purple text-sm font-medium text-white transition-all hover:bg-brand-800 active:scale-[0.98] disabled:opacity-60"
          >
            {busy ? 'Checking…' : 'View Result'}
          </button>
        </form>
      </div>

      {sheet && (
        <div className="mt-6 w-full max-w-4xl rounded-xl border border-purple-200 bg-surface-container-lowest p-4 shadow-xl sm:p-6">
          <div className="mb-4 flex items-center gap-3">
            {sheet.schoolLogoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={sheet.schoolLogoUrl}
                alt=""
                className="h-12 w-12 rounded-lg border border-brand-200 object-cover"
              />
            )}
            <div>
              <h2 className="text-lg font-semibold leading-tight text-ggsa-purple">
                {sheet.studentName} - {sheet.className}
              </h2>
              {sheet.schoolName && (
                <p className="text-xs text-on-surface-variant">{sheet.schoolName}</p>
              )}
            </div>
          </div>
          <ResultSheetView sheet={sheet} />
          <button
            onClick={() => downloadReportCardPDF(sheet).catch(() => undefined)}
            className="school-no-print mt-4 flex h-10 w-full items-center justify-center gap-2 rounded-lg border border-ggsa-purple text-sm font-medium text-ggsa-purple transition-colors hover:bg-brand-50"
          >
            <span className="material-symbols-outlined text-[18px]">picture_as_pdf</span>
            Download report card (PDF)
          </button>
        </div>
      )}

      <p className="mt-10 text-center text-sm text-on-surface-variant">
        <Link href="/" className="font-medium text-ggsa-purple underline-offset-4 hover:underline">
          Back to Renance
        </Link>
      </p>
    </main>
  );
}
