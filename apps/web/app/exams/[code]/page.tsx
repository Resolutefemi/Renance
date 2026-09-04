import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { Suspense } from 'react';
import ExamClient from './exam-client';

/**
 * Server wrapper for the CBT player.
 *
 * Static export (`output: 'export'`) requires every dynamic route to be
 * pinned at build time, so pack URLs are generated from the committed
 * data/manifest.json. Adding a pack ships in the same commit as its
 * manifest entry and the Pages rebuild, so the sets can never drift.
 */

function manifestCodes(): string[] {
  let dir = process.cwd();
  for (let i = 0; i < 6; i++) {
    const candidate = path.join(dir, 'data', 'manifest.json');
    if (existsSync(candidate)) {
      try {
        const parsed = JSON.parse(readFileSync(candidate, 'utf8')) as {
          exams?: Array<{ code?: string }>;
        };
        return (parsed.exams ?? [])
          .map((e) => e.code)
          .filter((c): c is string => Boolean(c));
      } catch {
        return [];
      }
    }
    const parent = path.dirname(dir);
    if (parent === dir) return [];
    dir = parent;
  }
  return [];
}

export function generateStaticParams() {
  return manifestCodes().map((code) => ({ code }));
}

export default async function ExamRoute({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;
  // Suspense boundary: the client reads ?timer= overrides (Practice
  // Settings) via useSearchParams, which requires one under export.
  return (
    <Suspense fallback={null}>
      <ExamClient code={code} />
    </Suspense>
  );
}
