'use client';

/**
 * ExplanationSheet - the school app's explanation modal, Renance cut.
 *
 * Opened from the Past-Questions readers and the marked-paper review,
 * it carries everything Myschool puts in this surface, in the same
 * positions:
 *   · header  - red X circle · "Explanation · Question N" · the Save pill
 *   · body    - passage, stem, image, then the option stack with the
 *               green check on the correct option and the red X on a
 *               wrong pick, then the Explanation card: the gradient
 *               "Explanation" label + the "Correct Option X" pill and
 *               the written walkthrough
 *   · AI pill - "Get Renance's AI Explanation", floating centred above
 *               the footer exactly where Myschool seats its own pill;
 *               opens the AI sheet (red close, sparkle title, the amber
 *               "AI can make mistakes" notice, the walkthrough)
 *   · footer  - Report (red) on the left, Previous / Next on the right;
 *               the pager keeps this one sheet open across questions
 *
 * The sheet is a controlled overlay: the parent owns `index` and simply
 * moves it for Prev/Next, so state never remounts mid-flip.
 */

import { useEffect, useRef, useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { aiChat, aiConfigured } from '@/lib/ai';
import { QText, apiImg } from '@/lib/qtext';
import { isSaved, toggleSave } from '@/lib/saved-questions';

export interface ExplanationData {
  questionId: string;
  code: string;
  title: string;
  stem: string;
  passage?: string;
  image?: string;
  options: Record<string, string>;
  /** Correct letter - '' when the paper was ungraded (reader without keys). */
  correct: string;
  /** What the student picked, '' when untouched. */
  selected?: string;
  explanation?: string;
  topic?: string;
  year?: number;
}

interface Props {
  open: boolean;
  onClose: () => void;
  /** Graded-attempt context: unlocks the server-anchored AI explanation. */
  attemptId?: string;
  /** 1-based display number of the current question. */
  number: number;
  question: ExplanationData;
  onPrevious?: () => void;
  onNext?: () => void;
}

const REPORT_REASONS = ['Wrong answer', 'Wrong or unclear explanation', 'Typo / formatting'] as const;

export default function ExplanationSheet({
  open,
  onClose,
  attemptId,
  number,
  question,
  onPrevious,
  onNext,
}: Props) {
  const [saved, setSaved] = useState(false);
  const [aiOpen, setAiOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [reportDone, setReportDone] = useState(false);

  // Reset the per-question surfaces whenever the pager flips.
  useEffect(() => {
    if (!open) return;
    setSaved(isSaved(question.questionId));
    setAiOpen(false);
    setReportOpen(false);
    setReportDone(false);
  }, [open, question.questionId]);

  // Lock the page behind the sheet.
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!open) return null;
  const graded = question.correct !== '';

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center sm:items-center">
      <button
        aria-label="Close explanation"
        onClick={onClose}
        className="absolute inset-0 bg-accent-ink/45 backdrop-blur-[2px]"
      />
      <div className="relative flex max-h-[94dvh] w-full flex-col overflow-hidden rounded-t-[20px] bg-surface-container-lowest shadow-2xl sm:m-6 sm:max-h-[88dvh] sm:max-w-2xl sm:rounded-[20px]">
        {/* ---- header: X · title · Save ------------------------------ */}
        <div className="flex shrink-0 items-center gap-3 border-b border-outline-variant/50 px-4 pb-3 pt-4">
          <button
            onClick={onClose}
            aria-label="Close"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-error text-error transition hover:bg-error-container/40"
          >
            <span className="material-symbols-outlined text-[19px]">close</span>
          </button>
          <h2 className="min-w-0 flex-1 truncate text-[19px] font-bold tracking-tight text-on-surface">
            Explanation · Question {number}
          </h2>
          {/* The Save pill - Myschool's bookmark position. */}
          <button
            onClick={() => {
              setSaved(
                toggleSave({
                  questionId: question.questionId,
                  code: question.code,
                  title: question.title,
                  stem: question.stem,
                  image: question.image,
                  passage: question.passage,
                  options: question.options,
                  correct: question.correct,
                  explanation: question.explanation,
                  topic: question.topic,
                  year: question.year,
                }),
              );
            }}
            className={`flex shrink-0 items-center gap-1.5 rounded-full border px-3.5 py-2 text-[13.5px] font-bold transition active:scale-[0.97] ${
              saved ? 'border-error bg-error-container/50 text-error' : 'border-error text-error'
            }`}
          >
            <span className={`material-symbols-outlined text-[16px] ${saved ? 'icon-fill' : ''}`}>
              {saved ? 'bookmark' : 'bookmark'}
            </span>
            {saved ? 'Saved' : 'Save'}
          </button>
        </div>

        {/* ---- body --------------------------------------------------- */}
        <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
          {question.passage && (
            <details open className="mb-3 rounded-[10px] border border-outline-variant/40 bg-surface-container-low/60">
              <summary className="cursor-pointer select-none px-3 py-2 font-mono text-[10px] uppercase tracking-wider text-outline">
                comprehension passage
              </summary>
              <div className="max-h-44 overflow-y-auto px-3 pb-3 text-[13.5px] leading-relaxed text-on-surface">
                <QText html={question.passage} />
              </div>
            </details>
          )}
          <div className="text-[16.5px] leading-relaxed text-on-surface">
            <QText html={question.stem} />
          </div>
          {question.image && (
            <div className="mt-3 flex justify-center">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={apiImg(question.image)}
                alt="question diagram"
                loading="lazy"
                className="max-h-56 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain"
              />
            </div>
          )}

          {/* options - green check on the correct one, red X on a wrong pick */}
          <div className="mt-4 space-y-2">
            {Object.entries(question.options).map(([letter, text]) => {
              const isCorrect = graded && letter === question.correct;
              const isWrongPick =
                graded && !!question.selected && letter === question.selected && letter !== question.correct;
              return (
                <div
                  key={letter}
                  className={`flex items-start gap-3 rounded-[10px] border px-3.5 py-3 ${
                    isCorrect
                      ? 'border-accent-emerald bg-accent-emerald/5'
                      : isWrongPick
                        ? 'border-error bg-error/5'
                        : 'border-outline-variant/60 bg-card'
                  }`}
                >
                  <span
                    className={`text-[15px] font-extrabold ${
                      isCorrect ? 'text-accent-emerald' : isWrongPick ? 'text-error' : 'text-error/85'
                    }`}
                  >
                    {letter}
                  </span>
                  <span className="w-px self-stretch bg-outline-variant/70" />
                  <span
                    className={`min-w-0 flex-1 text-[14.5px] leading-snug text-on-surface ${
                      isCorrect || isWrongPick ? 'font-semibold' : ''
                    }`}
                  >
                    <QText html={text} />
                  </span>
                  {isCorrect && (
                    <span className="material-symbols-outlined fill-current text-[19px] text-accent-emerald">
                      check_circle
                    </span>
                  )}
                  {isWrongPick && (
                    <span className="material-symbols-outlined fill-current text-[19px] text-error">cancel</span>
                  )}
                </div>
              );
            })}
          </div>

          {/* Explanation card - gradient label + Correct Option pill */}
          {graded ? (
            <div className="mt-4 rounded-xl bg-surface-container-low/55 p-3.5">
              <div className="flex items-center justify-between gap-2">
                <span className="explanation-gradient-label text-[16px] font-extrabold">Explanation</span>
                {question.correct && (
                  <span className="flex items-center gap-1.5 rounded-full bg-surface-container-lowest px-2.5 py-1.5 shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
                    <span className="material-symbols-outlined text-[13px] text-on-surface-variant">auto_awesome</span>
                    <span className="text-[12px] font-semibold text-on-surface-variant">
                      Correct Option {question.correct}
                    </span>
                  </span>
                )}
              </div>
              <div className="mt-2.5 text-[14px] leading-relaxed text-on-surface-variant">
                {question.explanation?.trim() ? (
                  <QText html={question.explanation} />
                ) : (
                  <p>No written explanation ships with this question yet, try the AI explanation below.</p>
                )}
              </div>
            </div>
          ) : (
            <div className="mt-4 flex items-center gap-2 rounded-xl bg-surface-container-low/55 p-3">
              <span className="material-symbols-outlined text-[17px] text-on-surface-variant">lock</span>
              <p className="text-[12.5px] leading-snug text-on-surface-variant">
                Submit the paper to unlock the correct option and its explanation.
              </p>
            </div>
          )}
        </div>

        {/* ---- AI pill + footer --------------------------------------- */}
        <div className="shrink-0 border-t border-outline-variant/40 bg-surface-container-lowest px-4 pb-4 pt-3">
          {(attemptId || aiConfigured()) && graded && (
            <div className="mb-3 flex justify-center">
              <button
                onClick={() => setAiOpen(true)}
                className="flex items-center gap-2 rounded-full border border-outline-variant bg-surface-container-lowest px-4 py-2.5 text-[13.5px] font-bold text-on-surface shadow-[0_4px_14px_-4px_rgba(20,28,45,0.25)] transition hover:shadow-md active:scale-[0.98]"
              >
                <span className="material-symbols-outlined text-[16px]">auto_awesome</span>
                Get Renance&apos;s AI Explanation
              </button>
            </div>
          )}
          <div className="flex items-center">
            {/* Report - left seat, the school app's footer grammar */}
            {reportDone ? (
              <span className="flex items-center gap-1.5 text-[13px] font-bold text-accent-emerald">
                <span className="material-symbols-outlined text-[16px]">check</span>
                Reported
              </span>
            ) : (
              <button
                onClick={() => setReportOpen((v) => !v)}
                className="flex items-center gap-1.5 rounded-lg px-1.5 py-2 text-[13.5px] font-bold text-error transition hover:bg-error-container/30"
              >
                <span className="material-symbols-outlined text-[17px]">flag</span>
                Report
              </button>
            )}
            <div className="ml-auto flex items-center gap-2.5">
              {onPrevious && (
                <button
                  onClick={onPrevious}
                  className="flex h-[46px] min-w-[108px] items-center justify-center rounded-[10px] bg-accent-ink px-4 text-[14px] font-semibold text-white transition active:scale-[0.98]"
                >
                  Previous
                </button>
              )}
              {onNext && (
                <button
                  onClick={onNext}
                  className="flex h-[46px] min-w-[96px] items-center justify-center rounded-[10px] bg-accent-ink px-4 text-[14px] font-semibold text-white transition active:scale-[0.98]"
                >
                  Next
                </button>
              )}
            </div>
          </div>
          {reportOpen && !reportDone && (
            <div className="mt-2.5 rounded-xl border border-outline-variant/60 bg-card p-2">
              {REPORT_REASONS.map((reason) => (
                <button
                  key={reason}
                  onClick={() => {
                    // Honest local report: recorded on-device with the
                    // question pointer, no pretend network call.
                    try {
                      const key = 'renance.reports.v1';
                      const rows = JSON.parse(window.localStorage.getItem(key) ?? '[]') as unknown[];
                      rows.push({ questionId: question.questionId, code: question.code, reason, at: Date.now() });
                      window.localStorage.setItem(key, JSON.stringify(rows.slice(-200)));
                    } catch {
                      /* private mode: the acknowledgement still shows */
                    }
                    setReportOpen(false);
                    setReportDone(true);
                  }}
                  className="block w-full rounded-lg px-3 py-2 text-left text-[13px] text-on-surface transition hover:bg-surface-container-low"
                >
                  {reason}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {aiOpen && (
        <AiExplanationSheet
          question={question}
          attemptId={attemptId}
          onClose={() => setAiOpen(false)}
        />
      )}
    </div>
  );
}

/* -------------------------------------------------------------- AI sheet */

/**
 * The AI Generated Explanation sheet - the school app's cut: red close,
 * sparkle title, the amber "AI can make mistakes" notice, then the
 * walkthrough. The server-anchored tutor endpoint is tried first when a
 * graded attempt exists, the deployment's client key second; neither
 * present, the pill never renders (see above).
 */
function AiExplanationSheet({
  question,
  attemptId,
  onClose,
}: {
  question: ExplanationData;
  attemptId?: string;
  onClose: () => void;
}) {
  const [text, setText] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const askedOnce = useRef(false);

  useEffect(() => {
    if (askedOnce.current) return;
    askedOnce.current = true;
    void ask();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function ask() {
    const optionLines = Object.entries(question.options)
      .map(([k, v]) => `${k}) ${v}`)
      .join('; ');
    const ask =
      `Explain this past question step by step: "${stripHtml(question.stem)}". Options: ${optionLines}. ` +
      (question.correct
        ? `End with the correct option (${question.correct}) and why the others are wrong.`
        : 'End with the correct option and why the others are wrong.');
    if (attemptId) {
      try {
        const res = await api<{ reply: string }>(`/attempts/${attemptId}/tutor`, {
          method: 'POST',
          noRedirect: true,
          body: {
            questionId: question.questionId,
            messages: [{ role: 'user', content: ask }],
          },
        });
        setText(res.reply);
        return;
      } catch (err) {
        // Cold API / unconfigured server AI: fall through to the client key.
        if (!(aiConfigured() && ((err instanceof ApiError && err.status >= 400) || err instanceof Error))) {
          setError(err instanceof Error ? err.message : 'The AI could not reply. Try again.');
          return;
        }
      }
    }
    if (!aiConfigured()) {
      setError('AI is not configured on this deployment yet.');
      return;
    }
    try {
      const reply = await aiChat(
        [
          {
            role: 'system',
            content:
              'You are Rence, an exam coach for Nigerian students (JAMB, WAEC, NECO, university modules). ' +
              'Explain the solution step by step, simply and honestly. Keep replies under 250 words.',
          },
          { role: 'user', content: ask },
        ],
        { temperature: 0.4, maxTokens: 700 },
      );
      setText(reply);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'The AI could not reply. Try again.');
    }
  }

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center sm:items-center">
      <button aria-label="Close AI explanation" onClick={onClose} className="absolute inset-0 bg-accent-ink/50" />
      <div className="relative flex max-h-[90dvh] w-full flex-col overflow-hidden rounded-t-[20px] bg-surface-container-lowest shadow-2xl sm:m-6 sm:max-h-[86dvh] sm:max-w-xl sm:rounded-[20px]">
        <div className="flex shrink-0 items-center gap-3 border-b border-outline-variant/50 px-4 pb-3 pt-4">
          <button
            onClick={onClose}
            aria-label="Close"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-error text-error transition hover:bg-error-container/40"
          >
            <span className="material-symbols-outlined text-[19px]">close</span>
          </button>
          <h2 className="flex min-w-0 flex-1 items-center gap-2 text-[18px] font-bold tracking-tight text-on-surface">
            <span className="explanation-gradient-label">AI Generated Explanation</span>
            <span className="material-symbols-outlined text-[18px] text-accent-amber">auto_awesome</span>
          </h2>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
          <div className="flex items-start gap-2 rounded-xl border border-accent-amber/40 bg-accent-amber/10 px-3.5 py-3">
            <span className="material-symbols-outlined text-[18px] text-accent-amber">warning</span>
            <p className="text-[12.5px] leading-snug text-on-surface-variant">
              <span className="font-semibold text-on-surface">AI can make mistakes.</span> Check the
              walkthrough against your notes before you take it as gospel.
            </p>
          </div>
          <div className="mt-3 text-[14.5px] leading-relaxed text-on-surface">
            {text ? (
              <QText html={renderParagraphs(text)} />
            ) : error ? (
              <p className="rounded-xl bg-error-container px-4 py-3 text-[13.5px] text-on-error-container">{error}</p>
            ) : (
              <div className="flex items-center gap-3 py-6 text-on-surface-variant">
                <span className="material-symbols-outlined animate-spin text-[22px]">progress_activity</span>
                <span className="text-sm">Thinking through the solution…</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Model replies arrive as plain prose; give every line a paragraph. */
function renderParagraphs(text: string): string {
  return text
    .split(/\n{1,}/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => `<p>${line.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</p>`)
    .join('');
}
