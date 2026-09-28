'use client';

/**
 * VerifyGate - email confirmation gate.
 *
 * HIDDEN per founder directive (2026-09): the confirmation mails do not
 * leave the server yet (SMTP credentials are not configured on Render),
 * so a strict gate would lock every manual signup out of the product.
 * The component is a pass-through until SMTP goes live; restore by
 * reverting the early return (git history keeps the full gate UI,
 * including the resend button and cooldown handling).
 */

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { getToken as readToken } from '@/lib/session';

export function useEmailVerified(): boolean | null {
  const [verified, setVerified] = useState<boolean | null>(null);
  useEffect(() => {
    let alive = true;
    if (!readToken()) {
      setVerified(true); // the page's own auth guard handles the redirect
      return;
    }
    api<{ entitlement?: { emailVerified?: boolean } }>('/me')
      .then((r) => alive && setVerified(r.entitlement?.emailVerified !== false))
      .catch(() => alive && setVerified(true)); // API down: never lock the desk
    return () => {
      alive = false;
    };
  }, []);
  return verified;
}

export default function VerifyGate({ children }: { children: React.ReactNode }) {
  // Feature hidden for now: mails cannot be sent, so never block the desk.
  return <>{children}</>;
}
