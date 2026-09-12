'use client';

/**
 * AI question generator, the Stitch ai_question_generator_light screen,
 * now wired to its real backend: POST /ai/generate runs the founder's
 * Gemini key through the study-api (same provider as the Socratic
 * tutor). Topic chips + free-text topic, Easy / Medium / Hard segmented
 * control, count stepper, and the Review Generated list — every
 * generated question ships with its options, correct answer and worked
 * explanation. Failures are honest: the API's error lands in a banner,
 * no mock questions are invented locally.
 */

import { useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { RenanceMark } from '@/components/renance-logo';
import { api, ApiError } from '@/lib/api';
import { QText } from '@/lib/qtext';

const TOPICS = ['Microeconomics', 'Calculus I', 'World History', 'Organic Chem'] as const;
const DIFFICULTIES = ['Easy', 'Medium', 'Hard'] as const;

interface Generated {
  stem: string;
  options: Record<string, string>;
  answer: string;
  explanation?: string;
  topic?: string;
  difficulty: string;
}

export default function AiGeneratorPage() {
  const [topics, setTopics] = useState<string[]>(['Microeconomics']);
  const [custom, setCustom] = useState('');
  const [difficulty, setDifficulty] = useState(1);
  const [count, setCount] = useState(5);
  const [generated, setGenerated] = useState<Generated[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [revealed, setRevealed] = useState<Set<number>>(new Set());

  const toggle = (t: string) =>
    setTopics((cur) => (cur.includes(t) ? cur.filter((x) => x !== t) : [...cur, t]));

  const effectiveTopics = custom.trim()
    ? [...topics, custom.trim()].slice(0, 5)
    : topics;

  async function generate() {
    if (effectiveTopics.length === 0 || busy) return;
    setBusy(true);
    setError(null);
    setRevealed(new Set());
    try {
      const res = await api<{ questions: Generated[]; mode: string }>('/ai/generate', {
        method: 'POST',
        body: { topics: effectiveTopics, difficulty: DIFFICULTIES[difficulty], count },
      });
      setGenerated(res.questions ?? []);
      if (!res.questions?.length) {
        setError('The AI returned no usable questions — try again or pick another topic.');
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not reach the AI — check your connection.');
    } finally {
      setBusy(false);
    }
  }

  function reveal(i: number) {
    setRevealed((cur) => {
      const next = new Set(cur);
      if (next.has(i)) {
        next.delete(i);
      } else {
        next.add(i);
      }
      return next;
    });
  }

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Generate practice" />
      </div>
      <p className="mt-2 text-[15px] leading-snug text-on-surface-variant">
        AI-powered question generation tailored to your needs — every question lands with its
        answer and explanation.
      </p>

      {/* builder card */}
      <section className="mt-5 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
        <h2 className="flex items-center gap-2.5 text-lg font-semibold tracking-tight text-on-surface">
          <span className="material-symbols-outlined text-[20px]">category</span>
          Select Topic
        </h2>
        <div className="mt-3.5 flex flex-wrap gap-2.5">
          {TOPICS.map((t) => (
            <button
              key={t}
              onClick={() => toggle(t)}
              className={`rounded-full px-[18px] py-3 text-[15px] transition ${
                topics.includes(t)
                  ? 'bg-selection-blue font-semibold text-on-surface'
                  : 'bg-surface-container-low text-on-surface-variant'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
        <input
          value={custom}
          onChange={(e) => setCustom(e.target.value)}
          placeholder="…or type any topic (e.g. Organic Chemistry, GST 111)"
          maxLength={80}
          className="mt-3 w-full rounded-xl bg-surface-container-low px-4 py-3 text-sm text-on-surface transition-colors placeholder:text-outline focus:bg-surface-container-lowest focus:outline-none focus:ring-2 focus:ring-primary"
        />

        <h2 className="mt-6 flex items-center gap-2.5 text-lg font-semibold tracking-tight text-on-surface">
          <span className="material-symbols-outlined text-[20px]">bar_chart</span>
          Difficulty
        </h2>
        <div className="mt-3.5 grid grid-cols-3 gap-1 rounded-xl bg-surface-container-low p-1">
          {DIFFICULTIES.map((d, i) => (
            <button
              key={d}
              onClick={() => setDifficulty(i)}
              className={`rounded-[10px] py-3 text-[15px] transition ${
                difficulty === i ? 'bg-card font-semibold text-on-surface shadow-sm' : 'text-on-surface'
              }`}
            >
              {d}
            </button>
          ))}
        </div>

        <h2 className="mt-6 flex items-center gap-2.5 text-lg font-semibold tracking-tight text-on-surface">
          <span className="material-symbols-outlined text-[20px]">format_list_numbered</span>
          Question Count
        </h2>
        <div className="mt-3.5 flex items-center gap-2 rounded-xl bg-surface-container-low p-2">
          <button
            onClick={() => setCount((c) => Math.max(1, c - 1))}
            aria-label="Decrease count"
            className="flex h-[52px] w-[52px] items-center justify-center rounded-[10px] bg-card text-on-surface"
          >
            <span className="material-symbols-outlined text-[22px]">remove</span>
          </button>
          <span className="flex-1 text-center text-xl font-bold tracking-tight text-on-surface">{count}</span>
          <button
            onClick={() => setCount((c) => Math.min(10, c + 1))}
            aria-label="Increase count"
            className="flex h-[52px] w-[52px] items-center justify-center rounded-[10px] bg-card text-on-surface"
          >
            <span className="material-symbols-outlined text-[22px]">add</span>
          </button>
        </div>

        {error && (
          <p className="mt-4 rounded-lg bg-error-container px-4 py-3 text-sm text-on-error-container">{error}</p>
        )}

        <button
          onClick={generate}
          disabled={effectiveTopics.length === 0 || busy}
          className="mt-5 flex h-[52px] w-full items-center justify-center gap-2 rounded-xl bg-primary text-[15px] font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98] disabled:opacity-40"
        >
          {busy ? (
            <>
              <RenanceMark size={20} state="busy" />
              Generating…
            </>
          ) : (
            <>
              <span className="material-symbols-outlined text-[18px]">auto_awesome</span>
              Generate
            </>
          )}
        </button>
      </section>

      {/* Review Generated */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Review Generated</h2>
        <span className="rounded-[10px] bg-surface-container-low px-3 py-1.5 text-[13px] text-on-surface-variant">
          {generated.length} Generated
        </span>
      </div>

      {generated.length === 0 && (
        <p className="mt-3 rounded-xl bg-card p-4 text-[13px] leading-relaxed text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
          Pick a topic, set the difficulty and tap Generate — your practice set appears here,
          answer and explanation included.
        </p>
      )}

      <div className="mt-3.5 space-y-3">
        {generated.map((g, i) => {
          const open = revealed.has(i);
          return (
            <div key={`${i}-${g.stem.slice(0, 24)}`} className="rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              <div className="flex items-center gap-2.5">
                <span className="flex items-center gap-1.5 rounded-lg bg-surface-container-low px-2.5 py-1.5 font-mono text-[10px] tracking-wide text-on-surface">
                  <span className="material-symbols-outlined text-[13px]">smart_toy</span>
                  AI GENERATED
                </span>
                <span className="text-[13px] text-on-surface-variant">{g.difficulty}</span>
                {g.topic && (
                  <span className="truncate text-[13px] text-on-surface-variant">· {g.topic}</span>
                )}
              </div>
              <div className="mt-2.5 text-[15px] font-medium leading-[22px] text-on-surface">
                <QText html={g.stem} />
              </div>
              <ul className="mt-2 space-y-1">
                {Object.entries(g.options ?? {}).map(([letter, text]) => {
                  const correct = open && letter === g.answer;
                  return (
                    <li
                      key={letter}
                      className={`flex gap-2 rounded-lg px-2.5 py-1.5 text-[14px] ${
                        correct
                          ? 'bg-accent-emerald/15 font-semibold text-on-surface'
                          : 'text-on-surface-variant'
                      }`}
                    >
                      <span className="font-mono text-[12px] leading-6 text-on-surface-variant">{letter}</span>
                      <span className="min-w-0 flex-1">
                        <QText html={text} />
                      </span>
                    </li>
                  );
                })}
              </ul>
              <button
                onClick={() => reveal(i)}
                className="mt-2 flex items-center gap-1.5 rounded-full bg-surface-container-low px-3 py-1.5 text-[12px] font-semibold text-on-surface transition hover:bg-surface-container-high"
              >
                <span className="material-symbols-outlined text-[15px]">
                  {open ? 'visibility_off' : 'visibility'}
                </span>
                {open ? 'Hide answer' : 'Show answer'}
              </button>
              {open && g.explanation && (
                <div className="mt-2 rounded-xl bg-selection-blue px-3.5 py-3 text-[13px] leading-relaxed text-on-surface">
                  <span className="font-semibold">Why: </span>
                  <QText html={g.explanation} />
                </div>
              )}
            </div>
          );
        })}
      </div>

      <SideNav />
      <BottomNav />
    </main>
  );
}
