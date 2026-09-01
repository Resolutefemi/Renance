'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { getToken, setStoredUser } from '@/lib/session';
import { fetchManifest, prefetchAll, type ExamMeta } from '@/lib/exams';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';

interface Profile {
  fullName: string;
  institution: string;
  gradeLevel: string;
  exams: string[];
  completed: boolean;
}

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: Profile | null;
}

const EXAM_OPTIONS = ['JAMB', 'WAEC', 'NECO', 'University Modules'] as const;
const GRADE_LEVELS = ['SS1', 'SS2', 'SS3', '100 Level', '200 Level', '300 Level', '400 Level', 'Postgraduate'];

export default function DashboardPage() {
  const router = useRouter();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [exams, setExams] = useState<ExamMeta[]>([]);
  const [needsProfile, setNeedsProfile] = useState(false);
  const [syncState, setSyncState] = useState<'idle' | 'syncing' | 'ready'>('idle');
  const [syncLabel, setSyncLabel] = useState('Preparing your study pack…');
  const [error, setError] = useState<string | null>(null);

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
      const [/* serverJob */] = await Promise.all([
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
    // ride along until the server-side worker finishes (drives the strip)
    for (let i = 0; i < 60; i++) {
      const res = await api<{ job: { status: string; progress: number } | null }>('/sync/status');
      if (!res.job || res.job.status === 'done') return;
      await new Promise((r) => setTimeout(r, 700));
    }
  }

  if (!me) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Loading your desk…" />
      </main>
    );
  }

  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
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

      <header className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <RenanceMark size={44} />
          <div>
            <h1 className="text-lg font-semibold tracking-tight text-on-surface">
              {me.profile?.fullName ? `Welcome, ${me.profile.fullName.split(' ')[0]}` : `@${me.user.username}`}
            </h1>
            <p className="text-xs text-on-surface-variant">
              {me.profile?.exams?.length
                ? `studying for ${me.profile.exams.join(' · ')}`
                : 'the global student study OS'}
            </p>
          </div>
        </div>
        <button
          onClick={() => {
            // JWT is stateless — clearing the session ends it client-side.
            localStorage.clear();
            router.replace('/login');
          }}
          className="rounded-lg border border-outline-variant px-3 py-1.5 text-xs text-on-surface-variant transition hover:border-outline hover:text-on-surface"
        >
          Sign out
        </button>
      </header>

      {/* silent asset-sync strip */}
      <section className="mt-6 flex items-center justify-between rounded-xl border border-outline-variant bg-surface-container-lowest px-5 py-4 shadow-sm">
        {syncState === 'syncing' ? (
          <LogoActivityIndicator state="busy" label={syncLabel} />
        ) : (
          <div className="flex items-center gap-3">
            <RenanceMark size={36} />
            <span className="text-sm text-on-surface-variant">{syncLabel}</span>
          </div>
        )}
        {syncState === 'syncing' && (
          <span className="text-xs text-outline">runs in background</span>
        )}
      </section>

      {error && (
        <p className="mt-4 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
          {error}
        </p>
      )}

      <h2 className="mt-10 font-mono text-xs font-medium uppercase tracking-[0.2em] text-on-surface-variant">
        Your study packs
      </h2>
      <section className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
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
      </section>
    </main>
  );
}

function ExamCard({ exam, ready }: { exam: ExamMeta; ready: boolean }) {
  return (
    <Link
      href={`/exams/${exam.code}`}
      className="group flex h-40 flex-col justify-between rounded-xl border border-outline-variant bg-surface-container-lowest p-5 shadow-sm transition hover:shadow-md"
    >
      <div>
        <div className="flex items-start justify-between gap-2">
          <h3 className="font-medium leading-snug text-on-surface">{exam.title}</h3>
          <span className="shrink-0 rounded-md bg-secondary-container px-2 py-0.5 text-[10px] font-medium text-on-secondary-container">
            {exam.questionCount} Q
          </span>
        </div>
        <p className="mt-1 text-xs text-on-surface-variant">
          {exam.durationMinutes ? `${exam.durationMinutes} minutes` : 'untimed'} · {exam.totalMarks} marks
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
/* Contextual profile modal — first thing after auth, non-dismissable */
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
  const [selected, setSelected] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid = useMemo(
    () => fullName.trim().length >= 2 && institution.trim().length >= 2 && selected.length >= 1,
    [fullName, institution, selected],
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
        },
      });
      onDone(res.profile);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save profile');
      setBusy(false);
    }
  }

  function toggleExam(exam: string) {
    setSelected((cur) =>
      cur.includes(exam) ? cur.filter((x) => x !== exam) : [...cur, exam],
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-on-background/60 p-4 backdrop-blur-sm">
      <div className="renance-rise w-full max-w-lg rounded-2xl bg-surface-container-lowest p-8 shadow-xl">
        <div className="mb-6 flex items-center gap-3">
          <RenanceMark size={44} state="busy" />
          <div>
            <h2 className="font-semibold text-on-surface">Set up your desk, @{username}</h2>
            <p className="text-xs text-on-surface-variant">
              We use this to pull the right past questions and syllabus in the background.
            </p>
          </div>
        </div>

        <form onSubmit={onSubmit} className="space-y-5">
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

          <div>
            <span className="mb-2 block text-sm text-on-surface-variant">Active examinations</span>
            <div className="flex flex-wrap gap-2">
              {EXAM_OPTIONS.map((exam) => (
                <button
                  key={exam}
                  type="button"
                  onClick={() => toggleExam(exam)}
                  className={`rounded-full border px-4 py-1.5 text-xs font-medium transition ${
                    selected.includes(exam)
                      ? 'border-primary bg-primary text-on-primary'
                      : 'border-outline-variant text-on-surface-variant hover:border-outline'
                  }`}
                >
                  {exam}
                </button>
              ))}
            </div>
          </div>

          {error && (
            <p className="rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={!valid || busy}
            className="flex w-full items-center justify-center gap-3 rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {busy && <RenanceMark size={22} state="busy" />}
            {busy ? 'Saving…' : 'Done — start syncing'}
          </button>
        </form>
      </div>
    </div>
  );
}
