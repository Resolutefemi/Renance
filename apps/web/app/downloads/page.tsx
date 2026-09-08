'use client';

/**
 * Downloads — the Stitch downloads_light / downloads_full_dark screen.
 * Every manifest pack with its real offline state: downloaded (cached
 * in IndexedDB, sha-pinned), ready to fetch, or syncing. Per-pack
 * download/delete, a live storage meter from the browser's own
 * estimate, and a sync-all sweep. Offline-ready is the whole product
 * promise (ADR-0003), so this page makes it visible and manageable.
 */

import { useCallback, useEffect, useMemo, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { LogoActivityIndicator } from '@/components/renance-logo';
import { fetchManifest, fetchBundle, type ExamMeta, type Manifest } from '@/lib/exams';
import { idbDeleteBundle, idbGetBundle, storageEstimate } from '@/lib/bundle-store';

type PackState = 'idle' | 'checking' | 'downloaded' | 'fetching';

function cacheKey(code: string, sha: string) {
  return `renance.bundle.${code}.${sha.slice(0, 12)}`;
}

function fmtBytes(n: number): string {
  if (!n) return '—';
  if (n >= 1_048_576) return `${(n / 1_048_576).toFixed(1)} MB`;
  if (n >= 1024) return `${Math.round(n / 1024)} KB`;
  return `${n} B`;
}

export default function DownloadsPage() {
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [failed, setFailed] = useState(false);
  const [states, setStates] = useState<Record<string, PackState>>({});
  const [downloaded, setDownloaded] = useState<Set<string>>(new Set());
  const [storage, setStorage] = useState<{ usage: number; quota: number } | null>(null);

  const markDownloaded = useCallback((code: string, on: boolean) => {
    setDownloaded((prev) => {
      const next = new Set(prev);
      if (on) next.add(code);
      else next.delete(code);
      return next;
    });
  }, []);

  // Load the manifest, then audit every pack against the local cache.
  useEffect(() => {
    let alive = true;
    fetchManifest()
      .then(async (m) => {
        if (!alive) return;
        setManifest(m);
        setStorage(await storageEstimate());
        for (const exam of m.exams) {
          if (!alive) return;
          setStates((s) => ({ ...s, [exam.code]: 'checking' }));
          const cached = await idbGetBundle(cacheKey(exam.code, exam.bundleSha256));
          if (!alive) return;
          const ok = Boolean(cached && (cached as { questions?: unknown[] }).questions);
          markDownloaded(exam.code, ok);
          setStates((s) => ({ ...s, [exam.code]: ok ? 'downloaded' : 'idle' }));
        }
      })
      .catch(() => alive && setFailed(true));
    return () => {
      alive = false;
    };
  }, [markDownloaded]);

  async function download(exam: ExamMeta) {
    setStates((s) => ({ ...s, [exam.code]: 'fetching' }));
    try {
      await fetchBundle(exam); // fetchBundle writes the IndexedDB cache
      markDownloaded(exam.code, true);
      setStates((s) => ({ ...s, [exam.code]: 'downloaded' }));
      setStorage(await storageEstimate());
    } catch {
      setStates((s) => ({ ...s, [exam.code]: 'idle' }));
    }
  }

  async function remove(exam: ExamMeta) {
    await idbDeleteBundle(cacheKey(exam.code, exam.bundleSha256));
    markDownloaded(exam.code, false);
    setStates((s) => ({ ...s, [exam.code]: 'idle' }));
    setStorage(await storageEstimate());
  }

  const groups = useMemo(() => {
    if (!manifest) return [];
    const order: string[] = [];
    const byBody = new Map<string, ExamMeta[]>();
    for (const e of manifest.exams) {
      const body = e.body ?? 'University Modules';
      if (!byBody.has(body)) {
        byBody.set(body, []);
        order.push(body);
      }
      byBody.get(body)!.push(e);
    }
    const rank = (b: string) => (b === 'JAMB' ? 0 : b === 'WAEC' ? 1 : b === 'NECO' ? 2 : 3);
    return order
      .map((body) => ({ body, packs: byBody.get(body)! }))
      .sort((a, b) => rank(a.body) - rank(b.body));
  }, [manifest]);

  const totalPacks = manifest?.exams.length ?? 0;
  const havePacks = downloaded.size;
  const totalBytes = manifest?.exams.reduce((n, e) => n + (e.sizeBytes ?? 0), 0) ?? 0;

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-60">
      <PageBar title="Downloads" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Downloads
        </h1>
        <p className="mt-1 text-[14px] text-on-surface-variant">
          Your offline library — every pack cached on this device keeps working with no network.
        </p>

        {/* Storage meter */}
        <section className="mt-4 flex flex-col gap-2 rounded-xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          <div className="flex items-center justify-between">
            <h2 className="text-[15px] font-semibold text-on-surface">Offline library</h2>
            <span className="font-mono text-[12px] text-on-surface-variant">
              {havePacks}/{totalPacks} packs · {fmtBytes(totalBytes)}
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-surface-container">
            <div
              className="h-full rounded-full bg-accent-emerald transition-all"
              style={{ width: `${totalPacks ? Math.round((havePacks * 100) / totalPacks) : 0}%` }}
            />
          </div>
          {storage && storage.quota > 0 && (
            <p className="font-mono text-[11px] text-on-surface-variant">
              Device storage: {fmtBytes(storage.usage)} used of {fmtBytes(storage.quota)} available to this site
            </p>
          )}
        </section>

        {failed && (
          <p className="mt-6 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">
            Could not reach Renance servers. Check your connection and try again.
          </p>
        )}

        {!manifest && !failed && (
          <div className="flex justify-center py-16">
            <LogoActivityIndicator state="busy" label="Checking your offline library…" />
          </div>
        )}

        {groups.map((group) => (
          <section key={group.body} className="mt-6">
            <h2 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">
              {group.body} · {group.packs.filter((p) => downloaded.has(p.code)).length}/{group.packs.length} offline
            </h2>
            <ul className="mt-3 flex flex-col gap-2">
              {group.packs.map((exam) => {
                const st = states[exam.code] ?? 'idle';
                const have = downloaded.has(exam.code);
                return (
                  <li
                    key={exam.code}
                    className="flex items-center gap-3 rounded-[12px] bg-card p-3.5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]"
                  >
                    <span
                      className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] ${
                        have ? 'bg-accent-emerald/15 text-accent-emerald' : 'bg-surface-container text-on-surface-variant'
                      }`}
                    >
                      <span className="material-symbols-outlined fill-current text-[20px]">
                        {have ? 'download_done' : 'download'}
                      </span>
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[14px] font-semibold text-on-surface">{exam.title}</p>
                      <p className="mt-0.5 font-mono text-[11px] text-on-surface-variant">
                        {fmtBytes(exam.sizeBytes ?? 0)} · {exam.questionCount} Q
                        {st === 'checking' ? ' · checking…' : st === 'fetching' ? ' · syncing…' : have ? ' · ready offline' : ''}
                      </p>
                    </div>
                    {st === 'fetching' || st === 'checking' ? (
                      <span className="material-symbols-outlined animate-spin text-[20px] text-on-surface-variant">
                        progress_activity
                      </span>
                    ) : have ? (
                      <button
                        type="button"
                        onClick={() => remove(exam)}
                        className="flex h-9 items-center gap-1 rounded-full border border-outline-variant/60 px-3 text-[12px] font-medium text-on-surface-variant transition-colors hover:border-error hover:text-error"
                      >
                        <span className="material-symbols-outlined text-[16px]">delete</span>
                        Remove
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => download(exam)}
                        className="flex h-9 items-center gap-1 rounded-full bg-primary px-3 text-[12px] font-semibold text-on-primary transition-transform active:scale-95"
                      >
                        <span className="material-symbols-outlined text-[16px]">download</span>
                        Get
                      </button>
                    )}
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
