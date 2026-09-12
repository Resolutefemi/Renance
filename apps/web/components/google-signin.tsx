'use client';

// Google Identity Services button.
//
// Renders nothing until NEXT_PUBLIC_GOOGLE_CLIENT_ID is baked at build
// time, so local/dev builds and forked deploys degrade gracefully to
// username+password only. The flow returns a Google ID token (JWT); the
// study API verifies it against Google's JWKS and issues a Renance session.

import { useEffect, useRef } from 'react';

type GoogleCredentialResponse = { credential?: string };

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: GoogleCredentialResponse) => void;
          }) => void;
          renderButton: (parent: HTMLElement, options: Record<string, string>) => void;
        };
      };
    };
  }
}

const GIS_SRC = 'https://accounts.google.com/gsi/client';
const SCRIPT_ID = 'renance-gsi';

export function GoogleSignIn({ onCredential }: { onCredential: (credential: string) => void }) {
  // Trim + validate: repo Variables often pick up stray quotes/whitespace, and
  // pasting the ANDROID client ID here produces "Error 401: invalid_client".
  // A web client ID looks like <number>-<hash>.apps.googleusercontent.com.
  const rawId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
  const clientId = rawId?.trim().replace(/^["']|["']$/g, '');
  const malformed = !!clientId && !/^\d{4,}-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$/.test(clientId);
  const holder = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!clientId || malformed || !holder.current) return;
    let cancelled = false;

    const render = () => {
      if (cancelled || !window.google || !holder.current) return;
      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: (response) => {
          if (response.credential) onCredential(response.credential);
        },
      });
      window.google.accounts.id.renderButton(holder.current, {
        theme: 'outline',
        size: 'large',
        shape: 'pill',
        text: 'continue_with',
        logo_alignment: 'center',
      });
    };

    const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null;
    if (window.google) {
      render();
      return () => {
        cancelled = true;
      };
    }

    const script = existing ?? document.createElement('script');
    if (!existing) {
      script.id = SCRIPT_ID;
      script.src = GIS_SRC;
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
    script.addEventListener('load', render);
    return () => {
      cancelled = true;
      script.removeEventListener('load', render);
    };
  }, [clientId, onCredential]);

  if (!clientId) return null;
  return (
    <>
      {malformed && (
        <p className="mx-auto max-w-sm rounded-xl border border-error/30 bg-error-container/40 p-3 text-center text-[12px] leading-5 text-on-surface">
          Google sign-in is misconfigured: <code className="font-mono">NEXT_PUBLIC_GOOGLE_CLIENT_ID</code>{' '}
          doesn&apos;t look like a web OAuth client ID (expected{' '}
          <code className="font-mono">&lt;number&gt;-&lt;hash&gt;.apps.googleusercontent.com</code>, got{' '}
          <span className="font-mono">&quot;{clientId}&quot;</span>). Using the Android client ID on web
          triggers <b>Error 401: invalid_client</b>.
        </p>
      )}
      <div className="flex items-center gap-3 text-xs uppercase tracking-widest text-on-surface-variant">
        <span className="h-px flex-1 bg-outline-variant" />
        or
        <span className="h-px flex-1 bg-outline-variant" />
      </div>
      <div ref={holder} className="flex min-h-10 justify-center" />
      {/* Google renders its own error page for a misconfigured OAuth client
          ("Error 401: invalid_client") — un-interceptable from JS. This
          note puts the exact fix one tap away instead of a dead end. */}
      <details className="mx-auto mt-2 max-w-sm text-center text-[12px] text-on-surface-variant">
        <summary className="cursor-pointer select-none text-outline hover:text-on-surface-variant">
          Google sign-in showing an error?
        </summary>
        <p className="mt-2 leading-5">
          <b>Error 401: invalid_client</b> is server-side OAuth configuration, not your
          account: the deployment origin must be listed under the web client&apos;s{' '}
          <i>Authorized JavaScript origins</i> in Google Cloud Console → APIs &amp;
          Services → Credentials:
          <br />
          <code className="mt-1 block break-all rounded bg-surface-container px-2 py-1 font-mono text-[11px]">
            {typeof window !== 'undefined' ? window.location.origin : 'https://resolutefemi.github.io'}
          </code>
          plus <code className="font-mono">http://localhost:3000</code> for local dev — and the
          OAuth consent screen must be published (Audience → Publishing status
          &ldquo;In production&rdquo;).
        </p>
      </details>
    </>
  );
}
