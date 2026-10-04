import { Suspense } from 'react';
import AiClient from './ai-client';

/**
 * Server wrapper: /ai reads no query params today, but the Suspense
 * boundary keeps the static export contract uniform with the other
 * client-first routes.
 */
export default function AiRoute() {
  return (
    <Suspense fallback={null}>
      <AiClient />
    </Suspense>
  );
}
