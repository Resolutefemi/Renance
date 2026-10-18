import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import { loadManifest } from '@/lib/site-data';
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
 * The public landing page. Punchy by founder directive 2026-10-18:
 * the motto "Your Guide to Academic Success" anchors the hero again
 * (and repeats small in the navbar), the description is the
 * founder-written platform copy, and the page carries only the
 * sections that match the product today - no archive panel, no
 * schools mega-panel, no Lekki/flashcards cards, no lessons preview.
 * Dark card backgrounds are banned on this page.
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
    icon: 'battery_saver',
    tone: 'amber',
    glow: 'rgba(245,158,11,0.18)',
    title: 'Fatigue-aware sessions',
    body: 'Renance notices when your answer pace collapses and nudges you to take five, because tired practice teaches the wrong lessons.',
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

// The For Schools story lives on /for-schools now (founder directive
// 2026-10-18: the landing page stays punchy, the deep school tour is
// one click away in the footer).

function fmt(n: number): string {
  return n.toLocaleString('en-US');
}

/* The founder's public numbers (2026-10-18 copy directive). The old
   landing computed its own counts from the bundle manifest and always
   read stale next to the real catalogue. */
const PAST_QUESTIONS = 288500;
const COURSES = 10000;
const TOPICS = 2000000;

export default function Landing() {
  const manifest = loadManifest();
  const exams = manifest?.exams ?? [];

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
                Renance: Your Guide to <span className="hero-gradient-text">Academic Success</span>
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
                    <span className="font-mono text-[11px] text-on-surface-variant">1978-2025</span>
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
          <div className="mt-10 grid grid-cols-2 gap-3 sm:mt-12 sm:grid-cols-3">
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
              tone="blue"
              icon="workspace_premium"
              title={`${fmt(PAST_QUESTIONS)}+ questions`}
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
      {/* STATS BAND - the founder's public numbers                     */}
      {/* ============================================================ */}
      <section className="relative z-10 mx-auto -mt-2 w-full max-w-6xl px-4 sm:px-6">
        <Reveal>
          <dl className="grid grid-cols-2 gap-3.5 sm:gap-4 lg:grid-cols-4">
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                <CountUp to={PAST_QUESTIONS} suffix="+" />
              </dd>
              <dt className="stat-label">Past questions</dt>
            </div>
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                <CountUp to={COURSES} suffix="+" />
              </dd>
              <dt className="stat-label">Courses</dt>
            </div>
            <div className="stat-glass glass-hover">
              <dd className="stat-value">
                <CountUp to={TOPICS} suffix="+" />
              </dd>
              <dt className="stat-label">Topics</dt>
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
              <RenanceMark size={56} />
              <h2 className="mx-auto mt-5 max-w-2xl text-2xl font-bold tracking-tight text-on-surface sm:text-4xl">
                Your competition started revising yesterday.
              </h2>
              <p className="mx-auto mt-3 max-w-lg text-[15px] leading-relaxed text-on-surface-variant">
                Create a free account and sit your first server-graded paper in the next two
                minutes, {fmt(PAST_QUESTIONS)}+ past questions are waiting.
              </p>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-3.5">
                <Link href="/register/" className="hero-cta-secondary">
                  Create free account
                </Link>
                <OpenAppButton className="hero-cta-primary" />
              </div>
              <p className="mt-5 font-mono text-xs text-on-surface-variant">
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
