'use client';

/**
 * PacingGauge - Live Exam Clock Coach for Renance Study OS.
 *
 * Keeps students conscious of per-question time limits without inducing panic.
 * Follows Renance light M3 tokens with subtle status indicators.
 */

import { useState } from 'react';
import { type LivePacingInfo } from '@/lib/pacing';

interface Props {
  pacing: LivePacingInfo;
  disabled?: boolean;
}

export default function PacingGauge({ pacing, disabled }: Props) {
  const [minimized, setMinimized] = useState(false);

  if (disabled) return null;

  const { elapsedSec, targetSec, state, label, advice } = pacing;

  const colorStyles = {
    on_track: {
      dot: 'bg-accent-emerald',
      pill: 'border-accent-emerald/30 bg-accent-emerald/5 text-accent-emerald',
      bar: 'bg-accent-emerald',
    },
    lingering: {
      dot: 'bg-accent-amber',
      pill: 'border-accent-amber/40 bg-accent-amber/10 text-on-surface',
      bar: 'bg-accent-amber',
    },
    trap_risk: {
      dot: 'bg-error animate-pulse',
      pill: 'border-error/40 bg-error/10 text-error',
      bar: 'bg-error',
    },
  }[state];

  const fillPct = Math.min(100, Math.round((elapsedSec / (targetSec * 2)) * 100));

  if (minimized) {
    return (
      <button
        onClick={() => setMinimized(false)}
        title="Open Pacing Coach"
        className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-mono text-[11px] font-semibold transition active:scale-[0.97] ${colorStyles.pill}`}
      >
        <span className={`h-2 w-2 rounded-full ${colorStyles.dot}`} />
        <span>{elapsedSec}s</span>
      </button>
    );
  }

  return (
    <div
      className={`relative flex items-center gap-2.5 rounded-full border px-3 py-1.5 transition-all ${colorStyles.pill}`}
    >
      <span className={`h-2 w-2 shrink-0 rounded-full ${colorStyles.dot}`} />

      <div className="flex items-center gap-1.5 font-mono text-[11.5px] font-semibold tracking-tight">
        <span>{elapsedSec}s</span>
        <span className="opacity-40">/</span>
        <span className="opacity-70">{targetSec}s target</span>
      </div>

      <span className="hidden text-[11px] font-medium text-on-surface-variant md:inline">
        · {label}
      </span>

      {state === 'trap_risk' && (
        <span
          title={advice}
          className="material-symbols-outlined text-[15px] text-error"
        >
          warning
        </span>
      )}

      <button
        onClick={() => setMinimized(true)}
        aria-label="Minimize pacing indicator"
        title="Minimize"
        className="ml-0.5 text-on-surface-variant/60 hover:text-on-surface active:scale-[0.95]"
      >
        <span className="material-symbols-outlined text-[14px]">remove</span>
      </button>
    </div>
  );
}
