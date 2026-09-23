'use client';

// ID card client: the ledger calls the card desk page makes plus the
// types the printable card sheet consumes.

import { api } from '@/lib/api';

export interface SchoolIDCard {
  id: string;
  studentId: string;
  serial: string;
  session: string;
  status: 'issued' | 'revoked' | 'reprinted';
  issuedAt: string;
}

export interface IDCardRow {
  card: SchoolIDCard;
  studentName: string;
  admissionNo: string;
  className: string;
  classId: string;
  sex: string;
  dob: string;
  photoUrl: string;
  guardianPhone: string;
  schoolName: string;
  schoolLogoUrl: string;
  address: string;
}

export const fetchIDCards = (schoolId: string, classId: string, session: string) =>
  api<{ cards: IDCardRow[] }>(
    `/school/id-cards?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&session=${encodeURIComponent(session)}`,
  );

export const issueIDCard = (schoolId: string, studentId: string, session: string) =>
  api<{ card: SchoolIDCard }>('/school/id-card', {
    method: 'POST',
    body: { schoolId, studentId, session },
  });

// Batch issue: every active student in scope who lacks a card gets
// one; the count says how many gaps were filled.
export const issueIDCards = (schoolId: string, classId: string, session: string) =>
  api<{ issued: number }>('/school/id-cards', {
    method: 'POST',
    body: { schoolId, classId, session },
  });

export const setCardStatus = (schoolId: string, cardId: string, status: 'issued' | 'revoked') =>
  api<{ ok: boolean }>('/school/id-card', { method: 'PUT', body: { schoolId, cardId, status } });
