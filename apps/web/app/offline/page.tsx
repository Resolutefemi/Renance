/**
 * /offline - the clean offline state (founder bug report 2026-10-15:
 * "when the network goes the app shows a raw text page like
 * /courses/index.txt - give it a proper offline screen").
 *
 * This page is served by the service worker whenever a navigation
 * fails, INSTEAD of the raw RSC payload the static export otherwise
 * falls through to. It is deliberately SELF-CONTAINED: inline styles,
 * no client JavaScript, no external CSS chunks - the worker precaches
 * the HTML alone, so it renders perfectly even on a cold offline
 * device that never cached an asset.
 */

import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'You are offline',
  robots: { index: false, follow: false },
};

const styles = {
  main: {
    minHeight: '100dvh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#0f1216',
    color: '#f0f3f6',
    fontFamily: 'Nunito, Inter, system-ui, -apple-system, sans-serif',
    padding: '24px',
  } as const,
  card: {
    maxWidth: 420,
    width: '100%',
    textAlign: 'center' as const,
    display: 'flex',
    flexDirection: 'column' as const,
    alignItems: 'center',
    gap: 14,
  } as const,
  icon: {
    width: 76,
    height: 76,
    borderRadius: 22,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#151a22',
    color: '#a9d6ff',
    fontSize: 36,
  } as const,
  h1: { fontSize: 22, fontWeight: 900, margin: 0, letterSpacing: '-0.01em' } as const,
  p: { fontSize: 14.5, lineHeight: 1.55, margin: 0, color: '#a6adba', fontWeight: 600 } as const,
  retry: {
    display: 'inline-block',
    marginTop: 6,
    padding: '12px 28px',
    borderRadius: 14,
    background: '#10da11',
    color: '#ffffff',
    fontWeight: 900,
    fontSize: 14,
    textDecoration: 'none',
    borderBottom: '4px solid #0a9c0b',
  } as const,
  hint: { fontSize: 12, color: '#8b93a3', margin: 0, fontWeight: 700 } as const,
};

export default function OfflinePage() {
  return (
    <main style={styles.main}>
      <div style={styles.card}>
        <div style={styles.icon} aria-hidden>
          <svg
            width="40"
            height="40"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
          >
            <path d="M2 2l20 20" />
            <path d="M8.5 16.5a5 5 0 0 1 7 0" />
            <path d="M5 12.5a10 10 0 0 1 3.2-2.2M19 12.5a10 10 0 0 0-5.7-2.9" />
            <path d="M9.5 20l2.5-2.5 2.5 2.5" />
            <path d="M2 8.8A15 15 0 0 1 7 5.6M22 8.8a15 15 0 0 0-4.5-2.9" opacity="0.5" />
          </svg>
        </div>
        <h1 style={styles.h1}>You are offline</h1>
        <p style={styles.p}>
          Renance needs the internet to load your lessons and past questions. Reconnect and pick
          up exactly where you stopped.
        </p>
        <a href="/" style={styles.retry}>
          Try again
        </a>
        <p style={styles.hint}>Your progress is saved - nothing is lost.</p>
      </div>
    </main>
  );
}
