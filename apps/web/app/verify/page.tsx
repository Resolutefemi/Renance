import { Suspense } from 'react';
import VerifyClient from './verify-client';

/**
 * Server wrapper for the /verify page: the 6-digit code entry (founder
 * directive 2026-10-05, the mailed-link era is over). The Suspense
 * boundary stays so the static export keeps the client boundary happy
 * for anyone still landing here from an old link.
 */
export default function VerifyRoute() {
  return (
    <Suspense fallback={null}>
      <VerifyClient />
    </Suspense>
  );
}
