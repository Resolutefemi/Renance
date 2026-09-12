'use client';

/**
 * Renance Appearance engine — the Chrome-style colour theming the
 * founder asked for ("all the black colours in the website or app can
 * be easily changed to any colour students want, under settings, like
 * Chrome appearance settings").
 *
 * A seed colour is expanded into the full token palette (surfaces,
 * containers, ink, primaries, outlines, hero chrome) for each appearance
 * tier — Light, Mixed, Dark — and written as CSS custom properties on
 * <html>. Every screen already reads the tokens, so one seed repaints
 * the whole product. The computed variables are also persisted
 * (renance.seedVars) so the inline bootstrap in app/layout.tsx can
 * apply them before first paint with no colour maths on the critical
 * path. Removing the seed falls back to the stylesheet palette.
 */

/* ------------------------------------------------------------------ */
/* colour maths                                                        */
/* ------------------------------------------------------------------ */

export function hexToHsl(hex: string): { h: number; s: number; l: number } {
  const m = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return { h: 145, s: 78, l: 48 }; // Renance green fallback
  let body = m[1];
  if (body.length === 3) body = [...body].map((c) => c + c).join('');
  const r = parseInt(body.slice(0, 2), 16) / 255;
  const g = parseInt(body.slice(2, 4), 16) / 255;
  const b = parseInt(body.slice(4, 6), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l: l * 100 };
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h: number;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return { h: h * 360, s: s * 100, l: l * 100 };
}

function hslToHex(h: number, s: number, l: number): string {
  h = ((h % 360) + 360) % 360;
  s = Math.min(100, Math.max(0, s)) / 100;
  l = Math.min(100, Math.max(0, l)) / 100;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let r = 0;
  let g = 0;
  let b = 0;
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const to = (v: number) =>
    Math.round((v + m) * 255)
      .toString(16)
      .padStart(2, '0');
  return `#${to(r)}${to(g)}${to(b)}`;
}
export { hslToHex };

export function normalizeHex(hex: string): string | null {
  const m = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return null;
  let body = m[1].toLowerCase();
  if (body.length === 3) body = [...body].map((c) => c + c).join('');
  return `#${body}`;
}

/** WCAG-ish relative luminance (0 black → 1 white). */
function luminance(hex: string): number {
  const body = hex.replace('#', '');
  const ch = [0, 2, 4].map((i) => {
    const v = parseInt(body.slice(i, i + 2), 16) / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
}

/* ------------------------------------------------------------------ */
/* palette derivation                                                  */
/* ------------------------------------------------------------------ */

export type ThemeMode = 'light' | 'mixed' | 'dark';

/** CSS custom properties one seed repaints. Keys match globals.css. */
export type PaletteVars = Record<string, string>;

export function buildPalette(seedHex: string, mode: ThemeMode): PaletteVars {
  const { h, s } = hexToHsl(seedHex);
  const hue = Math.round(h);
  // a fully desaturated seed would grey the whole product; keep a whisper
  // of tint on surfaces and let the ink stay neutral.
  const tint = Math.max(18, Math.min(52, s));
  const sat = Math.max(30, Math.min(100, s));
  const vars: PaletteVars = {};

  if (mode === 'dark') {
    vars['--color-background'] = hslToHex(hue, 34, 9);
    vars['--color-surface'] = vars['--color-background'];
    vars['--color-surface-bright'] = hslToHex(hue, 30, 15);
    vars['--color-surface-dim'] = hslToHex(hue, 32, 6);
    vars['--color-surface-container-lowest'] = hslToHex(hue, 30, 11);
    vars['--color-card'] = hslToHex(hue, 30, 14);
    vars['--color-surface-container-low'] = hslToHex(hue, 30, 10);
    vars['--color-surface-container'] = hslToHex(hue, 28, 14);
    vars['--color-surface-container-high'] = hslToHex(hue, 28, 17);
    vars['--color-surface-container-highest'] = hslToHex(hue, 28, 20);
    vars['--color-surface-variant'] = hslToHex(hue, 28, 17);
    vars['--color-on-background'] = hslToHex(hue, 60, 96);
    vars['--color-on-surface'] = vars['--color-on-background'];
    vars['--color-on-surface-variant'] = hslToHex(hue, 14, 72);
    // the seed lights up as the accent on dark
    const primary = hslToHex(hue, sat, Math.min(76, Math.max(58, l0(seedHex))));
    vars['--color-primary'] = primary;
    vars['--color-on-primary'] = luminance(primary) > 0.42 ? hslToHex(hue, 42, 10) : '#0b1120';
    vars['--color-primary-container'] = hslToHex(hue, 26, 19);
    vars['--color-on-primary-container'] = hslToHex(hue, 62, 90);
    vars['--color-secondary'] = hslToHex(hue, 14, 72);
    vars['--color-secondary-container'] = hslToHex(hue, 24, 15);
    vars['--color-on-secondary-container'] = hslToHex(hue, 55, 94);
    vars['--color-outline'] = hslToHex(hue, 14, 66);
    vars['--color-outline-variant'] = hslToHex(hue, 20, 28);
    vars['--color-outline-light'] = vars['--color-outline-variant'];
    vars['--color-selection-blue'] = hslToHex(hue, 30, 19);
    vars['--color-hero'] = hslToHex(hue, 30, 14);
    vars['--color-on-hero'] = vars['--color-on-background'];
    vars['--color-hero-muted'] = vars['--color-on-surface-variant'];
    vars['--color-hero-track'] = hslToHex(hue, 28, 17);
    vars['--color-hero-cta'] = primary;
    vars['--color-on-hero-cta'] = vars['--color-on-primary'];
    vars['--color-accent-ink'] = hslToHex(hue, 34, 17);
    vars['--color-ink-deep'] = hslToHex(hue, 32, 12);
    vars['--color-dark-surface'] = vars['--color-ink-deep'];
    vars['--color-dark-surface-low'] = hslToHex(hue, 30, 15);
    vars['--color-inverse-surface'] = hslToHex(hue, 40, 88);
    vars['--color-inverse-on-surface'] = hslToHex(hue, 35, 12);
    return vars;
  }

  // Light body (also the base of Mixed); the seed tints the neutrals and
  // drives the primary actions — the "black" becomes the student's colour.
  const primary = hslToHex(hue, sat, Math.min(46, Math.max(30, l0(seedHex) > 55 ? 38 : l0(seedHex) * 0.72)));
  vars['--color-background'] = hslToHex(hue, 46, 98);
  vars['--color-surface'] = vars['--color-background'];
  vars['--color-surface-bright'] = vars['--color-background'];
  vars['--color-surface-dim'] = hslToHex(hue, 32, 88);
  vars['--color-surface-container-lowest'] = '#ffffff';
  vars['--color-card'] = '#ffffff';
  vars['--color-surface-container-low'] = hslToHex(hue, 50, 96.5);
  vars['--color-surface-container'] = hslToHex(hue, 48, 93.5);
  vars['--color-surface-container-high'] = hslToHex(hue, 46, 91);
  vars['--color-surface-container-highest'] = hslToHex(hue, 44, 89);
  vars['--color-surface-variant'] = hslToHex(hue, 44, 89);
  vars['--color-on-background'] = hslToHex(hue, 40, 12);
  vars['--color-on-surface'] = vars['--color-on-background'];
  vars['--color-on-surface-variant'] = hslToHex(hue, 12, 30);
  vars['--color-primary'] = primary;
  vars['--color-on-primary'] = luminance(primary) > 0.5 ? hslToHex(hue, 42, 12) : '#ffffff';
  vars['--color-primary-container'] = hslToHex(hue, Math.max(30, tint), 90);
  vars['--color-on-primary-container'] = hslToHex(hue, 34, 24);
  vars['--color-secondary'] = hslToHex(hue, 18, 40);
  vars['--color-secondary-container'] = hslToHex(hue, 42, 91);
  vars['--color-on-secondary-container'] = hslToHex(hue, 26, 30);
  vars['--color-outline'] = hslToHex(hue, 6, 46);
  vars['--color-outline-variant'] = hslToHex(hue, 12, 79);
  vars['--color-outline-light'] = vars['--color-outline-variant'];
  vars['--color-selection-blue'] = hslToHex(hue, 48, 91);
  vars['--color-accent-ink'] = hslToHex(hue, 40, 13);
  vars['--color-ink-deep'] = hslToHex(hue, 38, 12);
  vars['--color-inverse-surface'] = hslToHex(hue, 36, 20);
  vars['--color-inverse-on-surface'] = hslToHex(hue, 60, 97);

  if (mode === 'mixed') {
    // dark hero chrome over the light body, tinted with the same seed
    vars['--color-hero'] = hslToHex(hue, 40, 12);
    vars['--color-on-hero'] = hslToHex(hue, 60, 96);
    vars['--color-hero-muted'] = hslToHex(hue, 20, 72);
    vars['--color-hero-track'] = hslToHex(hue, 30, 16);
    vars['--color-hero-cta'] = hslToHex(hue, sat, Math.min(76, Math.max(58, l0(seedHex))));
    vars['--color-on-hero-cta'] =
      luminance(vars['--color-hero-cta']) > 0.42 ? hslToHex(hue, 42, 10) : '#0b1120';
  } else {
    // plain light: white band, seed CTA (the old black button)
    vars['--color-hero'] = '#ffffff';
    vars['--color-on-hero'] = vars['--color-on-background'];
    vars['--color-hero-muted'] = vars['--color-on-surface-variant'];
    vars['--color-hero-track'] = hslToHex(hue, 44, 89);
    vars['--color-hero-cta'] = primary;
    vars['--color-on-hero-cta'] = vars['--color-on-primary'];
  }
  return vars;
}

/** Seed lightness without recomputing HSL twice. */
function l0(hex: string): number {
  return hexToHsl(hex).l;
}

/* ------------------------------------------------------------------ */
/* apply + persist                                                     */
/* ------------------------------------------------------------------ */

export const SEED_KEY = 'renance.seed';
export const SEED_VARS_KEY = 'renance.seedVars';

const THEME_KEYS = Object.keys(buildPalette('#13dc1b', 'dark'));

/** Write a palette onto <html> (null clears back to the stylesheet). */
export function applySeedVars(vars: PaletteVars | null): void {
  if (typeof document === 'undefined') return;
  const root = document.documentElement;
  for (const k of THEME_KEYS) root.style.removeProperty(k);
  if (vars) {
    for (const [k, v] of Object.entries(vars)) root.style.setProperty(k, v);
  }
}

/** Persist a seed (hex or null) and re-apply for the current mode. */
export function setSeedColor(seed: string | null, mode?: ThemeMode): void {
  try {
    if (seed == null) {
      window.localStorage.removeItem(SEED_KEY);
      window.localStorage.removeItem(SEED_VARS_KEY);
      applySeedVars(null);
      return;
    }
    const t = readThemeMode(mode);
    const pack: Record<string, PaletteVars> = {
      light: buildPalette(seed, 'light'),
      mixed: buildPalette(seed, 'mixed'),
      dark: buildPalette(seed, 'dark'),
    };
    window.localStorage.setItem(SEED_KEY, seed);
    window.localStorage.setItem(SEED_VARS_KEY, JSON.stringify(pack));
    applySeedVars(pack[t]);
  } catch {
    /* private mode: palette lives for this visit only */
  }
}

export function readSeedColor(): string | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(SEED_KEY);
    return raw ? normalizeHex(raw) : null;
  } catch {
    return null;
  }
}

export function readThemeMode(forced?: ThemeMode): ThemeMode {
  if (forced) return forced;
  if (typeof window === 'undefined') return 'light';
  const t = window.localStorage.getItem('renance.theme');
  return t === 'mixed' || t === 'dark' ? t : 'light';
}

/** Mode switch (Light/Mixed/Dark): persist, flip the tier attribute and
 *  re-apply the stored seed palette for that tier. */
export function setThemeMode(mode: ThemeMode): void {
  try {
    window.localStorage.setItem('renance.theme', mode);
  } catch {
    /* private mode */
  }
  if (typeof document !== 'undefined') {
    document.documentElement.dataset.theme = mode;
  }
  const seed = readSeedColor();
  if (seed) {
    try {
      const pack = JSON.parse(window.localStorage.getItem(SEED_VARS_KEY) ?? 'null') as
        | Record<string, PaletteVars>
        | null;
      applySeedVars(pack?.[mode] ?? buildPalette(seed, mode));
    } catch {
      applySeedVars(buildPalette(seed, mode));
    }
  }
}

/** Preset swatches under the picker (the stitches' gem tones + Chrome set). */
export const SEED_PRESETS: Array<{ hex: string; name: string }> = [
  { hex: '#13dc1b', name: 'Renance Green' },
  { hex: '#1a73e8', name: 'Chrome Blue' },
  { hex: '#8b5cf6', name: 'Violet' },
  { hex: '#10b981', name: 'Emerald' },
  { hex: '#f59e0b', name: 'Amber' },
  { hex: '#f43f5e', name: 'Rose' },
  { hex: '#06b6d4', name: 'Cyan' },
  { hex: '#f97316', name: 'Orange' },
  { hex: '#6366f1', name: 'Indigo' },
  { hex: '#ec4899', name: 'Pink' },
];
