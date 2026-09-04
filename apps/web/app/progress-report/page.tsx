'use client';

/**
 * Progress report, the Stitch progress_dashboard_light screen, 1:1.
 *
 * The three stat tiles (questions, accuracy, time spent), the 7-day
 * Accuracy Trend bars drawn from real graded attempts, the Subject
 * Mastery rails per pack and the Focus Areas list that hands the worst
 * packs straight back to practice, plus the streak chip. The Gamification
 * hub lives on /progress; this screen is its analytical twin.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';
import { LogoActivityIndicator } from '@/components/renance-logo';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

interface AttemptRow {
  attemptId: string;
  code: string;
  status: string;
  score?: number;
  total?: number;
  durationMs?: number;
  submittedAt?: string;
}

export default function ProgressReportPage() {
  const router = useRouter();
  const [attempts, setAttempts] = useState<AttemptRow[] | null>(null);
  const [failed, setFailed] = useState(false);

  const load = useCallback(async () => {
    try {
      const a = await api<{ attempts: AttemptRow[] }>('/me/attempts');
      setAttempts(a.attempts);
    } catch {
      setFailed(true);
    }
  }, []);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    void load();
  }, [router, load]);

  const graded = (attempts ?? []).filter(
    (a) => a.status === 'graded' && a.score != null && a.total != null && a.total! > 0,
  );
  const questions = graded.reduce((s, a) => s + (a.total ?? 0), 0);
  const correct = graded.reduce((s, a) => s + (a.score ?? 0), 0);
  const accuracy = questions === 0 ? 0 : Math.round((correct * 100) / questions);
  const minutes = Math.round(
    graded.reduce((s, a) => s + (a.durationMs ?? 0), 0) / 60000,
  );
  const timeLabel = minutes >= 60 ? `${Math.floor(minutes / 60)}h` : `${minutes}m`;

  // 7-day trend: mean accuracy per day.
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date();
    d.setUTCDate(d.getUTCDate() - (6 - i));
    const dayRows = graded.filter((a) => {
      if (!a.submittedAt) return false;
      const s = new Date(a.submittedAt);
      return (
        s.getUTCFullYear() === d.getUTCFullYear() &&
        s.getUTCMonth() === d.getUTCMonth() &&
        s.getUTCDate() === d.getUTCDate()
      );
    });
    const mean = dayRows.length
      ? Math.round(dayRows.reduce((s, a) => s + (100 * (a.score ?? 0)) / (a.total ?? 1), 0) / dayRows.length)
      : null;
    return { mean };
  });

  // Mastery: mean accuracy per pack.
  const byCode = new Map<string, number[]>();
  for (const a of graded) {
    const arr = byCode.get(a.code) ?? [];
    arr.push(Math.round((100 * (a.score ?? 0)) / (a.total ?? 1)));
    byCode.set(a.code, arr);
  }
  const mastery = [...byCode.entries()]
    .map(([code, pcts]) => ({
      code,
      pct: Math.round(pcts.reduce((s, p) => s + p, 0) / pcts.length),
    }))
    .sort((a, b) => b.pct - a.pct);
  const focus = [...mastery].sort((a, b) => a.pct - b.pct).slice(0, 3);

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Progress report" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Progress report
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          What the numbers say about your preparation.
        </p>

        {failed && (
          <p className="mt-6 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
            Could not reach Renance servers. Check your connection and try again.
          </p>
        )}

        {!attempts && !failed && (
          <div className="flex justify-center py-16">
            <LogoActivityIndicator state="busy" label="Crunching your history…" />
          </div>
        )}

        {attempts && (
          <>
            {/* Stat tiles ------------------------------------------------ */}
            <div className="mt-6 grid grid-cols-3 gap-3">
              <div className="rounded-[12px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
                <p className="text-[22px] font-bold leading-7 tracking-[-0.02em] text-on-surface">
                  {questions}
                </p>
                <p className="text-[13px] text-on-surface-variant">Questions</p>
              </div>
              <div className="rounded-[12px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
                <p className="text-[22px] font-bold leading-7 tracking-[-0.02em] text-on-surface">
                  {accuracy}%
                </p>
                <p className="text-[13px] text-on-surface-variant">Accuracy</p>
              </div>
              <div className="rounded-[12px] bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
                <span className="material-symbols-outlined text-[18px] text-on-surface-variant">
                  timer
                </span>
                <p className="text-[22px] font-bold leading-7 tracking-[-0.02em] text-on-surface">
                  {timeLabel}
                </p>
                <p className="text-[13px] text-on-surface-variant">Time Spent</p>
              </div>
            </div>

            {/* Accuracy trend ---------------------------------------------- */}
            <section className="mt-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
                Accuracy Trend
              </h2>
              <p className="text-[13px] text-on-surface-variant">Last 7 Days</p>
              <div className="mt-5 flex h-28 items-end gap-2">
                {days.map((d, i) => (
                  <div key={i} className="flex flex-1 flex-col items-center justify-end gap-1">
                    {d.mean != null && (
                      <span className="font-mono text-[9px] text-on-surface-variant">
                        {d.mean}%
                      </span>
                    )}
                    <div
                      className={`w-full rounded-md ${
                        d.mean != null ? 'bg-on-surface' : 'bg-surface-variant'
                      }`}
                      style={{
                        height: d.mean != null ? `${Math.max(15, (d.mean / 100) * 60)}px` : '4px',
                      }}
                    />
                    <span className="font-mono text-[9px] text-on-surface-variant">
                      D-{6 - i}
                    </span>
                  </div>
                ))}
              </div>
            </section>

            {/* Subject mastery --------------------------------------------- */}
            <section className="mt-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
                Subject Mastery
              </h2>
              <div className="mt-4 flex flex-col gap-4">
                {mastery.length === 0 && (
                  <p className="text-[15px] text-on-surface-variant">
                    Run a graded paper and mastery fills in here.
                  </p>
                )}
                {mastery.slice(0, 4).map((m) => (
                  <div key={m.code}>
                    <div className="flex items-center justify-between">
                      <span className="text-[14px] font-semibold text-on-surface">{m.code}</span>
                      <span className="font-mono text-[12px] text-on-surface">{m.pct}%</span>
                    </div>
                    <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-surface-variant">
                      <div
                        className={`h-full rounded-full ${
                          m.pct >= 70
                            ? 'bg-accent-emerald'
                            : m.pct >= 50
                              ? 'bg-accent-amber'
                              : 'bg-on-surface'
                        }`}
                        style={{ width: `${m.pct}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </section>

            {/* Focus areas -------------------------------------------------- */}
            <section className="mt-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px] text-accent-amber">
                  warning
                </span>
                <h2 className="text-[18px] font-semibold tracking-[-0.01em] text-on-surface">
                  Focus Areas
                </h2>
              </div>
              <div className="mt-3 flex flex-col gap-2">
                {focus.length === 0 && (
                  <p className="text-[15px] text-on-surface-variant">
                    No weak spots detected yet. Keep practicing!
                  </p>
                )}
                {focus.map((f) => (
                  <div key={f.code} className="flex items-center gap-3">
                    <span className="flex-1 truncate text-[14px] font-semibold text-on-surface">
                      {f.code}
                    </span>
                    <Link
                      href={`/exams/practice?pack=${encodeURIComponent(f.code)}`}
                      className="rounded-full bg-surface-container-low px-4 py-1.5 font-mono text-[11px] font-medium text-on-surface transition hover:bg-surface-variant"
                    >
                      Practice
                    </Link>
                  </div>
                ))}
              </div>
            </section>
          </>
        )}
      </div>

      <BottomNav />
    </main>
  );
}
