'use client';

/**
 * ContentGuard - the founder's content lock: nothing on the site is
 * selectable, copyable or drag-downloadable (notes, schemes of work,
 * questions, anything). Inputs, textareas and anything marked
 * data-allow-select stay interactive, so forms and the AI chat keep
 * working. Rendered once in the root layout; handlers passively block
 * the copy paths (copy, cut, drag, context menu) while keyboard
 * shortcuts stay untouched so the site remains fully navigable.
 */

import { useEffect } from 'react';

const GUARD_CSS = `
/* Renance content lock: selection off everywhere... */
.ren-guard, .ren-guard * {
  -webkit-user-select: none;
  -moz-user-select: none;
  user-select: none;
  -webkit-touch-callout: none;
}
/* ...except where typing or reading answers is the point. */
.ren-guard input,
.ren-guard textarea,
.ren-guard select,
.ren-guard [contenteditable="true"],
.ren-guard [data-allow-select],
.ren-guard [data-allow-select] * {
  -webkit-user-select: text;
  -moz-user-select: text;
  user-select: text;
  -webkit-touch-callout: default;
}
/* Images never drag out of the page. */
.ren-guard img {
  -webkit-user-drag: none;
  user-drag: none;
  pointer-events: none;
}
`;

export default function ContentGuard() {
  useEffect(() => {
    const root = document.body;
    root.classList.add('ren-guard');

    const isEditable = (el: EventTarget | null) => {
      if (!(el instanceof HTMLElement)) return false;
      if (el.closest('input, textarea, select, [contenteditable="true"], [data-allow-select]')) {
        return true;
      }
      return false;
    };

    const block = (e: Event) => {
      if (isEditable(e.target)) return;
      e.preventDefault();
    };

    document.addEventListener('copy', block);
    document.addEventListener('cut', block);
    document.addEventListener('dragstart', block);
    document.addEventListener('contextmenu', block);

    return () => {
      root.classList.remove('ren-guard');
      document.removeEventListener('copy', block);
      document.removeEventListener('cut', block);
      document.removeEventListener('dragstart', block);
      document.removeEventListener('contextmenu', block);
    };
  }, []);

  return <style dangerouslySetInnerHTML={{ __html: GUARD_CSS }} />;
}
