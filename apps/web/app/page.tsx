import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';
import OpenAppButton from '@/components/open-app-button';
import LandingDefaultTheme from '@/components/landing-default-theme';
import { RenanceMark } from '@/components/renance-logo';

/**
 * The public landing page - Duolingo-style, Round 8 (founder directive:
 * "make the Renance landing page the same as theirs", referencing
 * duolingo.com/log-in). One minimal centered column: a slim wordmark
 * bar, a huge keycap mascot over the brand slogan, two stacked chunky
 * 3D buttons, a plain trust row, a compact feature strip and a slim
 * one-row footer. No aurora, no glass, no marquee - the old motion
 * helpers in components/landing-motion.tsx are retired with the
 * redesign and the page is now a fully static server component (the
 * only client islands are LandingDefaultTheme and OpenAppButton).
 *
 * Everything above the fold is still static HTML with the same
 * structured data (SEO doctrine). "Renance" stays in an sr-only prefix
 * of the h1 so the brand name remains in the document outline; the
 * JSON-LD brand graph in app/layout.tsx carries the full entity.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://renance.app';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  openGraph: { url: SITE_URL, images: [...OG_IMAGES] },
};

/* The founder's public numbers (2026-10-18 copy directive). */
const PAST_QUESTIONS = 288500;
const COURSES = 10000;
const TOPICS = 2000000;

/* Compact value strip - icon + title + one line. Icon names are the
   same three glyphs the old landing used (already in the Material
   Symbols subset, so the icon coverage check stays green). */
const FEATURES = [
  {
    icon: 'fact_check',
    title: 'Server-graded papers',
    body: 'Every mock is marked on the server with sealed answer keys.',
  },
  {
    icon: 'event_repeat',
    title: 'Missed topics return',
    body: 'A spaced-repetition queue brings them back before you forget.',
  },
  {
    icon: 'battery_saver',
    title: 'Fatigue-aware sessions',
    body: 'Renance notices when your pace collapses and nudges you to rest.',
  },
] as const;

function fmt(n: number): string {
  return n.toLocaleString('en-US');
}

/* Slim one-row footer: Product / Company / Support. Every href the old
   footer carried survives here, redistributed across the three columns. */
const FOOTER_COLUMNS = [
  {
    heading: 'Product',
    links: [
      { href: '/register/', label: 'Create account' },
      { href: '/register/?audience=school', label: 'Register a school' },
      { href: '/exams/setup/', label: 'Mock exam setup' },
      { href: '/school/check/', label: 'Check a result PIN' },
      { href: '/practice/jamb/', label: 'JAMB past questions' },
      { href: '/practice/waec/', label: 'WAEC past questions' },
      { href: '/practice/neco/', label: 'NECO past questions' },
      { href: '/practice/post-utme/', label: 'Post-UTME past questions' },
    ],
  },
  {
    heading: 'Company',
    links: [
      { href: '/about/', label: 'About Renance' },
      { href: '/for-schools/', label: 'For Schools' },
      { href: '/lessons/', label: 'Lessons library' },
      { href: '/guides/', label: 'Exam guides' },
      { href: '/educational-app-in-nigeria/', label: 'Educational app guide' },
      { href: 'https://renance-api.onrender.com/healthz', label: 'Service status' },
    ],
  },
  {
    heading: 'Support',
    links: [
      { href: '/faq/', label: 'FAQ' },
      { href: '/subjects/', label: 'Subjects & syllabus' },
      { href: '/curriculum/', label: 'NERDC scheme of work' },
    ],
  },
] as const;

export default function Landing() {
  return (
    <div className="min-h-dvh bg-background">
      {/* The landing keeps the DEFAULT Renance palette - a student's
          Appearance seed repaints every other surface, never this one
          (founder directive 2026-10-05). Renders nothing; the effect
          strips the seed keys from <html> on arrival and restores them
          on the way out. */}
      <LandingDefaultTheme />

      {/* ============================================================ */}
      {/* TOP BAR - keycap + lowercase wordmark left, quiet Sign in     */}
      {/* ============================================================ */}
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between px-4 py-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2" aria-label="Renance home">
          <RenanceMark size={34} />
          <span className="text-[22px] font-extrabold lowercase leading-none tracking-tight text-on-surface">
            renance
          </span>
        </Link>
        <Link
          href="/login/"
          className="rounded-xl px-3 py-2 text-sm font-extrabold uppercase tracking-wide text-primary underline-offset-4 hover:underline"
        >
          Sign in
        </Link>
      </header>

      <main>
        {/* ============================================================ */}
        {/* HERO - Duolingo-minimal centered column                       */}
        {/* ============================================================ */}
        <section className="mx-auto flex min-h-[70vh] w-full max-w-md flex-col items-center justify-center px-4 pb-14 pt-8 text-center">
          <RenanceMark size={120} />

          <p className="mt-7 text-xs font-extrabold uppercase tracking-[0.2em] text-primary-ink">
            JAMB · WAEC · NECO · POST-UTME
          </p>

          <h1 className="mt-3 text-[clamp(2.5rem,7vw,4.5rem)] font-extrabold leading-[1.02] tracking-tight text-on-surface">
            <span className="sr-only">Renance: </span>
            Your Guide to Academic Success
          </h1>

          <p className="mt-4 max-w-sm text-[15px] font-semibold leading-relaxed text-on-surface-variant sm:text-base">
            Practice real past questions, learn your syllabus and compete with friends - free
            forever.
          </p>

          {/* Stacked chunky 3D CTAs, the Duolingo login-page pattern */}
          <div className="mt-8 flex w-full max-w-xs flex-col gap-3">
            <Link href="/register/" className="btn-3d w-full">
              Get started
            </Link>
            <Link href="/login/" className="btn-3d-secondary w-full">
              I already have an account
            </Link>
            {/* OpenAppButton stays mounted as a quiet link: signed-in
                visitors still hop straight to the desk, logged-out ones
                get the same /register target as GET STARTED. */}
            <OpenAppButton className="landing-open-app mt-1" />
          </div>

          {/* Trust row - plain inline stats, no glass cards */}
          <p className="mt-9 flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-[13px] font-bold text-on-surface-variant">
            <span>{fmt(PAST_QUESTIONS)}+ past questions</span>
            <span aria-hidden>·</span>
            <span>{fmt(COURSES)}+ courses</span>
            <span aria-hidden>·</span>
            <span>{fmt(TOPICS)}+ topics</span>
          </p>
        </section>

        {/* ============================================================ */}
        {/* FEATURE STRIP - three minimal value props, icon + one line    */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-3xl px-4 pb-16 sm:px-6">
          <h2 className="sr-only">Why Renance</h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            {FEATURES.map((f) => (
              <article
                key={f.title}
                className="rounded-[20px] border-2 border-outline-variant bg-card p-4 text-left"
              >
                <span className="material-symbols-outlined text-[22px] text-primary" aria-hidden>
                  {f.icon}
                </span>
                <h3 className="mt-1.5 text-[15px] font-extrabold leading-snug text-on-surface">
                  {f.title}
                </h3>
                <p className="mt-1 text-[13px] leading-snug text-on-surface-variant">{f.body}</p>
              </article>
            ))}
          </div>
        </section>
      </main>

      {/* ============================================================ */}
      {/* FOOTER - slim single row: Product / Company / Support         */}
      {/* ============================================================ */}
      <footer className="border-t-2 border-outline-variant">
        <div className="mx-auto grid w-full max-w-5xl gap-8 px-4 py-10 sm:grid-cols-3 sm:px-6">
          {FOOTER_COLUMNS.map((col) => (
            <nav key={col.heading} aria-label={col.heading}>
              <h3 className="text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">
                {col.heading}
              </h3>
              <ul className="mt-3 space-y-2 text-sm font-semibold text-on-surface">
                {col.links.map((l) => (
                  <li key={l.href + l.label}>
                    {l.href.startsWith('http') ? (
                      <a href={l.href} className="hover:underline" rel="noopener">
                        {l.label}
                      </a>
                    ) : (
                      <Link href={l.href} className="hover:text-primary hover:underline">
                        {l.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>
        <p className="pb-8 text-center text-xs font-semibold text-on-surface-variant">
          © {new Date().getFullYear()} Renance · Your Guide to Academic Success · built for
          students, free forever
        </p>
      </footer>
    </div>
  );
}
