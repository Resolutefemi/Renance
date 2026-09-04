'use client';

/**
 * Syllabus (Stitch syllabus_map_light — ROADMAP #4): the curriculum tree
 * of one exam body overlaid with the student's mastery state.
 *   /syllabus                → default body (first pill)
 *   /syllabus?body=jamb      → deep link (score-report weak chips land here)
 * A ?topic= highlight expands its section and rings the row.
 */

import { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import {
  SYLLABUS_BODIES,
  masteryPct,
  type SyllabusTopic,
  type SyllabusTree,
} from '@/lib/syllabus';
import { LogoActivityIndicator, RenanceMark } from '@/components/renance-logo';

const DOT = {
  mastered: 'bg-accent-emerald',
  learning: 'bg-accent-amber',
  unseen: 'bg-surface-variant',
} as const;

export default function SyllabusPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-dvh flex-col items-center justify-center bg-background px-6">
          <LogoActivityIndicator state="busy" label="Opening the map…" />
        </main>
      }
    >
      <SyllabusInner />
    </Suspense>
  );
}

function SyllabusInner() {
  const params = useSearchParams();
  const initialBody = params.get('body') ?? 'jamb';
  const initialTopic = params.get('topic');

  const [body, setBody] = useState(initialBody);
  const [highlightTopic, setHighlightTopic] = useState<string | null>(initialTopic);
  const [tree, setTree] = useState<SyllabusTree | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState<Set<string>>(() => new Set<string>());

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    api<SyllabusTree>(`/syllabus/${body}`)
      .then((t) => {
        if (!alive) return;
        setTree(t);
        // A deep-linked / focused topic auto-expands its section.
        const focus = initialTopic;
        if (focus) {
          for (const s of t.subjects) {
            for (const sec of s.sections) {
              if (sec.topics.some((x) => x.topic === focus)) {
                setOpen((prev) => new Set(prev).add(sec.title));
              }
            }
          }
        }
      })
      .catch((e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : 'Could not load the syllabus map');
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [body]);

  function toggle(title: string) {
    setOpen((prev) => {
      const next = new Set(prev);
      if (!next.delete(title)) next.add(title);
      return next;
    });
  }

  function focusTopic(t: SyllabusTopic) {
    if (!tree) return;
    for (const s of tree.subjects) {
      for (const sec of s.sections) {
        if (sec.topics.some((x) => x.topic === t.topic)) {
          setOpen((prev) => new Set(prev).add(sec.title));
        }
      }
    }
    setHighlightTopic(t.topic);
  }

  const pct = tree ? masteryPct(tree) : 0;

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-16 pt-8 sm:px-6 lg:max-w-4xl">
      <header className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight text-on-surface">Syllabus</h1>
        <Link href="/dashboard" className="text-sm text-on-surface-variant hover:text-on-surface">
          Dashboard
        </Link>
      </header>

      {/* Body pills */}
      <div className="mt-4 flex flex-wrap gap-2">
        {SYLLABUS_BODIES.map((b) => (
          <button
            key={b.slug}
            onClick={() => setBody(b.slug)}
            className={`rounded-full px-4 py-1.5 font-mono text-xs transition ${
              b.slug === body
                ? 'bg-primary font-semibold text-on-primary'
                : 'bg-card text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] hover:text-on-surface'
            }`}
          >
            {b.label}
          </button>
        ))}
      </div>

      {loading && (
        <div className="flex min-h-64 flex-col items-center justify-center py-16">
          <RenanceMark size={40} state="busy" />
        </div>
      )}
      {!loading && error && (
        <div className="flex min-h-64 flex-col items-center justify-center py-16">
          <p className="max-w-md rounded-xl bg-error-container px-6 py-5 text-center text-sm text-on-error-container">
            {error}
          </p>
        </div>
      )}
      {!loading && !error && tree && (
        <>
          {/* Header card: ring + legend */}
          <section className="mt-4 flex items-start justify-between gap-4 rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="min-w-0">
              <p className="font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
                Course Syllabus
              </p>
              <h2 className="mt-1 text-2xl font-bold tracking-tight text-on-surface">{tree.body}</h2>
              <p className="mt-2 text-[13px] text-on-surface-variant">
                {tree.stats.topics} topics · {tree.stats.mastered} mastered · {tree.stats.learning}{' '}
                learning · {tree.stats.unseen} unseen
              </p>
              <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1">
                <Legend color="bg-accent-emerald" label="Mastered" />
                <Legend color="bg-accent-amber" label="Learning" />
                <Legend color="bg-surface-variant" label="Unseen" />
              </div>
            </div>
            <Ring pct={pct} />
          </section>

          {/* Focus next — the server's weakest topics */}
          {tree.weakest.length > 0 && (
            <section className="mt-6">
              <h3 className="text-sm text-on-surface-variant">Focus next</h3>
              <div className="mt-2 flex flex-wrap gap-2">
                {tree.weakest.map((t) => (
                  <button
                    key={t.topic}
                    onClick={() => focusTopic(t)}
                    className="inline-flex items-center gap-1.5 rounded-full border border-accent-amber/40 bg-accent-amber/10 px-3 py-1.5 font-mono text-xs text-on-surface"
                  >
                    <span className="material-symbols-outlined text-[14px] text-accent-amber">
                      local_fire_department
                    </span>
                    {t.lastTotal > 0 ? `${t.topic} · ${Math.round(t.accuracy * 100)}%` : t.topic}
                  </button>
                ))}
              </div>
            </section>
          )}

          {/* Topic tree */}
          <div className="mt-6 space-y-6">
            {tree.subjects.map((subject) => (
              <div key={subject.subject}>
                <h3 className="text-[15px] font-semibold text-on-surface">{subject.subject}</h3>
                <div className="mt-3 space-y-3">
                  {subject.sections.map((sec, i) => {
                    const isOpen = open.has(sec.title);
                    return (
                      <div
                        key={sec.title}
                        className="overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
                      >
                        <button
                          onClick={() => toggle(sec.title)}
                          className="flex w-full items-center gap-3 p-4 text-left transition-colors hover:bg-surface-container-low"
                        >
                          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-surface-container font-mono text-[13px] text-on-surface">
                            {i + 1}
                          </span>
                          <span className="min-w-0 flex-1 truncate text-sm font-medium text-on-surface">
                            {sec.title}
                          </span>
                          <span
                            className={`font-mono text-xs ${
                              sec.mastery >= 0.7
                                ? 'text-accent-emerald'
                                : sec.mastery > 0
                                  ? 'text-accent-amber'
                                  : 'text-on-surface-variant'
                            }`}
                          >
                            {Math.round(sec.mastery * 100)}%
                          </span>
                          <span
                            className={`material-symbols-outlined text-outline-dark transition-transform ${
                              isOpen ? 'rotate-180' : ''
                            }`}
                          >
                            expand_more
                          </span>
                        </button>
                        {isOpen && (
                          <div className="flex flex-col gap-2 px-4 pb-4">
                            {sec.topics.map((t) => (
                              <TopicRow
                                key={t.topic}
                                topic={t}
                                highlight={highlightTopic === t.topic}
                              />
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </main>
  );
}

function TopicRow({ topic, highlight }: { topic: SyllabusTopic; highlight: boolean }) {
  const lit = topic.status === 'mastered' ? 3 : topic.status === 'learning' ? 2 : 1;
  return (
    <div
      className={`flex flex-col gap-1.5 rounded-lg bg-surface p-3 ${
        highlight ? 'ring-1 ring-accent-amber' : ''
      }`}
    >
      <div className="flex items-center justify-between">
        <span className="truncate text-[13px] text-on-surface">{topic.topic}</span>
        <span className="flex gap-1">
          {[0, 1, 2].map((i) => (
            <span
              key={i}
              className={`h-1.5 w-1.5 rounded-full ${
                i < lit ? DOT[topic.status] : 'bg-surface-variant'
              }`}
            />
          ))}
        </span>
      </div>
      <div className="flex items-center justify-between">
        <span className="text-[11px] text-on-surface-variant">
          {topic.seen && topic.lastTotal > 0
            ? `${topic.questions} questions · last ${topic.lastCorrect}/${topic.lastTotal}`
            : `${topic.questions} questions · not tried yet`}
        </span>
        <span className="flex h-1.5 w-24 overflow-hidden rounded-full bg-surface-variant">
          <span
            className={`h-full ${
              topic.status === 'mastered' ? 'bg-accent-emerald' : 'bg-accent-amber'
            }`}
            style={{ width: `${Math.round(topic.accuracy * 100)}%` }}
          />
        </span>
      </div>
    </div>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5 text-[11px] text-on-surface-variant">
      <span className={`h-2 w-2 rounded-full ${color}`} />
      {label}
    </span>
  );
}

function Ring({ pct }: { pct: number }) {
  return (
    <div className="relative h-16 w-16 shrink-0">
      <svg viewBox="0 0 36 36" className="h-full w-full -rotate-90">
        <path
          className="text-surface-variant"
          d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
        />
        <path
          className="text-accent-emerald"
          d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeDasharray={`${pct}, 100`}
          strokeLinecap="round"
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center font-mono text-sm font-bold text-on-surface">
        {pct}%
      </span>
    </div>
  );
}
