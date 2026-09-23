'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnGhost,
  btnPrimary,
  btnSmall,
  inputCls,
  selectCls,
} from '@/components/school-shell';
import {
  fetchClasses,
  getActiveSchool,
  type SchoolClass,
} from '@/lib/school';
import {
  deleteFee,
  fetchFeeBalances,
  fetchFees,
  koboText,
  recordPayment,
  saveFee,
  type FeeBalance,
  type SchoolFee,
} from '@/lib/school-fees';

// The fees desk: management prices each term's charges (school-wide or
// per class) and takes receipts; the balances tab is the debtors list.
// Teachers get a read-only view so form teachers know who owes what.

const SESSIONS = ['2025/2026', '2026/2027', '2027/2028'];

export default function SchoolFeesPage() {
  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [term, setTerm] = useState(1);
  const [session, setSession] = useState(SESSIONS[0]);
  const [tab, setTab] = useState<'charges' | 'balances'>('charges');
  const [fees, setFees] = useState<SchoolFee[]>([]);
  const [balances, setBalances] = useState<FeeBalance[]>([]);
  const [balanceClass, setBalanceClass] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [management, setManagement] = useState(false);

  // the pricing form
  const [classId, setClassId] = useState('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [amountNaira, setAmountNaira] = useState('');

  // the receipt form
  const [payStudent, setPayStudent] = useState<FeeBalance | null>(null);
  const [payFeeId, setPayFeeId] = useState('');
  const [payAmount, setPayAmount] = useState('');
  const [payMethod, setPayMethod] = useState('cash');
  const [payRef, setPayRef] = useState('');

  const loadFees = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const res = await fetchFees(a.schoolId, term, session);
    setFees(res.fees ?? []);
  }, [term, session]);

  const loadBalances = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const res = await fetchFeeBalances(a.schoolId, balanceClass, term, session);
    setBalances(res.balances ?? []);
  }, [term, session, balanceClass]);

  useEffect(() => {
    const a = getActiveSchool();
    if (!a) return;
    setManagement(a.role === 'management');
    fetchClasses(a.schoolId)
      .then((res) => setClasses(res.classes ?? []))
      .catch(() => setNotice('Could not load classes.'));
  }, []);

  useEffect(() => {
    loadFees().catch(() => setNotice('Could not load the charges.'));
  }, [loadFees]);

  useEffect(() => {
    if (tab === 'balances') loadBalances().catch(() => setNotice('Could not load the balances.'));
  }, [tab, loadBalances]);

  async function submitFee() {
    const a = getActiveSchool();
    if (!a) return;
    if (!title.trim() || !amountNaira.trim()) {
      setNotice('A title and an amount are required.');
      return;
    }
    setBusy(true);
    setNotice('');
    try {
      await saveFee(a.schoolId, {
        classId,
        title: title.trim(),
        description: description.trim(),
        amountNaira: amountNaira.trim(),
        term,
        session,
        seq: fees.length + 1,
      });
      setTitle('');
      setDescription('');
      setAmountNaira('');
      await loadFees();
      setNotice('Charge saved.');
    } catch {
      setNotice('Could not save the charge.');
    } finally {
      setBusy(false);
    }
  }

  async function removeFee(id: string) {
    const a = getActiveSchool();
    if (!a) return;
    setBusy(true);
    try {
      await deleteFee(a.schoolId, id);
      await loadFees();
    } catch {
      setNotice('Paid fees stay on the ledger; this one has receipts.');
    } finally {
      setBusy(false);
    }
  }

  function openReceipt(b: FeeBalance) {
    setPayStudent(b);
    setPayAmount(b.outstandingKobo > 0 ? String(b.outstandingKobo / 100) : '');
    setPayFeeId('');
    setPayRef('');
  }

  async function submitReceipt() {
    const a = getActiveSchool();
    if (!a || !payStudent || !payFeeId) {
      setNotice('Pick the charge the money is for.');
      return;
    }
    setBusy(true);
    setNotice('');
    try {
      await recordPayment(a.schoolId, {
        feeId: payFeeId,
        studentId: payStudent.studentId,
        amountNaira: payAmount,
        method: payMethod,
        reference: payRef.trim(),
      });
      setPayStudent(null);
      await loadBalances();
      setNotice('Receipt recorded.');
    } catch {
      setNotice('Could not record the receipt.');
    } finally {
      setBusy(false);
    }
  }

  const totals = balances.reduce(
    (acc, b) => {
      acc.charged += b.chargedKobo;
      acc.paid += b.paidKobo;
      acc.owe += b.outstandingKobo;
      return acc;
    },
    { charged: 0, paid: 0, owe: 0 },
  );

  return (
    <SchoolShell title="Fees">
      <SchoolHeading
        title="Fees"
        sub="Price the term's charges and keep the receipts flowing. Amounts are naira; the ledger keeps kobo so nothing rounds away."
        actions={
          <div className="flex gap-2">
            <select
              value={term}
              onChange={(e) => setTerm(Number(e.target.value))}
              className={`${selectCls} h-11 w-auto`}
              aria-label="Term"
            >
              <option value={1}>First Term</option>
              <option value={2}>Second Term</option>
              <option value={3}>Third Term</option>
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
          </div>
        }
      />

      {notice && (
        <p className="mb-4 rounded-lg border border-outline-variant bg-surface-container-lowest px-4 py-3 text-sm text-on-surface-variant">
          {notice}
        </p>
      )}

      <div className="mb-5 flex gap-2">
        {(['charges', 'balances'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={btnSmall + (tab === t ? ' bg-surface-container-high font-semibold' : '')}
          >
            {t === 'charges' ? 'Term charges' : 'Student balances'}
          </button>
        ))}
      </div>

      {tab === 'charges' && (
        <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
          <Card className="overflow-hidden">
            <CardTitle hint="School-wide charges land on every class; the rest hit their class only.">
              Charges for this term
            </CardTitle>
            <div className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
              <table className="w-full min-w-[560px] text-sm">
                <thead>
                  <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                    <th className="py-2 pr-3">Charge</th>
                    <th className="py-2 pr-3">Applies to</th>
                    <th className="py-2 pr-3 text-right">Amount</th>
                    {management && <th className="py-2" />}
                  </tr>
                </thead>
                <tbody>
                  {fees.length === 0 && (
                    <tr>
                      <td colSpan={4} className="py-6 text-center text-on-surface-variant">
                        No charges priced for this term yet.
                      </td>
                    </tr>
                  )}
                  {fees.map((f) => (
                    <tr key={f.id} className="border-b border-outline-variant/60 last:border-0">
                      <td className="py-3 pr-3">
                        <span className="font-medium text-on-surface">{f.title}</span>
                        {f.description && (
                          <span className="block text-xs text-on-surface-variant">{f.description}</span>
                        )}
                      </td>
                      <td className="py-3 pr-3 text-on-surface-variant">{f.className || 'Every class'}</td>
                      <td className="py-3 pr-3 text-right font-semibold">{koboText(f.amountKobo)}</td>
                      {management && (
                        <td className="py-3 text-right">
                          <button onClick={() => removeFee(f.id)} disabled={busy} className={btnSmall}>
                            Remove
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          {management && (
            <Card>
              <CardTitle hint="Empty the class pick to charge the whole school.">Price a charge</CardTitle>
              <div className="space-y-3">
                <select value={classId} onChange={(e) => setClassId(e.target.value)} className={selectCls}>
                  <option value="">Every class</option>
                  {classes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Title, e.g. School fees"
                  className={inputCls}
                />
                <input
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Note (optional)"
                  className={inputCls}
                />
                <input
                  value={amountNaira}
                  onChange={(e) => setAmountNaira(e.target.value)}
                  placeholder="Amount in naira, e.g. 15000"
                  inputMode="decimal"
                  className={inputCls}
                />
                <button onClick={submitFee} disabled={busy} className={`${btnPrimary} w-full`}>
                  Save charge
                </button>
              </div>
            </Card>
          )}
        </div>
      )}

      {tab === 'balances' && (
        <div className="space-y-5">
          {management ? (
            <Card className="overflow-hidden">
              <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
                <CardTitle hint="Every active student, scoped by class when you pick one.">Balances</CardTitle>
                <select
                  value={balanceClass}
                  onChange={(e) => setBalanceClass(e.target.value)}
                  className={`${selectCls} h-11 w-auto`}
                >
                  <option value="">All classes</option>
                  {classes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="mb-4 grid grid-cols-1 gap-3 text-center sm:grid-cols-3">
                <div className="rounded-lg border border-outline-variant p-3">
                  <p className="text-xs uppercase tracking-wide text-on-surface-variant">Charged</p>
                  <p className="text-sm font-bold">{koboText(totals.charged)}</p>
                </div>
                <div className="rounded-lg border border-outline-variant p-3">
                  <p className="text-xs uppercase tracking-wide text-on-surface-variant">Paid</p>
                  <p className="text-sm font-bold">{koboText(totals.paid)}</p>
                </div>
                <div className="rounded-lg border border-outline-variant p-3">
                  <p className="text-xs uppercase tracking-wide text-on-surface-variant">Outstanding</p>
                  <p className="text-sm font-bold">{koboText(totals.owe)}</p>
                </div>
              </div>
              <div className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
                <table className="w-full min-w-[640px] text-sm">
                  <thead>
                    <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                      <th className="py-2 pr-3">Student</th>
                      <th className="py-2 pr-3">Class</th>
                      <th className="py-2 pr-3 text-right">Charged</th>
                      <th className="py-2 pr-3 text-right">Paid</th>
                      <th className="py-2 pr-3 text-right">Outstanding</th>
                      <th className="py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {balances.length === 0 && (
                      <tr>
                        <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                          No students to bill yet.
                        </td>
                      </tr>
                    )}
                    {balances.map((b) => (
                      <tr key={b.studentId} className="border-b border-outline-variant/60 last:border-0">
                        <td className="py-3 pr-3">
                          <span className="font-medium text-on-surface">{b.studentName}</span>
                          <span className="block text-xs text-on-surface-variant">{b.admissionNo}</span>
                        </td>
                        <td className="py-3 pr-3 text-on-surface-variant">{b.className}</td>
                        <td className="py-3 pr-3 text-right">{koboText(b.chargedKobo)}</td>
                        <td className="py-3 pr-3 text-right">{koboText(b.paidKobo)}</td>
                        <td className="py-3 pr-3 text-right font-semibold">{koboText(b.outstandingKobo)}</td>
                        <td className="py-3 text-right">
                          <button onClick={() => openReceipt(b)} disabled={busy} className={btnSmall}>
                            Receipt
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>
          ) : (
            <Card>
              <p className="text-sm text-on-surface-variant">
                Balances are visible to management. Ask your school office for a student&apos;s fee position.
              </p>
            </Card>
          )}
        </div>
      )}

      {payStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/40" onClick={() => setPayStudent(null)} />
          <Card className="relative z-10 w-full max-w-md">
            <CardTitle hint={`${payStudent.studentName} (${payStudent.className})`}>Record a receipt</CardTitle>
            <div className="space-y-3">
              <select value={payFeeId} onChange={(e) => setPayFeeId(e.target.value)} className={selectCls}>
                <option value="">Which charge?</option>
                {fees
                  .filter((f) => !f.classId || f.classId === payStudent.classId)
                  .map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.title} ({koboText(f.amountKobo)})
                    </option>
                  ))}
              </select>
              <input
                value={payAmount}
                onChange={(e) => setPayAmount(e.target.value)}
                placeholder="Amount in naira"
                inputMode="decimal"
                className={inputCls}
              />
              <select value={payMethod} onChange={(e) => setPayMethod(e.target.value)} className={selectCls}>
                <option value="cash">Cash</option>
                <option value="transfer">Transfer</option>
                <option value="pos">POS</option>
                <option value="other">Other</option>
              </select>
              <input
                value={payRef}
                onChange={(e) => setPayRef(e.target.value)}
                placeholder="Reference (optional)"
                className={inputCls}
              />
              <div className="flex gap-2">
                <button onClick={submitReceipt} disabled={busy} className={`${btnPrimary} flex-1`}>
                  Record
                </button>
                <button onClick={() => setPayStudent(null)} className={btnGhost}>
                  Cancel
                </button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </SchoolShell>
  );
}
