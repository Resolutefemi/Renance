'use client';

/**
 * Renance AI - the dedicated companion page. A full chat, grounded in
 * Renance's own data: the school corpus (scheme of work + lesson notes)
 * and the exam banks ride along with every answer through POST /ai/chat.
 * Strictly black and white, conversation-first: suggested prompts up
 * front, class/subject grounding chips for the school corpus, and an
 * honest notice when the AI key is not connected yet.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import { api } from '@/lib/api';
import { getToken } from '@/lib/session';

interface Msg {
  role: 'user' | 'assistant';
  content: string;
}

const SUGGESTIONS = [
  'Explain photosynthesis like I am in JSS 2, with a village example',
  'Quiz me: five JAMB Use of English questions, mark me after',
  'What topics come up in SSS 1 Physics first term?',
  'Teach me surds step by step with three worked examples',
];

const CLASSES = [
  'primary-1', 'primary-2', 'primary-3', 'primary-4', 'primary-5', 'primary-6',
  'jss-1', 'jss-2', 'jss-3',
  'sss-1', 'sss-2', 'sss-3',
];

export default function AiClient() {
  const [messages, setMessages] = useState<Msg[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<'ai' | 'guide' | null>(null);
  const [ground, setGround] = useState<{ class: string; subject: string } | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    document.title = 'Renance AI · Your study companion';
  }, []);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [messages, busy]);

  const send = useCallback(
    async (text: string) => {
      const clean = text.trim();
      if (!clean || busy) return;
      if (!getToken()) {
        setMessages((m) => [
          ...m,
          { role: 'user', content: clean },
          { role: 'assistant', content: 'Sign in to chat with Renance AI. Your conversation history stays on this device.' },
        ]);
        setInput('');
        return;
      }
      const next = [...messages, { role: 'user' as const, content: clean }];
      setMessages(next);
      setInput('');
      setBusy(true);
      try {
        const res = await api<{ reply: string; mode: string }>('/ai/chat', {
          method: 'POST',
          body: {
            messages: next.slice(-12).map((m) => ({ role: m.role, content: m.content })),
            ...(ground ? { class: ground.class, subject: ground.subject } : {}),
          },
        });
        setMode(res.mode === 'ai' ? 'ai' : 'guide');
        setMessages((m) => [...m, { role: 'assistant', content: res.reply }]);
      } catch (err) {
        setMessages((m) => [
          ...m,
          {
            role: 'assistant',
            content: err instanceof Error && err.message.includes('rate')
              ? 'Renance AI is cooling down for a few seconds; try again shortly.'
              : 'Renance AI could not reach the server. Check the connection and try again.',
          },
        ]);
      } finally {
        setBusy(false);
      }
    },
    [busy, messages, ground],
  );

  const bubble = (m: Msg, i: number) =>
    m.role === 'user' ? (
      <div key={i} className="flex justify-end">
        <div className="max-w-[85%] rounded-2xl rounded-br-md bg-[#101418] px-4 py-2.5 text-[13.5px] leading-relaxed text-white">
          {m.content}
        </div>
      </div>
    ) : (
      <div key={i} className="flex justify-start">
        <div className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-bl-md border border-outline-variant/60 bg-white px-4 py-2.5 text-[13.5px] leading-relaxed text-[#101418]">
          {m.content}
        </div>
      </div>
    );

  return (
    <div className="flex min-h-dvh flex-col bg-surface-container-lowest">
      <PageBar title="Renance AI" backHref="/dashboard" />

      <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 pb-28 pt-3 sm:px-6">
        {/* mode chip */}
        <div className="mb-2 flex flex-wrap items-center gap-2">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-outline-variant/60 bg-white px-3 py-1 font-mono text-[10.5px] uppercase tracking-wider text-on-surface-variant">
            <span className={`h-1.5 w-1.5 rounded-full ${mode === 'ai' ? 'bg-[#1D9BF0]' : 'bg-[#101418]'}`} />
            {mode === 'guide' ? 'study-guide mode' : mode === 'ai' ? 'full AI on' : 'renance ai'}
          </span>
          {ground && (
            <button
              onClick={() => setGround(null)}
              className="inline-flex items-center gap-1 rounded-full bg-[#101418] px-3 py-1 font-mono text-[10.5px] text-white"
              title="Clear grounding"
            >
              {ground.class} · {ground.subject}
              <span className="material-symbols-outlined text-[12px]">close</span>
            </button>
          )}
        </div>

        {/* conversation */}
        <div className="flex-1 space-y-3">
          {messages.length === 0 && (
            <div className="renance-rise mt-4">
              <div className="rounded-2xl bg-[#101418] px-6 py-7 text-white">
                <h1 className="text-xl font-bold tracking-tight">Meet Renance AI</h1>
                <p className="mt-1.5 text-[13px] leading-relaxed text-white/75">
                  Trained on Renance itself: the Nigerian scheme of work,
                  lesson notes for every topic, and the exam banks. Ask it
                  to teach, drill or mark you.
                </p>
              </div>
              <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
                {SUGGESTIONS.map((s) => (
                  <button
                    key={s}
                    onClick={() => send(s)}
                    className="rounded-xl border border-outline-variant/60 bg-white px-4 py-3 text-left text-[13px] leading-snug text-[#101418] transition hover:border-[#101418]/60 active:scale-[0.99]"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          )}
          {messages.map(bubble)}
          {busy && (
            <div className="flex justify-start">
              <div className="flex items-center gap-1.5 rounded-2xl rounded-bl-md border border-outline-variant/60 bg-white px-4 py-3">
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-[#101418]" />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-[#101418] [animation-delay:150ms]" />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-[#101418] [animation-delay:300ms]" />
              </div>
            </div>
          )}
          <div ref={endRef} />
        </div>
      </main>

      {/* composer */}
      <div className="fixed inset-x-0 bottom-16 border-t border-outline-variant/50 bg-surface-container-lowest/95 backdrop-blur">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void send(input);
          }}
          className="mx-auto flex w-full max-w-2xl items-center gap-2 px-4 py-3 sm:px-6"
        >
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            data-allow-select
            placeholder="Ask Renance AI anything you are studying…"
            maxLength={1000}
            className="h-11 min-w-0 flex-1 rounded-full border border-outline-variant bg-white px-4 text-[13.5px] text-[#101418] placeholder:text-[#9a9a9a] focus:outline-none focus:ring-2 focus:ring-[#101418]/40"
          />
          <button
            type="submit"
            disabled={busy || !input.trim()}
            aria-label="Send"
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[#101418] text-white transition active:scale-95 disabled:opacity-40"
          >
            <span className="material-symbols-outlined text-[20px]">arrow_upward</span>
          </button>
        </form>
      </div>

      <BottomNav />
    </div>
  );
}
