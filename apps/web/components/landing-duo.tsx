'use client';

import { useEffect, useState, type CSSProperties } from 'react';
import Link from 'next/link';
import LandingDefaultTheme from '@/components/landing-default-theme';
import OpenAppButton from '@/components/open-app-button';
import { RenanceMark } from '@/components/renance-logo';
import { STORE_CONFIG } from '@/lib/store-links';

/**
 * The full duolingo.com-style landing, v2 (founder screenshots pass
 * 2026-10-22: "do same to Renance"). Section journey, top to bottom:
 *
 *   1. navbar - THREE states, exactly like the reference: quiet text
 *      CTA at the very top, white + shadow + green 3D "GET THE APP"
 *      once scrolled, and the CTA swaps to "GET STARTED" past the hero
 *   2. hero   - original cartoon cast (Renny the bookworm + floating
 *      pencil/book/star/gem doodles) drifting between the navbar and
 *      the headline, with GET STARTED / I ALREADY HAVE AN ACCOUNT
 *      pinned near the bottom of the first viewport
 *   3. subject marquee - seamless infinite loop, pauses on hover
 *   4. "free. fun. effective." slogan + green phone with lesson
 *      progress bar
 *   5. "backed by results" + avatar phone + #1 medallion scene
 *   6. EFFECTIVE / PERSONALIZED / FUN trio
 *   7. stories carousel (arrows, dots, auto-advance)
 *   8. sky download band - App Store COMING SOON + Google Play live
 *   9. green CTA band, navy mega footer
 *
 * Every character, doodle and sentence is a Renance original drawn in
 * inline SVG; only the interaction patterns mirror the reference. All
 * sections SSR-render for SEO (sr-only h1 stays).
 */

const cssVars = (o: Record<string, string>) => o as CSSProperties;

const WHATSAPP_CHANNEL = 'https://whatsapp.com/channel/0029VbDnzhVKAwEltcgbOZ3K';

/* ------------------------------------------------------------------ */
/* Data                                                                */
/* ------------------------------------------------------------------ */

type Floater = {
  id: string;
  node: string; // doodle key
  className: string;
  dur: string;
  delay: string;
};

const FLOATERS: Floater[] = [
  { id: 'pencil', node: 'pencil', className: 'left-[5%] top-[16%]', dur: '5.1s', delay: '0s' },
  { id: 'book', node: 'book', className: 'right-[6%] top-[12%]', dur: '6.2s', delay: '.5s' },
  { id: 'star', node: 'star', className: 'left-[10%] bottom-[14%]', dur: '4.6s', delay: '.9s' },
  { id: 'gem', node: 'gem', className: 'right-[9%] bottom-[20%]', dur: '5.7s', delay: '.3s' },
  { id: 'flame', node: 'flame', className: 'left-[16%] top-[54%] landing-chip-lg', dur: '4.9s', delay: '.7s' },
  { id: 'sparkle', node: 'sparkle', className: 'right-[15%] top-[52%] landing-chip-lg', dur: '5.4s', delay: '.1s' },
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
/* Doodles - the original cartoon cast (inline SVG, zero deps)         */
/* ------------------------------------------------------------------ */

/** Renny - Renance's own study buddy: a green bookworm in graduation
    regalia with round glasses. Deliberately NOT an owl. */
function RennyMascot({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 240 240" className={className} aria-hidden focusable="false">
      {/* ground shadow */}
      <ellipse cx="120" cy="224" rx="60" ry="9" fill="#0f2830" opacity="0.08" />
      {/* feet */}
      <ellipse cx="96" cy="213" rx="17" ry="9" fill="#46a302" />
      <ellipse cx="144" cy="213" rx="17" ry="9" fill="#46a302" />
      {/* waving arms */}
      <ellipse cx="46" cy="148" rx="23" ry="11" fill="#58cc02" transform="rotate(-26 46 148)" />
      <ellipse cx="194" cy="148" rx="23" ry="11" fill="#58cc02" transform="rotate(26 194 148)" />
      {/* body */}
      <circle cx="120" cy="140" r="76" fill="#58cc02" />
      <ellipse cx="120" cy="166" rx="46" ry="37" fill="#8ee000" />
      {/* graduation cap */}
      <polygon points="120,26 194,56 120,86 46,56" fill="#0f2830" />
      <path d="M96 76v10c0 7 11 13 24 13s24-6 24-13V76l-24 10z" fill="#123c3c" opacity="0.35" />
      <path d="M194 58v36" stroke="#ffc800" strokeWidth="5" strokeLinecap="round" />
      <circle cx="194" cy="101" r="7" fill="#ffc800" />
      {/* glasses */}
      <circle cx="97" cy="124" r="22" fill="#ffffff" stroke="#0f2830" strokeWidth="6" />
      <circle cx="143" cy="124" r="22" fill="#ffffff" stroke="#0f2830" strokeWidth="6" />
      <path d="M113 120c4-4 10-4 14 0" stroke="#0f2830" strokeWidth="5" fill="none" strokeLinecap="round" />
      <circle cx="97" cy="126" r="7.5" fill="#1f2937" />
      <circle cx="100.5" cy="122.5" r="2.6" fill="#ffffff" />
      <circle cx="143" cy="126" r="7.5" fill="#1f2937" />
      <circle cx="146.5" cy="122.5" r="2.6" fill="#ffffff" />
      {/* smile + cheeks */}
      <path d="M103 160q17 14 34 0" stroke="#0f2830" strokeWidth="6" fill="none" strokeLinecap="round" />
      <ellipse cx="78" cy="148" rx="9" ry="5.5" fill="#ff9db5" opacity="0.8" />
      <ellipse cx="162" cy="148" rx="9" ry="5.5" fill="#ff9db5" opacity="0.8" />
    </svg>
  );
}

function PencilDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <g transform="rotate(-18 32 32)">
        <rect x="25" y="6" width="14" height="36" rx="4" fill="#ffc800" />
        <rect x="25" y="6" width="14" height="8" rx="4" fill="#ff9db5" />
        <rect x="25" y="14" width="14" height="4" fill="#e6a800" opacity="0.5" />
        <path d="M25 42h14l-7 14z" fill="#f7c98d" />
        <path d="M29.5 49l2.5 7 2.5-7z" fill="#0f2830" />
      </g>
    </svg>
  );
}

function BookDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <path
        d="M32 18c-6-5-14-6-22-4v34c8-2 16-1 22 4 6-5 14-6 22-4V14c-8-2-16-1-22 4z"
        fill="#ffffff"
        stroke="#0f2830"
        strokeWidth="4"
        strokeLinejoin="round"
      />
      <path d="M32 18v34" stroke="#0f2830" strokeWidth="4" strokeLinecap="round" />
      <path d="M16 26h8M16 34h8M40 26h8M40 34h8" stroke="#7ed4ff" strokeWidth="3.4" strokeLinecap="round" />
    </svg>
  );
}

function StarDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <path
        d="M32 5l7.8 16.8 18.4 2.4-13.5 12.7 3.5 18.2L32 46.4 15.8 55.1l3.5-18.2L5.8 24.2l18.4-2.4z"
        fill="#ffc800"
        stroke="#e6a800"
        strokeWidth="3"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function GemDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <path d="M20 10h24l13 16-25 30L7 26z" fill="#1cb0f6" stroke="#0f8fd6" strokeWidth="3" strokeLinejoin="round" />
      <path d="M7 26h50M20 10l12 16 12-16M32 26v30" stroke="#7ed4ff" strokeWidth="3" fill="none" strokeLinejoin="round" />
    </svg>
  );
}

function SparkleDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <path d="M32 4l6.5 21.5L60 32l-21.5 6.5L32 60l-6.5-21.5L4 32l21.5-6.5z" fill="#ce82ff" />
    </svg>
  );
}

function FlameDoodle({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden focusable="false">
      <path
        d="M32 6c3 9-7.5 13.5-7.5 24a13.5 13.5 0 0 0 13.5 13.5c6-1.5 10.5-6.6 9-13.5 6 4.8 9 10.8 9 16.5a22.5 22.5 0 0 1-45 0C11 27.5 26.5 21.5 32 6Z"
        fill="#ff9600"
        stroke="#e08600"
        strokeWidth="3"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function Doodle({ node, className }: { node: string; className?: string }) {
  if (node === 'pencil') return <PencilDoodle className={className} />;
  if (node === 'book') return <BookDoodle className={className} />;
  if (node === 'star') return <StarDoodle className={className} />;
  if (node === 'gem') return <GemDoodle className={className} />;
  if (node === 'flame') return <FlameDoodle className={className} />;
  return <SparkleDoodle className={className} />;
}

/** A simple smiley avatar for the "backed by results" phone screen. */
function AvatarFace({ bg }: { bg: string }) {
  return (
    <svg viewBox="0 0 64 64" className="h-full w-full" aria-hidden focusable="false">
      <circle cx="32" cy="32" r="30" fill={bg} />
      <circle cx="23" cy="28" r="4" fill="#1f2937" />
      <circle cx="41" cy="28" r="4" fill="#1f2937" />
      <path d="M24 40q8 7 16 0" stroke="#1f2937" strokeWidth="3.5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

/* ------------------------------------------------------------------ */
/* Small UI glyphs                                                     */
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

function FlameGlyph() {
  return (
    <svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 3c1 3-2.5 4.5-2.5 8A4.5 4.5 0 0 0 14 15.5c2-.5 3.5-2.2 3-4.5 2 1.6 3 3.6 3 5.5A7.5 7.5 0 0 1 4.5 16C4.5 10.5 10 8.5 12 3Z" />
    </svg>
  );
}

function FeatureGlyph({ icon }: { icon: 'trophy' | 'target' | 'flame' }) {
  if (icon === 'trophy') return <TrophyIcon />;
  if (icon === 'target') return <TargetIcon />;
  return <FlameGlyph />;
}

function PlayStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden>
      <path d="M4 3.5v17a1 1 0 0 0 1.52.86l13.8-8.5a1 1 0 0 0 0-1.72L5.52 2.64A1 1 0 0 0 4 3.5Z" />
    </svg>
  );
}

function AppleDoodle() {
  return (
    <svg viewBox="0 0 64 64" width="24" height="24" aria-hidden focusable="false">
      <path
        d="M32 16c6-8 16-8 20-2-8 2-10 8-9 13 7 1 11 8 9 15-2 9-9 16-15 16-3 0-4-2-5-2s-2 2-5 2c-6 0-13-7-15-16-2-7 2-14 9-15 1-5-1-11-9-13 4-6 14-6 20 2z"
        fill="#ffffff"
      />
      <path d="M32 13c0-6 4-9 9-10-1 6-4 9-9 10z" fill="#ffffff" />
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

export default function LandingDuo() {
  /* THREE navbar states, exactly like the reference: 'top' (quiet),
     'raised' (shadow + green GET THE APP), 'cta' (past the hero, the
     CTA swaps to GET STARTED). */
  const [navState, setNavState] = useState<'top' | 'raised' | 'cta'>('top');
  const [story, setStory] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY;
      const heroDepth = window.innerHeight * 0.7;
      setNavState(y < 24 ? 'top' : y < heroDepth ? 'raised' : 'cta');
    };
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
      {/* 1. NAVBAR - three states                                       */}
      {/* ============================================================ */}
      <header
        className={`landing-nav sticky top-0 z-40 ${
          navState === 'top' ? 'bg-transparent' : 'bg-background/95 shadow-[0_2px_0_rgba(0,0,0,0.08)] backdrop-blur'
        }`}
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
            {navState === 'top' ? (
              <Link href="/register/" className="landing-nav-ghost">
                Get the app
              </Link>
            ) : (
              <Link href="/register/" className="btn-3d landing-nav-cta">
                {navState === 'cta' ? 'Get started' : 'Get the app'}
              </Link>
            )}
          </nav>
        </div>
      </header>

      <main>
        {/* ============================================================ */}
        {/* 2. HERO - cartoon cast up top, CTAs pinned low like Duo        */}
        {/* ============================================================ */}
        <section className="relative flex min-h-[100svh] flex-col overflow-hidden px-4 text-center sm:px-6">
          <h1 className="sr-only">Renance - Your Guide to Academic Success</h1>

          {/* The cast: Renny front and centre, doodles drifting around
              him - the "animated pictures between the navbar and GET
              STARTED". */}
          <div className="relative mx-auto flex w-full max-w-md flex-1 items-center justify-center py-10">
            <RennyMascot className="landing-rise relative z-10 w-[210px] drop-shadow-[0_20px_22px_rgba(15,40,48,0.16)] sm:w-[240px]" />
            {FLOATERS.map((f) => (
              <div
                key={f.id}
                className={`landing-floater ${f.className}`}
                style={cssVars({ '--rnt-dur': f.dur, '--rnt-delay': f.delay })}
                aria-hidden
              >
                <Doodle node={f.node} className="h-12 w-12 sm:h-14 sm:w-14" />
              </div>
            ))}
          </div>

          {/* Headline sits between the cast and the buttons; the whole
              cluster hugs the bottom of the viewport like the
              reference. */}
          <div className="landing-rise mx-auto w-full max-w-xl pb-10" style={cssVars({ '--rise-delay': '.18s' })}>
            <h2 className="text-[clamp(1.9rem,6vw,3.2rem)] font-extrabold leading-[1.08] tracking-tight text-on-surface">
              The most fun way to learn, practice, and smash your exams!
            </h2>

            <div className="mx-auto mt-7 flex w-full max-w-[340px] flex-col gap-3">
              <Link href="/register/" className="btn-3d w-full">
                Get started
              </Link>
              <Link href="/login/" className="btn-3d-blue w-full">
                I already have an account
              </Link>
              <OpenAppButton className="landing-open-app mt-1" />
            </div>
          </div>
        </section>

        {/* ============================================================ */}
        {/* 3. SUBJECT MARQUEE - seamless infinite loop                    */}
        {/* ============================================================ */}
        <section className="landing-marquee w-full pb-16" aria-label="Subjects on Renance">
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
        {/* 4. SLOGAN - "free. fun. effective." + green progress phone     */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-5xl px-4 pb-20 text-center sm:px-6">
          <h2 className="landing-reveal text-[clamp(2.2rem,6vw,4rem)] font-extrabold lowercase leading-tight tracking-tight" style={{ color: 'var(--color-primary)' }}>
            free. fun. effective.
          </h2>
          <p className="landing-reveal mx-auto mt-4 max-w-2xl text-[15px] font-semibold leading-relaxed text-on-surface-variant sm:text-base" style={cssVars({ '--reveal-delay': '.08s' })}>
            Learning on Renance is fun, and the results speak for themselves! Quick, bite-sized practice sessions earn you gems, keep your streak alive and unlock new levels - while real past questions turn into real exam scores.
          </p>

          <div className="landing-reveal mt-10 flex flex-wrap items-center justify-center gap-10" style={cssVars({ '--reveal-delay': '.14s' })}>
            {/* Green phone with the lesson progress bar */}
            <div className="landing-phone-green">
              <div className="space-y-2.5 p-3.5 text-left">
                <div className="flex items-center gap-1.5 text-[13px] font-extrabold text-[#4b4b4b]">
                  <span className="grid h-6 w-6 place-items-center rounded-lg text-white" style={{ background: '#ff9600' }}>
                    <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" aria-hidden>
                      <path d="M12 3c1 3-2.5 4.5-2.5 8A4.5 4.5 0 0 0 14 15.5c2-.5 3.5-2.2 3-4.5 2 1.6 3 3.6 3 5.5A7.5 7.5 0 0 1 4.5 16C4.5 10.5 10 8.5 12 3Z" />
                    </svg>
                  </span>
                  <span>7</span>
                  <span className="ml-auto" style={{ color: '#1cb0f6' }}>1,240 gems</span>
                </div>
                <p className="text-[13px] font-extrabold leading-snug text-[#3c3c3c]">
                  Physics · Newton&apos;s Laws · Lesson 3 of 5
                </p>
                <div className="h-3.5 w-full rounded-full bg-black/10">
                  <div className="h-3.5 w-2/3 rounded-full" style={{ background: 'var(--color-primary)' }} />
                </div>
                <div className="landing-lesson-row">
                  <span className="landing-lesson-check" style={{ background: '#58cc02' }}>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="M5 13l4 4L19 7" />
                    </svg>
                  </span>
                  Inertia and mass - done
                </div>
                <div className="landing-lesson-row">
                  <span className="landing-lesson-check" style={{ background: '#58cc02' }}>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="M5 13l4 4L19 7" />
                    </svg>
                  </span>
                  Action and reaction - done
                </div>
                <div className="landing-lesson-row justify-center border-0 pb-1 text-center" style={{ background: 'transparent' }}>
                  <span className="w-full rounded-xl py-2 text-center text-[13px] font-extrabold uppercase tracking-wide text-white" style={{ background: '#1cb0f6', boxShadow: '0 3px 0 #1899d6' }}>
                    Continue
                  </span>
                </div>
              </div>
            </div>

            {/* Trust numbers, carried over from the founder's numbers */}
            <div className="grid grid-cols-2 gap-x-10 gap-y-4 text-left">
              {[
                { n: '288,500+', l: 'past questions' },
                { n: '5,000+', l: 'courses' },
                { n: '500,000+', l: 'topics' },
                { n: '100%', l: 'free forever' },
              ].map((s) => (
                <div key={s.l}>
                  <p className="text-2xl font-extrabold tracking-tight" style={{ color: 'var(--color-primary)' }}>{s.n}</p>
                  <p className="text-[13px] font-bold text-on-surface-variant">{s.l}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ============================================================ */}
        {/* 5. BACKED BY RESULTS - avatar phone + #1 medallion scene       */}
        {/* ============================================================ */}
        <section className="mx-auto w-full max-w-5xl px-4 pb-20 text-center sm:px-6">
          <h2 className="landing-reveal text-[clamp(2rem,5.5vw,3.4rem)] font-extrabold lowercase leading-tight tracking-tight" style={{ color: 'var(--color-primary)' }}>
            backed by results
          </h2>
          <p className="landing-reveal mx-auto mt-4 max-w-2xl text-[15px] font-semibold leading-relaxed text-on-surface-variant sm:text-base" style={cssVars({ '--reveal-delay': '.08s' })}>
            Every mock is graded on the server against sealed answer keys, every wrong option is explained in the corrections reader, and spaced repetition keeps old topics fresh. That is how Ds turn into As - and why students keep coming back.
          </p>

          <div className="landing-reveal mt-10 flex flex-wrap items-end justify-center gap-8" style={cssVars({ '--reveal-delay': '.14s' })}>
            {/* Phone with four study buddies on screen */}
            <div className="landing-phone">
              <div className="landing-phone-notch" />
              <div className="space-y-2.5 p-3.5 text-left">
                <p className="text-center text-[12px] font-extrabold uppercase tracking-widest text-[#777]">Your study squad</p>
                <div className="grid grid-cols-2 gap-2.5">
                  {['#1cb0f6', '#ce82ff', '#ff9600', '#00cd9c'].map((c) => (
                    <div key={c} className="grid aspect-square place-items-center rounded-2xl border-2 border-[#e5e5e5] bg-white p-2">
                      <AvatarFace bg={c} />
                    </div>
                  ))}
                </div>
                <p className="text-center text-[11px] font-bold text-[#777]">2.1M learners and counting</p>
              </div>
            </div>

            {/* #1 medallion + red velvet rope, drawn small and proud */}
            <div className="flex flex-col items-center gap-3">
              <span className="grid h-20 w-20 place-items-center rounded-full text-xl font-black text-white" style={{ background: '#ffc800', boxShadow: 'inset 0 -4px 0 rgba(0,0,0,.18), 0 10px 18px rgba(15,40,48,.18)' }}>
                #1
              </span>
              <svg viewBox="0 0 140 64" width="150" height="69" aria-hidden>
                <rect x="10" y="8" width="9" height="52" rx="4" fill="#ff4b4b" />
                <rect x="121" y="8" width="9" height="52" rx="4" fill="#ff4b4b" />
                <circle cx="14.5" cy="8" r="5" fill="#d63a3a" />
                <circle cx="125.5" cy="8" r="5" fill="#d63a3a" />
                <path d="M14 20q56 34 112 0" stroke="#ff4b4b" strokeWidth="7" fill="none" strokeLinecap="round" />
              </svg>
              <p className="max-w-[190px] text-[13px] font-bold leading-snug text-on-surface-variant">
                The exam companion Nigerian students keep on their home screen
              </p>
            </div>
          </div>
        </section>

        {/* ============================================================ */}
        {/* 6. FEATURE TRIO                                                */}
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
        {/* 7. STORIES CAROUSEL                                            */}
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
        {/* 8. DOWNLOAD BAND - App Store COMING SOON + Google Play live    */}
        {/* ============================================================ */}
        <section className="landing-band-sky relative w-full overflow-hidden px-4 py-16 text-center sm:px-6">
          {/* floating doodles around the badges */}
          <div className="landing-floater left-[6%] top-[18%] landing-chip-lg" style={cssVars({ '--rnt-dur': '5.2s', '--rnt-delay': '.2s' })} aria-hidden>
            <BookDoodle className="h-14 w-14" />
          </div>
          <div className="landing-floater right-[7%] top-[24%] landing-chip-lg" style={cssVars({ '--rnt-dur': '4.8s', '--rnt-delay': '.6s' })} aria-hidden>
            <PencilDoodle className="h-12 w-12" />
          </div>
          <div className="landing-floater left-[12%] bottom-[14%] landing-chip-lg" style={cssVars({ '--rnt-dur': '5.8s', '--rnt-delay': '.4s' })} aria-hidden>
            <GemDoodle className="h-11 w-11" />
          </div>
          <div className="landing-floater right-[12%] bottom-[16%] landing-chip-lg" style={cssVars({ '--rnt-dur': '5s', '--rnt-delay': '.1s' })} aria-hidden>
            <StarDoodle className="h-11 w-11" />
          </div>
          <div className="landing-floater right-[26%] top-[10%] hidden xl:block" style={cssVars({ '--rnt-dur': '6.4s', '--rnt-delay': '.8s' })} aria-hidden>
            <RennyMascot className="h-24 w-24" />
          </div>

          <h2 className="landing-reveal text-[clamp(1.9rem,5vw,3.2rem)] font-extrabold lowercase leading-tight tracking-tight" style={{ color: '#0f2830' }}>
            learn anytime, anywhere
          </h2>
          <p className="landing-reveal mx-auto mt-3 max-w-xl text-[15px] font-bold text-[#33586e]" style={cssVars({ '--reveal-delay': '.08s' })}>
            Take Renance with you - past questions, streaks and leagues in your pocket. Web is live today, iOS is on the way.
          </p>

          <div className="landing-reveal mt-9 flex flex-wrap items-center justify-center gap-4" style={cssVars({ '--reveal-delay': '.14s' })}>
            <span className="landing-badge-wrap" aria-label="App Store - coming soon">
              <span className="landing-store-badge cursor-not-allowed opacity-95" role="presentation">
                <AppleDoodle />
                <span className="text-left leading-tight">
                  <span className="block text-[10px] font-bold uppercase tracking-widest opacity-80">Download on the</span>
                  <span className="block text-base font-extrabold">App Store</span>
                </span>
              </span>
              <span className="landing-badge-soon">COMING SOON</span>
            </span>

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
        {/* 9. FINAL CTA BAND                                              */}
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
      {/* 10. MEGA FOOTER                                                */}
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
