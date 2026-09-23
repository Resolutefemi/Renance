'use client';

// Fees desk client: types + calls for the school money pages. Amounts
// travel as naira strings for input and kobo numbers for display math,
// exactly what the API speaks.

import { api } from '@/lib/api';

export interface SchoolFee {
  id: string;
  classId: string;
  className: string;
  title: string;
  description: string;
  amountKobo: number;
  term: number;
  session: string;
  seq: number;
}

export interface SchoolFeePayment {
  id: string;
  feeId: string;
  studentId: string;
  amountKobo: number;
  method: string;
  reference: string;
  paidOn: string;
}

export interface FeeBalance {
  studentId: string;
  studentName: string;
  admissionNo: string;
  className: string;
  classId: string;
  chargedKobo: number;
  paidKobo: number;
  outstandingKobo: number;
  lastPayment: string;
}

export const fetchFees = (schoolId: string, term: number, session: string) =>
  api<{ fees: SchoolFee[] }>(
    `/school/fees?schoolId=${encodeURIComponent(schoolId)}&term=${term}&session=${encodeURIComponent(session)}`,
  );

export const saveFee = (
  schoolId: string,
  body: {
    classId: string;
    title: string;
    description: string;
    amountNaira: string;
    term: number;
    session: string;
    seq?: number;
  },
) => api<{ fee: SchoolFee }>('/school/fee', { method: 'PUT', body: { schoolId, ...body } });

export const deleteFee = (schoolId: string, id: string) =>
  api<{ ok: boolean }>(
    `/school/fee?schoolId=${encodeURIComponent(schoolId)}&id=${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );

export const recordPayment = (
  schoolId: string,
  body: { feeId: string; studentId: string; amountNaira: string; method: string; reference?: string; paidOn?: string },
) => api<{ payment: SchoolFeePayment }>('/school/fee-payment', { method: 'POST', body: { schoolId, ...body } });

export const fetchPayments = (schoolId: string, studentId: string, term: number, session: string) =>
  api<{ payments: SchoolFeePayment[] }>(
    `/school/fee-payments?schoolId=${encodeURIComponent(schoolId)}&studentId=${encodeURIComponent(
      studentId,
    )}&term=${term}&session=${encodeURIComponent(session)}`,
  );

export const fetchFeeBalances = (schoolId: string, classId: string, term: number, session: string) =>
  api<{ balances: FeeBalance[] }>(
    `/school/fee-balances?schoolId=${encodeURIComponent(schoolId)}&classId=${encodeURIComponent(
      classId,
    )}&term=${term}&session=${encodeURIComponent(session)}`,
  );

// koboText renders kobo as a naira string with thousands separators,
// the way the ledger prints on the desk and on receipts.
export function koboText(kobo: number): string {
  const naira = Math.round(kobo) / 100;
  const whole = Math.floor(Math.abs(naira));
  const frac = Math.abs(naira) - whole;
  const groups = whole.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const sign = naira < 0 ? '-' : '';
  const cents = frac > 0 ? `.${(Math.round(frac * 100) / 100).toFixed(2).slice(2)}` : '';
  return `${sign}\u20A6${groups}${cents}`;
}
