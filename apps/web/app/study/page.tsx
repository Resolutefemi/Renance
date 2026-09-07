'use client';

/**
 * Study — the PDF & resources shelf.
 *
 * One small icon on the desk (same size as the Exams icon) opens this
 * page: free, legal, downloadable study material for secondary and
 * university students — official syllabi, open textbooks, past-question
 * archives and curated open collections. Every link is external and
 * opens in a new tab; Renance itself stays the practice layer.
 */

import { useState } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';

interface Resource {
  name: string;
  desc: string;
  url: string;
  tag: 'PDF' | 'Web' | 'Repo';
}

interface Category {
  title: string;
  icon: string;
  items: Resource[];
}

const CATEGORIES: Category[] = [
  {
    title: 'Official syllabi & exam bodies',
    icon: 'gavel',
    items: [
      {
        name: 'JAMB IBASS',
        desc: 'The official UTME brochure and subject syllabus, straight from the exam body.',
        url: 'https://ibass.jamb.gov.ng',
        tag: 'Web',
      },
      {
        name: 'WAEC e-learning portal',
        desc: 'Free WASSCE past questions and Chief Examiner reports for every subject, by year.',
        url: 'https://waeconline.org.ng/e-learning/',
        tag: 'PDF',
      },
      {
        name: 'WAEC Nigeria',
        desc: 'Official timetables, regulations and exam notices for WASSCE candidates.',
        url: 'https://www.waecnigeria.org',
        tag: 'Web',
      },
      {
        name: 'NECO',
        desc: 'Official NECO timetables, syllabuses and candidate information.',
        url: 'https://www.neco.gov.ng',
        tag: 'Web',
      },
    ],
  },
  {
    title: 'Free textbooks (PDF)',
    icon: 'picture_as_pdf',
    items: [
      {
        name: 'OpenStax — Biology 2e',
        desc: 'Full university-standard biology textbook, free PDF, covers every WAEC/NECO bio topic.',
        url: 'https://openstax.org/details/books/biology-2e',
        tag: 'PDF',
      },
      {
        name: 'OpenStax — Chemistry 2e',
        desc: 'Complete chemistry text with worked examples and end-of-chapter drills.',
        url: 'https://openstax.org/details/books/chemistry-2e',
        tag: 'PDF',
      },
      {
        name: 'OpenStax — College Physics',
        desc: 'Algebra-based physics that maps cleanly onto the SS1-SS3 syllabus.',
        url: 'https://openstax.org/details/books/college-physics',
        tag: 'PDF',
      },
      {
        name: 'OpenStax — Precalculus',
        desc: 'Numbers, algebra, trigonometry and functions — the engine room of UTME maths.',
        url: 'https://openstax.org/details/books/precalculus',
        tag: 'PDF',
      },
      {
        name: 'LibreTexts',
        desc: 'A giant open library of course texts and problem sets across all science subjects.',
        url: 'https://libretexts.org',
        tag: 'Web',
      },
      {
        name: 'Open Textbook Library',
        desc: 'Hundreds of openly licensed textbooks, searchable by subject, downloadable as PDF.',
        url: 'https://open.umn.edu/opentextbooks',
        tag: 'PDF',
      },
      {
        name: 'Directory of Open Access Books',
        desc: 'Academic-grade open books — strong for economics, government and literature.',
        url: 'https://doabooks.org',
        tag: 'PDF',
      },
    ],
  },
  {
    title: 'Reading & set texts',
    icon: 'auto_stories',
    items: [
      {
        name: 'Project Gutenberg',
        desc: '70,000+ free classics — most literature set texts live here as free eBooks.',
        url: 'https://www.gutenberg.org',
        tag: 'PDF',
      },
      {
        name: 'African Storybook',
        desc: 'Open African stories and readers in dozens of languages, printable as PDFs.',
        url: 'https://africanstorybook.org',
        tag: 'PDF',
      },
    ],
  },
  {
    title: 'Computer studies & coding',
    icon: 'code',
    items: [
      {
        name: 'freeCodeCamp',
        desc: 'Free full curriculum for web development, data analysis and more, with certificates.',
        url: 'https://www.freecodecamp.org',
        tag: 'Web',
      },
      {
        name: 'free-programming-books',
        desc: 'The legendary GitHub list of free programming books and notes in many languages.',
        url: 'https://github.com/EbookFoundation/free-programming-books',
        tag: 'Repo',
      },
      {
        name: 'OSSU Computer Science',
        desc: 'A complete free CS degree, course by course, with a community to keep you honest.',
        url: 'https://github.com/ossu/computer-science',
        tag: 'Repo',
      },
      {
        name: 'Teach Yourself CS',
        desc: 'Nine subjects that make a computer scientist, with the exact free book for each.',
        url: 'https://teachyourselfcs.com',
        tag: 'Web',
      },
    ],
  },
  {
    title: 'Curated collections',
    icon: 'collections_bookmark',
    items: [
      {
        name: 'All-Resources by Resolute Femi',
        desc: '300 hand-picked open educational repositories from across the globe — textbooks, notes, past questions.',
        url: 'https://github.com/Resolutefemi/All-Resources',
        tag: 'Repo',
      },
    ],
  },
];

const TAG_STYLES: Record<Resource['tag'], string> = {
  PDF: 'bg-error-container text-on-error-container',
  Web: 'bg-selection-blue text-on-surface',
  Repo: 'bg-surface-container-high text-on-surface',
};

export default function StudyPage() {
  const [open, setOpen] = useState<string | null>(CATEGORIES[0]?.title ?? null);

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16">
      <PageBar title="Study" />

      <div className="mx-auto w-full max-w-2xl px-4 pb-8 pt-2 sm:px-6">
        <h1 className="text-[28px] font-bold leading-9 tracking-[-0.02em] text-on-surface">
          Study resources
        </h1>
        <p className="mt-1 text-[15px] font-medium text-on-surface-variant">
          Free PDFs, textbooks and archives for your exam — all legal, all open, all free.
        </p>

        <div className="mt-6 flex flex-col gap-3">
          {CATEGORIES.map((cat) => {
            const isOpen = open === cat.title;
            return (
              <section
                key={cat.title}
                className="overflow-hidden rounded-[12px] bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]"
              >
                <button
                  onClick={() => setOpen(isOpen ? null : cat.title)}
                  className="flex w-full items-center gap-3 p-4 text-left"
                  aria-expanded={isOpen}
                >
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] bg-surface-container-high text-on-surface">
                    <span className="material-symbols-outlined text-[22px]">{cat.icon}</span>
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[15px] font-semibold text-on-surface">{cat.title}</span>
                    <span className="mt-0.5 block font-mono text-[12px] text-on-surface-variant">
                      {cat.items.length} resources
                    </span>
                  </span>
                  <span
                    className={`material-symbols-outlined text-[20px] text-outline transition-transform ${isOpen ? 'rotate-180' : ''}`}
                  >
                    expand_more
                  </span>
                </button>

                {isOpen && (
                  <ul className="border-t border-outline-variant/40 px-4 pb-2 pt-1">
                    {cat.items.map((r) => (
                      <li key={r.name} className="border-b border-outline-variant/20 last:border-0">
                        <a
                          href={r.url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-start gap-3 py-3"
                        >
                          <span className="mt-0.5 min-w-0 flex-1">
                            <span className="flex flex-wrap items-center gap-2">
                              <span className="text-[14px] font-semibold text-on-surface">{r.name}</span>
                              <span
                                className={`rounded-full px-2 py-0.5 font-mono text-[10px] font-medium ${TAG_STYLES[r.tag]}`}
                              >
                                {r.tag}
                              </span>
                            </span>
                            <span className="mt-1 block text-[13px] leading-relaxed text-on-surface-variant">
                              {r.desc}
                            </span>
                          </span>
                          <span className="material-symbols-outlined mt-1 shrink-0 text-[18px] text-outline">
                            open_in_new
                          </span>
                        </a>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            );
          })}
        </div>

        <p className="mt-6 rounded-[12px] bg-surface-container-low p-4 text-[13px] leading-relaxed text-on-surface-variant">
          Practice stays here: pair any of these texts with the question banks,
          mocks and spaced review in the app — reading gets the concepts in,
          past questions make them stick.
        </p>
      </div>

      <BottomNav />
    </main>
  );
}
