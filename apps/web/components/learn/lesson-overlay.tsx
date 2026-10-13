'use client';

/**
 * LessonOverlay — the study → quiz → rewards flow of the merged learn
 * module (Supreme LessonOverlay adapted to Renance's tactile design,
 * 2026-10-14). Phases: loading (keycap splash) → study (notes + the
 * curated drawing library + key points) → quiz (up to 20 questions —
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
import {
  CompleteResult, LearnQuizQ, LessonDoc, PracticeQuestion,
  fetchLearnProfile, fetchLesson, fetchPractice, fetchReview, gradePractice, postProgress,
} from '@/lib/learn';
import { QText } from '@/lib/qtext';

type Phase = 'loading' | 'study' | 'quiz' | 'submitting' | 'done' | 'error';

const LOADING_COPY = [
  'Sharpening the explanation…', 'Picking real past questions…',
  'Drawing the diagrams…', 'Stacking your XP…', 'Almost there…',
];

type PlayQ = LearnQuizQ & { userAnswer?: string };

export function LessonOverlay({
  topicId, mode = 'lesson', courseId, unit, onClose, onCompleted,
}: {
  topicId?: string;
  /** lesson = full study+quiz flow; practice/review = straight quiz. */
  mode?: 'lesson' | 'practice' | 'review';
  courseId?: string;
  unit?: number;
  onClose: () => void;
  onCompleted?: (res: CompleteResult | null) => void;
}) {
  const [phase, setPhase] = useState<Phase>('loading');
  const [doc, setDoc] = useState<LessonDoc | null>(null);
  const [questions, setQuestions] = useState<PlayQ[]>([]);
  const [idx, setIdx] = useState(0);
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
  // The REAL heart count for the top rail (∞ retired, founder rule);
  // updated live when a completion pays back the economy.
  const [hearts, setHearts] = useState<number | null>(null);
  const startedRef = useRef(Date.now());
  // The quiet self-reload (founder: "remove retry"): when a lesson
  // fails to load the overlay retries ITSELF a few times before it
  // ever shows a final error — no button for the scholar to press.
  const [reloadTick, setReloadTick] = useState(0);
  const errorRetries = useRef(0);

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
          // Study the notes first; straight to the quiz when a cached
          // lesson somehow carries no questions.
          setPhase((d.quiz ?? []).length > 0 ? 'study' : 'quiz');
        } else {
          const set = mode === 'review'
            ? await fetchReview(courseId!, unit ?? 1)
            : await fetchPractice();
          if (!live) return;
          const qs: PlayQ[] = (set.questions ?? []).map((q: PracticeQuestion) => ({ ...q }));
          setQuestions(qs);
          setPhase('quiz');
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
  }, [mode, topicId, correctCount, total, maxCombo, mistakes, questions, onCompleted]);

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

  const answer = useCallback((letter: string) => {
    if (revealed || !q) return;
    setPicked(letter);
    setRevealed(true);
    const right = letter === q.answer;
    settle(right, letter);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [revealed, q && q.id, settle]);

  // Blank answers (fill_blank / word_bank): the input component judges
  // the typed text itself and reports the boolean.
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
            <ProgressBar value={total > 0 && phase !== 'study' ? ((idx + (revealed ? 1 : 0)) / total) * 100 : phase === 'done' ? 100 : 0} />
          </div>
          <div className="flex items-center gap-1.5">
            <StatHeart hearts={hearts} />
            <GemIcon size={17} />
            <span className="font-mono text-[12px] font-bold text-on-surface">{result ? result.gems : ''}</span>
          </div>
        </div>
      </div>

      <div className="mx-auto w-full max-w-2xl flex-1 overflow-y-auto px-4 pb-28 pt-4">
        {/* ── Loading ── */}
        {phase === 'loading' && (
          <div className="flex h-full flex-col items-center justify-center gap-4 py-24">
            <RenanceMark size={76} state="busy" />
            <p className="text-[14px] font-extrabold text-primary-ink">{LOADING_COPY[copyIdx]}</p>
            <p className="text-[12px] text-on-surface-variant">Lessons are generated once, then cached for you and every student.</p>
          </div>
        )}

        {/* ── Error (final, after the quiet self-retries) ── */}
        {phase === 'error' && (
          <div className="flex h-full flex-col items-center justify-center gap-3 py-24 text-center">
            <span className="material-symbols-outlined text-[44px] text-error">cloud_off</span>
            <p className="text-[15px] font-extrabold text-on-surface">This lesson could not load</p>
            <p className="max-w-sm text-[13px] text-on-surface-variant">The generator may be busy — close and reopen in a few seconds. Everything else on your account is safe.</p>
            <button type="button" onClick={onClose} className="key-btn bg-primary text-white">Back to my course</button>
          </div>
        )}

        {/* ── Study phase ── */}
        {phase === 'study' && doc && (
          <div className="flex flex-col gap-4">
            <header className="rounded-2xl border-2 border-outline-variant bg-surface-container p-4 learn-tile">
              <p className="text-[11px] font-black uppercase tracking-wide text-primary-ink">{doc.course}</p>
              <h2 className="mt-0.5 text-[19px] font-black leading-snug text-on-surface">{doc.title}</h2>
              {doc.summary && <p className="mt-1.5 text-[13.5px] leading-relaxed text-on-surface-variant">{doc.summary}</p>}
            </header>

            {doc.notes.map((n, i) => (
              <article key={i} className="rounded-2xl border-2 border-outline-variant bg-card p-4 learn-tile">
                <h3 className="text-[15px] font-black text-on-surface">{i + 1}. {n.heading}</h3>
                {n.image && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={n.image} alt={n.imageAlt ?? ''} className="mt-2 max-h-56 w-full rounded-xl object-cover" />
                )}
                <p className="mt-2 whitespace-pre-line text-[14px] leading-relaxed text-on-surface">
                  <QText html={n.body} />
                </p>
              </article>
            ))}

            {doc.drawings?.length > 0 && (
              <section className="rounded-2xl border-2 border-outline-variant bg-card p-4 learn-tile">
                <h3 className="text-[15px] font-black text-on-surface">Real drawings for this topic</h3>
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

            {doc.keyPoints?.length > 0 && (
              <section className="rounded-2xl border-2 border-primary/40 bg-primary/10 p-4">
                <h3 className="text-[14px] font-black text-primary-ink">Key points</h3>
                <ul className="mt-1.5 list-disc space-y-1 pl-5">
                  {doc.keyPoints.map((k, i) => (
                    <li key={i} className="text-[13.5px] font-bold leading-snug text-on-surface">{k}</li>
                  ))}
                </ul>
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
            </div>
            <h2 className="text-[17px] font-black leading-snug text-on-surface">
              <QText html={q.stem} />
            </h2>

            {(q.type === 'mcq' || q.type === 'true_false') && (
              <div className="flex flex-col gap-2.5">
                {(q.type === 'true_false'
                  ? [{ A: 'True' }, { B: 'False' }]
                  : Object.entries(q.options ?? {}).map(([letter, text]) => ({ [letter]: text }))
                ).map((opt, i) => {
                  const letter = Object.keys(opt)[0];
                  const text = opt[letter];
                  const isPicked = picked === letter;
                  const isAnswer = revealed && letter === q.answer;
                  const isWrongPick = revealed && isPicked && letter !== q.answer;
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
                        isAnswer ? 'border-primary bg-primary text-white' : isWrongPick ? 'border-error bg-error text-white' : 'border-outline-variant text-primary-ink'
                      }`}>{letter}</span>
                      <span className="min-w-0 flex-1"><QText html={text} /></span>
                    </button>
                  );
                })}
              </div>
            )}

            {(q.type === 'fill_blank' || q.type === 'word_bank') && <BlankInput q={q} revealed={revealed} onJudge={judgeBlank} />}

            {revealed && (
              <div className={`rounded-xl border-2 p-3 ${picked === q.answer ? 'border-primary bg-primary/10' : 'border-error bg-error/10'}`}>
                <p className={`text-[13px] font-black ${picked === q.answer ? 'text-primary-ink' : 'text-error'}`}>
                  {picked === q.answer ? 'Correct!' : `Answer: ${q.type === 'true_false' ? (q.answer === 'true' ? 'True' : 'False') : q.answer.toUpperCase()}`}
                </p>
                {q.explanation && <p className="mt-1 text-[13px] leading-relaxed text-on-surface"><QText html={q.explanation} /></p>}
              </div>
            )}
          </div>
        )}

        {/* ── Done ── */}
        {phase === 'done' && (
          <div className="flex h-full flex-col items-center justify-center gap-4 py-16 text-center">
            <span className="material-symbols-outlined text-[56px] text-primary">emoji_events</span>
            <h2 className="text-[22px] font-black text-on-surface">{mode === 'lesson' ? 'Topic complete!' : mode === 'review' ? 'Unit review done!' : 'Practice done!'}</h2>
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
              <button type="button" onClick={onClose} className="key-btn bg-primary text-white">
                {mode === 'lesson' ? 'Continue' : 'Done'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Sticky footer action */}
      {(phase === 'study' || phase === 'quiz') && (
        <div className="fixed inset-x-0 bottom-0 border-t-2 border-outline-variant bg-surface/95 px-4 py-3 backdrop-blur">
          <div className="mx-auto flex max-w-2xl items-center gap-3">
            {phase === 'study' ? (
              <>
                <button type="button" onClick={onClose} className="key-btn flex-1 bg-card text-on-surface">Quit for now</button>
                <button type="button" onClick={() => setPhase('quiz')} disabled={!doc} className="key-btn flex-[2] bg-primary text-white">
                  Start quiz {doc ? `(${doc.quiz.length})` : ''}
                </button>
              </>
            ) : (
              revealed && (
                <button type="button" onClick={next} className="key-btn w-full bg-primary text-white">
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
  // The REAL heart count — the ∞ symbol is retired everywhere
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

/** fill_blank / word_bank: type-in with an optional tile bank. */
function BlankInput({
  q, revealed, onJudge,
}: {
  q: LearnQuizQ; revealed: boolean;
  onJudge: (isRight: boolean, userText: string) => void;
}) {
  const entries = useMemo(() => Object.entries(q.options ?? {}), [q.options]);
  const [value, setValue] = useState('');

  const check = (text: string) => {
    if (revealed) return;
    const right = String(text).trim().toLowerCase() === String(q.answer).trim().toLowerCase();
    onJudge(right, text);
  };

  const right = revealed && value.trim().toLowerCase() === String(q.answer).trim().toLowerCase();
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
                revealed && String(w).toLowerCase() === String(q.answer).trim().toLowerCase()
                  ? 'border-primary bg-primary text-white'
                  : 'border-outline-variant bg-card text-on-surface'
              }`}
            >{w}</button>
          ))}
        </div>
      )}
      {!revealed && (
        <button type="button" onClick={() => check(value)} disabled={!value.trim()} className="key-btn bg-primary text-white">
          Check
        </button>
      )}
      {revealed && (
        <p className={`text-[13px] font-black ${right ? 'text-primary-ink' : 'text-error'}`}>
          {right ? 'Correct!' : `Answer: ${q.answer}`}
        </p>
      )}
    </div>
  );
}
