'use client';

/**
 * useTertiaryFocus: reactive read of the learning-focus flag.
 *
 * Returns null while the flag is unknown (fresh device, pre-login) and
 * after every change broadcast through setFocus(). Consumers hide the
 * GPA entry while null: the safe side is "not shown", because the flag
 * is written by the dashboard and the profile editor the moment the
 * student's desk is known.
 */

import { useEffect, useState } from 'react';

import { FOCUS_EVENT, Focus, getFocus } from './focus';

export function useTertiaryFocus(): Focus | null {
  const [focus, setLocal] = useState<Focus | null>(null);

  useEffect(() => {
    setLocal(getFocus());
    const read = () => setLocal(getFocus());
    window.addEventListener(FOCUS_EVENT, read);
    // A storage write from another tab also updates the flag.
    window.addEventListener('storage', read);
    return () => {
      window.removeEventListener(FOCUS_EVENT, read);
      window.removeEventListener('storage', read);
    };
  }, []);

  return focus;
}
