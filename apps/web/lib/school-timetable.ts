'use client';

// Timetable client: one class week in, one class week out.

import { api } from '@/lib/api';

export interface TimetableSlot {
  id: string;
  classId: string;
  day: number; // 1 Monday .. 5 Friday
  period: number;
  startTime: string;
  endTime: string;
  subjectId: string;
  label: string;
}

export interface TimetableSubject {
  subjectId: string;
  subjectName: string;
  code: string;
}

export interface TimetableWeek {
  classId: string;
  slots: TimetableSlot[];
  subjects: TimetableSubject[];
}

export const fetchTimetable = (schoolId: string, classId: string) =>
  api<{ timetable: TimetableWeek }>(
    `/school/timetable?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(classId)}`,
  );

export const saveTimetable = (schoolId: string, classId: string, slots: TimetableSlot[]) =>
  api<{ saved: number }>('/school/timetable', {
    method: 'POST',
    body: { schoolId, classId, slots },
  });

export const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
