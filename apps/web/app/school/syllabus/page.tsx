'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { SchoolHeading, SchoolShell, btnGhost, btnPrimary, inputCls, selectCls } from '@/components/school-shell';
import {
  fetchAssignments,
  fetchClassSubjects,
  fetchSyllabus,
  getActiveSchool,
  saveScheme,
  saveTopic,
  termLabel,
  type ActiveSchool,
  type SchoolSyllabus,
  type SchoolTopic,
  type SchemeRow,
} from '@/lib/school';
import {
  fetchCorpusIndex,
  loadCorpusNotes,
  loadCorpusSchemes,
  type CorpusNoteTerm,
  type CorpusSchemeTerm,
} from '@/lib/corpus';
import { downloadTopicPdf, type NotePdfMeta } from '@/lib/note-pdf';

export default function SchoolSyllabusPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [pairs, setPairs] = useState<{ classId: string; className: string; subjectId: string; subjectName: string }[]>([]);
  const [classId, setClassId] = useState('');
  const [subjectId, setSubjectId] = useState('');
  const [terms, setTerms] = useState<SchoolSyllabus[]>([]);
  const [openTerm, setOpenTerm] = useState(1);
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState('');

  // National bank fallback: when this school has no terms of its own for
  // the picked class + subject, fetch the NERDC corpus straight from the
  // curriculum library and display it right here (founder directive: no
  // install step anywhere, just fetch and display).
  const [national, setNational] = useState<{
    className: string;
    subjectName: string;
    terms: number[];
    schemes: CorpusSchemeTerm[];
    notes: CorpusNoteTerm[];
  } | null>(null);
  const [nationalTerm, setNationalTerm] = useState(1);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setActive(a);
    (async () => {
      try {
        if (a.role === 'teacher') {
          const asg = await fetchAssignments(a.schoolId, a.memberId);
          const mine = (asg.assignments ?? []).map((x) => ({
            classId: x.classId,
            className: x.className,
            subjectId: x.subjectId,
            subjectName: x.subjectName,
          }));
          setPairs(mine);
          if (mine[0]) {
            setClassId(mine[0].classId);
            setSubjectId(mine[0].subjectId);
          }
        } else {
          const res = await fetchClassSubjects(a.schoolId);
          setPairs(res.pairs ?? []);
          if (res.pairs?.[0]) {
            setClassId(res.pairs[0].classId);
            setSubjectId(res.pairs[0].subjectId);
          }
        }
      } catch {
        /* handled by empty state */
      }
    })();
  }, []);

  const loadTerms = useCallback(async () => {
    if (!active || !classId || !subjectId) return;
    setLoading(true);
    setNotice('');
    try {
      const res = await fetchSyllabus(active.schoolId, classId, subjectId);
      setTerms(res.terms ?? []);
      if ((res.terms ?? []).length > 0) setOpenTerm(res.terms[0].term);
    } finally {
      setLoading(false);
    }
  }, [active, classId, subjectId]);

  useEffect(() => {
    loadTerms();
  }, [loadTerms]);

  useEffect(() => {
    let alive = true;
    setNational(null);
    if (loading || terms.length > 0 || !classId || !subjectId) return () => { alive = false; };
    const pair = pairs.find((p) => p.classId === classId && p.subjectId === subjectId);
    if (!pair) return () => { alive = false; };
    (async () => {
      try {
        const idx = await fetchCorpusIndex();
        const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
        const cls = idx.classes.find(
          (c) => slug(c.id) === slug(pair.className) || slug(c.name) === slug(pair.className),
        );
        if (!cls) return;
        const subj = cls.subjects.find(
          (s) => slug(s.id) === slug(pair.subjectName) || slug(s.name) === slug(pair.subjectName),
        );
        if (!subj) return;
        const available = [...new Set([...subj.schemeTerms, ...subj.noteTerms])].sort((a, b) => a - b);
        if (!available.length) return;
        const [sc, nt] = await Promise.all([
          loadCorpusSchemes(cls.id, subj.id),
          loadCorpusNotes(cls.id, subj.id),
        ]);
        if (!alive) return;
        setNational({
          className: cls.name,
          subjectName: subj.name,
          terms: available,
          schemes: sc,
          notes: nt,
        });
        setNationalTerm(available[0]);
      } catch {
        /* the bank is optional here; the empty state still explains */
      }
    })();
    return () => {
      alive = false;
    };
  }, [loading, terms.length, classId, subjectId, pairs]);

  // The class picker shows only classes that appear in the allowed pairs.
  const classes = useMemo(() => {
    const seen = new Map<string, string>();
    for (const p of pairs) seen.set(p.classId, p.className);
    return [...seen.entries()].map(([id, name]) => ({ id, name }));
  }, [pairs]);

  const subjects = useMemo(
    () => pairs.filter((p) => p.classId === classId).map((p) => ({ id: p.subjectId, name: p.subjectName })),
    [pairs, classId],
  );

  const current = terms.find((t) => t.term === openTerm);
  const pairName = pairs.find((p) => p.classId === classId && p.subjectId === subjectId);
  const canEdit = active?.role === 'management' || !!pairs.find((p) => p.classId === classId && p.subjectId === subjectId);

  async function onEditTopic(topic: SchoolTopic, title: string, content: string, week: number) {
    if (!active) return;
    await saveTopic(active.schoolId, topic.id, title, content, week);
    setNotice(`Saved "${title}".`);
    await loadTerms();
  }

  async function onEditScheme(sy: SchoolSyllabus) {
    if (!active) return;
    const rows: SchemeRow[] = (sy.schemeOfWork ?? []).map((r) => ({ ...r }));
    // Simple scheme editor: one row per week, comma-newline format.
    const text = rows.map((r) => `${r.week}|${r.topic}`).join('\n');
    const next = window.prompt(
      'Scheme of work - one week per line as: week|topic\n(You can edit freely)',
      text || Array.from({ length: 10 }, (_, i) => `${i + 1}|`).join('\n'),
    );
    if (next == null) return;
    const scheme: SchemeRow[] = next
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean)
      .map((l) => {
        const [w, ...rest] = l.split('|');
        return { week: parseInt(w, 10) || 0, topic: rest.join('|').trim() };
      })
      .filter((r) => r.topic);
    await saveScheme(active.schoolId, sy.id, scheme);
    setNotice('Scheme of work saved.');
    await loadTerms();
  }

  const pdfMeta: { schoolName: string; className: string; subject: string; term: number; session: string } | null =
    active && pairName
      ? {
          schoolName: active.schoolName,
          className: pairName.className,
          subject: pairName.subjectName,
          term: openTerm,
          session: current?.session || '',
        }
      : null;

  const nationalScheme = national?.schemes.find((s) => s.term === nationalTerm) ?? null;
  const nationalNote = national?.notes.find((n) => n.term === nationalTerm) ?? null;

  return (
    <SchoolShell title="Syllabus & Notes">
      <SchoolHeading
        title="Syllabus, scheme of work & notes"
        sub="Pick a class and subject. Each term holds the weekly scheme, topics and the note under every topic - download any topic's note as a clean black & white PDF."
      />

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-outline-variant bg-surface-container-lowest px-4 py-3">
        <p className="min-w-0 text-sm text-on-surface-variant">
          Need a head start? The national curriculum bank carries a NERDC-aligned scheme of work and
          ready lesson notes for every class from Nursery 1 to SSS 3.
        </p>
        <Link
          href="/school/curriculum"
          className="shrink-0 rounded-full border border-outline px-4 py-2 text-sm font-medium text-on-surface hover:bg-surface-container"
        >
          Open the curriculum bank
        </Link>
      </div>

      <div className="mb-6 grid gap-3 md:grid-cols-2">
        <select className={selectCls} value={classId} onChange={(e) => setClassId(e.target.value)}>
          {classes.length === 0 && <option value="">No classes available</option>}
          {classes.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select className={selectCls} value={subjectId} onChange={(e) => setSubjectId(e.target.value)}>
          {subjects.length === 0 && <option value="">No subjects available</option>}
          {subjects.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </div>

      {notice && (
        <p className="mb-4 rounded-lg bg-surface-container px-4 py-3 text-sm text-on-surface">{notice}</p>
      )}

      {loading && <p className="text-sm text-on-surface-variant">Loading syllabus…</p>}

      {!loading && terms.length === 0 && (
        <div className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6 text-sm text-on-surface-variant">
          No syllabus terms for this class + subject yet. Below is the national NERDC scheme of work
          with ready lesson notes, fetched straight from the{' '}
          <Link href="/school/curriculum" className="underline">Curriculum Bank</Link> - read it here
          or hand it to teachers. Anything your school writes itself will appear above it.
        </div>
      )}

      {!loading && terms.length === 0 && national && (
        <NationalBank
          className={national.className}
          subjectName={national.subjectName}
          terms={national.terms}
          term={nationalTerm}
          onTerm={setNationalTerm}
          scheme={nationalScheme}
          note={nationalNote}
        />
      )}

      <div className="flex flex-col gap-4">
        {terms.map((sy) => {
          const open = sy.term === openTerm;
          return (
            <section key={sy.id} className="rounded-xl border border-outline-variant bg-surface-container-lowest">
              <header className="flex flex-wrap items-center gap-3 border-b border-outline-variant px-5 py-4">
                <button
                  className="flex-1 text-left text-base font-semibold text-on-surface"
                  onClick={() => setOpenTerm(sy.term)}
                >
                  {termLabel(sy.term)}
                  {sy.session ? ` · ${sy.session}` : ''}
                  <span className="ml-2 text-sm font-normal text-on-surface-variant">
                    {sy.topics.length} topic{sy.topics.length === 1 ? '' : 's'}
                  </span>
                </button>
                {open && (
                  <button className={btnGhost} onClick={() => onEditScheme(sy)}>
                    Edit scheme of work
                  </button>
                )}
              </header>

              {open && (
                <div className="flex flex-col gap-4 p-5">
                  {(sy.schemeOfWork ?? []).length > 0 && (
                    <div className="rounded-lg bg-surface-container p-4">
                      <h3 className="text-sm font-semibold text-on-surface">Scheme of work</h3>
                      <ol className="mt-2 grid gap-1 text-sm text-on-surface-variant md:grid-cols-2">
                        {sy.schemeOfWork.map((r, i) => (
                          <li key={i}>
                            <span className="font-medium text-on-surface">Week {r.week}:</span> {r.topic}
                          </li>
                        ))}
                      </ol>
                    </div>
                  )}

                  {sy.topics.length === 0 && (
                    <p className="text-sm text-on-surface-variant">
                      No topics yet for {termLabel(sy.term)}.
                    </p>
                  )}

                  {sy.topics.map((t) => (
                    <TopicCard
                      key={t.id}
                      topic={t}
                      canEdit={canEdit}
                      pdfMeta={pdfMeta}
                      onSave={(title, content, week) => onEditTopic(t, title, content, week)}
                    />
                  ))}
                </div>
              )}
            </section>
          );
        })}
      </div>
    </SchoolShell>
  );
}

function TopicCard({
  topic,
  canEdit,
  pdfMeta,
  onSave,
}: {
  topic: SchoolTopic;
  canEdit: boolean;
  pdfMeta: { schoolName: string; className: string; subject: string; term: number; session: string } | null;
  onSave: (title: string, content: string, week: number) => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(topic.title);
  const [content, setContent] = useState(topic.content);
  const [week, setWeek] = useState(topic.week);
  const [busy, setBusy] = useState(false);

  return (
    <article className="rounded-lg border border-outline-variant bg-surface-container p-4">
      <div className="flex flex-wrap items-center gap-2">
        <span className="rounded-full bg-surface-container-lowest px-2.5 py-1 text-xs font-medium text-on-surface">
          {topic.week ? `Week ${topic.week}` : `Topic ${topic.seq}`}
        </span>
        <h3 className="flex-1 text-sm font-semibold text-on-surface">{topic.title}</h3>
        {pdfMeta && (
          <button
            className="rounded-full border border-outline px-3 py-1.5 text-xs text-on-surface hover:bg-surface-container-lowest"
            onClick={() => downloadTopicPdf(pdfMeta, topic)}
            title="Download this topic's note as a black & white PDF"
          >
            PDF
          </button>
        )}
        {canEdit && (
          <button
            className="rounded-full border border-outline px-3 py-1.5 text-xs text-on-surface hover:bg-surface-container-lowest"
            onClick={() => setEditing((v) => !v)}
          >
            {editing ? 'Close' : 'Edit note'}
          </button>
        )}
      </div>

      {!editing && (
        <p className="mt-3 whitespace-pre-line text-sm leading-6 text-on-surface-variant">
          {topic.content || 'No note yet - open Edit note to write one.'}
        </p>
      )}

      {editing && (
        <div className="mt-3 flex flex-col gap-3">
          <div className="grid gap-3 md:grid-cols-[2fr_1fr]">
            <input className={inputCls} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Topic title" />
            <input
              className={inputCls}
              type="number"
              min={0}
              max={20}
              value={week}
              onChange={(e) => setWeek(parseInt(e.target.value, 10) || 0)}
              placeholder="Week"
            />
          </div>
          <textarea
            className={`${inputCls} min-h-48 py-3 leading-6`}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Write the note for this topic (blank line = new paragraph)"
          />
          <p className="text-xs text-on-surface-variant">
            House style: notes print black & white only. One blank line starts a new paragraph.
          </p>
          <button
            className={btnPrimary}
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await onSave(title, content, week);
                setEditing(false);
              } finally {
                setBusy(false);
              }
            }}
          >
            {busy ? 'Saving…' : 'Save note'}
          </button>
        </div>
      )}
    </article>
  );
}

/* ------------------------------------------------------- national bank */

const TERM_LABEL: Record<number, string> = { 1: 'First term', 2: 'Second term', 3: 'Third term' };

/**
 * The national NERDC scheme + notes for a class + subject this school has
 * not written its own terms for yet. Same read-only display as the
 * Curriculum Bank: every week opens its note inline, each note prints to
 * a clean black & white PDF. Nothing is stored against the school.
 */
function NationalBank({
  className,
  subjectName,
  terms,
  term,
  onTerm,
  scheme,
  note,
}: {
  className: string;
  subjectName: string;
  terms: number[];
  term: number;
  onTerm: (t: number) => void;
  scheme: CorpusSchemeTerm | null;
  note: CorpusNoteTerm | null;
}) {
  const [openWeek, setOpenWeek] = useState<number | null>(null);
  const noteByWeek = useMemo(() => {
    const map = new Map<number, NonNullable<CorpusNoteTerm['topics']>[number]>();
    for (const t of note?.topics ?? []) map.set(t.week, t);
    return map;
  }, [note]);

  if (!scheme && !note) return null;

  return (
    <section className="mt-2">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <h2 className="mr-2 text-lg font-semibold text-on-surface">
          National curriculum · {className} · {subjectName}
        </h2>
        {terms.map((t) => (
          <button
            key={t}
            onClick={() => onTerm(t)}
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

      {scheme && (
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
                                className,
                                subject: subjectName,
                                term,
                              } satisfies NotePdfMeta,
                              {
                                id: `corpus-${className}-${subjectName}-${term}-${noteTopic.week}`,
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
      )}

      {!scheme && note && (
        <div className="rounded-xl border border-outline-variant bg-surface-container-lowest p-6 text-sm text-on-surface-variant">
          Lesson notes for this subject are in the bank; the term scheme file is still landing.
        </div>
      )}
    </section>
  );
}
