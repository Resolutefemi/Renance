'use client';

/**
 * LessonOverlay - the study → quiz → rewards flow of the merged learn
 * module (Supreme LessonOverlay adapted to Renance's tactile design,
 * 2026-10-14). Phases: loading (keycap splash) → study (notes + the
 * curated drawing library + key points) → quiz (up to 20 questions -
 * AI teaching items AND real past questions from the Renance bank) →
 * done (XP / gems / streak chips + confetti). Hearts are unlimited at
 * launch (founder directive), so wrong answers bank as mistakes but
 * never lock the student out.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { RenanceMark } from '@/components/renance-logo';
import {
  ConfettiBurst, GemIcon, HeartIcon, ProgressBar, ToastBanner,
} from '@/components/learn/bits';
import { ChestOpening, MilestoneCelebration, StreakCelebration } from '@/components/learn/celebrations';
import { FlagQuestionModal } from '@/components/learn/voice';
import {
  CompleteResult, CoursePath, LearnQuizQ, LessonDoc, PracticeQuestion,
  fetchCoursePath, fetchLearnProfile, fetchLesson, fetchPractice, fetchReview, fetchRevision, gradePractice, postProgress,
} from '@/lib/learn';
import { QText } from '@/lib/qtext';
import { SharePrompt } from '@/components/learn/share-prompt';

type Phase = 'loading' | 'study' | 'quiz' | 'submitting' | 'done' | 'error';

/** The celebration queue: chest → streak → milestone → share, one at a time. */
type Celebration = 'chest' | 'streak' | 'milestone' | 'share';

const LOADING_COPY = [
  'Sharpening the explanation…', 'Picking real past questions…',
  'Drawing the diagrams…', 'Stacking your XP…', 'Almost there…',
];

/** Fully-completed units of a course path: every topic the unit
 *  carries sits at status 'completed' (a unit that is still empty or
 *  generating never counts). Feed-automation detector (round 8). */
function countCompletedUnits(path: CoursePath): number {
  let done = 0;
  for (const unit of path.units) {
    const topics = path.topics.filter((t) => t.unit === unit.index);
    if (topics.length > 0 && topics.every((t) => t.status === 'completed')) done += 1;
  }
  return done;
}

type PlayQ = LearnQuizQ & { userAnswer?: string };

export function LessonOverlay({
  topicId, mode = 'lesson', courseId, unit, onClose, onCompleted,
}: {
  topicId?: string;
  /** lesson = full study+quiz flow; practice/review/revision = straight
   *  quiz (revision is the 50 question unit exam, founder 2026-10-16). */
  mode?: 'lesson' | 'practice' | 'review' | 'revision';
  courseId?: string;
  unit?: number;
  onClose: () => void;
  onCompleted?: (res: CompleteResult | null) => void;
}) {
  const [phase, setPhase] = useState<Phase>('loading');
  const [doc, setDoc] = useState<LessonDoc | null>(null);
  const [questions, setQuestions] = useState<PlayQ[]>([]);
  const [idx, setIdx] = useState(0);
  // The report-this-question surface (founder 2026-10-17): wrong keys
  // and broken questions land on the admin desk, not in a void.
  const [flagOpen, setFlagOpen] = useState(false);
  const [picked, setPicked] = useState<string | null>(null);
  const [revealed, setRevealed] = useState(false);
  const [correctCount, setCorrectCount] = useState(0);
  const [combo, setCombo] = useState(0);
  const [maxCombo, setMaxCombo] = useState(0);
  const [mistakes, setMistakes] = useState<PlayQ[]>([]);
  const [result, setResult] = useState<CompleteResult | null>(null);
  const [confetti, setConfetti] = useState(0);
  const [toast, setToast] = useState('');
  const [copyIdx, setCopyIdx] = useState(0);
  // Study pagination (founder bug report 2026-10-14: the explanation must
  // page through ONE section at a time - Supreme courses parity - never
  // a single wall of notes). studyStep walks the study pages.
  const [studyStep, setStudyStep] = useState(0);
  // The REAL heart count for the top rail (∞ retired, founder rule);
  // updated live when a completion pays back the economy.
  const [hearts, setHearts] = useState<number | null>(null);
  // The celebration queue (founder directive 2026-10-16): the topic
  // chest, the streak popup and the achievement card play one after
  // another on the done screen - each gets its full moment.
  const [celebQueue, setCelebQueue] = useState<Celebration[]>([]);
  // The feed-automation milestone (founder round 8): "N units done in
  // {course}!" - detected after a lesson completes, shown after the
  // celebration queue empties, deduped in localStorage.
  const [shareInfo, setShareInfo] = useState<{ units: number; courseTitle: string } | null>(null);
  const startedRef = useRef(Date.now());
  // The quiet self-reload (founder: "remove retry"): when a lesson
  // fails to load the overlay retries ITSELF a few times before it
  // ever shows a final error - no button for the scholar to press.
  const [reloadTick, setReloadTick] = useState(0);
  const errorRetries = useRef(0);

  // The lesson screen is a full takeover (fixed inset-0, its own close
  // button and stats header) - the global bottom tab bar must NOT sit
  // underneath it (founder report 2026-10-17: the persistent nav
  // crowded the lesson's bottom rows and the device home indicator).
  // While this overlay is mounted the nav is REMOVED. Mechanism: a
  // body flag (a late-mounting nav reads the truth) + a window event
  // (a live one gets the news). The study, quiz, loading and done
  // phases all run inside this single mount, so one flag covers them.
  useEffect(() => {
    document.body.dataset.lessonOpen = '1';
    window.dispatchEvent(new CustomEvent('renance:lesson-visibility'));
    return () => {
      delete document.body.dataset.lessonOpen;
      window.dispatchEvent(new CustomEvent('renance:lesson-visibility'));
    };
  }, []);

  useEffect(() => {
    let live = true;
    fetchLearnProfile()
      .then((p) => live && setHearts(p.hearts))
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);

  // ── Load ────────────────────────────────────────────────────────────────
  useEffect(() => {
    let live = true;
    (async () => {
      try {
        if (mode === 'lesson') {
          const d = await fetchLesson(topicId!, true);
          if (!live) return;
          setDoc(d);
          setQuestions((d.quiz ?? []).map((q) => ({ ...q })));
          setStudyStep(0);
          // Study the notes first; straight to the quiz when a cached
          // lesson somehow carries no questions.
          setPhase((d.quiz ?? []).length > 0 ? 'study' : 'quiz');
        } else {
          const set = mode === 'review'
            ? await fetchReview(courseId!, unit ?? 1)
            : mode === 'revision'
              ? await fetchRevision(courseId!, unit ?? 1)
              : await fetchPractice();
          if (!live) return;
          const qs: PlayQ[] = (set.questions ?? []).map((q: PracticeQuestion) => ({ ...q }));
          setQuestions(qs);
          // A quiz mode that arrives with no paper has nothing to show
          // in the quiz phase - route to the honest error state (the
          // overlay retries itself a few times first).
          setPhase(qs.length > 0 ? 'quiz' : 'error');
        }
      } catch {
        if (!live) return;
        setPhase('error');
        if (errorRetries.current < 4) {
          errorRetries.current += 1;
          window.setTimeout(() => {
            if (!live) return;
            setPhase('loading');
            setReloadTick((t) => t + 1);
          }, 5000);
        }
      }
    })();
    return () => { live = false; };
  }, [mode, topicId, courseId, unit, reloadTick]);
  // Rotating loading copy (Supreme touch).
  useEffect(() => {
    if (phase !== 'loading') return;
    const t = setInterval(() => setCopyIdx((i) => (i + 1) % LOADING_COPY.length), 2600);
    return () => clearInterval(t);
  }, [phase]);

  const q = questions[idx];
  const total = questions.length;
  const isLast = idx >= total - 1;

  // ── Study pagination layout: intro page, then one note per page, then
  // the drawings page (when the topic carries curated figures), then the
  // key-points page, then the theory-questions page (200L+ units, the
  // six-key orchestrator's assessment half). Derived from the loaded doc only.
  const studyPages = useMemo(() => {
    if (!doc) return { count: 1, notesEnd: 1, drawingsPage: -1, keysPage: -1, theoryPage: -1 };
    const hasDrawings = (doc.drawings?.length ?? 0) > 0;
    const hasKeys = (doc.keyPoints?.length ?? 0) > 0;
    const hasTheory = (doc.theoryQuestions?.length ?? 0) > 0;
    const notesEnd = 1 + doc.notes.length;
    const keysPage = hasKeys ? notesEnd + (hasDrawings ? 1 : 0) : -1;
    const afterKeys = keysPage >= 0 ? keysPage + 1 : notesEnd + (hasDrawings ? 1 : 0);
    return {
      count: afterKeys + (hasTheory ? 1 : 0),
      notesEnd,
      drawingsPage: hasDrawings ? notesEnd : -1,
      keysPage,
      theoryPage: hasTheory ? afterKeys : -1,
    };
  }, [doc]);
  const studyAt = Math.min(studyStep, studyPages.count - 1);

  // Arrow keys page through the study sections (desktop scholars).
  useEffect(() => {
    if (phase !== 'study') return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') setStudyStep((s) => Math.min(s + 1, studyPages.count - 1));
      if (e.key === 'ArrowLeft') setStudyStep((s) => Math.max(0, s - 1));
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [phase, studyPages.count]);

  // ── Feed automation (founder round 8): when the count of fully-
  // completed units in this course ticks up and lands on a multiple of
  // three, offer to post the milestone to the feed. The whole detection
  // is fenced: a path-fetch hiccup must NEVER touch the lesson
  // completion that is mid-celebration.
  const offerUnitShare = useCallback(async () => {
    try {
      if (!courseId) return;
      const path = await fetchCoursePath(courseId);
      const done = countCompletedUnits(path);
      const countKey = `renance.unitsDone.${courseId}`;
      const prev = Number(window.localStorage.getItem(countKey) ?? '0') || 0;
      if (done <= prev) return;
      window.localStorage.setItem(countKey, String(done));
      if (done % 3 !== 0) return;
      // One prompt per (course, milestone): a re-run of a topic in the
      // same unit never asks twice for the same count.
      const dedupKey = `renance.unitShare.${courseId}.${done}`;
      if (window.localStorage.getItem(dedupKey)) return;
      window.localStorage.setItem(dedupKey, '1');
      const title = path.title?.trim() || doc?.course?.trim() || 'your course';
      setShareInfo({ units: done, courseTitle: title });
      setCelebQueue((cq) => [...cq, 'share']);
    } catch {
      /* silent by design - the celebration flow is sacred */
    }
  }, [courseId, doc]);

  const finish = useCallback(async (abandoned: boolean) => {
    setPhase('submitting');
    let res: CompleteResult | null = null;
    try {
      if (mode === 'lesson') {
        res = await postProgress({
          topicId: topicId!,
          correct: correctCount,
          total,
          maxCombo,
          mistakes: mistakes.map((m) => ({
            id: m.id, stem: m.stem, type: m.type, options: m.options,
            answer: m.answer, explanation: m.explanation, userAnswer: m.userAnswer, year: m.year,
          })),
          abandoned,
        });
        setResult(res);
        setHearts(res.hearts);
        if (!abandoned) setConfetti((c) => c + 1);
        // Queue the celebrations the server actually paid: the chest
        // drop, a streak that moved up (the Duolingo-style popup), and
        // the milestone the platform just posted to the feed.
        const q: Celebration[] = [];
        if (res?.chest) q.push('chest');
        if (res?.streakUp && (res?.streak ?? 0) > 0) q.push('streak');
        if (res?.milestone) q.push('milestone');
        setCelebQueue(q);
        // Feed automation rides behind the rewards (lesson runs only):
        // fire-and-forget detection, wrapped in its own try/catch above.
        if (!abandoned) void offerUnitShare();
      } else {
        const resolved = questions.filter((qq) => qq.userAnswer === qq.answer).map((qq) => qq.id);
        res = await gradePractice({ correct: correctCount, total, resolvedIds: resolved });
        setResult(res);
        setHearts(res.hearts);
        if (!abandoned) setConfetti((c) => c + 1);
      }
      setPhase('done');
    } catch {
      setPhase('done');
    } finally {
      onCompleted?.(res);
    }
  }, [mode, topicId, correctCount, total, maxCombo, mistakes, questions, onCompleted, offerUnitShare]);

  const settle = useCallback((right: boolean, letter: string) => {
    if (right) {
      setCorrectCount((c) => c + 1);
      setCombo((c) => {
        const next = c + 1;
        setMaxCombo((m) => Math.max(m, next));
        if (next > 0 && next % 3 === 0) setToast(`${next} in a row! +XP combo`);
        return next;
      });
    } else {
      setCombo(0);
      setMistakes((ms) => (ms.some((m) => m.id === q.id) ? ms : [...ms, { ...q, userAnswer: letter }]));
    }
    setTimeout(() => setToast(''), 1600);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q && q.id]);

  // ── Canonical answer judging (founder bug report 2026-10-15: "the
  // right answer will be picked and it will mark the user wrong") ──
  // The graded value is what the server stores: "true"/"false" for
  // true_false (the True/False tiles carry no letters), and for mcq the
  // answer LETTER - with a text fallback for cached questions whose
  // stored answer is the option text itself. A picked option is right
  // when its letter matches, or when its TEXT equals the stored answer.
  const isRightChoice = useCallback((qq: LearnQuizQ, letter: string): boolean => {
    if (qq.type === 'true_false') {
      return (letter === 'A' ? 'true' : 'false') === String(qq.answer ?? '').trim().toLowerCase();
    }
    const ans = String(qq.answer ?? '').trim();
    if (!ans) return false;
    if (letter === ans) return true;
    const text = String(qq.options?.[letter] ?? '').trim();
    return text !== '' && text.toLowerCase() === ans.toLowerCase();
  }, []);

  // The text a question's stored answer points at (for the reveal line
  // and the self-healing type-in): the option text behind the letter,
  // falling back to the raw stored answer.
  const answerTextOf = useCallback((qq: LearnQuizQ): string => {
    const ans = String(qq.answer ?? '').trim();
    if (qq.type === 'true_false') return ans.toLowerCase() === 'true' ? 'True' : 'False';
    const viaLetter = String(qq.options?.[ans.toUpperCase()] ?? '').trim();
    return viaLetter || ans;
  }, []);

  const answer = useCallback((letter: string) => {
    if (revealed || !q) return;
    setPicked(letter);
    setRevealed(true);
    const right = isRightChoice(q, letter);
    // The canonical graded value rides the mistake record so practice
    // resolution (userAnswer === answer) actually matches.
    const graded = q.type === 'true_false' ? (letter === 'A' ? 'true' : 'false') : letter;
    settle(right, graded);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revealed, q && q.id, settle, isRightChoice]);

  // Blank answers (fill_blank / word_bank / the self-healing type-in):
  // the input component judges the typed text itself and reports the
  // boolean. The comparison uses the ANSWER TEXT behind a letter answer
  // (the founder's "typed Anion, got marked wrong against Answer: D")
  // plus the raw stored answer, so both stored shapes grade correctly.
  const judgeBlank = useCallback((isRight: boolean, userText: string) => {
    if (revealed || !q) return;
    setPicked(isRight ? q.answer : '__wrong__');
    setRevealed(true);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    setQuestions((qs) => qs.map((qq) => (qq.id === q.id ? { ...qq, userAnswer: userText } as any : qq)));
    settle(isRight, isRight ? q.answer : '__wrong__');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revealed, q && q.id, settle]);

  const next = useCallback(() => {
    if (isLast) {
      void finish(false);
      return;
    }
    setIdx((i) => i + 1);
    setPicked(null);
    setRevealed(false);
  }, [isLast, finish]);

  const accuracy = total > 0 ? Math.round((correctCount / total) * 100) : 0;

  const dismissCelebration = useCallback(() => {
    setCelebQueue((q) => q.slice(1));
  }, []);

  const activeCeleb = celebQueue[0] ?? null;

  return (
    <div className="fixed inset-0 z-[80] flex flex-col bg-surface" role="dialog" aria-modal="true" aria-label={doc?.title ?? 'Lesson'}>
      <ConfettiBurst fire={confetti} />
      <ToastBanner text={combo > 0 && combo % 3 === 0 ? toast : ''} tone="blue" />

      {/* Top bar: close + progress */}
      <div className="sticky top-0 z-10 border-b-2 border-outline-variant bg-surface/95 backdrop-blur">
        <div className="mx-auto flex h-12 w-full max-w-2xl items-center gap-3 px-3">
          <button type="button" onClick={onClose} aria-label="Close" className="back-key">
            <span className="material-symbols-outlined text-[20px]">close</span>
          </button>
          <div className="flex-1">
            <ProgressBar value={
              phase === 'study' && studyPages.count > 0
                ? ((studyAt + 1) / studyPages.count) * 100
                : total > 0 && phase !== 'study'
                  ? ((idx + (revealed ? 1 : 0)) / total) * 100
                  : phase === 'done' ? 100 : 0} />
          </div>
          <div className="flex items-center gap-1.5">
            <StatHeart hearts={hearts} />
            <GemIcon size={17} />
            <span className="font-mono text-[12px] font-bold text-on-surface">{result ? result.gems : ''}</span>
          </div>
        </div>
      </div>

      <div className="mx-auto w-full max-w-2xl flex-1 overflow-y-auto px-4 pb-[calc(6.5rem+env(safe-area-inset-bottom))] pt-4">
        {/* ── Loading ── */}
        {phase === 'loading' && (
          <div className="flex h-full flex-col items-center justify-center gap-4 py-24">
            <RenanceMark size={76} state="busy" />
            <p className="text-[14px] font-extrabold text-primary-ink">{LOADING_COPY[copyIdx]}</p>
          </div>
        )}

        {/* ── Error (final, after the quiet self-retries) ── */}
        {phase === 'error' && (
          <div className="flex h-full flex-col items-center justify-center gap-3 py-24 text-center">
            <span className="material-symbols-outlined text-[44px] text-error">cloud_off</span>
            <p className="text-[15px] font-extrabold text-on-surface">This lesson could not load</p>
            <p className="max-w-sm text-[13px] text-on-surface-variant">The generator may be busy - close and reopen in a few seconds. Everything else on your account is safe.</p>
            <button type="button" onClick={onClose} className="key-btn bg-primary text-on-primary">Back to my course</button>
          </div>
        )}

        {/* ── Study phase: ONE section per page (Supreme courses parity). ── */}
        {phase === 'study' && doc && (
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <p className="text-[12px] font-black uppercase tracking-wide text-on-surface-variant">
                Part {studyAt + 1} of {studyPages.count}
              </p>
              <p className="max-w-[55%] truncate text-[11px] font-bold text-outline">{doc.course}</p>
            </div>

            {studyAt === 0 && (
              <header className="rounded-2xl border-2 border-outline-variant bg-surface-container p-4 learn-tile">
                <p className="text-[11px] font-black uppercase tracking-wide text-primary-ink">{doc.course}</p>
                <h2 className="mt-0.5 text-[19px] font-black leading-snug text-on-surface"><QText html={doc.title} /></h2>
                {doc.summary && <div className="mt-1.5 text-[13.5px] leading-relaxed text-on-surface-variant"><QText html={doc.summary} /></div>}
                <p className="mt-2.5 rounded-xl bg-surface-container-low px-3 py-2 text-[12px] font-bold leading-snug text-on-surface-variant">
                  {Math.max(0, studyPages.count - 1)} more section{studyPages.count - 1 === 1 ? '' : 's'} to read, then {doc.quiz.length} question{doc.quiz.length === 1 ? '' : 's'}. Tap Next to keep going.
                </p>
              </header>
            )}

            {doc.notes.map((n, i) => studyAt === i + 1 && (
              <article key={i} className="rounded-2xl border-2 border-outline-variant bg-card p-4 learn-tile">
                <h3 className="text-[15px] font-black text-on-surface"><QText html={`${i + 1}. ${n.heading}`} /></h3>
                {n.image && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={n.image} alt={n.imageAlt ?? ''} className="mt-2 max-h-56 w-full rounded-xl object-cover" />
                )}
                <p className="mt-2 whitespace-pre-line text-[14px] leading-relaxed text-on-surface">
                  <QText html={n.body} />
                </p>
              </article>
            ))}

            {studyPages.drawingsPage === studyAt && doc.drawings?.length > 0 && (
              <section className="rounded-2xl border-2 border-outline-variant bg-card p-4 learn-tile">
                <h3 className="text-[15px] font-black text-on-surface">Real drawings for this unit</h3>
                <div className="mt-2 flex flex-col gap-4">
                  {doc.drawings.map((d) => (
                    <figure key={d.id} className="rounded-xl border-2 border-outline-variant bg-surface p-2">
                      {/* Structured SVG structural formulas / wave figures */}
                      <div className="learn-drawing" dangerouslySetInnerHTML={{ __html: d.svg }} />
                      <figcaption className="mt-1 text-center text-[12px] font-bold text-on-surface-variant">{d.title}</figcaption>
                    </figure>
                  ))}
                </div>
              </section>
            )}

            {studyPages.keysPage === studyAt && doc.keyPoints?.length > 0 && (
              <section className="rounded-2xl border-2 border-primary/40 bg-primary/10 p-4">
                <h3 className="text-[14px] font-black text-primary-ink">Key points</h3>
                <ul className="mt-1.5 list-disc space-y-1 pl-5">
                  {doc.keyPoints.map((k, i) => (
                    <li key={i} className="text-[13.5px] font-bold leading-snug text-on-surface"><QText html={k} /></li>
                  ))}
                </ul>
              </section>
            )}

            {studyPages.theoryPage === studyAt && (doc.theoryQuestions?.length ?? 0) > 0 && (
              <section className="rounded-2xl border-2 border-outline-variant bg-card p-4 learn-tile">
                <h3 className="text-[15px] font-black text-on-surface">Theory questions</h3>
                <p className="mt-1 text-[12px] font-bold leading-snug text-on-surface-variant">
                  Attempt each one in writing first, then open its marking guide — that is how the exam marks it.
                </p>
                <div className="mt-3 flex flex-col gap-3">
                  {doc.theoryQuestions!.map((tq, i) => (
                    <article key={tq.id || i} className="rounded-xl border-2 border-outline-variant bg-surface p-3">
                      <h4 className="text-[13.5px] font-black leading-snug text-on-surface">
                        {tq.questionNumber || i + 1}. <QText html={tq.question} />
                      </h4>
                      <details className="group mt-2">
                        <summary className="cursor-pointer select-none rounded-lg bg-surface-container px-3 py-1.5 text-[12px] font-black text-primary-ink">
                          Marking guide &amp; model answer
                        </summary>
                        {tq.keyPoints && (
                          <ul className="mt-2 list-disc space-y-1 pl-5">
                            {tq.keyPoints.split(';').map((p, pi) => p.trim() && (
                              <li key={pi} className="text-[12.5px] leading-snug text-on-surface-variant">{p.trim()}</li>
                            ))}
                          </ul>
                        )}
                        {tq.answer && (
                          <p className="mt-2 whitespace-pre-line text-[12.5px] leading-relaxed text-on-surface"><QText html={tq.answer} /></p>
                        )}
                      </details>
                    </article>
                  ))}
                </div>
              </section>
            )}
          </div>
        )}

        {/* ── Quiz phase ── */}
        {(phase === 'quiz' || phase === 'submitting') && q && (
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <p className="text-[12px] font-black uppercase tracking-wide text-on-surface-variant">
                Question {idx + 1} of {total}
              </p>
              {q.fromBank && (
                <span className="rounded-full border-2 border-macaw-ring bg-macaw-light px-2 py-0.5 text-[10px] font-black uppercase text-macaw-dark">
                  {q.year ? `Past question ${q.year}` : 'Real past question'}
                </span>
              )}
              <button
                type="button"
                onClick={() => setFlagOpen(true)}
                title="Report this question"
                aria-label="Report this question"
                className="ml-auto flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container hover:text-on-surface"
              >
                <span className="material-symbols-outlined text-[16px]">flag</span>
              </button>
            </div>
            <h2 className="text-[17px] font-black leading-snug text-on-surface">
              <QText html={q.stem} />
            </h2>

            {/* Self-healing answer surface (founder bug report 2026-10-14:
                a cached lesson can carry an mcq whose options never made
                it - the stem rendered and the answer area was a blank
                void). When a choice question has no usable options, the
                type-in judge takes over so the question stays answerable
                without waiting on a regeneration. */}
            {(q.type === 'mcq' || q.type === 'true_false') &&
              (q.type === 'true_false' || Object.entries(q.options ?? {}).filter(([, v]) => (v ?? '').trim() !== '').length >= 2) && (
              <div className="flex flex-col gap-2.5">
                {(q.type === 'true_false'
                  ? [{ A: 'True' }, { B: 'False' }]
                  : Object.entries(q.options ?? {}).map(([letter, text]) => ({ [letter]: text }))
                ).map((opt, i) => {
                  const letter = Object.keys(opt)[0];
                  const text = opt[letter];
                  const isPicked = picked === letter;
                  const isAnswer = revealed && isRightChoice(q, letter);
                  const isWrongPick = revealed && isPicked && !isAnswer;
                  return (
                    <button
                      key={letter + i}
                      type="button"
                      disabled={revealed}
                      onClick={() => answer(letter)}
                      className={`flex items-center gap-3 rounded-xl border-2 px-3.5 py-3 text-left text-[14.5px] font-bold transition learn-quiz-option ${
                        isAnswer
                          ? 'border-primary bg-primary/10 text-on-surface'
                          : isWrongPick
                            ? 'border-error bg-error/10 text-on-surface'
                            : revealed
                              ? 'border-outline-variant bg-card text-on-surface-variant'
                              : 'border-outline-variant bg-card text-on-surface hover:border-primary/50'
                      }`}
                    >
                      <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 text-[12px] font-black ${
                        isAnswer ? 'border-primary bg-primary text-on-primary' : isWrongPick ? 'border-error bg-error text-white' : 'border-outline-variant text-primary-ink'
                      }`}>{letter}</span>
                      <span className="min-w-0 flex-1"><QText html={text} /></span>
                    </button>
                  );
                })}
              </div>
            )}

            {((q.type === 'fill_blank' || q.type === 'word_bank') ||
              ((q.type === 'mcq' || q.type === 'true_false') &&
                q.type !== 'true_false' &&
                Object.entries(q.options ?? {}).filter(([, v]) => (v ?? '').trim() !== '').length < 2)) && (
              <BlankInput key={q.id} q={q} revealed={revealed} onJudge={judgeBlank} answerText={answerTextOf(q)} />
            )}

            {revealed && (
              <div className={`rounded-xl border-2 p-3 ${picked !== null && isRightChoice(q, picked) ? 'border-primary bg-primary/10' : 'border-error bg-error/10'}`}>
                {/* Founder 2026-10-21: the correct answer + its explanation
                    always read in GREEN (primary-ink, the dark brand green)
                    - never the red error ink - on both banner washes. */}
                <p className="text-[13px] font-black text-primary-ink">
                  {picked !== null && isRightChoice(q, picked)
                    ? 'Correct!'
                    : `Answer: ${q.type === 'true_false' ? answerTextOf(q) : (String(q.answer ?? '').trim().length === 1 && q.options?.[q.answer.toUpperCase()] ? `${String(q.answer).toUpperCase()} - ${answerTextOf(q)}` : answerTextOf(q))}`}
                </p>
                {q.explanation && <p className="mt-1 text-[13px] leading-relaxed text-primary-ink"><QText html={q.explanation} /></p>}
              </div>
            )}
          </div>
        )}

        {/* ── Done ── */}
        {phase === 'done' && (
          <div className="flex h-full flex-col items-center justify-center gap-4 py-16 text-center">
            <span className="material-symbols-outlined text-[56px] text-primary">trophy</span>
            <h2 className="text-[22px] font-black text-on-surface">{mode === 'lesson' ? 'Unit complete!' : mode === 'review' ? 'Section review done!' : mode === 'revision' ? 'Section revision done!' : 'Practice done!'}</h2>
            <p className="text-[13.5px] font-bold text-on-surface-variant">
              {correctCount}/{total} correct · {accuracy}% accuracy
            </p>
            {result && (
              <div className="mt-1 flex flex-wrap items-center justify-center gap-2">
                <RewardChip icon={<span className="material-symbols-outlined text-[17px] text-accent-amber">bolt</span>} label={`+${result.xpEarned} XP`} />
                <RewardChip icon={<GemIcon size={16} />} label={`+${result.gemsEarned} gems`} />
                <RewardChip icon={<FlameInline />} label={`${result.streak} day streak`} />
                {result.boosted && <RewardChip icon={<span className="material-symbols-outlined text-[17px] text-macaw">bolt</span>} label="Boosted 2×" />}
              </div>
            )}
            {result?.perfect && <p className="text-[13px] font-black uppercase tracking-wide text-primary-ink">Perfect score!</p>}
            <div className="mt-3 flex gap-2.5">
              <button type="button" onClick={onClose} className="key-btn bg-primary text-on-primary">
                {mode === 'lesson' ? 'Continue' : 'Done'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ── Celebrations: chest → streak → milestone (one moment each) ── */}
      {activeCeleb === 'chest' && result?.chest && (
        <ChestOpening drop={result.chest} onDone={dismissCelebration} />
      )}
      {activeCeleb === 'streak' && result && (
        <StreakCelebration
          streak={result.streak}
          forgiven={result.streakForgiven}
          forgivesLeft={result.streakForgivesLeft}
          onDone={dismissCelebration}
        />
      )}
      {activeCeleb === 'milestone' && result?.milestone && (
        <MilestoneCelebration milestone={result.milestone} onDone={dismissCelebration} />
      )}
      {activeCeleb === 'share' && shareInfo && (
        <SharePrompt
          units={shareInfo.units}
          courseTitle={shareInfo.courseTitle}
          onDone={dismissCelebration}
        />
      )}

      {flagOpen && (
        <FlagQuestionModal
          onClose={() => setFlagOpen(false)}
          source={mode === 'revision' ? 'revision' : mode === 'practice' ? 'practice' : 'lesson'}
          questionId={q?.id ?? ''}
        />
      )}

      {/* Sticky footer action - the pb rides the device safe area:
          on notched screens the home indicator must never bite the
          Next/Continue buttons (founder report 2026-10-17). */}
      {(phase === 'study' || phase === 'quiz') && (
        <div className="fixed inset-x-0 bottom-0 z-10 border-t-2 border-outline-variant bg-surface/95 px-4 pt-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] backdrop-blur">
          <div className="mx-auto flex max-w-2xl items-center gap-3">
            {phase === 'study' ? (
              <>
                {studyAt > 0 && (
                  <button type="button" onClick={() => setStudyStep((s) => Math.max(0, s - 1))} className="key-btn flex-1 bg-card text-on-surface">
                    Back
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => (studyAt < studyPages.count - 1 ? setStudyStep((s) => s + 1) : setPhase('quiz'))}
                  disabled={!doc}
                  className={`key-btn ${studyAt > 0 ? 'flex-[2]' : 'flex-1'} bg-primary text-on-primary`}
                >
                  {studyAt < studyPages.count - 1 ? 'Next section' : `Start quiz ${doc ? `(${doc.quiz.length})` : ''}`}
                </button>
              </>
            ) : (
              revealed && (
                <button type="button" onClick={next} className="key-btn w-full bg-primary text-on-primary">
                  {isLast ? 'Finish' : 'Continue'}
                </button>
              )
            )}
          </div>
        </div>
      )}

      {phase === 'submitting' && (
        <div className="fixed inset-x-0 bottom-0 border-t-2 border-outline-variant bg-surface px-4 py-3 text-center text-[13px] font-extrabold text-primary-ink">
          Banking your XP…
        </div>
      )}
    </div>
  );
}

function StatHeart({ hearts }: { hearts: number | null }) {
  // The REAL heart count - the ∞ symbol is retired everywhere
  // (founder rule 2026-10-14: "remove that infinite symbol replace
  // with real data"). While the value is still loading, the heart
  // stands alone instead of printing a placeholder digit.
  return (
    <span className="flex items-center gap-0.5" title="Hearts">
      <HeartIcon size={16} />
      <span className="text-[12px] font-black text-on-surface">{hearts ?? ''}</span>
    </span>
  );
}

function RewardChip({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <span className="flex items-center gap-1 rounded-full border-2 border-outline-light bg-surface-container px-2.5 py-1 text-[12.5px] font-black text-on-surface">
      {icon}{label}
    </span>
  );
}

function FlameInline() {
  return <span className="material-symbols-outlined text-[17px] text-accent-amber">local_fire_department</span>;
}

/** fill_blank / word_bank / the self-healing type-in: type-in with an
 *  optional tile bank. Keyed by question id so a new question always
 *  starts with a clean input (the founder's screenshot: Q7's box still
 *  carried Q6's "Anion"). Judgement compares the typed text against the
 *  ANSWER TEXT (what a letter answer points at), never against a bare
 *  letter the student cannot see. */
function BlankInput({
  q, revealed, onJudge, answerText,
}: {
  q: LearnQuizQ; revealed: boolean; answerText: string;
  onJudge: (isRight: boolean, userText: string) => void;
}) {
  const entries = useMemo(() => Object.entries(q.options ?? {}), [q.options]);
  const [value, setValue] = useState('');

  const norm = (s: unknown) => String(s ?? '').trim().toLowerCase();
  const isAnswerText = (text: string) => norm(text) === norm(answerText) || norm(text) === norm(q.answer);

  const check = (text: string) => {
    if (revealed) return;
    onJudge(isAnswerText(text), text);
  };

  const right = revealed && (isAnswerText(value) || norm(value) === norm(answerText));
  return (
    <div className="flex flex-col gap-3">
      <input
        type="text"
        value={value}
        disabled={revealed}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter' && value.trim()) check(value); }}
        placeholder="Type your answer…"
        className={`w-full rounded-xl border-2 bg-card px-3.5 py-3 text-[14.5px] font-bold text-on-surface outline-none transition ${
          revealed
            ? right ? 'border-primary' : 'border-error'
            : 'border-outline-variant focus:border-primary'
        }`}
        aria-label="Your answer"
      />
      {entries.length > 1 && (
        <div className="flex flex-wrap gap-2">
          {entries.map(([k, w]) => (
            <button
              key={k}
              type="button"
              disabled={revealed}
              onClick={() => { setValue(w); check(w); }}
              className={`rounded-lg border-2 px-3 py-1.5 text-[13px] font-extrabold transition ${
                revealed && (norm(w) === norm(answerText) || norm(w) === norm(q.answer))
                  ? 'border-primary bg-primary text-on-primary'
                  : 'border-outline-variant bg-card text-on-surface'
              }`}
            >{w}</button>
          ))}
        </div>
      )}
      {!revealed && (
        <button type="button" onClick={() => check(value)} disabled={!value.trim()} className="key-btn bg-primary text-on-primary">
          Check
        </button>
      )}
      {revealed && (
        <p className={`text-[13px] font-black ${right ? 'text-primary-ink' : 'text-error'}`}>
          {right ? 'Correct!' : `Answer: ${answerText}`}
        </p>
      )}
    </div>
  );
}
