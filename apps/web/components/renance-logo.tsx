'use client';

/**
 * Renance logomark — the ONLY loading/progress visual in the product.
 * (Founder spec: "Standard circular progress indicators are completely
 * replaced with a custom vectorized animation of the Renance logomark,
 * pulsing and shifting opacities dynamically during background fetching
 * or data processing states." — Bybit-style brand transition.)
 *
 * states:
 *  - idle    : the mark breathes softly
 *  - busy    : mark breathes fast + three orbit arcs chase each other
 *  - grading : same as busy with a violet shift (used by the CBT player)
 */

type State = 'idle' | 'busy' | 'grading';

export function RenanceMark({
  size = 44,
  state = 'idle',
}: {
  size?: number;
  state?: State;
}) {
  const breathe = state === 'idle' ? 'renance-breathe' : 'renance-breathe-fast';
  const arcClass =
    state === 'idle' ? '' : 'renance-orbit';
  return (
    <span
      className="relative inline-flex items-center justify-center align-middle"
      style={{ width: size, height: size }}
    >
      {/* orbit arcs — only while busy */}
      {state !== 'idle' && (
        <svg
          viewBox="0 0 64 64"
          width={size}
          height={size}
          className="absolute inset-0"
          aria-hidden
        >
          <g className={arcClass}>
            <circle
              cx="32" cy="32" r="29" fill="none"
              stroke={state === 'grading' ? '#a78bfa' : '#34d399'}
              strokeWidth="2.5" strokeLinecap="round"
              strokeDasharray="18 40" className="renance-arc-1"
              transform="rotate(0 32 32)"
            />
            <circle
              cx="32" cy="32" r="29" fill="none"
              stroke={state === 'grading' ? '#a78bfa' : '#34d399'}
              strokeWidth="2.5" strokeLinecap="round"
              strokeDasharray="18 40" className="renance-arc-2"
              transform="rotate(120 32 32)"
            />
            <circle
              cx="32" cy="32" r="29" fill="none"
              stroke={state === 'grading' ? '#a78bfa' : '#34d399'}
              strokeWidth="2.5" strokeLinecap="round"
              strokeDasharray="18 40" className="renance-arc-3"
              transform="rotate(240 32 32)"
            />
          </g>
        </svg>
      )}

      {/* the mark itself */}
      <svg
        viewBox="0 0 64 64"
        width={size * 0.78}
        height={size * 0.78}
        className={breathe}
        role="img"
        aria-label="Renance"
      >
        <defs>
          <linearGradient id="renance-tile" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#8b5cf6" />
            <stop offset="100%" stopColor="#10b981" />
          </linearGradient>
        </defs>
        <rect x="2" y="2" width="60" height="60" rx="16" fill="url(#renance-tile)" />
        <path
          d="M22 47 V17 H34 a9.5 9.5 0 0 1 0 19 H22 M35 36 L47 47"
          fill="none"
          stroke="#ffffff"
          strokeWidth="6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

export function LogoActivityIndicator({
  state = 'busy',
  label,
}: {
  state?: State;
  label?: string;
}) {
  return (
    <div className="flex items-center gap-3">
      <RenanceMark size={40} state={state} />
      {label && (
        <span className="text-sm text-on-surface-variant">{label}</span>
      )}
    </div>
  );
}
