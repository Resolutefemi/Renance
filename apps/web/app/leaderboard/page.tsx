import { Suspense } from 'react';
import LeaderboardClient from './leaderboard-client';

/**
 * Server wrapper: the client reads ?tab= (deep links like
 * /leaderboard?tab=daily land straight on the right board) via
 * useSearchParams, which needs a Suspense boundary under static export.
 */
export default function LeaderboardRoute() {
  return (
    <Suspense fallback={null}>
      <LeaderboardClient />
    </Suspense>
  );
}
