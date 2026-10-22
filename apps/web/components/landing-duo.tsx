'use client';

import { useEffect, useState, type CSSProperties } from 'react';
import Link from 'next/link';
import LandingDefaultTheme from '@/components/landing-default-theme';
import OpenAppButton from '@/components/open-app-button';
import { RenanceMark } from '@/components/renance-logo';
import { STORE_CONFIG } from '@/lib/store-links';

/**
 * The full duolingo.com-style landing (founder directive 2026-10-22:
 * navbar, transitions and animations "exactly the same"). Structure,
 * per section, top to bottom:
 *
 *   1. sticky navbar  - wordmark left, GET THE APP right, shadow on scroll
 *   2. hero           - floating subject chips + bobbing keycap mascot,
 *                       stacked GET STARTED / I ALREADY HAVE AN ACCOUNT
 *   3. subject marquee- seamless infinite scroll, pauses on hover
 *   4. headline+phones- giant slogan, trust numbers, two CSS phones,
 *                       store badge
 *   5. feature trio   - EFFECTIVE / PERSONALIZED / FUN
 *   6. stories        - arrow-driven auto-advancing carousel + dots
 *   7. CTA band       - full-bleed brand green
 *   8. mega footer    - navy, four link columns, socials
 *
 * All copy and artwork are Renance originals; only the interaction
 * patterns (3D press physics, marquee loop, reveal-on-scroll, carousel)
 * mirror the reference. Everything SSR-renders for SEO; the h1 stays
 * sr-only exactly like the previous pass.
 */

const cssVars = (o: Record<string, string>) => o as CSSProperties;

const WHATSAPP_CHANNEL = 'https://whatsapp.com/channel/0029VbDnzhVKAwEltcgbOZ3K';

/* ------------------------------------------------------------------ */
/* Data                                                                */
/* ------------------------------------------------------------------ */

type Chip = {
  word: string;
  tag: string;
  color: string;
  className: string;
  dur: string;
  delay: string;
  rot: string;
};

const HERO_CHIPS: Chip[] = [
  { word: 'Kinematics!', tag: 'PH', color: '#ce82ff', className: 'left-[4%] top-[17%] landing-chip-md', dur: '5.2s', delay: '0s', rot: '-4deg' },
  { word: 'Comprehension!', tag: 'EN', color: '#58cc02', className: 'right-[4%] top-[13%] landing-chip-lg', dur: '4.6s', delay: '.4s', rot: '3deg' },
  { word: 'Algebra!', tag: 'MT', color: '#1cb0f6', className: 'left-[7%] bottom-[26%] landing-chip-lg', dur: '6s', delay: '1.1s', rot: '2deg' },
  { word: 'Organic Chemistry!', tag: 'CH', color: '#ff9600', className: 'right-[5%] bottom-[31%] landing-chip-md', dur: '5.6s', delay: '.8s', rot: '-3deg' },
  { word: 'Essay Writing!', tag: 'LI', color: '#ff86d0', className: 'left-[14%] top-[46%] landing-chip-xl', dur: '4.9s', delay: '.2s', rot: '4deg' },
  { word: 'Demand & Supply!', tag: 'EC', color: '#ffc800', className: 'right-[13%] top-[48%] landing-chip-xl', dur: '5.4s', delay: '.6s', rot: '-2deg' },
];

type Subject = { name: string; tag: string; color: string };

const SUBJECTS: Subject[] = [
  { name: 'English', tag: 'EN', color: '#58cc02' },
  { name: 'Mathematics', tag: 'MT', color: '#1cb0f6' },
  { name: 'Physics', tag: 'PH', color: '#ce82ff' },
  { name: 'Chemistry', tag: 'CH', color: '#ff9600' },
  { name: 'Biology', tag: 'BI', color: '#00cd9c' },
  { name: 'Economics', tag: 'EC', color: '#ffc800' },
  { name: 'Government', tag: 'GV', color: '#ff4b4b' },
  { name: 'Literature', tag: 'LI', color: '#ff86d0' },
  { name: 'Geography', tag: 'GE', color: '#2bb3a3' },
  { name: 'Commerce', tag: 'CO', color: '#8549ba' },
  { name: 'Accounting', tag: 'AC', color: '#4b9b69' },
  { name: 'Agric Science', tag: 'AG', color: '#8ee000' },
  { name: 'CRK', tag: 'CR', color: '#f49000' },
  { name: 'French', tag: 'FR', color: '#3f7df6' },
  { name: 'Yoruba', tag: 'YO', color: '#a560d8' },
  { name: 'Further Maths', tag: 'FM', color: '#00a4ad' },
];

const FEATURES = [
  {
    word: 'EFFECTIVE',
    color: '#58cc02',
    icon: 'trophy' as const,
    body: 'Every mock is graded on the server against sealed answer keys, so your score is the real thing, not a guess. Missed topics come back through a spaced-repetition queue right before you would forget them. Over 288,500 past questions from 1978 to today are ready to drill.',
  },
  {
    word: 'PERSONALIZED',
    color: '#1cb0f6',
    icon: 'target' as const,
    body: 'Renance watches how you learn, not just what you answer. Fatigue-aware sessions ease up when your pace collapses, and your course map rebuilds itself around the topics that need the most reps. No two students study the same path, and that is the point.',
  },
  {
    word: 'FUN',
    color: '#ff9600',
    icon: 'flame' as const,
    body: 'Keep a streak alive, climb the diamond league, win gems and challenge a friend in the live arena. Daily quests and a community feed turn revision into something you actually want to open. Progress should feel like play, and here it finally does.',
  },
] as const;

const STORIES = [
  {
    quote:
      'I went from a D in Chemistry to an A in one term. The corrections reader shows me exactly why every option I picked was wrong, so the same trap never catches me twice.',
    name: 'Chidinma',
    detail: 'SS3 student, Lagos',
  },
  {
    quote:
      'The streak keeps me honest. Twenty questions a day on the way to school and my JAMB mock score jumped by 40 marks. The freezes saved me when NEPA took our light for a week.',
    name: 'Emeka',
    detail: 'JAMB candidate, Enugu',
  },
  {
    quote:
      'Borrowing courses from other departments filled the gaps my school timetable left. Then the arena made it a real competition - my friends and I now battle every evening.',
    name: 'Fatima',
    detail: 'Science student, Kano',
  },
  {
    quote:
      'Post-UTME past questions for my school, graded instantly with full explanations. I walked into the hall knowing exactly what to expect, and it showed in my score.',
    name: 'Yusuf',
    detail: 'Post-UTME candidate, Oyo',
  },
] as const;

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
  {
    heading: 'Subjects',
    links: [
      { href: '/subjects/', label: 'English' },
      { href: '/subjects/', label: 'Mathematics' },
      { href: '/subjects/', label: 'Physics' },
      { href: '/subjects/', label: 'Chemistry' },
      { href: '/subjects/', label: 'Biology' },
      { href: '/subjects/', label: 'Economics' },
    ],
  },
] as const;

/* ------------------------------------------------------------------ */
/* Inline SVG icons (no icon-font dependency on this page)             */
/* ------------------------------------------------------------------ */

function TrophyIcon() {
  return (
    <svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0V4Z" />
      <path d="M7 6H4a1 1 0 0 0-1 1c0 2.2 1.8 4 4 4M17 6h3a1 1 0 0 1 1 1c0 2.2-1.8 4-4 4" />
    </svg>
  );
}

function TargetIcon() {
  return (
    <svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="5" />
      <circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none" />
    </svg>
  );
}

function FlameIcon() {
  return (
    <svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 3c1 3-2.5 4.5-2.5 8A4.5 4.5 0 0 0 14 15.5c2-.5 3.5-2.2 3-4.5 2 1.6 3 3.6 3 5.5A7.5 7.5 0 0 1 4.5 16C4.5 10.5 10 8.5 12 3Z" />
    </svg>
  );
}

function PlayStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden>
      <path d="M4 3.5v17a1 1 0 0 0 1.52.86l13.8-8.5a1 1 0 0 0 0-1.72L5.52 2.64A1 1 0 0 0 4 3.5Z" />
    </svg>
  );
}

function ChevronLeft() {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M15 5l-7 7 7 7" />
    </svg>
  );
}

function ChevronRight() {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M9 5l7 7-7 7" />
    </svg>
  );
}

function XSocialIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden>
      <path d="M17.9 3H21l-6.8 7.8L22.2 21h-6.3l-4.9-6.4L5.4 21H2.2l7.3-8.3L2 3h6.4l4.4 5.9L17.9 3Zm-1.1 16h1.7L7.6 4.9H5.8L16.8 19Z" />
    </svg>
  );
}

function GitHubIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden>
      <path d="M12 2a10 10 0 0 0-3.2 19.5c.5.1.7-.2.7-.5v-1.8c-2.8.6-3.4-1.2-3.4-1.2-.4-1.1-1.1-1.5-1.1-1.5-.9-.6.1-.6.1-.6 1 .1 1.5 1 1.5 1 .9 1.6 2.4 1.1 3 .9.1-.7.4-1.1.6-1.4-2.2-.3-4.6-1.1-4.6-5A3.9 3.9 0 0 1 6.7 8.7a3.6 3.6 0 0 1 .1-2.7s.9-.3 2.8 1a9.4 9.4 0 0 1 5 0c1.9-1.3 2.8-1 2.8-1 .5 1.4.2 2.4.1 2.7a3.9 3.9 0 0 1 1 2.7c0 3.9-2.4 4.7-4.6 5 .4.3.7.9.7 1.9V21c0 .3.2.6.7.5A10 10 0 0 0 12 2Z" />
    </svg>
  );
}

function WhatsAppIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden>
      <path d="M12 2a9.9 9.9 0 0 0-8.6 14.9L2 22l5.3-1.4A10 10 0 1 0 12 2Zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-3.1.8.8-3-.2-.3A8.2 8.2 0 1 1 12 20.2Zm4.6-6.1c-.3-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1-.2.3-.6.8-.8 1-.1.2-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4 0-.5.2-.7l.5-.6c.1-.2 0-.4 0-.5L9.6 7.6c-.2-.5-.4-.4-.6-.4h-.5c-.2 0-.5.1-.7.3-.9.9-.7 2.1.1 3.5a11.6 11.6 0 0 0 4.4 4.1c1.7.8 2.5.8 3.3.7.5-.1 1.5-.6 1.7-1.2.2-.6.2-1.1.1-1.2 0-.1-.2-.2-.5-.3Z" />
    </svg>
  );
}

function FeatureGlyph({ icon }: { icon: 'trophy' | 'target' | 'flame' }) {
  if (icon === 'trophy') return <TrophyIcon />;
  if (icon === 'target') return <TargetIcon />;
  return <FlameIcon />;
}

/* ------------------------------------------------------------------ */
/* Component                                                           */
/* ------------------------------------------------------------------ */

export default function LandingDuo() {
  const [scrolled, setScrolled] = useState(false);
  const [story, setStory] = useState(0);
  const [paused, setPaused] = useState(false);

  /* Navbar shadow appears the moment the page moves, like the
     reference. */
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  /* Reveal-on-scroll: sections slide up once as they enter. */
  useEffect(() => {
    const els = document.querySelectorAll('.landing-reveal');
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-in');
            io.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.15 },
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  /* Carousel auto-advance, paused on hover / focus. */
  useEffect(() => {
    if (paused) return;
    const timer = window.setInterval(() => {
      setStory((i) => (i + 1) % STORIES.length);
    }, 6500);
    return () => window.clearInterval(timer);
  }, [paused]);

  return (
    <div className="min-h-dvh bg-background">
      <LandingDefaultTheme />

      {/* ============================================================ */}
      {/* 1. STICKY NAVBAR                                             */}
      {/* ============================================================ */}
      <header
        className={`landing-nav sticky top-0 z-40 bg-background/95 backdrop-blur ${scrolled ? 'landing-nav-scrolled' : ''}`}
      >
        <div className="mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-3 sm:px-6">
          <Link href="/" className="flex items-center gap-2" aria-label="Renance home">
            <RenanceMark size={34} />
            <span className="text-[22px] font-extrabold lowercase leading-none tracking-tight text-on-surface">
              renance
            </span>
          </Link>
          <nav className="flex items-center gap-4 sm:gap-6">
            <Link
              href="/subjects/"
              className="hidden text-xs font-extrabold uppercase tracking-widest text-on-surface-variant hover:text-on-surface md:block"
            >
              Subjects
            </Link>
            <Link href="/register/" className="btn-3d landing-nav-cta">
              Get the app
            </Link>
          </nav>
        </div>
      </header>

      <main>
        {/* ============================================================ */}
        {/* 2. HERO - floating chips + bobbing mascot + stacked CTAs      */}
        {/* ============================================================ */}
        <section className="relative mx-auto flex min-h-[86vh] w-full max-w-6xl flex-col items-center justify-center overflow-hidden px-4 py-16 text-center">
          <h1 className="sr-only">Renance - Your Guide to Academic Success</h1>

          {HERO_CHIPS.map((chip) => (
            <div
              key={chip.word}
              className={`landing-chip ${chip.className}`}
              style={cssVars({ '--rnt-dur': chip.dur, '--rnt-delay': chip.delay, '--rnt-rot': chip.rot })}
              aria-hidden
            >
              <span className="landing-chip-dot" style={{ background: chip.color }}>
                {chip.tag}
              </span>
              <span className="landing-chip-word">{chip.word}</span>
            </div>
          ))}

          <div className="landing-rise" style={cssVars({ '--rise-delay': '0s' })}>
            <div className="landing-mark-bob">
              <RenanceMark size={116} />
            </div>
          </div>

          <div className="landing-rise mt-9 flex w-full max-w-xs flex-col gap-3" style={cssVars({ '--rise-delay': '.15s' })}>
            <Link href="/register/" className="btn-3d w-full">
              Get started
            </Link>
            <Link href="/login/" className="btn-3d-blue w-full">
              I already have an account
            </Link>
            <OpenAppButton className="landing-open-app mt-1" />
          </div>
        </section>

        {/* ============================================================ */}
        {/* 3. SUBJECT MARQUEE - seamless infinite loop                   */}
        {/* ============================================================ */}
        <section className="landing-marquee w-full pb-14" aria-label="Subjects on Renance">
          <div className="landing-marquee-track">
            {[0, 1].map((copy) => (
              <div key={copy} className="flex gap-4 pr-4" aria-hidden={copy === 1}>
                {SUBJECTS.map((s) => (
                  <div key={`${copy}-${s.name}`} className="landing-flag">
                    <span className="landing-flag-tile" style={{ background: s.color }}>
                      {s.tag}
                    </span>
                    <span className="landing-flag-name">{s.name}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </section>

        {/* ============================================================ */}
        {/* 4. HEADLINE + PHONES + STORE BADGE                            */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-6xl px-4 pb-20 text-center sm:px-6">
          <h2
            className="landing-reveal mx-auto max-w-4xl text-[clamp(2.2rem,6vw,4.2rem)] font-extrabold leading-[1.05] tracking-tight text-on-surface"
          >
            The free, fun, and effective way to smash your exams!
          </h2>
          <p
            className="landing-reveal mx-auto mt-5 flex max-w-2xl flex-wrap items-center justify-center gap-x-2 gap-y-1 text-[15px] font-bold text-on-surface-variant"
            style={cssVars({ '--reveal-delay': '.1s' })}
          >
            <span>288,500+ past questions</span>
            <span aria-hidden>·</span>
            <span>10,000+ courses</span>
            <span aria-hidden>·</span>
            <span>2,000,000+ topics</span>
            <span aria-hidden>·</span>
            <span>100% free</span>
          </p>

          <div className="landing-reveal mt-12 flex flex-wrap items-start justify-center gap-8" style={cssVars({ '--reveal-delay': '.15s' })}>
            {/* Phone 1 - live quiz */}
            <div className="landing-phone">
              <div className="landing-phone-notch" />
              <div className="space-y-2.5 p-3.5 text-left">
                <div className="landing-phone-row">
                  <span className="grid h-5 w-5 place-items-center rounded-md" style={{ background: '#ff9600', color: '#fff' }}>
                    <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" aria-hidden>
                      <path d="M12 3c1 3-2.5 4.5-2.5 8A4.5 4.5 0 0 0 14 15.5c2-.5 3.5-2.2 3-4.5 2 1.6 3 3.6 3 5.5A7.5 7.5 0 0 1 4.5 16C4.5 10.5 10 8.5 12 3Z" />
                    </svg>
                  </span>
                  <span>7 day streak</span>
                  <span className="ml-auto" style={{ color: '#1cb0f6' }}>1,240 gems</span>
                </div>
                <div className="h-2.5 w-full rounded-full bg-black/10">
                  <div className="h-2.5 w-2/3 rounded-full" style={{ background: '#58cc02' }} />
                </div>
                <p className="pt-1 text-[13px] font-extrabold leading-snug text-[#3c3c3c]">
                  A body at rest remains at rest unless acted upon by an external force. This is Newton&apos;s ______ law.
                </p>
                <div className="landing-quiz-option">First</div>
                <div className="landing-quiz-option is-right">Second</div>
                <div className="landing-quiz-option">Third</div>
                <div className="landing-quiz-option">Fourth</div>
              </div>
            </div>

            {/* Phone 2 - league */}
            <div className="landing-phone hidden sm:block">
              <div className="landing-phone-notch" />
              <div className="space-y-2.5 p-3.5 text-left">
                <div className="flex items-center gap-2 pt-1">
                  <span className="grid h-8 w-8 place-items-center rounded-xl" style={{ background: '#ffc800', color: '#fff' }}>
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0V4Z" />
                    </svg>
                  </span>
                  <p className="text-[13px] font-extrabold text-[#3c3c3c]">Diamond League</p>
                </div>
                {[
                  { n: '1', name: 'A. Okafor', pts: '2,410', c: '#ffc800' },
                  { n: '2', name: 'T. Bello', pts: '2,180', c: '#c0c8d0' },
                  { n: '3', name: 'M. Musa', pts: '1,965', c: '#e2985b' },
                ].map((row) => (
                  <div key={row.n} className="landing-quiz-option justify-between">
                    <span className="flex items-center gap-2">
                      <span className="grid h-6 w-6 place-items-center rounded-lg text-[11px] font-extrabold text-white" style={{ background: row.c }}>
                        {row.n}
                      </span>
                      {row.name}
                    </span>
                    <span style={{ color: '#1cb0f6' }}>{row.pts}</span>
                  </div>
                ))}
                <p className="pt-1 text-center text-[11px] font-bold text-[#777]">Top 10 promote every Sunday</p>
              </div>
            </div>
          </div>

          <div className="landing-reveal mt-10" style={cssVars({ '--reveal-delay': '.2s' })}>
            <a href={STORE_CONFIG.playStoreUrl} target="_blank" rel="noopener" className="landing-store-badge">
              <PlayStoreIcon />
              <span className="text-left leading-tight">
                <span className="block text-[10px] font-bold uppercase tracking-widest opacity-80">Get it on</span>
                <span className="block text-base font-extrabold">Google Play</span>
              </span>
            </a>
          </div>
        </section>

        {/* ============================================================ */}
        {/* 5. FEATURE TRIO - EFFECTIVE / PERSONALIZED / FUN              */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-6xl px-4 pb-20 sm:px-6">
          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {FEATURES.map((f, i) => (
              <article
                key={f.word}
                className="landing-reveal rounded-[22px] border-2 border-outline-variant bg-card p-6 text-left"
                style={cssVars({ '--reveal-delay': `${i * 0.09}s` })}
              >
                <span
                  className="grid h-14 w-14 place-items-center rounded-2xl text-white"
                  style={{ background: f.color, boxShadow: 'inset 0 -3px 0 rgba(0,0,0,.15)' }}
                >
                  <FeatureGlyph icon={f.icon} />
                </span>
                <h3 className="mt-4 text-xl font-extrabold tracking-tight" style={{ color: f.color }}>
                  {f.word}
                </h3>
                <p className="mt-2 text-[14px] font-semibold leading-relaxed text-on-surface-variant">{f.body}</p>
              </article>
            ))}
          </div>
        </section>

        {/* ============================================================ */}
        {/* 6. STORIES CAROUSEL                                           */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-3xl px-4 pb-20 text-center sm:px-6">
          <h2 className="landing-reveal text-[clamp(1.7rem,4vw,2.6rem)] font-extrabold tracking-tight text-on-surface">
            Stories from students like you
          </h2>

          <div
            className="landing-reveal relative mt-8"
            style={cssVars({ '--reveal-delay': '.1s' })}
            onMouseEnter={() => setPaused(true)}
            onMouseLeave={() => setPaused(false)}
          >
            <div className="landing-carousel-viewport border-2 border-outline-variant bg-card">
              <div className="landing-carousel-track" style={{ transform: `translateX(-${story * 100}%)` }}>
                {STORIES.map((s) => (
                  <figure key={s.name} className="w-full flex-none px-7 py-9 text-left sm:px-10">
                    <blockquote className="text-[16px] font-semibold leading-relaxed text-on-surface">
                      &ldquo;{s.quote}&rdquo;
                    </blockquote>
                    <figcaption className="mt-4 flex items-center gap-3">
                      <span className="grid h-10 w-10 place-items-center rounded-full text-sm font-extrabold text-white" style={{ background: '#1cb0f6' }}>
                        {s.name.charAt(0)}
                      </span>
                      <span>
                        <span className="block text-sm font-extrabold text-on-surface">{s.name}</span>
                        <span className="block text-xs font-bold text-on-surface-variant">{s.detail}</span>
                      </span>
                    </figcaption>
                  </figure>
                ))}
              </div>
            </div>

            <button
              type="button"
              className="landing-carousel-arrow absolute -left-5 top-1/2 -translate-y-1/2"
              onClick={() => setStory((story - 1 + STORIES.length) % STORIES.length)}
              aria-label="Previous story"
            >
              <ChevronLeft />
            </button>
            <button
              type="button"
              className="landing-carousel-arrow absolute -right-5 top-1/2 -translate-y-1/2"
              onClick={() => setStory((story + 1) % STORIES.length)}
              aria-label="Next story"
            >
              <ChevronRight />
            </button>
          </div>

          <div className="mt-5 flex items-center justify-center gap-2">
            {STORIES.map((s, i) => (
              <button
                key={s.name}
                type="button"
                className={`landing-carousel-dot ${i === story ? 'is-active' : ''}`}
                onClick={() => setStory(i)}
                aria-label={`Go to story ${i + 1}`}
              />
            ))}
          </div>
        </section>

        {/* ============================================================ */}
        {/* 7. FINAL CTA BAND                                             */}
        {/* ============================================================ */}
        <section className="landing-cta-band w-full px-4 py-16 text-center sm:px-6">
          <h2 className="landing-reveal mx-auto max-w-2xl text-[clamp(1.8rem,4.5vw,3rem)] font-extrabold leading-tight tracking-tight text-white">
            Your best score starts today
          </h2>
          <p className="landing-reveal mx-auto mt-3 max-w-xl text-[15px] font-bold text-white/90" style={cssVars({ '--reveal-delay': '.08s' })}>
            Join the students turning past questions into distinctions - free forever, no card required.
          </p>
          <div className="landing-reveal mt-7" style={cssVars({ '--reveal-delay': '.16s' })}>
            <Link
              href="/register/"
              className="inline-flex items-center justify-center rounded-2xl bg-white px-8 py-3.5 text-[15px] font-extrabold uppercase tracking-wide shadow-[0_4px_0_rgba(0,0,0,0.18)] transition-all hover:brightness-95 active:translate-y-1 active:shadow-none"
              style={{ color: 'var(--color-primary)' }}
            >
              Get started
            </Link>
          </div>
        </section>
      </main>

      {/* ============================================================ */}
      {/* 8. MEGA FOOTER                                                */}
      {/* ============================================================ */}
      <footer className="landing-footer w-full">
        <div className="mx-auto grid w-full max-w-6xl grid-cols-2 gap-8 px-4 py-14 sm:px-6 md:grid-cols-4">
          {FOOTER_COLUMNS.map((col) => (
            <nav key={col.heading} aria-label={col.heading}>
              <h3 className="text-xs font-extrabold uppercase tracking-widest">{col.heading}</h3>
              <ul className="mt-3 space-y-2 text-sm font-semibold">
                {col.links.map((l) => (
                  <li key={col.heading + l.label}>
                    {l.href.startsWith('http') ? (
                      <a href={l.href} rel="noopener" target="_blank">
                        {l.label}
                      </a>
                    ) : (
                      <Link href={l.href}>{l.label}</Link>
                    )}
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mx-auto flex w-full max-w-6xl flex-col items-center gap-5 px-4 pb-10 sm:px-6">
          <div className="flex items-center gap-3">
            <a href="https://x.com/Resolutefemi" target="_blank" rel="noopener" className="landing-social-chip" aria-label="Renance on X">
              <XSocialIcon />
            </a>
            <a href="https://github.com/Resolutefemi" target="_blank" rel="noopener" className="landing-social-chip" aria-label="Renance on GitHub">
              <GitHubIcon />
            </a>
            <a href={WHATSAPP_CHANNEL} target="_blank" rel="noopener" className="landing-social-chip" aria-label="Join the Renance WhatsApp channel">
              <WhatsAppIcon />
            </a>
            <a href={STORE_CONFIG.playStoreUrl} target="_blank" rel="noopener" className="landing-social-chip" aria-label="Get Renance on Google Play">
              <PlayStoreIcon />
            </a>
          </div>
          <p className="text-center text-xs font-semibold">
            © {new Date().getFullYear()} Renance · Your Guide to Academic Success · built for students, free forever
          </p>
        </div>
      </footer>
    </div>
  );
}
