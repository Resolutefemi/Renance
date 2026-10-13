'use client';

/**
 * /shop — RETIRED as a standalone tab (founder directive 2026-10-14
 * evening pass: "the shop feature should be under profile and the
 * heart read too"). The shop now lives inside the profile page; this
 * route keeps every stale link and gem chip working by walking the
 * student straight there.
 */

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function ShopRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace('/profile#shop');
  }, [router]);
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-3 bg-background">
      <span className="material-symbols-outlined text-[32px] text-primary">storefront</span>
      <p className="text-[13.5px] font-bold text-on-surface-variant">The shop moved to your profile…</p>
    </main>
  );
}
