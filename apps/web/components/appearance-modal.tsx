'use client';

/**
 * AppearanceModal - the founder's first-signup appearance popup
 * (directive 2026-09-28, restored 2026-10-02): "when student first
 * signup on the app or website display change appearance pop up that
 * will change the seed colour".
 *
 * 2026-10-13 founder pass: the popup is COLOURS ONLY. The Light /
 * Mixed / Dark mode row is gone from here - mixed mode is retired
 * outright, and dark/light lives in Settings after login (founder:
 * "in the appearance pop up remove the dark/light mode settings, only
 * those colour should be there, users can do that under settings after
 * login"). Every tap still applies LIVE through lib/theme.ts
 * (setSeedColor), so the whole product re-tints behind the dialog,
 * Chrome-style. One-time per ACCOUNT: the flag stores the account id
 * it already greeted in localStorage next to the theme keys, and
 * needsAppearanceIntro() / markAppearanceIntroDone() gate the flows.
 */

import { useEffect, useState } from 'react';
import { getStoredUser } from '@/lib/session';
import {
  SEED_PRESETS,
  readSeedColor,
  setSeedColor,
} from '@/lib/theme';

export const APPEARANCE_ASKED_KEY = 'renance.appearanceAsked';

export function needsAppearanceIntro(): boolean {
  try {
    // Per-ACCOUNT flag (founder bug 2026-10-05: "the appearance settings
    // pop up didn't show after i verify my email" + "make sure the
    // appearance pop up too even when a user sign up with google"): the
    // key used to hold a bare '1', so any browser that had met the
    // picker once (earlier builds popped it at register time) suppressed
    // it for EVERY later signup - manual or Google - and a fresh
    // student verified their email to silence instead of the picker.
    // The picker is a per-student moment: the key now stores the
    // account id it already greeted, so a NEW account (the 6-digit-code
    // signup or a first-time Google upsert) gets its own popup, while
    // the same account never sees it twice in this browser. The legacy
    // '1' value matches no account id, so it suppresses nothing.
    const uid = getStoredUser()?.id ?? '';
    if (!uid) return false;
    return window.localStorage.getItem(APPEARANCE_ASKED_KEY) !== uid;
  } catch {
    return false;
  }
}

export function markAppearanceIntroDone(): void {
  try {
    const uid = getStoredUser()?.id ?? '';
    window.localStorage.setItem(APPEARANCE_ASKED_KEY, uid || '1');
  } catch {
    /* private mode: it will simply ask again next signup */
  }
}

export default function AppearanceModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const [seed, setSeed] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setSeed(readSeedColor());
  }, [open]);

  if (!open) return null;

  function pick(hex: string | null) {
    setSeed(hex);
    setSeedColor(hex);
  }

  return (
    <div
      className="fixed inset-0 z-[100] flex items-end justify-center bg-[#0b1120cc] p-4 backdrop-blur-sm sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-label="Change appearance"
    >
      <div className="w-full max-w-md rounded-2xl border-2 border-outline-variant bg-card p-6 shadow-[0_6px_0_0_var(--color-outline-variant)]">
        <div className="flex items-center gap-3">
          <span className="material-symbols-outlined text-primary">palette</span>
          <h2 className="text-[20px] font-extrabold tracking-[-0.01em] text-on-surface">
            Make renance yours
          </h2>
        </div>
        <p className="mt-1 text-[14px] font-semibold leading-5 text-on-surface-variant">
          Pick a colour - it re-tints every page, like Chrome. Dark or
          light mode can be switched later in Settings after you sign in.
        </p>

        {/* Seed presets - the Renance Default (ink and paper) leads the
            list (founder directive 2026-10-05: "among the colour appearance
            pop up, add the default colour to the colour list"); tapping
            it clears the seed entirely. This is the WHOLE popup now:
            colours only, no mode row (founder directive 2026-10-13). */}
        <div className="mt-5">
          <span className="block text-[13px] font-extrabold uppercase tracking-wide text-on-surface-variant">
            Colour
          </span>
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <button
              type="button"
              title="Renance default (ink and paper)"
              aria-label="Renance default (ink and paper)"
              aria-pressed={seed === null}
              onClick={() => pick(null)}
              className={`flex h-10 w-10 items-center justify-center overflow-hidden rounded-full border-2 transition ${
                seed === null
                  ? 'scale-110 border-on-surface'
                  : 'border-transparent hover:scale-105'
              }`}
            >
              <span
                aria-hidden
                className="block h-full w-full"
                style={{
                  background:
                    'linear-gradient(to right, #111 0 50%, #fff 50% 100%)',
                }}
              />
            </button>
            {SEED_PRESETS.map((p) => {
              const selected = seed?.toLowerCase() === p.hex.toLowerCase();
              return (
                <button
                  key={p.hex}
                  type="button"
                  title={p.name}
                  aria-label={p.name}
                  aria-pressed={selected}
                  onClick={() => pick(p.hex)}
                  className={`flex h-10 w-10 items-center justify-center rounded-full border-2 transition ${
                    selected
                      ? 'border-on-surface scale-110'
                      : 'border-transparent hover:scale-105'
                  }`}
                  style={{ background: p.hex }}
                >
                  {selected && (
                    <span className="material-symbols-outlined text-[20px] text-white drop-shadow">
                      check
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <button
          type="button"
          onClick={() => {
            markAppearanceIntroDone();
            onClose();
          }}
          className="mt-6 w-full rounded-[12px] bg-primary px-4 py-3 text-[15px] font-extrabold text-on-primary"
        >
          Looks good
        </button>
      </div>
    </div>
  );
}
