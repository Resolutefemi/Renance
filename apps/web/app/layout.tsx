import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://renance.vercel.app';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Renance — Modular platform for African education & commerce',
    template: '%s · Renance',
  },
  description:
    'Renance is a modular platform for CBT exams, school results, SME tools, skills, utilities and payroll — one core, purpose-built for African businesses and schools.',
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    siteName: 'Renance',
    url: SITE_URL,
    title: 'Renance — Modular platform for African education & commerce',
    description:
      'CBT exams, school results, SME tools, skills, utilities and payroll on one modular platform.',
  },
  twitter: { card: 'summary_large_image' },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
