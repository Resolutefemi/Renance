'use client';

/**
 * The daily CBT subject-combination picker (the founder's rule: the
 * first Daily tap asks for the combination, and every daily sprint
 * afterwards draws only those subjects). Saving hits
 * PUT /me/daily-subjects; the server then composes the day's sprint
 * from exactly these subjects, so web and app play the same paper.
 */

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { fetchManifest, subjectName } from '@/lib/exams';

/** Bodies that carry per-subject banks (the only ones that can ask). */
export const COMBO_BODIES = ['JAMB', 'WAEC', 'NECO'] as const;

const BODY_SLUG: Record<string, string> = { JAMB: 'jamb', WAEC: 'waec', NECO: 'neco' };

export default function DailyComboModal({
  open,
  body,
  onClose,
  onSaved,
}: {
  open: boolean;
  /** Canonical body: JAMB | WAEC | NECO. */
  body: string;
  onClose: () => void;
  onSaved: (subjects: string[]) => void;
}) {
  const [rows, setRows] = useState<{ slug: string; count: number }[] | null>(null);
  const [picked, setPicked] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    const slug = BODY_SLUG[body];
    if (!slug) return;
    let alive = true;
    setRows(null);
    setError(null);
    setPicked(slug === 'jamb' ? ['english'] : []);
    fetchManifest()
      .then((m) => {
        if (!alive) return;
        const hit = new RegExp(`^${slug}-(.+)-bank$`);
        const seen = new Map<string, number>();
        for (const e of m.exams) {
          const match = hit.exec(e.code);
          if (!match || match[1].endsWith('-enrich')) continue;
          seen.set(match[1], (seen.get(match[1]) ?? 0) + e.questionCount);
        }
        setRows(
          [...seen.entries()]
            .map(([s, c]) => ({ slug: s, count: c }))
            .sort((a, b) => a.slug.localeCompare(b.slug)),
        );
      })
      .catch(() => alive && setError('Could not load the subject list, check your connection.'));
    return () => {
      alive = false;
    };
  }, [open, body]);

  const toggle = (slug: string) => {
    setPicked((p) =>
      p.includes(slug) ? p.filter((s) => s !== slug) : p.length >= 9 ? p : [...p, slug],
    );
  };

  const save = async () => {
    if (picked.length === 0 || busy) return;
    setBusy(true);
    setError(null);
    try {
      await api('/me/daily-subjects', { method: 'PUT', body: { subjects: picked } });
      onSaved(picked);
    } catch {
      setError('Could not save the combination, try again.');
      setBusy(false);
    }
  };

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center">
      <button aria-label="Close" onClick={onClose} className="absolute inset-0 bg-accent-ink/45" />
      <div className="relative max-h-[88dvh] w-full max-w-md overflow-y-auto rounded-t-3xl bg-surface-container-lowest p-6 shadow-2xl sm:rounded-3xl">
        <h3 className="text-lg font-bold tracking-tight text-on-surface">Your Daily subjects</h3>
        <p className="mt-1 text-[13.5px] leading-relaxed text-on-surface-variant">
          Pick your subject combination once - every daily CBT then shows only these subjects, every day.
          {body === 'JAMB' && ' Use of English is pre-picked, the hall rule.'}
        </p>

        {error && <p className="mt-3 rounded-lg bg-error-container px-3 py-2 text-[13px] text-on-error-container">{error}</p>}

        {rows == null && !error && (
          <p className="mt-6 text-center text-[13.5px] text-on-surface-variant">Loading the subject list…</p>
        )}

        {rows != null && (
          <div className="mt-4 flex flex-wrap gap-2">
            {rows.map((r) => {
              const on = picked.includes(r.slug);
              return (
                <button
                  key={r.slug}
                  type="button"
                  onClick={() => toggle(r.slug)}
                  className={`rounded-full px-3.5 py-2 text-[13px] transition ${
                    on
                      ? 'bg-primary font-semibold text-on-primary'
                      : 'bg-surface-container-low text-on-surface-variant hover:text-on-surface'
                  }`}
                >
                  {subjectName(r.slug)}
                  <span className={`ml-1 font-mono text-[10px] ${on ? 'text-on-primary/70' : 'text-outline'}`}>
                    {r.count.toLocaleString()} Q
                  </span>
                </button>
              );
            })}
          </div>
        )}

        <p className="mt-3 font-mono text-[11px] text-outline">{picked.length}/9 picked · at least 1</p>

        <div className="mt-4 flex gap-2">
          <button
            onClick={onClose}
            className="h-12 flex-1 rounded-xl border border-outline-variant bg-card text-[14px] font-semibold text-on-surface-variant"
          >
            Not now
          </button>
          <button
            onClick={save}
            disabled={picked.length === 0 || busy}
            className="h-12 flex-1 rounded-xl bg-primary text-[14px] font-bold text-on-primary transition active:scale-[0.98] disabled:opacity-50"
          >
            {busy ? 'Saving…' : 'Save & start'}
          </button>
        </div>
      </div>
    </div>
  );
}
