'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getToken } from '@/lib/session';

/**
 * Landing CTA that respects an existing session: signed-in students go
 * straight to their dashboard, everyone else to registration.
 */
export default function OpenAppButton({ className }: { className?: string }) {
  const router = useRouter();
  const [target, setTarget] = useState<string | null>(null);

  useEffect(() => {
    setTarget(getToken() ? '/dashboard' : '/register');
  }, []);

  return (
    <button
      onClick={() => target && router.push(target)}
      disabled={!target}
      className={className}
    >
      {target === '/dashboard' ? 'Open the app' : 'Start free'}
    </button>
  );
}
