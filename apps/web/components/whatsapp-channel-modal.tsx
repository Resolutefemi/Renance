'use client';

/**
 * WhatsAppChannelModal - the founder's 2026-10-17 directive: "once a
 * user signup/login notify them with this join our WhatsApp channel to
 * stay tuned https://whatsapp.com/channel/0029VbDnzhVKAwEltcgbOZ3K.
 * If a user doesn't click the join button, make sure anytime a user
 * login, it pops up for them".
 *
 * Mechanics: the login and register screens stamp renance_wa_prompt
 * into localStorage right after a successful auth. This modal (mounted
 * on the dashboard) consumes the stamp once per browser session and
 * shows the sheet - UNLESS renance_wa_joined is already set, which only
 * the Join button ever writes. "Maybe later" always comes back on the
 * next login, exactly as the founder asked.
 */

import { useEffect, useState } from 'react';

const CHANNEL_URL = 'https://whatsapp.com/channel/0029VbDnzhVKAwEltcgbOZ3K';
const PROMPT_KEY = 'renance_wa_prompt';
const JOINED_KEY = 'renance_wa_joined';

export function stampWhatsAppPrompt() {
  try {
    window.localStorage.setItem(PROMPT_KEY, '1');
  } catch {
    /* private mode: the popup simply will not nag */
  }
}

function readFlag(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export default function WhatsAppChannelModal() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (readFlag(JOINED_KEY) === '1') return;
    if (readFlag(PROMPT_KEY) !== '1') return;
    // Consume the stamp; a dismissed popup returns on the NEXT login.
    try {
      window.localStorage.removeItem(PROMPT_KEY);
    } catch {
      /* noop */
    }
    const t = window.setTimeout(() => setOpen(true), 900);
    return () => window.clearTimeout(t);
  }, []);

  if (!open) return null;

  const join = () => {
    try {
      window.localStorage.setItem(JOINED_KEY, '1');
    } catch {
      /* noop */
    }
    window.open(CHANNEL_URL, '_blank', 'noopener,noreferrer');
    setOpen(false);
  };

  return (
    <div
      className="fixed inset-0 z-[60] flex items-end justify-center bg-black/55 sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Join the Renance WhatsApp channel"
    >
      <div className="w-full max-w-sm overflow-hidden rounded-t-3xl bg-card shadow-2xl sm:rounded-3xl">
        <div className="flex flex-col items-center gap-3 px-6 pb-5 pt-7 text-center">
          <span className="flex h-16 w-16 items-center justify-center rounded-2xl bg-[#25D366]/15">
            <svg viewBox="0 0 32 32" className="h-9 w-9" aria-hidden fill="#25D366">
              <path d="M16 3C8.8 3 3 8.8 3 16c0 2.3.6 4.5 1.7 6.4L3 29l6.8-1.7c1.9 1 4 1.6 6.2 1.6 7.2 0 13-5.8 13-13S23.2 3 16 3Zm7.6 18.3c-.3.9-1.8 1.7-2.5 1.8-.7.1-1.5.2-4.4-.9-3.4-1.3-5.6-4.8-5.8-5-.2-.2-1.4-1.9-1.4-3.6 0-1.7.9-2.6 1.2-2.9.3-.4.7-.5 1-.5h.7c.2 0 .5-.1.8.6l1.1 2.7c.1.2.2.5 0 .8l-.5.8c-.2.2-.4.5-.2.8.2.4.9 1.5 1.9 2.4 1.3 1.2 2.4 1.5 2.8 1.7.3.2.5.1.7-.1l1.1-1.3c.2-.3.5-.2.8-.1l2.5 1.2c.4.2.6.3.7.5.1.1.1.8-.1 1.6Z" />
            </svg>
          </span>
          <h3 className="text-[18px] font-black text-on-surface">Join our WhatsApp channel</h3>
          <p className="max-w-[19rem] text-[13px] font-semibold leading-snug text-on-surface-variant">
            Stay tuned for new features, study packs and exam tips - straight to your WhatsApp.
          </p>
        </div>
        <div className="flex flex-col gap-2 px-6 pb-6">
          <button
            type="button"
            onClick={join}
            className="key-btn flex w-full items-center justify-center gap-2 bg-[#25D366] py-3.5 text-[14px] text-white"
          >
            <span className="material-symbols-outlined text-[18px]">open_in_new</span>
            Join the channel
          </button>
          <button
            type="button"
            onClick={() => setOpen(false)}
            className="w-full rounded-xl px-4 py-3 text-[13px] font-bold text-on-surface-variant transition hover:bg-surface-container"
          >
            Maybe later
          </button>
        </div>
      </div>
    </div>
  );
}
