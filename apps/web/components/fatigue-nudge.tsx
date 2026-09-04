'use client';

/**
 * Fatigue nudge (ROADMAP #6) — the Stitch fatigue_nudge_light overlay:
 * a soft veil, the RenanceMark anchor, and a gentle card with Take 5 /
 * Keep going. Presentation only — the caller owns every decision.
 */

import { RenanceMark } from '@/components/renance-logo';

export function FatigueNudgeOverlay({
  visible,
  reasons,
  onTakeBreak,
  onKeepGoing,
}: {
  visible: boolean;
  reasons: string[];
  onTakeBreak: () => void;
  onKeepGoing: () => void;
}) {
  if (!visible) return null;
  const reason = reasons.length > 0 ? reasons[0] : 'Your pace is dipping';
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-white/90 px-6 backdrop-blur-sm">
      <div className="w-full max-w-[340px] rounded-xl bg-card p-6 text-center shadow-xl shadow-on-surface/5">
        <div className="mb-6 flex justify-center">
          <RenanceMark size={64} />
        </div>
        <h3 className="text-[18px] font-semibold tracking-tight text-on-surface">
          Your pace is dipping
        </h3>
        <p className="mt-2 text-[15px] leading-relaxed text-on-surface-variant">
          {reason}. A 5-minute break now protects your streak and helps you
          retain what you&apos;ve learned.
        </p>
        <button
          type="button"
          onClick={onTakeBreak}
          className="mt-6 flex h-[52px] w-full items-center justify-center rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition-all active:scale-[0.98]"
        >
          Take 5
        </button>
        <button
          type="button"
          onClick={onKeepGoing}
          className="mt-1 flex h-[44px] w-full items-center justify-center rounded-[10px] text-sm text-on-surface-variant transition hover:text-on-surface"
        >
          Keep going
        </button>
      </div>
    </div>
  );
}
