'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
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
  seedSchemes,
} from '@/lib/school';
import { downloadTopicPdf } from '@/lib/note-pdf';

export default function SchoolSyllabusPage() {
  const [active, setActive] = useState<ActiveSchool | null>(null);
  const [pairs, setPairs] = useState<{ classId: string; className: string; subjectId: string; subjectName: string }[]>([]);
  const [classId, setClassId] = useState('');
  const [subjectId, setSubjectId] = useState('');
  const [terms, setTerms] = useState<SchoolSyllabus[]>([]);
  const [openTerm, setOpenTerm] = useState(1);
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState('');

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

  async function draftSchemes() {
    const a = getActiveSchool();
    if (!a) return;
    setSeeding(true);
    setNotice('');
    try {
      const res = await seedSchemes(a.schoolId, session);
      setNotice(`Drafted ${res.filled} scheme${res.filled === 1 ? '' : 's'} for ${session}.`);
    } catch {
      setNotice('Could not draft the schemes.');
    } finally {
      setSeeding(false);
    }
  }

  return (
    <SchoolShell title="Syllabus & Notes">
      <SchoolHeading
        title="Syllabus, scheme of work & notes"
        sub="Pick a class and subject. Each term holds the weekly scheme, topics and the note under every topic - download any topic's note as a clean black & white PDF."
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <input
          value={session}
          onChange={(e) => setSession(e.target.value)}
          placeholder="Session (2025/2026)"
          className={`${inputCls} h-11 w-auto min-w-40`}
          aria-label="Session"
        />
        <button onClick={draftSchemes} disabled={seeding || !active || active.role !== 'management'} className={btnPrimary}>
          {seeding ? 'Drafting…' : 'Draft empty schemes'}
        </button>
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
          No syllabus terms for this class + subject yet. Open it once from the app or ask management
          to install the curriculum from the Overview page - the three terms are created automatically.
        </div>
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
