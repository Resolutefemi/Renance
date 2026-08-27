#!/usr/bin/env tsx
/**
 * cbt:build — bank JSON -> student-safe bundle.json + server-only key.json.
 *
 *   pnpm cbt:build <input.json-or-dir> <outdir>
 *
 * Writes <outdir>/<code>/bundle.json and <outdir>/<code>/key.json, prints a
 * per-bank report. The key file MUST never be shipped/served publicly —
 * uploading it to the API (Gate 1.9) is an authenticated org-admin action.
 */
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { basename, isAbsolute, join, resolve } from 'node:path';
import { normalizeBank } from './normalize';
import type { BuildReport } from './types';

function collectInputs(input: string): string[] {
  const st = statSync(input);
  if (st.isFile()) return [input];
  return readdirSync(input)
    .filter((f) => f.toLowerCase().endsWith('.json'))
    .map((f) => join(input, f));
}

function main(): number {
  const [input, outDir] = process.argv.slice(2);
  if (!input || !outDir) {
    console.error('usage: cbt:build <input.json-or-dir> <outdir>');
    return 2;
  }
  const inPath = isAbsolute(input) ? input : resolve(process.cwd(), input);
  const outPath = isAbsolute(outDir) ? outDir : resolve(process.cwd(), outDir);
  const files = collectInputs(inPath);
  if (files.length === 0) {
    console.error(`no .json files under ${inPath}`);
    return 2;
  }

  const reports: BuildReport[] = [];
  let failed = 0;
  mkdirSync(outPath, { recursive: true });

  for (const file of files) {
    const name = basename(file);
    try {
      const { bundle, key, report } = normalizeBank(readFileSync(file, 'utf8'), name);
      if (bundle.questionCount === 0) {
        console.log(`✗ ${name.padEnd(28)} 0 usable questions — skipped`);
        failed++;
        continue;
      }
      const dir = join(outPath, bundle.code);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'bundle.json'), JSON.stringify(bundle, null, 2) + '\n');
      writeFileSync(join(dir, 'key.json'), JSON.stringify(key, null, 2) + '\n');
      reports.push(report);
      console.log(
        `✓ ${name.padEnd(28)} → ${bundle.code.padEnd(20)} kept ${String(bundle.questionCount).padStart(4)}/${report.parsed}  (mcq ${report.mcq} · text ${report.text})${report.dropped.length ? `  dropped ${report.dropped.length}` : ''}`,
      );
    } catch (e) {
      console.log(`✗ ${name.padEnd(28)} ${(e as Error).message.slice(0, 90)}`);
      failed++;
    }
  }

  const totals = reports.reduce(
    (acc, r) => ({ kept: acc.kept + r.kept, mcq: acc.mcq + r.mcq, text: acc.text + r.text }),
    { kept: 0, mcq: 0, text: 0 },
  );
  console.log(
    `\n${reports.length} bank(s) built · ${totals.kept} questions (mcq ${totals.mcq}, text ${totals.text}) · ${failed} failed → ${outPath}`,
  );
  console.log('REMINDER: key.json files are SERVER-ONLY. Never commit them to a public surface or serve them to clients.');
  return failed === 0 ? 0 : 1;
}

process.exit(main());
