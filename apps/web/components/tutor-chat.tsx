'use client';

/**
 * TutorChat (ROADMAP #9), "Ask the Tutor" panel on the answer-review
 * page. Anchored to one graded attempt + one question; the server
 * answers in AI mode when a provider key is configured and in
 * deterministic technique-hint mode otherwise (badge shows which).
 * Per-user rate limiting lives server-side; 429s surface as a friendly
 * cooldown note.
 */

import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';

interface TutorQuestion {
  questionId: string;
  stem: string;
  topic?: string;
  selected?: string;
  correctly: boolean;
}

interface Turn {
  role: 'user' | 'assistant';
  content: string;
}

const SUGGESTIONS = [
  'Give me a hint',
  'Explain simply',
  'Show the rule',
];

export default function TutorChat({
  attemptId,
  questions,
}: {
  attemptId: string;
  questions: TutorQuestion[];
}) {
  const [aiEnabled, setAiEnabled] = useState<boolean | null>(null);
  const [qid, setQid] = useState<string>('');
  const [turns, setTurns] = useState<Turn[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const pool = useMemo(() => questions, [questions]);
  const active = useMemo(
    () => pool.find((q) => q.questionId === qid) ?? pool.find((q) => !q.correctly) ?? pool[0],
    [pool, qid],
  );

  useEffect(() => {
    api<{ aiEnabled: boolean }>('/tutor/status')
      .then((s) => setAiEnabled(s.aiEnabled))
      .catch(() => setAiEnabled(false));
  }, []);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight, behavior: 'smooth' });
  }, [turns, busy]);

  async function send(text: string) {
    const content = text.trim();
    if (!content || busy || !active) return;
    const next = [...turns, { role: 'user' as const, content }];
    setTurns(next);
    setInput('');
    setBusy(true);
    setError(null);
    try {
      const res = await api<{ reply: string; mode: 'ai' | 'hint' }>(
        `/attempts/${attemptId}/tutor`,
        { method: 'POST', body: { questionId: active.questionId, messages: next } },
      );
      setTurns([...next, { role: 'assistant', content: res.reply }]);
    } catch (err) {
      setTurns(next); // keep the student's ask visible
      setError(err instanceof Error ? err.message : 'The tutor could not reply — try again.');
    } finally {
      setBusy(false);
    }
  }

  if (!active) return null;

  return (
    <section className="mt-6 overflow-hidden rounded-xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] ring-1 ring-accent-ink/25">
      {/* header */}
      <header className="flex items-center justify-between bg-accent-ink/10 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="material-symbols-outlined text-2xl text-accent-ink">school</span>
          <div>
            <h2 className="text-[15px] font-bold text-on-surface">Ask the Tutor</h2>
            <p className="text-xs text-on-surface-variant">
              Socratic coaching on this paper — guided by your answers.
            </p>
          </div>
        </div>
        {aiEnabled !== null && (
          <span
            className={`rounded-full px-3 py-1 text-[11px] font-semibold ${
              aiEnabled
                ? 'bg-accent-ink text-white'
                : 'bg-surface-container-low text-on-surface-variant'
            }`}
          >
            {aiEnabled ? 'AI Coach' : 'Technique Hints'}
          </span>
        )}
      </header>

      {/* question picker */}
      <div className="flex gap-2 overflow-x-auto px-5 pt-4">
        {pool.map((q, i) => {
          const idx = questions.indexOf(q) + 1;
          const selected = active.questionId === q.questionId;
          return (
            <button
              key={q.questionId}
              onClick={() => {
                setQid(q.questionId);
                setTurns([]);
                setError(null);
              }}
              className={`shrink-0 rounded-full px-3.5 py-1.5 font-mono text-xs transition ${
                selected
                  ? 'bg-accent-ink font-semibold text-white'
                  : 'bg-surface-container-low text-on-surface-variant hover:text-on-surface'
              }`}
            >
              Q{idx}
              {q.topic ? ` · ${q.topic}` : ''}
            </button>
          );
        })}
      </div>

      {/* conversation */}
      <div ref={listRef} className="max-h-80 space-y-3 overflow-y-auto px-5 py-4">
        {turns.length === 0 && (
          <div className="space-y-2">
            <p className="text-[13px] text-on-surface-variant">
              <span className="font-medium text-on-surface">Q: {active.stem}</span>
              {active.topic && <> · topic: {active.topic}</>}
            </p>
            <div className="flex flex-wrap gap-2 pt-1">
              {SUGGESTIONS.map((s) => (
                <button
                  key={s}
                  onClick={() => void send(s)}
                  className="rounded-full bg-surface-container-low px-3.5 py-1.5 text-xs text-on-surface transition hover:bg-selection-blue"
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}
        {turns.map((t, i) => (
          <div
            key={i}
            className={`max-w-[85%] rounded-xl px-4 py-2.5 text-[14px] leading-relaxed ${
              t.role === 'user'
                ? 'ml-auto bg-primary text-on-primary'
                : 'bg-accent-ink/10 text-on-surface'
            }`}
          >
            {t.content}
          </div>
        ))}
        {busy && (
          <div className="flex items-center gap-2 text-xs text-on-surface-variant">
            <span className="material-symbols-outlined animate-pulse text-accent-ink">school</span>
            The tutor is thinking…
          </div>
        )}
        {error && <p className="text-xs text-error">{error}</p>}
      </div>

      {/* composer */}
      <form
        className="flex items-center gap-2 border-t border-surface-container-high px-5 py-3"
        onSubmit={(e) => {
          e.preventDefault();
          void send(input);
        }}
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask why this answer is wrong…"
          maxLength={1000}
          className="h-11 flex-1 rounded-lg bg-surface-container-low px-4 text-sm text-on-surface outline-none placeholder:text-on-surface-variant focus:ring-1 focus:ring-accent-ink"
        />
        <button
          type="submit"
          disabled={busy || input.trim() === ''}
          className="flex h-11 w-11 items-center justify-center rounded-lg bg-accent-ink text-white transition hover:opacity-90 disabled:opacity-40"
          aria-label="Send"
        >
          <span className="material-symbols-outlined text-[20px]">send</span>
        </button>
      </form>
    </section>
  );
}
