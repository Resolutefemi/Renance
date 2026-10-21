'use client';

/**
 * SharePrompt - the feed-automation popup (founder directive, round 8):
 * after every third fully-completed unit in a course, the lesson's done
 * moment asks the scholar to post the milestone to the Renance feed.
 * Pure presentation over lib/social's createPost: the overlay detected
 * the milestone, deduped it and paid nothing - this card only talks.
 */

import { useEffect, useState } from 'react';
import { createPost } from '@/lib/social';
import { ConfettiBurst } from '@/components/learn/bits';

type ShareState = 'idle' | 'sharing' | 'posted' | 'error';

export function SharePrompt({
  units,
  courseTitle,
  onDone,
}: {
  /** Fully-completed units in the course (the milestone that fired). */
  units: number;
  /** Course display title; the caller falls back to the id or "your course". */
  courseTitle: string;
  onDone?: () => void;
}) {
  const [state, setState] = useState<ShareState>('idle');

  // "Posted 🎉" lingers a beat, then the card closes itself.
  useEffect(() => {
    if (state !== 'posted') return;
    const t = window.setTimeout(() => onDone?.(), 1200);
    return () => window.clearTimeout(t);
  }, [state, onDone]);

  const share = () => {
    if (state === 'sharing' || state === 'posted') return;
    setState('sharing');
    createPost(`Just finished ${units} units of ${courseTitle} on Renance! 🔥`)
      .then(() => setState('posted'))
      .catch(() => setState('error'));
  };

  return (
    <div
      className="fixed inset-0 z-[96] flex flex-col items-center justify-center bg-black/70 px-6 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-label="Share your milestone"
    >
      <ConfettiBurst fire={1} />
      {/* The trophy circle mirrors the streak flame's stage presence. */}
      <div className="flex h-28 w-28 items-center justify-center rounded-full bg-gradient-to-b from-[#ffc800] to-[#ff9600] shadow-[0_0_60px_rgba(255,200,0,0.5)]">
        <span className="material-symbols-outlined text-[60px] text-white">trophy</span>
      </div>
      <p className="mt-6 text-[15px] font-black uppercase tracking-[0.16em] text-white/85">
        Units conquered
      </p>
      <p className="mt-1 max-w-sm text-center text-[26px] font-black leading-snug text-white">
        {units} unit{units === 1 ? '' : 's'} done in {courseTitle}!
      </p>
      <p className="mt-2 max-w-xs text-center text-[13px] font-bold leading-relaxed text-white/75">
        Tell the feed about it
      </p>
      {state === 'error' && (
        <p className="mt-3 max-w-xs text-center text-[12.5px] font-bold text-[#ffd7d7]">
          Could not share right now - try again in a moment.
        </p>
      )}
      <div className="mt-7 flex w-64 flex-col gap-2.5">
        <button
          type="button"
          onClick={share}
          disabled={state === 'sharing' || state === 'posted'}
          className="key-btn w-full bg-primary text-on-primary disabled:opacity-80"
        >
          {state === 'posted' ? 'Posted 🎉' : state === 'sharing' ? 'Posting…' : 'Share to feed'}
        </button>
        <button
          type="button"
          onClick={() => onDone?.()}
          className="mx-auto rounded-xl px-4 py-2 text-[12.5px] font-extrabold text-white/70 transition hover:text-white"
        >
          Maybe later
        </button>
      </div>
    </div>
  );
}
