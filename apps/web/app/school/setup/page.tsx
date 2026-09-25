'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  SchoolHeading,
  SchoolShell,
  Card,
  CardTitle,
  btnPrimary,
  btnSmall,
  inputCls,
  selectCls,
} from '@/components/school-shell';
import {
  createSubject,
  fetchClasses,
  fetchClassSubjects,
  fetchSchoolProfile,
  fetchSubjects,
  getActiveSchool,
  setClassSubject,
  updateSchoolProfile,
  updateSubject,
  type SchoolClass,
  type SchoolSubject,
  type SubjectDepartment,
} from '@/lib/school';

// School Setup: the identity + curriculum desk management fills before
// results season. Three panels: the school record (logo, name, address),
// the subject catalog (with art / science / commercial departments for
// the senior band) and the per-class subject picker.

const DEPARTMENTS: { key: SubjectDepartment; label: string }[] = [
  { key: '', label: 'General' },
  { key: 'art', label: 'Art' },
  { key: 'science', label: 'Science' },
  { key: 'commercial', label: 'Commercial' },
];

export default function SchoolSetupPage() {
  const [school, setSchool] = useState<{ name: string; address: string; logoUrl: string; schoolType: string } | null>(null);
  const [name, setName] = useState('');
  const [address, setAddress] = useState('');
  const [logo, setLogo] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileNotice, setProfileNotice] = useState('');

  const [classes, setClasses] = useState<SchoolClass[]>([]);
  const [subjects, setSubjects] = useState<SchoolSubject[]>([]);
  const [pairs, setPairs] = useState<Set<string>>(new Set());
  const [activeClass, setActiveClass] = useState('');
  const [pairBusy, setPairBusy] = useState('');

  const [subName, setSubName] = useState('');
  const [subCode, setSubCode] = useState('');
  const [subLevel, setSubLevel] = useState('senior');
  const [subDept, setSubDept] = useState<SubjectDepartment>('');
  const [subCore, setSubCore] = useState(false);
  const [subBusy, setSubBusy] = useState(false);
  const [subNotice, setSubNotice] = useState('');

  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    const a = getActiveSchool();
    if (!a) return;
    const [prof, cls, subs, cs] = await Promise.all([
      fetchSchoolProfile(a.schoolId),
      fetchClasses(a.schoolId),
      fetchSubjects(a.schoolId),
      fetchClassSubjects(a.schoolId),
    ]);
    setSchool({
      name: prof.school?.name ?? '',
      address: prof.school?.address ?? '',
      logoUrl: prof.school?.logoUrl ?? '',
      schoolType: prof.school?.schoolType ?? '',
    });
    setName(prof.school?.name ?? '');
    setAddress(prof.school?.address ?? '');
    setLogo(prof.school?.logoUrl ?? '');
    setClasses(cls.classes ?? []);
    setSubjects(subs.subjects ?? []);
    setPairs(new Set((cs.pairs ?? []).map((p) => `${p.classId}|${p.subjectId}`)));
    const first = (cls.classes ?? [])[0]?.id ?? '';
    setActiveClass((cur) => cur || first);
  }, []);

  useEffect(() => {
    load().catch(() => setProfileNotice('Could not load the school profile.'));
  }, [load]);

  async function saveProfile() {
    const a = getActiveSchool();
    if (!a) return;
    setSavingProfile(true);
    setProfileNotice('');
    try {
      await updateSchoolProfile(a.schoolId, { name, address, logoUrl: logo || undefined });
      setProfileNotice('Saved. The logo now appears on the portal and every report card.');
    } catch (err) {
      setProfileNotice(err instanceof Error ? err.message : 'Could not save.');
    } finally {
      setSavingProfile(false);
    }
  }

  // Resize + encode the chosen logo fully client-side: long edge 256px,
  // PNG data URL, comfortably inside the API's size ceiling.
  function onLogoFile(file: File) {
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(1, 256 / Math.max(img.width, img.height));
        const w = Math.max(1, Math.round(img.width * scale));
        const h = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        ctx.drawImage(img, 0, 0, w, h);
        setLogo(canvas.toDataURL('image/png'));
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  }

  async function addSubject() {
    const a = getActiveSchool();
    if (!a || !subName.trim()) return;
    setSubBusy(true);
    setSubNotice('');
    try {
      const res = await createSubject(a.schoolId, {
        name: subName.trim(),
        code: subCode.trim(),
        level: subLevel,
        department: subDept,
        isCore: subCore,
      });
      setSubjects((cur) => [...cur, res.subject].sort((x, y) => x.seq - y.seq || x.name.localeCompare(y.name)));
      setSubName('');
      setSubCode('');
      setSubNotice(`Added ${res.subject.name}.`);
    } catch (err) {
      setSubNotice(err instanceof Error ? err.message : 'Could not add the subject.');
    } finally {
      setSubBusy(false);
    }
  }

  async function togglePair(classId: string, subject: SchoolSubject) {
    const a = getActiveSchool();
    if (!a) return;
    const key = `${classId}|${subject.id}`;
    const remove = pairs.has(key);
    setPairBusy(key);
    try {
      await setClassSubject(a.schoolId, classId, subject.id, remove);
      setPairs((cur) => {
        const next = new Set(cur);
        if (remove) next.delete(key);
        else next.add(key);
        return next;
      });
    } finally {
      setPairBusy('');
    }
  }

  async function bumpDepartment(sub: SchoolSubject, department: SubjectDepartment) {
    const a = getActiveSchool();
    if (!a || sub.department === department) return;
    await updateSubject(a.schoolId, { id: sub.id, department });
    setSubjects((cur) => cur.map((s) => (s.id === sub.id ? { ...s, department } : s)));
  }

  const grouped = useMemo(() => {
    const cls = classes.find((c) => c.id === activeClass);
    const relevant = subjects.filter((s) => cls && (s.level === cls.level || s.level === 'both'));
    const buckets: Record<string, SchoolSubject[]> = { core: [], art: [], science: [], commercial: [], general: [] };
    for (const s of relevant) {
      if (s.isCore) buckets.core.push(s);
      else if (s.department) buckets[s.department].push(s);
      else buckets.general.push(s);
    }
    return { cls, buckets };
  }, [classes, subjects, activeClass]);

  const classSubjectCount = (classId: string) => [...pairs].filter((p) => p.startsWith(`${classId}|`)).length;

  return (
    <SchoolShell title="School Setup">
      <SchoolHeading
        title="School Setup"
        sub="Identity, subjects and the class curriculum. Upload the logo first: it stamps every report card, the PIN checker and this portal."
      />

      <div className="grid gap-4">
        {/* -------------------------------------------------- identity */}
        <Card>
          <CardTitle hint="The logo shows on report cards and the public result checker. Keep it square for the crispest stamp.">
            School identity
          </CardTitle>
          <div className="grid gap-6 md:grid-cols-[auto_1fr]">
            <div className="flex flex-col items-center gap-3">
              <div className="flex h-28 w-28 items-center justify-center overflow-hidden rounded-2xl border border-outline-variant bg-surface-container">
                {logo ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={logo} alt="School logo" className="h-full w-full object-cover" />
                ) : (
                  <span className="material-symbols-outlined text-4xl text-on-surface-variant">school</span>
                )}
              </div>
              <input
                ref={fileRef}
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) onLogoFile(f);
                }}
              />
              <button className={btnSmall} onClick={() => fileRef.current?.click()}>
                <span className="material-symbols-outlined text-[16px]">upload</span>
                Upload logo
              </button>
              {logo && (
                <button className="text-xs text-on-surface-variant underline" onClick={() => setLogo('')}>
                  Remove
                </button>
              )}
            </div>
            <div className="grid gap-3">
              <label className="grid gap-1.5">
                <span className="text-sm font-medium text-on-surface">School name</span>
                <input className={inputCls} value={name} onChange={(e) => setName(e.target.value)} />
              </label>
              <label className="grid gap-1.5">
                <span className="text-sm font-medium text-on-surface">Address</span>
                <input className={inputCls} value={address} onChange={(e) => setAddress(e.target.value)} placeholder="Street, city, state" />
              </label>
              <div className="flex flex-wrap items-center gap-3">
                <button className={btnPrimary} disabled={savingProfile || !name.trim()} onClick={saveProfile}>
                  {savingProfile ? 'Saving…' : 'Save profile'}
                </button>
                {school?.schoolType && (
                  <span className="rounded-full border border-outline-variant px-3 py-1 text-xs text-on-surface-variant">
                    Type: {school.schoolType}
                  </span>
                )}
              </div>
              {profileNotice && <p className="text-sm text-on-surface">{profileNotice}</p>}
            </div>
          </div>
        </Card>

        {/* ------------------------------------------------- class subjects */}
        <Card>
          <CardTitle hint="Tick what each class offers. SSS classes compose from Core plus their Art / Science / Commercial tracks.">
            Subjects per class
          </CardTitle>
          <div className="grid gap-4 lg:grid-cols-[220px_1fr]">
            <div className="flex flex-wrap gap-2 lg:flex-col">
              {classes.map((c) => (
                <button
                  key={c.id}
                  onClick={() => setActiveClass(c.id)}
                  className={`flex items-center justify-between rounded-lg border px-3.5 py-2.5 text-sm transition-colors ${
                    activeClass === c.id
                      ? 'border-primary bg-primary text-on-primary'
                      : 'border-outline-variant text-on-surface hover:bg-surface-container'
                  }`}
                >
                  {c.name}
                  <span className={`ml-3 text-xs ${activeClass === c.id ? 'text-on-primary/70' : 'text-on-surface-variant'}`}>
                    {classSubjectCount(c.id)}
                  </span>
                </button>
              ))}
            </div>
            <div>
              {grouped.cls && grouped.cls.level === 'senior' && (
                <p className="mb-3 rounded-lg bg-surface-container px-4 py-2.5 text-[13px] text-on-surface-variant">
                  {grouped.cls.name} is a senior class: the core subjects apply to every student, then
                  each student offers their department. Set per-student tracks on the Students page.
                </p>
              )}
              <div className="grid gap-5 sm:grid-cols-2">
                {(['core', 'art', 'science', 'commercial', 'general'] as const)
                  .filter((k) => grouped.buckets[k].length > 0)
                  .map((k) => (
                    <div key={k}>
                      <p className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-on-surface-variant">
                        {k === 'general' ? 'General (no department)' : k}
                      </p>
                      <ul className="grid gap-1.5">
                        {grouped.buckets[k].map((s) => {
                          const key = `${activeClass}|${s.id}`;
                          const on = pairs.has(key);
                          return (
                            <li key={s.id}>
                              <button
                                disabled={pairBusy === key}
                                onClick={() => togglePair(activeClass, s)}
                                className={`flex w-full items-center gap-2.5 rounded-lg border px-3 py-2 text-left text-sm transition-colors ${
                                  on ? 'border-primary bg-primary text-on-primary' : 'border-outline-variant text-on-surface hover:bg-surface-container'
                                }`}
                              >
                                <span
                                  className={`flex h-5 w-5 items-center justify-center rounded border ${
                                    on ? 'border-on-primary' : 'border-outline-variant'
                                  }`}
                                >
                                  {on && <span className="material-symbols-outlined text-[13px] text-on-primary">check</span>}
                                </span>
                                <span className="flex-1">{s.name}</span>
                                {s.code && <span className="font-mono text-[11px] opacity-60">{s.code}</span>}
                              </button>
                            </li>
                          );
                        })}
                      </ul>
                    </div>
                  ))}
              </div>
            </div>
          </div>
        </Card>

        {/* --------------------------------------------- subject catalog */}
        <Card>
          <CardTitle hint="The NERDC catalog is pre-installed. Add anything your school teaches that is missing.">
            Subject catalog
          </CardTitle>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-6">
            <input className={inputCls + ' sm:col-span-2 lg:col-span-2'} placeholder="Subject name (e.g. Marketing)" value={subName} onChange={(e) => setSubName(e.target.value)} />
            <input className={inputCls} placeholder="Code (MKT)" value={subCode} onChange={(e) => setSubCode(e.target.value)} />
            <select className={selectCls} value={subLevel} onChange={(e) => setSubLevel(e.target.value)}>
              <option value="primary">Primary</option>
              <option value="junior">JSS</option>
              <option value="senior">SSS</option>
              <option value="both">All levels</option>
            </select>
            <select className={selectCls} value={subDept} onChange={(e) => setSubDept(e.target.value as SubjectDepartment)}>
              {DEPARTMENTS.map((d) => (
                <option key={d.key} value={d.key}>
                  {d.label === 'General' ? 'No department' : d.label}
                </option>
              ))}
            </select>
            <button className={btnPrimary + ' sm:col-span-2 lg:col-span-1'} disabled={subBusy || !subName.trim()} onClick={addSubject}>
              {subBusy ? 'Adding…' : 'Add subject'}
            </button>
          </div>
          <label className="mt-2 flex w-fit items-center gap-2 text-sm text-on-surface">
            <input type="checkbox" checked={subCore} onChange={(e) => setSubCore(e.target.checked)} className="h-4 w-4 accent-black" />
            Core subject (compulsory for every SSS student)
          </label>
          {subNotice && <p className="mt-2 text-sm text-on-surface">{subNotice}</p>}

          <div className="mt-5 overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead>
                <tr className="border-b border-outline-variant text-left text-xs uppercase tracking-wide text-on-surface-variant">
                  <th className="py-2 pr-3">Subject</th>
                  <th className="py-2 pr-3">Code</th>
                  <th className="py-2 pr-3">Level</th>
                  <th className="py-2">Department</th>
                </tr>
              </thead>
              <tbody>
                {subjects.map((s) => (
                  <tr key={s.id} className="border-b border-outline-variant/50 last:border-0">
                    <td className="py-2 pr-3 font-medium text-on-surface">
                      {s.name}
                      {s.isCore && (
                        <span className="ml-2 rounded-full border border-outline-variant px-2 py-0.5 text-[10px] uppercase tracking-wide text-on-surface-variant">
                          core
                        </span>
                      )}
                    </td>
                    <td className="py-2 pr-3 font-mono text-xs text-on-surface-variant">{s.code || '-'}</td>
                    <td className="py-2 pr-3 text-on-surface-variant">{s.level}</td>
                    <td className="py-2">
                      <select
                        aria-label={`Department for ${s.name}`}
                        className="h-8 rounded border border-outline-variant bg-surface-container-lowest px-2 text-xs text-on-surface"
                        value={s.department}
                        onChange={(e) => bumpDepartment(s, e.target.value as SubjectDepartment)}
                      >
                        {DEPARTMENTS.map((d) => (
                          <option key={d.key} value={d.key}>
                            {d.label === 'General' ? 'None' : d.label}
                          </option>
                        ))}
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </SchoolShell>
  );
}
