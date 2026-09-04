'use client';

/**
 * Certificate wallet, the Stitch certificate_wallet_light screen.
 * The featured card derives from the scholar's real name and level; the
 * archive grid is the milestone catalogue, static until the exam board
 * ships verified credentials (founder: static is fine for now).
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';
import { LogoActivityIndicator } from '@/components/renance-logo';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

interface MeResponse {
  user: { id: string; username: string };
  profile: { fullName: string } | null;
}

interface GameState {
  level: number;
  totalXp: number;
}

const MILESTONES: ReadonlyArray<{
  eyebrow: string;
  title: string;
  icon: string;
  art: string;
  locked?: boolean;
}> = [
  { eyebrow: 'Level 6', title: 'Consistency 50', icon: 'shield', art: 'from-[#E7EEFF] to-[#F0F3FF]' },
  { eyebrow: 'Milestone', title: '10k Mastery', icon: 'diamond', art: 'from-[#D8E3FB] to-[#F0F3FF]' },
  { eyebrow: 'Foundation', title: 'First 100 XP', icon: 'menu_book', art: 'from-[#DAE2FC] to-[#EEF2FF]' },
  { eyebrow: 'Exam board', title: 'Distinction', icon: 'workspace_premium', art: 'from-[#D0E1FB] to-[#EDF3FF]', locked: true },
];

function certId(uid: string, level: number): string {
  const src = uid.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  const take = (from: number, n: number) => (src.slice(from, from + n) || 'RNC').padEnd(n, 'X');
  return `RNC-${take(0, 3)}-${take(3, 3)}-L${level}`;
}

export default function CertificatesPage() {
  const router = useRouter();
  const [me, setMe] = useState<MeResponse | null>(null);
  const [state, setState] = useState<GameState | null>(null);
  const [verifyOpen, setVerifyOpen] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    let alive = true;
    api<MeResponse>('/me')
      .then((res) => alive && setMe(res))
      .catch(() => alive && setMe({ user: { id: '', username: 'Renance scholar' }, profile: null }));
    api<{ state: GameState }>('/me/gamification')
      .then((g) => alive && setState(g.state))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [router]);

  if (!me) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-background">
        <LogoActivityIndicator state="busy" label="Opening your wallet…" />
      </main>
    );
  }

  const name = me.profile?.fullName || me.user.username || 'Renance scholar';
  const level = state?.level ?? 1;
  const id = certId(me.user.id, level);
  const issued = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

  async function share() {
    const text = `My Renance Level ${level} certificate (${id})`;
    try {
      if (typeof navigator !== 'undefined' && navigator.share) {
        await navigator.share({ title: 'Renance certificate', text });
        return;
      }
      await navigator.clipboard.writeText(text);
      window.alert('Certificate details copied to your clipboard.');
    } catch {
      /* user dismissed the share sheet */
    }
  }

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-28 md:pb-16">
      <PageBar title="Digital Wallet" />

      <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 px-4 pt-4 sm:px-6">
        <div className="mx-auto flex w-full max-w-2xl flex-col gap-4">
          <div className="flex items-center gap-1.5">
            <h2 className="text-lg font-semibold text-on-surface">Digital Wallet</h2>
            <span className="text-[13px] text-text-secondary">· 1 of 4 certificates</span>
          </div>

          {/* Featured certificate ------------------------------------------- */}
          <div className="relative w-full overflow-hidden rounded-xl bg-card shadow-[0_4px_24px_-4px_rgba(20,28,45,0.08)]">
            {/* Ambient guilloche pattern (Stitch detail) */}
            <div className="pointer-events-none absolute inset-0 opacity-[0.03]">
              <svg height="100%" width="100%" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern id="guilloche" width="60" height="60" patternUnits="userSpaceOnUse">
                    <path
                      d="M30,0 C45,15 60,15 60,30 C45,45 30,45 30,60 C15,45 0,45 0,30 C15,15 30,15 30,0 Z"
                      fill="none"
                      stroke="#263143"
                      strokeWidth="0.5"
                    />
                    <circle cx="30" cy="30" r="15" fill="none" stroke="#263143" strokeWidth="0.5" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#guilloche)" />
              </svg>
            </div>

            <div className="relative flex flex-col gap-8 p-6">
              <div className="flex items-start justify-between gap-3">
                <div className="flex flex-col gap-1">
                  <span className="font-mono text-[13px] uppercase tracking-widest text-accent-amber">
                    Consistency 100
                  </span>
                  <span className="text-[28px] font-bold leading-9 tracking-tight text-primary">Level {level}</span>
                </div>
                <div className="flex items-center gap-1 rounded-full bg-accent-emerald/10 px-2 py-1">
                  <span className="font-mono text-[13px] text-accent-emerald">Verified</span>
                  <span className="material-symbols-outlined text-[16px] text-accent-emerald">verified</span>
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <div className="flex items-end justify-between border-b border-surface-container-highest pb-2">
                  <span className="text-[13px] text-text-secondary">Issued to</span>
                  <span className="text-[15px] font-semibold text-on-surface">{name}</span>
                </div>
                <div className="flex items-end justify-between border-b border-surface-container-highest pb-2">
                  <span className="text-[13px] text-text-secondary">Date</span>
                  <span className="text-[15px] font-semibold text-on-surface">{issued}</span>
                </div>
                <div className="flex items-end justify-between">
                  <span className="text-[13px] text-text-secondary">ID</span>
                  <span className="font-mono text-[13px] text-on-surface">{id}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Actions ---------------------------------------------------------- */}
          <div className="flex gap-2">
            <button
              type="button"
              onClick={share}
              className="flex h-[52px] flex-1 items-center justify-center gap-2 rounded-[10px] bg-primary text-[15px] font-semibold text-on-primary transition-transform hover:bg-primary/90 active:scale-[0.98]"
            >
              <span className="material-symbols-outlined text-[20px]">ios_share</span>
              Share
            </button>
            <button
              type="button"
              onClick={() => setVerifyOpen((v) => !v)}
              className="flex h-[52px] flex-1 items-center justify-center gap-2 rounded-[10px] border border-outline-light text-[15px] font-semibold text-on-surface transition hover:bg-surface-container active:scale-[0.98]"
            >
              <span className="material-symbols-outlined text-[20px]">qr_code_scanner</span>
              Verify
            </button>
          </div>
          {verifyOpen && (
            <div className="flex items-start gap-3 rounded-xl bg-selection-blue/60 p-4">
              <span className="material-symbols-outlined text-accent-emerald">verified</span>
              <p className="text-[13px] leading-relaxed text-on-surface">
                Level {level} certificate for {name}. ID {id}, issued {issued}. Public verification links
                land with shareable profiles.
              </p>
            </div>
          )}

          {/* Archive ------------------------------------------------------------ */}
          <div className="mt-2 flex flex-col gap-3">
            <h2 className="text-lg font-semibold text-on-surface">Archive</h2>
            <div className="grid grid-cols-2 gap-4">
              {MILESTONES.map((m) => (
                <div
                  key={m.title}
                  className="flex flex-col gap-3 rounded-lg bg-card p-2 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition-transform active:scale-[0.98]"
                >
                  <div
                    className={`relative flex h-24 w-full items-center justify-center overflow-hidden rounded bg-gradient-to-br ${m.art}`}
                  >
                    <span className="material-symbols-outlined text-[40px] text-on-surface/80">{m.icon}</span>
                    {m.locked && (
                      <span className="absolute bottom-1 right-1 rounded-full bg-surface-container px-1.5 py-0.5 font-mono text-[10px] text-on-surface-variant">
                        soon
                      </span>
                    )}
                  </div>
                  <div className="flex flex-col gap-1 pb-1">
                    <span className="font-mono text-[11px] text-text-secondary">{m.eyebrow}</span>
                    <span className="truncate text-sm font-semibold leading-tight text-on-surface">{m.title}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <p className="pb-4 text-[13px] leading-relaxed text-text-secondary">
            Distinction certificates are issued once your exam board results are verified on Renance.
          </p>
        </div>
      </div>

      <BottomNav />
    </main>
  );
}
