'use client';

/**
 * Renance AI Studio client: the typed bridge to the study API's studio
 * surface - persistent chats (folders + history + memories), the
 * past-question bridge stats, and the four generators (quiz, note,
 * lesson note, notebook) whose artifacts export to PDF and share via
 * public name-bearing links.
 */

import { api, withBase } from './api';

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------

export interface StudioChat {
  id: string;
  folder: string;
  title: string;
  updatedAt: string;
}

export interface StudioMessage {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  thinking?: string;
  bridged?: number;
  createdAt: string;
}

export interface StudioFolder {
  name: string;
  count: number;
}

export interface StudioMemory {
  id: number;
  content: string;
  createdAt: string;
}

export interface StudioQuizQuestion {
  stem: string;
  options?: Record<string, string>;
  answer?: string;
  explanation?: string;
}

export interface StudioQuizData {
  title: string;
  subject?: string;
  difficulty?: string;
  body?: string;
  questions: StudioQuizQuestion[];
}

export interface StudioNoteSection {
  heading: string;
  body: string;
}

export interface StudioNoteData {
  title: string;
  subject?: string;
  classLevel?: string;
  template?: string;
  summary: string;
  sections: StudioNoteSection[];
  keyPoints?: string[];
  examTips?: string[];
  practiceQuestions?: StudioQuizQuestion[];
}

export interface StudioLessonData {
  subject: string;
  classLevel: string;
  topic: string;
  term?: string;
  duration?: number;
  ageGroup?: string;
  objectives: string[];
  materials: string[];
  entryBehaviour: string;
  previousKnowledge: string;
  content: StudioNoteSection[];
  evaluation: string[];
  summary: string;
  assignment: string;
}

export interface StudioKeyTerm {
  term: string;
  meaning: string;
}

export interface StudioTopicNote {
  topic: string;
  summary: string;
  deepDive: string;
  keyTerms?: StudioKeyTerm[];
  examples?: string[];
}

export interface StudioNotebookData {
  title: string;
  subject?: string;
  classLevel?: string;
  overview: string;
  topicNotes: StudioTopicNote[];
  glossary?: StudioKeyTerm[];
  examFocus?: string[];
  studyPlan?: string[];
}

export type ArtifactKind = 'quiz' | 'note' | 'notebook' | 'lesson_note';

export interface StudioArtifact {
  id: string;
  kind: ArtifactKind;
  title: string;
  subject?: string;
  classLevel?: string;
  data: unknown;
  shareSlug?: string;
  createdAt: string;
}

export interface GenerateResult {
  artifact: StudioArtifact;
  phases?: string[];
  bridged?: number;
}

// ---------------------------------------------------------------------------
// Chats + folders + memories
// ---------------------------------------------------------------------------

export async function listChats(folder?: string): Promise<StudioChat[]> {
  const q = folder ? `?folder=${encodeURIComponent(folder)}` : '';
  const res = await api<{ chats: StudioChat[] }>(`/ai/chats${q}`);
  return res.chats ?? [];
}

export async function createChat(opts: { title?: string; folder?: string } = {}): Promise<StudioChat> {
  const res = await api<{ chat: StudioChat }>('/ai/chats', {
    method: 'POST',
    body: opts,
  });
  return res.chat;
}

export async function getChat(id: string): Promise<{ chat: StudioChat; messages: StudioMessage[] }> {
  return api<{ chat: StudioChat; messages: StudioMessage[] }>(`/ai/chats/${id}`);
}

export async function updateChat(
  id: string,
  patch: { title?: string; folder?: string },
): Promise<void> {
  await api(`/ai/chats/${id}`, { method: 'PATCH', body: patch });
}

export async function deleteChat(id: string): Promise<void> {
  await api(`/ai/chats/${id}`, { method: 'DELETE' });
}

export interface SendMessageResult {
  userMessage: StudioMessage;
  assistantMessage: StudioMessage;
  mode: string;
  phases: string[];
  bridged: number;
  memorySaved?: boolean;
}

export function sendMessage(
  chatId: string,
  content: string,
  ground?: { class: string; subject: string },
): Promise<SendMessageResult> {
  return api<SendMessageResult>(`/ai/chats/${chatId}/messages`, {
    method: 'POST',
    body: { content, ...(ground ?? {}) },
  });
}

export async function listFolders(): Promise<StudioFolder[]> {
  const res = await api<{ folders: StudioFolder[] }>('/ai/folders');
  return res.folders ?? [];
}

export async function listMemories(): Promise<StudioMemory[]> {
  const res = await api<{ memories: StudioMemory[] }>('/ai/memories');
  return res.memories ?? [];
}

export function addMemory(content: string): Promise<StudioMemory> {
  return api<{ memory: StudioMemory }>('/ai/memories', {
    method: 'POST',
    body: { content },
  }).then((r) => r.memory);
}

export async function deleteMemory(id: number): Promise<void> {
  await api(`/ai/memories/${id}`, { method: 'DELETE' });
}

// ---------------------------------------------------------------------------
// The bridge
// ---------------------------------------------------------------------------

export interface BridgeStats {
  exams: number;
  questions: number;
}

export function bridgeStats(): Promise<BridgeStats> {
  return api<BridgeStats>('/ai/bridge/stats');
}

export interface BridgeQuestion extends StudioQuizQuestion {
  exam: string;
  code: string;
  body: string;
  year?: number;
}

export async function bridgeSearch(
  q: string,
  opts: { body?: string; limit?: number } = {},
): Promise<BridgeQuestion[]> {
  const p = new URLSearchParams({ q });
  if (opts.body) p.set('body', opts.body);
  if (opts.limit) p.set('limit', String(opts.limit));
  const res = await api<{ questions: BridgeQuestion[] }>(`/ai/bridge/search?${p}`);
  return res.questions ?? [];
}

// ---------------------------------------------------------------------------
// Generators + artifacts
// ---------------------------------------------------------------------------

export function generateQuiz(opts: {
  title?: string;
  topics: string[];
  difficulty: string;
  count: number;
  body?: string;
}): Promise<GenerateResult> {
  return api<GenerateResult>('/ai/quiz', { method: 'POST', body: opts });
}

export function generateNote(opts: {
  title?: string;
  topic: string;
  subject?: string;
  classLevel?: string;
  template?: string;
}): Promise<GenerateResult> {
  return api<GenerateResult>('/ai/notes', { method: 'POST', body: opts });
}

export function saveNoteFromText(opts: {
  title: string;
  content: string;
  subject?: string;
}): Promise<GenerateResult> {
  return api<GenerateResult>('/ai/notes/from-text', { method: 'POST', body: opts });
}

export function generateLessonNote(opts: {
  subject: string;
  classLevel: string;
  topic: string;
  term?: string;
  duration?: number;
}): Promise<GenerateResult> {
  return api<GenerateResult>('/ai/lesson-note', { method: 'POST', body: opts });
}

export function generateNotebook(opts: {
  title?: string;
  subject: string;
  classLevel?: string;
  topics: string[];
}): Promise<GenerateResult> {
  return api<GenerateResult>('/ai/notebook', { method: 'POST', body: opts });
}

export async function listArtifacts(kind?: ArtifactKind | ''): Promise<StudioArtifact[]> {
  const q = kind ? `?type=${kind}` : '';
  const res = await api<{ artifacts: StudioArtifact[] }>(`/ai/artifacts${q}`);
  return res.artifacts ?? [];
}

export function fetchArtifact(id: string): Promise<StudioArtifact> {
  return api<{ artifact: StudioArtifact }>(`/ai/artifacts/${id}`).then((r) => r.artifact);
}

export interface WaitedArtifact {
  artifact: StudioArtifact;
  bridged: number;
}

/** Generation is async server-side (the provider can outlive Render's
 *  ~30s proxy wall): POST returns a pending artifact immediately and
 *  this loop watches the row until the document lands. Large quizzes
 *  generate in server-side chunks (10 questions per provider call),
 *  so the quiz deadline scales with the ordered count. */
export async function waitForArtifact(
  start: StudioArtifact,
  bridged = 0,
  hintCount = 0,
): Promise<WaitedArtifact> {
  let budget = 90_000;
  if (start.kind === 'quiz') {
    // ~7s per question beyond the base: a 40-question quiz gets ~5.5
    // minutes, a 10-question one stays near two.
    const n = hintCount > 0 ? hintCount : 10;
    budget = Math.min(45_000 + n * 7_000, 340_000);
  }
  const deadline = Date.now() + budget;
  let art = start;
  while (Date.now() < deadline) {
    const data = art.data as { pending?: boolean; error?: string } | undefined;
    if (!data?.pending) {
      if (data?.error) throw new Error(data.error);
      return { artifact: art, bridged };
    }
    await new Promise((res) => setTimeout(res, 2000));
    try {
      art = await fetchArtifact(art.id);
    } catch {
      /* transient poll failure: keep waiting */
    }
  }
  throw new Error('Still writing - open your documents in a moment, it lands there automatically.');
}

export async function deleteArtifact(id: string): Promise<void> {
  await api(`/ai/artifacts/${id}`, { method: 'DELETE' });
}

export async function shareArtifact(id: string): Promise<string> {
  const res = await api<{ shareSlug: string }>(`/ai/artifacts/${id}/share`, { method: 'POST' });
  return res.shareSlug;
}

/** The public link a student copies to challenge friends. The quiz's
 *  own name is the link's tag: /quiz/?q=<name-slug>. A query-param page
 *  because the whole web app is a static export. */
export function sharedQuizUrl(shareSlug: string): string {
  if (typeof window === 'undefined') return withBase(`/quiz/?q=${shareSlug}`);
  return `${window.location.origin}${withBase(`/quiz/?q=${shareSlug}`)}`;
}

// ---------------------------------------------------------------------------
// PDF export (jsPDF, client-side, no server round trip)
// ---------------------------------------------------------------------------

const INK: [number, number, number] = [16, 20, 24];

export function exportArtifactPdf(art: StudioArtifact): void {
  import('jspdf').then(({ jsPDF }) => {
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    const pageW = doc.internal.pageSize.getWidth();
    const pageH = doc.internal.pageSize.getHeight();
    const M = 48; // margin
    const FOOT = 56; // footer reserve
    let y = 0;

    // Founder bugfix (2026-09-30): every block now advances y by its FULL
    // wrapped height. The old writer drew multi-line blocks but only
    // advanced one line, so the next heading printed on top of the
    // paragraph above it - "the PDFs are overlapping".
    const lineH = (size: number) => size * 1.45;

    const newPage = () => {
      doc.addPage();
      y = M;
    };
    const need = (h: number) => {
      if (y + h > pageH - FOOT) newPage();
    };

    /** Draws a wrapped block of text and advances y past all of it. */
    const block = (t: string, size: number, style: 'normal' | 'bold', color: number[], gap = 4) => {
      doc.setFont('helvetica', style);
      doc.setFontSize(size);
      doc.setTextColor(color[0], color[1], color[2]);
      const lines: string[] = doc.splitTextToSize(t, pageW - 2 * M);
      const lh = lineH(size);
      need(lines.length * lh + gap);
      let cursor = y + lh; // first baseline
      for (const ln of lines) {
        if (cursor > pageH - FOOT + lh) {
          newPage();
          cursor = y + lh;
        }
        doc.text(ln, M, cursor);
        cursor += lh;
      }
      y = Math.max(y, cursor - lh) + gap;
    };

    const title = (t: string) => block(t, 20, 'bold', INK, 10);
    const meta = (t: string) => block(t, 10, 'normal', [90, 99, 112], 2);
    const heading = (t: string) => block(t, 13, 'bold', INK, 8);
    const para = (t: string, size = 11) => block(t, size, 'normal', [38, 45, 56]);
    const bullet = (t: string) => para(`-  ${t}`);
    const rule = () => {
      need(18);
      doc.setDrawColor(220, 224, 230);
      y += 8;
      doc.line(M, y, pageW - M, y);
      y += 6;
    };

    // Every page carries the footer: page number + the Renance stamp.
    const stampFooter = () => {
      const n = doc.getNumberOfPages();
      for (let i = 1; i <= n; i++) {
        doc.setPage(i);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8.5);
        doc.setTextColor(140, 146, 156);
        doc.text('Generated with Renance AI - renance.app', M, pageH - 24);
        doc.text(`${i} / ${n}`, pageW - M, pageH - 24, { align: 'right' });
      }
    };

    y = M;
    title(art.title || 'Renance AI document');
    const when = new Date(art.createdAt).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
    const bits = [art.subject, art.classLevel, when].filter(Boolean).join('  |  ');
    meta(`Renance AI  |  ${bits}`);
    y += 4;

    if (art.kind === 'quiz') {
      const data = art.data as StudioQuizData;
      heading('Questions');
      (data.questions ?? []).forEach((q, i) => {
        rule();
        para(`${i + 1}.  ${q.stem}`, 11.5);
        const letters = Object.keys(q.options ?? {}).sort();
        letters.forEach((l) => para(`   ${l}.  ${q.options?.[l]}`));
        if (q.answer) para(`Answer: ${q.answer}${q.explanation ? `  -  ${q.explanation}` : ''}`);
      });
    } else if (art.kind === 'note') {
      const data = art.data as StudioNoteData;
      if (data.summary) {
        heading('Overview');
        para(data.summary);
      }
      (data.sections ?? []).forEach((s) => {
        heading(s.heading);
        para(s.body);
      });
      if (data.keyPoints?.length) {
        heading('Key points');
        data.keyPoints.forEach(bullet);
      }
      if (data.examTips?.length) {
        heading('Exam tips');
        data.examTips.forEach(bullet);
      }
      if (data.practiceQuestions?.length) {
        heading('Practice questions');
        data.practiceQuestions.forEach((q, i) => {
          para(`${i + 1}.  ${q.stem}`);
          if (q.answer) para(`Answer: ${q.answer}  -  ${q.explanation ?? ''}`);
        });
      }
    } else if (art.kind === 'lesson_note') {
      const data = art.data as StudioLessonData;
      heading('Lesson information');
      bullet(`Subject: ${data.subject}`);
      bullet(`Class: ${data.classLevel}`);
      bullet(`Topic: ${data.topic}`);
      if (data.term) bullet(`Term: ${data.term}`);
      if (data.duration) bullet(`Duration: ${data.duration} minutes`);
      if (data.ageGroup) bullet(`Age group: ${data.ageGroup}`);
      heading('Objectives');
      (data.objectives ?? []).forEach(bullet);
      if (data.materials?.length) {
        heading('Instructional materials');
        data.materials.forEach(bullet);
      }
      if (data.entryBehaviour) {
        heading('Entry behaviour');
        para(data.entryBehaviour);
      }
      if (data.previousKnowledge) {
        heading('Previous knowledge');
        para(data.previousKnowledge);
      }
      (data.content ?? []).forEach((s) => {
        heading(s.heading);
        para(s.body);
      });
      if (data.evaluation?.length) {
        heading('Evaluation');
        data.evaluation.forEach(bullet);
      }
      if (data.summary) {
        heading('Summary');
        para(data.summary);
      }
      if (data.assignment) {
        heading('Assignment');
        para(data.assignment);
      }
    } else {
      // notebook
      const data = art.data as StudioNotebookData;
      heading('Overview');
      para(data.overview);
      (data.topicNotes ?? []).forEach((tn) => {
        rule();
        heading(tn.topic);
        para(tn.summary, 11.5);
        para(tn.deepDive);
        (tn.keyTerms ?? []).forEach((k) => bullet(`${k.term}: ${k.meaning}`));
        (tn.examples ?? []).forEach((e) => bullet(`Example: ${e}`));
      });
      if (data.glossary?.length) {
        rule();
        heading('Glossary');
        data.glossary.forEach((k) => bullet(`${k.term}: ${k.meaning}`));
      }
      if (data.examFocus?.length) {
        heading('Exam focus');
        data.examFocus.forEach(bullet);
      }
      if (data.studyPlan?.length) {
        heading('Study plan');
        data.studyPlan.forEach(bullet);
      }
    }

    stampFooter();
    const safe = (art.title || 'renance-ai')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 60);
    doc.save(`${safe || 'renance-ai'}.pdf`);
  });
}
