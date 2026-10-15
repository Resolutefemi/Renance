'use client';

/**
 * OfflineBanner: the in-app offline state (founder bug report
 * 2026-10-15: offline sessions fell through to raw text pages).
 *
 * Listens to the browser's online/offline events and shows a slim,
 * dismissible banner at the top of every screen while the connection
 * is down, with a Retry that refreshes the route. The bundle rides the
 * browser's HTTP cache after the first visit, so the banner itself
 * renders offline.
 */

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function OfflineBanner() {
  const router = useRouter();
  const [offline, setOffline] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    setOffline(!navigator.onLine);
    const down = () => {
      setOffline(true);
      setDismissed(false);
    };
    const up = () => setOffline(false);
    window.addEventListener('offline', down);
    window.addEventListener('online', up);
    return () => {
      window.removeEventListener('offline', down);
      window.removeEventListener('online', up);
    };
  }, []);

  if (!offline || dismissed) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        position: 'fixed',
        inset: '0 0 auto 0',
        zIndex: 90,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '12px',
        padding: '10px 16px',
        background: '#93000a',
        color: '#ffdad6',
        font: '700 13px/1.2 Nunito, Inter, system-ui, sans-serif',
      }}
    >
      <span aria-hidden style={{ fontSize: 16 }}>
        ⚠
      </span>
      <span>You are offline - some things will not load until the connection is back.</span>
      <button
        type="button"
        onClick={() => router.refresh()}
        style={{
          border: '2px solid rgba(255, 218, 214, 0.6)',
          borderRadius: 10,
          background: 'transparent',
          color: '#ffdad6',
          padding: '4px 12px',
          font: '800 12px/1.2 inherit',
          cursor: 'pointer',
        }}
      >
        Retry
      </button>
      <button
        type="button"
        aria-label="Dismiss the offline notice"
        onClick={() => setDismissed(true)}
        style={{
          border: 'none',
          background: 'transparent',
          color: '#ffdad6',
          cursor: 'pointer',
          font: '800 14px/1 inherit',
          padding: 4,
        }}
      >
        ✕
      </button>
    </div>
  );
}
