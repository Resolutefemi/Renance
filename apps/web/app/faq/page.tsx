import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import Link from 'next/link';

/**
 * /faq, the public answers page. Doubles as FAQPage structured data so
 * the questions can win rich results in search.
 */

export const dynamic = 'force-static';

import { SITE_URL } from '@/lib/site-url';

const QA: Array<{ q: string; a: string }> = [
  {
    q: 'What is Renance?',
    a: "Renance is Nigeria's exam-prep app: mock CBT exams for JAMB, WAEC, NECO and Post-UTME that are graded server-side, a spaced-repetition review queue built from every paper you take, and full university semester desks where students learn and quiz course by course. It works on Android and on the web at renance.app.",
  },
  {
    q: 'Who builds Renance?',
    a: 'Renance is built by Resolute Femi (Ariyo Oluwafemi Stephen), a Nigerian software engineering undergraduate in 200 level of Software Engineering at the Federal University of Technology, Akure (FUTA). Read the full story at renance.app/about.',
  },
  {
    q: 'Is Renance free?',
    a: 'Yes. Creating an account takes seconds, and practising, lessons, reviewing, quests, the leaderboards and the feed are free. Optional paid plans add higher paper limits for heavy exam seasons.',
  },
  {
    q: 'What are diamonds and how do I earn them?',
    a: 'Diamonds are the Renance currency. You earn them from daily and weekly quests, unit chests, first clears, perfect scores, and every friend who joins with your referral code adds 100 more. Spend them in the Shop.',
  },
  {
    q: 'What are Streak Freezes?',
    a: 'A Streak Freeze auto-saves a missed day so your streak survives a busy day. Each one costs 200 diamonds, you can hold up to 2 at a time, and your freezes show in blue next to your streak. Buy them in the Shop before you need them.',
  },
  {
    q: 'Which exams does Renance cover?',
    a: 'JAMB UTME past questions and the full JAMB MOCK (the official 4-subject, 60-question-per-subject simulation scored over 400), WAEC/WASSCE, NECO, Post-UTME packs arranged by school, and university semester desks for tertiary students.',
  },
  {
    q: 'How does course selection work?',
    a: 'Tertiary students pick their institution kind and department, and the desk lines up the national general courses plus everything in their department. Beyond that, the whole catalogue is borrowable: other departments\u2019 courses sit under your shelves, 100 at a time.',
  },
  {
    q: 'How is my performance tracked?',
    a: 'Every graded paper feeds your subject mastery: the Performance Analysis page aggregates your six most recent marked papers into per-subject score bars, trends and pacing, so you always know which topics to attack next.',
  },
  {
    q: 'What are corrections?',
    a: 'After every graded paper the review opens your corrections: each subject becomes a pill, and inside you get the options you picked, the correct answers, the worked explanations and an AI explanation on any question you missed.',
  },
  {
    q: 'What is the feed for?',
    a: 'The feed is where Renance celebrates you: completed units, streaks, scores and league moves post automatically, and you can share your own moments from the result screen or after finishing units. Followers can like, comment and view your profile.',
  },
  {
    q: 'How do quests work?',
    a: 'Quests are daily and weekly diamond missions: answer a number of questions, finish units, keep the streak alive. Each completed mission pays diamonds straight into your wallet.',
  },
  {
    q: 'Which leaderboards can I compete on?',
    a: 'Six boards: JAMB, WAEC, NECO, Streak, Diamonds and the Daily Challenge. Every row is tappable - open any name to view their public profile, streak and courses, and follow them straight from there.',
  },
  {
    q: 'What are leagues?',
    a: 'Leagues are the weekly XP competition: every student who studies during the week is ranked inside a tier, from Bronze up to the legendary tiers, with a promotion zone at the top and a demotion line at the bottom. The board resets every Monday (Lagos time) - top the promotion zone to climb.',
  },
  {
    q: 'Does Renance remind me to study?',
    a: 'Yes. Turn on notifications and Renance drops one streak reminder a day - a different voice line each day, spoken aloud on your phone, so the chain never breaks quietly. You can flip reminders off any time in Settings.',
  },
  {
    q: 'Can I study offline?',
    a: 'Yes. Question packs download as offline packs, so practice, marking and lessons keep working through network drops. Your results sync the moment connectivity returns.',
  },
  {
    q: 'How do I reach support?',
    a: 'Join our WhatsApp channel for announcements and quick help, or message management directly on +234 916 763 6685. The team reads and replies.',
  },
];

export const metadata: Metadata = {
  title: "FAQ - Nigeria's Educational App",
  description:
    'How Renance works: free server-graded mock exams, diamonds, streak freezes, quests, leaderboards, corrections, offline packs and support, for JAMB, WAEC, NECO, Post-UTME and university students.',
  alternates: { canonical: '/faq/' },
  openGraph: {
    title: 'FAQ - how Renance works',
    description: 'How Renance works: exams covered, diamonds, streak freezes, quests, leaderboards, corrections, the feed and support.',
    url: `${SITE_URL}/faq/`,
    images: [...OG_IMAGES],
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
