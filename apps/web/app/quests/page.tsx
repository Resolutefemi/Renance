'use client';

/**
 * Quests — daily / weekly / monthly challenges of the merged learn
 * module (founder directive 2026-10-14). Progress is LIVE: it counts
 * the questions, topics, combos and XP the student actually earned on
 * their Renance account, and claims pay gems into the same wallet the
 * top-bar counter reads.
 */

import { useCallback, useEffect, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { ConfettiBurst, GemIcon, ProgressBar, ToastBanner } from '@/components/learn/bits';
import { getStoredUser } from '@/lib/session';
import { useRouter } from 'next/navigation';
import { QuestDef, claimQuest, fetchQuests } from '@/lib/learn';

export default function QuestsPage() {
  const router = useRouter();
  const [data, setData] = useState<Awaited<ReturnType<typeof fetchQuests>> | null>(null);
  const [loading, setLoading] = useState(true);
  const [claiming, setClaiming] = useState('');
  const [toast, setToast] = useState('');
  const [confetti, setConfetti] = useState(0);

  const load = useCallback(() => {
    fetchQuests()
      .then(setData)
      .catch(() => {
        // No dead-end error card (founder: "remove retry"): the page
        // keeps its syncing face and the quiet poll below heals it.
      })
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined' && !getStoredUser()) {
      router.replace('/login?next=/quests');
      return;
    }
    load();
  }, [load, router]);

  // The quiet re-sync: until the quests answer, poll every 8s. The
  // page heals itself — nothing for the scholar to press.
  useEffect(() => {
    if (data) return;
    const t = window.setInterval(load, 8000);
    return () => window.clearInterval(t);
  }, [data, load]);

  const claim = useCallback(async (key: string) => {
    setClaiming(key);
    try {
      const res = await claimQuest(key);
      setToast(`+${res.gems} gems claimed!`);
      setConfetti((c) => c + 1);
      setTimeout(() => setToast(''), 2200);
      setData(await fetchQuests());
    } catch {
      setToast('Claim failed — finish the quest first');
      setTimeout(() => setToast(''), 2000);
    } finally {
      setClaiming('');
    }
  }, []);

  return (
    <div className="min-h-screen bg-background md:pl-[var(--rail-w)]">
      <SideNav />
      <ConfettiBurst fire={confetti} />
      <ToastBanner text={toast} />
      <PageBar title="Quests" backHref="/dashboard" />

      <main className="mx-auto w-full max-w-2xl px-4 pb-28 pt-4">
        {loading && <div className="h-40 animate-pulse rounded-2xl bg-surface-container" aria-hidden />}

        {!loading && !data && (
          <div className="learn-tile flex flex-col items-center gap-2 rounded-2xl border-2 border-dashed border-outline-variant bg-card px-4 py-12 text-center">
            <span className="material-symbols-outlined text-[36px] text-primary">flag</span>
            <p className="text-[15px] font-black text-on-surface">Your quests are syncing…</p>
            <p className="max-w-xs text-[12.5px] font-bold text-on-surface-variant">
              Today's challenges appear the moment the connection is back.
            </p>
          </div>
        )}

        {data && (
          <div className="flex flex-col gap-5">
            <section>
              <h2 className="px-1 pb-2 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">Daily quests · reset at midnight</h2>
              <div className="flex flex-col gap-2.5">
                {data.daily.map((q) => <QuestCard key={q.key} q={q} claiming={claiming === q.key} onClaim={() => void claim(q.key)} />)}
              </div>
            </section>

            <section>
              <h2 className="px-1 pb-2 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">Weekly challenge</h2>
              <QuestCard q={data.weekly} claiming={claiming === data.weekly.key} onClaim={() => void claim(data.weekly.key)} big />
            </section>

            <section>
              <h2 className="px-1 pb-2 text-[13px] font-black uppercase tracking-wide text-on-surface-variant">Monthly challenge</h2>
              <QuestCard q={data.monthly} claiming={claiming === data.monthly.key} onClaim={() => void claim(data.monthly.key)} big />
            </section>

            <p className="px-1 text-center text-[12px] font-bold text-on-surface-variant">
              Everything you do on Renance counts: lessons, past-question quizzes, practice and reviews all feed your quests.
            </p>
          </div>
        )}
      </main>
      <BottomNav />
    </div>
  );
}

function QuestCard({ q, claiming, onClaim, big }: { q: QuestDef; claiming: boolean; onClaim: () => void; big?: boolean }) {
  const pct = Math.min(100, (q.progress / Math.max(1, q.target)) * 100);
  return (
    <div className={`learn-tile flex items-center gap-3 rounded-2xl border-2 p-3.5 ${
      q.claimed ? 'border-outline-variant bg-surface-container' : q.complete ? 'border-accent-amber bg-accent-amber/10' : 'border-outline-variant bg-card'
    }`}>
      <span className={`flex ${big ? 'h-12 w-12' : 'h-11 w-11'} shrink-0 items-center justify-center rounded-xl bg-primary/15`}>
        <span className="material-symbols-outlined text-[24px] text-primary-ink">{q.icon}</span>
      </span>
      <div className="min-w-0 flex-1">
        <p className={`text-[14px] font-black ${q.claimed ? 'text-on-surface-variant line-through' : 'text-on-surface'}`}>{q.title}</p>
        <div className="mt-1.5 flex items-center gap-2">
          <ProgressBar value={pct} tone={q.complete ? 'gold' : 'green'} />
          <span className="shrink-0 text-[11px] font-black text-on-surface-variant">
            {Math.min(q.progress, q.target)}/{q.target}
          </span>
        </div>
      </div>
      {q.claimed ? (
        <span className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/15 text-primary-ink" aria-label="Claimed">
          <span className="material-symbols-outlined text-[20px]">check_circle</span>
        </span>
      ) : q.complete ? (
        <button type="button" onClick={onClaim} disabled={claiming} className="key-btn bg-accent-amber px-3 text-[12.5px] text-white">
          {claiming ? '…' : 'Claim'}
        </button>
      ) : (
        <span className="flex shrink-0 items-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2 py-1 text-[12px] font-black text-on-surface">
          <GemIcon size={14} />{q.gems}
        </span>
      )}
    </div>
  );
}
