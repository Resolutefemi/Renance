'use client';

/**
 * Renance AI client. Every AI surface rides the study API's /ai/chat
 * route: the provider key lives on the server (Render env), never in
 * the browser bundle, and students never bring their own key. When the
 * server has no provider configured, it answers from the corpus in
 * study-guide mode, so the companion is never dead.
 */

import { api } from '@/lib/api';

export const AI_MODEL = 'renance-ai';

/** True: the server route is always the path; it degrades gracefully. */
export function aiConfigured(): boolean {
  return true;
}

export interface AiMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/** One chat completion through the study API's grounded /ai/chat route. */
export async function aiChat(
  messages: AiMessage[],
  _opts?: { temperature?: number; maxTokens?: number },
): Promise<string> {
  // The server owns the system prompt and the corpus grounding, so only
  // the conversation rides north; unknown fields would be rejected.
  const rest = messages.filter((m) => m.role !== 'system');
  const res = await api<{ reply: string; mode: string }>('/ai/chat', {
    method: 'POST',
    body: {
      messages: rest.length ? rest : [{ role: 'user', content: 'Hello' }],
    },
  });
  if (!res.reply || !res.reply.trim()) {
    throw new Error('AI returned an empty reply.');
  }
  return res.reply.trim();
}

/**
 * Pull the first JSON value out of a model reply. Models fence JSON in
 * ```blocks or wrap it in prose; find the first balanced [ or { and
 * parse from there.
 */
export function extractJson<T>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : text;
  const starts = [candidate.indexOf('['), candidate.indexOf('{')].filter((i) => i >= 0);
  if (starts.length === 0) throw new Error('The AI reply carried no JSON.');
  const start = Math.min(...starts);
  const open = candidate[start];
  const close = open === '[' ? ']' : '}';
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < candidate.length; i++) {
    const ch = candidate[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === '\\') esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') inStr = true;
    else if (ch === open) depth++;
    else if (ch === close) {
      depth--;
      if (depth === 0) return JSON.parse(candidate.slice(start, i + 1)) as T;
    }
  }
  throw new Error('The AI reply carried malformed JSON.');
}

export interface GeneratedQuestion {
  stem: string;
  options?: Record<string, string>;
  answer?: string;
  explanation?: string;
  difficulty?: string;
}

/** Generate exam-style MCQs for one topic through the model. */
export async function aiGenerateQuestions(opts: {
  topic: string;
  count: number;
  difficulty: 'Easy' | 'Medium' | 'Hard';
}): Promise<GeneratedQuestion[]> {
  const system =
    'You are a Nigerian exam paper setter preparing candidates for JAMB, WAEC and NECO. ' +
    'You write exam-accurate multiple-choice questions with four options and exactly one correct answer. ' +
    'Reply with JSON only, no prose.';
  const user = [
    `Write ${opts.count} ${opts.difficulty} multiple-choice questions on "${opts.topic}".`,
    'Each question targets the way Nigerian examiners actually ask this topic.',
    'Return a JSON array; every element looks like:',
    '{"stem":"...","options":{"A":"...","B":"...","C":"...","D":"..."},"answer":"B","explanation":"one or two sentences"}',
  ].join(' ');
  const text = await aiChat(
    [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    { temperature: 0.7, maxTokens: 2048 },
  );
  const parsed = extractJson<GeneratedQuestion[]>(text);
  if (!Array.isArray(parsed)) throw new Error('The AI reply was not a question list.');
  return parsed
    .filter((q) => q && typeof q.stem === 'string' && q.stem.trim())
    .map((q) => ({ ...q, difficulty: opts.difficulty }));
}
