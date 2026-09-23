'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnGhost,
  btnPrimary,
  btnSmall,
  inputCls,
  selectCls,
} from '@/components/school-shell';
import {
  fetchClasses,
  fetchSubjects,
  getActiveSchool,
  type SchoolClass,
  type SchoolSubject,
} from '@/lib/school';
import {
  LETTERS,
  addExamQuestion,
  bandForClassName,
  deleteExamQuestion,
  fetchExamPaper,
  fetchExamQuestions,
  fetchExams,
  publishExam,
  seedExamBank,
  type ExamQuestion,
  type SchoolExam,
} from '@/lib/school-exams';

// The exam desk: a question bank per subject per term plus published
// papers. Publishing pins a paper for a class; opening it draws the
// questions from the pool, ready to print or to sit online.

const SESSIONS = ['2025/2026', '2026/2027', '2027/2028'];

export default function SchoolExamsPage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [subjects, setSubjects] = useState<SchoolSubject[]>([]);
  const [term, setTerm] = useState(1);
  const [session, setSession] = useState(SESSIONS[0]);
  const [tab, setTab] = useState<'pool' | 'papers'>('pool');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [management, setManagement] = useState(false);

  // pool state
  const [subjectId, setSubjectId] = useState('');
  const [band, setBand] = useState('');
  const [questions, setQuestions] = useState<ExamQuestion[]>([]);
  const [qText, setQText] = useState('');
  const [poolSearch, setPoolSearch] = useState('');
  const [opts, setOpts] = useState(['', '', '', '']);
  const [answer, setAnswer] = useState(0);
  const [expl, setExpl] = useState('');

  // papers state
  const [exams, setExams] = useState<SchoolExam[]>([]);
  const [pubClass, setPubClass] = useState('');
  const [pubSubject, setPubSubject] = useState('');
  const [pubCount, setPubCount] = useState(40);
  const [pubMinutes, setPubMinutes] = useState(60);
  const [pubTitle, setPubTitle] = useState('');
  const [paper, setPaper] = useState<{ exam: SchoolExam; questions: ExamQuestion[] } | null>(null);

  const loadPool = useCallback(async () => {
    const a = getActiveSchool();
    if (!a || !subjectId) return;
    const res = await fetchExamQuestions(a.schoolId, subjectId, term, session, band);
    setQuestions(res.questions ?? []);
  }, [subjectId, term, session, band]);

  const loadPapers = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const res = await fetchExams(a.schoolId, term, session);
    setExams(res.exams ?? []);
  }, [term, session]);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setManagement(a.role === 'management');
    Promise.all([fetchClasses(a.schoolId), fetchSubjects(a.schoolId)])
      .then(([c, s]) => {
        setClasses(c.classes ?? []);
        setSubjects(s.subjects ?? []);
      })
      .catch(() => setNotice('Could not load classes and subjects.'));
  }, []);

  useEffect(() => {
    if (tab === 'pool') loadPool().catch(() => setNotice('Could not load the pool.'));
    if (tab === 'papers') loadPapers().catch(() => setNotice('Could not load the papers.'));
  }, [tab, loadPool, loadPapers]);

  async function submitQuestion() {
    const a = getActiveSchool();
    if (!a || !subjectId) {
      setNotice('Pick a subject first.');
      return;
    }
    if (!qText.trim() || opts.filter((o) => o.trim()).length < 2) {
      setNotice('A question and at least two options are required.');
      return;
    }
    setBusy(true);
    setNotice('');
    try {
      await addExamQuestion(a.schoolId, {
        subjectId,
        band,
        term,
        session,
        question: qText.trim(),
        options: opts.map((o) => o.trim()).filter(Boolean),
        answerIndex: answer,
        explanation: expl.trim(),
        marks: 1,
      });
      setQText('');
      setOpts(['', '', '', '']);
      setAnswer(0);
      setExpl('');
      await loadPool();
      setNotice('Question added to the bank.');
    } catch {
      setNotice('Could not save the question.');
    } finally {
      setBusy(false);
    }
  }

  async function removeQuestion(id: string) {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    try {
      await deleteExamQuestion(a.schoolId, id);
      await loadPool();
    } catch {
      setNotice('Could not delete the question.');
    } finally {
      setBusy(false);
    }
  }

  async function pourStarter() {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    setNotice('');
    try {
      const res = await seedExamBank(a.schoolId);
      setNotice(`Added ${res.added} starter question${res.added === 1 ? '' : 's'} to the bank.`);
      await loadPool();
    } catch {
      setNotice('Could not pour the starter questions.');
    } finally {
      setBusy(false);
    }
  }

  async function submitPublish() {
    const a = getActiveSchool();
    if (!a || !pubClass || !pubSubject) {
      setNotice('A class and a subject are required to publish.');
      return;
    }
    setBusy(true);
    setNotice('');
    try {
      await publishExam(a.schoolId, {
        classId: pubClass,
        subjectId: pubSubject,
        term,
        session,
        title: pubTitle.trim(),
        durationMinutes: pubMinutes,
        questionCount: pubCount,
      });
      setPubTitle('');
      await loadPapers();
      setNotice('Paper published.');
    } catch {
      setNotice('Could not publish the paper.');
    } finally {
      setBusy(false);
    }
  }

  async function openPaper(id: string) {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    setNotice('');
    try {
      const res = await fetchExamPaper(a.schoolId, id);
      setPaper({ exam: res.exam, questions: res.questions ?? [] });
    } catch {
      setNotice('Could not assemble the paper.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <SchoolShell title="Exam Bank">
      <SchoolHeading
        title="Exam Question Bank"
        sub="Original questions per subject per term, and the papers drawn from them. The bank grows with the school; nothing is copied."
        actions={
          <div className="flex gap-2">
            <select value={term} onChange={(e) => setTerm(Number(e.target.value))} className={`${selectCls} h-11 w-auto`} aria-label="Term">
              <option value={1}>First Term</option>
              <option value={2}>Second Term</option>
              <option value={3}>Third Term</option>
            </select>
            <select value={session} onChange={(e) => setSession(e.target.value)} className={`${selectCls} h-11 w-auto`} aria-label="Session">
              {SESSIONS.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>
        }
      />

      {notice && (
        <p className="mb-4 rounded-lg border border-outline-variant bg-surface-container-lowest px-4 py-3 text-sm text-on-surface-variant">
          {notice}
        </p>
      )}

      <div className="mb-5 flex gap-2" role="tablist" aria-label="Exam sections">
        {(['pool', 'papers'] as const).map((t) => (
          <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)} className={btnSmall + (tab === t ? ' bg-surface-container-high font-semibold' : '')}>
            {t === 'pool' ? 'Question pool' : 'Published papers'}
          </button>
        ))}
      </div>

      {tab === 'pool' && (
        <div className="grid gap-5 lg:grid-cols-[1fr_380px]">
          <Card className="overflow-hidden">
            <div className="mb-4 flex flex-wrap items-end justify-between gap-2">
              <div className="flex flex-wrap items-end gap-2">
                <select value={subjectId} onChange={(e) => setSubjectId(e.target.value)} className={`${selectCls} h-11 w-auto min-w-44`} aria-label="Subject">
                  <option value="">Subject?</option>
                  {subjects.map((s) => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
                </select>
                <select value={band} onChange={(e) => setBand(e.target.value)} className={`${selectCls} h-11 w-auto`} aria-label="Band">
                  <option value="">All bands</option>
                  <option value="primary">Primary</option>
                  <option value="junior">Junior</option>
                  <option value="senior">Senior</option>
                </select>
              </div>
              {management && (
                <button onClick={pourStarter} disabled={busy} className={btnSmall}>
                  Pour starter bank
                </button>
              )}
            </div>
            <input
              value={poolSearch}
              onChange={(e) => setPoolSearch(e.target.value)}
              placeholder="Search the pool..."
              className={`${inputCls} mb-3`}
              aria-label="Search questions"
            />
            <div className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
              <table className="w-full min-w-[560px] text-sm">
                <thead>
                  <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                    <th className="py-2 pr-3">Question</th>
                    <th className="py-2 pr-3 text-right">Answer</th>
                    {management && <th className="py-2" />}
                  </tr>
                </thead>
                <tbody>
                  {questions.length > 0 && (
                    <tr>
                      <td colSpan={3} className="pb-2 text-xs text-on-surface-variant">
                        Showing {questions.filter((q) => q.question.toLowerCase().includes(poolSearch.toLowerCase())).length} of {questions.length} questions
                      </td>
                    </tr>
                  )}
                  {questions.length === 0 && (
                    <tr>
                      <td colSpan={3} className="py-6 text-center text-on-surface-variant">
                        The pool is empty for this pick. Add the first question.
                      </td>
                    </tr>
                  )}
                  {questions
                    .filter((q) => q.question.toLowerCase().includes(poolSearch.toLowerCase()))
                    .map((q) => (
                    <tr key={q.id} className="border-b border-outline-variant/60 last:border-0 align-top">
                      <td className="py-3 pr-3">
                        <span className="font-medium text-on-surface">{q.question}</span>
                        <span className="mt-1 block text-xs text-on-surface-variant">
                          {q.options.map((o, i) => `${LETTERS[i] ?? '?'}. ${o}`).join('  |  ')}
                        </span>
                        {q.explanation && <span className="mt-1 block text-xs italic text-on-surface-variant">{q.explanation}</span>}
                      </td>
                      <td className="py-3 pr-3 text-right text-xs text-on-surface-variant">
                        {q.answerIndex >= 0
                          ? `Key: ${LETTERS[q.answerIndex] ?? q.answerIndex + 1}`
                          : 'Key pending'}
                      </td>
                      {management && (
                        <td className="py-3 text-right">
                          <button onClick={() => removeQuestion(q.id)} disabled={busy} className={btnSmall}>Drop</button>
                        </td>
                      )}
                    </tr>
                    ))}
                </tbody>
              </table>
            </div>
          </Card>

          <Card>
            <CardTitle hint="Two to six options; mark the correct one.">Add a question</CardTitle>
            <div className="space-y-3">
              <textarea
                value={qText}
                onChange={(e) => setQText(e.target.value)}
                placeholder="The question text"
                rows={3}
                className={`${inputCls} h-auto py-2.5`}
              />
              {opts.map((o, i) => (
                <div key={i} className="flex items-center gap-2">
                  <input
                    type="radio"
                    name="correct"
                    checked={answer === i}
                    onChange={() => setAnswer(i)}
                    className="h-4 w-4 accent-black"
                    aria-label={`Option ${LETTERS[i]} is correct`}
                  />
                  <input
                    value={o}
                    onChange={(e) => setOpts((cur) => cur.map((x, j) => (j === i ? e.target.value : x)))}
                    placeholder={`Option ${LETTERS[i]}`}
                    className={inputCls}
                  />
                </div>
              ))}
              <input value={expl} onChange={(e) => setExpl(e.target.value)} placeholder="Explanation (optional)" className={inputCls} />
              <button onClick={submitQuestion} disabled={busy} className={`${btnPrimary} w-full`}>
                Add to bank
              </button>
            </div>
          </Card>
        </div>
      )}

      {tab === 'papers' && (
        <div className="space-y-5">
          {management && (
            <Card>
              <CardTitle hint="Publishing pins a paper; open it to draw the questions.">Publish a paper</CardTitle>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <select value={pubClass} onChange={(e) => { setPubClass(e.target.value); const c = classes.find((x) => x.id === e.target.value); if (c) setBand(bandForClassName(c.name)); }} className={selectCls}>
                  <option value="">Class?</option>
                  {classes.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
                <select value={pubSubject} onChange={(e) => setPubSubject(e.target.value)} className={selectCls}>
                  <option value="">Subject?</option>
                  {subjects.map((s) => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
                </select>
                <input value={pubTitle} onChange={(e) => setPubTitle(e.target.value)} placeholder="Paper title (optional)" className={inputCls} />
                <label className="text-sm text-on-surface-variant">
                  Questions
                  <input type="number" min={1} max={100} value={pubCount} onChange={(e) => setPubCount(Number(e.target.value))} className={`${inputCls} mt-1`} />
                </label>
                <label className="text-sm text-on-surface-variant">
                  Duration (minutes)
                  <input type="number" min={5} max={300} value={pubMinutes} onChange={(e) => setPubMinutes(Number(e.target.value))} className={`${inputCls} mt-1`} />
                </label>
                <button onClick={submitPublish} disabled={busy} className={`${btnPrimary} self-end`}>
                  Publish
                </button>
              </div>
            </Card>
          )}

          <Card className="overflow-hidden">
            <CardTitle hint={`${exams.length} paper${exams.length === 1 ? '' : 's'} this term.`}>Papers</CardTitle>
            <div className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
              <table className="w-full min-w-[560px] text-sm">
                <thead>
                  <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                    <th className="py-2 pr-3">Paper</th>
                    <th className="py-2 pr-3">Class</th>
                    <th className="py-2 pr-3 text-right">Questions</th>
                    <th className="py-2 pr-3 text-right">Minutes</th>
                    <th className="py-2" />
                  </tr>
                </thead>
                <tbody>
                  {exams.length === 0 && (
                    <tr>
                      <td colSpan={5} className="py-6 text-center text-on-surface-variant">Nothing published yet.</td>
                    </tr>
                  )}
                  {exams.map((e) => (
                    <tr key={e.id} className="border-b border-outline-variant/60 last:border-0">
                      <td className="py-3 pr-3 font-medium text-on-surface">
                        {e.title || e.subjectName}
                        <span className="block text-xs font-normal text-on-surface-variant">{e.subjectName}</span>
                      </td>
                      <td className="py-3 pr-3 text-on-surface-variant">{e.className}</td>
                      <td className="py-3 pr-3 text-right">{e.questionCount}</td>
                      <td className="py-3 pr-3 text-right">{e.durationMinutes}</td>
                      <td className="py-3 text-right">
                        <button onClick={() => openPaper(e.id)} disabled={busy} className={btnSmall}>Open</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {paper && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-surface-container p-4 sm:p-8">
          <div className="mx-auto max-w-3xl space-y-4">
            <div className="flex items-center justify-between print:hidden">
              <h2 className="text-lg font-bold text-on-surface">{paper.exam.title || paper.exam.subjectName}</h2>
              <div className="flex gap-2">
                <button onClick={() => window.print()} className={btnPrimary}>Print</button>
                <button onClick={() => setPaper(null)} className={btnGhost}>Close</button>
              </div>
            </div>
            <Card>
              <div className="mb-4 border-b border-outline-variant pb-4 text-center">
                <p className="text-base font-bold text-on-surface">{paper.exam.className}</p>
                <p className="text-sm text-on-surface-variant">
                  {paper.exam.subjectName} | {paper.exam.session} | Duration: {paper.exam.durationMinutes} minutes
                </p>
              </div>
              <ol className="space-y-4">
                {paper.questions.map((q, qi) => (
                  <li key={q.id} className="text-sm">
                    <p className="font-medium text-on-surface">{qi + 1}. {q.question}</p>
                    <div className="mt-1.5 grid gap-1 pl-4 sm:grid-cols-2">
                      {q.options.map((o, oi) => (
                        <p key={oi} className="text-on-surface-variant">
                          ({LETTERS[oi] ?? oi + 1}) {o}
                        </p>
                      ))}
                    </div>
                  </li>
                ))}
              </ol>
              {paper.questions.length === 0 && (
                <p className="py-6 text-center text-sm text-on-surface-variant">
                  The pool behind this paper is empty. Add questions first.
                </p>
              )}
            </Card>
          </div>
        </div>
      )}
    </SchoolShell>
  );
}
