'use client';

/**
 * BlueTick - the premium verified badge, X-style. The ONE splash of
 * colour a monochrome product allows: a paid subscriber's name carries
 * the tick on leaderboards, the arena, the profile and the paywall.
 */

interface Props {
  /** Size in px for the badge glyph. */
  size?: number;
  className?: string;
}

export default function BlueTick({ size = 16, className = '' }: Props) {
  return (
    <span
      title="Renance Premium"
      aria-label="Renance Premium verified"
      className={`inline-flex shrink-0 items-center justify-center ${className}`}
    >
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden
        style={{ display: 'block' }}
      >
        <path
          d="M12 1.5 14.8 4l3.7-.5 1 3.6 3.2 1.9-1.6 3.4 1.6 3.4-3.2 1.9-1 3.6-3.7-.5L12 22.5 9.2 20l-3.7.5-1-3.6L1.3 15l1.6-3.4L1.3 8.2l3.2-1.9 1-3.6L9.2 4 12 1.5Z"
          fill="#1D9BF0"
        />
        <path
          d="M8.2 12.4l2.5 2.5 5-5.2"
          stroke="#fff"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}
