'use client';

import { useEffect } from 'react';
import { SEED_VARS_KEY, THEME_KEYS, applySeedVars, readThemeMode } from '@/lib/theme';

/**
 * LandingDefaultTheme - the landing page renders the DEFAULT Renance
 * palette, no matter what a student picked under Appearance (founder
 * directive 2026-10-05, "the appearance changes must not affect the
 * landing page - leave the default colour").
 *
 * The appearance engine writes the seeded CSS custom properties onto
 * <html> (pre-paint bootstrap + lib/theme.ts), and the landing's dark
 * panels (.cbt-panel), hero chrome and CTAs read those tokens - so a
 * rose seed turned the landing's navy panels maroon. This component
 * strips exactly the seed keys from <html> while the visitor is on the
 * landing page: the stylesheet defaults (the original navy/black look
 * in every tier) render instead. Navigating into the app restores the
 * student's palette from the persisted pack, so the seed keeps working
 * on every other surface untouched.
 *
 * Renders nothing; the effect is the whole feature.
 */
export default function LandingDefaultTheme() {
  useEffect(() => {
    const root = document.documentElement;

    // Whatever the bootstrap / Appearance panel wrote inline right now,
    // keyed for a faithful restore if the persisted pack is unreadable.
    const saved = new Map<string, string>();
    for (const k of THEME_KEYS) {
      const v = root.style.getPropertyValue(k);
      if (v) saved.set(k, v);
      root.style.removeProperty(k);
    }

    return () => {
      // Leaving the landing page: put the student's seed back for the
      // current tier (the persisted pack is the source of truth - it
      // survives reloads; the saved inline values are the fallback).
      try {
        const pack = JSON.parse(
          window.localStorage.getItem(SEED_VARS_KEY) ?? 'null',
        ) as Record<string, Record<string, string>> | null;
        const vars = pack?.[readThemeMode()];
        if (vars && Object.keys(vars).length > 0) {
          applySeedVars(vars);
        } else if (saved.size > 0) {
          for (const [k, v] of saved) root.style.setProperty(k, v);
        } else {
          applySeedVars(null);
        }
      } catch {
        // private mode / corrupted pack: the saved inline values are
        // the best we know; with none, the stylesheet defaults stand.
        for (const [k, v] of saved) root.style.setProperty(k, v);
      }
    };
  }, []);

  return null;
}
