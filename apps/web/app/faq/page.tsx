import type { Metadata } from 'next';
import Link from 'next/link';

/**
 * /faq — the public answers page. Doubles as FAQPage structured data so
 * the questions can win rich results in search.
 */

export const dynamic = 'force-static';

import { SITE_URL } from '@/lib/site-url';

const QA: Array<{ q: string; a: string }> = [
  {
    q: 'What is Renance?',
    a: 'Renance is a study OS for students — mock CBT exams that are graded server-side, a spaced-repetition review plan built from every paper you take, voice flashcards, exam-focused lessons and a Socratic tutor that coaches you through the questions you got wrong. It works on Android, iOS, Windows, macOS and the web.',
  },
  {
    q: 'Who builds Renance?',
    a: 'Renance is built by Resolute Femi (Ariyo Oluwafemi Stephen), a Nigerian software engineer. The platform is designed for students preparing JAMB, WAEC, NECO and university module exams across Africa and beyond.',
  },
  {
    q: 'Is Renance free?',
    a: 'Yes. Creating an account takes seconds (username and password only), and practising, reviewing, flashcards and lessons are free.',
  },
  {
    q: 'How does grading work?',
    a: 'When you submit a paper, the Renance API grades it on the server with the same answer keys used to publish the questions — no browser tricks, no self-marking. Results, streaks, XP and badges follow immediately, and wrong topics enter your spaced-repetition queue automatically.',
  },
  {
    q: 'Can I study offline?',
    a: 'Yes. The mobile app downloads question packs, flashcard decks and lessons to your device, so you can practise and read on the bus or in a hostel with no data. Progress syncs when you reconnect.',
  },
  {
    q: 'What exams does Renance cover?',
    a: 'JAMB, WAEC and NECO syllabus topics plus university course modules. See the subjects page for the full coverage list, which grows with every content release.',
  },
  {
    q: 'What is the review queue?',
    a: 'Every question topic you get wrong is scheduled for spaced repetition using the SM-2 algorithm: it reappears just before you would forget it. Clear the queue daily and retention compounds.',
  },
  {
    q: 'How does the tutor work?',
    a: 'On any graded paper, tap "Ask the Tutor" on a question. The tutor coaches Socratically — it guides you to the reasoning instead of handing you the answer, using the question, your pick and the official explanation.',
  },
];

export const metadata: Metadata = {
  title: 'FAQ — Renance study OS',
  description:
    'How Renance works: free server-graded mock exams, spaced repetition, offline study, voice flashcards and the Socratic tutor — for JAMB, WAEC, NECO and university students.',
  alternates: { canonical: '/faq/' },
  openGraph: {
    title: 'FAQ · Renance study OS',
    description: 'How Renance works — grading, offline study, review queue, tutor and pricing.',
    url: `${SITE_URL}/faq/`,
  },
};

export default function FaqPage() {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: QA.map(({ q, a }) => ({
      '@type': 'Question',
      name: q,
      acceptedAnswer: { '@type': 'Answer', text: a },
    })),
  };
  return (
    <main className="mx-auto w-full max-w-2xl px-4 pb-20 pt-10 sm:px-6">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <h1 className="text-3xl font-bold tracking-tight text-on-surface sm:text-4xl">
        Frequently asked questions
      </h1>
      <div className="mt-8 space-y-3">
        {QA.map(({ q, a }) => (
          <details
            key={q}
            className="group rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
          >
            <summary className="cursor-pointer list-none text-[15px] font-semibold text-on-surface marker:hidden">
              <span className="mr-2 inline-block text-on-surface-variant transition group-open:rotate-90">
                ›
              </span>
              {q}
            </summary>
            <p className="mt-3 pl-5 text-[14px] leading-relaxed text-on-surface-variant">{a}</p>
          </details>
        ))}
      </div>
      <footer className="mt-10 text-center">
        <Link href="/register/" className="text-sm font-semibold text-on-surface underline">
          Create your free account →
        </Link>
      </footer>
    </main>
  );
}
