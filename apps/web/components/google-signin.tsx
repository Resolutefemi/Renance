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
  const clientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
  const holder = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!clientId || !holder.current) return;
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
      <div className="flex items-center gap-3 text-xs uppercase tracking-widest text-on-surface-variant">
        <span className="h-px flex-1 bg-outline-variant" />
        or
        <span className="h-px flex-1 bg-outline-variant" />
      </div>
      <div ref={holder} className="flex min-h-10 justify-center" />
    </>
  );
}
