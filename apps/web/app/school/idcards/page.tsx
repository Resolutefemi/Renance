'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnPrimary,
  btnSmall,
  selectCls,
} from '@/components/school-shell';
import { fetchClasses, getActiveSchool, type SchoolClass } from '@/lib/school';
import { fetchIDCards, issueIDCards, setCardStatus, type IDCardRow } from '@/lib/school-idcards';

// The ID card desk: issue cards per session, browse them by class,
// revoke a lost serial, and print the sheet. The card face is strict
// black on white; the school logo is the only image allowed.

const SESSIONS = ['2025/2026', '2026/2027', '2027/2028'];

function CardFace({ row }: { row: IDCardRow }) {
  return (
    <div className="ren-card-face w-[288px] shrink-0 overflow-hidden rounded-xl border-2 border-black bg-white text-black">
      <div className="flex items-center gap-2 border-b-2 border-black px-3 py-2">
        {row.schoolLogoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={row.schoolLogoUrl} alt="" className="h-9 w-9 rounded object-cover" />
        ) : (
          <span className="flex h-9 w-9 items-center justify-center rounded bg-black text-white">
            <span className="material-symbols-outlined text-[18px]">school</span>
          </span>
        )}
        <div className="min-w-0">
          <p className="truncate text-[11px] font-bold leading-tight">{row.schoolName || 'School'}</p>
          <p className="text-[9px] uppercase tracking-wider">Student Identity Card</p>
        </div>
      </div>
      <div className="flex gap-3 px-3 py-2.5">
        {row.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={row.photoUrl} alt="" className="h-16 w-14 rounded border border-black object-cover" />
        ) : (
          <span className="flex h-16 w-14 items-center justify-center rounded border border-black bg-surface-container text-black">
            <span className="material-symbols-outlined">person</span>
          </span>
        )}
        <div className="min-w-0 flex-1 text-[10px] leading-snug">
          <p className="truncate text-[12px] font-bold">{row.studentName}</p>
          <p className="truncate">{row.admissionNo}</p>
          <p className="truncate">{row.className}</p>
          <p className="truncate">Sex: {row.sex || '-'}</p>
          {row.dob && <p className="truncate">DOB: {row.dob}</p>}
          {row.guardianPhone && <p className="truncate">Guardian: {row.guardianPhone}</p>}
        </div>
      </div>
      <div className="flex items-center justify-between border-t border-black px-3 py-1.5 text-[9px]">
        <span className="font-bold">{row.card.serial}</span>
        <span>{row.card.session}</span>
        <span className="uppercase">{row.card.status}</span>
      </div>
    </div>
  );
}

export default function SchoolIDCardsPage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [classId, setClassId] = useState('');
  const [session, setSession] = useState(SESSIONS[0]);
  const [cards, setCards] = useState<IDCardRow[]>([]);
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [management, setManagement] = useState(false);

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const res = await fetchIDCards(a.schoolId, classId, session);
    setCards(res.cards ?? []);
  }, [classId, session]);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setManagement(a.role === 'management');
    fetchClasses(a.schoolId)
      .then((res) => setClasses(res.classes ?? []))
      .catch(() => setNotice('Could not load classes.'));
  }, []);

  useEffect(() => {
    load().catch(() => setNotice('Could not load the cards.'));
  }, [load]);

  async function issueAll() {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    setNotice('');
    try {
      const res = await issueIDCards(a.schoolId, classId, session);
      setNotice(`Issued ${res.issued} card${res.issued === 1 ? '' : 's'}.`);
      await load();
    } catch {
      setNotice('Could not issue the cards.');
    } finally {
      setBusy(false);
    }
  }

  async function toggleStatus(row: IDCardRow) {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    try {
      await setCardStatus(a.schoolId, row.card.id, row.card.status === 'revoked' ? 'issued' : 'revoked');
      await load();
    } catch {
      setNotice('Could not update the card.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <SchoolShell title="ID Cards">
      <SchoolHeading
        title="Student ID Cards"
        sub="One card per student per session, serial-numbered. Revoke a lost card and the serial history stays put."
        actions={
          <div className="flex flex-wrap gap-2">
            <select
              value={classId}
              onChange={(e) => setClassId(e.target.value)}
              className={`${selectCls} h-11 w-auto`}
              aria-label="Class"
            >
              <option value="">All classes</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <select
              value={session}
              onChange={(e) => setSession(e.target.value)}
              className={`${selectCls} h-11 w-auto`}
              aria-label="Session"
            >
              {SESSIONS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
            {management && (
              <button onClick={issueAll} disabled={busy} className={btnPrimary}>
                Issue missing cards
              </button>
            )}
            <button onClick={() => window.print()} className={btnSmall}>
              Print sheet
            </button>
          </div>
        }
      />

      {notice && (
        <p className="mb-4 rounded-lg border border-outline-variant bg-surface-container-lowest px-4 py-3 text-sm text-on-surface-variant print:hidden">
          {notice}
        </p>
      )}

      <Card className="overflow-hidden print:border-0 print:shadow-none">
        <CardTitle hint={`${cards.length} card${cards.length === 1 ? '' : 's'} in view.`}>Card sheet</CardTitle>
        {cards.length === 0 ? (
          <p className="py-6 text-center text-sm text-on-surface-variant">
            No cards for this pick yet. Management can issue them in one tap.
          </p>
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3 print:grid-cols-3">
            {cards.map((row) => (
              <div key={row.card.id} className="space-y-1.5">
                <CardFace row={row} />
                {management && (
                  <div className="flex justify-end print:hidden">
                    <button onClick={() => toggleStatus(row)} disabled={busy} className={btnSmall}>
                      {row.card.status === 'revoked' ? 'Re-activate' : 'Revoke'}
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </Card>
    </SchoolShell>
  );
}
