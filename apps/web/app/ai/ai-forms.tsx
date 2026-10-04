'use client';

/**
 * The studio's generator forms: Quiz, Study note, Notebook and Lesson
 * note. One shared shape (a compact form card per mode), each with the
 * fields its backend prompt needs and a live phase animation while the
 * model works: Thinking, Analysing, Researching past questions,
 * Composing - the way Claude and Gemini surface their reasoning.
 */

import { useEffect, useState } from 'react';
import {
  generateLessonNote,
  generateNote,
  generateNotebook,
  generateQuiz,
  waitForArtifact,
  type GenerateResult,
} from '@/lib/ai-studio';

export interface GenerateOpts {
  title?: string;
  topics: string[];
  topic?: string;
  subject?: string;
  classLevel?: string;
  difficulty?: string;
  count?: number;
  body?: string;
  template?: string;
  term?: string;
  duration?: number;
}

export type GenMode = 'quiz' | 'note' | 'notebook' | 'lesson_note';

/** The thinking-phase ticker the forms and chat share. */
export function PhaseTicker({ phases }: { phases: string[] }) {
  const [i, setI] = useState(0);
  useEffect(() => {
    setI(0);
    const t = window.setInterval(() => setI((v) => Math.min(v + 1, phases.length - 1)), 2600);
    return () => window.clearInterval(t);
  }, [phases.length]);
  return (
    <div className="flex items-center gap-2.5 rounded-xl border border-outline-variant/60 bg-card px-4 py-3">
      <span className="material-symbols-outlined animate-pulse text-[20px] text-on-surface">psychology</span>
      <div>
        <p className="text-[13px] font-semibold text-on-surface">{phases[i] ?? 'Thinking'}…</p>
        <div className="mt-1 flex gap-1">
          {phases.map((_, j) => (
            <span
              key={j}
              className={`h-1 w-4 rounded-full transition-colors ${j <= i ? 'bg-primary' : 'bg-outline-variant/50'}`}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

const input =
  'w-full rounded-lg border border-outline-variant bg-card px-3.5 py-2.5 text-[13.5px] text-on-surface placeholder:text-on-surface-variant focus:outline-none focus:ring-2 focus:ring-primary/40';
const label = 'mb-1.5 block font-mono text-[10px] uppercase tracking-[0.18em] text-on-surface-variant';

function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: readonly T[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex gap-1.5">
      {options.map((o) => (
        <button
          key={o}
          type="button"
          onClick={() => onChange(o)}
          className={`flex-1 rounded-lg px-2 py-2 text-[12.5px] font-semibold transition ${
            value === o ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant hover:bg-surface-container-high'
          }`}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

function Stepper({ value, min, max, onChange }: { value: number; min: number; max: number; onChange: (v: number) => void }) {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex h-10 items-center rounded-lg border border-outline-variant bg-card">
        <button
          type="button"
          onClick={() => onChange(Math.max(min, value - 1))}
          className="flex h-full w-10 shrink-0 items-center justify-center rounded-l-lg text-on-surface transition hover:bg-surface-container active:bg-surface-container-high disabled:opacity-30"
          disabled={value <= min}
          aria-label="Fewer questions"
        >
          <span className="material-symbols-outlined text-[19px]">remove</span>
        </button>
        <span className="min-w-0 flex-1 text-center font-mono text-[15px] font-semibold tabular-nums text-on-surface">
          {value}
        </span>
        <button
          type="button"
          onClick={() => onChange(Math.min(max, value + 1))}
          className="flex h-full w-10 shrink-0 items-center justify-center rounded-r-lg text-on-surface transition hover:bg-surface-container active:bg-surface-container-high disabled:opacity-30"
          disabled={value >= max}
          aria-label="More questions"
        >
          <span className="material-symbols-outlined text-[19px]">add</span>
        </button>
      </div>
      <p className="font-mono text-[9.5px] uppercase tracking-wider text-on-surface-variant">
        up to {max}
      </p>
    </div>
  );
}

function ErrorCard({ msg, onRetry }: { msg: string; onRetry: () => void }) {
  return (
    <div className="rounded-xl border border-red-300 bg-red-50 px-4 py-3">
      <p className="text-[13px] leading-relaxed text-on-error-container">{msg}</p>
      <button type="button" onClick={onRetry} className="mt-2 font-mono text-[11px] font-semibold uppercase tracking-wider text-on-error-container underline">
        Try again
      </button>
    </div>
  );
}

/**
 * One generator form. mode picks the fields and the endpoint. The
 * generated artifact flows up through onResult; the canvas opens.
 */
export function GeneratorForm({
  mode,
  busy,
  error,
  onBusy,
  onError,
  onResult,
  children,
}: {
  mode: GenMode;
  busy: boolean;
  error: string | null;
  onBusy: (b: boolean) => void;
  onError: (e: string | null) => void;
  onResult: (r: GenerateResult) => void;
  /** last-params passthrough so Regenerate can reuse the form values. */
  children?: React.ReactNode;
}) {
  // shared fields
  const [subject, setSubject] = useState('');
  const [classLevel, setClassLevel] = useState('');
  // quiz
  const [topics, setTopics] = useState('');
  const [difficulty, setDifficulty] = useState<'Easy' | 'Medium' | 'Hard'>('Medium');
  const [count, setCount] = useState(5);
  const MAX_QUESTIONS = 40;
  const [body, setBody] = useState('');
  const [title, setTitle] = useState('');
  // note
  const [topic, setTopic] = useState('');
  const [template, setTemplate] = useState<'simple' | 'detailed' | 'revision'>('detailed');
  // notebook
  const [nbTopics, setNbTopics] = useState('');
  // lesson note
  const [term, setTerm] = useState('First Term');
  const [duration, setDuration] = useState(40);

  useEffect(() => {
    onError(null);
  }, [mode, onError]);

  function splitTopics(s: string): string[] {
    return s
      .split(/[,;\n]/)
      .map((t) => t.trim())
      .filter(Boolean)
      .slice(0, 6);
  }

  async function run() {
    onError(null);
    onBusy(true);
    try {
      let res: GenerateResult;
      if (mode === 'quiz') {
        const ts = splitTopics(topics);
        if (ts.length === 0) throw new Error('Add at least one topic.');
        res = await generateQuiz({ title: title || undefined, topics: ts, difficulty, count, body: body || undefined });
      } else if (mode === 'note') {
        if (!topic.trim()) throw new Error('Add a topic.');
        res = await generateNote({ topic: topic.trim(), subject: subject || undefined, classLevel: classLevel || undefined, template });
      } else if (mode === 'notebook') {
        const ts = splitTopics(nbTopics);
        if (!subject.trim() || ts.length === 0) throw new Error('Add the subject and at least one topic.');
        res = await generateNotebook({ title: title || undefined, subject: subject.trim(), classLevel: classLevel || undefined, topics: ts });
      } else {
        if (!subject.trim() || !classLevel.trim() || !topic.trim()) throw new Error('Subject, class and topic are required.');
        res = await generateLessonNote({ subject: subject.trim(), classLevel: classLevel.trim(), topic: topic.trim(), term, duration });
      }
      // The document generates in the background; the ticker keeps
      // animating while this loop watches the artifact row. Large
      // quizzes generate in server-side chunks, so the wait scales
      // with the ordered count.
      const ordered = mode === 'quiz' ? count : 0;
      const waited = await waitForArtifact(res.artifact, res.bridged, ordered);
      onResult({ artifact: waited.artifact, phases: res.phases, bridged: waited.bridged });
    } catch (e) {
      onError(e instanceof Error ? e.message : 'Generation failed, try again.');
    } finally {
      onBusy(false);
    }
  }

  const phases =
    mode === 'lesson_note'
      ? ['Thinking', 'Structuring the lesson plan', 'Composing']
      : ['Thinking', 'Analysing the topic', 'Researching past questions', 'Composing'];

  return (
    <div className="flex flex-col gap-3.5">
      {mode === 'quiz' && (
        <>
          <div>
            <span className={label}>Quiz title (optional)</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. JAMB Biology Cells Drill" className={input} maxLength={90} />
          </div>
          <div>
            <span className={label}>Topics (comma separated)</span>
            <input value={topics} onChange={(e) => setTopics(e.target.value)} placeholder="e.g. photosynthesis, cell division" className={input} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <span className={label}>Difficulty</span>
              <Segmented options={['Easy', 'Medium', 'Hard'] as const} value={difficulty} onChange={setDifficulty} />
            </div>
            <div>
              <span className={label}>Questions</span>
              <Stepper value={count} min={3} max={MAX_QUESTIONS} onChange={setCount} />
            </div>
          </div>
          {/* Quick sizes: the standard papers students ask for - a
              JAMB-sized drill (40) is one tap, not 35 taps. */}
          <div className="flex flex-wrap gap-1.5">
            {[5, 10, 20, 30, 40].map((n) => (
              <button
                key={n}
                type="button"
                onClick={() => setCount(n)}
                className={`rounded-full px-3 py-1.5 font-mono text-[11.5px] font-semibold transition ${
                  count === n
                    ? 'bg-primary text-on-primary'
                    : 'bg-surface-container text-on-surface-variant hover:bg-surface-container-high'
                }`}
              >
                {n}
              </button>
            ))}
          </div>
          <div>
            <span className={label}>Exam style</span>
            <select value={body} onChange={(e) => setBody(e.target.value)} className={input}>
              <option value="">Mixed / any body</option>
              <option value="JAMB">JAMB UTME</option>
              <option value="WAEC">WAEC / WASSCE</option>
              <option value="NECO">NECO</option>
              <option value="POST-UTME">Post-UTME</option>
              <option value="University Modules">University module</option>
            </select>
          </div>
        </>
      )}

      {mode === 'note' && (
        <>
          <div>
            <span className={label}>Topic</span>
            <input value={topic} onChange={(e) => setTopic(e.target.value)} placeholder="e.g. Surds" className={input} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <span className={label}>Subject (optional)</span>
              <input value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Mathematics" className={input} />
            </div>
            <div>
              <span className={label}>Class (optional)</span>
              <input value={classLevel} onChange={(e) => setClassLevel(e.target.value)} placeholder="SSS 2" className={input} />
            </div>
          </div>
          <div>
            <span className={label}>Template</span>
            <Segmented options={['simple', 'detailed', 'revision'] as const} value={template} onChange={setTemplate} />
          </div>
        </>
      )}

      {mode === 'notebook' && (
        <>
          <div>
            <span className={label}>Notebook title (optional)</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. SSS 2 Biology Term 1" className={input} maxLength={90} />
          </div>
          <div>
            <span className={label}>Subject</span>
            <input value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="e.g. Biology" className={input} />
          </div>
          <div>
            <span className={label}>Topics (comma separated)</span>
            <textarea value={nbTopics} onChange={(e) => setNbTopics(e.target.value)} placeholder={'e.g. cell structure,\nphotosynthesis,\ngenetics'} rows={3} className={`${input} resize-none`} />
          </div>
          <div>
            <span className={label}>Class (optional)</span>
            <input value={classLevel} onChange={(e) => setClassLevel(e.target.value)} placeholder="SSS 2" className={input} />
          </div>
        </>
      )}

      {mode === 'lesson_note' && (
        <>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <span className={label}>Subject</span>
              <input value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Biology" className={input} />
            </div>
            <div>
              <span className={label}>Class</span>
              <input value={classLevel} onChange={(e) => setClassLevel(e.target.value)} placeholder="SSS 1" className={input} />
            </div>
          </div>
          <div>
            <span className={label}>Topic</span>
            <input value={topic} onChange={(e) => setTopic(e.target.value)} placeholder="e.g. Cell division (mitosis)" className={input} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <span className={label}>Term</span>
              <select value={term} onChange={(e) => setTerm(e.target.value)} className={input}>
                <option>First Term</option>
                <option>Second Term</option>
                <option>Third Term</option>
              </select>
            </div>
            <div>
              <span className={label}>Duration (min)</span>
              <Stepper value={duration} min={20} max={120} onChange={setDuration} />
            </div>
          </div>
        </>
      )}

      {children}

      {busy ? (
        <div className="flex flex-col items-center gap-3.5">
          <PhaseTicker phases={phases} />
          {/* Founder directive (2026-10-02): say the wait out loud -
              big quizzes generate in server-side chunks. */}
          <p className="text-center text-[12.5px] text-on-surface-variant">
            It may take some time - larger documents generate in chunks.
          </p>
        </div>
      ) : (
        <button
          type="button"
          onClick={run}
          className="flex items-center justify-center gap-2 rounded-xl bg-primary py-3.5 text-[14px] font-semibold text-on-primary transition active:scale-[0.98]"
        >
          <span className="material-symbols-outlined text-[19px]">auto_awesome</span>
          Generate with Renance AI
        </button>
      )}
      {error && !busy && <ErrorCard msg={error} onRetry={run} />}
    </div>
  );
}
