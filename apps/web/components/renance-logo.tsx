'use client';

/**
 * Renance logomark, the ONLY loading/progress visual in the product.
 *
 * 2026-10-13 founder directive (Supreme splash pass): the flat breathing
 * mark + orbit arcs are RETIRED. The R now sits on a chunky 3D-flat
 * app-icon keycap - solid brand face, extruded darker bottom edge, soft
 * inner top highlight - exactly like the Supreme splash screen. While
 * data loads the keycap floats above the page (renance-float) with the
 * wordmark and a caption under it; no generic spinners, ever.
 *
 * The mark tile follows the live --color-primary token: green on the
 * student product, strict black inside the B&W school portal, purple in
 * the GGSA portal. `inverse` flips to a white keycap with the navy R
 * for dark panels (the landing's final CTA band).
 *
 * states:
 *  - idle    : the 3D keycap logo, static
 *  - busy    : keycap floats (Supreme splash motion)
 *  - grading : alias of busy (used by the CBT player while marking)
 */

import type { CSSProperties } from 'react';

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

type State = 'idle' | 'busy' | 'grading';

export function RenanceMark({
  size = 44,
  state = 'idle',
  inverse = false,
}: {
  size?: number;
  state?: State;
  inverse?: boolean;
}) {
  return (
    <span
      className={`renance-mark ${inverse ? 'renance-mark-inverse' : ''} ${
        state !== 'idle' ? 'renance-mark-busy' : ''
      }`}
      style={{ width: size, height: size, '--mark-size': `${size}px` } as CSSProperties}
      role="img"
      aria-label="Renance"
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`${BASE_PATH}/renance-mark${inverse ? '' : '-white'}.png`}
        width={size}
        height={size}
        alt=""
        aria-hidden
        className="renance-mark-glyph"
        draggable={false}
      />
    </span>
  );
}

/**
 * The full Supreme-style splash: floating keycap mark, wordmark, and a
 * friendly caption. Every "loading circle" in the product routes here.
 */
export function LogoActivityIndicator({
  state = 'busy',
  label,
  inverse = false,
}: {
  state?: State;
  label?: string;
  inverse?: boolean;
}) {
  return (
    <div className="renance-splash" role="status" aria-live="polite">
      <RenanceMark size={76} state={state} inverse={inverse} />
      <span className="renance-splash-word">renance</span>
      {label && <span className="renance-splash-caption">{label}</span>}
    </div>
  );
}
