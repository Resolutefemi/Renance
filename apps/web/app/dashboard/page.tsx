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
      <main className="flex min-h-screen items-center justify-center">
        <LogoActivityIndicator state="busy" label="Loading your desk…" />
      </main>
    );
  }

  return (
    <main className="mx-auto w-full max-w-5xl px-6 py-10">
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
          <RenanceMark size={40} />
          <div>
            <h1 className="text-lg font-semibold tracking-tight">
              {me.profile?.fullName ? `Welcome, ${me.profile.fullName.split(' ')[0]}` : `@${me.user.username}`}
            </h1>
            <p className="text-xs text-neutral-500">
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
          className="rounded-lg border border-neutral-800 px-3 py-1.5 text-xs text-neutral-400 hover:border-neutral-600 hover:text-neutral-200"
        >
          Sign out
        </button>
      </header>

      {/* silent asset-sync strip */}
      <section className="mt-6 flex items-center justify-between rounded-xl border border-neutral-800 bg-neutral-900/60 px-5 py-4">
        {syncState === 'syncing' ? (
          <LogoActivityIndicator state="busy" label={syncLabel} />
        ) : (
          <div className="flex items-center gap-3">
            <RenanceMark size={36} />
            <span className="text-sm text-neutral-400">{syncLabel}</span>
          </div>
        )}
        {syncState === 'syncing' && <span className="text-xs text-neutral-500">runs in background</span>}
      </section>

      {error && (
        <p className="mt-4 rounded-lg border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
          {error}
        </p>
      )}

      <h2 className="mt-10 text-sm font-medium uppercase tracking-wider text-neutral-500">
        Your study packs
      </h2>
      <section className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {(exams.length ? exams : Array.from({ length: 3 }, () => null)).map((exam, i) =>
          exam ? (
            <ExamCard key={exam.code} exam={exam} ready={syncState !== 'syncing'} />
          ) : (
            <div key={i} className="h-40 animate-pulse rounded-xl border border-neutral-800/60 bg-neutral-900/40" />
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
      className="group flex h-40 flex-col justify-between rounded-xl border border-neutral-800 bg-neutral-900 p-5 transition hover:border-emerald-600/60"
    >
      <div>
        <div className="flex items-start justify-between gap-2">
          <h3 className="font-medium leading-snug">{exam.title}</h3>
          <span className="shrink-0 rounded bg-emerald-500/10 px-2 py-0.5 text-[10px] font-medium text-emerald-300">
            {exam.questionCount} Q
          </span>
        </div>
        <p className="mt-1 text-xs text-neutral-500">
          {exam.durationMinutes ? `${exam.durationMinutes} minutes` : 'untimed'} · {exam.totalMarks} marks
        </p>
      </div>
      <div className="flex items-center justify-between">
        <span className="text-xs text-neutral-600 group-hover:text-neutral-400">
          {ready ? 'Ready offline' : 'syncing…'}
        </span>
        <span className="text-sm font-semibold text-emerald-400 group-hover:translate-x-0.5 transition-transform">
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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm">
      <div className="renance-rise w-full max-w-lg rounded-2xl border border-neutral-800 bg-neutral-950 p-8">
        <div className="mb-6 flex items-center gap-3">
          <RenanceMark size={44} state="busy" />
          <div>
            <h2 className="font-semibold">Set up your desk, @{username}</h2>
            <p className="text-xs text-neutral-500">
              We use this to pull the right past questions and syllabus in the background.
            </p>
          </div>
        </div>

        <form onSubmit={onSubmit} className="space-y-5">
          <label className="block">
            <span className="mb-1.5 block text-sm text-neutral-400">Full name</span>
            <input
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="e.g. Ariyo Oluwafemi"
              required
              className="w-full rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-2.5 text-sm outline-none focus:border-emerald-500"
            />
          </label>

          <label className="block">
            <span className="mb-1.5 block text-sm text-neutral-400">Target institution</span>
            <input
              value={institution}
              onChange={(e) => setInstitution(e.target.value)}
              placeholder="e.g. Federal University of Technology, Akure"
              required
              list="institutions"
              className="w-full rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-2.5 text-sm outline-none focus:border-emerald-500"
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
            <span className="mb-1.5 block text-sm text-neutral-400">Current level</span>
            <select
              value={gradeLevel}
              onChange={(e) => setGradeLevel(e.target.value)}
              className="w-full rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-2.5 text-sm outline-none focus:border-emerald-500"
            >
              {GRADE_LEVELS.map((g) => (
                <option key={g}>{g}</option>
              ))}
            </select>
          </label>

          <div>
            <span className="mb-2 block text-sm text-neutral-400">Active examinations</span>
            <div className="flex flex-wrap gap-2">
              {EXAM_OPTIONS.map((exam) => (
                <button
                  key={exam}
                  type="button"
                  onClick={() => toggleExam(exam)}
                  className={`rounded-full border px-4 py-1.5 text-xs font-medium transition ${
                    selected.includes(exam)
                      ? 'border-emerald-500 bg-emerald-500/10 text-emerald-300'
                      : 'border-neutral-700 text-neutral-400 hover:border-neutral-500'
                  }`}
                >
                  {exam}
                </button>
              ))}
            </div>
          </div>

          {error && (
            <p className="rounded-lg border border-red-900/60 bg-red-950/40 px-4 py-3 text-sm text-red-300">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={!valid || busy}
            className="flex w-full items-center justify-center gap-3 rounded-lg bg-emerald-500 px-4 py-3 text-sm font-semibold text-black transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {busy && <RenanceMark size={22} state="busy" />}
            {busy ? 'Saving…' : 'Done — start syncing'}
          </button>
        </form>
      </div>
    </div>
  );
}
