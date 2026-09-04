'use client';

/**
 * Renance logomark, the ONLY loading/progress visual in the product.
 * (Founder spec: "Standard circular progress indicators are completely
 * replaced with a custom animation of the Renance logomark, pulsing and
 * shifting opacities dynamically during background fetching or data
 * processing states.", Bybit-style brand transition.)
 *
 * The mark itself is the official Stitch brand sheet extraction
 * (design/stitch/screen.png, R cut out with a transparent background by
 * scripts/make_brand.py). Two tones ship: the ink navy original for light
 * surfaces and a white cut for dark containers (`inverse`).
 *
 * states:
 *  - idle    : the mark breathes softly
 *  - busy    : mark breathes fast + three emerald orbit arcs chase each other
 *  - grading : alias of busy (used by the CBT player while marking)
 */

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
  const breathe = state === 'idle' ? 'renance-breathe' : 'renance-breathe-fast';
  return (
    <span
      className="relative inline-flex items-center justify-center align-middle"
      style={{ width: size, height: size }}
    >
      {/* orbit arcs, only while busy */}
      {state !== 'idle' && (
        <svg
          viewBox="0 0 64 64"
          width={size}
          height={size}
          className="absolute inset-0 renance-orbit"
          aria-hidden
        >
          <circle cx="32" cy="32" r="29" fill="none" stroke="#34d399"
            strokeWidth="2.5" strokeLinecap="round" strokeDasharray="18 40"
            className="renance-arc-1" />
          <circle cx="32" cy="32" r="29" fill="none" stroke="#34d399"
            strokeWidth="2.5" strokeLinecap="round" strokeDasharray="18 40"
            className="renance-arc-2" transform="rotate(120 32 32)" />
          <circle cx="32" cy="32" r="29" fill="none" stroke="#34d399"
            strokeWidth="2.5" strokeLinecap="round" strokeDasharray="18 40"
            className="renance-arc-3" transform="rotate(240 32 32)" />
        </svg>
      )}

      {/* the mark itself */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`${BASE_PATH}/renance-mark${inverse ? '-white' : ''}.png`}
        width={size * 0.86}
        height={size * 0.86}
        alt="Renance"
        role="img"
        className={breathe}
        draggable={false}
      />
    </span>
  );
}

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
    <div className="flex items-center gap-3">
      <RenanceMark size={40} state={state} inverse={inverse} />
      {label && (
        <span className="text-sm text-on-surface-variant">{label}</span>
      )}
    </div>
  );
}
