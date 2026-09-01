'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getToken } from '@/lib/session';
import { RenanceMark } from '@/components/renance-logo';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    const t = setTimeout(() => {
      router.replace(getToken() ? '/dashboard' : '/register');
    }, 600);
    return () => clearTimeout(t);
  }, [router]);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6">
      <RenanceMark size={72} state="busy" />
      <p className="text-sm text-neutral-500">the global student study OS</p>
    </main>
  );
}
