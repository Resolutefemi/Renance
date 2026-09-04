import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import SubjectSelectionClient from './subject-client';

/**
 * Server wrapper for the Stitch jamb_subject_selection_light screen.
 *
 * The Start Mock Exam button launches the primary pack's CBT player,
 * so the first manifest exam code is pinned here at build time (static
 * export requires every route target to exist in the export, and the
 * /exams/[code] set is generated from the same manifest).
 */

function firstExamCode(): string {
  let dir = process.cwd();
  for (let i = 0; i < 6; i++) {
    const candidate = path.join(dir, 'data', 'manifest.json');
    if (existsSync(candidate)) {
      try {
        const parsed = JSON.parse(readFileSync(candidate, 'utf8')) as {
          exams?: Array<{ code?: string }>;
        };
        const code = (parsed.exams ?? []).map((e) => e.code).find(Boolean);
        return code ?? '';
      } catch {
        return '';
      }
    }
    const parent = path.dirname(dir);
    if (parent === dir) return '';
    dir = parent;
  }
  return '';
}

export default function SubjectSelectionRoute() {
  return <SubjectSelectionClient startCode={firstExamCode()} />;
}
