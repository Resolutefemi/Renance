'use client';

// Exam bank client: the pool calls and the published-paper calls. The
// bank holds original, curriculum-aligned questions per subject per
// term; papers draw from the pool at print time.

import { api } from '@/lib/api';

export interface ExamQuestion {
  id: string;
  subjectId: string;
  subjectName?: string;
  band: 'primary' | 'junior' | 'senior' | '';
  term: number;
  session: string;
  question: string;
  options: string[];
  answerIndex: number;
  explanation: string;
  marks: number;
  source: string;
}

export interface SchoolExam {
  id: string;
  classId: string;
  className: string;
  subjectId: string;
  subjectName: string;
  term: number;
  session: string;
  title: string;
  durationMinutes: number;
  questionCount: number;
  status: string;
}

export const fetchExamQuestions = (
  schoolId: string,
  subjectId: string,
  term: number,
  session: string,
  band: string,
) =>
  api<{ questions: ExamQuestion[] }>(
    `/school/exam-questions?schoolId=${encodeURIComponent(schoolId)}&subjectId=${encodeURIComponent(
      subjectId,
    )}&term=${term}&session=${encodeURIComponent(session)}&band=${encodeURIComponent(band)}`,
  );

export const addExamQuestion = (
  schoolId: string,
  body: {
    subjectId: string;
    band: string;
    term: number;
    session: string;
    question: string;
    options: string[];
    answerIndex: number;
    explanation: string;
    marks: number;
  },
) => api<{ question: ExamQuestion }>('/school/exam-question', { method: 'POST', body: { schoolId, ...body } });

export const deleteExamQuestion = (schoolId: string, id: string) =>
  api<{ ok: boolean }>(
    `/school/exam-question?schoolId=${encodeURIComponent(schoolId)}&id=${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );

export const fetchExams = (schoolId: string, term: number, session: string) =>
  api<{ exams: SchoolExam[] }>(
    `/school/exams?schoolId=${encodeURIComponent(schoolId)}&term=${term}&session=${encodeURIComponent(session)}`,
  );

export const publishExam = (
  schoolId: string,
  body: {
    classId: string;
    subjectId: string;
    term: number;
    session: string;
    title: string;
    durationMinutes: number;
    questionCount: number;
  },
) => api<{ exam: SchoolExam }>('/school/exam', { method: 'POST', body: { schoolId, ...body } });

// Pour the original starter questions into the pool. Idempotent: what
// is already there stays.
export const seedExamBank = (schoolId: string) =>
  api<{ added: number }>('/school/seed-exam-bank', { method: 'POST', body: { schoolId } });

export const fetchExamPaper = (schoolId: string, id: string) =>
  api<{ exam: SchoolExam; questions: ExamQuestion[] }>(
    `/school/exam-paper?schoolId=${encodeURIComponent(schoolId)}&id=${encodeURIComponent(id)}`,
  );

// bandForClassName maps a class name to the bank band tag, mirroring
// the server rule so the picker preselects the right pool.
export function bandForClassName(name: string): 'primary' | 'junior' | 'senior' {
  if (name.startsWith('Primary')) return 'primary';
  if (name.startsWith('JSS')) return 'junior';
  return 'senior';
}

// LETTERS renders option indices as the A/B/C/D column markers.
export const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];
