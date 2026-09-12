'use client';

/**
 * AppearancePanel — the Stitch "Renance Learning OS" theme screen,
 * 1:1 with the founder's mock: a Mode segmented control (Light / Mixed
 * / Dark) and a Seed Colour section. The seed drives a Chrome-style
 * colour picker — a saturation/brightness field, a rainbow hue rail,
 * preset swatches and a hex box — and every black/ink surface in the
 * product re-tints live (lib/theme.ts paints the token palette).
 */

import { useEffect, useRef, useState } from 'react';
import {
  SEED_PRESETS,
  hexToHsl,
  hslToHex,
  normalizeHex,
  readSeedColor,
  setSeedColor,
  setThemeMode,
  type ThemeMode,
} from '@/lib/theme';

const MODES: Array<{ value: ThemeMode; icon: string; label: string }> = [
  { value: 'light', icon: 'light_mode', label: 'Light' },
  { value: 'mixed', icon: 'contrast', label: 'Mixed' },
  { value: 'dark', icon: 'dark_mode', label: 'Dark' },
];

export default function AppearancePanel({ mode, onMode }: { mode: ThemeMode; onMode: (m: ThemeMode) => void }) {
  const [seed, setSeed] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [hexDraft, setHexDraft] = useState('#13dc1b');

  useEffect(() => {
    const s = readSeedColor();
    setSeed(s);
    setHexDraft(s ?? '#13dc1b');
  }, []);

  function apply(hex: string | null) {
    const next = hex ? normalizeHex(hex) : null;
    setSeed(next);
    if (next) setHexDraft(next);
    setSeedColor(next);
  }

  const hsl = hexToHsl(seed ?? '#13dc1b');

  return (
    <section className="mt-6 flex flex-col gap-4 rounded-[12px] bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
      {/* Mode ---------------------------------------------------------- */}
      <div className="flex items-center gap-3">
        <span className="material-symbols-outlined text-on-surface-variant">brightness_medium</span>
        <div>
          <h2 className="text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">Mode</h2>
          <p className="text-[13px] text-on-surface-variant">Light, Mixed or Dark, saved to this device</p>
        </div>
      </div>
      <div className="flex gap-2">
        {MODES.map((o) => {
          const selected = mode === o.value;
          return (
            <button
              key={o.value}
              type="button"
              onClick={() => {
                onMode(o.value);
                setThemeMode(o.value);
              }}
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

      {/* Seed colour --------------------------------------------------- */}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="mt-1 flex items-center gap-3"
      >
        <span className="material-symbols-outlined text-on-surface-variant">palette</span>
        <span className="flex-1 text-left">
          <span className="block text-[18px] font-semibold leading-6 tracking-[-0.01em] text-on-surface">
            Seed Color
          </span>
          <span className="block text-[13px] text-on-surface-variant">
            Re-tints every surface, like Chrome appearance
          </span>
        </span>
        <span className={`material-symbols-outlined text-outline transition-transform ${open ? 'rotate-180' : ''}`}>
          expand_more
        </span>
      </button>

      {open && (
        <div className="flex flex-col gap-4">
          {/* current colour row */}
          <div className="flex items-center gap-3 rounded-[10px] bg-surface-container-low px-4 py-3">
            <span
              className="h-9 w-9 shrink-0 rounded-full border border-outline-variant/60 shadow-inner"
              style={{ background: seed ?? hslToHex(hsl.h, hsl.s, hsl.l) }}
            />
            <span className="flex-1">
              <span className="block text-[15px] font-semibold text-on-surface">
                {seed ? seed.toUpperCase() : 'Renance default'}
              </span>
              <span className="block text-[12px] text-on-surface-variant">
                {seed ? 'Custom tint active' : 'The classic ink and paper look'}
              </span>
            </span>
            {seed && (
              <button
                type="button"
                onClick={() => apply(null)}
                className="rounded-lg border border-outline-variant px-3 py-1.5 text-[12px] font-semibold text-on-surface-variant hover:bg-surface-container"
              >
                Reset
              </button>
            )}
          </div>

          {/* preset swatches */}
          <div className="flex flex-wrap gap-2.5">
            {SEED_PRESETS.map((p) => (
              <button
                key={p.hex}
                type="button"
                title={p.name}
                aria-label={p.name}
                onClick={() => apply(p.hex)}
                className={`h-9 w-9 rounded-full border-2 transition-transform hover:scale-110 ${
                  seed?.toLowerCase() === p.hex ? 'border-on-surface' : 'border-transparent'
                }`}
                style={{ background: p.hex }}
              />
            ))}
          </div>

          {/* saturation × brightness field */}
          <SaturationField
            hue={hsl.h}
            s={hsl.s}
            l={hsl.l}
            onChange={(s, l) => apply(hslToHex(hsl.h, s, l))}
          />

          {/* hue rail */}
          <HueRail
            hue={hsl.h}
            s={hsl.s}
            l={hsl.l}
            onChange={(h) => {
              // keep the pick visible when the old colour sat at an extreme
              const nextL = hsl.l > 96 || hsl.l < 4 ? 50 : hsl.l;
              apply(hslToHex(h, Math.max(hsl.s, 45), nextL));
            }}
          />

          {/* hex box */}
          <div className="flex items-center gap-3 rounded-[10px] bg-surface-container-low px-3 py-2">
            <span
              className="h-6 w-6 shrink-0 rounded-full border border-outline-variant/60"
              style={{ background: seed ?? hslToHex(hsl.h, hsl.s, hsl.l) }}
            />
            <span className="font-mono text-[15px] text-on-surface-variant">#</span>
            <input
              value={hexDraft.replace(/^#/, '')}
              onChange={(e) => {
                const v = e.target.value.replace(/[^0-9a-fA-F]/g, '').slice(0, 6);
                setHexDraft(`#${v}`);
                if (v.length === 6 || v.length === 3) apply(`#${v}`);
              }}
              spellCheck={false}
              aria-label="Seed colour hex"
              className="w-full bg-transparent font-mono text-[15px] uppercase text-on-surface outline-none"
              placeholder="13DC1B"
            />
          </div>
        </div>
      )}
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* the two-picker Chrome colour field                                  */
/* ------------------------------------------------------------------ */

/** 2D saturation (→) × brightness (↑) field with a draggable thumb. */
function SaturationField({
  hue,
  s,
  l,
  onChange,
}: {
  hue: number;
  s: number;
  l: number;
  onChange: (s: number, l: number) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const drag = useRef(false);

  function emit(e: React.PointerEvent | PointerEvent) {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
    const y = Math.min(1, Math.max(0, (e.clientY - r.top) / r.height));
    onChange(Math.round(x * 100), Math.round((1 - y) * 100));
  }

  return (
    <div
      ref={ref}
      role="slider"
      aria-label="Saturation and brightness"
      aria-valuetext={`saturation ${Math.round(s)}, brightness ${Math.round(l)}`}
      className="relative h-44 w-full cursor-crosshair touch-none overflow-hidden rounded-[10px] border border-outline-variant/50"
      style={{
        background: `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, hsl(${hue} 100% 50%))`,
      }}
      onPointerDown={(e) => {
        drag.current = true;
        e.currentTarget.setPointerCapture(e.pointerId);
        emit(e);
      }}
      onPointerMove={(e) => {
        if (drag.current) emit(e);
      }}
      onPointerUp={() => {
        drag.current = false;
      }}
    >
      <span
        className="pointer-events-none absolute h-5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-[3px] border-white shadow-[0_0_0_1px_rgba(0,0,0,0.45)]"
        style={{ left: `${s}%`, top: `${100 - l}%` }}
      />
    </div>
  );
}

/** The rainbow hue rail with a circular thumb. */
function HueRail({
  hue,
  s,
  l,
  onChange,
}: {
  hue: number;
  s: number;
  l: number;
  onChange: (h: number) => void;
}) {
  return (
    <input
      type="range"
      min={0}
      max={360}
      value={Math.round(hue)}
      aria-label="Hue"
      onChange={(e) => onChange(Number(e.target.value))}
      className="h-4 w-full cursor-pointer appearance-none rounded-full outline-none [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border-[3px] [&::-webkit-slider-thumb]:border-white [&::-webkit-slider-thumb]:shadow-[0_0_0_1px_rgba(0,0,0,0.45)] [&::-moz-range-thumb]:h-5 [&::-moz-range-thumb]:w-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border-[3px] [&::-moz-range-thumb]:border-white"
      style={{
        background:
          'linear-gradient(to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%)',
      }}
    />
  );
}
