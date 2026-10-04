'use client';

/**
 * AppearanceModal - the founder's first-signup appearance popup
 * (directive 2026-09-28, restored 2026-10-02): "when student first
 * signup on the app or website display change appearance pop up that
 * will change the seed colour".
 *
 * A compact dialog that mirrors the Settings Appearance panel: Mode
 * (Light / Mixed / Dark) + the ten Seed Color presets. Every tap applies
 * LIVE through lib/theme.ts (setThemeMode + setSeedColor), so the whole
 * product re-tints behind the dialog, Chrome-style. One-time per device:
 * the flag lives in localStorage next to the theme keys, and
 * needsAppearanceIntro() / markAppearanceIntroDone() gate the flows.
 */

import { useEffect, useState } from 'react';
import {
  SEED_PRESETS,
  readSeedColor,
  readThemeMode,
  setSeedColor,
  setThemeMode,
  type ThemeMode,
} from '@/lib/theme';

export const APPEARANCE_ASKED_KEY = 'renance.appearanceAsked';

export function needsAppearanceIntro(): boolean {
  try {
    return !window.localStorage.getItem(APPEARANCE_ASKED_KEY);
  } catch {
    return false;
  }
}

export function markAppearanceIntroDone(): void {
  try {
    window.localStorage.setItem(APPEARANCE_ASKED_KEY, '1');
  } catch {
    /* private mode: it will simply ask again next signup */
  }
}

const MODES: Array<{ value: ThemeMode; icon: string; label: string }> = [
  { value: 'light', icon: 'light_mode', label: 'Light' },
  { value: 'mixed', icon: 'contrast', label: 'Mixed' },
  { value: 'dark', icon: 'dark_mode', label: 'Dark' },
];

export default function AppearanceModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const [mode, setMode] = useState<ThemeMode>('light');
  const [seed, setSeed] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setSeed(readSeedColor());
    setMode(readThemeMode());
  }, [open]);

  if (!open) return null;

  function pick(hex: string | null) {
    setSeed(hex);
    setSeedColor(hex, mode);
  }

  function pickMode(m: ThemeMode) {
    setMode(m);
    setThemeMode(m);
    // Re-apply the current seed under the new tier so the preview is
    // honest (setSeedColor already accepts a mode override).
    if (seed) setSeedColor(seed, m);
  }

  return (
    <div
      className="fixed inset-0 z-[100] flex items-end justify-center bg-[#0b1120cc] p-4 backdrop-blur-sm sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-label="Change appearance"
    >
      <div className="w-full max-w-md rounded-2xl border border-outline-variant bg-card p-6 shadow-2xl">
        <div className="flex items-center gap-3">
          <span className="material-symbols-outlined text-on-surface-variant">palette</span>
          <h2 className="text-[20px] font-semibold tracking-[-0.01em] text-on-surface">
            Make Renance yours
          </h2>
        </div>
        <p className="mt-1 text-[14px] leading-5 text-on-surface-variant">
          Pick an appearance - it re-tints every page, like Chrome. You can
          change it anytime in Settings.
        </p>

        {/* Mode */}
        <div className="mt-5">
          <span className="block text-[13px] font-semibold uppercase tracking-wide text-on-surface-variant">
            Mode
          </span>
          <div className="mt-2 flex gap-2">
            {MODES.map((o) => {
              const selected = mode === o.value;
              return (
                <button
                  key={o.value}
                  type="button"
                  onClick={() => pickMode(o.value)}
                  aria-pressed={selected}
                  className={`flex flex-1 flex-col items-center gap-1.5 rounded-[10px] border px-2 py-3 transition ${
                    selected
                      ? 'border-on-surface bg-selection-blue text-on-surface'
                      : 'border-outline-variant bg-surface-container-lowest text-on-surface-variant hover:border-outline'
                  }`}
                >
                  <span className="material-symbols-outlined text-[22px]">{o.icon}</span>
                  <span className="text-[13px] font-semibold">{o.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Seed presets */}
        <div className="mt-5">
          <span className="block text-[13px] font-semibold uppercase tracking-wide text-on-surface-variant">
            Seed color
          </span>
          <div className="mt-3 flex flex-wrap items-center gap-3">
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
          <button
            type="button"
            onClick={() => pick(null)}
            className={`mt-3 inline-flex items-center gap-1.5 text-[13px] font-medium ${
              seed === null ? 'text-on-surface' : 'text-on-surface-variant hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[16px]">
              {seed === null ? 'check_box' : 'check_box_outline_blank'}
            </span>
            Keep the classic ink &amp; paper look
          </button>
        </div>

        <button
          type="button"
          onClick={() => {
            markAppearanceIntroDone();
            onClose();
          }}
          className="mt-6 w-full rounded-[12px] bg-on-surface px-4 py-3 text-[15px] font-semibold text-surface-container-lowest transition hover:opacity-90"
        >
          Looks good
        </button>
      </div>
    </div>
  );
}
