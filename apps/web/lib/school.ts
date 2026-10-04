'use client';

// School-platform client: types + API calls + a tiny localStorage-backed
// school session so the portal remembers which school workspace you have
// open (a member can belong to more than one school).

import { api } from '@/lib/api';

export type SchoolRole = 'management' | 'teacher';

export interface SchoolInfo {
  id: string;
  name: string;
  schoolType: 'primary' | 'secondary' | 'both';
  address?: string;
  logoUrl?: string;
  /* GGSA report-card header lines (founder directive 2026-10-04). */
  phone?: string;
  email?: string;
  motto?: string;
}

export interface SchoolMemberInfo {
  id: string;
  schoolId: string;
  userId: string;
  role: SchoolRole;
  fullName: string;
  staffCode: string;
  status: string;
}

export interface SchoolContext {
  member: SchoolMemberInfo;
  school: SchoolInfo;
}

export interface SchoolClass {
  id: string;
  name: string;
  level: 'primary' | 'junior' | 'senior';
  seq: number;
}

export type SubjectDepartment = '' | 'art' | 'science' | 'commercial';

export interface SchoolSubject {
  id: string;
  name: string;
  code: string;
  level: string;
  seq: number;
  department: SubjectDepartment;
  isCore: boolean;
}

export interface SchoolTopic {
  id: string;
  title: string;
  seq: number;
  week: number;
  content: string;
  source: string;
}

export interface SchoolSyllabus {
  id: string;
  classId: string;
  subjectId: string;
  term: number;
  session: string;
  schemeOfWork: SchemeRow[];
  topics: SchoolTopic[];
}

export interface SchemeRow {
  week: number;
  topic: string;
  objectives?: string;
  activities?: string;
}

export interface SchoolStudent {
  id: string;
  classId: string;
  fullName: string;
  admissionNo: string;
  sex: '' | 'M' | 'F';
  session: string;
  guardianName?: string;
  dob?: string;
}

// The full enrollment record (student detail form).
export interface StudentDetail extends SchoolStudent {
  dob: string;
  guardianName: string;
  guardianPhone: string;
  address: string;
  photoUrl: string;
  status: 'active' | 'left' | 'graduated';
  subjects?: string[];
}

export type AttendanceStatus = 'present' | 'absent' | 'late' | 'excused';

export interface AttendanceEntry {
  studentId: string;
  status: AttendanceStatus;
  note: string;
}

export interface AttendanceSummaryRow {
  studentId: string;
  present: number;
  absent: number;
  late: number;
  excused: number;
  total: number;
  rate: number;
}

export interface AssignmentDetail {
  id: string;
  memberId: string;
  classId: string;
  subjectId: string;
  className: string;
  subjectName: string;
  memberName: string;
  memberRole: string;
}

export interface MemberSummary {
  member: SchoolMemberInfo;
  username: string;
  email: string;
}

export interface ResultItem {
  subjectId: string;
  subjectName: string;
  enteredBy?: string;
  ca1: number;
  ca2: number;
  exam: number;
  total: number;
  grade: string;
  remark: string;
  position?: number;
  classAverage?: number;
  /* GGSA sheet extras (optional): cumulative term history columns. */
  firstTermScore?: number | null;
  secondTermScore?: number | null;
  thirdTermScore?: number | null;
}

/* GGSA character/development trait on the report card (A-E ratings). */
export interface ResultTrait {
  section: string; // 'SKILL' | 'BEHAVIOUR'
  name: string;
  rating?: string | null;
}

export interface ResultSheet {
  id: string;
  studentId: string;
  studentName: string;
  admissionNo: string;
  classId: string;
  className: string;
  term: number;
  session: string;
  status: 'draft' | 'finalized';
  pin?: string;
  marksObtainable?: number;
  teacherReport: string;
  principalReport: string;
  schoolName?: string;
  schoolLogoUrl?: string;
  items: ResultItem[];
  /* GGSA sheet extras (optional, rendered when the API ships them). */
  sex?: string;
  noInClass?: number;
  attendancePresent?: number;
  attendanceOpened?: number;
  nextTermBegins?: string;
  schoolAddress?: string;
  schoolPhone?: string;
  schoolEmail?: string;
  schoolMotto?: string;
  traits?: ResultTrait[] | null;
}

/* ------------------------------------------------------------------
 * GGSA grade scale - the authoritative boundaries of the God Generals
 * Standard Academy result portal, identical to the study-api's
 * internal/school/grade.go (A 70-100, B 60-69, C 50-59, D 45-49,
 * E 40-44, F 0-39). Exported so the report card renders its grading
 * key and grade chips from the same table the backend grades with.
 * ------------------------------------------------------------------ */
export const GRADE_SCALE = [
  { grade: 'A', min: 70, max: 100, remark: 'Excellent' },
  { grade: 'B', min: 60, max: 69, remark: 'Very Good' },
  { grade: 'C', min: 50, max: 59, remark: 'Good' },
  { grade: 'D', min: 45, max: 49, remark: 'Pass' },
  { grade: 'E', min: 40, max: 44, remark: 'Fair' },
  { grade: 'F', min: 0, max: 39, remark: 'Fail' },
] as const;

/* GGSA paper-card trait lists (used when the API ships no traits). */
export const SKILL_TRAITS = [
  'Handwriting',
  'Fluency',
  'Spelling',
  'Drawing',
  'Painting & Craft',
  'Music',
  'Drama',
] as const;

export const BEHAVIOUR_TRAITS = [
  'Attentiveness',
  'Punctuality',
  'Neatness',
  'Politeness',
  'Honesty',
  'Reliability',
  'Obedience',
] as const;

// ------------------------------------------------------------- session

const SCHOOL_KEY = 'renance.school.v1';

export interface ActiveSchool {
  schoolId: string;
  schoolName: string;
  role: SchoolRole;
  memberId: string;
  fullName: string;
}

export function setActiveSchool(a: ActiveSchool): void {
  try {
    localStorage.setItem(SCHOOL_KEY, JSON.stringify(a));
  } catch {
    /* private mode */
  }
}

export function getActiveSchool(): ActiveSchool | null {
  try {
    const raw = localStorage.getItem(SCHOOL_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as ActiveSchool;
  } catch {
    return null;
  }
}

export function clearActiveSchool(): void {
  try {
    localStorage.removeItem(SCHOOL_KEY);
  } catch {
    /* private mode */
  }
}

// Pick the first membership (or the requested one) and remember it.
export function chooseSchool(ctxs: SchoolContext[], preferredId?: string): ActiveSchool | null {
  const pick = (preferredId && ctxs.find((c) => c.school.id === preferredId)) || ctxs[0];
  if (!pick) return null;
  const active: ActiveSchool = {
    schoolId: pick.school.id,
    schoolName: pick.school.name,
    role: pick.member.role,
    memberId: pick.member.id,
    fullName: pick.member.fullName,
  };
  setActiveSchool(active);
  return active;
}

// ---------------------------------------------------------------- API

export function schoolMe(): Promise<{ schools: SchoolContext[] }> {
  return api('/school/me');
}

export function schoolRegister(body: {
  schoolName: string;
  schoolType: string;
  fullName: string;
  email: string;
  password: string;
}): Promise<{
  token: string;
  user: { id: string; username: string; profileCompleted: boolean };
  school: { id: string; name: string; schoolType: string; memberId: string; role: string };
}> {
  return api('/school/auth/register', { method: 'POST', body, auth: false });
}

export const fetchClasses = (schoolId: string) =>
  api<{ classes: SchoolClass[] }>(`/school/classes?schoolId=${encodeURIComponent(schoolId)}`);

export const fetchSubjects = (schoolId: string) =>
  api<{ subjects: SchoolSubject[] }>(`/school/subjects?schoolId=${encodeURIComponent(schoolId)}`);

export const fetchClassSubjects = (schoolId: string) =>
  api<{ pairs: { classId: string; className: string; subjectId: string; subjectName: string }[] }>(
    `/school/class-subjects?schoolId=${encodeURIComponent(schoolId)}`,
  );

export const fetchMembers = (schoolId: string) =>
  api<{ members: MemberSummary[] }>(`/school/members?schoolId=${encodeURIComponent(schoolId)}`);

export const fetchAssignments = (schoolId: string, memberId = '') =>
  api<{ assignments: AssignmentDetail[] }>(
    `/school/assignments?schoolId=${encodeURIComponent(schoolId)}${
      memberId ? `&memberId=${encodeURIComponent(memberId)}` : ''
    }`,
  );

export const fetchStudents = (schoolId: string, classId = '') =>
  api<{ students: SchoolStudent[] }>(
    `/school/students?schoolId=${encodeURIComponent(schoolId)}${
      classId ? `&classId=${encodeURIComponent(classId)}` : ''
    }`,
  );

export const fetchSyllabus = (schoolId: string, classId: string, subjectId: string) =>
  api<{ terms: SchoolSyllabus[] }>(
    `/school/syllabus?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&subjectId=${encodeURIComponent(subjectId)}`,
  );

export const saveTopic = (schoolId: string, topicId: string, title: string, content: string, week: number) =>
  api('/school/topic', { method: 'PUT', body: { schoolId, topicId, title, content, week } });

export const saveScheme = (schoolId: string, syllabusId: string, scheme: SchemeRow[]) =>
  api('/school/scheme', { method: 'PUT', body: { schoolId, syllabusId, scheme } });

export const seedCurriculum = (schoolId: string) =>
  api<{ seededClasses: number; seededSubjects: number }>('/school/seed-curriculum', {
    method: 'POST',
    body: { schoolId },
  });

export const createTeacher = (schoolId: string, body: { fullName: string; email: string; password: string; staffCode: string }) =>
  api('/school/teachers', { method: 'POST', body: { schoolId, ...body } });

export const toggleAssignment = (schoolId: string, memberId: string, classId: string, subjectId: string, remove: boolean) =>
  api('/school/assignments', { method: 'POST', body: { schoolId, memberId, classId, subjectId, remove } });

export const createStudent = (schoolId: string, body: { classId: string; fullName: string; admissionNo: string; sex: string; session: string }) =>
  api<{ student: SchoolStudent }>('/school/students', { method: 'POST', body: { schoolId, ...body } });

export const fetchResults = (schoolId: string, classId: string, term: number, session: string) =>
  api<{ results: ResultSheet[] }>(
    `/school/results?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&term=${term}&session=${encodeURIComponent(session)}`,
  );

export const saveResultItem = (schoolId: string, body: {
  studentId: string;
  classId: string;
  subjectId: string;
  term: number;
  session: string;
  ca1: number;
  ca2: number;
  exam: number;
}) => api<{ item: ResultItem }>('/school/result-item', { method: 'PUT', body: { schoolId, ...body } });

/* The GGSA report-card extras (founder directive 2026-10-04): traits
 * (name -> A-E), attendance counts, teacher/principal reports and the
 * next-term-begins line, saved per student per term. */
export const saveResultDetail = (
  schoolId: string,
  body: {
    studentId: string;
    classId: string;
    term: number;
    session: string;
    traits: Record<string, string>;
    attendancePresent: number | null;
    attendanceOpened: number | null;
    teacherReport: string;
    principalReport: string;
    nextTermBegins: string;
  },
) => api<{ ok: true }>('/school/result-detail', { method: 'PUT', body: { schoolId, ...body } });

/* The API stores traits as a flat { name: rating } map; the report card
 * renders the ordered SKILL/BEHAVIOUR cards. Normalize both shapes. */
export function normalizeTraits(raw: unknown): ResultTrait[] | null {
  if (Array.isArray(raw)) return raw.length ? (raw as ResultTrait[]) : null;
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    const record = raw as Record<string, string>;
    const out: ResultTrait[] = [];
    for (const name of SKILL_TRAITS) out.push({ section: 'SKILL', name, rating: record[name] ?? null });
    for (const name of BEHAVIOUR_TRAITS) out.push({ section: 'BEHAVIOUR', name, rating: record[name] ?? null });
    return out;
  }
  return null;
}

/** One student's full report card (bio + extras + items) - the sheet the
 * report-card modal renders and the details editor edits. */
export async function fetchResultSheet(
  schoolId: string,
  studentId: string,
  term: number,
  session: string,
): Promise<ResultSheet> {
  const res = await api<{ result: ResultSheet }>(
    `/school/result-sheet?schoolId=${encodeURIComponent(schoolId)}&studentId=${encodeURIComponent(
      studentId,
    )}&term=${term}&session=${encodeURIComponent(session)}`,
  );
  const sheet = res.result;
  return { ...sheet, items: sheet.items ?? [], traits: normalizeTraits(sheet.traits) };
}

export const finalizeResults = (schoolId: string, classId: string, term: number, session: string) =>
  api<{ finalized: number }>('/school/finalize', { method: 'POST', body: { schoolId, classId, term, session } });

export async function checkResultByPin(pin: string, term: number, session: string): Promise<{ result: ResultSheet }> {
  const res = await api<{ result: ResultSheet }>(
    `/school/check-result?pin=${encodeURIComponent(pin)}&term=${term}&session=${encodeURIComponent(session)}`,
    { auth: false },
  );
  // Normalize the flat trait map into the ordered SKILL/BEHAVIOUR cards.
  return {
    result: { ...res.result, items: res.result.items ?? [], traits: normalizeTraits(res.result.traits) },
  };
}

// Term ordinal -> label, shared by portal + PDF.
export function termLabel(term: number): string {
  return term === 1 ? 'First Term' : term === 2 ? 'Second Term' : 'Third Term';
}

// ------------------------------------------------- setup / people / attendance API

export const fetchSchoolProfile = (schoolId: string) =>
  api<{ school: SchoolInfo & { logoUrl?: string } }>(
    `/school/profile?schoolId=${encodeURIComponent(schoolId)}`,
  );

export const updateSchoolProfile = (
  schoolId: string,
  body: { name?: string; address?: string; phone?: string; email?: string; motto?: string; logoUrl?: string; clearLogo?: boolean },
) => api<{ school: SchoolInfo }>('/school/profile', { method: 'PUT', body: { schoolId, ...body } });

export const createSubject = (
  schoolId: string,
  body: { name: string; code: string; level: string; department: SubjectDepartment; isCore: boolean },
) => api<{ subject: SchoolSubject }>('/school/subject', { method: 'POST', body: { schoolId, ...body } });

export const updateSubject = (
  schoolId: string,
  body: { id: string; name?: string; code?: string; department?: SubjectDepartment; isCore?: boolean },
) => api('/school/subject', { method: 'PUT', body: { schoolId, ...body } });

export const setClassSubject = (schoolId: string, classId: string, subjectId: string, remove: boolean) =>
  api('/school/class-subject', { method: 'POST', body: { schoolId, classId, subjectId, remove } });

export const fetchStudentDetail = (schoolId: string, studentId: string) =>
  api<{ student: StudentDetail }>(
    `/school/student-detail?schoolId=${encodeURIComponent(schoolId)}&studentId=${encodeURIComponent(studentId)}`,
  );

export const updateStudent = (schoolId: string, student: Partial<StudentDetail> & { id: string }) =>
  api<{ student: StudentDetail }>('/school/student', { method: 'PUT', body: { schoolId, ...student } });

export const fetchStudentSubjects = (schoolId: string, studentId: string) =>
  api<{ subjectIds: string[] }>(
    `/school/student-subjects?schoolId=${encodeURIComponent(schoolId)}&studentId=${encodeURIComponent(studentId)}`,
  );

export const setStudentSubjects = (schoolId: string, studentId: string, subjectIds: string[]) =>
  api('/school/student-subjects', { method: 'PUT', body: { schoolId, studentId, subjectIds } });

export const fetchAttendanceDay = (schoolId: string, classId: string, day: string) =>
  api<{ entries: AttendanceEntry[] }>(
    `/school/attendance?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&day=${encodeURIComponent(day)}`,
  );

export const saveAttendance = (schoolId: string, classId: string, day: string, entries: AttendanceEntry[]) =>
  api<{ saved: number }>('/school/attendance', { method: 'POST', body: { schoolId, classId, day, entries } });

export const fetchAttendanceSummary = (schoolId: string, classId: string, from: string, to: string) =>
  api<{ summary: AttendanceSummaryRow[] }>(
    `/school/attendance-summary?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
  );

export const bulkNotes = (
  schoolId: string,
  body: { classId: string; subjectId: string; term: number; session: string; overwrite: boolean; topics: { title: string; week: number; content: string; source: string }[] },
) => api<{ written: number; received: number }>('/school/bulk-notes', { method: 'POST', body: { schoolId, ...body } });

// todayISO returns the local date in the YYYY-MM-DD shape the
// attendance endpoints expect.
export function todayISO(d = new Date()): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// Draft the NERDC scheme of work into every empty syllabus slot of a
// session. Idempotent: filled schemes stay untouched.
export const seedSchemes = (schoolId: string, session: string) =>
  api<{ filled: number }>('/school/seed-schemes', { method: 'POST', body: { schoolId, session } });

// Switch the active workspace to another membership. Persists the pick
// so the next page load lands in the same school.
export function switchSchool(ctxs: SchoolContext[], schoolId: string): ActiveSchool | null {
  const pick = ctxs.find((c) => c.school.id === schoolId);
  if (!pick) return null;
  const active: ActiveSchool = {
    schoolId: pick.school.id,
    schoolName: pick.school.name,
    role: pick.member.role,
    memberId: pick.member.id,
    fullName: pick.member.fullName,
  };
  setActiveSchool(active);
  return active;
}
