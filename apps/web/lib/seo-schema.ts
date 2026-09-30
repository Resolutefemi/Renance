/**
 * @file apps/web/lib/seo-schema.ts
 *
 * Phase 1 - Automated JSON-LD Schema Generator for Renance Programmatic SEO.
 *
 * Pure TypeScript - no `fs` calls, no Node APIs. Safe to import from both
 * Server Components and Server Actions. Do NOT add 'use client' here.
 *
 * Exports:
 *   buildQuizSchema()        → SchemaOrgQuiz         (schema.org/Quiz)
 *   buildBreadcrumbSchema()  → SchemaOrgBreadcrumbList
 *   buildCourseSchema()      → Record<string, unknown> (schema.org/Course)
 *   buildFAQSchema()         → Record<string, unknown> (schema.org/FAQPage)
 *   serializeJsonLd()        → string (for <script type="application/ld+json">)
 */

import type {
  SchemaOrgAnswer,
  SchemaOrgBreadcrumbList,
  SchemaOrgQuestion,
  SchemaOrgQuiz,
  SEOCurriculumScheme,
  SEOExamPaperSummary,
  SEOSampleQuestion,
} from './seo-types';

// ─── Quiz Schema (schema.org/Quiz) ────────────────────────────────────────────

/**
 * Builds a fully compliant `schema.org/Quiz` JSON-LD object from a
 * {@link SEOExamPaperSummary}. Embeds up to 5 `Question` nodes with
 * `acceptedAnswer` and optional explanation comments.
 *
 * Paste the result into a `<script type="application/ld+json">` tag to
 * unlock Google's "Practice problems" / AI Overview rich results.
 *
 * @example
 *   const schema = buildQuizSchema(paper);
 *   // → inject via: <script dangerouslySetInnerHTML={{ __html: serializeJsonLd(schema) }} />
 */
export function buildQuizSchema(paper: SEOExamPaperSummary): SchemaOrgQuiz {
  return {
    '@context': 'https://schema.org',
    '@type': 'Quiz',
    name: `${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} Past Questions`,
    description: `Practice ${paper.totalQuestions} real ${paper.bodyTitle} ${paper.subjectTitle} past questions from ${paper.year}. ` +
      `Full explanations included. Free on Renance - Nigeria's largest exam prep platform.`,
    educationalLevel: educationalLevelFor(paper.body),
    about: {
      '@type': 'Thing',
      name: `${paper.subjectTitle} (${paper.bodyTitle} ${paper.year})`,
    },
    hasPart: paper.sampleQuestions.map(buildQuestionNode),
  };
}

/** Maps an exam body slug to a schema.org educational level string. */
function educationalLevelFor(body: SEOExamPaperSummary['body']): string {
  switch (body) {
    case 'jamb':
      return 'HighSchool'; // JAMB is pre-tertiary (SS3/UME level)
    case 'waec':
    case 'neco':
      return 'HighSchool';
    case 'post-utme':
      return 'CollegeOrUniversity';
    default:
      return 'HighSchool';
  }
}

/** Converts a single sample question into a `schema.org/Question` node. */
function buildQuestionNode(q: SEOSampleQuestion): SchemaOrgQuestion {
  const acceptedAnswer = buildAnswerNode(q);

  const node: SchemaOrgQuestion = {
    '@type': 'Question',
    name: q.stem,
  };

  if (acceptedAnswer) {
    node.acceptedAnswer = acceptedAnswer;
  }

  // If there are wrong options, list them as suggestedAnswer alternatives
  if (q.options && q.answer) {
    const wrongOptions = Object.entries(q.options)
      .filter(([key]) => key !== q.answer)
      .map(([, value]): SchemaOrgAnswer => ({
        '@type': 'Answer',
        text: value,
      }));

    if (wrongOptions.length > 0) {
      node.suggestedAnswer = wrongOptions;
    }
  }

  return node;
}

/** Builds the `acceptedAnswer` node for a question, including an explanation comment. */
function buildAnswerNode(q: SEOSampleQuestion): SchemaOrgAnswer | undefined {
  if (!q.answer || !q.options) return undefined;

  const answerText = q.options[q.answer];
  if (!answerText) return undefined;

  const node: SchemaOrgAnswer = {
    '@type': 'Answer',
    text: answerText,
  };

  if (q.explanation) {
    node.comment = {
      '@type': 'Comment',
      text: q.explanation,
    };
  }

  return node;
}

// ─── Breadcrumb Schema (schema.org/BreadcrumbList) ───────────────────────────

/**
 * Builds a `schema.org/BreadcrumbList` from an ordered array of name + URL pairs.
 *
 * @example
 *   buildBreadcrumbSchema([
 *     { name: 'Home', url: 'https://renance.app/' },
 *     { name: 'JAMB',  url: 'https://renance.app/exams/jamb/' },
 *     { name: 'Physics', url: 'https://renance.app/exams/jamb/physics/' },
 *   ])
 */
export function buildBreadcrumbSchema(
  items: Array<{ name: string; url: string }>,
): SchemaOrgBreadcrumbList {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  };
}

// ─── Course Schema (schema.org/Course) ───────────────────────────────────────

/**
 * Builds a `schema.org/Course` JSON-LD object from a NERDC curriculum scheme.
 * Suitable for scheme-of-work / lesson-plan pages and may appear in Google's
 * "Courses" rich results and AI Overview citations.
 */
export function buildCourseSchema(scheme: SEOCurriculumScheme): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Course',
    name: `${scheme.subjectTitle} - ${scheme.classTitle} ${scheme.termTitle} Scheme of Work`,
    description:
      `NERDC-approved ${scheme.subjectTitle} scheme of work for ${scheme.classTitle}, ` +
      `${scheme.termTitle}. Covers ${scheme.weeks.length} weeks of topics and learning objectives.`,
    provider: {
      '@type': 'Organization',
      name: 'Renance',
      url: 'https://renance.app',
    },
    educationalLevel: educationalLevelFromClass(scheme.classLevel),
    url: scheme.canonicalUrl,
    hasPart: scheme.weeks.map((week, i) => ({
      '@type': 'CourseUnit',
      position: i + 1,
      name: `Week ${week.week}: ${week.topic}`,
      description: week.subtopics?.join('; ') ?? week.topic,
    })),
  };
}

/** Maps a class-level slug to a schema.org educational level string. */
function educationalLevelFromClass(classLevel: string): string {
  if (classLevel.startsWith('pry')) return 'PrimaryEducation';
  if (classLevel.startsWith('jss')) return 'MiddleSchool';
  if (classLevel.startsWith('sss')) return 'HighSchool';
  return 'HighSchool';
}

// ─── FAQPage Schema (schema.org/FAQPage) ─────────────────────────────────────

/**
 * Builds a `schema.org/FAQPage` from a list of question-answer pairs.
 * Useful for enriching exam guide pages (e.g. "What topics appear in JAMB Physics?").
 *
 * @example
 *   buildFAQSchema([
 *     { q: 'What year is JAMB Physics hardest?', a: 'Many students find 2019 the most challenging.' },
 *   ])
 */
export function buildFAQSchema(
  faqs: Array<{ q: string; a: string }>,
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map(({ q, a }) => ({
      '@type': 'Question',
      name: q,
      acceptedAnswer: {
        '@type': 'Answer',
        text: a,
      },
    })),
  };
}

// ─── Exam-specific FAQ generator ─────────────────────────────────────────────

/**
 * Auto-generates contextual FAQ JSON-LD for a given exam paper summary.
 * Designed to rank for long-tail queries like "JAMB Physics 2022 topics".
 */
export function buildExamFAQSchema(paper: SEOExamPaperSummary): Record<string, unknown> {
  const faqs: Array<{ q: string; a: string }> = [
    {
      q: `How many questions are in ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year}?`,
      a: `The ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} paper contains ${paper.totalQuestions} questions ` +
        `and should be completed in ${paper.durationMinutes} minutes.`,
    },
    {
      q: `What topics appear in ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year}?`,
      a: paper.sampleQuestions
        .filter((q) => q.topic)
        .map((q) => q.topic as string)
        .filter((v, i, a) => a.indexOf(v) === i) // deduplicate
        .slice(0, 5)
        .join(', ')
        || `${paper.subjectTitle} core topics as set by ${paper.bodyTitle}.`,
    },
    {
      q: `Where can I practice ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} past questions?`,
      a: `You can practice all ${paper.totalQuestions} questions from ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} ` +
        `for free at ${paper.canonicalUrl} on Renance. Full explanations and scoring are included.`,
    },
    {
      q: `Is ${paper.bodyTitle} ${paper.subjectTitle} ${paper.year} hard?`,
      a: `Every student's experience varies, but practising past questions is the most reliable way to prepare. ` +
        `Renance gives you instant access to all ${paper.year} ${paper.bodyTitle} ${paper.subjectTitle} questions with ` +
        `step-by-step explanations - completely free.`,
    },
  ];

  return buildFAQSchema(faqs);
}

// ─── Serialiser ───────────────────────────────────────────────────────────────

/**
 * Serialises any JSON-LD schema object to a safe string for embedding in
 * `<script type="application/ld+json">` tags.
 *
 * Escapes `</script>` sequences to prevent XSS when using
 * `dangerouslySetInnerHTML` in React.
 */
export function serializeJsonLd(schema: Record<string, unknown> | SchemaOrgQuiz | SchemaOrgBreadcrumbList): string {
  return JSON.stringify(schema, null, 2).replace(/<\/script>/gi, '<\\/script>');
}
