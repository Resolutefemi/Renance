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
import { focusFromExams, setFocus } from '@/lib/focus';
import {
  OTHERS_SCHOOL,
  SCHOOLS,
  TYPE_ICONS,
  TYPE_LABELS,
  clearPendingInstitution,
  findSchoolByName,
  readPendingInstitution,
  storeSchoolSlug,
  type School,
} from '@/lib/university';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import ShopPanel from '@/components/learn/shop-panel';
import { LearnProfile, fetchLearnProfile } from '@/lib/learn';
import { type Connections, fetchConnections } from '@/lib/social';
import SideNav from '@/components/side-nav';

interface Profile {
  fullName: string;
  institution: string;
  gradeLevel: string;
  exams: string[];
  targetYear?: number;
  avatar?: string;
  completed: boolean;
}

interface MeResponse {
  user: { id: string; username: string; profileCompleted: boolean };
  profile: Profile | null;
  email?: string;
  entitlement?: {
    renCoins: number;
    referralCode?: string;
    premiumRole: boolean;
    premiumType?: string;
  };
}

interface GameState {
  currentStreak: number;
  bestStreak: number;
  totalXp: number;
  totalCorrect: number;
  attempts: number;
  level: number;
}

const EXAM_OPTIONS = ['JAMB', 'WAEC', 'NECO', 'POST-UTME', 'University Modules'] as const;
const TARGET_YEARS = [2026, 2027, 2028] as const;

// The 50 baked-in avatars (founder directive 2026-10-17). Deterministic
// filenames: avatar-01.svg .. avatar-50.svg under /avatars.
const AVATAR_COUNT = 50;
const AVATARS = Array.from({ length: AVATAR_COUNT }, (_, i) => `avatar-${String(i + 1).padStart(2, '0')}`);
const avatarSrc = (key: string) => `/avatars/${key}.svg`;

const EXAM_META: Record<string, { title: string; subtitle: string; icon: string }> = {
  JAMB: { title: 'JAMB UTME', subtitle: 'Nigerian tertiary institution admissions', icon: 'school' },
  WAEC: {
    title: 'WAEC/WASSCE',
    subtitle: 'West African senior school certificate',
    icon: 'workspace_premium',
  },
  NECO: { title: 'NECO', subtitle: 'National examinations council', icon: 'verified' },
  'POST-UTME': {
    title: 'Post UTME',
    subtitle: 'School screening past questions',
    icon: 'quiz',
  },
  'University Modules': {
    title: 'School Desk',
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
  // Supreme learn stats (founder 2026-10-14): gems, hearts, league,
  // topics done and perfect scores live on the profile too.
  const [learn, setLearn] = useState<LearnProfile | null>(null);
  // The follow graph (founder 2026-10-14 evening pass): followers and
  // following counts read right on the profile; the lists live on
  // /profile/social with follow-backs.
  const [connections, setConnections] = useState<Connections | null>(null);

  // Focus switcher state ---------------------------------------------------
  const [editing, setEditing] = useState(false);
  const [exam, setExam] = useState<string>('');
  const [year, setYear] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [focusError, setFocusError] = useState<string | null>(null);

  // My school editor state (the ONLY place a picked school changes).
  const [schoolEditing, setSchoolEditing] = useState(false);
  const [schoolName, setSchoolName] = useState('');
  const [schoolQuery, setSchoolQuery] = useState('');
  const [schoolBusy, setSchoolBusy] = useState(false);
  const [schoolError, setSchoolError] = useState<string | null>(null);
  // Referral link copy feedback. Lives up here with the other hooks: a
  // hook declared below the loading early-return crashes the page with
  // "Rendered fewer hooks than expected" the moment /me resolves.
  const [copied, setCopied] = useState(false);

  // The identity editor (founder directive 2026-10-17: the pencil sits
  // where the level badge used to be): username, display name and one
  // of the 50 Renance avatars, saved through PUT /me/profile.
  const [idOpen, setIdOpen] = useState(false);
  const [idUsername, setIdUsername] = useState('');
  const [idName, setIdName] = useState('');
  const [idAvatar, setIdAvatar] = useState('');
  const [idBusy, setIdBusy] = useState(false);
  const [idError, setIdError] = useState<string | null>(null);

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
        setFocus(focusFromExams(res.profile?.exams));
        setYear(res.profile?.targetYear ?? null);
      })
      .catch(() => {});
    api<{ state: GameState }>('/me/gamification')
      .then((g) => alive && setState(g.state))
      .catch(() => {});
    fetchLearnProfile().then((p) => alive && setLearn(p)).catch(() => {});
    fetchConnections()
      .then((c) => alive && setConnections(c))
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
      setFocus(focusFromExams(res.profile?.exams));
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

  function openIdentityEditor() {
    setIdUsername(me?.user.username ?? '');
    setIdName(profile?.fullName ?? '');
    setIdAvatar(profile?.avatar ?? '');
    setIdError(null);
    setIdOpen(true);
  }

  async function saveIdentity(e: FormEvent) {
    e.preventDefault();
    if (!me || !profile || idBusy) return;
    const name = idName.trim();
    if (name.length < 2) {
      setIdError('Your full name needs at least 2 characters');
      return;
    }
    setIdBusy(true);
    setIdError(null);
    try {
      const res = await api<{ profile: Profile; user?: { username: string } }>('/me/profile', {
        method: 'PUT',
        body: {
          fullName: name,
          institution: profile.institution,
          gradeLevel: profile.gradeLevel,
          exams: profile.exams,
          targetYear: profile.targetYear ?? null,
          avatar: idAvatar,
          ...(idUsername.trim() && idUsername.trim().toLowerCase() !== me.user.username
            ? { username: idUsername.trim().toLowerCase() }
            : {}),
        },
      });
      setMe((prev) =>
        prev
          ? {
              ...prev,
              profile: res.profile,
              user: res.user ? { ...prev.user, username: res.user.username } : prev.user,
            }
          : prev,
      );
      setIdBusy(false);
      setIdOpen(false);
    } catch (err) {
      setIdError(err instanceof Error ? err.message.replace('learn: ', '') : 'Could not save your profile');
      setIdBusy(false);
    }
  }

  async function saveSchool(e: FormEvent) {
    e.preventDefault();
    if (!profile || schoolBusy) return;
    setSchoolBusy(true);
    setSchoolError(null);
    try {
      const res = await api<{ profile: Profile }>('/me/profile', {
        method: 'PUT',
        body: {
          fullName: profile.fullName,
          institution: schoolName.trim(),
          gradeLevel: profile.gradeLevel,
          exams: profile.exams,
          targetYear: profile.targetYear ?? null,
        },
      });
      setMe((prev) => (prev ? { ...prev, profile: res.profile } : prev));
      // Keep the School Desk pick in step with the profile record.
      const matched = findSchoolByName(schoolName.trim());
      if (matched) {
        // A school without a banked desk yet still becomes the student's
        // institution - its content rides the shared general pool, so
        // the desk slug routes to Other Schools (founder 2026-10-16).
        storeSchoolSlug(matched.live ? matched.slug : 'others');
      }
      clearPendingInstitution();
      setSchoolBusy(false);
      setSchoolEditing(false);
    } catch (err) {
      setSchoolError(err instanceof Error ? err.message : 'Could not save school');
      setSchoolBusy(false);
    }
  }

  // The school picker's browsable list (founder directive 2026-10-16,
  // second batch: the FULL directory - 1,100+ Nigerian tertiary
  // institutions, every university, polytechnic, college of education
  // and nursing/health college in the registry - is browsable here, not
  // only the schools with banked desks; a school without content yet
  // still becomes the student's institution and rides the shared
  // general pool). Other Schools stays pinned last: the fallback for
  // a name the student still cannot find. The search box narrows, an
  // empty query shows the whole shelf so it is ALWAYS browsable.
  const schoolPickResults = useMemo<School[]>(() => {
    const q = schoolQuery.trim().toLowerCase();
    const listed = SCHOOLS.filter((s) => s.slug !== 'others');
    const base = q
      ? listed.filter(
          (s) =>
            s.name.toLowerCase().includes(q) ||
            s.short.toLowerCase().includes(q) ||
            s.state.toLowerCase().includes(q),
        )
      : listed;
    return [...base, OTHERS_SCHOOL];
  }, [schoolQuery]);

  if (!me) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Opening your profile…" />
      </main>
    );
  }

  // Founder-only school switching (2026-10-04): the only account that
  // may change its school from the profile is the founder's; everyone
  // else reads a locked card (the first pick still happens on the School
  // Desk gate).
  const isFounder = (me.email ?? '').trim().toLowerCase() === 'ariyooluwafemi487@gmail.com';
  const hasSchool = Boolean(profile?.institution?.trim());
  const schoolEditable = isFounder || !hasSchool;

  const name = profile?.fullName || me.user.username || 'Renance scholar';

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Profile" />

      <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 px-4 pt-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl flex flex-col gap-4">
          {/* Header card: avatar + level badge, name, chip, stat strip */}
          <section className="flex flex-col gap-4 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="flex items-center gap-4">
              <div className="relative shrink-0">
                {profile?.avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={avatarSrc(profile.avatar)}
                    alt="Your avatar"
                    className="h-20 w-20 rounded-full border border-outline-light bg-surface-container-high object-cover"
                  />
                ) : (
                  <div className="flex h-20 w-20 items-center justify-center rounded-full border border-outline-light bg-surface-container-high text-2xl font-semibold text-on-surface">
                    {name.slice(0, 1).toUpperCase()}
                  </div>
                )}
                {/* The pencil (founder directive 2026-10-17: it replaces
                    the level badge): opens the identity editor - username,
                    display name and the 50-avatar picker. */}
                <button
                  type="button"
                  onClick={openIdentityEditor}
                  aria-label="Edit your profile"
                  className="absolute -bottom-1 -right-1 flex h-8 w-8 items-center justify-center rounded-full border-2 border-card bg-primary text-on-primary shadow-sm transition active:scale-95"
                >
                  <span className="material-symbols-outlined text-[16px]">edit</span>
                </button>
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
                {/* Founder 2026-10-15: the XP readout reads primary-ink
                    (light pastel accent on the fixed dark surface - the
                    dark accent-ink was invisible on the dark strip) with
                    tabular figures so the number never jitters. */}
                <span className="text-2xl font-bold tabular-nums tracking-tight text-primary-ink">
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
                <span className="text-[13px] text-text-secondary">Gems</span>
                <div className="flex items-center gap-1">
                  <span aria-hidden className="inline-block h-3.5 w-3.5 rounded-[3px] bg-macaw shadow-[0_1px_0_0_#1899d6]" />
                  <span className="text-2xl font-bold tracking-tight text-macaw-dark">
                    {learn ? learn.gems.toLocaleString() : 0}
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

          {/* The league strip is RETIRED (founder 2026-10-15: "remove the
              Bronze League card from the profile"). The league standings
              still live on /league from the sidebar. */}

          {/* The follow strip (founder 2026-10-14 evening pass): followers
              and following read right on the profile; tapping opens the
              lists on /profile/social with follow-backs. Founder
              2026-10-15: it sits DIRECTLY above the invite-friends card. */}
          <section className="flex items-stretch overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <Link href="/profile/social" className="flex flex-1 items-center justify-center gap-2 py-3.5 transition hover:bg-surface-container-high">
              <span className="material-symbols-outlined text-[19px] text-primary">group</span>
              <span className="text-[14px] font-bold text-on-surface">{connections?.followers.length ?? 0}</span>
              <span className="text-[13px] font-semibold text-text-secondary">Followers</span>
            </Link>
            <div className="my-3 w-px bg-outline-light/40" />
            <Link href="/profile/social" className="flex flex-1 items-center justify-center gap-2 py-3.5 transition hover:bg-surface-container-high">
              <span className="material-symbols-outlined text-[19px] text-macaw-dark">person_add</span>
              <span className="text-[14px] font-bold text-on-surface">{connections?.following.length ?? 0}</span>
              <span className="text-[13px] font-semibold text-text-secondary">Following</span>
            </Link>
          </section>

          {/* The big premium subscription card is RETIRED (founder
              directive 2026-10-14: "remove that big premium subscription
              card from the profile") - the whole REN wallet gradient
              with it. The referral invite below keeps the
              invite-friends-for-points loop alive in a compact card. */}
          {me.entitlement?.referralCode && (
            <section className="flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/15">
                <span className="material-symbols-outlined text-[20px] text-primary-ink">redeem</span>
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[14px] font-bold text-on-surface">Invite friends, earn REN</p>
                <p className="truncate font-mono text-[12px] font-bold tracking-wider text-on-surface-variant">
                  {me.entitlement.referralCode}
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  const link = `${window.location.origin}/register/?ref=${me.entitlement!.referralCode}`;
                  void navigator.clipboard?.writeText(link);
                  setCopied(true);
                  window.setTimeout(() => setCopied(false), 1800);
                }}
                className="key-btn shrink-0 bg-primary px-3.5 text-[12px] text-on-primary"
              >
                {copied ? 'Copied' : 'Copy link'}
              </button>
            </section>
          )}

          {/* The follow strip (founder 2026-10-14 evening pass) lives
              DIRECTLY above the invite card now (founder 2026-10-15) -
              it was moved up to sit on top of "Invite friends". */}

          {/* The SHOP lives here now (founder 2026-10-14 evening pass):
              "the shop feature should be under profile and the heart read
              too" - the gem store, the heart readout (REAL data, the ∞
              symbol is retired) and the Super trial ride inside this
              section. The old /shop page redirects here. */}
          <section className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="mb-3 flex items-center gap-2">
              <span className="material-symbols-outlined text-[20px] text-primary-ink">storefront</span>
              <h3 className="text-[15px] font-bold text-on-surface">Shop</h3>
            </div>
            <ShopPanel id="shop" />
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

          {/* My school: the ONLY place the picked school can change -------
              and since 2026-10-04 only the founder's account can switch;
              everyone else gets a locked, read-only card. */}
          <section className="overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            {!schoolEditing || !schoolEditable ? (
              schoolEditable ? (
                <button
                  type="button"
                  onClick={() => {
                    // Prefill the saved institution; a School Desk gate
                    // pick that has not reached the profile yet (the
                    // pending stamp) fills the editor until Save lands.
                    const prefill = profile?.institution || readPendingInstitution();
                    setSchoolName(prefill);
                    setSchoolQuery(prefill);
                    setSchoolError(null);
                    setSchoolEditing(true);
                  }}
                  className="flex w-full items-center gap-4 p-4 text-left transition hover:bg-surface-container-high"
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-selection-blue text-on-surface">
                    <span className="material-symbols-outlined">account_balance</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-[15px] font-semibold text-on-surface">My school</p>
                    <p className="truncate text-[13px] text-text-secondary">
                      {profile?.institution
                        ? profile.institution
                        : readPendingInstitution()
                          ? `${readPendingInstitution()} (picked on the School Desk - tap save to keep it)`
                          : 'Not set yet. Pick your school here.'}
                    </p>
                  </div>
                  <span className="material-symbols-outlined text-outline-light">edit</span>
                </button>
              ) : (
                <div className="flex w-full items-center gap-4 p-4 text-left">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-selection-blue text-on-surface">
                    <span className="material-symbols-outlined">account_balance</span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-[15px] font-semibold text-on-surface">My school</p>
                    <p className="truncate text-[13px] text-text-secondary">
                      {profile?.institution || 'Not set yet'}
                    </p>
                  </div>
                  <span className="material-symbols-outlined text-outline-light">lock</span>
                </div>
              )
            ) : (
              <form onSubmit={saveSchool} className="p-4">
                <div className="mb-3 flex items-center gap-2">
                  <span className="material-symbols-outlined text-[20px] text-on-surface">account_balance</span>
                  <h3 className="text-[15px] font-semibold text-on-surface">Which school are you in?</h3>
                </div>
                <p className="mb-4 text-[13px] text-text-secondary">
                  Your school drives the School Desk content. This is the only place it can
                  be changed after the first pick.
                </p>

                {/* Search box (founder bug report 2026-10-11: the old
                    datalist never listed the schools until you typed the
                    exact name, and its dropdown was unusable). The list
                    below is always browsable and scrolls. */}
                <div className="flex items-center gap-2 rounded-lg border border-outline-variant bg-surface-container px-3.5 py-2.5 transition-colors focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/40">
                  <span className="material-symbols-outlined text-[18px] text-on-surface-variant">search</span>
                  <input
                    value={schoolQuery}
                    onChange={(e) => {
                      setSchoolQuery(e.target.value);
                      // free text stays a valid pick: whatever is typed
                      // is what saves until a row below is picked.
                      setSchoolName(e.target.value);
                    }}
                    placeholder="Search school, short code or state…"
                    className="w-full bg-transparent text-sm text-on-surface placeholder:text-outline focus:outline-none"
                  />
                  {schoolQuery && (
                    <button
                      type="button"
                      onClick={() => {
                        setSchoolQuery('');
                        setSchoolName(profile?.institution ?? '');
                      }}
                      aria-label="Clear search"
                      className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
                    >
                      <span className="material-symbols-outlined text-[16px]">close</span>
                    </button>
                  )}
                </div>

                {/* The browsable, scrollable school list: every live
                    desk (the same listing as the School Desk gate) plus
                    Other Schools pinned last. Founder bug 2026-10-16:
                    the list sits on its OWN opaque, isolated layer -
                    z-stacked above the summary text and action row, with
                    a viewport-fraction height bound so it can never
                    overflow onto the Save buttons. */}
                <ul className="relative z-10 mt-3 max-h-[45vh] list-none divide-y divide-outline-variant/40 overflow-y-auto overscroll-contain rounded-xl border border-outline-variant/60 bg-card shadow-sm">
                  {schoolPickResults.map((s) => {
                    const isOthers = s.slug === 'others';
                    const selected = schoolName.trim().toLowerCase() === s.name.toLowerCase();
                    return (
                      <li key={s.slug}>
                        <button
                          type="button"
                          onClick={() => {
                            setSchoolName(s.name);
                            setSchoolQuery(isOthers ? '' : s.name);
                          }}
                          className={`flex w-full items-center gap-3 px-3.5 py-3 text-left transition ${
                            selected ? 'bg-selection-blue/25' : 'hover:bg-surface-container'
                          }`}
                        >
                          <span
                            className={`flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full ${
                              selected ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
                            }`}
                          >
                            <span className="material-symbols-outlined text-[16px] leading-none">
                              {isOthers ? 'diversity_3' : TYPE_ICONS[s.type] ?? 'account_balance'}
                            </span>
                          </span>
                          <span className="min-w-0 flex-1">
                            {/* Founder bug 2026-10-16: long university
                                names wrapped to an early "…" even with
                                room to spare - the name may now use the
                                full row width and wrap to two lines. */}
                            <span className="block break-words text-[14px] font-semibold leading-snug text-on-surface">
                              {s.name}
                            </span>
                            <span className="block truncate text-[11.5px] text-on-surface-variant">
                              {isOthers
                                ? 'Merged general course banks for every unlisted school'
                                : `${TYPE_LABELS[s.type]}${s.state ? ` · ${s.state}` : ''}`}
                            </span>
                          </span>
                          {selected && (
                            <span className="material-symbols-outlined shrink-0 text-[18px] text-primary">check_circle</span>
                          )}
                        </button>
                      </li>
                    );
                  })}
                </ul>

                {/* The picked value - what Save will write. */}
                <p className="mt-3 text-[12.5px] text-on-surface-variant">
                  {schoolName.trim() ? (
                    <>
                      Saving school:{' '}
                      <span className="font-semibold text-on-surface">{schoolName.trim()}</span>
                      {!findSchoolByName(schoolName.trim()) && (
                        <span className="text-accent-amber"> (not a listed desk yet - general desks still apply)</span>
                      )}
                    </>
                  ) : (
                    'Pick a school from the list above, or type a name not listed.'
                  )}
                </p>

                {schoolError && (
                  <p className="mt-3 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
                    {schoolError}
                  </p>
                )}

                <div className="mt-4 flex gap-2">
                  <button
                    type="button"
                    onClick={() => setSchoolEditing(false)}
                    className="rounded-lg px-4 py-3 text-sm font-medium text-on-surface-variant hover:bg-surface-container"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={schoolBusy || !schoolName.trim()}
                    className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-primary py-3 text-sm font-semibold text-on-primary transition-transform active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {schoolBusy && <RenanceMark size={20} state="busy" />}
                    {schoolBusy ? 'Saving…' : 'Save school'}
                  </button>
                </div>
              </form>
            )}
          </section>

          {/* Menu group: account (the avatar popup retired - everything it
              held now lives here, founder 2026-10-14 evening pass) ------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <MenuLink icon="insights" tint="text-on-surface" label="Performance Analysis" href="/performance" />
            <MenuDivider />
            <MenuLink icon="bookmark" tint="text-on-surface" label="Saved Questions" href="/saved" />
            <MenuDivider />
            <MenuLink icon="settings" tint="text-on-surface" label="App Settings" href="/settings" />
          </section>

          {/* Menu group: content ------------------------------------------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            {/* Founder 2026-10-15: the My Packs icon is pure white in the
                dark tier (text-on-surface) like its sibling menu icons -
                the old accent-ink tint vanished on the dark card. */}
            <MenuLink icon="auto_stories" tint="text-on-surface" label="My Packs" href="/packs" />
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
            <MenuDivider />
            {/* Delete account (from the retired avatar popup): asks twice
                via the server's own confirm flow, then purges everything. */}
            <a
              href="/delete-account"
              className="group flex w-full items-center gap-4 p-4 text-left transition hover:bg-error-container"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-error-container text-error transition group-hover:bg-card">
                <span className="material-symbols-outlined">delete_forever</span>
              </div>
              <div className="flex-1 text-[15px] font-semibold text-error">Delete account</div>
            </a>
          </section>

          <p className="pb-4 text-center text-[13px] text-text-secondary">
            {profile?.institution ? `${profile.institution} · ${profile.gradeLevel}` : profile?.gradeLevel}
          </p>
        </div>
      </div>

      {/* The identity editor: username, display name, avatar. */}
      {idOpen && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4"
          onClick={() => !idBusy && setIdOpen(false)}
          role="presentation"
        >
          <form
            onSubmit={saveIdentity}
            onClick={(e) => e.stopPropagation()}
            className="flex max-h-[92dvh] w-full max-w-md flex-col overflow-hidden rounded-t-2xl bg-card shadow-xl sm:rounded-2xl"
          >
            <div className="flex items-center gap-2 border-b border-outline-variant/40 px-4 py-3.5">
              <span className="material-symbols-outlined text-[20px] text-primary-ink">edit</span>
              <h3 className="text-[15px] font-bold text-on-surface">Edit profile</h3>
              <button
                type="button"
                onClick={() => !idBusy && setIdOpen(false)}
                aria-label="Close"
                className="ml-auto flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
              >
                <span className="material-symbols-outlined text-[18px]">close</span>
              </button>
            </div>

            {/* min-h-0 is the load-bearing fix (founder report
                2026-10-17: mobile could never reach the Save button):
                without it the flex child refuses to shrink below its
                content height, the 50-avatar grid pushes the footer
                past the 92dvh sheet, and overflow-hidden clips the
                Save button off forever. */}
            <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
              <p className="mb-2 font-mono text-xs uppercase tracking-wider text-on-surface-variant">
                Pick your avatar
              </p>
              <div className="grid grid-cols-5 gap-2 sm:grid-cols-6">
                {AVATARS.map((a) => {
                  const active = idAvatar === a;
                  return (
                    <button
                      key={a}
                      type="button"
                      onClick={() => setIdAvatar(active ? '' : a)}
                      aria-label={`Choose avatar ${a}`}
                      className={`relative overflow-hidden rounded-full transition ${
                        active ? 'ring-2 ring-primary ring-offset-2 ring-offset-card' : 'opacity-90 hover:opacity-100'
                      }`}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={avatarSrc(a)} alt="" className="aspect-square w-full object-cover" />
                      {active && (
                        <span className="absolute bottom-0 right-0 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-on-primary">
                          <span className="material-symbols-outlined text-[11px] leading-none">check</span>
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>

              <label className="mt-4 block">
                <span className="mb-1 block font-mono text-xs uppercase tracking-wider text-on-surface-variant">
                  Full name
                </span>
                <input
                  value={idName}
                  onChange={(e) => setIdName(e.target.value)}
                  maxLength={120}
                  className="w-full rounded-lg border border-outline-variant bg-surface-container px-3.5 py-2.5 text-sm text-on-surface focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/40"
                  placeholder="Your name"
                />
              </label>

              <label className="mt-3 block">
                <span className="mb-1 block font-mono text-xs uppercase tracking-wider text-on-surface-variant">
                  Username
                </span>
                <div className="flex items-center rounded-lg border border-outline-variant bg-surface-container px-3.5 focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/40">
                  <span className="text-sm text-text-secondary">@</span>
                  <input
                    value={idUsername}
                    onChange={(e) => setIdUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
                    maxLength={24}
                    className="w-full bg-transparent py-2.5 pl-0.5 text-sm text-on-surface focus:outline-none"
                    placeholder="your_handle"
                  />
                </div>
                <span className="mt-1 block text-[11.5px] text-text-secondary">
                  3-24 characters: lowercase letters, numbers, underscores.
                </span>
              </label>

              {idError && (
                <p className="mt-3 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">{idError}</p>
              )}
            </div>

            <div className="flex gap-2 border-t border-outline-variant/40 px-4 pt-3.5 pb-[max(0.875rem,env(safe-area-inset-bottom))]">
              <button
                type="button"
                onClick={() => setIdOpen(false)}
                disabled={idBusy}
                className="rounded-lg px-4 py-3 text-sm font-medium text-on-surface-variant transition hover:bg-surface-container"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={idBusy || idName.trim().length < 2}
                className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-primary py-3 text-sm font-semibold text-on-primary transition-transform active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
              >
                {idBusy && <RenanceMark size={20} state="busy" />}
                {idBusy ? 'Saving…' : 'Save profile'}
              </button>
            </div>
          </form>
        </div>
      )}

      <SideNav />
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
