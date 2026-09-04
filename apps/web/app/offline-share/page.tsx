'use client';

/**
 * Offline share, the Stitch offline_share_light screen.
 * Send Pack / Receive cards, the nearby-phone radar (the extracted R mark
 * at the center, orbiting ink dot) and the Devices Found row. Static
 * friendly: discovery is simulated locally, Connect is a stub until the
 * peer channel ships.
 */

import { useEffect, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

export default function OfflineSharePage() {
  const [angle, setAngle] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setAngle((a) => (a + 2) % 360), 33);
    return () => clearInterval(t);
  }, []);

  const radius = 132;
  const rad = (angle * Math.PI) / 180;

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-2xl flex-col px-4 pb-0 sm:px-6">
      <div className="pt-4">
        <PageBar title="Offline Share" />
      </div>
      <p className="mt-2 text-[15px] leading-snug text-on-surface-variant">
        Share study packs without an internet connection.
      </p>

      <div className="mt-5 grid grid-cols-2 gap-3">
        <button className="rounded-2xl bg-card py-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition active:scale-[0.98]">
          <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-surface-container-low">
            <span className="material-symbols-outlined text-[26px] text-on-surface">arrow_upward</span>
          </span>
          <span className="mt-3.5 block text-[17px] font-semibold text-on-surface">Send Pack</span>
        </button>
        <button className="rounded-2xl bg-card py-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition active:scale-[0.98]">
          <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-surface-container-low">
            <span className="material-symbols-outlined text-[26px] text-on-surface">arrow_downward</span>
          </span>
          <span className="mt-3.5 block text-[17px] font-semibold text-on-surface">Receive</span>
        </button>
      </div>

      {/* radar */}
      <div className="relative mx-auto my-6 h-[340px] w-full max-w-[360px] flex-1">
        {[100, 186, 272].map((d) => (
          <span
            key={d}
            className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-surface-variant"
            style={{ width: d, height: d }}
          />
        ))}
        <span
          className="absolute left-1/2 top-1/2 h-3.5 w-3.5 rounded-full bg-primary"
          style={{
            transform: `translate(calc(-50% + ${Math.cos(rad) * radius}px), calc(-50% + ${Math.sin(rad) * radius}px))`,
          }}
        />
        <div className="absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center">
          <span className="flex h-[84px] w-[84px] items-center justify-center rounded-full bg-card shadow-[0_8px_18px_0_rgba(17,28,45,0.10)]">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/renance-mark.png`}
              alt="Renance"
              className="h-11 w-11"
            />
          </span>
          <p className="mt-4 text-center text-[15px] text-on-surface-variant">
            Looking for nearby Renance phones...
          </p>
        </div>
      </div>

      {/* devices sheet */}
      <section className="sticky bottom-20 rounded-t-3xl bg-card p-4 pb-6 shadow-[0_-8px_24px_0_rgba(17,28,45,0.12)]">
        <span className="mx-auto block h-1.5 w-11 rounded-full bg-surface-container-high" />
        <h2 className="mt-3.5 text-lg font-semibold tracking-tight text-on-surface">Devices Found</h2>
        <div className="mt-3 flex items-center gap-3 rounded-2xl bg-surface-container-low p-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-container-high">
            <span className="material-symbols-outlined text-[22px] text-on-surface">smartphone</span>
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[15px] font-semibold text-on-surface">Alex&apos;s iPhone</span>
            <span className="block text-[13px] text-on-surface-variant">Ready to connect</span>
          </span>
          <button className="h-11 rounded-xl bg-primary px-5 text-sm font-semibold text-on-primary transition active:scale-[0.97]">
            Connect
          </button>
        </div>
      </section>

      <BottomNav />
    </main>
  );
}
