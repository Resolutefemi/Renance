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

// ------------------------------------------------- setup / people / attendance API

export const fetchSchoolProfile = (schoolId: string) =>
  api<{ school: SchoolInfo & { logoUrl?: string } }>(
    `/school/profile?schoolId=${encodeURIComponent(schoolId)}`,
  );

export const updateSchoolProfile = (
  schoolId: string,
  body: { name?: string; address?: string; logoUrl?: string; clearLogo?: boolean },
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
