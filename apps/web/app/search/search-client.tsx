'use client';

/**
 * Search (Stitch search_light on the web). One field, four shelves: packs,
 * lessons, flashcard decks and syllabus topics. The lessons and syllabus
 * trees are baked into the page at build time (static export doctrine);
 * packs and decks arrive from the authed API in the background. All
 * matching runs in the browser, so nothing extra is exposed server-side.
 */

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { getToken } from '@/lib/session';
import { api } from '@/lib/api';
import { fetchManifest, type ExamMeta } from '@/lib/exams';
import { fetchDecks, type FlashcardDeckMeta } from '@/lib/flashcards';

export interface LessonHit {
  slug: string;
  title: string;
  subject?: string;
  minutes: number;
  summary: string;
}

export interface TopicHit {
  body: string;
  label: string;
  subject: string;
  topic: string;
}

interface Props {
  lessons: LessonHit[];
  topics: TopicHit[];
}

type Shelf = 'packs' | 'lessons' | 'decks' | 'topics';

interface Hit {
  shelf: Shelf;
  title: string;
  subtitle: string;
  href: string;
  icon: string;
}

const SHELF_LABEL: Record<Shelf, string> = {
  packs: 'Packs',
  lessons: 'Lessons',
  decks: 'Flashcards',
  topics: 'Syllabus topics',
};

const ICON: Record<Shelf, string> = {
  packs: 'description',
  lessons: 'menu_book',
  decks: 'style',
  topics: 'account_tree',
};

/** Every whitespace token must appear somewhere in the fields (AND). */
function matches(query: string, fields: string[]): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return false;
  const hay = fields.join('\n').toLowerCase();
  return q.split(/\s+/).every((t) => hay.includes(t));
}

export default function SearchClient({ lessons, topics }: Props) {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [packs, setPacks] = useState<ExamMeta[]>([]);
  const [decks, setDecks] = useState<FlashcardDeckMeta[]>([]);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    let alive = true;
    fetchManifest()
      .then((m) => alive && setPacks(m.exams))
      .catch(() => {});
    fetchDecks()
      .then((d) => alive && setDecks(d))
      .catch(() => {});
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router]);

  const grouped = useMemo(() => {
    const out = new Map<Shelf, Hit[]>();
    if (!query.trim()) return out;
    const push = (hit: Hit) => {
      const list = out.get(hit.shelf);
      if (list) list.push(hit);
      else out.set(hit.shelf, [hit]);
    };
    for (const e of packs) {
      if (!matches(query, [e.title])) continue;
      push({
        shelf: 'packs',
        title: e.title,
        subtitle: `${e.questionCount} questions · ${e.totalMarks} marks`,
        href: `/exams/${e.code}`,
        icon: ICON.packs,
      });
    }
    for (const l of lessons) {
      if (!matches(query, [l.title, l.summary, l.subject ?? ''])) continue;
      push({
        shelf: 'lessons',
        title: l.title,
        subtitle: `${l.minutes} min read${l.subject ? ` · ${l.subject}` : ''}`,
        href: `/lessons/${l.slug}`,
        icon: ICON.lessons,
      });
    }
    for (const d of decks) {
      if (!matches(query, [d.title, d.subject ?? '', d.body ?? ''])) continue;
      push({
        shelf: 'decks',
        title: d.title,
        subtitle: `${d.cardCount} cards`,
        href: '/flashcards',
        icon: ICON.decks,
      });
    }
    for (const t of topics) {
      if (!matches(query, [t.topic, t.subject, t.label])) continue;
      push({
        shelf: 'topics',
        title: t.topic,
        subtitle: `${t.label} · ${t.subject}`,
        href: `/syllabus?body=${encodeURIComponent(t.body)}&topic=${encodeURIComponent(t.topic)}`,
        icon: ICON.topics,
      });
    }
    return out;
  }, [query, packs, decks, lessons, topics]);

  const total = [...grouped.values()].reduce((n, l) => n + l.length, 0);

  return (
    <main className="min-h-dvh bg-surface-container-lowest pb-20">
      <div className="mx-auto w-full max-w-3xl px-4 pt-10 sm:px-6">
        <header className="flex items-center gap-3">
          <Link
            href="/dashboard"
            className="flex h-9 w-9 items-center justify-center rounded-full border border-outline-variant/60 bg-card text-on-surface transition hover:bg-surface-container"
            aria-label="Back to dashboard"
          >
            <span className="material-symbols-outlined text-[20px]">arrow_back</span>
          </Link>
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-on-surface">Search</h1>
            <p className="text-[13px] text-on-surface-variant">
              Packs, lessons, flashcard decks and syllabus topics, all in one field.
            </p>
          </div>
        </header>

        <div className="mt-6">
          <div className="flex items-center gap-2 rounded-xl bg-card px-4 py-3 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] ring-1 ring-outline-variant/40 focus-within:ring-2 focus-within:ring-primary">
            <span className="material-symbols-outlined text-[22px] text-on-surface-variant">search</span>
            <input
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder='Try "cells", "essay" or "Newton"'
              className="w-full bg-transparent text-[15px] text-on-surface outline-none placeholder:text-outline"
              aria-label="Search Renance"
            />
            {query && (
              <button
                type="button"
                onClick={() => setQuery('')}
                className="text-on-surface-variant transition hover:text-on-surface"
                aria-label="Clear search"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            )}
          </div>
        </div>

        {!query.trim() ? (
          <p className="mt-8 rounded-xl border border-outline-variant/60 bg-surface-container-lowest px-5 py-4 text-sm text-on-surface-variant shadow-sm">
            Everything you have synced is searchable, including offline data. Results
            open straight into the matching shelf.
          </p>
        ) : total === 0 ? (
          <div className="mt-10 flex flex-col items-center gap-2 text-center">
            <span className="material-symbols-outlined text-[40px] text-outline-light">search_off</span>
            <p className="font-semibold text-on-surface">Nothing matches yet</p>
            <p className="text-sm text-on-surface-variant">Check the spelling or try a shorter word.</p>
          </div>
        ) : (
          <div className="mt-6 space-y-6">
            {(['packs', 'lessons', 'decks', 'topics'] as Shelf[]).map((shelf) => {
              const hits = grouped.get(shelf);
              if (!hits?.length) return null;
              return (
                <section key={shelf}>
                  <div className="flex items-baseline justify-between">
                    <h2 className="font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
                      {SHELF_LABEL[shelf]}
                    </h2>
                    <span className="font-mono text-xs text-on-surface">{hits.length}</span>
                  </div>
                  <div className="mt-2 grid grid-cols-1 gap-3 sm:grid-cols-2">
                    {hits.slice(0, 6).map((hit) => (
                      <Link
                        key={`${hit.shelf}-${hit.href}-${hit.title}`}
                        href={hit.href}
                        className="group flex items-center gap-3 rounded-xl bg-card p-3.5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)] transition hover:shadow-md"
                      >
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-surface-container-highest text-primary">
                          <span className="material-symbols-outlined text-[20px]">{hit.icon}</span>
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] font-semibold text-on-surface">{hit.title}</p>
                          <p className="truncate text-[13px] text-on-surface-variant">{hit.subtitle}</p>
                        </div>
                        <span className="material-symbols-outlined text-outline transition group-hover:translate-x-0.5 group-hover:text-on-surface-variant">
                          chevron_right
                        </span>
                      </Link>
                    ))}
                  </div>
                </section>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}
