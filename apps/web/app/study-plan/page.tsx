'use client';

/**
 * Study plan, the Stitch study_plan_light screen.
 * The design stays 1:1; the VALUES go live when the student is signed in,
 * mirroring the app's study_plan_screen.dart derivation (lib/study-plan.ts):
 * the practice block names the weakest syllabus subject (#4), the review
 * block estimates from the SM-2 due count (#3), the voice block from the
 * Leitner cards due today (#7), and the Fatigue Insight card reads
 * /me/fatigue (#6). Signed out, or when a call fails, the exact Stitch
 * copy stands, so the page is never a hole.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';
import { fetchCardProgress } from '@/lib/flashcards';
import type { SyllabusTree } from '@/lib/syllabus';
import type { ReviewSummary } from '@/lib/review';
import {
  cardsDueToday,
  deriveStudyPlanValues,
  type FatigueState,
  type StudyPlanValues,
} from '@/lib/study-plan';

/** The signed-out render: the design mock, exactly as Stitch wrote it. */
const STITCH: StudyPlanValues = deriveStudyPlanValues({ signedIn: false });

const ENERGIES = [
  { label: 'Sharp', icon: 'bolt' },
  { label: 'Normal', icon: 'battery_charging_full' },
  { label: 'Tired', icon: 'battery_1_bar' },
] as const;

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: { completed?: boolean; exams?: string[]; targetYear?: number } | null;
}

/** "University Modules" -> "university-modules", matching cbtdata.Slug. */
function bodySlugOf(me: MeResponse | null): string {
  const exam = me?.profile?.exams?.[0] ?? '';
  if (exam.includes('WAEC')) return 'waec';
  if (exam.includes('University')) return 'university-modules';
  return 'jamb';
}

/** The subject that owns the map's weakest topic, null when unmapped. */
function weakestSubjectOf(tree: SyllabusTree | null): string | null {
  if (!tree || tree.weakest.length === 0) return null;
  const topic = tree.weakest[0].topic;
  for (const s of tree.subjects) {
    for (const sec of s.sections) {
      if (sec.topics.some((t) => t.topic === topic)) return s.subject;
    }
  }
  return null;
}

export default function StudyPlanPage() {
  const router = useRouter();
  const [energy, setEnergy] = useState(0);
  const [plan, setPlan] = useState<StudyPlanValues>(STITCH);

  useEffect(() => {
    if (!getToken()) return; // signed out: the design copy stands
    let alive = true;
    (async () => {
      const me = await api<MeResponse>('/me').catch(() => null);
      if (!alive || !me) return;
      const [review, fatigue, progress, tree] = await Promise.all([
        api<ReviewSummary>('/me/review').catch(() => null),
        api<FatigueState>('/me/fatigue').catch(() => null),
        fetchCardProgress().catch(() => null),
        api<SyllabusTree>(`/syllabus/${bodySlugOf(me)}`).catch(() => null),
      ]);
      if (!alive) return;
      setPlan(
        deriveStudyPlanValues({
          signedIn: true,
          dueTopics: review ? review.stats.due : null,
          cardsDue: cardsDueToday(progress),
          weakestSubject: weakestSubjectOf(tree),
          fatigue,
        }),
      );
    })();
    return () => {
      alive = false;
    };
  }, []);

  const rows = [
    {
      icon: 'science',
      iconBg: 'bg-emerald-tint',
      iconColor: 'text-accent-emerald',
      title: plan.practiceTitle,
      meta: `${plan.practiceMinutes} min`,
      focus: 'High focus',
      href: '/dashboard#packs',
    },
    {
      icon: 'style',
      iconBg: 'bg-surface-container-high',
      iconColor: 'text-accent-ink',
      title: 'Review Cards',
      meta: `${plan.reviewMinutes} min`,
      focus: 'Medium focus',
      href: '/review',
    },
    {
      icon: 'mic',
      iconBg: 'bg-amber-tint',
      iconColor: 'text-accent-amber',
      title: 'Voice Flashcards',
      meta: `${plan.cardsMinutes} min`,
      focus: 'Low focus',
      href: '/flashcards',
    },
  ] as const;

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Study Plan" />
      </div>

      {/* TODAY'S PLAN card */}
      <section className="mt-4 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <div className="flex items-start justify-between">
          <p className="font-mono text-[11px] uppercase tracking-[1.2px] text-accent-amber">
            TODAY&apos;S PLAN
          </p>
          <button
            aria-label="Edit plan"
            className="flex h-11 w-11 items-center justify-center rounded-full bg-surface-container-low text-on-surface"
          >
            <span className="material-symbols-outlined text-[20px]">edit</span>
          </button>
        </div>
        <p className="mt-1 text-2xl font-bold tracking-tight text-on-surface">
          {plan.totalMinutes} min remaining
        </p>

        <div className="mt-4 space-y-2.5">
          {rows.map((row) => (
            <button
              key={row.title}
              onClick={() => router.push(row.href)}
              className="flex w-full items-center gap-3 rounded-2xl bg-surface-container-low px-3 py-3.5 text-left transition active:scale-[0.99]"
            >
              <span className="grid grid-cols-2 gap-1">
                {[0, 1, 2, 3].map((d) => (
                  <span key={d} className="h-[3.5px] w-[3.5px] rounded-full bg-outline-light" />
                ))}
              </span>
              <span className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-full ${row.iconBg}`}>
                <span className={`material-symbols-outlined text-[24px] ${row.iconColor}`}>{row.icon}</span>
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[17px] font-semibold text-on-surface">{row.title}</span>
                <span className="block text-[15px] text-on-surface-variant">{row.meta} • {row.focus}</span>
              </span>
              <span className="material-symbols-outlined text-[26px] text-on-surface">play_arrow</span>
            </button>
          ))}
        </div>
      </section>

      {/* Current Energy Level */}
      <h2 className="mt-7 text-lg font-semibold tracking-tight text-on-surface">Current Energy Level</h2>
      <div className="mt-3.5 grid grid-cols-3 gap-2.5">
        {ENERGIES.map((e, i) => (
          <button
            key={e.label}
            onClick={() => setEnergy(i)}
            className={`flex items-center justify-center gap-1.5 rounded-full py-3 text-[15px] transition ${
              energy === i
                ? 'bg-selection-blue font-semibold text-on-surface'
                : 'bg-surface-container-low text-on-surface-variant'
            }`}
          >
            <span className="material-symbols-outlined text-[18px]">{e.icon}</span>
            {e.label}
          </button>
        ))}
      </div>

      {/* Fatigue Insight */}
      <section className="mt-7 flex items-start gap-4 rounded-2xl bg-[#E4EAFB] p-5">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-card text-on-surface">
          <span className="material-symbols-outlined text-[22px]">lightbulb</span>
        </span>
        <div>
          <p className="text-[15px] font-semibold text-on-surface">Fatigue Insight</p>
          <p className="mt-2 text-[15px] leading-6 text-on-surface-variant">
            {plan.insight}
          </p>
        </div>
      </section>

      <BottomNav />
    </main>
  );
}
