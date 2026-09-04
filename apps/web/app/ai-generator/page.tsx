'use client';

/**
 * AI question generator, the Stitch ai_question_generator_light screen.
 * Topic chips, the Easy / Medium / Hard segmented control, the count
 * stepper and the black Generate CTA (the design's purple, re-toned per
 * the founder's no-purple rule), plus the Review Generated list.
 * Static friendly: Generate appends mock pending questions locally until
 * the AI provider key lands (Class B).
 */

import { useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

const TOPICS = ['Microeconomics', 'Calculus I', 'World History', 'Organic Chem'] as const;
const DIFFICULTIES = ['Easy', 'Medium', 'Hard'] as const;

interface Generated {
  stem: string;
  difficulty: string;
}

export default function AiGeneratorPage() {
  const [topics, setTopics] = useState<string[]>(['Microeconomics']);
  const [difficulty, setDifficulty] = useState(1);
  const [count, setCount] = useState(5);
  const [generated, setGenerated] = useState<Generated[]>([
    { stem: 'Explain the concept of opportunity cost using a real-world example.', difficulty: 'Medium' },
  ]);

  const toggle = (t: string) =>
    setTopics((cur) => (cur.includes(t) ? cur.filter((x) => x !== t) : [...cur, t]));

  const generate = () => {
    const seed = topics.length ? topics[0] : 'Microeconomics';
    setGenerated((cur) => [
      ...cur,
      ...Array.from({ length: count }, (_, i) => ({
        stem: `Practice question ${cur.length + i + 1}: Explain the concept of ${seed}.`,
        difficulty: DIFFICULTIES[difficulty],
      })),
    ]);
  };

  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-28 sm:px-6">
      <div className="pt-4">
        <PageBar title="Generate practice" />
      </div>
      <p className="mt-2 text-[15px] leading-snug text-on-surface-variant">
        AI-powered question generation tailored to your needs.
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
            onClick={() => setCount((c) => Math.min(50, c + 1))}
            aria-label="Increase count"
            className="flex h-[52px] w-[52px] items-center justify-center rounded-[10px] bg-card text-on-surface"
          >
            <span className="material-symbols-outlined text-[22px]">add</span>
          </button>
        </div>

        <button
          onClick={generate}
          disabled={topics.length === 0}
          className="mt-5 flex h-[52px] w-full items-center justify-center gap-2 rounded-xl bg-primary text-[15px] font-semibold text-on-primary transition-all hover:shadow-md active:scale-[0.98] disabled:opacity-40"
        >
          <span className="material-symbols-outlined text-[18px]">auto_awesome</span>
          Generate
        </button>
      </section>

      {/* Review Generated */}
      <div className="mt-7 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight text-on-surface">Review Generated</h2>
        <span className="rounded-[10px] bg-surface-container-low px-3 py-1.5 text-[13px] text-on-surface-variant">
          {generated.length} Pending
        </span>
      </div>
      <div className="mt-3.5 space-y-3">
        {generated.map((g, i) => (
          <div key={`${i}-${g.stem}`} className="flex items-start gap-3 rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2.5">
                <span className="flex items-center gap-1.5 rounded-lg bg-surface-container-low px-2.5 py-1.5 font-mono text-[10px] tracking-wide text-on-surface">
                  <span className="material-symbols-outlined text-[13px]">smart_toy</span>
                  AI GENERATED
                </span>
                <span className="text-[13px] text-on-surface-variant">{g.difficulty}</span>
              </div>
              <p className="mt-2.5 text-[15px] font-medium leading-[22px] text-on-surface">{g.stem}</p>
            </div>
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-container-low">
              <span className="material-symbols-outlined text-[20px] text-accent-emerald">check</span>
            </span>
          </div>
        ))}
      </div>

      <BottomNav />
    </main>
  );
}
