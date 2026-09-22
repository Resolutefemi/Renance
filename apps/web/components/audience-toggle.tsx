'use client';

// The For Students / For Schools segmented control shared by the login
// and register screens. Students stay the default — everything Renance
// has shipped so far lives on that side — while schools is the new
// management + teacher world.

import Link from 'next/link';

export type Audience = 'students' | 'schools';

export function AudienceToggle({
  audience,
  onChange,
  mode,
}: {
  audience: Audience;
  onChange: (a: Audience) => void;
  mode: 'login' | 'register';
}) {
  const seg = (active: boolean) =>
    `flex-1 rounded-full py-2.5 text-sm font-medium transition-all ${
      active ? 'bg-primary text-on-primary shadow' : 'text-on-surface-variant hover:text-on-surface'
    }`;

  return (
    <div className="flex flex-col items-center gap-4">
      <div
        role="tablist"
        aria-label="Account type"
        className="flex w-full items-center rounded-full bg-surface-container p-1"
      >
        <button
          type="button"
          role="tab"
          aria-selected={audience === 'students'}
          onClick={() => onChange('students')}
          className={seg(audience === 'students')}
        >
          For Students
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={audience === 'schools'}
          onClick={() => onChange('schools')}
          className={seg(audience === 'schools')}
        >
          For Schools
        </button>
      </div>
      {audience === 'schools' && (
        <p className="text-center text-xs text-on-surface-variant">
          {mode === 'register'
            ? 'Create your school workspace with management + teacher accounts, syllabuses, notes and results.'
            : 'Management and teachers: sign in with your school email to open the school workspace.'}
          {' '}
          <Link href={mode === 'register' ? '/register' : '/school/check'} className="font-medium text-primary underline-offset-4 hover:underline">
            {mode === 'register' ? '' : 'Check a result'}
          </Link>
        </p>
      )}
    </div>
  );
}
