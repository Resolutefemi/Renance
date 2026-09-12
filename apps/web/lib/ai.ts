'use client';

/**
 * Rence AI client (Gemini via its OpenAI-compatible surface, the same
 * provider the study API's tutor uses).
 *
 * The site ships as a static GitHub Pages export with no server of its
 * own beyond the study API, so the provider key is baked into the
 * client bundle at build time (NEXT_PUBLIC_AI_API_KEY in
 * web-deploy.yml). That is an accepted trade-off for this deployment
 * shape: every AI surface degrades gracefully when the key is absent
 * or the provider rejects the request, and the server route stays the
 * primary path wherever one exists.
 */

export const AI_BASE_URL =
  process.env.NEXT_PUBLIC_AI_BASE_URL ??
  'https://generativelanguage.googleapis.com/v1beta/openai';
export const AI_MODEL = process.env.NEXT_PUBLIC_AI_MODEL ?? 'gemini-3.6-flash';

const AI_KEY = (process.env.NEXT_PUBLIC_AI_API_KEY ?? '').trim();

/** True when this deployment ships a provider key. */
export function aiConfigured(): boolean {
  return AI_KEY.length > 0;
}

export interface AiMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ChatChoice {
  message?: { content?: unknown };
}

/** One chat completion through the OpenAI-compatible /chat/completions route. */
export async function aiChat(
  messages: AiMessage[],
  opts?: { temperature?: number; maxTokens?: number },
): Promise<string> {
  if (!AI_KEY) throw new Error('AI is not configured on this deployment.');
  const res = await fetch(`${AI_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${AI_KEY}`,
    },
    body: JSON.stringify({
      model: AI_MODEL,
      messages,
      temperature: opts?.temperature ?? 0.6,
      max_tokens: opts?.maxTokens ?? 1024,
      stream: false,
    }),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`AI request failed (${res.status}). ${detail.slice(0, 140)}`);
  }
  const data = (await res.json()) as { choices?: ChatChoice[] };
  const content = data.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content.trim()) {
    throw new Error('AI returned an empty reply.');
  }
  return content.trim();
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
