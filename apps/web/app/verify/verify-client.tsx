'use client';

/**
 * VerifyClient - the /verify page. FOUNDER DIRECTIVE 2026-10-05: email
 * confirmation is a 6-digit CODE typed into this card, not a mailed
 * link - so the page now hosts the same code entry the register and
 * login flows use. Anyone arriving from an old confirmation link, or
 * opening /verify directly, types the code here; the card upgrades the
 * restricted session server-side and offers the Continue hop.
 */

import ConfirmEmailCard from '@/components/confirm-email-card';

export default function VerifyClient() {
  return <ConfirmEmailCard />;
}
