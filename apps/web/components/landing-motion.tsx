'use client';

/**
 * Landing motion kit — the lively layer of the public landing page.
 *
 * Every piece degrades gracefully: without JS the content simply renders
 * (reveals default to visible when IO is unavailable), so the page stays
 * a complete static document for crawlers and search engines.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import Link from 'next/link';
import { RenanceMark } from '@/components/renance-logo';

/* ------------------------------------------------------------------ */
/* Reduced motion — one hook every animation consults.                 */
/* ------------------------------------------------------------------ */

const MotionContext = createContext<boolean>(false);

export function MotionPrefs({ children }: { children: ReactNode }) {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const on = () => setReduced(mq.matches);
    on();
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return <MotionContext.Provider value={reduced}>{children}</MotionContext.Provider>;
}

export function useReducedMotion() {
  return useContext(MotionContext);
}

/* ------------------------------------------------------------------ */
/* Reveal — scroll-triggered rise-and-fade with optional stagger.      */
/* ------------------------------------------------------------------ */

export function Reveal({
  children,
  delay = 0,
  y = 28,
  className = '',
  as: Tag = 'div',
}: {
  children: ReactNode;
  delay?: number;
  y?: number;
  className?: string;
  as?: 'div' | 'section' | 'article' | 'li' | 'span' | 'h2' | 'p';
}) {
  const ref = useRef<HTMLDivElement | null>(null);
  const [shown, setShown] = useState(false);
  const reduced = useReducedMotion();

  useEffect(() => {
    if (reduced) {
      setShown(true);
      return;
    }
    const el = ref.current;
    if (!el || typeof IntersectionObserver === 'undefined') {
      setShown(true);
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            setShown(true);
            io.disconnect();
          }
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -8% 0px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [reduced]);

  const style: CSSProperties = {
    opacity: shown ? 1 : 0,
    transform: shown ? 'none' : `translateY(${y}px)`,
    transition: reduced
      ? 'none'
      : `opacity 0.9s cubic-bezier(0.22,1,0.36,1) ${delay}ms, transform 0.9s cubic-bezier(0.22,1,0.36,1) ${delay}ms`,
    willChange: 'opacity, transform',
  };
  const Component = Tag as 'div';
  return (
    <Component ref={ref} className={className} style={style}>
      {children}
    </Component>
  );
}

/* ------------------------------------------------------------------ */
/* CountUp — stat numbers count in when they enter the viewport.       */
/* ------------------------------------------------------------------ */

export function CountUp({
  to,
  suffix = '',
  duration = 1600,
  className = '',
}: {
  to: number;
  suffix?: string;
  duration?: number;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement | null>(null);
  const [value, setValue] = useState(0);
  const started = useRef(false);
  const reduced = useReducedMotion();

  useEffect(() => {
    if (reduced) {
      setValue(to);
      return;
    }
    const el = ref.current;
    if (!el || typeof IntersectionObserver === 'undefined') {
      setValue(to);
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting && !started.current) {
            started.current = true;
            const t0 = performance.now();
            const tick = (now: number) => {
              const p = Math.min(1, (now - t0) / duration);
              const eased = 1 - Math.pow(1 - p, 4);
              setValue(Math.round(to * eased));
              if (p < 1) requestAnimationFrame(tick);
            };
            requestAnimationFrame(tick);
            io.disconnect();
          }
        }
      },
      { threshold: 0.4 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [to, duration, reduced]);

  return (
    <span ref={ref} className={className}>
      {value.toLocaleString('en-US')}
      {suffix}
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* AuroraField — the drifting gradient backdrop behind the hero.       */
/* Pointer tilt makes the whole field lean towards the cursor, the     */
/* Apple-wallpaper trick that makes glass feel physical.               */
/* ------------------------------------------------------------------ */

export function AuroraField() {
  const ref = useRef<HTMLDivElement | null>(null);
  const reduced = useReducedMotion();

  useEffect(() => {
    if (reduced) return;
    const el = ref.current;
    if (!el) return;
    let raf = 0;
    let tx = 0;
    let ty = 0;
    let cx = 0;
    let cy = 0;
    const onMove = (e: PointerEvent) => {
      tx = (e.clientX / window.innerWidth - 0.5) * 2;
      ty = (e.clientY / window.innerHeight - 0.5) * 2;
    };
    const loop = () => {
      cx += (tx - cx) * 0.06;
      cy += (ty - cy) * 0.06;
      el.style.setProperty('--tilt-x', cx.toFixed(4));
      el.style.setProperty('--tilt-y', cy.toFixed(4));
      raf = requestAnimationFrame(loop);
    };
    window.addEventListener('pointermove', onMove, { passive: true });
    raf = requestAnimationFrame(loop);
    return () => {
      window.removeEventListener('pointermove', onMove);
      cancelAnimationFrame(raf);
    };
  }, [reduced]);

  return (
    <div ref={ref} className="aurora-field" aria-hidden>
      <div className="aurora aurora-a" />
      <div className="aurora aurora-b" />
      <div className="aurora aurora-c" />
      <div className="aurora-grain" />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* LandingNav — the floating glass navbar.                             */
/* Stable: always pinned, never hides. Transparent over the hero, it   */
/* snaps to a frosted pill once the page scrolls. Mobile collapses     */
/* into a glass sheet.                                                 */
/* ------------------------------------------------------------------ */

const NAV_LINKS = [
  { href: '/subjects/', label: 'Subjects' },
  { href: '/packs/', label: 'Question packs' },
  { href: '/lessons/', label: 'Lessons' },
  { href: '/flashcards/', label: 'Flashcards' },
  { href: '/faq/', label: 'FAQ' },
];

export function LandingNav() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const close = useCallback(() => setOpen(false), []);

  return (
    <header className={`landing-nav ${scrolled ? 'is-scrolled' : ''}`}>
      <nav className="landing-nav-pill" aria-label="Primary">
        <Link href="/" className="landing-nav-brand" onClick={close}>
          <RenanceMark size={30} />
          <span className="landing-nav-word">Renance</span>
        </Link>

        <div className="landing-nav-links">
          {NAV_LINKS.map((l) => (
            <Link key={l.href} href={l.href} className="landing-nav-link">
              {l.label}
            </Link>
          ))}
        </div>

        <div className="landing-nav-cta">
          <Link href="/login/" className="landing-nav-login">
            Sign in
          </Link>
          <Link href="/register/" className="landing-nav-start">
            Start free
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden>
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

        <button
          type="button"
          className={`landing-nav-burger ${open ? 'is-open' : ''}`}
          aria-expanded={open}
          aria-label={open ? 'Close menu' : 'Open menu'}
          onClick={() => setOpen((v) => !v)}
        >
          <span />
          <span />
        </button>
      </nav>

      <div className={`landing-nav-sheet ${open ? 'is-open' : ''}`}>
        {NAV_LINKS.map((l) => (
          <Link key={l.href} href={l.href} className="landing-sheet-link" onClick={close}>
            {l.label}
          </Link>
        ))}
        <div className="landing-sheet-actions">
          <Link href="/login/" className="landing-sheet-login" onClick={close}>
            Sign in
          </Link>
          <Link href="/register/" className="landing-sheet-start" onClick={close}>
            Create free account
          </Link>
        </div>
      </div>
    </header>
  );
}

/* ------------------------------------------------------------------ */
/* FloatingCards — the three glass tiles orbiting the hero copy.       */
/* Pure CSS animation; this wrapper only staggers entrance.            */
/* ------------------------------------------------------------------ */

export function FloatingCard({
  className = '',
  tone,
  icon,
  title,
  body,
  delay = 0,
}: {
  className?: string;
  tone: 'blue' | 'emerald' | 'amber';
  icon: string;
  title: string;
  body: string;
  delay?: number;
}) {
  const reduced = useReducedMotion();
  return (
    <div
      className={`glass-float tone-${tone} float-${tone} ${className}`}
      style={{
        animationDelay: `${delay}ms`,
        // Reduced motion: kill the drift, keep the entrance.
        ...(reduced ? { animation: 'none' as const } : {}),
      }}
    >
      <div className="glass-float-icon">
        <span className="material-symbols-outlined">{icon}</span>
      </div>
      <div>
        <p className="glass-float-title">{title}</p>
        <p className="glass-float-body">{body}</p>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* MarqueeRail — infinite exam-pack ticker (pausable, a11y-safe).      */
/* ------------------------------------------------------------------ */

export function MarqueeRail({ items }: { items: string[] }) {
  const doubled = [...items, ...items];
  return (
    <div className="marquee" aria-hidden>
      <div className="marquee-track">
        {doubled.map((t, i) => (
          <span className="marquee-chip" key={`${t}-${i}`}>
            {t}
          </span>
        ))}
      </div>
    </div>
  );
}
