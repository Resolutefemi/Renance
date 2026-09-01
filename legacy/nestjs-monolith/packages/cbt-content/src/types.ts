/**
 * CBT content pipeline types (Gate 1.8).
 *
 * DOCTRINE (ADR-0003): one bank -> TWO artifacts.
 *   bundle  — what students/devices ever see: questions, NO answer material
 *   key     — server-only: correct answers + explanations (post-result reveal)
 * Explanations deliberately live in the KEY: they usually restate the answer,
 * so they may only surface AFTER grading.
 */

export type QuestionType = 'mcq' | 'text';

export interface BundleQuestion {
  id: string;
  type: QuestionType;
  stem: string;
  /** MCQ only: letter -> option text. Letters A.. uppercase, no gaps. */
  options?: Record<string, string>;
  marks: number;
}

export interface CbtBundle {
  code: string; // bank identifier, filename-derived, lowercase-dash
  title: string;
  version: number; // starts at 1; bump on republish
  questionCount: number;
  totalMarks: number;
  durationMinutes: number | null;
  questions: BundleQuestion[];
}

export type KeyEntry =
  | { type: 'mcq'; letter: string; explanation?: string }
  | { type: 'text'; accepted: string[]; explanation?: string };

export interface CbtKey {
  code: string;
  version: number;
  /** question id -> grading material. NEVER leaves the server. */
  answers: Record<string, KeyEntry>;
}

export interface BuildReport {
  file: string;
  code: string;
  parsed: number;
  kept: number;
  mcq: number;
  text: number;
  fixes: string[];
  dropped: Array<{ index: number; reason: string }>;
}
