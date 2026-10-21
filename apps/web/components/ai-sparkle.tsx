/**
 * AiSparkle: the house AI glyph - the curved four-point sparkle the
 * flagship AI products use (Gemini, Copilot), not a generic robot.
 * Drawn as inline SVG with currentColor so it sits on black, white or
 * any accent without a second asset. Two stars: the big sparkle and a
 * small companion, the "two thoughts" composition.
 *
 * Used by the floating Renance AI button on the home desk and inside
 * the AI Studio (header, empty state, composer).
 */
export default function AiSparkle({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Main sparkle: curved four-point star through the center */}
      <path d="M12 1.5q1.5 9 10.5 10.5Q13.5 13.5 12 22.5 10.5 13.5 1.5 12 10.5 10.5 12 1.5Z" />
      {/* Companion sparkle, top right */}
      <path d="M18.6 2.4q.7 3.4 4.1 4.1-3.4.7-4.1 4.1-.7-3.4-4.1-4.1 3.4-.7 4.1-4.1Z" />
    </svg>
  );
}
