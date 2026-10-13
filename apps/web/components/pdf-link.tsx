'use client';

/**
 * PdfLink - the shielded past-question PDF button (founder directive
 * 2026-10-12: "I need ultimate security, no openings").
 *
 * The /pdfs/** shelf on renance.app now ships as AES-256-GCM
 * ciphertext (scripts/encrypt_pdfs.mjs) - a plain <a href> would
 * download noise. This component keeps the exact card/button markup
 * the pages already render, but clicks run the shield flow:
 * fetch -> GET /bundles/key?code=static:<path> (PoW when signed out)
 * -> WebCrypto decrypt -> blob -> new tab (download fallback).
 *
 * Swap:  <a href={withBase(c.pdf)} ...> ... </a>
 *   ->   <PdfLink href={c.pdf} className="...same classes..."> ... </PdfLink>
 */

import { useState, type MouseEvent, type ReactNode } from 'react';
import { openPdfAsset } from '@/lib/asset-crypto';
import { RenanceMark } from '@/components/renance-logo';

type Status = 'idle' | 'working' | 'error';

export function PdfLink({
  href,
  className,
  children,
}: {
  /** Site-root-relative path, e.g. "/pdfs/futa/cos101.pdf". */
  href: string;
  className?: string;
  children: ReactNode;
}) {
  const [status, setStatus] = useState<Status>('idle');
  const [error, setError] = useState('');

  async function go(e: MouseEvent) {
    e.preventDefault();
    if (status === 'working') return;
    setStatus('working');
    setError('');
    try {
      await openPdfAsset(href);
      setStatus('idle');
    } catch (err) {
      setStatus('error');
      setError(err instanceof Error ? err.message : 'Could not open this PDF. Please try again.');
      // The card returns to normal after the message had its moment.
      setTimeout(() => {
        setStatus((s) => (s === 'error' ? 'idle' : s));
        setError('');
      }, 7000);
    }
  }

  return (
    <button
      type="button"
      onClick={go}
      className={`${className ?? ''} text-left ${status === 'working' ? 'pointer-events-none opacity-70' : ''}`}
      aria-busy={status === 'working'}
    >
      {children}
      {status === 'working' && (
        <span className="ml-2 flex shrink-0 items-center">
          <RenanceMark size={18} state="busy" />
        </span>
      )}
      {status === 'error' && (
        <span className="ml-2 shrink-0 text-xs text-error">{error}</span>
      )}
    </button>
  );
}
