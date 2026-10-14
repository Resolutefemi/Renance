'use client';

/**
 * Learn bits - the gamification atoms of the merged Supreme module,
 * rebuilt in Renance's tactile design language (2026-10-14). Gem and
 * heart counters, the flame, the daily-goal ring, league badges and
 * the confetti burst. All surfaces read the live theme tokens, so
 * light and dark tiers both stay legible.
 */

import { ReactNode, useEffect, useState } from 'react';

// ─── Icons (inline, Duolingo-style rounded geometry) ──────────────────────

export function GemIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
      <path d="M6 3h12l4 6-10 12L2 9l4-6z" fill="#1cb0f6" stroke="#1899d6" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M2 9h20" stroke="#1899d6" strokeWidth="1.4" />
      <path d="M9 3l-2 6 5 12 5-12-2-6" stroke="#84d8ff" strokeWidth="1.2" fill="none" strokeLinejoin="round" />
    </svg>
  );
}

export function HeartIcon({ size = 18, filled = true }: { size?: number; filled?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
      <path
        d="M12 21s-7.5-4.9-9.7-9.2C.7 8.6 2.6 4.9 6.1 4.9c2 0 3.6 1.1 4.4 2.7l1.5 2.6 1.5-2.6c.8-1.6 2.4-2.7 4.4-2.7 3.5 0 5.4 3.7 3.8 6.9C19.5 16.1 12 21 12 21z"
        fill={filled ? '#ff4b4b' : 'none'}
        stroke="#ea2b2b"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function FlameIcon({ size = 18, frozen = false }: { size?: number; frozen?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
      <path
        d="M13.2 2.2c.3 2.4-.6 4-1.9 5.4C10 9 8.6 10.4 8.6 13a5.4 5.4 0 0010.8 0c0-2.2-1-3.8-2.2-5.4-.3 1-.8 1.8-1.6 2.3.3-2.7-.8-5.8-2.4-7.7z"
        fill={frozen ? '#1cb0f6' : '#ffc800'}
        stroke={frozen ? '#1899d6' : '#e6ac00'}
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M12 20.2c-1.8 0-3.1-1.3-3.1-3.1 0-1.6 1.1-2.6 2-3.6.5.9 1.2 1.4 2 1.5-.2-1.2.2-2.4 1-3.2 1 1.2 1.7 2.9 1.7 4.7 0 2.1-1.6 3.7-3.6 3.7z" fill={frozen ? '#84d8ff' : '#ff9600'} opacity="0.9" />
    </svg>
  );
}

// ─── Counters ─────────────────────────────────────────────────────────────

export function StatChip({
  icon, value, onClick, title,
}: {
  icon: ReactNode;
  value: ReactNode;
  onClick?: () => void;
  title?: string;
}) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      type={onClick ? 'button' : undefined}
      onClick={onClick}
      title={title}
      className={`flex h-8 min-w-[54px] items-center justify-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 ${
        onClick ? 'transition active:translate-y-[2px]' : ''
      }`}
    >
      {icon}
      <span className="font-mono text-[12.5px] font-bold text-on-surface">{value}</span>
    </Tag>
  );
}

export function GoalRing({ value, max }: { value: number; max: number }) {
  const pct = Math.max(0, Math.min(1, max > 0 ? value / max : 0));
  const r = 10;
  const c = 2 * Math.PI * r;
  return (
    <svg width="30" height="30" viewBox="0 0 30 30" aria-label={`Daily goal ${value}/${max}`} className="hidden sm:block">
      <circle cx="15" cy="15" r={r} fill="none" stroke="var(--color-outline-light, #e5e5e5)" strokeWidth="3.5" />
      <circle
        cx="15" cy="15" r={r} fill="none"
        stroke="var(--color-primary, #10da11)"
        strokeWidth="3.5" strokeLinecap="round"
        strokeDasharray={`${c * pct} ${c}`}
        transform="rotate(-90 15 15)"
      />
      <text x="15" y="18.5" textAnchor="middle" fontSize="8" fontWeight="800" fill="var(--color-on-surface, #3c3c46)">
        {pct >= 1 ? '✓' : `${Math.round(pct * 100)}`}
      </text>
    </svg>
  );
}

export function LeagueBadge({ name, size = 44 }: { name: string; size?: number }) {
  const tones: Record<string, string> = {
    Bronze: '#d9a15b', Copper: '#c96f4a', Silver: '#b8c0cc', Gold: '#ffc800',
    Sapphire: '#1cb0f6', Ruby: '#ff4b4b', Emerald: '#2ec46e', Amethyst: '#ce82ff',
    Pearl: '#e8e6f2', Diamond: '#84d8ff',
  };
  const fill = tones[name] ?? '#10da11';
  return (
    <svg width={size} height={size} viewBox="0 0 44 44" aria-label={`${name} league`}>
      <path d="M22 3l16 6v12c0 10-6.8 16.9-16 20C12.8 37.9 6 31 6 21V9l16-6z" fill={fill} stroke="rgba(0,0,0,.25)" strokeWidth="2" />
      <path d="M22 3l16 6v6L22 9 6 15V9l16-6z" fill="#ffffff" opacity="0.25" />
      <text x="22" y="27" textAnchor="middle" fontSize="14" fontWeight="900" fill="rgba(0,0,0,.55)">{name.slice(0, 2).toUpperCase()}</text>
    </svg>
  );
}

export function ProgressBar({ value, tone = 'green' }: { value: number; tone?: 'green' | 'blue' | 'gold' }) {
  const v = Math.max(0, Math.min(100, value));
  const bg = tone === 'blue' ? 'bg-macaw' : tone === 'gold' ? 'bg-accent-amber' : 'bg-primary';
  return (
    <div className="h-3.5 w-full overflow-hidden rounded-full bg-surface-container-high" role="progressbar" aria-valuenow={Math.round(v)} aria-valuemin={0} aria-valuemax={100}>
      <div className="relative h-full rounded-full transition-[width] duration-500" style={{ width: `${v}%` }}>
        <div className={`h-full rounded-full ${bg}`} />
        <span className="pointer-events-none absolute inset-x-1 top-[2px] h-1 rounded-full bg-white/40" />
      </div>
    </div>
  );
}

// ─── Confetti ─────────────────────────────────────────────────────────────

const CONFETTI_COLORS = ['#10da11', '#1cb0f6', '#ffc800', '#ff9600', '#ff4b4b', '#ce82ff'];

export function ConfettiBurst({ fire }: { fire: number }) {
  const [pieces, setPieces] = useState<Array<{ id: number; left: number; delay: number; color: string; dx: number }>>([]);
  useEffect(() => {
    if (!fire) return;
    const batch = Array.from({ length: 26 }, (_, i) => ({
      id: fire * 100 + i,
      left: 5 + Math.random() * 90,
      delay: Math.random() * 0.35,
      color: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
      dx: -40 + Math.random() * 80,
    }));
    setPieces(batch);
    const t = setTimeout(() => setPieces([]), 2400);
    return () => clearTimeout(t);
  }, [fire]);
  if (!pieces.length) return null;
  return (
    <div className="pointer-events-none fixed inset-x-0 top-24 z-[70] mx-auto h-64 max-w-lg" aria-hidden>
      {pieces.map((p) => (
        <span
          key={p.id}
          className="learn-confetti absolute top-0 h-2.5 w-2 rounded-sm"
          style={{ left: `${p.left}%`, background: p.color, animationDelay: `${p.delay}s`, ['--dx' as string]: `${p.dx}px` }}
        />
      ))}
    </div>
  );
}

// ─── Toast ────────────────────────────────────────────────────────────────

export function ToastBanner({ text, tone = 'green' }: { text: string; tone?: 'green' | 'blue' | 'red' }) {
  if (!text) return null;
  const bg = tone === 'blue' ? 'bg-macaw' : tone === 'red' ? 'bg-error' : 'bg-primary';
  return (
    <div className={`pointer-events-none fixed inset-x-0 top-16 z-[70] mx-auto w-fit max-w-[90vw] rounded-xl px-4 py-2 text-[13px] font-extrabold text-white learn-toast-shadow ${bg}`}>
      {text}
    </div>
  );
}
