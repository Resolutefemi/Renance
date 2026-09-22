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

export interface SchoolSubject {
  id: string;
  name: string;
  code: string;
  level: string;
  seq: number;
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
  items: ResultItem[];
}

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

export const finalizeResults = (schoolId: string, classId: string, term: number, session: string) =>
  api<{ finalized: number }>('/school/finalize', { method: 'POST', body: { schoolId, classId, term, session } });

export function checkResultByPin(pin: string, term: number, session: string): Promise<{ result: ResultSheet }> {
  return api(
    `/school/check-result?pin=${encodeURIComponent(pin)}&term=${term}&session=${encodeURIComponent(session)}`,
    { auth: false },
  );
}

// Term ordinal -> label, shared by portal + PDF.
export function termLabel(term: number): string {
  return term === 1 ? 'First Term' : term === 2 ? 'Second Term' : 'Third Term';
}
