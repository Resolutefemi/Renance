'use client';

/**
 * Renance logomark, the ONLY loading/progress visual in the product.
 *
 * 2026-10-13 founder directive (Supreme splash pass): the R sits on a
 * chunky 3D-flat app-icon keycap - solid brand face, extruded darker
 * bottom edge, glassy inner top highlight - exactly like the Supreme
 * splash screen. While data loads the keycap floats above the page
 * (renance-float) with the wordmark and a caption under it; no generic
 * spinners, ever.
 *
 * 2026-10-14 founder fix ("remove that white colour box"): the mark no
 * longer composites a PNG glyph over the CSS tile - the old stack put a
 * WHITE keycap PNG inside the green tile, which read as a white box on
 * the login/sign-up screens. The keycap is now ONE inline SVG whose
 * face, edge and letter all read the LIVE tokens:
 *
 *   face   = var(--color-primary)     → follows the appearance colour
 *   edge   = color-mix(primary 62%, black)
 *   letter = var(--color-on-primary)
 *
 * so a student who picks red in Settings → Appearance gets a red keycap
 * in the splash, the header and every loading state. `inverse` keeps the
 * fixed white keycap + navy R for dark panels (the landing's final CTA
 * band) and the school portals keep their pinned tokens automatically.
 *
 * states:
 *  - idle    : the 3D keycap logo, static
 *  - busy    : keycap floats (Supreme splash motion)
 *  - grading : alias of busy (used by the CBT player while marking)
 */

import { useId, type CSSProperties } from 'react';

type State = 'idle' | 'busy' | 'grading';

function KeycapGlyph({ inverse }: { inverse?: boolean }) {
  // React useId: every mark on a page gets its own gradient def, so
  // multiple keycaps (header + splash + button) never share an id.
  const gid = useId().replace(/[^a-zA-Z0-9_-]/g, '');
  const face = inverse ? '#ffffff' : 'var(--color-primary)';
  const edge = inverse
    ? '#d8d8de'
    : 'color-mix(in srgb, var(--color-primary) 62%, #000000)';
  const letter = inverse ? '#111c2d' : 'var(--color-on-primary)';
  return (
    <svg viewBox="0 0 64 64" className="renance-mark-svg" aria-hidden focusable="false">
      <defs>
        <linearGradient id={`khl-${gid}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ffffff" stopOpacity={inverse ? 0.9 : 0.3} />
          <stop offset="1" stopColor="#ffffff" stopOpacity="0" />
        </linearGradient>
      </defs>
      {/* extruded bottom edge (behind the face) */}
      <rect x="3" y="3" width="58" height="58" rx="15" fill={edge} />
      {/* face, lifted up to reveal the edge */}
      <rect x="3" y="3" width="58" height="50" rx="15" fill={face} />
      {/* glassy top lip */}
      <rect x="9" y="9" width="46" height="27" rx="10" fill={`url(#khl-${gid})`} />
      {/* the letter */}
      <text
        x="32"
        y="42.5"
        textAnchor="middle"
        fontFamily="Nunito, 'Arial Rounded MT Bold', Arial, sans-serif"
        fontWeight={900}
        fontSize="38"
        fill={letter}
      >
        R
      </text>
    </svg>
  );
}

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
      <KeycapGlyph inverse={inverse} />
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
