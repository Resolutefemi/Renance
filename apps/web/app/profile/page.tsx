'use client';

/**
 * Profile, the Stitch profile_light screen, 1:1, plus the founder's
 * learning-focus switcher: students move between JAMB, WAEC, NECO and
 * tertiary institutions without losing papers or XP (exam_target_light).
 * Mobile follows the Stitch column; PC centres a reading column and the
 * sticky PageBar carries the top-LHS back button.
 */

import { FormEvent, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, API_BASE } from '@/lib/api';
import { clearSession, getToken } from '@/lib/session';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';
import PageBar from '@/components/page-bar';
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

interface GameState {
  currentStreak: number;
  bestStreak: number;
  totalXp: number;
  totalCorrect: number;
  attempts: number;
  level: number;
}

const EXAM_OPTIONS = ['JAMB', 'WAEC', 'NECO', 'University Modules'] as const;
const TARGET_YEARS = [2026, 2027, 2028] as const;

const EXAM_META: Record<string, { title: string; subtitle: string; icon: string }> = {
  JAMB: { title: 'JAMB UTME', subtitle: 'Nigerian university admissions', icon: 'school' },
  WAEC: {
    title: 'WAEC/WASSCE',
    subtitle: 'West African senior school certificate',
    icon: 'workspace_premium',
  },
  NECO: { title: 'NECO', subtitle: 'National examinations council', icon: 'verified' },
  'University Modules': {
    title: 'Tertiary institution',
    subtitle: 'Undergraduate semester exams',
    icon: 'account_balance',
  },
};

function xpLabel(xp: number): string {
  return xp >= 1000 ? `${(xp / 1000).toFixed(1)}k` : `${xp}`;
}

export default function ProfilePage() {
  const router = useRouter();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [state, setState] = useState<GameState | null>(null);

  // Focus switcher state ---------------------------------------------------
  const [editing, setEditing] = useState(false);
  const [exam, setExam] = useState<string>('');
  const [year, setYear] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [focusError, setFocusError] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    let alive = true;
    api<MeResponse>('/me')
      .then((res) => {
        if (!alive) return;
        setMe(res);
        const first = res.profile?.exams?.[0] ?? '';
        setExam(first);
        setYear(res.profile?.targetYear ?? null);
      })
      .catch(() => {});
    api<{ state: GameState }>('/me/gamification')
      .then((g) => alive && setState(g.state))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [router]);

  const profile = me?.profile ?? null;
  const accuracy = useMemo(() => {
    if (!state || state.attempts === 0) return 0;
    return Math.round((state.totalCorrect * 100) / state.attempts);
  }, [state]);

  const targetChip = useMemo(() => {
    if (!profile?.exams?.length) return 'No target yet';
    const base = profile.exams[0];
    return profile.targetYear ? `${base} ${profile.targetYear}` : base;
  }, [profile]);

  async function saveFocus(e: FormEvent) {
    e.preventDefault();
    if (!exam || year == null || busy || !profile) return;
    setBusy(true);
    setFocusError(null);
    try {
      const res = await api<{ profile: Profile }>('/me/profile', {
        method: 'PUT',
        body: {
          fullName: profile.fullName,
          institution: profile.institution,
          gradeLevel: profile.gradeLevel,
          exams: [exam],
          targetYear: year,
        },
      });
      setMe((prev) => (prev ? { ...prev, profile: res.profile } : prev));
      setBusy(false);
      setEditing(false);
      // Packs for the new focus sync in the background; best effort.
      void fetch(`${API_BASE}/sync`, { method: 'POST' }).catch(() => {});
    } catch (err) {
      setFocusError(err instanceof Error ? err.message : 'Could not save focus');
      setBusy(false);
    }
  }

  function signOut() {
    clearSession();
    // Respect the Pages base path when redirecting to the sign-in screen.
    const bp = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
    window.location.href = `${bp}/login`;
  }

  if (!me) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Opening your profile…" />
      </main>
    );
  }

  const name = profile?.fullName || me.user.username || 'Renance scholar';
  const level = state?.level ?? 1;

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      <PageBar title="Profile" />

      <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 px-4 pt-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl flex flex-col gap-4">
          {/* Header card: avatar + level badge, name, chip, stat strip */}
          <section className="flex flex-col gap-4 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="flex items-center gap-4">
              <div className="relative shrink-0">
                <div className="flex h-20 w-20 items-center justify-center rounded-full border border-outline-light bg-surface-container-high text-2xl font-semibold text-on-surface">
                  {name.slice(0, 1).toUpperCase()}
                </div>
                <div className="absolute -bottom-1 -right-1 flex items-center justify-center rounded-full border-2 border-card bg-accent-ink px-2 py-0.5 font-mono text-[11px] text-white shadow-sm">
                  Lvl {level}
                </div>
              </div>
              <div className="min-w-0 flex-1">
                <h2 className="truncate text-2xl font-bold tracking-tight text-on-surface">{name}</h2>
                <div className="mt-1 flex items-center gap-2">
                  <span className="truncate text-[15px] text-text-secondary">@{me.user.username}</span>
                  <span className="shrink-0 rounded-full bg-selection-blue px-2 py-0.5 font-mono text-[12px] text-on-surface">
                    {targetChip}
                  </span>
                </div>
              </div>
            </div>

            {/* Stat strip */}
            <div className="mt-1 flex items-center justify-between rounded-lg bg-surface-container p-2">
              <div className="flex flex-1 flex-col items-center">
                <span className="text-[13px] text-text-secondary">XP</span>
                <span className="text-2xl font-bold tracking-tight text-accent-ink">
                  {xpLabel(state?.totalXp ?? 0)}
                </span>
              </div>
              <div className="h-8 w-px bg-outline-light/30" />
              <div className="flex flex-1 flex-col items-center">
                <span className="text-[13px] text-text-secondary">Streak</span>
                <div className="flex items-center gap-1">
                  <span className="material-symbols-outlined fill-current text-[18px] text-accent-amber">
                    local_fire_department
                  </span>
                  <span className="text-2xl font-bold tracking-tight text-on-surface">
                    {state?.currentStreak ?? 0}
                  </span>
                </div>
              </div>
              <div className="h-8 w-px bg-outline-light/30" />
              <div className="flex flex-1 flex-col items-center">
                <span className="text-[13px] text-text-secondary">Accuracy</span>
                <span className="text-2xl font-bold tracking-tight text-accent-emerald">{accuracy}%</span>
              </div>
            </div>
          </section>

          {/* Learning focus switcher (founder directive) ---------------------- */}
          <section className="overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            {!editing ? (
              <button
                type="button"
                onClick={() => {
                  setEditing(true);
                  setFocusError(null);
                }}
                className="flex w-full items-center gap-4 p-4 text-left transition hover:bg-surface-container-high"
              >
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-selection-blue text-on-surface">
                  <span className="material-symbols-outlined">track_changes</span>
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-semibold text-on-surface">Learning focus</p>
                  <p className="truncate text-[13px] text-text-secondary">
                    Preparing for {targetChip}. Tap to switch.
                  </p>
                </div>
                <span className="material-symbols-outlined text-outline-light">swap_horiz</span>
              </button>
            ) : (
              <form onSubmit={saveFocus} className="p-4">
                <div className="mb-3 flex items-center gap-2">
                  <span className="material-symbols-outlined text-[20px] text-on-surface">track_changes</span>
                  <h3 className="text-[15px] font-semibold text-on-surface">What are you preparing for?</h3>
                </div>
                <p className="mb-4 text-[13px] text-text-secondary">
                  Switch your target exam and the whole app reshapes around it. Your papers and XP stay put.
                </p>
                <div className="flex flex-col gap-2">
                  {EXAM_OPTIONS.map((opt) => {
                    const active = exam === opt;
                    const meta = EXAM_META[opt];
                    return (
                      <button
                        key={opt}
                        type="button"
                        onClick={() => setExam(opt)}
                        className={`flex items-center gap-3 rounded-xl p-3 text-left transition ${
                          active
                            ? 'bg-selection-blue shadow-[inset_0_0_0_2px_#111c2d]'
                            : 'bg-surface-container-lowest shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] ring-1 ring-outline-variant/60'
                        }`}
                      >
                        <div
                          className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${
                            active ? 'bg-primary text-on-primary' : 'bg-surface-container-low text-on-surface-variant'
                          }`}
                        >
                          <span className="material-symbols-outlined text-[22px]">{meta.icon}</span>
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] font-semibold text-on-surface">{meta.title}</p>
                          <p className="truncate text-[13px] text-text-secondary">{meta.subtitle}</p>
                        </div>
                        {active && (
                          <span className="material-symbols-outlined text-primary">check_circle</span>
                        )}
                      </button>
                    );
                  })}
                </div>

                <p className="mb-2 mt-4 font-mono text-xs uppercase tracking-wider text-on-surface-variant">
                  Exam year
                </p>
                <div className="flex gap-2">
                  {TARGET_YEARS.map((y) => (
                    <button
                      key={y}
                      type="button"
                      onClick={() => setYear(y)}
                      className={`rounded-full px-4 py-1.5 font-mono text-sm transition ${
                        year === y
                          ? 'bg-selection-blue text-on-surface ring-1 ring-primary'
                          : 'bg-surface-container-low text-on-surface-variant'
                      }`}
                    >
                      {y}
                    </button>
                  ))}
                </div>

                {focusError && (
                  <p className="mt-3 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
                    {focusError}
                  </p>
                )}

                <div className="mt-4 flex gap-2">
                  <button
                    type="button"
                    onClick={() => setEditing(false)}
                    className="rounded-lg px-4 py-3 text-sm font-medium text-on-surface-variant hover:bg-surface-container"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={!exam || year == null || busy}
                    className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-primary py-3 text-sm font-semibold text-on-primary transition-transform active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {busy && <RenanceMark size={20} state="busy" />}
                    {busy ? 'Saving…' : 'Save focus'}
                  </button>
                </div>
              </form>
            )}
          </section>

          {/* Menu group: content ------------------------------------------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <MenuLink icon="auto_stories" tint="text-accent-ink" label="My Packs" href="/dashboard#packs" />
            <MenuDivider />
            <MenuLink icon="download" tint="text-accent-ink" label="Downloads" href="/dashboard#packs" />
            <MenuDivider />
            <MenuLink icon="workspace_premium" tint="text-accent-ink" label="Certificates" href="/certificates" />
          </section>

          {/* Menu group: system -------------------------------------------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <MenuLink icon="history_edu" tint="text-on-surface-variant" label="My papers" href="/review" />
            <MenuDivider />
            <MenuLink icon="help" tint="text-on-surface-variant" label="Help & Support" href="/faq" />
          </section>

          {/* Sign out ------------------------------------------------------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <button
              type="button"
              onClick={signOut}
              className="group flex w-full items-center gap-4 p-4 text-left transition hover:bg-error-container"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-error-container text-error transition group-hover:bg-card">
                <span className="material-symbols-outlined">logout</span>
              </div>
              <div className="flex-1 text-[15px] font-semibold text-error">Sign Out</div>
            </button>
          </section>

          <p className="pb-4 text-center text-[13px] text-text-secondary">
            {profile?.institution ? `${profile.institution} · ${profile.gradeLevel}` : profile?.gradeLevel}
          </p>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}

function MenuLink({
  icon,
  tint,
  label,
  href,
}: {
  icon: string;
  tint: string;
  label: string;
  href: string;
}) {
  return (
    <Link href={href} className="flex items-center gap-4 p-4 transition hover:bg-surface-container-high">
      <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-container ${tint}`}>
        <span className="material-symbols-outlined">{icon}</span>
      </div>
      <div className="flex-1 text-[15px] font-semibold text-on-surface">{label}</div>
      <span className="material-symbols-outlined text-outline-light">chevron_right</span>
    </Link>
  );
}

function MenuDivider() {
  return <div className="mx-4 h-px bg-surface-container-high" />;
}
