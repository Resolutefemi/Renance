'use client';

/**
 * The Studio canvas: the right-hand panel where generated documents
 * come alive, Gemini-Canvas style. Quizzes are playable inline (pick,
 * score, explanations), notes/notebooks/lesson notes render with the
 * house template, and every artifact carries its action bar - Share
 * (public name-bearing link), Download PDF, Regenerate, Open in Notes.
 */

import { useMemo, useState } from 'react';
import Link from 'next/link';
import {
  exportArtifactPdf,
  sharedQuizUrl,
  shareArtifact,
  type ArtifactKind,
  type StudioArtifact,
  type StudioLessonData,
  type StudioNotebookData,
  type StudioNoteData,
  type StudioQuizData,
  type StudioQuizQuestion,
} from '@/lib/ai-studio';

export function CanvasHeader({
  title,
  kind,
  onClose,
  actions,
}: {
  title: string;
  kind?: string;
  onClose?: () => void;
  actions?: React.ReactNode;
}) {
  return (
    <div className="sticky top-0 z-10 flex items-center gap-2 border-b border-outline-variant/50 bg-surface-container-lowest/95 px-4 py-3 backdrop-blur">
      {onClose && (
        <button
          type="button"
          onClick={onClose}
          aria-label="Close canvas"
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container lg:hidden"
        >
          <span className="material-symbols-outlined text-[20px]">close</span>
        </button>
      )}
      <div className="min-w-0 flex-1">
        <p className="font-mono text-[9.5px] uppercase tracking-[0.22em] text-on-surface-variant">
          {kind ?? 'Canvas'}
        </p>
        <h2 className="truncate text-[15px] font-semibold text-on-surface">{title}</h2>
      </div>
      <div className="flex shrink-0 items-center gap-1.5">{actions}</div>
    </div>
  );
}

function ActionBtn({
  icon,
  label,
  onClick,
  primary,
  disabled,
}: {
  icon: string;
  label: string;
  onClick?: () => void;
  primary?: boolean;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex h-9 items-center gap-1.5 rounded-lg px-3 text-[12.5px] font-semibold transition active:scale-[0.97] disabled:opacity-40 ${
        primary
          ? 'bg-primary text-on-primary hover:opacity-90'
          : 'border border-outline-variant/70 bg-card text-on-surface hover:border-primary/50'
      }`}
    >
      <span className="material-symbols-outlined text-[17px]">{icon}</span>
      <span className="hidden sm:inline">{label}</span>
    </button>
  );
}

/** The full action bar for one artifact (share / pdf / regenerate /
 *  notes / delete). */
export function ArtifactActions({
  artifact,
  onRegenerate,
  onDeleted,
}: {
  artifact: StudioArtifact;
  onRegenerate?: () => void;
  onDeleted?: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const [shareSlug, setShareSlug] = useState(artifact.shareSlug ?? '');
  const [deleted, setDeleted] = useState(false);

  async function copyShare() {
    try {
      let slug = shareSlug;
      if (!slug) slug = await shareArtifact(artifact.id);
      setShareSlug(slug);
      const url = sharedQuizUrl(slug);
      await navigator.clipboard?.writeText(url);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      /* clipboard unavailable: the share page itself still exists */
    }
  }

  async function remove() {
    try {
      const { deleteArtifact } = await import('@/lib/ai-studio');
      await deleteArtifact(artifact.id);
      setDeleted(true);
      window.setTimeout(() => onDeleted?.(), 250);
    } catch {
      /* keep the canvas open on failure */
    }
  }

  if (deleted) {
    return (
      <span className="font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
        Deleted
      </span>
    );
  }

  return (
    <>
      {artifact.kind === 'quiz' && (
        <ActionBtn icon={copied ? 'check' : 'share'} label={copied ? 'Link copied' : 'Share link'} onClick={copyShare} primary />
      )}
      <ActionBtn icon="download" label="PDF" onClick={() => exportArtifactPdf(artifact)} />
      {onRegenerate && <ActionBtn icon="refresh" label="Redo" onClick={onRegenerate} />}
      {artifact.kind !== 'quiz' && (
        <Link
          href="/notes"
          className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-outline-variant/70 bg-card px-3 text-[12.5px] font-semibold text-on-surface transition hover:border-primary/50"
        >
          <span className="material-symbols-outlined text-[17px]">note_add</span>
          <span className="hidden sm:inline">Notes</span>
        </Link>
      )}
      <ActionBtn icon="delete" label="" onClick={remove} />
    </>
  );
}

// ---------------------------------------------------------------------------
// Quiz player
// ---------------------------------------------------------------------------

export function QuizPlayer({ data }: { data: StudioQuizData }) {
  const questions = data.questions ?? [];
  const [idx, setIdx] = useState(0);
  const [picks, setPicks] = useState<Record<number, string>>({});
  const [submitted, setSubmitted] = useState(false);
  const q: StudioQuizQuestion | undefined = questions[idx];

  const score = useMemo(() => {
    let s = 0;
    questions.forEach((qq, i) => {
      if (qq.answer && picks[i] === qq.answer) s++;
    });
    return s;
  }, [questions, picks]);

  if (!q) return <p className="px-4 py-8 text-center text-sm text-on-surface-variant">This quiz is empty.</p>;

  const letters = Object.keys(q.options ?? {}).sort();
  const picked = picks[idx];
  const last = idx === questions.length - 1;

  return (
    <div className="flex flex-col gap-4 px-4 py-4">
      {/* progress */}
      <div className="flex items-center gap-3">
        <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-container">
          <div
            className="h-full rounded-full bg-primary transition-all"
            style={{ width: `${((idx + 1) / questions.length) * 100}%` }}
          />
        </div>
        <span className="font-mono text-[11px] text-on-surface-variant">
          {idx + 1}/{questions.length}
        </span>
      </div>

      <div className="rounded-2xl border border-outline-variant/60 bg-card p-4">
        <p className="text-[15.5px] font-medium leading-relaxed text-on-surface">{q.stem}</p>
        <div className="mt-4 flex flex-col gap-2">
          {letters.map((l) => {
            const isPick = picked === l;
            const isRight = submitted && q.answer === l;
            const isWrong = submitted && isPick && q.answer !== l;
            return (
              <button
                key={l}
                type="button"
                disabled={submitted}
                onClick={() => setPicks((p) => ({ ...p, [idx]: l }))}
                className={`flex items-center gap-3 rounded-xl border px-3.5 py-3 text-left text-[14px] transition ${
                  isRight
                    ? 'border-emerald-600 bg-emerald-50 text-accent-emerald dark:bg-emerald-tint'
                    : isWrong
                      ? 'border-red-500 bg-red-50 text-on-error-container dark:bg-error-container dark:border-error'
                      : isPick
                        ? 'border-primary bg-surface-container'
                        : 'border-outline-variant/60 bg-card hover:border-primary/40'
                }`}
              >
                <span
                  className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full font-mono text-[12px] font-semibold ${
                    isPick || isRight ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant'
                  }`}
                >
                  {l}
                </span>
                <span className="leading-snug">{q.options?.[l]}</span>
                {isRight && <span className="material-symbols-outlined ml-auto text-[18px]">check_circle</span>}
                {isWrong && <span className="material-symbols-outlined ml-auto text-[18px]">cancel</span>}
              </button>
            );
          })}
        </div>
        {submitted && q.explanation && (
          <div className="mt-3 rounded-xl bg-surface-container px-3.5 py-3 text-[13px] leading-relaxed text-on-surface-variant">
            <span className="font-semibold text-on-surface">Why: </span>
            {q.explanation}
          </div>
        )}
      </div>

      {submitted ? (
        <div className="flex flex-col gap-3">
          <div className="rounded-2xl bg-primary px-5 py-4 text-center text-on-primary">
            <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-on-primary/60">Your score</p>
            <p className="mt-1 text-3xl font-bold tracking-tight">
              {score}
              <span className="text-base text-on-primary/60"> / {questions.length}</span>
            </p>
          </div>
          {/* Review navigation (founder directive, 2026-10-02): Previous
              AND Next flip through every question after submitting - the
              student can walk back through what they got wrong, not only
              forward. The old footer offered a lone "Review next" that
              vanished on the last question. */}
          <div className="flex gap-2">
            <button
              type="button"
              disabled={idx === 0}
              onClick={() => setIdx((i) => i - 1)}
              className="flex-1 rounded-xl border border-outline-variant/70 bg-card py-3 text-[13px] font-semibold text-on-surface transition enabled:hover:border-primary/50 disabled:opacity-40"
            >
              Previous
            </button>
            <button
              type="button"
              disabled={idx >= questions.length - 1}
              onClick={() => setIdx((i) => i + 1)}
              className="flex-1 rounded-xl bg-primary py-3 text-[13px] font-semibold text-on-primary transition active:scale-[0.98] disabled:opacity-40"
            >
              Next
            </button>
          </div>
          <button
            type="button"
            onClick={() => {
              setPicks({});
              setSubmitted(false);
              setIdx(0);
            }}
            className="rounded-xl border border-outline-variant/70 bg-card py-3 text-[13px] font-semibold text-on-surface transition hover:border-primary/50"
          >
            Play again
          </button>
        </div>
      ) : (
        <div className="flex gap-2">
          {idx > 0 && (
            <button
              type="button"
              onClick={() => setIdx((i) => i - 1)}
              className="rounded-xl border border-outline-variant/70 bg-card px-5 py-3 text-[13px] font-semibold text-on-surface"
            >
              Back
            </button>
          )}
          <button
            type="button"
            disabled={!picked}
            onClick={() => (last ? setSubmitted(true) : setIdx((i) => i + 1))}
            className="flex-1 rounded-xl bg-primary py-3 text-[13px] font-semibold text-on-primary transition active:scale-[0.98] disabled:opacity-40"
          >
            {last ? 'Submit and score me' : 'Next question'}
          </button>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Document renderers
// ---------------------------------------------------------------------------

function Section({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <section className="px-4 py-4">
      <h3 className="mb-2 font-mono text-[10px] uppercase tracking-[0.22em] text-on-surface-variant">{heading}</h3>
      {children}
    </section>
  );
}

function Bullets({ items }: { items: string[] }) {
  return (
    <ul className="flex flex-col gap-1.5">
      {items.map((it, i) => (
        <li key={i} className="flex gap-2 text-[13.5px] leading-relaxed text-on-surface">
          <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
          <span>{it}</span>
        </li>
      ))}
    </ul>
  );
}

export function NoteView({ data }: { data: StudioNoteData }) {
  return (
    <div className="flex flex-col">
      {data.summary && (
        <Section heading="Overview">
          <p className="rounded-xl bg-primary px-4 py-3 text-[13.5px] leading-relaxed text-on-primary">{data.summary}</p>
        </Section>
      )}
      {(data.sections ?? []).map((s, i) => (
        <Section key={i} heading={s.heading}>
          <div className="whitespace-pre-wrap text-[13.5px] leading-relaxed text-on-surface">{s.body}</div>
        </Section>
      ))}
      {!!data.keyPoints?.length && (
        <Section heading="Key points">
          <Bullets items={data.keyPoints} />
        </Section>
      )}
      {!!data.examTips?.length && (
        <Section heading="Exam tips">
          <Bullets items={data.examTips} />
        </Section>
      )}
      {!!data.practiceQuestions?.length && (
        <Section heading="Practice questions">
          <div className="flex flex-col gap-3">
            {data.practiceQuestions.map((q, i) => (
              <div key={i} className="rounded-xl border border-outline-variant/60 bg-card p-3.5">
                <p className="text-[13.5px] font-medium leading-relaxed text-on-surface">{q.stem}</p>
                {q.answer && (
                  <p className="mt-2 text-[12.5px] text-on-surface-variant">
                    <span className="font-mono font-semibold text-on-surface">Answer: {q.answer}</span>
                    {q.explanation ? ` - ${q.explanation}` : ''}
                  </p>
                )}
              </div>
            ))}
          </div>
        </Section>
      )}
    </div>
  );
}

export function NotebookView({ data }: { data: StudioNotebookData }) {
  return (
    <div className="flex flex-col">
      <Section heading="Overview">
        <p className="rounded-xl bg-primary px-4 py-3 text-[13.5px] leading-relaxed text-on-primary">{data.overview}</p>
      </Section>
      {(data.topicNotes ?? []).map((tn, i) => (
        <div key={i} className="border-t border-outline-variant/40">
          <Section heading={tn.topic}>
            <p className="text-[13px] font-semibold text-on-surface">{tn.summary}</p>
            <div className="mt-2 whitespace-pre-wrap text-[13.5px] leading-relaxed text-on-surface">{tn.deepDive}</div>
            {!!tn.keyTerms?.length && (
              <div className="mt-3 flex flex-col gap-1.5">
                {tn.keyTerms.map((k, j) => (
                  <p key={j} className="text-[12.5px] leading-relaxed text-on-surface-variant">
                    <span className="font-semibold text-on-surface">{k.term}: </span>
                    {k.meaning}
                  </p>
                ))}
              </div>
            )}
            {!!tn.examples?.length && (
              <div className="mt-3 rounded-xl bg-surface-container px-3.5 py-3">
                <p className="mb-1.5 font-mono text-[9.5px] uppercase tracking-[0.2em] text-on-surface-variant">Examples</p>
                <Bullets items={tn.examples} />
              </div>
            )}
          </Section>
        </div>
      ))}
      {!!data.glossary?.length && (
        <div className="border-t border-outline-variant/40">
          <Section heading="Glossary">
            <Bullets items={data.glossary.map((k) => `${k.term}: ${k.meaning}`)} />
          </Section>
        </div>
      )}
      {!!data.examFocus?.length && (
        <div className="border-t border-outline-variant/40">
          <Section heading="Exam focus">
            <Bullets items={data.examFocus} />
          </Section>
        </div>
      )}
      {!!data.studyPlan?.length && (
        <div className="border-t border-outline-variant/40">
          <Section heading="Study plan">
            <Bullets items={data.studyPlan} />
          </Section>
        </div>
      )}
    </div>
  );
}

export function LessonNoteView({ data }: { data: StudioLessonData }) {
  const info: string[] = [
    `Subject: ${data.subject}`,
    `Class: ${data.classLevel}`,
    `Topic: ${data.topic}`,
    data.term ? `Term: ${data.term}` : '',
    data.duration ? `Duration: ${data.duration} minutes` : '',
    data.ageGroup ? `Age group: ${data.ageGroup}` : '',
  ].filter(Boolean);

  return (
    <div className="flex flex-col">
      <Section heading="Lesson information">
        <Bullets items={info} />
      </Section>
      {!!data.objectives?.length && (
        <Section heading="Objectives">
          <Bullets items={data.objectives} />
        </Section>
      )}
      {!!data.materials?.length && (
        <Section heading="Instructional materials">
          <Bullets items={data.materials} />
        </Section>
      )}
      {data.entryBehaviour && (
        <Section heading="Entry behaviour">
          <p className="text-[13.5px] leading-relaxed text-on-surface">{data.entryBehaviour}</p>
        </Section>
      )}
      {data.previousKnowledge && (
        <Section heading="Previous knowledge">
          <p className="text-[13.5px] leading-relaxed text-on-surface">{data.previousKnowledge}</p>
        </Section>
      )}
      {(data.content ?? []).map((s, i) => (
        <Section key={i} heading={s.heading}>
          <div className="whitespace-pre-wrap text-[13.5px] leading-relaxed text-on-surface">{s.body}</div>
        </Section>
      ))}
      {!!data.evaluation?.length && (
        <Section heading="Evaluation">
          <Bullets items={data.evaluation} />
        </Section>
      )}
      {data.summary && (
        <Section heading="Summary">
          <p className="text-[13.5px] leading-relaxed text-on-surface">{data.summary}</p>
        </Section>
      )}
      {data.assignment && (
        <Section heading="Assignment">
          <p className="text-[13.5px] leading-relaxed text-on-surface">{data.assignment}</p>
        </Section>
      )}
    </div>
  );
}

/** Renders any artifact in the canvas with its header + actions. */
export function ArtifactCanvas({
  artifact,
  onClose,
  onRegenerate,
  onDeleted,
}: {
  artifact: StudioArtifact;
  onClose: () => void;
  onRegenerate?: () => void;
  onDeleted: () => void;
}) {
  const kindLabel: Record<ArtifactKind, string> = {
    quiz: 'Quiz',
    note: 'Study note',
    notebook: 'Notebook',
    lesson_note: 'Lesson note',
  };
  const state = artifact.data as { pending?: boolean; error?: string } | undefined;
  const body = (() => {
    if (state?.pending) {
      return (
        <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
          <span className="material-symbols-outlined animate-pulse text-[30px] text-on-surface-variant">hourglass_top</span>
          <p className="text-[14px] font-semibold text-on-surface">Still writing this document…</p>
          <p className="max-w-xs text-[12.5px] leading-relaxed text-on-surface-variant">
            It may take some time. Renance AI is grounding it on real past questions - it lands here automatically, keep this panel open or find it in your documents.
          </p>
        </div>
      );
    }
    if (state?.error) {
      return (
        <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
          <span className="material-symbols-outlined text-[30px] text-on-surface-variant">error</span>
          <p className="text-[14px] font-semibold text-on-surface">The document did not finish</p>
          <p className="max-w-xs text-[12.5px] leading-relaxed text-on-surface-variant">{state.error}</p>
          {onRegenerate && (
            <button type="button" onClick={onRegenerate} className="rounded-lg bg-primary px-4 py-2.5 text-[12.5px] font-semibold text-on-primary">
              Regenerate
            </button>
          )}
        </div>
      );
    }
    switch (artifact.kind) {
      case 'quiz':
        return <QuizPlayer data={artifact.data as StudioQuizData} />;
      case 'note':
        return <NoteView data={artifact.data as StudioNoteData} />;
      case 'notebook':
        return <NotebookView data={artifact.data as StudioNotebookData} />;
      case 'lesson_note':
        return <LessonNoteView data={artifact.data as StudioLessonData} />;
    }
  })();
  return (
    <div className="flex h-full flex-col">
      <CanvasHeader
        title={artifact.title || 'Untitled'}
        kind={kindLabel[artifact.kind]}
        onClose={onClose}
        actions={
          state?.pending || state?.error ? null : (
            <ArtifactActions artifact={artifact} onRegenerate={onRegenerate} onDeleted={onDeleted} />
          )
        }
      />
      <div className="flex-1 overflow-y-auto">{body}</div>
    </div>
  );
}
