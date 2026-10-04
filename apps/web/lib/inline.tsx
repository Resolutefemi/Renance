import type { ReactNode } from 'react';

/**
 * Renders the lesson inline markers (**bold**, *italic*, `code`) into
 * React nodes. Lesson text is linted HTML-free at build time, so this
 * renderer is the ONLY styling path, there is no HTML injection
 * surface anywhere in the lessons pipeline.
 */
export function renderInline(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  // order matters: ** before *, ` spans both
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let key = 0;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) nodes.push(text.slice(last, m.index));
    const token = m[0];
    if (token.startsWith('**')) {
      nodes.push(<strong key={key++} className="font-semibold text-on-surface">{token.slice(2, -2)}</strong>);
    } else if (token.startsWith('`')) {
      nodes.push(
        <code key={key++} className="rounded bg-surface-container-low px-1 py-0.5 font-mono text-[0.9em]">
          {token.slice(1, -1)}
        </code>,
      );
    } else {
      nodes.push(<em key={key++}>{token.slice(1, -1)}</em>);
    }
    last = m.index + token.length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}
