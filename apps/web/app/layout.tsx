import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Renance — the global student study OS',
    template: '%s · Renance',
  },
  description:
    'Register in seconds, set your exams, and Renance syncs past questions, notes and syllabi to your device — then grades your mock exams server-side on a goroutine engine.',
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    siteName: 'Renance',
    url: SITE_URL,
    title: 'Renance — the global student study OS',
    description:
      'Past questions, CBT mocks, spaced review and exam intelligence — purpose-built for JAMB, WAEC, NECO and university modules.',
  },
  twitter: { card: 'summary_large_image' },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        {/* Founder mockups load Inter + JetBrains Mono — kept as runtime
            links so `next build` stays hermetic (no font fetch at build). */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
