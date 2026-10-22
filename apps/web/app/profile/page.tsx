'use client';

/**
 * Profile, the founder's 2026-10-22 Duolingo-grade identity pass.
 *
 * The page now reads like the Duolingo profile the founder screenshotted,
 * only better: a gradient banner with the scholar's face (uploaded photo
 * from Cloudflare R2's profile-picture/ folder, or one of the 50 baked-in
 * avatars), the @handle + joined date, the Courses/Following/Followers
 * stat row, the ADD FRIENDS + share row, the "Friend suggestions" strip
 * (follow-backs first, dismissible, VIEW ALL), the Overview with every
 * course the scholar is taking and its live progress, the school card,
 * and the classic XP/Streak/Gems/Accuracy strip + learning-focus
 * switcher (exam_target_light) + system menus.
 */

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
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
import { LearnProfile, fetchLearnProfile, MyCourse, fetchMyCourses } from '@/lib/learn';
import {
  type Connections,
  type FollowRow,
  deleteAvatarPhoto,
  fetchConnections,
  fetchPublicProfile,
  fetchSuggestions,
  photoUrl,
  toggleFollow,
  uploadAvatarPhoto,
} from '@/lib/social';
import SideNav from '@/components/side-nav';

interface Profile {
  fullName: string;
  institution: string;
  gradeLevel: string;
  exams: string[];
  targetYear?: number;
  avatar?: string;
  avatarPhoto?: string;
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

/** The month-year join stamp the Duolingo profile wears. */
function joinedLabel(ms: number | null): string {
  if (!ms) return '';
  return new Date(ms).toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
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
  // Founder 2026-10-22: the Duolingo identity pass. joinedMs comes off
  // the public profile endpoint; courses + suggestions fill the new
  // Overview and Friend-suggestions sections.
  const [joinedMs, setJoinedMs] = useState<number | null>(null);
  const [myCourses, setMyCourses] = useState<MyCourse[] | null>(null);
  const [suggestions, setSuggestions] = useState<FollowRow[] | null>(null);
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());
  const [followBusy, setFollowBusy] = useState<string | null>(null);
  const [followed, setFollowed] = useState<Set<string>>(new Set());

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
  // where the level badge used to be): username, display name, then the
  // founder's 2026-10-22 upgrade - a PHOTO tab (upload to R2) next to
  // the AVATAR tab (the 50 baked-in characters).
  const [idOpen, setIdOpen] = useState(false);
  const [idUsername, setIdUsername] = useState('');
  const [idName, setIdName] = useState('');
  const [idAvatar, setIdAvatar] = useState('');
  const [idTab, setIdTab] = useState<'photo' | 'avatar'>('photo');
  const [idBusy, setIdBusy] = useState(false);
  const [idError, setIdError] = useState<string | null>(null);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [pendingFile, setPendingFile] = useState<File | null>(null);

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
        if (res.user.username) {
          fetchPublicProfile(res.user.username)
            .then((r) => alive && setJoinedMs(r.profile?.joinedMs ?? null))
            .catch(() => undefined);
        }
      })
      .catch(() => {});
    api<{ state: GameState }>('/me/gamification')
      .then((g) => alive && setState(g.state))
      .catch(() => {});
    fetchLearnProfile().then((p) => alive && setLearn(p)).catch(() => {});
    fetchConnections()
      .then((c) => {
        if (!alive) return;
        setConnections(c);
        setFollowed(new Set(c.following.map((f) => f.username)));
      })
      .catch(() => {});
    fetchMyCourses()
      .then((r) => alive && setMyCourses(r.courses))
      .catch(() => alive && setMyCourses([]));
    fetchSuggestions(10)
      .then((r) => alive && setSuggestions(r.users))
      .catch(() => alive && setSuggestions([]));
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

  // The face the banner wears: the uploaded photo wins, then the avatar
  // key, then the initial letter.
  const faceSrc = profile?.avatarPhoto ? photoUrl(profile.avatarPhoto) : profile?.avatar ? avatarSrc(profile.avatar) : null;

  const shownSuggestions = useMemo(
    () => (suggestions ?? []).filter((s) => !dismissed.has(s.username)),
    [suggestions, dismissed],
  );

  async function followSuggestion(row: FollowRow) {
    setFollowBusy(row.username);
    const wasFollowing = followed.has(row.username);
    setFollowed((prev) => {
      const next = new Set(prev);
      if (wasFollowing) next.delete(row.username);
      else next.add(row.username);
      return next;
    });
    try {
      const res = await toggleFollow(row.username);
      setFollowed((prev) => {
        const next = new Set(prev);
        if (res.following) next.add(row.username);
        else next.delete(row.username);
        return next;
      });
      setSuggestions((prev) =>
        (prev ?? []).map((s) => (s.username === row.username ? { ...s, following: res.following } : s)),
      );
      setConnections((prev) =>
        prev
          ? {
              followers: res.following ? [...prev.followers, row] : prev.followers,
              following: res.following ? [...prev.following, row] : prev.following.filter((f) => f.username !== row.username),
            }
          : prev,
      );
    } catch {
      setFollowed((prev) => {
        const next = new Set(prev);
        if (wasFollowing) next.add(row.username);
        else next.delete(row.username);
        return next;
      });
    } finally {
      setFollowBusy(null);
    }
  }

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
    setIdTab(profile?.avatarPhoto ? 'photo' : 'photo');
    setPreview(profile?.avatarPhoto ? photoUrl(profile.avatarPhoto) : null);
    setPendingFile(null);
    setPhotoError(null);
    setIdError(null);
    setIdOpen(true);
  }

  function pickFile(f: File | null) {
    setPhotoError(null);
    if (!f) return;
    if (!/^image\/(png|jpe?g|webp)$/.test(f.type)) {
      setPhotoError('The photo must be a PNG, JPEG or WebP image.');
      return;
    }
    if (f.size > 5 * 1024 * 1024) {
      setPhotoError('The photo must be 5MB or smaller.');
      return;
    }
    setPendingFile(f);
    setPreview(URL.createObjectURL(f));
  }

  async function uploadPhoto() {
    if (!pendingFile || photoBusy) return;
    setPhotoBusy(true);
    setPhotoError(null);
    try {
      const r = await uploadAvatarPhoto(pendingFile);
      setMe((prev) => (prev ? { ...prev, profile: prev.profile ? { ...prev.profile, avatarPhoto: r.avatarPhoto } : prev.profile } : prev));
      setPendingFile(null);
      setPhotoBusy(false);
      setIdOpen(false);
    } catch (err) {
      setPhotoError(err instanceof Error ? err.message : 'Could not upload the photo');
      setPhotoBusy(false);
    }
  }

  async function removePhoto() {
    if (photoBusy) return;
    setPhotoBusy(true);
    setPhotoError(null);
    try {
      await deleteAvatarPhoto();
      setMe((prev) => (prev ? { ...prev, profile: prev.profile ? { ...prev.profile, avatarPhoto: '' } : prev.profile } : prev));
      setPreview(null);
      setPendingFile(null);
      setPhotoBusy(false);
    } catch (err) {
      setPhotoError(err instanceof Error ? err.message : 'Could not remove the photo');
      setPhotoBusy(false);
    }
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
  // institutions - is browsable here, not only the schools with banked
  // desks). Other Schools stays pinned last; the search box narrows.
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
  const joined = joinedLabel(joinedMs);

  // Identity photo state for the editor's Photo tab.
  const editorPhotoSrc = preview ?? (profile?.avatarPhoto ? photoUrl(profile.avatarPhoto) : null);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <PageBar title="Profile" />

      <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 px-4 pt-4 sm:px-6">
        <div className="mx-auto w-full max-w-2xl flex flex-col gap-4">
          {/* ── The Duolingo banner (founder 2026-10-22) ─────────────── */}
          <section className="overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            {/* The gradient stage behind the face */}
            <div className="relative flex flex-col items-center bg-gradient-to-b from-[#CE82FF] via-[#A560F8] to-[#7C3AED] px-4 pb-6 pt-7">
              {/* settings gear, top-right like Duolingo */}
              <Link
                href="/settings"
                aria-label="App settings"
                className="absolute right-3 top-3 flex h-9 w-9 items-center justify-center rounded-full text-white/90 transition hover:bg-white/15"
              >
                <span className="material-symbols-outlined text-[22px]">settings</span>
              </Link>
              <div className="relative">
                <div className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-full bg-white/25 text-[34px] font-black text-white ring-4 ring-white/60">
                  {faceSrc ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={faceSrc} alt="Your avatar" className="h-full w-full object-cover" />
                  ) : (
                    name.slice(0, 1).toUpperCase()
                  )}
                </div>
                {/* The camera pencil: opens the identity editor with the
                    Photo tab front and centre (founder 2026-10-22). */}
                <button
                  type="button"
                  onClick={openIdentityEditor}
                  aria-label="Edit your profile"
                  className="absolute bottom-0 right-0 z-10 flex h-8 w-8 items-center justify-center rounded-full border-2 border-card bg-primary text-on-primary shadow-sm transition active:scale-95"
                >
                  <span className="material-symbols-outlined text-[15px]">photo_camera</span>
                </button>
              </div>
            </div>

            {/* Identity + stats on the card body */}
            <div className="flex flex-col items-center gap-1 px-4 pt-3 text-center">
              <h2 className="text-[22px] font-black tracking-tight text-on-surface">{name}</h2>
              <p className="text-[13.5px] font-bold text-on-surface-variant">
                @{me.user.username}
                {joined ? <span className="font-semibold"> · Joined {joined}</span> : null}
              </p>

              {/* The Duolingo stat row: courses / following / followers */}
              <div className="mt-3 flex w-full items-stretch justify-between text-center">
                <div className="flex flex-1 flex-col items-center">
                  <p className="flex items-center gap-1 text-[19px] font-black text-on-surface">
                    <span className="material-symbols-outlined text-[17px] text-primary">menu_book</span>
                    {myCourses?.length ?? 0}
                  </p>
                  <p className="text-[11.5px] font-bold text-on-surface-variant">Courses</p>
                </div>
                <div className="my-1 w-px bg-outline-variant/40" />
                <Link href="/profile/social" className="flex flex-1 flex-col items-center transition hover:opacity-80">
                  <p className="text-[19px] font-black text-on-surface">{connections?.following.length ?? 0}</p>
                  <p className="text-[11.5px] font-bold text-on-surface-variant">Following</p>
                </Link>
                <div className="my-1 w-px bg-outline-variant/40" />
                <Link href="/profile/social" className="flex flex-1 flex-col items-center transition hover:opacity-80">
                  <p className="text-[19px] font-black text-on-surface">{connections?.followers.length ?? 0}</p>
                  <p className="text-[11.5px] font-bold text-on-surface-variant">Followers</p>
                </Link>
              </div>

              {/* ADD FRIENDS + share, the Duolingo action row */}
              <div className="mt-4 flex w-full items-center gap-2">
                <Link
                  href="/profile/search"
                  className="flex flex-1 items-center justify-center gap-2 rounded-xl border-2 border-primary py-2.5 text-[13px] font-extrabold uppercase tracking-wide text-primary transition hover:bg-selection-blue active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[18px]">person_add</span>
                  Add friends
                </Link>
                <button
                  type="button"
                  aria-label="Share your profile"
                  onClick={() => {
                    const url = typeof window !== 'undefined' ? `${window.location.origin}/profile/view/?u=${encodeURIComponent(me.user.username)}` : '';
                    const text = `Add me on Renance - @${me.user.username}`;
                    if (typeof navigator !== 'undefined' && navigator.share) {
                      void navigator.share({ title: 'Renance', text, url }).catch(() => undefined);
                    } else {
                      void navigator.clipboard?.writeText(`${text} ${url}`);
                      setCopied(true);
                      window.setTimeout(() => setCopied(false), 1800);
                    }
                  }}
                  className="flex h-11 w-12 shrink-0 items-center justify-center rounded-xl border-2 border-outline-variant text-on-surface-variant transition hover:bg-surface-container active:translate-y-[1px]"
                >
                  <span className="material-symbols-outlined text-[20px]">ios_share</span>
                </button>
              </div>
            </div>
          </section>

          {/* ── Friend suggestions (founder 2026-10-22) ───────────────── */}
          {shownSuggestions.length > 0 && (
            <section className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
              <div className="mb-3 flex items-baseline justify-between">
                <h3 className="text-[15px] font-black text-on-surface">Friend suggestions</h3>
                <Link href="/profile/search" className="text-[12px] font-extrabold uppercase tracking-wide text-primary hover:underline">
                  View all
                </Link>
              </div>
              <div className="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1">
                {shownSuggestions.map((s) => (
                  <div
                    key={s.username}
                    className="relative w-[132px] shrink-0 snap-start rounded-xl border-2 border-outline-variant/70 p-3 text-center"
                  >
                    <button
                      type="button"
                      aria-label={`Dismiss ${s.name}`}
                      onClick={() => setDismissed((prev) => new Set(prev).add(s.username))}
                      className="absolute right-1 top-1 flex h-6 w-6 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
                    >
                      <span className="material-symbols-outlined text-[15px]">close</span>
                    </button>
                    <Link href={`/profile/view/?u=${encodeURIComponent(s.username)}`} className="mt-2 flex justify-center">
                      <FaceAvatar row={s} size={56} />
                    </Link>
                    <p className="mt-2 truncate text-[13px] font-extrabold text-on-surface">{s.name}</p>
                    {s.followsYou && <p className="text-[11px] font-bold text-on-surface-variant">Follows you</p>}
                    <button
                      type="button"
                      onClick={() => void followSuggestion(s)}
                      disabled={followBusy === s.username}
                      className={`mt-2 w-full rounded-lg py-1.5 text-[11.5px] font-extrabold uppercase tracking-wide transition active:translate-y-[1px] disabled:opacity-60 ${
                        s.following || followed.has(s.username)
                          ? 'border-2 border-outline-variant text-on-surface-variant'
                          : 'bg-macaw text-white'
                      }`}
                    >
                      {s.following || followed.has(s.username) ? 'Following' : 'Follow'}
                    </button>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* ── Overview: the courses on this scholar's desk ──────────── */}
          <section className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="mb-3 flex items-baseline justify-between">
              <h3 className="text-[15px] font-black text-on-surface">Overview</h3>
              <span className="text-[12px] font-bold text-on-surface-variant">
                {myCourses?.length ?? 0} course{(myCourses?.length ?? 0) === 1 ? '' : 's'}
              </span>
            </div>
            {!myCourses && <p className="py-2 text-[13px] font-bold text-on-surface-variant">Loading your courses…</p>}
            {myCourses && myCourses.length === 0 && (
              <div className="rounded-xl border-2 border-dashed border-outline-variant/70 px-4 py-6 text-center">
                <span className="material-symbols-outlined text-[30px] text-primary">school</span>
                <p className="mt-1 text-[13.5px] font-extrabold text-on-surface">No courses yet</p>
                <p className="mt-0.5 text-[12.5px] font-semibold text-on-surface-variant">
                  Pick your first course and it shows up here with your progress.
                </p>
                <Link href="/courses" className="key-btn mt-3 inline-flex bg-primary text-[12.5px] text-on-primary">
                  Find courses
                </Link>
              </div>
            )}
            <div className="flex flex-col gap-3">
              {myCourses?.map((c) => {
                const pct = c.topicCount > 0 ? Math.round((c.completedTopics * 100) / c.topicCount) : 0;
                return (
                  <Link
                    key={c.id}
                    href="/learn"
                    className="group rounded-xl border-2 border-outline-variant/60 p-3 transition hover:border-primary/60 hover:bg-surface-container"
                  >
                    <div className="flex items-center gap-3">
                      <span
                        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-white ${
                          c.active ? 'bg-primary' : 'bg-on-surface-variant/70'
                        }`}
                      >
                        <span className="material-symbols-outlined text-[20px]">auto_stories</span>
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="flex items-center gap-1.5">
                          <span className="min-w-0 truncate text-[13.5px] font-extrabold text-on-surface">{c.title}</span>
                          {c.active && (
                            <span className="shrink-0 rounded-full bg-selection-blue px-1.5 py-0.5 font-mono text-[9.5px] font-black uppercase text-on-surface">
                              Active
                            </span>
                          )}
                        </span>
                        <span className="mt-0.5 block truncate text-[11.5px] font-semibold text-on-surface-variant">
                          {c.completedTopics}/{c.topicCount} topics · {pct}%
                        </span>
                      </span>
                      <span className="material-symbols-outlined shrink-0 text-outline-light transition group-hover:text-primary">
                        chevron_right
                      </span>
                    </div>
                    <div className="mt-2 h-2.5 w-full overflow-hidden rounded-full bg-surface-container">
                      <div
                        className={`h-full rounded-full transition-all ${pct >= 100 ? 'bg-[#FFC800]' : 'bg-primary'}`}
                        style={{ width: `${Math.max(pct, pct > 0 ? 4 : 0)}%` }}
                      />
                    </div>
                  </Link>
                );
              })}
            </div>
          </section>

          {/* ── Stat strip: XP / Streak / Gems / Accuracy ─────────────── */}
          <section className="flex items-center justify-between rounded-xl bg-card p-2 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <div className="flex flex-1 flex-col items-center">
              <span className="text-[13px] text-text-secondary">XP</span>
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
              everyone else gets a locked, read-only card. Founder
              2026-10-22: the school also renders on the new banner-era
              profile so viewers see it (public profiles show it too). */}
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
                  Your school drives the School Desk content and shows on your profile. This is the
                  only place it can be changed after the first pick.
                </p>

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

          {/* Menu group: system -------------------------------------------- */}
          <section className="flex flex-col overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <MenuLink icon="info" tint="text-on-surface-variant" label="About Renance" href="/about" />
            <MenuDivider />
            <MenuLink icon="help" tint="text-on-surface-variant" label="Help & Support" href="/faq" />
          </section>

          {/* The referral invite keeps the invite-friends-for-points loop
              alive (founder 2026-10-14) in its compact card. */}
          {me.entitlement?.referralCode && (
            <section className="flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/15">
                <span className="material-symbols-outlined text-[20px] text-primary-ink">redeem</span>
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[14px] font-bold text-on-surface">Invite friends, earn 100 diamonds</p>
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
            {/* Delete account: asks twice via the server's own confirm
                flow, then purges everything. */}
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

      {/* The identity editor: Photo tab (upload to R2) + Avatar tab
          (the 50 characters) + the name/username fields. Founder
          2026-10-22: photos live in the bucket's profile-picture/
          folder; the one-wins rule means picking a photo clears the
          avatar and picking an avatar clears the photo. */}
      {idOpen && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4"
          onClick={() => !idBusy && !photoBusy && setIdOpen(false)}
          role="presentation"
        >
          <form
            onSubmit={saveIdentity}
            onClick={(e) => {
              e.stopPropagation();
              // Tap a blank stretch of the sheet and the soft keyboard
              // steps aside. Only bare background taps blur - taps on
              // inputs, buttons, labels and links pass through.
              const target = e.target as HTMLElement;
              if (!target.closest('input, button, a, label, [role=\'button\']')) {
                const active = document.activeElement;
                if (active instanceof HTMLElement && active.tagName === 'INPUT') active.blur();
              }
            }}
            className="flex max-h-[92dvh] w-full max-w-md flex-col overflow-hidden rounded-t-2xl bg-card shadow-xl sm:rounded-2xl"
          >
            <div className="flex items-center gap-2 border-b border-outline-variant/40 px-4 py-3.5">
              <span className="material-symbols-outlined text-[20px] text-primary-ink">edit</span>
              <h3 className="text-[15px] font-bold text-on-surface">Edit profile</h3>
              <button
                type="button"
                onClick={() => !idBusy && !photoBusy && setIdOpen(false)}
                aria-label="Close"
                className="ml-auto flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container"
              >
                <span className="material-symbols-outlined text-[18px]">close</span>
              </button>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-4">
              {/* ── Identity image: Photo | Avatar tabs ─────────────── */}
              <div className="mb-3 flex rounded-xl bg-surface-container p-1">
                {(['photo', 'avatar'] as const).map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setIdTab(t)}
                    className={`flex flex-1 items-center justify-center gap-1.5 rounded-lg py-2 text-[12.5px] font-extrabold uppercase tracking-wide transition ${
                      idTab === t ? 'bg-card text-on-surface shadow-sm' : 'text-on-surface-variant'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[16px]">{t === 'photo' ? 'photo_camera' : 'mood'}</span>
                    {t === 'photo' ? 'Photo' : 'Avatar'}
                  </button>
                ))}
              </div>

              {idTab === 'photo' ? (
                <div className="flex flex-col items-center gap-3 rounded-xl border-2 border-dashed border-outline-variant/70 px-4 py-5">
                  <div className="relative">
                    <div className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-full bg-surface-container-high text-[34px] font-black text-on-surface">
                      {editorPhotoSrc ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={editorPhotoSrc} alt="Your photo" className="h-full w-full object-cover" />
                      ) : profile?.avatar ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={avatarSrc(profile.avatar)} alt="" className="h-full w-full object-cover" />
                      ) : (
                        (idName || name).slice(0, 1).toUpperCase()
                      )}
                    </div>
                  </div>
                  <input
                    ref={fileRef}
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    className="hidden"
                    onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
                  />
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => fileRef.current?.click()}
                      className="key-btn bg-primary text-[12.5px] text-on-primary"
                    >
                      {pendingFile ? 'Choose another' : 'Upload photo'}
                    </button>
                    {profile?.avatarPhoto && !pendingFile && (
                      <button
                        type="button"
                        onClick={() => void removePhoto()}
                        disabled={photoBusy}
                        className="key-btn border-2 border-outline-variant bg-card text-[12.5px] text-on-surface-variant disabled:opacity-50"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                  {pendingFile && (
                    <button
                      type="button"
                      onClick={() => void uploadPhoto()}
                      disabled={photoBusy}
                      className="key-btn w-full bg-macaw text-[12.5px] text-white disabled:opacity-60"
                    >
                      {photoBusy ? 'Uploading…' : 'Save photo'}
                    </button>
                  )}
                  {photoError && (
                    <p className="w-full rounded-lg bg-error-container px-3 py-2 text-center text-[12.5px] font-semibold text-on-error-container">
                      {photoError}
                    </p>
                  )}
                  <p className="text-center text-[11.5px] font-semibold text-on-surface-variant">
                    PNG, JPEG or WebP · up to 5MB. Stored on Cloudflare R2 and used everywhere your face shows.
                  </p>
                </div>
              ) : (
                <div className="grid max-h-56 grid-cols-5 gap-2 overflow-y-auto overscroll-contain pr-1 sm:grid-cols-6">
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
              )}

              <label className="mt-4 block">
                <span className="mb-1 block font-mono text-xs uppercase tracking-wider text-on-surface-variant">
                  Full name
                </span>
                <input
                  value={idName}
                  onChange={(e) => setIdName(e.target.value)}
                  maxLength={120}
                  enterKeyHint="done"
                  autoComplete="name"
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
                    enterKeyHint="go"
                    autoCapitalize="none"
                    autoComplete="username"
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

            <div className="flex gap-2 border-t border-outline-variant/40 px-4 pb-[max(0.875rem,env(safe-area-inset-bottom))] pt-3.5">
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

/** The suggestion/row face: photo wins, then avatar, then the initial. */
function FaceAvatar({ row, size = 40 }: { row: { avatar?: string; photo?: string; name?: string; username?: string }; size?: number }) {
  const src = row.photo ? photoUrl(row.photo) : row.avatar ? avatarSrc(row.avatar) : null;
  const initial = (row.name || row.username || '?').slice(0, 1).toUpperCase();
  return (
    <span
      className="flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-surface-container-high font-bold text-on-surface"
      style={{ width: size, height: size, fontSize: Math.max(11, size * 0.38) }}
    >
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt="" className="h-full w-full object-cover" loading="lazy" />
      ) : (
        initial
      )}
    </span>
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
