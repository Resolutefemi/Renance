'use client';

/**
 * Renance Appearance engine - the Chrome-style colour theming the
 * founder asked for ("all the black colours in the website or app can
 * be easily changed to any colour students want, under settings, like
 * Chrome appearance settings").
 *
 * A seed colour is expanded into the full token palette (surfaces,
 * containers, ink, primaries, outlines, hero chrome) for each appearance
 * tier - Light, Mixed, Dark - and written as CSS custom properties on
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

/** WCAG-ish relative luminance (0 black → 1 white), exported for tests. */
export function luminance(hex: string): number {
  const body = hex.replace('#', '');
  const ch = [0, 2, 4].map((i) => {
    const v = parseInt(body.slice(i, i + 2), 16) / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
}

/**
 * The founder's button-text rule (2026-10-02): coloured buttons carry
 * WHITE text - pure red, green, blue, every vivid tone. Black text only
 * on genuinely LIGHT colours (pale pastels, creams, yellows) where a
 * white label would disappear. Lightness-led with a luma guard (HSL
 * lightness misreads yellow - l=50 yet blinding) and a saturation guard
 * so vivid mid-lightness tones (amber, rose, orange) keep white labels.
 * This is what makes a red Continue button read white-on-red in every
 * tier instead of black-on-pink.
 */
function wantsDarkText(hex: string): boolean {
  const { s, l } = hexToHsl(hex);
  return l >= 68 || luminance(hex) >= 0.55 || (l >= 52 && s < 35);
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
    // Founder directive 2026-10-15 (evening): every dark surface is a
    // FIXED near-black - the seed no longer tints the dark backgrounds.
    // "All the black colours can be changed" now means the ACCENT only:
    // primary / hero CTA / inverse chrome follow the seed, the canvas
    // stays the same calm near-black under every palette. The constants
    // mirror [data-theme='dark'] in globals.css exactly, so seeded and
    // seedless students see the identical dark chrome.
    vars['--color-background'] = '#0f1216';
    vars['--color-surface'] = '#0f1216';
    vars['--color-surface-bright'] = '#161b22';
    vars['--color-surface-dim'] = '#0a0d11';
    vars['--color-surface-container-lowest'] = '#0c0f14';
    vars['--color-card'] = '#131720';
    vars['--color-surface-container-low'] = '#11151c';
    vars['--color-surface-container'] = '#151a22';
    vars['--color-surface-container-high'] = '#191f28';
    vars['--color-surface-container-highest'] = '#1d242e';
    vars['--color-surface-variant'] = '#191f28';
    vars['--color-on-background'] = '#f0f3f6';
    vars['--color-on-surface'] = '#f0f3f6';
    vars['--color-on-surface-variant'] = '#a6adba';
    // the seed lights up as the accent on dark
    const primary = hslToHex(hue, sat, Math.min(76, Math.max(58, l0(seedHex))));
    vars['--color-primary'] = primary;
    vars['--color-on-primary'] = wantsDarkText(primary) ? hslToHex(hue, 42, 10) : '#ffffff';
    vars['--color-primary-container'] = '#151a22';
    vars['--color-on-primary-container'] = '#f0f3f6';
    vars['--color-secondary'] = '#a6adba';
    vars['--color-secondary-container'] = '#11151c';
    vars['--color-on-secondary-container'] = '#f0f3f6';
    vars['--color-outline'] = '#a6adba';
    vars['--color-outline-variant'] = '#363d49';
    vars['--color-outline-light'] = vars['--color-outline-variant'];
    vars['--color-selection-blue'] = '#1a212b';
    // the sidebar row hover wash: a low-opacity translucent surface,
    // never the light tier's #f7f7f7 polar (white flash on dark).
    vars['--color-polar'] = 'rgba(240, 243, 255, 0.07)';
    vars['--color-hero'] = '#131720';
    vars['--color-on-hero'] = '#f0f3f6';
    vars['--color-hero-muted'] = '#a6adba';
    vars['--color-hero-track'] = '#191f28';
    vars['--color-hero-cta'] = primary;
    vars['--color-on-hero-cta'] = vars['--color-on-primary'];
    // accent-ink is the SCRIM/dark-ink colour (bg-accent-ink/40 modal
    // washes, dark chips): it stays a fixed dark neutral in the dark
    // tier - only its hue-tint is dropped, the seed never repaints it.
    vars['--color-accent-ink'] = '#242c38';
    vars['--color-ink-deep'] = '#161c26';
    vars['--color-dark-surface'] = vars['--color-ink-deep'];
    vars['--color-dark-surface-low'] = '#131820';
    vars['--color-inverse-surface'] = hslToHex(hue, 40, 88);
    vars['--color-inverse-on-surface'] = hslToHex(hue, 35, 12);
    return vars;
  }

  // Light body (also the base of Mixed); the seed tints the neutrals and
  // drives the primary actions - the "black" becomes the student's colour.
  // Founder directive (2026-10-02): the primary keeps the seed's OWN
  // lightness (clamped to a readable 42-58 band) so a pure red stays
  // PURE RED - never the deep #B80000 the old 30-46 clamp produced - and
  // slider-picked light/deep variants stay recognisable.
  const primary = hslToHex(hue, sat, Math.min(58, Math.max(42, l0(seedHex))));
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
  vars['--color-on-primary'] = wantsDarkText(primary) ? hslToHex(hue, 42, 12) : '#ffffff';
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
    // dark hero chrome over the light body, tinted with the same seed.
    // The hero CTA keeps the seed's own lightness in a 44-62 band - a
    // pure red stays PURE RED on the dark hero (the old 58-76 lift
    // washed it to pink and flipped the label to black) - and the
    // founder's white-label rule keeps the text white on every vivid
    // tone.
    vars['--color-hero'] = hslToHex(hue, 40, 12);
    vars['--color-on-hero'] = hslToHex(hue, 60, 96);
    vars['--color-hero-muted'] = hslToHex(hue, 20, 72);
    vars['--color-hero-track'] = hslToHex(hue, 30, 16);
    vars['--color-hero-cta'] = hslToHex(hue, sat, Math.min(62, Math.max(44, l0(seedHex))));
    vars['--color-on-hero-cta'] = wantsDarkText(vars['--color-hero-cta'])
      ? hslToHex(hue, 42, 10)
      : '#ffffff';
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

/** Every CSS custom property one seed repaints. Exported so surfaces
 *  that opt OUT of the seed (the landing page keeps the default
 *  palette, founder directive 2026-10-05) can strip exactly these
 *  keys from <html> and restore them on the way out. */
export const THEME_KEYS = Object.keys(buildPalette('#13dc1b', 'dark'));

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
  // Mixed mode is retired (founder 2026-10-13): any stored 'mixed'
  // lands on light so nobody keeps a zombie tier after the removal.
  return t === 'dark' ? 'dark' : 'light';
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

/** Preset swatches under the picker (the stitches' gem tones + Chrome set).
 *  Renance Green follows the founder's 2026-10-15 default (#10da11). */
export const SEED_PRESETS: Array<{ hex: string; name: string }> = [
  { hex: '#10da11', name: 'Renance Green' },
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
