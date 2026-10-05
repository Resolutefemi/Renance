import type { Metadata } from 'next';
import Link from 'next/link';

import PillarNav from '@/components/pillar-nav';

export const dynamic = 'force-static';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description:
    'How Renance collects, uses, shares and protects your data: accounts, study activity, school records, analytics and your rights, for the Renance app and renance.app.',
  alternates: { canonical: '/privacy/' },
  openGraph: {
    title: 'Renance Privacy Policy',
    description:
      'How Renance collects, uses, shares and protects your data, and the rights you have over it. Applies to the Renance app, renance.app and Renance for Schools.',
    url: '/privacy/',
    siteName: 'Renance',
    images: [
      {
        url: '/og.jpg',
        width: 1200,
        height: 630,
        alt: 'Renance privacy policy',
      },
    ],
    type: 'website',
  },
};

const CONTACT_EMAIL = 'info@renance.app';
const LAST_UPDATED = '6 October 2026';

const APPLIES_TO =
  'This policy applies to the Renance mobile app for Android and iOS, the Renance website at renance.app, the Renance API that powers them, and Renance for Schools. It covers every student, teacher, school manager and patron who uses Renance, anywhere in the world, whether or not you create an account.';

const INTRO =
  'Renance is an edtech platform in Nigeria: exam preparation for JAMB, WAEC, NECO and Post-UTME with past questions and server-graded CBT mocks, the NERDC curriculum with lesson notes, the Renance AI study companion, and Renance for Schools, a school management suite. Renance is built and operated by Resolute Femi (Ariyo Oluwafemi Stephen). We collect the minimum data we need to run the service, we never sell it, and we show no advertising. This page explains, in plain language, exactly what we collect, why, who we share it with, and what you can do about it.';

type Row = { term: string; body: string };

const DATA_ROWS: Row[] = [
  {
    term: 'Account data',
    body:
      'When you register, we store your username, email address, class or exam level and your account type (student, teacher or school manager). Your password is stored only as a salted hash: nobody at Renance, including us, can read it. If you sign up with Google instead, we receive your Google account name, email address and account ID.',
  },
  {
    term: 'Study activity',
    body:
      'Your practice attempts, the answers you pick, your scores and grades, streaks, XP, badges, saved questions, spaced-repetition review queue entries, arena matches and leaderboard entries are stored against your account so your progress syncs across your devices and your review plan can schedule what to revise next.',
  },
  {
    term: 'School records',
    body:
      "In Renance for Schools, the school and its staff enter and manage student names, class assignments, attendance, continuous assessment and exam scores, fees records and student ID card details. The school that enters these records controls them; Renance processes them on the school's instructions to deliver the portal.",
  },
  {
    term: 'Emails',
    body:
      'We use your email address to deliver account emails: your verification codes, password resets, email-change confirmations and, where needed, service notices. If you email us for support, we keep your message and address so we can reply.',
  },
  {
    term: 'Technical logs',
    body:
      'Our servers keep standard request logs (IP address, browser or app user agent, timestamps) for security, rate limiting and reliability. The app also checks our app-version endpoint so it can tell you when an update is available.',
  },
  {
    term: 'Website analytics',
    body:
      'On the renance.app website (not inside the mobile app) we use Microsoft Clarity to understand how pages are used: pages viewed, taps, scroll depth, heatmaps and session recordings. Clarity masks the text you type. We use this to fix confusing pages, not to profile you for marketing.',
  },
  {
    term: 'On your device',
    body:
      'The app and site store your theme preference, your session token and copies of papers you have opened in local storage, so practice, marking and revision keep working offline. Clearing the app data or your browser storage removes these.',
  },
];

const NOT_COLLECTED =
  'We do not collect your contacts, photos, microphone audio or precise location. We do not collect or use advertising identifiers, we contain no advertising SDKs and we show no ads. We do not sell your personal data or share it with data brokers.';

const USES: string[] = [
  'Operate the service: create and secure your account, sign you in (including with Google), and keep you signed in on your devices.',
  'Deliver learning: serve past questions, grade your CBT papers on the server, build your spaced-repetition review queue, track streaks, XP and badges, and run the arena and leaderboards.',
  'Sync your progress so your attempts, results and saved questions follow you across web, Android and iOS.',
  'Send account emails: verification codes, password resets, email-change confirmations and service notices. These are transactional; we do not send marketing email blasts.',
  'Provide the AI study companion: when you ask the tutor or use the AI study tools, the question you are studying, your selected answer and related course material are processed to generate your explanations, quizzes and study plans. These conversations are kept with your account, shown only to you in your history, and deleted when you delete your account.',
  "Run Renance for Schools: deliver the school portal, the curriculum, attendance, results, fees records and ID cards on the school's instructions.",
  'Keep Renance safe: rate limiting, abuse and cheating detection, and enforcing our rules on shared accounts.',
  'Improve Renance: study aggregated, de-identified usage patterns to fix bugs, prioritize subjects and features, and keep the free tier free.',
  'Comply with the law and enforce our rights.',
];

const LEGAL_BASES: Row[] = [
  {
    term: 'Consent',
    body: 'When you choose Google Sign-In, choose a theme seed or contact us voluntarily.',
  },
  {
    term: 'Contract',
    body: 'Most processing: keeping your account, syncing your progress, grading your papers, sending your codes and delivering the school portal are all necessary to give you the service you signed up for.',
  },
  {
    term: 'Legitimate interests',
    body: 'Security logging, abuse prevention, and aggregated product improvement, always balanced against your rights.',
  },
  {
    term: 'Legal obligation',
    body: 'Where Nigerian law, a court or a regulator requires it.',
  },
];

const PARTIES: Row[] = [
  {
    term: 'Vercel Inc.',
    body: 'Hosts the renance.app website and its global CDN. Website requests, including your IP address, pass through their infrastructure.',
  },
  {
    term: 'Render',
    body: 'Hosts the Renance API servers that serve the app and website.',
  },
  {
    term: 'Neon',
    body: 'Provides the managed PostgreSQL database where Renance data is stored.',
  },
  {
    term: 'Brevo and Resend',
    body: 'Deliver our transactional emails (verification codes, password resets, account notices) to your inbox. They process your email address for this purpose only.',
  },
  {
    term: 'Google',
    body: "If you use Google Sign-In, Google authenticates you and shares your basic profile (name, email, account ID) with Renance. Google's own privacy policy covers its use of your Google account.",
  },
  {
    term: 'Microsoft Clarity',
    body: 'Website analytics (heatmaps and session recordings) on renance.app only, never inside the mobile app.',
  },
  {
    term: 'Schools',
    body: "For Renance for Schools, the school you attend or work for controls the records it enters and can view and manage its students' data within the portal.",
  },
  {
    term: 'Authorities',
    body: 'Where the law requires it, or to protect Renance, our users and the public, in the minimum amount necessary.',
  },
];

const RETENTION: string[] = [
  'Your study data (attempts, answers, results, review queue, streaks, badges) is kept for as long as your account exists, because it is the product you signed up for.',
  'You can delete your account at any time from the app: open the account sheet and choose Delete account, then confirm. This wipes, in one transaction: your profile, attempts, answers, results, sessions, streaks, awards, review queue, saved items, arena data, school memberships, entitlements and your AI conversations. An automated sweep then clears any orphaned records from backups and storage.',
  'You can also delete your account, or ask us to delete anything else, by emailing ' + CONTACT_EMAIL + ' from your registered address.',
  'Schools can remove students and their records from their portal at any time; the school controls those records.',
  'Server request logs are kept for a short window (up to 90 days) for security and then expire.',
  'Aggregated, de-identified statistics (for example, how many candidates attempted a question this month) may be retained after deletion, because they no longer identify anyone.',
];

const RIGHTS: string[] = [
  'Access: get a copy of the personal data we hold about you.',
  'Correction: fix inaccurate data, most of which you can also edit yourself in your profile.',
  'Erasure: delete your account and its data, as described above.',
  'Portability: receive your study data in a machine-readable format.',
  'Restriction and objection: ask us to pause or stop specific processing.',
  'Withdraw consent: where processing rests on consent, you can withdraw it at any time without affecting earlier processing.',
  'Complain: lodge a complaint with your data protection authority. In Nigeria that is the Nigeria Data Protection Commission (NDPC), under the Nigeria Data Protection Act 2023.',
];

const CHILDREN =
  'Renance is an exam preparation platform intended for candidates and students, typically from age 13 upwards, and for their schools and teachers. We do not knowingly create accounts for, or collect personal data from, children under 13 without the involvement of a parent, guardian or school. If you believe a child under 13 has given us personal data, email ' + CONTACT_EMAIL + ' and we will delete it. Where a school registers its students on Renance for Schools, the school is responsible for obtaining any consents required for those students.';

const TRANSFERS =
  'Renance serves students worldwide, and the providers listed above may process data in Nigeria, the United States, the European Union and other countries. Where data leaves your country, we rely on the safeguards those providers offer (including standard contractual clauses where applicable) and on TLS encryption in transit, so your data receives substantially similar protection wherever it is processed.';

const SECURITY: string[] = [
  'All traffic between your device and Renance, and between our own services, travels over HTTPS/TLS.',
  'Passwords are stored only as salted hashes and can never be read by anyone at Renance.',
  'School workspace data is scoped: a teacher only reaches the classes and records their school assigns them, and student result checking is PIN-secured.',
  'Account deletion performs a real, verified purge, not a soft flag.',
  'No service is perfectly secure; if a breach ever affects your data, we will notify you and the regulator as the law requires.',
];

const STORAGE =
  'Cookies and local storage: the site and app store a session token to keep you signed in, your theme choice, and cached papers for offline study on your own device. On the website, Microsoft Clarity sets the cookies it needs for analytics. There are no advertising or cross-site tracking cookies anywhere on Renance.';

const CHANGES =
  'If we change this policy, we will publish the new version on this page with a new last-updated date. If a change is material, for example a new category of data or a new party we share with, we will also announce it in the app or by email before it takes effect. The policy is always the current version on this page: it is a standard web page, so you can check it at any time without an account.';

export default function PrivacyPage() {
  return (
    <>
      <style
        dangerouslySetInnerHTML={{
          __html: `
.rpp-root{background:#fff;color:#111;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65;padding-top:64px;-webkit-font-smoothing:antialiased}
.rpp-wrap{max-width:860px;margin:0 auto;padding:0 22px}
.rpp-eyebrow{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8a8a8a}
.rpp-hero{padding:70px 0 48px;text-align:center;border-bottom:1px solid rgba(10,10,10,.08)}
.rpp-hero h1{font-size:clamp(32px,5vw,50px);line-height:1.05;font-weight:800;letter-spacing:-.035em;margin:14px 0 16px;color:#0a0a0a}
.rpp-updated{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:13px;color:#8a8a8a;margin-bottom:22px}
.rpp-applies{text-align:left;background:#fafafa;border:1px solid rgba(10,10,10,.12);border-left:3px solid var(--color-primary,#0a0a0a);border-radius:14px;padding:22px 26px;max-width:780px;margin:0 auto;font-size:15.5px;color:#333}
.rpp-section{padding:52px 0;border-bottom:1px solid rgba(10,10,10,.07)}
.rpp-kicker{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;color:#8a8a8a;letter-spacing:.14em;text-transform:uppercase}
.rpp-section h2{font-size:clamp(22px,3vw,30px);font-weight:800;letter-spacing:-.02em;margin:8px 0 18px;color:#0a0a0a}
.rpp-section p{margin:0 0 14px;color:#333;font-size:15.5px}
.rpp-rows{width:100%;border-collapse:collapse;font-size:15px}
.rpp-rows th,.rpp-rows td{text-align:left;padding:13px 14px;border-bottom:1px solid rgba(10,10,10,.1);vertical-align:top}
.rpp-rows th{color:#0a0a0a;font-weight:700;white-space:nowrap;width:190px;font-size:14.5px}
.rpp-rows td{color:#444}
.rpp-list{margin:0;padding-left:22px;color:#444;font-size:15.5px}
.rpp-list li{margin-bottom:11px}
.rpp-list li:last-child{margin-bottom:0}
.rpp-note{background:#fafafa;border:1px solid rgba(10,10,10,.12);border-radius:14px;padding:20px 24px;font-size:15px;color:#333;margin-top:18px}
.rpp-contact{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 24%, #0a0a0a);color:#fff;border-radius:18px;padding:32px 34px;margin:52px 0 0}
.rpp-contact h2{color:#fff;font-size:clamp(22px,3vw,28px);font-weight:800;letter-spacing:-.02em;margin:0 0 12px}
.rpp-contact p{color:#d6d6d6;font-size:15.5px;margin:0 0 10px}
.rpp-contact p:last-child{margin:0}
.rpp-contact a{color:#fff;font-weight:700;text-decoration:none;border-bottom:1.5px solid rgba(255,255,255,.6);padding-bottom:1px}
.rpp-foot{border-top:1px solid rgba(10,10,10,.1);padding:28px 0;color:#8a8a8a;font-size:13.5px;text-align:center}
.rpp-foot a{color:#555;text-decoration:none;margin:0 7px}
.rpp-foot a:hover{color:#0a0a0a}
@media(max-width:640px){.rpp-rows th{display:block;width:100%;padding-bottom:4px}.rpp-rows td{display:block;padding-top:2px}}
`,
        }}
      />
      <div className="rpp-root">
        <PillarNav />

        <section className="rpp-hero">
          <div className="rpp-wrap">
            <span className="rpp-eyebrow">Renance · Legal</span>
            <h1>Privacy Policy</h1>
            <div className="rpp-updated">Last updated: {LAST_UPDATED}</div>
            <p className="rpp-applies">{APPLIES_TO}</p>
          </div>
        </section>

        <main className="rpp-wrap">
          <section className="rpp-section">
            <span className="rpp-kicker">1</span>
            <h2>Who we are</h2>
            <p>
              Renance (&quot;Renance&quot;, &quot;we&quot;, &quot;us&quot;) is
              the edtech platform at renance.app, built and operated by
              Resolute Femi (Ariyo Oluwafemi Stephen), Nigeria. For everyone
              who uses Renance, we are the data controller of your personal
              data. If you have any question about this policy or your data,
              write to us at{' '}
              <a
                href={'mailto:' + CONTACT_EMAIL}
                style={{ color: '#0a0a0a', fontWeight: 700 }}
              >
                {CONTACT_EMAIL}
              </a>
              . You do not need an account to read this page, and nothing on
              this page requires you to sign in.
            </p>
            <p>{INTRO}</p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">2</span>
            <h2>The data Renance collects</h2>
            <table className="rpp-rows">
              <tbody>
                {DATA_ROWS.map((row) => (
                  <tr key={row.term}>
                    <th scope="row">{row.term}</th>
                    <td>{row.body}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="rpp-note">{NOT_COLLECTED}</div>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">3</span>
            <h2>How we use your data</h2>
            <p>
              We use the data above only for these purposes, and only the
              minimum each purpose needs:
            </p>
            <ul className="rpp-list">
              {USES.map((use) => (
                <li key={use.slice(0, 40)}>{use}</li>
              ))}
            </ul>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">4</span>
            <h2>Why we are allowed to (legal bases)</h2>
            <table className="rpp-rows">
              <tbody>
                {LEGAL_BASES.map((row) => (
                  <tr key={row.term}>
                    <th scope="row">{row.term}</th>
                    <td>{row.body}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p style={{ marginTop: 14 }}>
              We follow the Nigeria Data Protection Act 2023 (NDPA) and, where
              it applies to you, other data protection laws such as the EU
              General Data Protection Regulation (GDPR).
            </p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">5</span>
            <h2>Who we share data with</h2>
            <p>
              We do not sell your personal data and we do not share it with
              advertising networks or data brokers. We share it only with the
              categories of parties below, each strictly for the job listed:
            </p>
            <table className="rpp-rows">
              <tbody>
                {PARTIES.map((row) => (
                  <tr key={row.term}>
                    <th scope="row">{row.term}</th>
                    <td>{row.body}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="rpp-note">
              We never give third parties permission to use Renance data for
              their own marketing or profiling.
            </div>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">6</span>
            <h2>Data retention and deletion</h2>
            <ul className="rpp-list">
              {RETENTION.map((item) => (
                <li key={item.slice(0, 40)}>{item}</li>
              ))}
            </ul>
            <p>
              The step-by-step deletion guide, including exactly what is
              deleted and what is kept, lives at{' '}
              <Link
                href="/delete-account/"
                style={{ color: '#0a0a0a', fontWeight: 700 }}
              >
                renance.app/delete-account
              </Link>
              .
            </p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">7</span>
            <h2>Your rights</h2>
            <p>
              Wherever you live, you have the following rights over your
              personal data. To use any of them, email{' '}
              <a
                href={'mailto:' + CONTACT_EMAIL}
                style={{ color: '#0a0a0a', fontWeight: 700 }}
              >
                {CONTACT_EMAIL}
              </a>{' '}
              from your registered address, or use Delete account inside the
              app for erasure. We answer every request.
            </p>
            <ul className="rpp-list">
              {RIGHTS.map((right) => (
                <li key={right.slice(0, 40)}>{right}</li>
              ))}
            </ul>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">8</span>
            <h2>Children&apos;s privacy</h2>
            <p>{CHILDREN}</p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">9</span>
            <h2>International data transfers</h2>
            <p>{TRANSFERS}</p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">10</span>
            <h2>How we protect your data</h2>
            <ul className="rpp-list">
              {SECURITY.map((item) => (
                <li key={item.slice(0, 40)}>{item}</li>
              ))}
            </ul>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">11</span>
            <h2>Cookies and local storage</h2>
            <p>{STORAGE}</p>
          </section>

          <section className="rpp-section">
            <span className="rpp-kicker">12</span>
            <h2>Changes to this policy</h2>
            <p>{CHANGES}</p>
          </section>

          <div className="rpp-contact">
            <h2>Contact us</h2>
            <p>
              Renance, built by Resolute Femi (Ariyo Oluwafemi Stephen),
              Nigeria.
            </p>
            <p>
              Privacy questions, access requests, deletion requests or
              complaints:{' '}
              <a href={'mailto:' + CONTACT_EMAIL}>{CONTACT_EMAIL}</a>
            </p>
            <p>Policy version: {LAST_UPDATED} · renance.app/privacy</p>
          </div>
        </main>

        <footer className="rpp-foot">
          <div className="rpp-wrap">
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
