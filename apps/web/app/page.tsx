import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { loadLessons, loadManifest } from '@/lib/site-data';
import { GUIDES } from '@/lib/guides';
import OpenAppButton from '@/components/open-app-button';
import LandingDefaultTheme from '@/components/landing-default-theme';
import { RenanceMark } from '@/components/renance-logo';
import {
  MotionPrefs,
  LandingNav,
  Reveal,
  CountUp,
  AuroraField,
  FloatingCard,
  MarqueeRail,
} from '@/components/landing-motion';

/**
 * The public landing page. The motto "Your Guide to Academic Success"
 * lives in the navbar now (founder directive 2026-10-18); the hero
 * carries the platform claim and the founder-written description.
 *
 * Built to feel alive: an aurora gradient field drifts behind frosted
 * glass panels, feature tiles lift on hover, stats count in on scroll
 * and an exam-pack ticker runs under the hero. Everything above the
 * fold is still static HTML with structured data (SEO doctrine), the
 * client components only add motion and never gate content.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://renance.app';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  openGraph: { url: SITE_URL, images: [...OG_IMAGES] },
};

const FEATURES = [
  {
    icon: 'fact_check',
    tone: 'blue',
    glow: 'rgba(59,130,246,0.16)',
    title: 'Server-graded CBT papers',
    body: 'Every mock is marked on the server with sealed answer keys, the same doctrine real exam bodies use. No browser tricks, no self-marking: your score is honest even when the network drops.',
  },
  {
    icon: 'event_repeat',
    tone: 'violet',
    glow: 'rgba(139,92,246,0.16)',
    title: 'Missed topics return before you forget',
    body: 'Topics you miss enter an SM-2 spaced-repetition queue and come back right when memory starts to fade. Clear the queue, keep the knowledge, no planner to maintain.',
  },
  {
    icon: 'record_voice_over',
    tone: 'teal',
    glow: 'rgba(20,184,166,0.16)',
    title: 'Voice flashcards',
    body: 'Decks that read themselves aloud on your phone, so you can drill while walking, cooking or commuting. Leitner-boxed so hard cards come back sooner and easy ones fade away.',
  },
  {
    icon: 'auto_stories',
    tone: 'emerald',
    glow: 'rgba(16,185,129,0.16)',
    title: 'The JAMB novel, question by question',
    body: 'The Lekki Headmaster ships as an opt-in question set inside every Use of English mock. Switch it on when you are ready, exactly like the hall asks.',
  },
  {
    icon: 'battery_saver',
    tone: 'amber',
    glow: 'rgba(245,158,11,0.18)',
    title: 'Fatigue-aware sessions',
    body: 'Renance notices when your answer pace collapses and nudges you to take five, because tired practice teaches the wrong lessons.',
  },
  {
    icon: 'bolt',
    tone: 'blue',
    glow: 'rgba(99,102,241,0.16)',
    title: 'Instant practice, anywhere',
    body: 'Every past-question bank ships with the site, so a paper opens the moment you tap it. Answers and worked solutions grade right on your device, even on a weak network.',
  },
] as const;

const STEPS = [
  {
    icon: 'how_to_reg',
    title: 'Register in 10 seconds',
    body: 'Email and password only, no forms to drown in. Set your target exam and year, and your desk is ready.',
  },
  {
    icon: 'tune',
    title: 'Set the paper your way',
    body: 'Pick subjects, pin a particular year or go fully random, size the English section, decide on passages and the novel, or carve a custom practice set.',
  },
  {
    icon: 'military_tech',
    title: 'Sit, grade, review, rise',
    body: 'Sit under real CBT rules, get graded server-side in seconds, walk the topic breakdown, and let the review queue schedule your comeback.',
  },
] as const;

// The For Schools story: the same platform, wearing the school badge.
const SCHOOL_FEATURES = [
  {
    icon: 'account_balance',
    title: 'The Nigerian curriculum, pre-installed',
    body: 'Primary 1 to 6, JSS 1 to 3 and SSS 1 to 3 with the NERDC subject list land in your portal the moment you register. Senior classes compose their subjects from Core, Art, Science and Commercial tracks.',
  },
  {
    icon: 'auto_stories',
    title: 'Syllabuses, topics and a real note library',
    body: 'Every term syllabus carries its topics, weekly scheme of work and notes your teachers can edit. Notes come from classnotes.ng and NERDC-sourced material, credited and kept legal, and schools pour in more any time.',
  },
  {
    icon: 'fact_check',
    title: 'Attendance with a classroom kiosk',
    body: 'Mark the daily register in seconds, or project the kiosk and let pupils tap themselves present. Every term rolls up into per-student attendance rates.',
  },
  {
    icon: 'workspace_premium',
    title: 'Results with positions and PIN-secured checking',
    body: 'Fill CA1, CA2 and exam scores per subject, finalize, and the portal computes positions, grades and class averages. Each student gets a private 6-digit PIN to check their own result.',
  },
  {
    icon: 'calendar_month',
    title: 'Weekly timetable, period by period',
    body: 'Draw each class week on a live grid: subjects per period, assembly and break blocks, bell times included. Edit on the web and the whole school reads the same grid.',
  },
  {
    icon: 'quiz',
    title: 'An exam question bank per subject per term',
    body: 'Original, NERDC-aligned questions pour into your school pool in one tap, and publishing a paper draws from it ready to print. Your teachers keep adding school-written questions.',
  },
  {
    icon: 'badge',
    title: 'Serial-numbered student ID cards',
    body: 'Issue every student a card with their photo, class and a school-unique serial, then print the sheet on normal paper. A lost card is revoked, not forgotten.',
  },
  {
    icon: 'payments',
    title: 'Fees and receipts in one ledger',
    body: 'Price term charges per class or school-wide, record cash, transfer or POS receipts per student, and read the outstanding balance straight off the debtors list.',
  },
  {
    icon: 'co_present',
    title: 'Teacher accounts with real boundaries',
    body: 'Create an account per teacher, assign them classes and subjects, and they fill exactly those results cells and teach exactly those notes. Nothing more.',
  },
  {
    icon: 'devices',
    title: 'Offline app for your staff',
    body: 'Teachers and management get syllabus, scheme of work and notes on the Renance app, downloadable for offline use in the classroom. Records and results stay on the web.',
  },
] as const;

function fmt(n: number): string {
  return n.toLocaleString('en-US');
}

export default function Landing() {
  const lessons = loadLessons().slice(0, 3);
  const manifest = loadManifest();
  const exams = manifest?.exams ?? [];
  const totalQuestions = exams.reduce((s, e) => s + (e.questionCount ?? 0), 0);
  // A sane floor guards the headline: bundle metadata has carried
  // stray small ints before, and "past questions from 1" is silly.
  const allYears = exams.flatMap((e) => e.years ?? []).filter((y) => y >= 1970 && y <= 2100);
  const yearFrom = allYears.length ? Math.min(...allYears) : 1978;
  const yearTo = allYears.length ? Math.max(...allYears) : new Date().getFullYear();
  const byBody = (body: string) => exams.filter((e) => e.body === body);
  const jambExams = byBody('JAMB');
  const waecExams = byBody('WAEC');
  const necoExams = byBody('NECO');
  const uniExams = exams.filter((e) => e.category === 'university');
  const sum = (list: typeof exams) => list.reduce((s, e) => s + (e.questionCount ?? 0), 0);

  /* exam-pack ticker: the biggest packs by question count */
  const tickerItems = [...exams]
    .sort((a, b) => (b.questionCount ?? 0) - (a.questionCount ?? 0))
    .slice(0, 14)
    .map((e) => `${e.title ?? e.code ?? 'Pack'} · ${fmt(e.questionCount ?? 0)} Q`);

  const iconTone: Record<string, string> = {
    blue: 'linear-gradient(135deg,#3b82f6,#6366f1)',
    violet: 'linear-gradient(135deg,#8b5cf6,#6366f1)',
    teal: 'linear-gradient(135deg,#14b8a6,#10b981)',
    emerald: 'linear-gradient(135deg,#10b981,#34d399)',
    amber: 'linear-gradient(135deg,#f59e0b,#f97316)',
  };

  return (
    <div className="landing bg-background">
      {/* The landing keeps the DEFAULT Renance palette - a student's
          Appearance seed repaints every other surface, never this one
          (founder directive 2026-10-05). Renders nothing; the effect
          strips the seed keys from <html> on arrival and restores them
          on the way out. */}
      <LandingDefaultTheme />
      <MotionPrefs>
        <LandingNav />
      </MotionPrefs>

      {/* ============================================================ */}
      {/* HERO - aurora field, split desktop layout, contained badges  */}
      {/* 2026-10-18 desktop pass: the old hero floated four glass      */}
      {/* cards around the headline (they drifted into the margins and  */}
      {/* crowded the title on wide monitors) and forced 100svh, which  */}
      {/* clipped the pack ticker at the fold. Now: a structured split  */}
      {/* - copy left, live CBT paper preview right - and ONE calm      */}
      {/* feature row under the CTAs at every breakpoint.               */}
      {/* 2026-10-18 mobile pass: top padding tightened so the headline */}
      {/* anchors near the fold under the fixed pill nav, the wall of   */}
      {/* copy became one lead line + three scannable bullets, and the  */}
      {/* CTA sits right under them. Floating cards are static now.     */}
      {/* ============================================================ */}
      <section className="relative overflow-hidden pb-16 pt-24 sm:pt-28 lg:pb-24 lg:pt-36">
        <AuroraField />

        <div className="relative z-10 mx-auto w-full max-w-6xl px-4 sm:px-6">
          <div className="lg:grid lg:grid-cols-[1.02fr_0.98fr] lg:items-center lg:gap-12 xl:gap-16">
            <div className="mx-auto max-w-3xl text-center lg:mx-0 lg:max-w-none lg:text-left">
              <h1 className="hero-headline hero-enter hero-enter-1 text-on-surface">
                Renance: Nigeria&apos;s <span className="hero-gradient-text">Biggest</span> Educational
                and School Management App
              </h1>

              <p className="hero-enter hero-enter-2 mx-auto mt-4 max-w-xl text-[15px] font-medium leading-relaxed text-on-surface sm:text-lg lg:mx-0">
                Renance is Nigeria&apos;s Biggest Educational and school management app available on
                Android, iOS, Windows, macOS, and Web.
              </p>
              <p className="hero-enter hero-enter-2 mx-auto mt-3 max-w-xl text-[14px] leading-relaxed text-on-surface-variant sm:text-[15px] lg:mx-0">
                For students, the app helps master JAMB, WAEC, NECO, and university exams using
                over 288,500 past questions spanning from 1978 to 2025 alongside more than 10,000
                courses and over 2,000,000+ topics. For schools, it automates administration with
                attendance, results, ID cards, and lecture notes all in one place.
              </p>
              <ul className="hero-enter hero-enter-2 mx-auto mt-4 flex max-w-xl flex-col gap-2 text-left sm:gap-2.5 lg:mx-0">
                {[
                  {
                    icon: 'fact_check',
                    text: 'CBT mocks the server grades - sealed answer keys, honest scores in seconds.',
                  },
                  {
                    icon: 'event_repeat',
                    text: 'A smart review queue - topics you miss come back before you forget them.',
                  },
                ].map((b) => (
                  <li
                    key={b.icon}
                    className="flex items-start gap-2.5 text-[13.5px] leading-snug text-on-surface-variant sm:text-[15px]"
                  >
                    <span className="material-symbols-outlined mt-0.5 text-[17px] text-primary" aria-hidden>
                      {b.icon}
                    </span>
                    {b.text}
                  </li>
                ))}
              </ul>

              <div className="hero-enter hero-enter-3 mt-6 flex flex-wrap items-center justify-center gap-3.5 lg:justify-start">
                <OpenAppButton className="hero-cta-primary" />
                <Link href="/subjects/" className="hero-cta-secondary">
                  Browse {exams.length} question packs
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden>
                    <path
                      d="M3 8h9M8.5 3.5 13 8l-4.5 4.5"
                      stroke="currentColor"
                      strokeWidth="1.8"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </Link>
              </div>
            </div>

            {/* the live-paper preview - desktop only. A still of an actual
                UTME question mid-sit: progress, timer, options, the sealed
                server grade. Pure presentational markup (aria-hidden). */}
            <div className="hero-enter hero-enter-4 mt-12 hidden lg:mt-0 lg:block" aria-hidden>
              <div className="relative">
                <div className="glass relative rounded-3xl p-5 xl:p-6">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-on-surface-variant">
                        UTME 2025 · Use of English
                      </p>
                      <p className="mt-1 text-[15px] font-bold text-on-surface">Question 14 of 60</p>
                    </div>
                    <span className="flex items-center gap-1 rounded-full bg-[var(--ink)] px-2.5 py-1 font-mono text-[11px] font-bold text-[var(--color-background)]">
                      <span className="material-symbols-outlined text-[13px]">timer</span>
                      12:47
                    </span>
                  </div>
                  <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-[var(--ink)]/10">
                    <div className="h-full w-[23%] rounded-full bg-gradient-to-r from-[#3b82f6] to-[#10b981]" />
                  </div>
                  <p className="mt-5 text-[15px] leading-relaxed text-on-surface">
                    Choose the option <em>nearest</em> in meaning to the word underlined: The
                    clerk&apos;s{' '}
                    <span className="font-bold underline decoration-2 underline-offset-4">gregarious</span>{' '}
                    nature won him friends in every office.
                  </p>
                  <div className="mt-4 grid gap-2">
                    {[
                      { k: 'A', v: 'talkative', ok: false },
                      { k: 'B', v: 'mysterious', ok: false },
                      { k: 'C', v: 'sociable', ok: true },
                      { k: 'D', v: 'selfish', ok: false },
                    ].map((o) => (
                      <div
                        key={o.k}
                        className={`flex items-center gap-3 rounded-xl border px-3.5 py-2.5 ${
                          o.ok
                            ? 'border-emerald-500/40 bg-emerald-500/10'
                            : 'border-[var(--glass-ring)] bg-[var(--glass-bg)]/40'
                        }`}
                      >
                        <span
                          className={`grid h-6 w-6 shrink-0 place-items-center rounded-full font-mono text-[11px] font-bold ${
                            o.ok ? 'bg-emerald-500 text-white' : 'bg-[var(--ink)]/8 text-on-surface-variant'
                          }`}
                        >
                          {o.k}
                        </span>
                        <span className="text-[13.5px] text-on-surface">{o.v}</span>
                        {o.ok && (
                          <span className="material-symbols-outlined ml-auto text-[16px] text-emerald-500">
                            check_circle
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                  <div className="mt-5 flex items-center justify-between gap-3 border-t border-[var(--glass-border)] pt-4">
                    <span className="flex items-center gap-1.5 text-[12px] font-semibold text-on-surface-variant">
                      <span className="material-symbols-outlined text-[15px] text-emerald-500">verified</span>
                      Server-graded · sealed answer keys
                    </span>
                    <span className="font-mono text-[11px] text-on-surface-variant">1978-{yearTo}</span>
                  </div>
                </div>
                {/* one anchored chip, the only survivor of the old orbit */}
                <div className="glass-float float-emerald absolute -bottom-6 -right-3 max-w-[13rem]">
                  <div className="glass-float-icon">
                    <span className="material-symbols-outlined">military_tech</span>
                  </div>
                  <div>
                    <p className="glass-float-title">Graded in seconds</p>
                    <p className="glass-float-body">Score synced to your desk</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* the feature row - every breakpoint, one calm grid directly
              under the hero copy and CTAs. The old desktop orbit cards
              lived here no longer (2026-10-18 desktop pass). */}
          <div className="mt-10 grid grid-cols-2 gap-3 sm:mt-12 sm:grid-cols-4">
            <FloatingCard
              tone="blue"
              icon="fact_check"
              title="Server-graded"
              body="Honest marks, always"
            />
            <FloatingCard
              tone="emerald"
              icon="event_repeat"
              title="Review queue"
              body="Missed topics return"
            />
            <FloatingCard
              tone="amber"
              icon="record_voice_over"
              title="Voice flashcards"
              body="Drill hands-free"
            />
            <FloatingCard
              tone="blue"
              icon="workspace_premium"
              title={`${fmt(totalQuestions)}+ questions`}
              body="Real papers"
            />
          </div>
        </div>

        {/* exam-pack ticker - the section now flows at its natural height
            on desktop, so the rail can never be guillotined by the fold */}
        {tickerItems.length > 0 && (
          <div className="hero-enter hero-enter-5 relative z-10 mt-12 lg:mt-16">
            <MarqueeRail items={tickerItems} />
          </div>
        )}
      </section>

      {/* ============================================================ */}
      {/* STATS BAND                                                   */}
      {/* ============================================================ */}
      <section className="relative z-10 mx-auto -mt-2 w-full max-w-6xl px-4 sm:px-6">
        <Reveal>
          <dl className="grid grid-cols-2 gap-3.5 sm:gap-4 lg:grid-cols-4">
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                <CountUp to={totalQuestions} suffix="+" />
              </dd>
              <dt className="stat-label">Past questions</dt>
            </div>
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                <CountUp to={exams.length} />
              </dd>
              <dt className="stat-label">Exam packs</dt>
            </div>
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                {yearFrom}-{yearTo}
              </dd>
              <dt className="stat-label">Years covered</dt>
            </div>
            <div className="stat-glass glass-hover">
              <dd className="stat-value text-[clamp(1.2rem,2.6vw,1.7rem)] leading-tight">
                JAMB · WAEC · NECO
              </dd>
              <dt className="stat-label">Exam bodies</dt>
            </div>
          </dl>
        </Reveal>
      </section>

      {/* ============================================================ */}
      {/* COVERAGE - the archive, by body                              */}
      {/* ============================================================ */}
      {/* pb-20 pairs with the for-schools section's own pb-20: the two
          dark panels below are full-bleed neighbours and used to touch
          edge to edge (founder screenshot 2026-10-04). */}
      <section className="mx-auto w-full max-w-6xl px-4 pb-20 pt-20 sm:px-6">
        <Reveal>
          <div className="cbt-panel p-6 sm:p-10">
            <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-end">
              <div>
                <span
                  className="eyebrow"
                  style={{
                    color: '#7db2ff',
                    background: 'rgba(125,178,255,0.1)',
                    borderColor: 'rgba(125,178,255,0.22)',
                  }}
                >
                  The archive
                </span>
                <h2 className="mt-3 text-2xl font-bold tracking-tight text-white sm:text-3xl">
                  The archive is the product
                </h2>
                <p className="mt-2 max-w-xl text-sm leading-relaxed text-white/70">
                  Every pack carries the year it was sat, the options, the sealed answer key and the
                  worked explanation, harvested, cleaned and organised so you practise the real
                  thing, not a paraphrase.
                </p>
              </div>
              <Link
                href="/subjects/"
                className="shrink-0 rounded-full bg-white px-5 py-2.5 text-sm font-extrabold text-[#111c2d] shadow-[0_4px_0_0_rgba(0,0,0,0.35)] transition hover:bg-white/90 active:translate-y-[2px] active:shadow-[0_2px_0_0_rgba(0,0,0,0.35)]"
              >
                See full subject coverage →
              </Link>
            </div>
            <div className="mt-8 grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-4">
              {[
                {
                  body: 'JAMB (UTME)',
                  count: sum(jambExams),
                  packs: jambExams.length,
                  note: '1978-2025 · all subjects · novel included',
                },
                {
                  body: 'WAEC',
                  count: sum(waecExams),
                  packs: waecExams.length,
                  note: 'objectives + theory with model answers',
                },
                {
                  body: 'NECO',
                  count: sum(necoExams),
                  packs: necoExams.length,
                  note: 'objectives + theory packs',
                },
                {
                  body: 'Tertiary Institution',
                  count: sum(uniExams),
                  packs: uniExams.length,
                  note: 'per-school course banks, more landing',
                },
              ].map((b) => (
                <div
                  key={b.body}
                  className="rounded-2xl bg-white/[0.06] p-5 ring-1 ring-white/10 shadow-[inset_0_1px_0_rgba(255,255,255,0.07),0_3px_0_0_rgba(0,0,0,0.30)] transition hover:bg-white/[0.1]"
                >
                  <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-white/60">
                    {b.body}
                  </p>
                  <p className="mt-2 text-2xl font-bold text-white">{fmt(b.count)}</p>
                  <p className="mt-0.5 text-xs text-white/60">
                    questions · {b.packs} packs · {b.note}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </Reveal>
      </section>

      {/* ============================================================ */}
      {/* FOR SCHOOLS                                                   */}
      {/* ============================================================ */}
      <section id="for-schools" className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
        <Reveal>
          <div className="cbt-panel p-6 sm:p-10">
            <div className="flex flex-col items-start justify-between gap-5 lg:flex-row lg:items-end">
              <div className="max-w-2xl">
                <span
                  className="eyebrow"
                  style={{
                    color: '#ffffff',
                    background: 'rgba(255,255,255,0.08)',
                    borderColor: 'rgba(255,255,255,0.2)',
                  }}
                >
                  New · For Schools
                </span>
                <h2 className="mt-3 text-2xl font-bold tracking-tight text-white sm:text-4xl">
                  Run your school on the same platform
                </h2>
                <p className="mt-3 text-[15px] leading-relaxed text-white/75">
                  Renance is no longer only for candidates. Register your school, install the
                  Nigerian curriculum in one tap, enroll your students with full details, hand your
                  teachers their classes, and manage syllabuses, notes, attendance and results from
                  one desk. Students check their results themselves with a private PIN.
                </p>
              </div>
              <div className="flex shrink-0 flex-wrap gap-3">
                <Link
                  href="/register/?audience=school"
                  className="rounded-full bg-white px-6 py-3 text-sm font-extrabold text-[#111c2d] shadow-[0_4px_0_0_rgba(0,0,0,0.35)] transition hover:bg-white/90 active:translate-y-[2px] active:shadow-[0_2px_0_0_rgba(0,0,0,0.35)]"
                >
                  Register your school
                </Link>
                <Link
                  href="/school/check/"
                  className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white shadow-[0_4px_0_0_rgba(0,0,0,0.28)] transition hover:bg-white/10 active:translate-y-[2px] active:shadow-[0_2px_0_0_rgba(0,0,0,0.28)]"
                >
                  Check a result PIN
                </Link>
                <Link
                  href="/for-schools/"
                  className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white shadow-[0_4px_0_0_rgba(0,0,0,0.28)] transition hover:bg-white/10 active:translate-y-[2px] active:shadow-[0_2px_0_0_rgba(0,0,0,0.28)]"
                >
                  Explore Renance for Schools
                </Link>
              </div>
            </div>

            <div className="mt-9 grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
              {SCHOOL_FEATURES.map((f) => (
                <div
                  key={f.title}
                  className="rounded-2xl bg-white/[0.06] p-5 ring-1 ring-white/10 shadow-[inset_0_1px_0_rgba(255,255,255,0.07),0_3px_0_0_rgba(0,0,0,0.30)] transition hover:bg-white/[0.1]"
                >
                  <span
                    className="chip-icon material-symbols-outlined h-10 w-10 rounded-xl bg-white text-[#111c2d] shadow-[0_3px_0_0_rgba(0,0,0,0.35)]"
                    aria-hidden
                  >
                    {f.icon}
                  </span>
                  <h3 className="mt-4 text-[15px] font-bold text-white">{f.title}</h3>
                  <p className="mt-2 text-[13px] leading-relaxed text-white/70">{f.body}</p>
                </div>
              ))}
            </div>

            <p className="mt-7 border-t border-white/10 pt-5 text-xs leading-relaxed text-white/50">
              The school portal is strict black and white on the web. Management runs records and
              results there; staff carry syllabuses, schemes of work and notes offline in the app.
            </p>
          </div>
        </Reveal>
      </section>

      {/* ============================================================ */}
      {/* FEATURES                                                     */}
      {/* ============================================================ */}
      <section className="mx-auto w-full max-w-6xl px-4 py-20 sm:px-6">
        <Reveal className="text-center">
          <span className="eyebrow">Why Renance</span>
          <h2 className="mt-4 text-2xl font-bold tracking-tight text-on-surface sm:text-4xl">
            Everything a serious candidate needs
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-[15px] leading-relaxed text-on-surface-variant">
            Not a quiz bank with ads glued on, but a complete study companion that remembers what
            you missed and schedules the fix.
          </p>
        </Reveal>

        <div className="mt-10 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f, i) => (
            <Reveal key={f.title} delay={i * 70}>
              <article className="feature-card h-full">
                <span
                  className="feature-icon material-symbols-outlined"
                  style={{ background: iconTone[f.tone] ?? iconTone.blue }}
                >
                  {f.icon}
                </span>
                <h3 className="mt-4 text-[15px] font-bold text-on-surface">{f.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-on-surface-variant">{f.body}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </section>

      {/* ============================================================ */}
      {/* HOW IT WORKS                                                 */}
      {/* ============================================================ */}
      <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
        <Reveal className="text-center">
          <span className="eyebrow">Three steps</span>
          <h2 className="mt-4 text-2xl font-bold tracking-tight text-on-surface sm:text-4xl">
            From panic to pass mark
          </h2>
        </Reveal>
        <div className="mt-10 grid grid-cols-1 gap-4 sm:grid-cols-3">
          {STEPS.map((s, i) => (
            <Reveal key={s.title} delay={i * 90}>
              <article className="step-card feature-card h-full">
                <div className="flex items-start justify-between">
                  <span
                    className="feature-icon material-symbols-outlined"
                    style={{ background: iconTone[['blue', 'violet', 'emerald'][i]] }}
                  >
                    {s.icon}
                  </span>
                  <span className="step-num">{i + 1}</span>
                </div>
                <h3 className="mt-4 text-[15px] font-bold text-on-surface">{s.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-on-surface-variant">{s.body}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </section>

      {/* ============================================================ */}
      {/* EXAM-DAY FIDELITY                                            */}
      {/* ============================================================ */}
      <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <Reveal>
            <div className="cbt-panel h-full p-6 sm:p-8">
              <div className="relative">
                <span
                  className="feature-icon material-symbols-outlined"
                  style={{ background: 'linear-gradient(135deg,#3b82f6,#6366f1)' }}
                >
                  desktop_windows
                </span>
                <h3 className="mt-4 text-lg font-bold tracking-tight text-white">
                  A CBT hall on every screen
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/75">
                  The player mirrors the real JAMB software: a live question map, flag-and-return,
                  answers that lock in exam mode, a hall-approved calculator, auto-submit at zero,
                  and a keyboard-first desktop layout (A-F to pick, arrows to move) so laptop
                  candidates train the way they will sit.
                </p>
                <ul className="mt-5 space-y-2.5">
                  {[
                    'Pause & resume with an honest clock',
                    'Topic breakdown after every paper',
                    'Worked explanations on every review',
                  ].map((t) => (
                    <li key={t} className="cbt-check">
                      <span className="material-symbols-outlined text-[17px] text-emerald-400">
                        check_circle
                      </span>
                      {t}
                    </li>
                  ))}
                </ul>
                <div className="mt-6 flex flex-wrap gap-2">
                  <span className="cbt-score-pill">⏱ 59:47 left</span>
                  <span className="cbt-score-pill">Q17 / 60</span>
                  <span className="cbt-score-pill" style={{ color: '#6ee7b7' }}>
                    ▲ 87%
                  </span>
                </div>
              </div>
            </div>
          </Reveal>

          <Reveal delay={100}>
            <div className="cbt-panel h-full p-6 sm:p-8">
              <div className="relative">
                <span
                  className="feature-icon material-symbols-outlined"
                  style={{ background: 'linear-gradient(135deg,#f59e0b,#f97316)' }}
                >
                  auto_stories
                </span>
                <h3 className="mt-4 text-lg font-bold tracking-tight text-white">
                  Reading “The Lekki Headmaster”?
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/75">
                  JAMB&apos;s recommended text ships inside Renance as a proper question set: fifty
                  questions across all twelve chapters, each with the sealed answer and a worked
                  explanation. Switch it on in Mock Setup when you are ready; leave it off while you
                  are still reading.
                </p>
                <p className="mt-5 font-mono text-[11px] uppercase tracking-[0.2em] text-white/50">
                  Kabir Alabi Garba · UTME Use of English
                </p>
                <div className="mt-6 grid grid-cols-4 gap-2">
                  {['Ch 1-3', 'Ch 4-6', 'Ch 7-9', 'Ch 10-12'].map((c) => (
                    <span
                      key={c}
                      className="rounded-xl bg-white/[0.06] px-2 py-2.5 text-center text-[11px] font-semibold text-white/75 ring-1 ring-white/10 shadow-[inset_0_1px_0_rgba(255,255,255,0.07),0_3px_0_0_rgba(0,0,0,0.30)]"
                    >
                      {c}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ============================================================ */}
      {/* LESSONS PREVIEW                                              */}
      {/* ============================================================ */}
      {lessons.length > 0 && (
        <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
          <Reveal className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <span className="eyebrow">Free library</span>
              <h2 className="mt-4 text-2xl font-bold tracking-tight text-on-surface sm:text-4xl">
                Start reading free
              </h2>
            </div>
            <Link
              href="/lessons/"
              className="text-sm font-semibold text-on-surface-variant hover:text-on-surface"
            >
              All lessons →
            </Link>
          </Reveal>
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {lessons.map((les, i) => (
              <Reveal key={les.slug} delay={i * 80}>
                <Link
                  href={`/lessons/${les.slug}/`}
                  className="glass glass-hover group flex h-full flex-col rounded-2xl p-5 no-underline"
                >
                  {les.subject && (
                    <span className="w-fit rounded-full bg-selection-blue px-2.5 py-0.5 text-[11px] font-medium text-on-surface">
                      {les.subject}
                    </span>
                  )}
                  <h3 className="mt-3 text-[15px] font-semibold leading-snug text-on-surface group-hover:underline">
                    {les.title}
                  </h3>
                  <p className="mt-2 line-clamp-2 text-[13px] leading-relaxed text-on-surface-variant">
                    {les.summary}
                  </p>
                  <span className="mt-auto pt-3 font-mono text-xs text-on-surface-variant">
                    {les.minutes} min read →
                  </span>
                </Link>
              </Reveal>
            ))}
          </div>
        </section>
      )}

      {/* ============================================================ */}
      {/* GUIDES - the explainers AI and search engines can cite        */}
      {/* ============================================================ */}
      <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
        <Reveal>
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-end">
            <div>
              <span className="eyebrow">Exam guides</span>
              <h2 className="mt-3 text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
                Understand the exam, not just the questions
              </h2>
              <p className="mt-2 max-w-xl text-sm leading-relaxed text-on-surface-variant">
                Plain explanations of how the UTME is scored, what your result can and
                cannot do, which O&apos;level body fits you, and what actually happens in
                the CBT hall.
              </p>
            </div>
            <Link href="/guides/" className="shrink-0 text-sm font-bold text-primary hover:underline">
              All guides →
            </Link>
          </div>
          <div className="mt-6 grid gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
            {GUIDES.slice(0, 3).map((g) => (
              <Link
                key={g.slug}
                href={`/guides/${g.slug}/`}
                className="group rounded-2xl border-2 border-outline-variant bg-card p-5 shadow-[0_3px_0_0_var(--color-outline-variant)] transition hover:bg-surface-container active:translate-y-[2px]"
              >
                <span className="font-mono text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                  {g.tag} · {g.minutes} min
                </span>
                <h3 className="mt-2 text-[15px] font-bold leading-snug text-on-surface group-hover:underline">
                  {g.title}
                </h3>
              </Link>
            ))}
          </div>
        </Reveal>
      </section>

      {/* ============================================================ */}
      {/* FINAL CTA                                                    */}
      {/* ============================================================ */}
      <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
        <Reveal>
          <div className="final-cta">
            <div className="final-cta-glow" />
            <div className="relative">
              <RenanceMark size={56} inverse />
              <h2 className="mx-auto mt-5 max-w-2xl text-2xl font-bold tracking-tight text-white sm:text-4xl">
                Your competition started revising yesterday.
              </h2>
              <p className="mx-auto mt-3 max-w-lg text-[15px] leading-relaxed text-white/75">
                Create a free account and sit your first server-graded paper in the next two
                minutes, {fmt(totalQuestions)}+ past questions are waiting.
              </p>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-3.5">
                <Link
                  href="/register/"
                  className="hero-cta-secondary !border-white/25 !bg-white/10 !text-white hover:!bg-white/20"
                >
                  Create free account
                </Link>
                <OpenAppButton className="hero-cta-primary hero-cta-white !bg-white !bg-none !text-[#111c2d]" />
              </div>
              <p className="mt-5 font-mono text-xs text-white/50">
                Android · iOS · Windows · macOS · Web
              </p>
            </div>
          </div>
        </Reveal>
      </section>

      {/* ============================================================ */}
      {/* FOOTER                                                       */}
      {/* ============================================================ */}
      <footer className="landing-footer">
        <div className="mx-auto grid w-full max-w-6xl grid-cols-2 gap-8 px-4 py-10 sm:grid-cols-4 sm:px-6">
          <div className="col-span-2 sm:col-span-1">
            <RenanceMark size={28} />
            <p className="mt-3 text-xs leading-relaxed text-on-surface-variant">
              Your Guide to Academic Success. Built by Resolute Femi (Ariyo Oluwafemi Stephen).
            </p>
          </div>
          <nav aria-label="Study">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              Study
            </h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li>
                <Link href="/practice/jamb/" className="hover:underline">
                  JAMB past questions
                </Link>
              </li>
              <li>
                <Link href="/practice/waec/" className="hover:underline">
                  WAEC past questions
                </Link>
              </li>
              <li>
                <Link href="/practice/neco/" className="hover:underline">
                  NECO past questions
                </Link>
              </li>
              <li>
                <Link href="/practice/post-utme/" className="hover:underline">
                  Post-UTME past questions
                </Link>
              </li>
              <li>
                <Link href="/curriculum/" className="hover:underline">
                  NERDC scheme of work
                </Link>
              </li>
              <li>
                <Link href="/subjects/" className="hover:underline">
                  Subjects &amp; syllabus
                </Link>
              </li>
            </ul>
          </nav>
          <nav aria-label="Product">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              Product
            </h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li>
                <Link href="/register/" className="hover:underline">
                  Create account
                </Link>
              </li>
              <li>
                <Link href="/register/?audience=school" className="hover:underline">
                  Register a school
                </Link>
              </li>
              <li>
                <Link href="/school/check/" className="hover:underline">
                  Check a result PIN
                </Link>
              </li>
              <li>
                <Link href="/exams/setup/" className="hover:underline">
                  Mock exam setup
                </Link>
              </li>
              <li>
                <Link href="/for-schools/" className="hover:underline">
                  For Schools
                </Link>
              </li>
              <li>
                <Link href="/about/" className="hover:underline">
                  About Renance
                </Link>
              </li>
              <li>
                <Link href="/faq/" className="hover:underline">
                  FAQ
                </Link>
              </li>
            </ul>
          </nav>
          <nav aria-label="Company">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              Company
            </h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li>
                <Link href="/lessons/" className="hover:underline">
                  Lessons library
                </Link>
              </li>
              <li>
                <Link href="/flashcards/" className="hover:underline">
                  Flashcards
                </Link>
              </li>
              <li>
                <Link href="/guides/" className="hover:underline">
                  Exam guides
                </Link>
              </li>
              <li>
                <Link href="/educational-app-in-nigeria/" className="hover:underline">
                  Educational app guide
                </Link>
              </li>
              <li>
                <a
                  href="https://renance-api.onrender.com/healthz"
                  className="hover:underline"
                  rel="noopener"
                >
                  Service status
                </a>
              </li>
            </ul>
          </nav>
        </div>
        <p className="pb-8 text-center font-mono text-xs text-on-surface-variant">
          © {new Date().getFullYear()} Renance · built for students, free forever
        </p>
      </footer>
    </div>
  );
}
