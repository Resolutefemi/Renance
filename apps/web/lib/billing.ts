'use client';

/**
 * Billing client: the plan catalog, the Paystack handoff and the REN
 * redemption table. Every amount is Naira; the API owns the truth and
 * gracefully reports when card payments are still being connected (the
 * WhatsApp line takes over).
 */

import { api } from './api';

export interface PremiumPlan {
  code: string;
  label: string;
  amountNaira: number;
  amountKobo: number;
  durationDays: number;
  perks: string;
}

export interface Redemption {
  code: string;
  label: string;
  coins: number;
  durationDays: number;
}

export interface PlanCatalog {
  plans: PremiumPlan[];
  redemptions: Redemption[];
  freePreviewQuestions: number;
  paystackEnabled: boolean;
  whatsapp: string;
}

export interface Entitlement {
  userId: string;
  premiumRole: boolean;
  premiumType: string;
  premiumExpiresAt?: string | null;
  renCoins: number;
  emailVerified: boolean;
  firstFreeCbt: boolean;
  referralCode?: string;
}

/** The full plan catalog (public - the paywall renders pre-login). */
export function fetchPlans(): Promise<PlanCatalog> {
  return api<PlanCatalog>('/billing/plans', { auth: false, noRedirect: true });
}

/** The signed-in student's entitlement row (/me carries it). */
export function fetchEntitlement(): Promise<Entitlement> {
  return api<{ entitlement: Entitlement }>('/me').then((r) => r.entitlement);
}

/** Starts a Paystack charge; resolves to the hosted checkout URL. */
export function initializePaystack(plan: string): Promise<{ reference: string; authorizationUrl: string }> {
  return api<{ reference: string; authorizationUrl: string }>('/billing/paystack/initialize', {
    method: 'POST',
    body: { plan },
  });
}

/** Exchanges REN coins for premium days. */
export function redeemWithCoins(code: string): Promise<{ entitlement: Entitlement }> {
  return api<{ entitlement: Entitlement }>('/billing/redeem', {
    method: 'POST',
    body: { code },
  });
}

export const naira = (n: number) => `₦${n.toLocaleString('en-NG')}`;
