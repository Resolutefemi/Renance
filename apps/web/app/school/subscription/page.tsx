'use client';

import { useEffect, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnPrimary,
} from '@/components/school-shell';
import { fetchSchoolPlan, type SchoolPlanState } from '@/lib/school-subscription';
import { getActiveSchool } from '@/lib/school';

const WHATSAPP = '07046203544';

/* ------------------------------------------------------------------ */
/* The plan matrix: every feature, listed one by one, exactly as each  */
/* plan grants it. Management reads this page before choosing, so no   */
/* line is a surprise later.                                           */
/* ------------------------------------------------------------------ */

type Grant = true | false | string;

interface FeatureGroup {
  group: string;
  items: Array<{
    label: string;
    free: Grant;
    basic: Grant;
    standard: Grant;
    premium: Grant;
    note?: string;
  }>;
}

const GROUPS: FeatureGroup[] = [
  {
    group: 'Academics',
    items: [
      { label: 'Nigerian national curriculum: classes and subjects seeded for you', free: '1 subject sample', basic: true, standard: true, premium: true },
      { label: 'Term syllabus builder: topics per week, all three terms', free: false, basic: true, standard: true, premium: true },
      { label: 'Scheme of work, week by week, every class and subject', free: '1 subject sample', basic: true, standard: true, premium: true },
      { label: 'Lesson notes for every topic (read online)', free: '1 subject sample', basic: true, standard: true, premium: true },
      { label: 'Download lesson notes and scheme of work as PDFs', free: false, basic: false, standard: false, premium: true, note: 'PDF export is the premium stamp, and the one thing the trial withholds' },
      { label: 'Exam question bank: questions per subject, per term', free: false, basic: false, standard: true, premium: true },
      { label: 'Assign topics and notes to teachers for the term', free: false, basic: false, standard: true, premium: true },
    ],
  },
  {
    group: 'People',
    items: [
      { label: 'Teacher accounts the school creates and controls', free: false, basic: '3 teachers', standard: '20 teachers', premium: 'Unlimited' },
      { label: 'Student records: profiles stored by class', free: false, basic: '100 students', standard: '300 students', premium: 'Unlimited' },
      { label: 'Classes, arms and the SSS science / art / commercial split', free: false, basic: true, standard: true, premium: true },
      { label: 'Bulk import students from a spreadsheet', free: false, basic: true, standard: true, premium: true },
    ],
  },
  {
    group: 'Attendance',
    items: [
      { label: 'Daily attendance register per class', free: false, basic: true, standard: true, premium: true },
      { label: 'Attendance kiosk: students tap in their presence', free: false, basic: true, standard: true, premium: true },
      { label: 'Attendance history and per-student records', free: false, basic: true, standard: true, premium: true },
    ],
  },
  {
    group: 'Results',
    items: [
      { label: 'Result entry: CA1, CA2 and exam scores per subject', free: false, basic: false, standard: true, premium: true },
      { label: 'Authorize each teacher to fill results for their subjects', free: false, basic: false, standard: true, premium: true },
      { label: 'Term report cards with positions on finalize', free: false, basic: false, standard: true, premium: true },
      { label: 'Per-result PIN so only the family sees the sheet', free: false, basic: false, standard: true, premium: true },
    ],
  },
  {
    group: 'Operations',
    items: [
      { label: 'School fees setup and payment receipts', free: false, basic: false, standard: true, premium: true },
      { label: 'Debtors list and balance tracking', free: false, basic: false, standard: true, premium: true },
      { label: 'Student ID cards, print-ready three across', free: false, basic: false, standard: true, premium: true },
      { label: 'Timetable builder, print-ready per class', free: false, basic: false, standard: true, premium: true },
    ],
  },
  {
    group: 'Access and extras',
    items: [
      { label: 'Teachers use the mobile app: syllabus, notes, attendance on the go', free: false, basic: 'View only', standard: true, premium: true },
      { label: 'Offline packs: school content downloaded to the app for offline school days', free: false, basic: false, standard: true, premium: true },
      { label: 'Student accounts with Renance premium handled for you', free: false, basic: false, standard: false, premium: '10 students', note: 'Premium bundles premium for 10 of your students: a year each on the yearly plan, a month each on the monthly plan' },
      { label: 'Everything unlimited: students, teachers, downloads, every module', free: false, basic: false, standard: false, premium: true },
    ],
  },
];

const PLANS: Array<{
  code: string;
  name: string;
  monthly: number | null;
  yearly: number | null;
  pitch: string;
  featured?: boolean;
}> = [
  { code: 'trial', name: 'Free Trial', monthly: 0, yearly: 0, pitch: '30 days, every feature except PDF downloads. No card required.' },
  { code: 'free', name: 'Free', monthly: 0, yearly: 0, pitch: 'After the trial, keep one subject scheme of work and lesson notes as a working sample.' },
  { code: 'basic', name: 'Basic', monthly: 3000, yearly: 10000, pitch: 'The scheme-of-work desk: curriculum, notes and attendance for a small school.' },
  { code: 'standard', name: 'Standard', monthly: 6000, yearly: 25000, pitch: 'The full portal minus PDF exports: results, fees, ID cards, timetable, exams.' },
  { code: 'premium', name: 'Premium', monthly: 20000, yearly: 60000, pitch: 'Everything, unlimited, with PDF downloads and premium for 10 of your students.', featured: true },
];

function GrantCell({ g }: { g: Grant }) {
  if (g === true) {
    return (
      <span className="material-symbols-outlined mx-auto block text-[18px] text-[#0a0a0a]" aria-label="Included">
        check
      </span>
    );
  }
  if (g === false) {
    return <span className="mx-auto block text-[13px] text-[#c8c8c8]" aria-label="Not included">-</span>;
  }
  return <span className="font-mono text-[10.5px] leading-tight text-[#0a0a0a]">{g}</span>;
}

export default function SchoolSubscriptionPage() {
  const [plan, setPlan] = useState<SchoolPlanState | null>(null);
  const school = getActiveSchool();

  useEffect(() => {
    document.title = 'Subscription · School · Renance';
    fetchSchoolPlan().then(setPlan).catch(() => {});
  }, []);

  return (
    <SchoolShell title="Subscription">
      <SchoolHeading
        title="Subscription"
        sub="Every feature in every plan, listed line by line. Choose by what the school needs this session; upgrade or downgrade anytime."
      />

      {/* current state */}
      <Card>
        <CardTitle>Where your school stands</CardTitle>
        <div className="mt-2 flex flex-wrap items-center gap-x-6 gap-y-2 text-[13px] text-[#0a0a0a]">
          <span>
            School: <span className="font-semibold">{school?.schoolName ?? 'not signed in'}</span>
          </span>
          <span>
            Plan: <span className="font-mono uppercase">{plan?.plan ?? '...'}</span>
          </span>
          {plan?.expiresAt && (
            <span>
              Active until{' '}
              <span className="font-semibold">
                {new Date(plan.expiresAt).toLocaleDateString('en-NG', { day: 'numeric', month: 'long', year: 'numeric' })}
              </span>
            </span>
          )}
        </div>
        {plan?.trialDaysLeft != null && plan.trialDaysLeft <= 7 && (
          <p className="mt-3 rounded-lg bg-[#f5f5f4] px-4 py-2.5 text-[12.5px] text-[#0a0a0a]">
            {plan.trialDaysLeft} day{plan.trialDaysLeft === 1 ? '' : 's'} of the trial left. We
            mail the school daily until it ends.
          </p>
        )}
      </Card>

      {/* the tiers */}
      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {PLANS.map((p) => (
          <div
            key={p.code}
            className={`flex flex-col rounded-[14px] border p-5 ${
              p.featured
                ? 'border-2 border-[#0a0a0a] bg-white shadow-[5px_5px_0_0_#0a0a0a]'
                : 'border-[#e3e3e3] bg-white'
            }`}
          >
            <div className="flex items-center justify-between">
              <h3 className="text-[15px] font-bold tracking-tight text-[#0a0a0a]">{p.name}</h3>
              {p.featured && (
                <span className="rounded-full bg-[#0a0a0a] px-2 py-0.5 font-mono text-[9px] uppercase tracking-wider text-white">
                  everything
                </span>
              )}
            </div>
            <p className="mt-1 min-h-[40px] text-[12px] leading-snug text-[#5c5c5c]">{p.pitch}</p>
            <div className="mt-3">
              {p.code === 'trial' || p.code === 'free' ? (
                <p className="text-xl font-bold tracking-tight text-[#0a0a0a]">Free</p>
              ) : (
                <>
                  <p className="text-2xl font-bold tracking-tight text-[#0a0a0a]">
                    ₦{p.monthly!.toLocaleString('en-NG')}
                    <span className="text-[12px] font-medium text-[#5c5c5c]"> / month</span>
                  </p>
                  <p className="mt-0.5 font-mono text-[11.5px] text-[#5c5c5c]">
                    or ₦{p.yearly!.toLocaleString('en-NG')} a year
                  </p>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* the matrix */}
      {GROUPS.map((grp) => (
        <Card key={grp.group} className="mt-4">
          <CardTitle>{grp.group}</CardTitle>
          <div className="mt-2 overflow-x-auto">
            <table className="w-full min-w-[640px] border-collapse text-left">
              <thead>
                <tr className="border-b border-[#e3e3e3]">
                  <th className="py-2 pr-3 font-mono text-[9.5px] font-semibold uppercase tracking-[0.14em] text-[#9a9a9a]">
                    Feature
                  </th>
                  {(['free', 'basic', 'standard', 'premium'] as const).map((k) => (
                    <th
                      key={k}
                      className="w-[92px] py-2 text-center font-mono text-[9.5px] font-semibold uppercase tracking-[0.14em] text-[#9a9a9a]"
                    >
                      {k}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {grp.items.map((it) => (
                  <tr key={it.label} className="border-b border-[#efefef] align-top last:border-b-0">
                    <td className="py-2.5 pr-3 text-[13px] leading-snug text-[#0a0a0a]">
                      {it.label}
                      {it.note && (
                        <span className="mt-0.5 block text-[11px] leading-snug text-[#8a8a8a]">{it.note}</span>
                      )}
                    </td>
                    <td className="py-2.5 text-center"><GrantCell g={it.free} /></td>
                    <td className="py-2.5 text-center"><GrantCell g={it.basic} /></td>
                    <td className="py-2.5 text-center"><GrantCell g={it.standard} /></td>
                    <td className="py-2.5 text-center"><GrantCell g={it.premium} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      ))}

      {/* trial + bulk */}
      <Card className="mt-4">
        <CardTitle>The free trial and bulk plans</CardTitle>
        <div className="mt-2 space-y-3 text-[13px] leading-relaxed text-[#0a0a0a]">
          <p>
            <span className="font-semibold">30-day free trial.</span> Every
            feature the platform has, active for 30 days, except PDF
            downloads. We send one email when 7 days are left, then a
            daily reminder until the trial ends, so the school is never
            caught off guard.
          </p>
          <p>
            <span className="font-semibold">Bulk subscriptions.</span> Want
            Renance installed on every school PC, or premium for a whole
            class of students? Bulk pricing is negotiated directly with
            the founder on WhatsApp at{' '}
            <span className="font-mono font-semibold">{WHATSAPP}</span>.
          </p>
        </div>
        <a
          href={`https://wa.me/234${WHATSAPP.replace(/^0/, '')}`}
          target="_blank"
          rel="noreferrer"
          className={`${btnPrimary} mt-4 inline-flex`}
        >
          <span className="material-symbols-outlined text-[18px]">chat</span>
          Talk to the founder on WhatsApp
        </a>
        <p className="mt-3 font-mono text-[10.5px] leading-relaxed text-[#8a8a8a]">
          Payments are processed by Paystack once the school picks a plan.
          The trial never asks for a card.
        </p>
      </Card>
    </SchoolShell>
  );
}
