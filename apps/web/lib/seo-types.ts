/**
 * @file apps/web/lib/seo-types.ts
 * Type definitions for Renance Programmatic SEO & GEO Engine.
 * Supports Phase 1 through Phase 5 data harvesting, schema generation,
 * and static route pre-rendering.
 */

export type ExamBodySlug = 'jamb' | 'waec' | 'neco' | 'post-utme';

export interface SEOSampleQuestion {
  id: string;
  stem: string;
  options?: Record<string, string>;
  answer?: string;
  explanation?: string;
  year?: number;
  marks?: number;
  topic?: string;
  image?: string;
  nerdcTheme?: string;
}

export interface SEOExamPaperSummary {
  body: ExamBodySlug;
  bodyTitle: string;
  subjectSlug: string;
  subjectTitle: string;
  year: number;
  totalQuestions: number;
  durationMinutes: number;
  sampleQuestions: SEOSampleQuestion[];
  canonicalUrl: string;
}

export interface SEOSubjectPillar {
  body: ExamBodySlug;
  bodyTitle: string;
  subjectSlug: string;
  subjectTitle: string;
  totalBankedQuestions: number;
  availableYears: number[];
  syllabusThemes: string[];
  canonicalUrl: string;
}

export interface SEOCurriculumWeek {
  week: number;
  topic: string;
  subtopics?: string[];
  learningObjectives?: string[];
  suggestedActivities?: string[];
}

export interface SEOCurriculumScheme {
  classLevel: string; // e.g., 'ss2' | 'jss1'
  classTitle: string; // e.g., 'Senior Secondary 2'
  subjectSlug: string;
  subjectTitle: string;
  term: 'first-term' | 'second-term' | 'third-term';
  termTitle: string;
  weeks: SEOCurriculumWeek[];
  canonicalUrl: string;
}

export interface SEOUniversityCutOffGuide {
  schoolSlug: string;
  schoolName: string;
  schoolAbbr: string;
  courseSlug: string;
  courseTitle: string;
  faculty: string;
  jambCutOff: number;
  meritAggregate?: number;
  catchmentAggregate?: number;
  requiredSubjects: string[];
  oLevelRequirements: string[];
  postUtmeFormat: string;
  canonicalUrl: string;
}

/** Schema.org structured data types */
export interface SchemaOrgAnswer {
  '@type': 'Answer';
  text: string;
  encodingFormat?: string;
  comment?: {
    '@type': 'Comment';
    text: string;
  };
}

export interface SchemaOrgQuestion {
  '@type': 'Question';
  name: string;
  suggestedAnswer?: SchemaOrgAnswer[];
  acceptedAnswer?: SchemaOrgAnswer;
}

export interface SchemaOrgQuiz {
  '@context': 'https://schema.org';
  '@type': 'Quiz';
  name: string;
  description: string;
  educationalLevel?: string;
  about?: {
    '@type': 'Thing';
    name: string;
  };
  hasPart: SchemaOrgQuestion[];
}

export interface SchemaOrgBreadcrumbItem {
  '@type': 'ListItem';
  position: number;
  name: string;
  item: string;
}

export interface SchemaOrgBreadcrumbList {
  '@context': 'https://schema.org';
  '@type': 'BreadcrumbList';
  itemListElement: SchemaOrgBreadcrumbItem[];
}
