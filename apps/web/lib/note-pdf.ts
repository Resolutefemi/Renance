'use client';

// Per-topic note PDF, BLACK & WHITE ONLY (house style for school notes:
// no colours, no fills — just ink on white, print-ready). One topic per
// file, exactly as schools asked: download notes per topic, never all at
// once.

import { jsPDF } from 'jspdf';
import type { SchoolTopic } from '@/lib/school';
import { termLabel } from '@/lib/school';

const PAGE_W = 210; // A4 mm
const PAGE_H = 297;
const MARGIN = 22;
const CONTENT_W = PAGE_W - MARGIN * 2;

export interface NotePdfMeta {
  schoolName: string;
  className: string;
  subject: string;
  term: number;
  session?: string;
}

export function topicFileName(meta: NotePdfMeta, topic: SchoolTopic): string {
  const slug = (s: string) =>
    s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 48);
  return `${slug(meta.subject)}-${slug(topic.title)}-wk${topic.week || topic.seq || ''}.pdf`;
}

export function downloadTopicPdf(meta: NotePdfMeta, topic: SchoolTopic): void {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });

  // ---- header (black text on white, thin rule) --------------------------
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(15);
  doc.text(meta.schoolName.toUpperCase(), PAGE_W / 2, MARGIN, { align: 'center' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10.5);
  const sessionBit = meta.session ? ` — ${meta.session}` : '';
  doc.text(`${meta.className}  ·  ${meta.subject}  ·  ${termLabel(meta.term)}${sessionBit}`, PAGE_W / 2, MARGIN + 7, {
    align: 'center',
  });

  doc.setDrawColor(0);
  doc.setLineWidth(0.5);
  doc.line(MARGIN, MARGIN + 12, PAGE_W - MARGIN, MARGIN + 12);

  // ---- title -------------------------------------------------------------
  let y = MARGIN + 24;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(13.5);
  doc.text(topic.title, PAGE_W / 2, y, { align: 'center', maxWidth: CONTENT_W });
  y += 7;

  const weekBit = topic.week ? `Week ${topic.week}` : `Topic ${topic.seq}`;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9.5);
  doc.text(weekBit, PAGE_W / 2, y, { align: 'center' });
  y += 6;

  doc.setDrawColor(0);
  doc.setLineWidth(0.2);
  doc.line(MARGIN, y, PAGE_W - MARGIN, y);
  y += 8;

  // ---- body: wrap plain text; blank line = paragraph break ---------------
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(11);
  const lineH = 5.6;
  const paragraphs = (topic.content || '').split(/\n\s*\n/);
  for (const para of paragraphs) {
    const clean = para.replace(/\s+/g, ' ').trim();
    if (!clean) continue;
    const lines = doc.splitTextToSize(clean, CONTENT_W);
    for (const line of lines as string[]) {
      if (y > PAGE_H - MARGIN) {
        doc.addPage();
        y = MARGIN;
      }
      doc.text(line, MARGIN, y);
      y += lineH;
    }
    y += lineH * 0.7; // paragraph gap
  }

  // ---- footer on every page ----------------------------------------------
  const pages = doc.getNumberOfPages();
  for (let p = 1; p <= pages; p++) {
    doc.setPage(p);
    doc.setFontSize(8.5);
    doc.setTextColor(0);
    doc.text(
      `${meta.schoolName} — ${meta.subject} note (${topic.title})`,
      MARGIN,
      PAGE_H - 12,
    );
    doc.text(`Page ${p} of ${pages}`, PAGE_W - MARGIN, PAGE_H - 12, { align: 'right' });
  }

  doc.save(topicFileName(meta, topic));
}
