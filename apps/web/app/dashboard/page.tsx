'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { getToken, setStoredUser } from '@/lib/session';
import { fetchManifest, prefetchAll, type ExamMeta } from '@/lib/exams';
import { type ReviewSummary } from '@/lib/review';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';
import BottomNav from '@/components/bottom-nav';

interface Profile {
  fullName: string;
  institution: string;
  gradeLevel: string;
  exams: string[];
  targetYear?: number;
  completed: boolean;
}

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: Profile | null;
}

interface GamificationResponse {
  state: { currentStreak: number; bestStreak: number; totalXp: number };
}

interface AttemptRow {
  attemptId: string;
  code: string;
  status: string;
  score?: number;
  total?: number;
  submittedAt?: string;
}

const EXAM_OPTIONS = ['JAMB', 'WAEC', 'NECO', 'University Modules'] as const;
const GRADE_LEVELS = ['SS1', 'SS2', 'SS3', '100 Level', '200 Level', '300 Level', '400 Level', 'Postgraduate'];
const TARGET_YEARS = [2026, 2027, 2028] as const;

const TARGET_LABELS: Record<string, string> = {
  JAMB: 'UTME',
  WAEC: 'WASSCE',
  NECO: 'NECO',
  'University Modules': 'Semester',
};

function daysToTarget(year?: number): number | null {
  if (!year) return null;
  return Math.max(0, Math.floor((new Date(year, 4, 1).getTime() - Date.now()) / 86_400_000));
}

export default function DashboardPage() {
  const router = useRouter();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [exams, setExams] = useState<ExamMeta[]>([]);
  const [streak, setStreak] = useState(0);
  const [attempts, setAttempts] = useState<AttemptRow[]>([]);
  const [reviewDueCount, setReviewDueCount] = useState(0);
  const [needsProfile, setNeedsProfile] = useState(false);
  const [syncState, setSyncState] = useState<'idle' | 'syncing' | 'ready'>('idle');
  const [syncLabel, setSyncLabel] = useState('Preparing your study pack…');
  const [error, setError] = useState<string | null>(null);
  const [moreOpen, setMoreOpen] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    let alive = true;
    (async () => {
      try {
        const meRes = await api<MeResponse>('/me');
        if (!alive) return;
        setMe(meRes);
        api<GamificationResponse>('/me/gamification')
          .then((g) => alive && setStreak(g.state.currentStreak))
          .catch(() => {});
        api<ReviewSummary>('/me/review')
          .then((r) => alive && setReviewDueCount(r.stats.due))
          .catch(() => {});
        api<{ attempts: AttemptRow[] }>('/me/attempts')
          .then((a) => alive && setAttempts(a.attempts))
          .catch(() => {});
        if (!meRes.profile?.completed) {
          setNeedsProfile(true);
          return;
        }
        await startSyncFlow();
      } catch {
        /* api() already redirects on 401 */
      }
    })();
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router]);

  /** Silent background asset sync: server job + client prefetch, in parallel. */
  async function startSyncFlow() {
    setSyncState('syncing');
    setSyncLabel('Syncing past questions, notes and syllabi…');
    try {
      const manifest = await fetchManifest();
      setExams(manifest.exams);
      await Promise.all([
        pollSyncJob(),
        prefetchAll(manifest, (done, total) =>
          setSyncLabel(`Downloading study packs… ${done}/${total}`),
        ),
      ]);
      setSyncState('ready');
      setSyncLabel(`${manifest.exams.length} packs ready on this device`);
    } catch (err) {
      setSyncState('idle');
      setError(err instanceof Error ? err.message : 'Sync failed');
    }
  }

  async function pollSyncJob() {
    for (let i = 0; i < 60; i++) {
      const res = await api<{ job: { status: string; progress: number } | null }>('/sync/status');
      if (!res.job || res.job.status === 'done') return;
      await new Promise((r) => setTimeout(r, 700));
    }
  }

  const targetTitle = useMemo(() => {
    const p = me?.profile;
    if (!p?.exams?.length) return 'Set your target';
    const label = TARGET_LABELS[p.exams[0]] ?? p.exams[0];
    return p.targetYear ? `${label} ${p.targetYear}` : label;
  }, [me]);

  const days = daysToTarget(me?.profile?.targetYear);

  const coveragePct = useMemo(() => {
    const gradedCodes = new Set(
      attempts.filter((a) => a.status === 'graded' && a.score != null).map((a) => a.code),
    );
    const pool = attempts.length ? gradedCodes.size : exams.length || gradedCodes.size;
    if (!pool) return 0;
    return Math.min(100, Math.round((gradedCodes.size * 100) / pool));
  }, [attempts, exams]);

  const recent = attempts[0] ?? null;

  if (!me) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Loading your desk…" />
      </main>
    );
  }

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      {needsProfile && (
        <ProfileModal
          username={me.user.username}
          onDone={(profile) => {
            setMe({ ...me, profile });
            setStoredUser({ ...me.user, profileCompleted: true });
            setNeedsProfile(false);
            void startSyncFlow();
          }}
        />
      )}

      {/* Brand header: fixed, blurred, hairline shadow (home_dashboard).
          Founder rule: the logo and the avatar are both clickable. */}
      <header className="fixed top-0 z-50 w-full border-b border-outline-variant/40 bg-surface/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 w-full max-w-5xl items-center justify-between px-4 sm:px-6">
          <Link
            href="/dashboard"
            aria-label="Renance home"
            className="flex items-center gap-2 transition-opacity hover:opacity-80"
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary font-bold text-on-primary">
              R
            </div>
            <span className="text-2xl font-bold tracking-tight text-on-surface">Renance</span>
          </Link>
          <div className="flex items-center gap-4">
            <Link
              href="/search"
              aria-label="Search"
              className="flex h-8 w-8 items-center justify-center rounded-full border border-outline-light bg-surface-container text-on-surface transition hover:bg-surface-container-high"
            >
              <span className="material-symbols-outlined text-[18px]">search</span>
            </Link>
            <div className="flex items-center gap-1 rounded-full bg-surface-container px-2 py-1">
              <span className="material-symbols-outlined fill-current text-[20px] text-accent-amber">local_fire_department</span>
              <span className="font-mono text-[13px] text-on-surface">{streak}</span>
            </div>
            <Link
              href="/profile"
              aria-label="Your profile"
              title="Your profile"
              className="flex h-8 w-8 items-center justify-center rounded-full border border-outline-light bg-surface-container-high text-xs font-semibold text-on-surface transition hover:ring-2 hover:ring-primary"
            >
              {(me.profile?.fullName || me.user.username || 'R').slice(0, 1).toUpperCase()}
            </Link>
          </div>
        </div>
      </header>

      <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 px-4 pt-20 sm:px-6">
        {/* Hero progress card ------------------------------------------- */}
        <section className="relative mt-4 flex flex-col gap-4 overflow-hidden rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-6">
          <div className="absolute -right-16 -top-16 h-40 w-40 rounded-full bg-primary/5" />
          <div className="absolute -bottom-14 -left-12 h-28 w-28 rounded-full bg-accent-violet/5" />
          <div className="relative z-10 flex items-start justify-between gap-4">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">Next Target</p>
              <h2 className="text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">{targetTitle}</h2>
            </div>
            <div className="text-right">
              <p className="font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">Countdown</p>
              <p className="text-sm font-semibold text-accent-violet">
                {days == null ? 'Set a year' : days <= 0 ? 'This month' : `${days} Days`}
              </p>
            </div>
          </div>
          <div className="relative z-10 flex flex-col gap-2">
            <div className="flex justify-between font-mono text-xs text-on-surface-variant">
              <span>Syllabus Completion</span>
              <span className="font-semibold text-on-surface">{coveragePct}%</span>
            </div>
            <div className="h-2 w-full overflow-hidden rounded-full bg-surface-variant">
              <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${coveragePct}%` }} />
            </div>
          </div>
          <Link
            href={exams[0] ? `/exams/${exams[0].code}` : '#packs'}
            className="relative z-10 flex h-[52px] items-center justify-center gap-2 rounded-lg bg-primary text-[15px] font-semibold text-on-primary transition-transform active:scale-[0.98]"
          >
            <span className="material-symbols-outlined text-[20px]">play_arrow</span>
            Continue Practice
          </Link>
        </section>

        {syncState !== 'ready' && (
          <section className="flex items-center justify-between rounded-xl border border-outline-variant/60 bg-surface-container-lowest px-5 py-4 shadow-sm">
            <LogoActivityIndicator state="busy" label={syncLabel} />
            <span className="text-xs text-outline">runs in background</span>
          </section>
        )}

        {error && (
          <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">{error}</p>
        )}

        {/* Mock exam simulator banner (exam_mode_setup_light entry) ------ */}
        <Link
          href="/exams/setup"
          className="flex items-center gap-3 rounded-xl bg-dark-surface p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
        >
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-accent-violet/15">
            <span className="material-symbols-outlined text-[22px] text-accent-violet">timer</span>
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-[15px] font-semibold text-dark-text-primary">Mock Exam Setup</p>
            <p className="truncate text-[13px] text-dark-text-secondary">
              Official JAMB conditions, 2 hours, 4 subjects
            </p>
          </div>
          <span className="material-symbols-outlined text-[20px] text-dark-text-secondary">arrow_forward</span>
        </Link>

        {/* Launcher grids: one Stitch pair on phones, side by side on PC --- */}
        <div className="lg:grid lg:grid-cols-2 lg:items-start lg:gap-x-8">
          <section className="mt-2">
            <h3 className="text-sm text-on-surface-variant">Practice</h3>
            <div className="mt-3 grid grid-cols-4 gap-3 sm:max-w-md lg:max-w-none">
              <LauncherTile icon="description" label="Exams" href="#packs" />
              <LauncherTile icon="history" label="Review Due" badge={reviewDueCount > 0 ? reviewDueCount : undefined} href="/review" />
              <LauncherTile icon="style" label="Flashcards" href="/flashcards" />
              <LauncherTile icon="menu_book" label="Syllabus" href="/syllabus" />
            </div>
          </section>

          <section className="mt-4 lg:mt-2">
            <h3 className="text-sm text-on-surface-variant">Grow</h3>
            <div className="mt-3 grid grid-cols-4 gap-3 sm:max-w-md lg:max-w-none">
              <LauncherTile icon="trending_up" label="Progress" href="/progress" />
              <LauncherTile icon="military_tech" label="Badges" amber href="/progress" />
              <LauncherTile icon="smart_toy" label="Tutor" violet soon />
              <LauncherTile icon="more_horiz" label="More" muted onMore={() => setMoreOpen(true)} />
            </div>
          </section>
        </div>

        {/* Recent activity ------------------------------------------------ */}
        {recent && (
          <Link
            href="/progress"
            className="mt-6 mb-4 flex items-center gap-3 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition-colors hover:bg-surface-container-lowest"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-error-container">
              <span className="material-symbols-outlined text-[20px] text-error">science</span>
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[15px] font-semibold text-on-surface">{recent.code}</p>
              <p className="truncate text-[13px] text-on-surface-variant">
                {recent.score != null && recent.total
                  ? `Score: ${Math.round((recent.score * 100) / recent.total)}% · ${
                      recent.score * 100 >= 7500 ? 'Strong work' : recent.score * 100 >= 5000 ? 'Keep pushing' : 'Focus needed'
                    }`
                  : recent.status}
              </p>
            </div>
            <span className="material-symbols-outlined text-outline">chevron_right</span>
          </Link>
        )}

        {/* Pack library ---------------------------------------------------- */}
        <section id="packs" className="scroll-mt-24">
          <h2 className="mt-4 font-mono text-xs font-medium uppercase tracking-[0.2em] text-on-surface-variant">
            Your study packs
          </h2>
          <div className="mt-4 grid grid-cols-1 gap-4 pb-8 sm:grid-cols-2 lg:grid-cols-3">
            {(exams.length ? exams : Array.from({ length: 3 }, () => null)).map((exam, i) =>
              exam ? (
                <ExamCard key={exam.code} exam={exam} ready={syncState !== 'syncing'} />
              ) : (
                <div
                  key={i}
                  className="h-40 animate-pulse rounded-xl border border-outline-variant/60 bg-surface-container-low"
                />
              ),
            )}
          </div>
        </section>
      </div>

      {/* More sheet: the launcher's jump table (more_features_sheet_light) */}
      {moreOpen && <MoreSheet onClose={() => setMoreOpen(false)} />}

      <BottomNav />
    </main>
  );
}

/** Small bottom sheet listing the destinations that live beyond the grid. */
function MoreSheet({ onClose }: { onClose: () => void }) {
  const items = [
    { icon: 'history_edu', label: 'Review center', href: '/review' },
    { icon: 'auto_stories', label: 'Lessons', href: '/lessons' },
    { icon: 'person', label: 'Profile', href: '/profile' },
    { icon: 'workspace_premium', label: 'Certificates', href: '/certificates' },
    { icon: 'menu_book', label: 'Subjects', href: '/subjects' },
    { icon: 'help', label: 'Help & FAQ', href: '/faq' },
  ] as const;
  return (
    <div
      className="fixed inset-0 z-[60] flex items-end justify-center bg-on-background/60 backdrop-blur-sm sm:items-center"
      onClick={onClose}
      role="presentation"
    >
      <div
        className="renance-rise w-full max-w-md rounded-t-2xl bg-surface-container-lowest p-5 shadow-xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-label="More features"
      >
        <div className="mx-auto mb-4 h-1.5 w-12 rounded-full bg-outline-variant sm:hidden" />
        <h3 className="mb-3 text-lg font-semibold text-on-surface">More</h3>
        <div className="grid grid-cols-2 gap-2">
          {items.map((it) => (
            <Link
              key={it.label}
              href={it.href}
              onClick={onClose}
              className="flex items-center gap-3 rounded-xl border border-outline-variant/50 bg-card p-3 transition hover:border-outline hover:bg-surface-container-low"
            >
              <span className="material-symbols-outlined text-[22px] text-on-surface">{it.icon}</span>
              <span className="text-sm font-medium text-on-surface">{it.label}</span>
            </Link>
          ))}
        </div>
        <button
          type="button"
          onClick={onClose}
          className="mt-4 h-12 w-full rounded-lg bg-primary text-sm font-semibold text-on-primary transition-transform active:scale-[0.98]"
        >
          Close
        </button>
      </div>
    </div>
  );
}

function LauncherTile({
  icon,
  label,
  href,
  badge,
  amber,
  violet,
  muted,
  soon,
  onMore,
}: {
  icon: string;
  label: string;
  href?: string;
  badge?: number;
  amber?: boolean;
  violet?: boolean;
  muted?: boolean;
  soon?: boolean;
  onMore?: () => void;
}) {
  const inner = (
    <>
      <div
        className={`relative flex h-14 w-14 items-center justify-center rounded-[18px] transition-transform group-active:scale-95 ${
          violet
            ? 'bg-accent-violet text-white shadow-[0_2px_8px_0_rgba(139,92,246,0.25)]'
            : muted
              ? 'border border-outline-light/30 bg-surface-container text-on-surface-variant'
              : 'bg-card text-on-surface shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]'
        } ${violet ? 'overflow-hidden' : ''}`}
      >
        {violet && <div className="absolute inset-0 bg-gradient-to-tr from-transparent to-white/20" />}
        <span className={`material-symbols-outlined relative z-10 ${amber ? 'text-accent-amber' : ''}`}>{icon}</span>
        {badge != null && (
          <span className="absolute -right-1.5 -top-1.5 rounded-full bg-accent-emerald px-1.5 py-0.5 font-mono text-[10px] font-bold text-white shadow-sm">
            {badge}
          </span>
        )}
      </div>
      <span
        className={`w-full truncate text-center text-[11px] ${
          violet ? 'font-semibold text-accent-violet' : 'text-on-surface-variant'
        }`}
      >
        {label}
      </span>
    </>
  );

  if (soon || onMore) {
    return (
      <button
        type="button"
        title={onMore ? `${label} features` : `${label}: ships in an upcoming release`}
        onClick={onMore}
        className="group flex flex-col items-center gap-2 opacity-70"
      >
        {inner}
      </button>
    );
  }
  return (
    <Link href={href ?? '#'} className="group flex flex-col items-center gap-2">
      {inner}
    </Link>
  );
}

function ExamCard({ exam, ready }: { exam: ExamMeta; ready: boolean }) {
  return (
    <Link
      href={`/exams/practice?pack=${encodeURIComponent(exam.code)}`}
      className="group flex h-40 flex-col justify-between rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition hover:shadow-md"
    >
      <div>
        <div className="flex items-start justify-between gap-2">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-surface-container-highest text-primary">
            <span className="material-symbols-outlined fill-current text-[22px]">description</span>
          </div>
          <span className="shrink-0 rounded-md bg-surface-container px-2 py-0.5 font-mono text-[10px] text-on-surface">
            {exam.questionCount} Q
          </span>
        </div>
        <h3 className="mt-2 text-[15px] font-semibold leading-snug text-on-surface">{exam.title}</h3>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          {exam.durationMinutes ? `${exam.durationMinutes} min` : 'untimed'} · {exam.totalMarks} marks
        </p>
      </div>
      <div className="flex items-center justify-between">
        <span className="text-xs text-outline transition group-hover:text-on-surface-variant">
          {ready ? 'Ready offline' : 'syncing…'}
        </span>
        <span className="text-sm font-semibold text-primary transition-transform group-hover:translate-x-0.5">
          Start →
        </span>
      </div>
    </Link>
  );
}

/* ----------------------------------------------------------------- */
/* Contextual profile modal: first thing after auth, non-dismissable */
/* ----------------------------------------------------------------- */

function ProfileModal({
  username,
  onDone,
}: {
  username: string;
  onDone: (profile: Profile) => void;
}) {
  const [fullName, setFullName] = useState('');
  const [institution, setInstitution] = useState('');
  const [gradeLevel, setGradeLevel] = useState('SS3');
  const [targetYear, setTargetYear] = useState<number | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid = useMemo(
    () =>
      fullName.trim().length >= 2 &&
      institution.trim().length >= 2 &&
      selected.length >= 1 &&
      targetYear != null,
    [fullName, institution, selected, targetYear],
  );

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!valid) return;
    setBusy(true);
    setError(null);
    try {
      const res = await api<{ profile: Profile }>('/me/profile', {
        method: 'PUT',
        body: {
          fullName: fullName.trim(),
          institution: institution.trim(),
          gradeLevel,
          exams: selected,
          targetYear,
        },
      });
      onDone(res.profile);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save profile');
      setBusy(false);
    }
  }

  function toggleExam(exam: string) {
    setSelected(() => [exam]);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-on-background/60 p-4 backdrop-blur-sm">
      <div className="renance-rise max-h-[92dvh] w-full max-w-lg overflow-y-auto rounded-2xl bg-surface-container-lowest p-8 shadow-xl">
        <div className="mb-6 flex items-center gap-3">
          <RenanceMark size={44} state="busy" />
          <div>
            <h2 className="font-semibold text-on-surface">What are you preparing for?</h2>
            <p className="text-xs text-on-surface-variant">
              Select your target exam to customize your learning OS, @{username}.
            </p>
          </div>
        </div>

        <form onSubmit={onSubmit} className="space-y-5">
          <div>
            <span className="mb-2 block text-sm text-on-surface-variant">Target exam</span>
            <div className="grid gap-2">
              {EXAM_OPTIONS.map((exam) => {
                const active = selected.includes(exam);
                return (
                  <button
                    key={exam}
                    type="button"
                    onClick={() => toggleExam(exam)}
                    className={`flex items-center gap-3 rounded-xl border p-3 text-left transition ${
                      active
                        ? 'border-primary bg-selection-blue ring-1 ring-primary'
                        : 'border-outline-variant bg-card hover:border-outline'
                    }`}
                  >
                    <div
                      className={`flex h-9 w-9 items-center justify-center rounded-lg ${
                        active ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[20px]">school</span>
                    </div>
                    <span className="flex-1 text-sm font-semibold text-on-surface">{exam}</span>
                    {active && <span className="material-symbols-outlined text-primary">check_circle</span>}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <span className="mb-2 block text-sm text-on-surface-variant">Exam year</span>
            <div className="flex gap-2">
              {TARGET_YEARS.map((y) => (
                <button
                  key={y}
                  type="button"
                  onClick={() => setTargetYear(y)}
                  className={`rounded-full px-4 py-1.5 font-mono text-sm transition ${
                    targetYear === y
                      ? 'border border-primary bg-selection-blue text-on-surface'
                      : 'bg-surface-container-low text-on-surface-variant'
                  }`}
                >
                  {y}
                </button>
              ))}
            </div>
          </div>

          <label className="block">
            <span className="mb-1.5 block text-sm text-on-surface-variant">Full name</span>
            <input
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="e.g. Ariyo Oluwafemi"
              required
              className="w-full rounded-lg bg-surface-container px-4 py-2.5 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </label>

          <label className="block">
            <span className="mb-1.5 block text-sm text-on-surface-variant">Target institution</span>
            <input
              value={institution}
              onChange={(e) => setInstitution(e.target.value)}
              placeholder="e.g. Federal University of Technology, Akure"
              required
              list="institutions"
              className="w-full rounded-lg bg-surface-container px-4 py-2.5 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
            />
            <datalist id="institutions">
              <option value="University of Ibadan" />
              <option value="University of Lagos" />
              <option value="Obafemi Awolowo University" />
              <option value="Federal University of Technology, Akure" />
              <option value="University of Ilorin" />
              <option value="Ahmadu Bello University" />
            </datalist>
          </label>

          <label className="block">
            <span className="mb-1.5 block text-sm text-on-surface-variant">Current level</span>
            <select
              value={gradeLevel}
              onChange={(e) => setGradeLevel(e.target.value)}
              className="w-full rounded-lg bg-surface-container px-4 py-2.5 text-sm text-on-surface focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
            >
              {GRADE_LEVELS.map((g) => (
                <option key={g}>{g}</option>
              ))}
            </select>
          </label>

          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">{error}</p>
          )}

          <button
            type="submit"
            disabled={!valid || busy}
            className="flex w-full items-center justify-center gap-3 rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {busy && <RenanceMark size={22} state="busy" />}
            {busy ? 'Saving…' : 'Done, start syncing'}
          </button>
        </form>
      </div>
    </div>
  );
}
