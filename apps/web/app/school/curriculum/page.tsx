'use client';

/**
 * The school portal's Curriculum Bank: the national scheme of work and
 * lesson notes for every class from Nursery 1 to SSS 3, fetched from the
 * baked corpus and displayed straight on the page. Management reads any
 * class's weekly scheme and opens the note under every topic; nothing is
 * copied into the school account, the bank itself is the content.
 */

import { Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
} from '@/components/school-shell';
import { downloadTopicPdf, type NotePdfMeta } from '@/lib/note-pdf';
import {
  fetchCorpusIndex,
  loadCorpusNotes,
  loadCorpusSchemes,
  type CorpusClass,
  type CorpusIndex,
  type CorpusNoteTerm,
  type CorpusSchemeTerm,
} from '@/lib/corpus';

const TERM_LABEL: Record<number, string> = { 1: 'First term', 2: 'Second term', 3: 'Third term' };

export default function SchoolCurriculumPage() {
  return (
    <SchoolShell title="Curriculum Bank">
      <Suspense fallback={<p className="text-sm text-on-surface-variant">Opening the bank…</p>}>
        <CurriculumInner />
      </Suspense>
    </SchoolShell>
  );
}

function CurriculumInner() {
  const [index, setIndex] = useState<CorpusIndex | null>(null);
  const [stage, setStage] = useState('');
  const [classId, setClassId] = useState('');
  const [subject, setSubject] = useState('');
  const [term, setTerm] = useState(1);
  const [schemes, setSchemes] = useState<CorpusSchemeTerm[]>([]);
  const [notes, setNotes] = useState<CorpusNoteTerm[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    fetchCorpusIndex()
      .then((idx) => {
        if (!alive) return;
        setIndex(idx);
        const stages = [...new Set(idx.classes.map((c) => c.stage))];
        const first = idx.classes.find((c) => c.stage === stages[0]);
        if (first) {
          setStage(first.stage);
          setClassId(first.id);
        }
      })
      .catch(() => alive && setError('The curriculum bank could not load. Refresh to try again.'));
    return () => {
      alive = false;
    };
  }, []);

  const activeClass = useMemo(
    () => index?.classes.find((c) => c.id === classId) ?? null,
    [index, classId],
  );
  const activeSubject = useMemo(
    () => activeClass?.subjects.find((s) => s.id === subject) ?? null,
    [activeClass, subject],
  );

  useEffect(() => {
    if (!activeSubject) return;
    const available = activeSubject.schemeTerms.length
      ? activeSubject.schemeTerms
      : activeSubject.noteTerms;
    if (available.length && !available.includes(term)) setTerm(available[0]);
  }, [activeSubject, term]);

  useEffect(() => {
    if (!classId || !subject) {
      setSchemes([]);
      setNotes([]);
      return;
    }
    let alive = true;
    setLoading(true);
    setError('');
    Promise.all([loadCorpusSchemes(classId, subject), loadCorpusNotes(classId, subject)])
      .then(([sc, nt]) => {
        if (!alive) return;
        setSchemes(sc);
        setNotes(nt);
      })
      .catch(() => alive && setError('This subject could not load. Try another one.'))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [classId, subject]);

  const onPickClass = useCallback((cls: CorpusClass) => {
    setClassId(cls.id);
    setStage(cls.stage);
    setSubject('');
    setSchemes([]);
    setNotes([]);
  }, []);

  const scheme = schemes.find((s) => s.term === term) ?? null;
  const note = notes.find((n) => n.term === term) ?? null;

  return (
    <>
      <SchoolHeading
        title="Curriculum Bank"
        sub="The national bank: NERDC-aligned scheme of work and ready lesson notes for every class from Nursery 1 to SSS 3, fetched and displayed straight from the Renance curriculum library. Read any week here and download its note as a PDF."
      />

      {error && !index && (
        <Card>
          <p className="text-sm text-on-surface-variant">{error}</p>
        </Card>
      )}

      {index && (
        <>
          <StageTabs
            classes={index.classes}
            stage={stage}
            onPickStage={(s) => {
              setStage(s);
              const first = index.classes.find((c) => c.stage === s);
              if (first) onPickClass(first);
            }}
          />

          <ClassPills classes={index.classes.filter((c) => c.stage === stage)} active={classId} onPick={onPickClass} />

          <section className="mt-6">
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-on-surface-variant">
              Subjects {activeClass ? `in ${activeClass.name}` : ''}
            </h2>
            {!activeClass && (
              <p className="text-sm text-on-surface-variant">Pick a class to list its subjects.</p>
            )}
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {activeClass?.subjects.map((s) => {
                const active = s.id === subject;
                const readTerms = [...new Set([...s.schemeTerms, ...s.noteTerms])].length;
                return (
                  <button
                    key={s.id}
                    onClick={() => setSubject(s.id)}
                    className={`rounded-xl border px-4 py-3 text-left transition ${
                      active
                        ? 'border-primary bg-primary text-on-primary'
                        : 'border-outline-variant bg-surface-container-lowest text-on-surface hover:bg-surface-container'
                    }`}
                  >
                    <span className="block text-sm font-semibold">{s.name}</span>
                    <span className={`mt-0.5 block text-xs ${active ? 'text-on-primary/80' : 'text-on-surface-variant'}`}>
                      {readTerms} term{readTerms === 1 ? '' : 's'} available
                    </span>
                  </button>
                );
              })}
            </div>
          </section>

          {activeSubject && (
            <section className="mt-8">
              <div className="mb-4 flex flex-wrap items-center gap-2">
                <h2 className="mr-2 text-lg font-semibold text-on-surface">
                  {activeClass?.name} &middot; {activeSubject.name}
                </h2>
                {[...new Set([...activeSubject.schemeTerms, ...activeSubject.noteTerms])].map((t) => (
                  <button
                    key={t}
                    onClick={() => setTerm(t)}
                    className={`rounded-full px-4 py-1.5 text-xs font-medium transition ${
                      t === term
                        ? 'bg-primary text-on-primary'
                        : 'border border-outline text-on-surface hover:bg-surface-container'
                    }`}
                  >
                    {TERM_LABEL[t] ?? `Term ${t}`}
                  </button>
                ))}
              </div>

              {loading && <p className="text-sm text-on-surface-variant">Loading the bank…</p>}

              {!loading && !scheme && !note && (
                <Card>
                  <p className="text-sm text-on-surface-variant">
                    No scheme or note files for this term yet. The corpus keeps growing with every
                    release.
                  </p>
                </Card>
              )}

              {scheme && (
                <SchemePanel
                  meta={{
                    className: activeClass?.name ?? '',
                    subject: activeSubject.name,
                    term,
                  }}
                  scheme={scheme}
                  note={note}
                />
              )}
            </section>
          )}
        </>
      )}
    </>
  );
}

/* ------------------------------------------------------------------ tabs */

function StageTabs({
  classes,
  stage,
  onPickStage,
}: {
  classes: CorpusClass[];
  stage: string;
  onPickStage: (stage: string) => void;
}) {
  const stages = useMemo(() => {
    const seen = new Map<string, string>();
    for (const c of classes) if (!seen.has(c.stage)) seen.set(c.stage, c.stageLabel);
    return [...seen.entries()];
  }, [classes]);

  return (
    <div className="mb-4 flex flex-wrap gap-2">
      {stages.map(([id, label]) => (
        <button
          key={id}
          onClick={() => onPickStage(id)}
          className={`rounded-full px-4 py-2 text-sm font-medium transition ${
            id === stage
              ? 'bg-primary text-on-primary'
              : 'border border-outline-variant bg-surface-container-lowest text-on-surface hover:bg-surface-container'
          }`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}

function ClassPills({
  classes,
  active,
  onPick,
}: {
  classes: CorpusClass[];
  active: string;
  onPick: (cls: CorpusClass) => void;
}) {
  return (
    <div className="no-scrollbar flex gap-2 overflow-x-auto pb-1">
      {classes.map((c) => (
        <button
          key={c.id}
          onClick={() => onPick(c)}
          className={`shrink-0 rounded-full px-4 py-1.5 text-sm transition ${
            c.id === active
              ? 'bg-on-surface text-surface'
              : 'border border-outline-variant text-on-surface hover:bg-surface-container'
          }`}
        >
          {c.name}
        </button>
      ))}
    </div>
  );
}

/* ---------------------------------------------------------------- panel */

function SchemePanel({
  meta,
  scheme,
  note,
}: {
  meta: { className: string; subject: string; term: number };
  scheme: CorpusSchemeTerm;
  note: CorpusNoteTerm | null;
}) {
  const [openWeek, setOpenWeek] = useState<number | null>(null);
  const noteByWeek = useMemo(() => {
    const map = new Map<number, CorpusNoteTerm['topics'][number]>();
    for (const t of note?.topics ?? []) map.set(t.week, t);
    return map;
  }, [note]);

  return (
    <div className="min-w-0 overflow-hidden rounded-xl border border-outline-variant bg-surface-container-lowest">
      <div className="border-b border-outline-variant bg-surface-container px-5 py-3">
        <p className="text-sm font-semibold text-on-surface">Scheme of work</p>
        <p className="text-xs text-on-surface-variant">
          {scheme.weeks.length} teaching weeks. The note under every topic opens inline.
        </p>
      </div>
      <ol className="divide-y divide-outline-variant">
        {scheme.weeks.map((w) => {
          const noteTopic = noteByWeek.get(w.week);
          const open = openWeek === w.week;
          return (
            <li key={w.week} className="px-5 py-4">
              <div className="flex flex-wrap items-start gap-3">
                <span className="mt-0.5 shrink-0 rounded-full border border-outline-variant px-2.5 py-1 text-xs font-medium text-on-surface">
                  Week {w.week}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-on-surface">{w.topic}</p>
                  {w.content && (
                    <p className="mt-1 whitespace-pre-line text-sm leading-6 text-on-surface-variant">{w.content}</p>
                  )}
                </div>
                {noteTopic && (
                  <button
                    onClick={() => setOpenWeek(open ? null : w.week)}
                    className="shrink-0 rounded-full border border-outline px-3 py-1.5 text-xs font-medium text-on-surface hover:bg-surface-container"
                  >
                    {open ? 'Hide note' : 'Read note'}
                  </button>
                )}
              </div>

              {open && noteTopic && (
                <div className="mt-4 rounded-lg border border-outline-variant bg-surface-container p-4">
                  <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-on-surface">{noteTopic.title}</p>
                    <button
                      onClick={() =>
                        downloadTopicPdf(
                          {
                            schoolName: 'Renance National Curriculum',
                            className: meta.className,
                            subject: meta.subject,
                            term: meta.term,
                          } satisfies NotePdfMeta,
                          {
                            id: `corpus-${meta.className}-${meta.subject}-${meta.term}-${noteTopic.week}`,
                            title: noteTopic.title,
                            content: noteTopic.content,
                            week: noteTopic.week,
                            seq: noteTopic.week,
                            source: 'renance-corpus',
                          },
                        )
                      }
                      className="rounded-full border border-outline px-3 py-1.5 text-xs text-on-surface hover:bg-surface-container-lowest"
                    >
                      Download PDF
                    </button>
                  </div>
                  <p className="whitespace-pre-line text-sm leading-6 text-on-surface-variant">{noteTopic.content}</p>
                </div>
              )}
            </li>
          );
        })}
      </ol>
    </div>
  );
}
