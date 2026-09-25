import { Suspense } from 'react';
import VerifyClient from './verify-client';

/**
 * Server wrapper: the confirmation link lands here with ?token=…&return=…
 * (web or app), which needs a Suspense boundary under static export.
 */
export default function VerifyRoute() {
  return (
    <Suspense fallback={null}>
      <VerifyClient />
    </Suspense>
  );
}
