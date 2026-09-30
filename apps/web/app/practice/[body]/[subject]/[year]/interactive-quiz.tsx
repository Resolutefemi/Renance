'use client';

import { useState } from 'react';
import Link from 'next/link';
import type { SEOSampleQuestion } from '@/lib/seo-types';
import { STORE_CONFIG } from '@/lib/store-links';

function PlayStoreIcon({ className = 'h-4 w-4 shrink-0' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1z" fill="#EA4335" />
      <path d="M47 38.8c-3.5 7.1-5.6 15.3-5.6 24.1v386.2c0 8.8 2.1 17 5.6 24.1l226.7-226.7L47 38.8z" fill="#4285F4" />
      <path d="M325.3 277.7l60.1 60.1L104.6 499l220.7-221.3z" fill="#34A853" />
      <path d="M459.7 238.3l-74.3-42.7-60.1 60.1 60.1 60.1 74.3-42.7c16.9-9.7 26.6-24.4 26.6-34.8 0-10.4-9.7-25.1-26.6-34.8z" fill="#FBBC04" />
    </svg>
  );
}

interface InteractiveQuizProps {
  questions: SEOSampleQuestion[];
  totalQuestions: number;
  bodyTitle: string;
  subjectTitle: string;
  year: number;
  subjectSlug: string;
  body: string;
}

export default function InteractiveQuiz({
  questions,
  totalQuestions,
  bodyTitle,
  subjectTitle,
  year,
  subjectSlug,
  body,
}: InteractiveQuizProps) {
  // Map of question.id -> chosen option letter ('A', 'B', etc.)
  const [selectedAnswers, setSelectedAnswers] = useState<Record<string, string>>({});
  // Expanded explanation toggles
  const [expandedExplanations, setExpandedExplanations] = useState<Record<string, boolean>>({});

  const answeredCount = Object.keys(selectedAnswers).length;
  const correctCount = questions.filter(
    (q) => selectedAnswers[q.id] && selectedAnswers[q.id] === q.answer,
  ).length;

  const handleSelectOption = (questionId: string, optionKey: string) => {
    // Only allow selecting once per question so the test feels authentic
    if (selectedAnswers[questionId]) return;

    setSelectedAnswers((prev) => ({
      ...prev,
      [questionId]: optionKey,
    }));

    // Auto-reveal explanation when answered
    setExpandedExplanations((prev) => ({
      ...prev,
      [questionId]: true,
    }));
  };

  const toggleExplanation = (questionId: string) => {
    setExpandedExplanations((prev) => ({
      ...prev,
      [questionId]: !prev[questionId],
    }));
  };

  const handleReset = () => {
    setSelectedAnswers({});
    setExpandedExplanations({});
  };

  const isCompleted = answeredCount === questions.length && questions.length > 0;
  const percentage = questions.length > 0 ? Math.round((correctCount / questions.length) * 100) : 0;
  const bankCode = `${body}-${subjectSlug}-bank`;
  const webReaderUrl = `/study-past-questions/reader?body=${body}&subject=${subjectSlug}&bank=${bankCode}&year=${year}`;
  const playStoreUrl = STORE_CONFIG.getTrackedPlayStoreUrl('seo_quiz_complete', body, subjectSlug, year);

  return (
    <section aria-label="Interactive practice test" className="mt-6">
      {/* ── Web Version Quick Banner ── */}
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-primary/20 bg-primary/5 px-4 py-2.5 text-xs text-on-surface">
        <div className="flex items-center gap-2">
          <span className="material-symbols-outlined text-[18px] text-primary">laptop_mac</span>
          <span>Want to practice all <strong>{totalQuestions} questions</strong> on your computer?</span>
        </div>
        <Link
          href={webReaderUrl}
          className="font-bold text-primary hover:underline inline-flex items-center gap-1"
        >
          Launch Free Web Reader →
        </Link>
      </div>

      {/* ── Progress and Score Bar ── */}
      <div className="sticky top-4 z-10 mb-6 flex items-center justify-between rounded-2xl border border-outline-variant bg-card/95 p-4 shadow-sm backdrop-blur-md">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-on-surface-variant">
            Live Quiz Practice
          </p>
          <p className="text-sm font-bold text-on-surface">
            {answeredCount} of {questions.length} answered
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <p className="text-xs text-on-surface-variant">Score</p>
            <p className="text-base font-bold text-primary">
              {correctCount} / {questions.length}
            </p>
          </div>
          {answeredCount > 0 && (
            <button
              onClick={handleReset}
              className="rounded-xl border border-outline-variant bg-surface-container px-3 py-1.5 text-xs font-medium text-on-surface transition hover:bg-surface-container-high active:scale-95"
            >
              Reset
            </button>
          )}
        </div>
      </div>

      {/* ── Question Cards ── */}
      <ol className="space-y-6">
        {questions.map((q, i) => {
          const selected = selectedAnswers[q.id];
          const hasAnswered = Boolean(selected);
          const isCorrect = selected === q.answer;
          const showExplanation = expandedExplanations[q.id];

          return (
            <li
              key={q.id}
              className={`rounded-2xl border p-5 transition-all ${
                hasAnswered
                  ? isCorrect
                    ? 'border-emerald-500/40 bg-card shadow-sm'
                    : 'border-rose-500/40 bg-card shadow-sm'
                  : 'border-outline-variant bg-card hover:border-primary/40'
              }`}
            >
              {/* Question Header & Stem */}
              <div className="flex items-start gap-3">
                <span
                  className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold transition-colors ${
                    hasAnswered
                      ? isCorrect
                        ? 'bg-emerald-500 text-white'
                        : 'bg-rose-500 text-white'
                      : 'bg-surface-container text-on-surface-variant'
                  }`}
                >
                  {hasAnswered ? (isCorrect ? '✓' : '✕') : i + 1}
                </span>
                <div className="flex-1">
                  <p className="text-sm font-medium leading-relaxed text-on-surface">
                    {q.stem}
                  </p>
                </div>
              </div>

              {/* Options Interactive List */}
              {q.options && (
                <div className="mt-4 space-y-2.5" role="group" aria-label={`Options for question ${i + 1}`}>
                  {Object.entries(q.options).map(([key, value]) => {
                    const isThisSelected = selected === key;
                    const isThisCorrect = key === q.answer;

                    // Option styling states
                    let optionStyle =
                      'border-outline-variant bg-surface-container/60 hover:bg-surface-container hover:border-primary/40 text-on-surface cursor-pointer';

                    if (hasAnswered) {
                      if (isThisSelected && isThisCorrect) {
                        optionStyle =
                          'border-emerald-500 bg-emerald-500/10 text-emerald-800 dark:text-emerald-300 font-semibold ring-1 ring-emerald-500';
                      } else if (isThisSelected && !isThisCorrect) {
                        optionStyle =
                          'border-rose-500 bg-rose-500/10 text-rose-800 dark:text-rose-300 font-semibold ring-1 ring-rose-500';
                      } else if (isThisCorrect) {
                        optionStyle =
                          'border-emerald-500/80 bg-emerald-500/5 text-emerald-800 dark:text-emerald-300 font-medium border-dashed';
                      } else {
                        optionStyle = 'opacity-40 border-outline-variant bg-surface-container text-on-surface-variant cursor-not-allowed';
                      }
                    }

                    return (
                      <button
                        key={key}
                        type="button"
                        disabled={hasAnswered}
                        onClick={() => handleSelectOption(q.id, key)}
                        className={`flex w-full items-center justify-between rounded-xl border px-3.5 py-2.5 text-left text-sm transition-all active:scale-[0.99] ${optionStyle}`}
                      >
                        <div className="flex items-center gap-3">
                          <span
                            className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-lg text-xs font-bold ${
                              isThisSelected
                                ? isThisCorrect
                                  ? 'bg-emerald-500 text-white'
                                  : 'bg-rose-500 text-white'
                                : 'bg-surface-container-high text-on-surface-variant'
                            }`}
                          >
                            {key}
                          </span>
                          <span className="leading-snug">{String(value)}</span>
                        </div>

                        {/* Status Icon */}
                        {hasAnswered && (
                          <div className="ml-2 shrink-0">
                            {isThisSelected && isThisCorrect && (
                              <span className="flex items-center gap-1 text-xs font-bold text-emerald-600 dark:text-emerald-400">
                                <span className="material-symbols-outlined text-[18px]">check_circle</span>
                                Correct
                              </span>
                            )}
                            {isThisSelected && !isThisCorrect && (
                              <span className="flex items-center gap-1 text-xs font-bold text-rose-600 dark:text-rose-400">
                                <span className="material-symbols-outlined text-[18px]">cancel</span>
                                Incorrect
                              </span>
                            )}
                            {!isThisSelected && isThisCorrect && (
                              <span className="text-[11px] font-medium text-emerald-600 dark:text-emerald-400">
                                Correct Answer
                              </span>
                            )}
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
              )}

              {/* Explanation Accordion */}
              {q.explanation && hasAnswered && (
                <div className="mt-4 pt-3 border-t border-outline-variant/60">
                  <button
                    type="button"
                    onClick={() => toggleExplanation(q.id)}
                    className="flex items-center gap-1.5 text-xs font-semibold text-primary transition hover:underline"
                  >
                    <span className={`material-symbols-outlined text-[16px] transition-transform ${showExplanation ? 'rotate-90' : ''}`}>
                      chevron_right
                    </span>
                    {showExplanation ? 'Hide Explanation' : 'Show Step-by-Step Explanation'}
                  </button>

                  {showExplanation && (
                    <div className="mt-2.5 rounded-xl bg-surface-container/80 p-3.5 text-xs text-on-surface leading-relaxed border border-outline-variant/40">
                      <p className="font-semibold text-primary mb-1">Worked Solution:</p>
                      <p className="whitespace-pre-line">{q.explanation}</p>
                    </div>
                  )}
                </div>
              )}
            </li>
          );
        })}
      </ol>

      {/* ── Completion & Dual Platform Conversion Card (Web + Play Store) ── */}
      {isCompleted && (
        <div className="mt-10 rounded-2xl border border-primary/30 bg-primary/5 p-6 text-center shadow-md animate-in fade-in zoom-in duration-300">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-primary/10 text-primary">
            <span className="material-symbols-outlined text-[32px]">
              {percentage >= 70 ? 'emoji_events' : 'psychology'}
            </span>
          </div>

          <h3 className="mt-3 text-xl font-bold text-on-surface">
            {percentage >= 70 ? 'Outstanding Work!' : 'Practice Makes Perfect!'}
          </h3>

          <p className="mt-1 text-sm text-on-surface-variant">
            You scored <strong className="text-primary">{correctCount} out of {questions.length}</strong> ({percentage}%) on this preview paper.
          </p>

          <p className="mx-auto mt-3 max-w-lg text-xs text-on-surface-variant leading-relaxed">
            There are <strong>{totalQuestions} total questions</strong> in the full {bodyTitle} {subjectTitle} {year} paper.
            Continue practicing on the <strong>Web App</strong> right now, or download the <strong>Android App</strong> for 100% offline study with CBT timers and forensics.
          </p>

          {/* Dual Action Buttons: Web + Play Store */}
          <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
            {/* Primary Option: Web Version */}
            <Link
              href={webReaderUrl}
              className="inline-flex h-11 items-center justify-center rounded-xl bg-primary px-6 text-sm font-semibold text-on-primary shadow-sm transition hover:opacity-95 active:scale-[0.98]"
            >
              <span className="material-symbols-outlined mr-2 text-[18px]">laptop_mac</span>
              Practice Full Paper on Web (Free)
            </Link>

            {/* Secondary Option: Android App */}
            <a
              href={playStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-11 items-center justify-center rounded-xl border border-outline-variant bg-card px-5 text-sm font-medium text-on-surface transition hover:bg-surface-container active:scale-[0.98]"
            >
              <PlayStoreIcon className="mr-2 h-4 w-4 shrink-0" />
              Get Android App (Offline)
            </a>

            {/* Other Years */}
            <Link
              href={`/practice/${body}/${subjectSlug}/`}
              className="inline-flex h-11 items-center justify-center rounded-xl border border-outline-variant bg-surface-container/60 px-4 text-sm font-medium text-on-surface-variant transition hover:bg-surface-container active:scale-[0.98]"
            >
              Browse Other Years
            </Link>
          </div>
        </div>
      )}
    </section>
  );
}
