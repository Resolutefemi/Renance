'use client';

/**
 * The old arena match page. The arena is one surface now - matchmaking,
 * invites, challenges and the duel itself all live on /arena over a
 * single socket (a route change mid-match would drop the connection and
 * forfeit the duel). Everyone lands on the floor.
 */

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function ArenaMatchRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace('/arena');
  }, [router]);
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
      <p className="text-sm text-on-surface-variant">Heading to the arena floor…</p>
    </main>
  );
}
