'use client';

/**
 * ActivityHeartbeat: one presence ping per minute while the tab is
 * visible. Feeds the admin dashboard's "active now / used today /
 * most time on Renance" surfaces. Deliberately streak-neutral - the
 * founder doctrine: streaks move on quiz/lesson activity ONLY, never
 * on opening the app.
 *
 * Mounted once from the root layout; a no-op when nobody is signed in
 * (the API call simply 401s into the void with no redirect).
 */

import { useEffect } from 'react';
import { sendHeartbeat } from '@/lib/learn';
import { getToken } from '@/lib/session';

export default function ActivityHeartbeat() {
  useEffect(() => {
    if (!getToken()) return;

    let secondsVisible = 0;
    let stopped = false;

    const tick = setInterval(() => {
      if (stopped) return;
      if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return;
      secondsVisible += 60;
      if (secondsVisible < 60) return;
      const chunk = Math.min(secondsVisible, 180);
      secondsVisible = 0;
      // Fire-and-forget: a missed ping is presence noise, not an error.
      void sendHeartbeat(chunk).catch(() => undefined);
    }, 60_000);

    const onLeave = () => {
      // Flush what we have when the tab hides or the page goes away.
      if (secondsVisible <= 0) return;
      const chunk = Math.min(secondsVisible, 180);
      secondsVisible = 0;
      void sendHeartbeat(chunk).catch(() => undefined);
    };

    document.addEventListener('visibilitychange', onLeave);
    window.addEventListener('pagehide', onLeave);
    return () => {
      stopped = true;
      clearInterval(tick);
      document.removeEventListener('visibilitychange', onLeave);
      window.removeEventListener('pagehide', onLeave);
      onLeave();
    };
  }, []);

  return null;
}
