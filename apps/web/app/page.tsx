import type { Metadata } from 'next';
import Link from 'next/link';
import { loadLessons, loadManifest } from '@/lib/site-data';
import OpenAppButton from '@/components/open-app-button';
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
 * The public landing page - "Your Guide to Academic Success".
 *
 * Built to feel alive: an aurora gradient field drifts behind frosted
 * glass panels, feature tiles lift on hover, stats count in on scroll
 * and an exam-pack ticker runs under the hero. Everything above the
 * fold is still static HTML with structured data (SEO doctrine), the
 * client components only add motion and never gate content.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  openGraph: { url: SITE_URL },
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
    title: 'Spaced review that plans itself',
    body: 'Topics you miss enter an SM-2 spaced-repetition queue and return exactly when you would forget them. Clear the queue, keep the knowledge, no planner to maintain.',
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
  const allYears = exams.flatMap((e) => e.years ?? []);
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
      <MotionPrefs>
        <LandingNav />
      </MotionPrefs>

      {/* ============================================================ */}
      {/* HERO - aurora field, gradient headline, floating glass       */}
      {/* ============================================================ */}
      <section className="relative flex min-h-[100svh] flex-col justify-center overflow-hidden pb-16 pt-32 sm:pt-36">
        <AuroraField />

        <div className="relative z-10 mx-auto w-full max-w-6xl px-4 sm:px-6">
          {/* floating glass cards - desktop only, orbit the copy */}
          <div className="pointer-events-none absolute inset-0 hidden xl:block" aria-hidden>
            <div className="absolute left-0 top-[16%] hero-enter hero-enter-3">
              <FloatingCard
                tone="blue"
                icon="fact_check"
                title="Server-graded"
                body="87% avg. score improvement"
                delay={900}
              />
            </div>
            <div className="absolute right-0 top-[24%] hero-enter hero-enter-4">
              <FloatingCard
                tone="emerald"
                icon="event_repeat"
                title="Review queue"
                body="Plans itself while you sleep"
                delay={1100}
              />
            </div>
            <div className="absolute bottom-[12%] left-[6%] hero-enter hero-enter-5">
              <FloatingCard
                tone="amber"
                icon="record_voice_over"
                title="Voice flashcards"
                body="Drill hands-free, anywhere"
                delay={1300}
              />
            </div>
            <div className="absolute bottom-[20%] right-[4%] hero-enter hero-enter-5">
              <FloatingCard
                tone="blue"
                icon="workspace_premium"
                title={`${fmt(totalQuestions)}+ questions`}
                body="Real papers, sealed keys"
                delay={1500}
              />
            </div>
          </div>

          <div className="mx-auto max-w-3xl text-center">
            <h1 className="hero-headline hero-enter hero-enter-1 text-on-surface">
              Your Guide to <span className="hero-gradient-text">Academic Success</span>
            </h1>

            <p className="hero-enter hero-enter-2 mx-auto mt-6 max-w-2xl text-[15px] leading-relaxed text-on-surface-variant sm:text-lg">
              {fmt(totalQuestions)}+ real past questions from {yearFrom} to {yearTo}, server-graded
              CBT mocks, a review queue that plans itself, voice flashcards and the JAMB novel built
              in. And for schools: a full portal with syllabuses, notes, attendance and PIN-secured
              results. Free, on Android, iOS, Windows, macOS and the web.
            </p>

            <div className="hero-enter hero-enter-3 mt-9 flex flex-wrap items-center justify-center gap-3.5">
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

          {/* floating cards on mobile/tablet - inline strip */}
          <div className="mt-12 grid grid-cols-2 gap-3 sm:grid-cols-4 xl:hidden">
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
              body="Plans itself"
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

        {/* exam-pack ticker */}
        {tickerItems.length > 0 && (
          <div className="hero-enter hero-enter-5 relative z-10 mt-14">
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
      <section className="mx-auto w-full max-w-6xl px-4 pt-20 sm:px-6">
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
                className="shrink-0 text-sm font-semibold text-white underline underline-offset-4 hover:text-white/80"
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
                  body: 'University',
                  count: sum(uniExams),
                  packs: uniExams.length,
                  note: 'per-school course banks, more landing',
                },
              ].map((b) => (
                <div
                  key={b.body}
                  className="rounded-2xl bg-white/[0.06] p-5 ring-1 ring-white/10 backdrop-blur-sm transition hover:bg-white/[0.1]"
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
                  className="rounded-full bg-white px-6 py-3 text-sm font-semibold text-[#111c2d] transition hover:bg-white/90"
                >
                  Register your school
                </Link>
                <Link
                  href="/school/check/"
                  className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white transition hover:bg-white/10"
                >
                  Check a result PIN
                </Link>
              </div>
            </div>

            <div className="mt-9 grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
              {SCHOOL_FEATURES.map((f) => (
                <div
                  key={f.title}
                  className="rounded-2xl bg-white/[0.06] p-5 ring-1 ring-white/10 backdrop-blur-sm transition hover:bg-white/[0.1]"
                >
                  <span
                    className="material-symbols-outlined flex h-10 w-10 items-center justify-center rounded-xl bg-white text-[#111c2d]"
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
                      className="rounded-xl bg-white/[0.06] px-2 py-2.5 text-center text-[11px] font-semibold text-white/75 ring-1 ring-white/10"
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
                <OpenAppButton className="hero-cta-primary !bg-white !bg-none !text-[#111c2d]" />
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
                <Link href="/lessons/" className="hover:underline">
                  Lessons
                </Link>
              </li>
              <li>
                <Link href="/subjects/" className="hover:underline">
                  Subjects &amp; syllabus
                </Link>
              </li>
              <li>
                <Link href="/flashcards/" className="hover:underline">
                  Flashcards
                </Link>
              </li>
              <li>
                <Link href="/packs/" className="hover:underline">
                  Question packs
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
                <a
                  href="https://github.com/Resolutefemi/Renance"
                  className="hover:underline"
                  rel="noopener"
                >
                  GitHub
                </a>
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
