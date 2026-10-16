import type { Metadata } from 'next';
import Link from 'next/link';

import PillarNav from '@/components/pillar-nav';

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'Delete your Renance account',
  description:
    'How to delete your Renance account and its data: delete inside the app in under a minute, or email info@renance.app. What is deleted, what is kept and for how long.',
  alternates: { canonical: '/delete-account/' },
  openGraph: {
    title: 'Delete your Renance account',
    description:
      'Delete your Renance account and its data from the app in under a minute, or request deletion by email. What is deleted, what is kept, for how long.',
    url: '/delete-account/',
    siteName: 'Renance',
    images: [
      {
        url: '/og-2026.jpg',
        width: 1200,
        height: 630,
        alt: 'Delete your Renance account',
      },
    ],
    type: 'website',
  },
};

const UPDATED = '6 October 2026';

const INTRO =
  'Renance is the educational app in Nigeria for JAMB, WAEC, NECO and Post-UTME preparation, built by Resolute Femi. This page is the official account deletion request link for the Renance app (Android and iOS) and renance.app. You never need to explain why: every Renance account can be deleted, for free, at any time, by the account owner alone.';

const APP_STEPS: string[] = [
  'Open the Renance app and sign in to the account you want to delete.',
  'Open the profile menu and tap My Account (the account sheet).',
  'Tap Delete account, read the warning, then tap the confirm button.',
  'The deletion runs immediately: the account and its data are wiped in one transaction and you are signed out. This cannot be undone.',
];

const EMAIL_STEPS: string[] = [
  'Email info@renance.app from the address registered on the account (so we can verify ownership).',
  'Use the subject line: Delete my account.',
  'Include your Renance username if you have it; it speeds up matching.',
  'We process verified deletion requests within 7 days and reply to confirm once your account and data are gone.',
];

type Row = { term: string; body: string };

const DELETED: Row[] = [
  {
    term: 'Account data',
    body: 'Your username, email address, hashed password, class or exam level, referral link and account settings.',
  },
  {
    term: 'Study history',
    body: 'Every practice attempt, the answers you picked, your scores and results, your spaced-repetition review queue and saved questions.',
  },
  {
    term: 'Progress and rewards',
    body: 'Streaks, XP, badges and awards tied to the account.',
  },
  {
    term: 'Arena and leaderboard',
    body: 'Your arena matches and your leaderboard entries; other players simply stop seeing you.',
  },
  {
    term: 'School memberships',
    body: 'Your membership in any Renance for Schools workspace is removed.',
  },
  {
    term: 'Entitlements',
    body: 'Any premium entitlements on the account.',
  },
  {
    term: 'AI conversations',
    body: 'Your Renance AI study companion and tutor conversations, in full.',
  },
];

const KEPT: Row[] = [
  {
    term: 'Server request logs',
    body: 'Anonymised request logs (IP address, user agent, timestamp) are kept up to 90 days for security and abuse prevention, then they expire. They are not study data and are not used to rebuild your account.',
  },
  {
    term: 'Aggregated statistics',
    body: 'De-identified counts (for example, how many candidates attempted a question this month) may be kept indefinitely because they no longer identify anyone.',
  },
  {
    term: 'School-entered records',
    body: "If your school entered your records in Renance for Schools, those records belong to the school: deleting your student account does not erase the school's copies. Ask the school directly, or ask us and we will pass the request on.",
  },
];

const NO_APP =
  'No app access? If you lost the device or the password, you do not need to sign in first: email ' +
  'info@renance.app from your registered address and we will verify you are the owner before deleting. ' +
  'We never delete an account on the word of an unverified email.';

export default function DeleteAccountPage() {
  return (
    <>
      <style
        dangerouslySetInnerHTML={{
          __html: `
.rpd-root{background:#fff;color:#111;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65;padding-top:64px;-webkit-font-smoothing:antialiased}
.rpd-wrap{max-width:860px;margin:0 auto;padding:0 22px}
.rpd-eyebrow{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8a8a8a}
.rpd-hero{padding:70px 0 48px;text-align:center;border-bottom:1px solid rgba(10,10,10,.08)}
.rpd-hero h1{font-size:clamp(32px,5vw,50px);line-height:1.05;font-weight:800;letter-spacing:-.035em;margin:14px 0 16px;color:#0a0a0a}
.rpd-updated{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:13px;color:#8a8a8a;margin-bottom:22px}
.rpd-applies{text-align:left;background:#fafafa;border:1px solid rgba(10,10,10,.12);border-left:3px solid var(--color-primary,#0a0a0a);border-radius:14px;padding:22px 26px;max-width:780px;margin:0 auto;font-size:15.5px;color:#333}
.rpd-section{padding:52px 0;border-bottom:1px solid rgba(10,10,10,.07)}
.rpd-kicker{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;color:#8a8a8a;letter-spacing:.14em;text-transform:uppercase}
.rpd-section h2{font-size:clamp(22px,3vw,30px);font-weight:800;letter-spacing:-.02em;margin:8px 0 18px;color:#0a0a0a}
.rpd-section p{margin:0 0 14px;color:#333;font-size:15.5px}
.rpd-ways{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px;margin-top:6px}
.rpd-way{background:#fff;border:1px solid rgba(10,10,10,.14);border-radius:16px;padding:26px}
.rpd-tag{display:inline-block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11px;letter-spacing:.12em;text-transform:uppercase;background:var(--color-primary,#0a0a0a);color:var(--color-on-primary,#fff);border-radius:999px;padding:5px 12px;margin-bottom:14px}
.rpd-way h3{font-size:18px;color:#0a0a0a;margin:0 0 14px;letter-spacing:-.015em;font-weight:750}
.rpd-way ol{margin:0;padding-left:20px;color:#444;font-size:15px}
.rpd-way li{margin-bottom:10px}
.rpd-way li:last-child{margin-bottom:0}
.rpd-rows{width:100%;border-collapse:collapse;font-size:15px}
.rpd-rows th,.rpd-rows td{text-align:left;padding:13px 14px;border-bottom:1px solid rgba(10,10,10,.1);vertical-align:top}
.rpd-rows th{color:#0a0a0a;font-weight:700;white-space:nowrap;width:210px;font-size:14.5px}
.rpd-rows td{color:#444}
.rpd-note{background:#fafafa;border:1px solid rgba(10,10,10,.12);border-radius:14px;padding:20px 24px;font-size:15px;color:#333;margin-top:18px}
.rpd-contact{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 24%, #0a0a0a);color:#fff;border-radius:18px;padding:32px 34px;margin:52px 0 0}
.rpd-contact h2{color:#fff;font-size:clamp(22px,3vw,28px);font-weight:800;letter-spacing:-.02em;margin:0 0 12px}
.rpd-contact p{color:#d6d6d6;font-size:15.5px;margin:0 0 10px}
.rpd-contact p:last-child{margin:0}
.rpd-contact a{color:#fff;font-weight:700;text-decoration:none;border-bottom:1.5px solid rgba(255,255,255,.6);padding-bottom:1px}
.rpd-foot{border-top:1px solid rgba(10,10,10,.1);padding:28px 0;color:#8a8a8a;font-size:13.5px;text-align:center}
.rpd-foot a{color:#555;text-decoration:none;margin:0 7px}
.rpd-foot a:hover{color:#0a0a0a}
@media(max-width:640px){.rpd-rows th{display:block;width:100%;padding-bottom:4px}.rpd-rows td{display:block;padding-top:2px}}
`,
        }}
      />
      <div className="rpd-root">
        <PillarNav />

        <section className="rpd-hero">
          <div className="rpd-wrap">
            <span className="rpd-eyebrow">Renance · Account deletion</span>
            <h1>Delete your Renance account</h1>
            <div className="rpd-updated">Last updated: {UPDATED}</div>
            <p className="rpd-applies">{INTRO}</p>
          </div>
        </section>

        <main className="rpd-wrap">
          <section className="rpd-section">
            <span className="rpd-kicker">How to delete</span>
            <h2>Two ways, both free</h2>
            <div className="rpd-ways">
              <div className="rpd-way">
                <span className="rpd-tag">Fastest · instant</span>
                <h3>Delete inside the Renance app</h3>
                <ol>
                  {APP_STEPS.map((step) => (
                    <li key={step.slice(0, 30)}>{step}</li>
                  ))}
                </ol>
              </div>
              <div className="rpd-way">
                <span className="rpd-tag">No app needed · within 7 days</span>
                <h3>Request deletion by email</h3>
                <ol>
                  {EMAIL_STEPS.map((step) => (
                    <li key={step.slice(0, 30)}>{step}</li>
                  ))}
                </ol>
              </div>
            </div>
            <div className="rpd-note">{NO_APP}</div>
          </section>

          <section className="rpd-section">
            <span className="rpd-kicker">What disappears</span>
            <h2>Data that is deleted</h2>
            <p>
              Deleting your account wipes the following, permanently, in one
              transaction. Nobody at Renance can restore it:
            </p>
            <table className="rpd-rows">
              <tbody>
                {DELETED.map((row) => (
                  <tr key={row.term}>
                    <th scope="row">{row.term}</th>
                    <td>{row.body}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="rpd-section">
            <span className="rpd-kicker">What survives</span>
            <h2>Data that is kept, and for how long</h2>
            <table className="rpd-rows">
              <tbody>
                {KEPT.map((row) => (
                  <tr key={row.term}>
                    <th scope="row">{row.term}</th>
                    <td>{row.body}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="rpd-note">
              Deletion is permanent. Your username and email are released, so
              the same email can register a fresh account later - it starts
              empty, with no history, streaks or entitlements.
            </div>
          </section>

          <section className="rpd-section">
            <span className="rpd-kicker">Related</span>
            <h2>Your privacy, in full</h2>
            <p>
              The complete list of what Renance collects, why, who it is
              shared with and every right you have over it lives in the{' '}
              <Link
                href="/privacy/"
                className="font-bold text-primary"
              >
                Renance Privacy Policy
              </Link>
              . For anything this page does not cover, write to us.
            </p>
          </section>

          <div className="rpd-contact">
            <h2>Contact us</h2>
            <p>
              Renance, built by Resolute Femi (Ariyo Oluwafemi Stephen),
              Nigeria.
            </p>
            <p>
              Account deletion, questions or appeals:{' '}
              <a href="mailto:info@renance.app">info@renance.app</a>
            </p>
            <p>
              Page version: {UPDATED} · renance.app/delete-account
            </p>
          </div>
        </main>

        <footer className="rpd-foot">
          <div className="rpd-wrap">
            <div>
              <Link href="/">Renance</Link>·
              <Link href="/about/">About</Link>·
              <Link href="/faq/">FAQ</Link>·
              <Link href="/privacy/">Privacy</Link>·
              <Link href="/delete-account/">Delete account</Link>
            </div>
            <div style={{ marginTop: 8 }}>
              Renance · Your Guide to Academic Success · Built by Resolute Femi
            </div>
          </div>
        </footer>
      </div>
    </>
  );
}
