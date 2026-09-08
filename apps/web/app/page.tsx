import type { Metadata } from 'next';
import Link from 'next/link';
import { loadLessons, loadManifest } from '@/lib/site-data';
import OpenAppButton from '@/components/open-app-button';
import { RenanceMark } from '@/components/renance-logo';

/**
 * The public landing page. This is the front door for search engines and
 * the SEO battle for the name "Renance", everything above the fold is
 * static HTML with structured data in the root layout. Numbers on the
 * page are baked from the committed manifest at build time, so the copy
 * can never drift from the real archive.
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
    body: 'Every mock is marked on the server with the sealed answer keys, the same doctrine real exam bodies use. No browser tricks, no self-marking — your score is honest even when the network drops.',
  },
  {
    icon: 'event_repeat',
    title: 'Spaced review that plans itself',
    body: 'Topics you miss enter an SM-2 spaced-repetition queue and return exactly when you would forget them. Clear the queue, keep the knowledge — no planner to maintain.',
  },
  {
    icon: 'record_voice_over',
    title: 'Voice flashcards',
    body: 'Decks that read themselves aloud on your phone, drill while walking, cooking or commuting. Leitner-boxed so hard cards come back sooner and easy ones fade away.',
  },
  {
    icon: 'auto_stories',
    title: 'The JAMB novel, question by question',
    body: 'The Lekki Headmaster ships as an opt-in question set inside every Use of English mock — switch it on when you are ready, exactly like the hall asks.',
  },
  {
    icon: 'battery_saver',
    title: 'Fatigue-aware sessions',
    body: 'Renance notices when your answer pace collapses and nudges you to take five, because tired practice teaches the wrong lessons.',
  },
  {
    icon: 'cloud_off',
    title: 'Offline-first, everywhere',
    body: 'Download packs, decks and lessons once; practise on the bus or in the hostel with zero data. Progress syncs when you reconnect.',
  },
];

const STEPS = [
  {
    icon: 'how_to_reg',
    title: 'Register in 10 seconds',
    body: 'Username and password only — no email, no data bundle wasted on forms. Set your target exam and year, and your desk is ready.',
  },
  {
    icon: 'tune',
    title: 'Set the paper your way',
    body: 'Pick subjects, pin a particular year or go fully random, size the English section, decide on passages and the novel, or carve a custom practice set.',
  },
  {
    icon: 'military_tech',
    title: 'Sit, grade, review, rise',
    body: 'Sit under real CBT rules, get graded server-side in seconds, walk the topic breakdown, and let the review queue schedule your comeback.',
  },
];

function fmt(n: number): string {
  return n.toLocaleString('en-US');
}

export default function Landing() {
  const lessons = loadLessons().slice(0, 3);
  const manifest = loadManifest();
  const exams = manifest?.exams ?? [];
  const totalQuestions = exams.reduce((s, e) => s + (e.questionCount ?? 0), 0);
  const allYears = exams.flatMap((e) => e.years ?? []);
  const yearFrom = allYears.length ? Math.min(...allYears) : 1978;
  const yearTo = allYears.length ? Math.max(...allYears) : new Date().getFullYear();
  const byBody = (body: string) => exams.filter((e) => e.body === body);
  const jambExams = byBody('JAMB');
  const waecExams = byBody('WAEC');
  const necoExams = byBody('NECO');
  const sum = (list: typeof exams) => list.reduce((s, e) => s + (e.questionCount ?? 0), 0);

  return (
    <div className="bg-background">
      <main className="mx-auto w-full max-w-5xl px-4 sm:px-6">
        {/* hero */}
        <section className="flex min-h-[80dvh] flex-col items-center justify-center py-16 text-center">
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
            {fmt(totalQuestions)}+ real past questions from {yearFrom} to {yearTo}, CBT mocks graded
            on the server, a review queue that plans itself, voice flashcards and the JAMB novel
            built in — for JAMB, WAEC, NECO and university students. Free, on Android, iOS, Windows,
            macOS and the web.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
            <OpenAppButton className="inline-flex h-13 items-center justify-center rounded-[10px] bg-primary px-9 py-3.5 text-sm font-semibold text-on-primary transition hover:opacity-90" />
            <Link
              href="/subjects/"
              className="inline-flex h-13 items-center justify-center rounded-[10px] bg-surface-container-high px-9 py-3.5 text-sm font-semibold text-on-surface transition hover:opacity-90"
            >
              Browse {exams.length} question packs
            </Link>
          </div>
          <p className="mt-4 font-mono text-xs text-on-surface-variant">
            username + password only · no email required
          </p>

          {/* live stats strip — baked from the manifest at build time */}
          <dl className="mt-12 grid w-full max-w-3xl grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { k: 'Past questions', v: `${fmt(totalQuestions)}+` },
              { k: 'Exam packs', v: String(exams.length) },
              { k: 'Years covered', v: `${yearFrom}–${yearTo}` },
              { k: 'Exam bodies', v: 'JAMB · WAEC · NECO' },
            ].map((s) => (
              <div
                key={s.k}
                className="rounded-xl bg-card px-4 py-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
              >
                <dd className="text-lg font-bold tracking-tight text-on-surface sm:text-xl">{s.v}</dd>
                <dt className="mt-1 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">
                  {s.k}
                </dt>
              </div>
            ))}
          </dl>
        </section>

        {/* coverage — the archive, by body */}
        <section className="pb-4">
          <div className="rounded-2xl bg-dark-surface p-6 sm:p-10">
            <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-end">
              <div>
                <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
                  The archive is the product
                </h2>
                <p className="mt-2 max-w-xl text-sm leading-relaxed text-white/70">
                  Every pack carries the year it was sat, the options, the sealed answer key and the
                  worked explanation — harvested, cleaned and organised so you practise the real
                  thing, not a paraphrase.
                </p>
              </div>
              <Link
                href="/subjects/"
                className="shrink-0 text-sm font-semibold text-white underline underline-offset-4 hover:text-white/80"
              >
                See full subject coverage →
              </Link>
            </div>
            <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
              {[
                { body: 'JAMB (UTME)', count: sum(jambExams), packs: jambExams.length, note: '1978–2025 · all subjects · novel included' },
                { body: 'WAEC', count: sum(waecExams), packs: waecExams.length, note: 'objectives + theory with model answers' },
                { body: 'NECO', count: sum(necoExams), packs: necoExams.length, note: 'objectives + theory packs' },
              ].map((b) => (
                <div key={b.body} className="rounded-xl bg-white/5 p-5 ring-1 ring-white/10">
                  <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-white/60">{b.body}</p>
                  <p className="mt-2 text-2xl font-bold text-white">{fmt(b.count)}</p>
                  <p className="mt-0.5 text-xs text-white/60">
                    questions · {b.packs} packs · {b.note}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* features */}
        <section className="py-14">
          <h2 className="text-center text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
            Everything a serious candidate needs
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-center text-[15px] leading-relaxed text-on-surface-variant">
            Not a quiz bank with ads glued on — a complete study operating system that remembers
            what you missed and schedules the fix.
          </p>
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((f) => (
              <article
                key={f.title}
                className="rounded-xl bg-card p-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]"
              >
                <span className="material-symbols-outlined text-3xl text-accent-ink">{f.icon}</span>
                <h3 className="mt-3 text-[15px] font-bold text-on-surface">{f.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-on-surface-variant">{f.body}</p>
              </article>
            ))}
          </div>
        </section>

        {/* how it works */}
        <section className="pb-14">
          <h2 className="text-center text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
            Three steps from panic to pass mark
          </h2>
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
            {STEPS.map((s, i) => (
              <article key={s.title} className="relative rounded-xl bg-card p-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
                <span className="absolute right-5 top-5 font-mono text-3xl font-bold text-surface-container-high">
                  {i + 1}
                </span>
                <span className="material-symbols-outlined text-3xl text-accent-ink">{s.icon}</span>
                <h3 className="mt-3 pr-8 text-[15px] font-bold text-on-surface">{s.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-on-surface-variant">{s.body}</p>
              </article>
            ))}
          </div>
        </section>

        {/* exam-day fidelity band */}
        <section className="pb-14">
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <div className="rounded-2xl bg-card p-6 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-8">
              <span className="material-symbols-outlined text-3xl text-accent-ink">desktop_windows</span>
              <h3 className="mt-3 text-lg font-bold tracking-tight text-on-surface">
                A CBT hall on every screen
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-on-surface-variant">
                The player mirrors the real JAMB software: a live question map, flag-and-return,
                answers that lock in exam mode, a hall-approved calculator, auto-submit at zero —
                and a keyboard-first desktop layout (A–F to pick, arrows to move) so laptop
                candidates train the way they will sit.
              </p>
              <ul className="mt-4 space-y-1.5 text-[13px] text-on-surface-variant">
                <li className="flex items-center gap-2">
                  <span className="material-symbols-outlined text-[16px] text-accent-emerald">check_circle</span>
                  Pause &amp; resume with an honest clock
                </li>
                <li className="flex items-center gap-2">
                  <span className="material-symbols-outlined text-[16px] text-accent-emerald">check_circle</span>
                  Topic breakdown after every paper
                </li>
                <li className="flex items-center gap-2">
                  <span className="material-symbols-outlined text-[16px] text-accent-emerald">check_circle</span>
                  Worked explanations on every review
                </li>
              </ul>
            </div>
            <div className="rounded-2xl bg-accent-ink p-6 text-white shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] sm:p-8">
              <span className="material-symbols-outlined text-3xl text-accent-amber">auto_stories</span>
              <h3 className="mt-3 text-lg font-bold tracking-tight">Reading “The Lekki Headmaster”?</h3>
              <p className="mt-2 text-sm leading-relaxed text-white/75">
                JAMB&apos;s recommended text ships inside Renance as a proper question set — fifty
                questions across all twelve chapters, each with the sealed answer and a worked
                explanation. Switch it on in Mock Setup when you are ready; leave it off while you
                are still reading.
              </p>
              <p className="mt-4 font-mono text-[11px] uppercase tracking-[0.2em] text-white/50">
                Kabir Alabi Garba · UTME Use of English
              </p>
            </div>
          </div>
        </section>

        {/* lessons preview */}
        {lessons.length > 0 && (
          <section className="pb-16">
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

        {/* closing CTA */}
        <section className="pb-16">
          <div className="rounded-2xl bg-surface-container-high px-6 py-10 text-center sm:px-10">
            <h2 className="text-2xl font-bold tracking-tight text-on-surface sm:text-3xl">
              Your competition started revising yesterday.
            </h2>
            <p className="mx-auto mt-3 max-w-lg text-[15px] leading-relaxed text-on-surface-variant">
              Create a free account and sit your first server-graded paper in the next two minutes —
              {fmt(totalQuestions)}+ past questions are waiting.
            </p>
            <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
              <Link
                href="/register/"
                className="inline-flex h-13 items-center justify-center rounded-[10px] bg-primary px-9 py-3.5 text-sm font-semibold text-on-primary transition hover:opacity-90"
              >
                Create free account
              </Link>
              <OpenAppButton className="inline-flex h-13 items-center justify-center rounded-[10px] bg-card px-9 py-3.5 text-sm font-semibold text-on-surface shadow-[inset_0_0_0_1px_#C6C6CD] transition hover:opacity-90" />
            </div>
          </div>
        </section>
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
              <li><Link href="/packs/" className="hover:underline">Question packs</Link></li>
            </ul>
          </nav>
          <nav aria-label="Product">
            <h3 className="font-mono text-xs uppercase tracking-widest text-on-surface-variant">Product</h3>
            <ul className="mt-3 space-y-2 text-sm text-on-surface">
              <li><Link href="/register/" className="hover:underline">Create account</Link></li>
              <li><Link href="/login/" className="hover:underline">Sign in</Link></li>
              <li><Link href="/exams/setup/" className="hover:underline">Mock exam setup</Link></li>
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
