import { Suspense } from 'react';
import PricingClient from './pricing-client';

/**
 * Server wrapper: the client reads ?plan= deep links (a paywall "see all
 * plans" hop lands pre-opened) via useSearchParams, which needs a
 * Suspense boundary under static export.
 */
export default function PricingRoute() {
  return (
    <Suspense fallback={null}>
      <PricingClient />
    </Suspense>
  );
}
