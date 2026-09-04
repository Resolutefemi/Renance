import type { Metadata } from 'next';
import Link from 'next/link';
import { loadLessons } from '@/lib/site-data';
import OpenAppButton from '@/components/open-app-button';
import { RenanceMark } from '@/components/renance-logo';

/**
 * The public landing page. This is the front door for search engines and
 * the SEO battle for the name "Renance" — everything above the fold is
 * static HTML with structured data in the root layout.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://resolutefemi.github.io/Renance';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  openGraph: { url: SITE_URL },
};

const FEATURES = [
  {
    icon: 'fact_check',
    title: 'Server-graded CBT papers',
    body: 'Every mock is marked on the server with the sealed answer keys — the same doctrine real exam bodies use. No browser tricks, no self-marking.',
  },
  {
    icon: 'event_repeat',
    title: 'Spaced review that plans itself',
    body: 'Topics you miss enter an SM-2 spaced-repetition queue and return exactly when you would forget them. Clear the queue, keep the knowledge.',
  },
  {
    icon: 'record_voice_over',
    title: 'Voice flashcards',
    body: 'Decks that read themselves aloud on your phone — drill while walking, cooking or commuting. Leitner-boxed so hard cards come back sooner.',
  },
  {
    icon: 'school',
    title: 'A tutor that teaches technique',
    body: 'Stuck on a question you got wrong? Ask the tutor. It coaches Socratically — guiding questions first, never just handing over the letter.',
  },
  {
    icon: 'battery_saver',
    title: 'Fatigue-aware sessions',
    body: 'Rence notices when your answer pace collapses and nudges you to take five — because tired practice teaches the wrong lessons.',
  },
  {
    icon: 'cloud_off',
    title: 'Offline-first, everywhere',
    body: 'Download packs, decks and lessons once; practise on the bus or in the hostel with zero data. Progress syncs when you reconnect.',
  },
];

export default function Landing() {
  const lessons = loadLessons().slice(0, 3);
  return (
    <div className="bg-background">
      {/* hero */}
      <main className="mx-auto w-full max-w-5xl px-4 sm:px-6">
        <section className="flex min-h-[78dvh] flex-col items-center justify-center py-16 text-center">
          <RenanceMark size={64} />
          <p className="mt-6 font-mono text-xs uppercase tracking-[0.25em] text-on-surface-variant">
            the global student study OS
          </p>
          <h1 className="mt-4 max-w-3xl text-4xl font-bold tracking-tight text-on-surface sm:text-5xl lg:text-6xl">
            Turn past questions into marks with{' '}
            <span className="underline decoration-accent-amber decoration-4 underline-offset-4">
              Renance
            </span>
          </h1>
          <p className="mt-5 max-w-2xl text-[15px] leading-relaxed text-on-surface-variant sm:text-lg">
            Mock CBT papers graded on the server, a review queue that plans itself,
            voice flashcards and an exam-technique tutor — built for JAMB, WAEC,
            NECO and university students. Free, on Android, iOS, Windows, macOS
            and the web.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <OpenAppButton className="inline-flex h-13 items-center justify-center rounded-[10px] bg-primary px-9 py-3.5 text-sm font-semibold text-on-primary transition hover:opacity-90" />
            <Link
              href="/lessons/"
              className="inline-flex h-13 items-center justify-center rounded-[10px] bg-surface-container-high px-9 py-3.5 text-sm font-semibold text-on-surface transition hover:opacity-90"
            >
              Browse lessons
            </Link>
          </div>
          <p className="mt-4 font-mono text-xs text-on-surface-variant">
            username + password only · no email required
          </p>
        </section>

        {/* features */}
        <section className="pb-16">
          <h2 className="text-center text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
            Everything a serious candidate needs
          </h2>
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <article
                key={f.title}
                className="rounded-xl bg-card p-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
              >
                <span className="material-symbols-outlined text-3xl text-[#7C3AED]">{f.icon}</span>
                <h3 className="mt-3 text-[15px] font-bold text-on-surface">{f.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-on-surface-variant">{f.body}</p>
              </article>
            ))}
          </div>
        </section>

        {/* coverage strip */}
        <section className="rounded-xl bg-dark-surface p-8 text-center sm:p-10">
          <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
            Mapped to the syllabus, topic by topic
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-sm leading-relaxed text-white/70">
            Every paper, flashcard deck and lesson is tagged to the official topic
            tree — so the app always knows what you know, what you missed, and
            what to drill next.
          </p>
          <div className="mt-6 flex flex-wrap items-center justify-center gap-2.5">
            {['JAMB', 'WAEC', 'NECO', 'University Modules'].map((b) => (
              <span
                key={b}
                className="rounded-full bg-white/10 px-4 py-1.5 text-sm font-medium text-white"
              >
                {b}
              </span>
            ))}
          </div>
          <Link
            href="/subjects/"
            className="mt-6 inline-block text-sm font-semibold text-[#C4B5FD] underline underline-offset-4 hover:text-white"
          >
            See the full subject coverage →
          </Link>
        </section>

        {/* lessons preview */}
        {lessons.length > 0 && (
          <section className="py-16">
            <div className="flex items-baseline justify-between gap-3">
              <h2 className="text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
                Start reading free
              </h2>
              <Link href="/lessons/" className="text-sm font-semibold text-on-surface-variant hover:text-on-surface">
                All lessons →
              </Link>
            </div>
            <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {lessons.map((les) => (
                <Link
                  key={les.slug}
                  href={`/lessons/${les.slug}/`}
                  className="group flex flex-col rounded-xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
                >
                  {les.subject && (
                    <span className="w-fit rounded-full bg-selection-blue px-2.5 py-0.5 text-[11px] font-medium text-on-surface">
                      {les.subject}
                    </span>
                  )}
                  <h3 className="mt-3 text-[15px] font-semibold leading-snug text-on-surface group-hover:underline">
                    {les.title}
                  </h3>
                  <p className="mt-2 line-clamp-2 text-[13px] leading-relaxed text-on-surface-variant">
                    {les.summary}
                  </p>
                  <span className="mt-auto pt-3 font-mono text-xs text-on-surface-variant">
                    {les.minutes} min read →
                  </span>
                </Link>
              ))}
            </div>
          </section>
        )}
      </main>

      {/* footer */}
      <footer className="border-t border-surface-container-high bg-surface-container-low">
        <div className="mx-auto grid w-full max-w-5xl grid-cols-2 gap-8 px-4 py-10 sm:grid-cols-4 sm:px-6">
          <div className="col-span-2 sm:col-span-1">
            <RenanceMark size={28} />
            <p className="mt-3 text-xs leading-relaxed text-on-surface-variant">
              The global student study OS. Built by Resolute Femi (Ariyo Oluwafemi Stephen).
            </p>
          </div>
          <nav aria-label="Study">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">Study</h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li><Link href="/lessons/" className="hover:underline">Lessons</Link></li>
              <li><Link href="/subjects/" className="hover:underline">Subjects &amp; syllabus</Link></li>
              <li><Link href="/flashcards/" className="hover:underline">Flashcards</Link></li>
            </ul>
          </nav>
          <nav aria-label="Product">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">Product</h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li><Link href="/register/" className="hover:underline">Create account</Link></li>
              <li><Link href="/login/" className="hover:underline">Sign in</Link></li>
              <li><Link href="/faq/" className="hover:underline">FAQ</Link></li>
            </ul>
          </nav>
          <nav aria-label="Company">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">Company</h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li><a href="https://github.com/Resolutefemi/Renance" className="hover:underline" rel="noopener">GitHub</a></li>
              <li><a href="https://renance-api.onrender.com/healthz" className="hover:underline" rel="noopener">Service status</a></li>
            </ul>
          </nav>
        </div>
        <p className="pb-8 text-center font-mono text-xs text-on-surface-variant">
          © {new Date().getFullYear()} Renance · built for students, free forever
        </p>
      </footer>
    </div>
  );
}
