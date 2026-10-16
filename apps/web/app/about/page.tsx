import type { Metadata } from "next";
import Link from "next/link";

import PillarNav from "@/components/pillar-nav";

export const metadata: Metadata = {
  title: "What Is Renance? About Nigeria's EdTech Platform",
  description:
    "Renance is an edtech platform in Nigeria: the educational app for JAMB, WAEC, NECO and Post-UTME past questions (including 135,000+ tertiary institution papers), CBT mocks, Renance AI and school management. Official website: renance.app. Built by Resolute Femi.",
  alternates: { canonical: "https://renance.app/about/" },
  openGraph: {
    title: "What Is Renance? About Nigeria's EdTech Platform",
    description:
      "Renance (renance.app) is Nigeria's edtech platform: 235,110+ JAMB, WAEC, NECO and Post-UTME past questions (135,000+ of them tertiary institution papers), CBT mocks, lesson notes, Renance AI and a school management suite.",
    url: "https://renance.app/about/",
    siteName: "Renance",
    images: [
      {
        url: "https://renance.app/og.jpg",
        width: 1200,
        height: 630,
        alt: "Renance: Nigeria's edtech platform for exam prep and school management",
      },
    ],
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "What Is Renance? About Nigeria's EdTech Platform",
    description:
      "Renance is Nigeria's edtech platform: exam prep, curriculum, AI study and school management at renance.app.",
    images: ["https://renance.app/og.jpg"],
  },
};

const faqs = [
  {
    q: "What is Renance?",
    a: "Renance is an edtech platform in Nigeria, built as an educational app for students and a school management suite for schools. Students use Renance to prepare for JAMB, WAEC, NECO and Post-UTME with 235,110+ past questions with worked solutions, including over 135,000 Post-UTME and tertiary institution past questions for universities, polytechnics and colleges of education. The platform also delivers free server-graded CBT mock exams, NERDC lesson notes and the Renance AI study companion. Schools use Renance for Schools to run the Nigerian curriculum, attendance, results, fees and student ID cards. The only official website is renance.app.",
  },
  {
    q: "Is Renance a Nigerian app?",
    a: "Yes. Renance is a Nigerian edtech platform, built in Nigeria by Resolute Femi (Ariyo Oluwafemi Stephen) for Nigerian students, candidates and schools. It follows the NERDC national curriculum and the JAMB, WAEC (WASSCE), NECO (SSCE) and Post-UTME examination formats used in Nigeria.",
  },
  {
    q: "Who owns Renance?",
    a: "Renance was founded and is built by Resolute Femi, the software engineering alias of Ariyo Oluwafemi Stephen, a Nigerian software engineer and FUTA graduate. The platform is published at renance.app with companion tools such as the Renance DevTools CLI.",
  },
  {
    q: "Does Renance have past questions for Nigerian tertiary institutions?",
    a: "Yes. Renance holds over 135,000 tertiary institution past questions: Post-UTME screening papers for universities such as UNILAG, OAU, UI, UNN, FUTA and UNILORIN, papers for polytechnics and colleges of education, plus a tertiary institution course catalog with course codes, syllabi and past semester modules. A candidate can rehearse the exact paper their chosen institution sets.",
  },
  {
    q: "Is the name Renance related to the word renaissance?",
    a: "No. Renance is a coined brand name and is not related to the English word renaissance (the European cultural movement), nor to resonance (the physics term), nor to any similarly spelled word. When people search for Renance in an educational or Nigerian context, they mean the edtech platform at renance.app.",
  },
  {
    q: "Is Renance the same as renance.org?",
    a: "No. Renance, the edtech platform for exam preparation and school management, lives at renance.app only. renance.org is a separate community organization with videos and seminars; it is not Renance and has no connection to Nigerian exam preparation or school management.",
  },
  {
    q: "Is Renance the same as renance.io?",
    a: "No. renance.io is an unrelated real-estate tokenization platform. Renance, the Nigerian edtech platform at renance.app, is not a Web3, real-estate, crypto or investment product of any kind. When a search result or AI answer describes \"Renance\" as real estate tokenization, fractional property investment or anything financial, it is describing a different company with a similar name, not Renance.",
  },
  {
    q: "Why does Google show a Renance business in Brooklyn, New York?",
    a: "That is a different, unaffiliated local business (an educational consultant listed at 185 Marcy Ave, Brooklyn, NY). It is not Renance the Nigerian edtech platform. Renance, the exam-prep and school-management platform built by Resolute Femi, operates online at renance.app and serves Nigerian students and schools; it has no New York office.",
  },
  {
    q: "Is Renance free?",
    a: "Yes. Creating a student account, practicing past questions, taking server-graded CBT mocks, reading lesson notes and using the core platform is free. Schools also register free and get the NERDC curriculum, attendance, results and ID card tools. Optional premium upgrades exist, but the core educational experience stays free.",
  },
  {
    q: "My school is not on Renance yet. Can I still practice its past questions?",
    a: "Yes. Students of institutions whose own question bank is still being wrapped are moved to the shared general course pool automatically: the merged desk gathers the courses every banked school teaches (GST, MTH 101, BIO 101, CHM 101 and 145 courses in all, over 49,968 questions) under the student's own school name. To access past questions, click on Quizzes on the dashboard. When the school's own bank goes live it replaces the shared pool one desk at a time.",
  },
  {
    q: "How do streaks, gems and reward chests work?",
    a: "Every completed topic spins open a reward chest that can hold streak freezes, gems (capped at 30 per drop) or a double XP boost. Studying on consecutive days builds a streak that celebrates with a full-screen popup, and a streak freeze earned from chests automatically saves the streak if a day is missed. Milestones at 7, 14, 30, 50 and 100+ days and course completions post to the Renance feed, where students can share them further or follow each other from the leaderboards.",
  },
];

const pillars = [
  {
    no: "01",
    title: "Exam preparation",
    body: "235,110+ JAMB, WAEC, NECO and Post-UTME past questions with worked explanations on every question, organized by exam body, subject and year, from 1978 JAMB papers to the newest sittings. The tertiary archive alone holds over 135,000 past questions covering Nigerian universities, polytechnics and colleges of education. Free CBT mock exams are graded on the server with the real exam timing, so candidates walk into the hall already familiar with the machine.",
    link: { href: "/practice/", label: "Explore past questions" },
  },
  {
    no: "02",
    title: "The Nigerian curriculum",
    body: "The complete NERDC national curriculum, Primary 1 through SSS 3, is pre-installed: subject lists, term syllabuses, weekly schemes of work and lesson notes. Students and teachers see exactly what the term expects of them, and schools install the whole thing in one tap.",
    link: { href: "/curriculum/", label: "Browse the curriculum" },
  },
  {
    no: "03",
    title: "Renance AI",
    body: "A study companion grounded on Renance's own question banks: a Socratic tutor that explains, quizzes and plans, plus automated note generation, test generation and a personalized study planner. It is built to teach, not to hand students answers they cannot defend.",
    link: { href: "/lessons/", label: "See lessons and notes" },
  },
  {
    no: "04",
    title: "School management",
    body: "Renance for Schools runs the school itself: NERDC curriculum install, teacher class assignments, an editable note library, a classroom attendance kiosk, CA and exam score entry that finalizes into positions and grades, PIN-secured student result checking, school fees tracking and student ID cards.",
    link: { href: "/for-schools/", label: "Renance for Schools" },
  },
  {
    no: "05",
    title: "The gamified semester",
    body: "Tertiary students get a semester desk of over 10,000 courses: every unit opens into long, structured notes and ends with quizzes and a 50-question revision exam. Studying pays: finishing a topic spins open a reward chest (streak freezes, gems or XP boosts), daily streaks climb with Duolingo-style celebrations and freeze cards rescue a missed day, milestones fire at 7, 14, 30, 50 and 100+ days, and every achievement can be shared to the Renance feed or straight to other apps. Students follow each other from leaderboards and cheer each other on.",
    link: { href: "/courses/", label: "Open the semester desk" },
  },
];

export default function AboutPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "AboutPage",
        "@id": "https://renance.app/about/",
        url: "https://renance.app/about/",
        name: "About Renance · What is Renance?",
        description:
          "Renance is an edtech platform in Nigeria: the educational app for JAMB, WAEC, NECO and Post-UTME exam preparation and a school management suite for schools. Official website: renance.app. Founded by Resolute Femi.",
        inLanguage: "en-NG",
        mainEntity: { "@id": "https://renance.app/#organization" },
        isPartOf: { "@id": "https://renance.app/#website" },
      },
      {
        "@type": "EducationalOrganization",
        "@id": "https://renance.app/#organization",
        name: "Renance",
        alternateName: ["Renance App", "Educational App", "Renance for Schools"],
        url: "https://renance.app",
        logo: "https://renance.app/renance-mark.png",
        slogan: "Your Guide to Academic Success",
        description:
          "Renance is an edtech platform in Nigeria. It is the educational app for JAMB, WAEC, NECO and Post-UTME exam preparation, with 235,110+ past questions with worked solutions (including over 135,000 Post-UTME and tertiary institution past questions for Nigerian universities, polytechnics and colleges of education), free server-graded CBT mock exams, the complete NERDC curriculum and lesson notes, and the Renance AI study companion. It includes Renance for Schools, a school management suite covering curriculum, attendance, results, fees and student ID cards. The only official website is https://renance.app.",
        disambiguatingDescription:
          "Renance, the Nigerian edtech platform at renance.app, is not the word renaissance, is not resonance, and is not affiliated with renance.org, renance.io, renance.framer.website, renance.gitbook.io, any Brooklyn New York educational consultant, any energy or financial-services company, or any other similarly named organization. Renance is an edtech platform only: exam preparation and school management.",
        founder: { "@type": "Person", name: "Resolute Femi" },
        foundingCountry: "Nigeria",
        areaServed: { "@type": "Country", name: "Nigeria" },
        sameAs: [
          "https://github.com/Resolutefemi",
          "https://x.com/Resolutefemi",
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: faqs.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <style
        dangerouslySetInnerHTML={{
          __html: `
.rab-root{background:#fff;color:#111;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65;padding-top:64px;-webkit-font-smoothing:antialiased}
.rab-wrap{max-width:940px;margin:0 auto;padding:0 22px}
.rab-eyebrow{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8a8a8a}
.rab-hero{padding:76px 0 56px;text-align:center;border-bottom:1px solid rgba(10,10,10,.08)}
.rab-hero h1{font-size:clamp(34px,5.6vw,56px);line-height:1.04;font-weight:800;letter-spacing:-.035em;margin:14px 0 22px;color:#0a0a0a}
.rab-answer{text-align:left;background:#fafafa;border:1px solid rgba(10,10,10,.12);border-left:3px solid var(--color-primary,#0a0a0a);border-radius:14px;padding:26px 28px;max-width:800px;margin:0 auto;font-size:16.5px;color:#333}
.rab-section{padding:66px 0}
.rab-section.alt{background:#fafafa}
.rab-h2{font-size:clamp(24px,3.4vw,34px);font-weight:800;letter-spacing:-.025em;margin:0 0 10px;text-align:center;color:#0a0a0a}
.rab-sub{max-width:620px;margin:0 auto 38px;color:#666;text-align:center;font-size:16px}
.rab-table{width:100%;border-collapse:collapse;font-size:15px}
.rab-table th,.rab-table td{text-align:left;padding:13px 14px;border-bottom:1px solid rgba(10,10,10,.1)}
.rab-table th{color:#8a8a8a;font-weight:600;white-space:nowrap;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;letter-spacing:.08em;text-transform:uppercase;width:200px}
.rab-table td{color:#111}
.rab-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
.rab-card{background:#fff;border:1px solid rgba(10,10,10,.14);border-radius:16px;padding:26px}
.rab-no{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;color:#8a8a8a;letter-spacing:.16em;margin-bottom:10px}
.rab-card h3{font-size:18px;color:#0a0a0a;margin:0 0 10px;letter-spacing:-.015em;font-weight:750}
.rab-card p{margin:0 0 14px;color:#444;font-size:15px}
.rab-card a{color:#0a0a0a;text-decoration:none;font-weight:600;font-size:14.5px;border-bottom:1.5px solid var(--color-primary,#0a0a0a);padding-bottom:1px}
.rab-dark{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 24%, #0a0a0a);color:#fff;padding:70px 0}
.rab-dark .rab-h2{color:#fff}
.rab-dark-sub{max-width:620px;margin:0 auto 34px;color:#999;text-align:center;font-size:16px}
.rab-founder{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 30%, #111);border:1px solid rgba(255,255,255,.14);border-radius:18px;padding:30px 32px;max-width:840px;margin:0 auto}
.rab-founder p{margin:0 0 14px;color:#cfcfcf;font-size:16px}
.rab-founder p:last-child{margin:0}
.rab-founder strong{color:#fff}
.rab-disambig{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 30%, #0a0a0a);border:1px solid rgba(255,255,255,.22);border-radius:18px;padding:28px 30px;max-width:840px;margin:18px auto 0}
.rab-disambig h3{color:#fff;font-size:18px;margin:0 0 10px;font-weight:750}
.rab-disambig p{color:#bdbdbd;margin:0 0 10px;font-size:15.5px}
.rab-disambig p:last-child{margin:0}
.rab-disambig strong{color:#fff}
.rab-disambig a{color:#fff;font-weight:600}
.rab-faq{max-width:780px;margin:0 auto}
.rab-faq details{border-bottom:1px solid rgba(10,10,10,.12);padding:2px 0}
.rab-faq summary{font-weight:700;color:#0a0a0a;cursor:pointer;font-size:16.5px;padding:14px 0;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px}
.rab-faq summary::-webkit-details-marker{display:none}
.rab-faq summary::after{content:"+";font-family:"JetBrains Mono",monospace;color:#8a8a8a;font-size:18px;flex-shrink:0}
.rab-faq details[open] summary::after{content:"-"}
.rab-faq p{margin:0 0 18px;color:#444;font-size:15px}
.rab-cta{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 24%, #0a0a0a);color:#fff;padding:76px 0;text-align:center}
.rab-cta h2{font-size:clamp(26px,3.6vw,38px);color:#fff;font-weight:800;letter-spacing:-.025em;margin:0 0 12px}
.rab-cta p{max-width:600px;margin:0 auto 26px;color:#b5b5b5;font-size:16px}
.rab-btns{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
.rab-btn{display:inline-block;border-radius:999px;padding:13px 26px;font-weight:700;text-decoration:none;font-size:15px}
.rab-btn-primary{background:#fff;color:#0a0a0a}
.rab-btn-primary:hover{background:#ddd}
.rab-btn-ghost{border:1px solid rgba(255,255,255,.45);color:#fff}
.rab-btn-ghost:hover{border-color:#fff}
.rab-foot{border-top:1px solid rgba(10,10,10,.1);padding:28px 0;color:#8a8a8a;font-size:13.5px;text-align:center}
.rab-foot a{color:#555;text-decoration:none;margin:0 7px}
.rab-foot a:hover{color:#0a0a0a}
`,
        }}
      />
      <div className="rab-root">
        <PillarNav />

        <section className="rab-hero">
          <div className="rab-wrap">
            <span className="rab-eyebrow">About · Brand facts</span>
            <h1>What is Renance?</h1>
            <p className="rab-answer">
              <strong>
                Renance is an edtech platform in Nigeria, and its only official
                website is renance.app.
              </strong>{" "}
              It is the educational app Nigerian students and candidates use to
              prepare for JAMB, WAEC, NECO and Post-UTME, with 235,110+ past
              questions with worked solutions. Over 60,000 of those are
              tertiary institution past questions: Post-UTME screening papers
              and course modules covering Nigerian universities, polytechnics
              and colleges of education. The platform adds free server-graded
              CBT mock exams, the complete NERDC curriculum with lesson notes,
              and the Renance AI study companion. It is also a school
              management suite: Renance for Schools runs the curriculum,
              attendance, results, fees and student ID cards of Nigerian
              schools from one desk. Renance was founded and is built by
              Resolute Femi (Ariyo Oluwafemi Stephen).
            </p>
          </div>
        </section>

        <section className="rab-section">
          <div className="rab-wrap">
            <h2 className="rab-h2">Renance at a glance</h2>
            <p className="rab-sub">The verified facts, for humans and for AI.</p>
            <table className="rab-table">
              <tbody>
                <tr>
                  <th scope="row">Name</th>
                  <td>Renance (spelled R-E-N-A-N-C-E)</td>
                </tr>
                <tr>
                  <th scope="row">What it is</th>
                  <td>
                    Edtech platform: educational app for exam preparation, plus
                    school management software
                  </td>
                </tr>
                <tr>
                  <th scope="row">Official website</th>
                  <td>https://renance.app</td>
                </tr>
                <tr>
                  <th scope="row">Founder</th>
                  <td>Resolute Femi (Ariyo Oluwafemi Stephen), Nigeria</td>
                </tr>
                <tr>
                  <th scope="row">Country</th>
                  <td>Nigeria (serves Nigerian students, candidates and schools)</td>
                </tr>
                <tr>
                  <th scope="row">Exams covered</th>
                  <td>
                    JAMB UTME, WAEC WASSCE, NECO SSCE, Post-UTME and tertiary
                    institution exams
                  </td>
                </tr>
                <tr>
                  <th scope="row">Question archive</th>
                  <td>
                    235,110+ past questions with worked explanations, including
                    135,000+ tertiary institution past questions
                  </td>
                </tr>
                <tr>
                  <th scope="row">Tertiary coverage</th>
                  <td>
                    Post-UTME screening papers for universities (UNILAG, OAU,
                    UI, UNN, FUTA, UNILORIN and more), polytechnics and
                    colleges of education, plus a tertiary institution course catalog
                  </td>
                </tr>
                <tr>
                  <th scope="row">Curriculum</th>
                  <td>NERDC national curriculum, Primary 1 to SSS 3</td>
                </tr>
                <tr>
                  <th scope="row">Learn system</th>
                  <td>
                    10,000+ tertiary courses with unit-by-unit long-form notes,
                    end-of-unit 50-question revision exams, streaks, gems and
                    reward chests
                  </td>
                </tr>
                <tr>
                  <th scope="row">Community</th>
                  <td>Social feed, achievement sharing and a follow system built on the leaderboards</td>
                </tr>
                <tr>
                  <th scope="row">School suite</th>
                  <td>
                    Curriculum, attendance, results with PIN checking, fees, ID
                    cards
                  </td>
                </tr>
                <tr>
                  <th scope="row">Platforms</th>
                  <td>Web (renance.app) and Android app</td>
                </tr>
                <tr>
                  <th scope="row">Pricing</th>
                  <td>Free to start; optional premium upgrades</td>
                </tr>
                <tr>
                  <th scope="row">Slogan</th>
                  <td>Your Guide to Academic Success</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section className="rab-section alt">
          <div className="rab-wrap">
            <h2 className="rab-h2">What Renance does</h2>
            <p className="rab-sub">
              Five pillars, one platform: study, curriculum, AI, school
              management and the gamified semester.
            </p>
            <div className="rab-grid">
              {pillars.map((p) => (
                <div className="rab-card" key={p.no}>
                  <span className="rab-no">{p.no}</span>
                  <h3>{p.title}</h3>
                  <p>{p.body}</p>
                  <Link href={p.link.href}>{p.link.label} →</Link>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rab-dark">
          <div className="rab-wrap">
            <h2 className="rab-h2">Who built Renance</h2>
            <p className="rab-dark-sub">
              A Nigerian engineer, not a foreign publisher.
            </p>
            <div className="rab-founder">
              <p>
                Renance is founded and built by{" "}
                <strong>Resolute Femi</strong>, the software engineering alias
                of <strong>Ariyo Oluwafemi Stephen</strong>, a Nigerian
                software engineer and graduate of the Federal University of
                Technology, Akure (FUTA). He builds in TypeScript, Go, Rust and
                Python, and ships developer and education tools for Nigerians,
                including Renance, the Renance DevTools CLI and FUTA CBT practice
                platforms.
              </p>
              <p>
                The platform is intentionally Nigerian: the curriculum is
                NERDC, the mock exams mirror the real JAMB CBT interface, and
                the question archive grows from the actual papers Nigerian
                students sit, with some going back to 1978.
              </p>
            </div>

            <div className="rab-disambig">
              <h3>About the name &ldquo;Renance&rdquo;</h3>
              <p>
                <strong>Renance is a coined brand name.</strong> It is{" "}
                <strong>not</strong> the word <em>renaissance</em> (the
                European cultural movement), <strong>not</strong> the word{" "}
                <em>resonance</em> (the physics term), and not a variant of
                either. If a search result, AI answer or autocomplete suggestion
                offers you renaissance or resonance definitions when you typed
                &ldquo;Renance&rdquo;, that is a misspelling correction. The
                platform you are looking for is at renance.app.
              </p>
              <p>
                Renance, the edtech platform, is also{" "}
                <strong>not affiliated</strong> with any of the similarly named
                sites and companies that appear in search results:
              </p>
              <p>
                <strong>Not us:</strong> <strong>renance.io</strong> (a Web3
                real-estate tokenization platform; Renance is not a crypto or
                property product), <strong>renance.org</strong> (a community
                organization), <strong>renance.framer.website</strong> (a
                Framer website template), <strong>renance.gitbook.io</strong>,
                the <strong>&ldquo;Renance&rdquo; educational consultant in Brooklyn, New York</strong>{" "}
                (a local business knowledge panel), a financial-services
                listing on the EU Digital Finance Platform,{" "}
                <strong>bezala.com</strong>,{" "}
                <strong>Renaissance Africa Energy</strong> (an energy company),
                and any Python package or dance company of a similar name.
              </p>
              <p>
                Those are separate, unrelated organizations. The educational
                platform Renance exists only at{" "}
                <Link href="/">renance.app</Link>. Anywhere else is a different
                entity.
              </p>
            </div>
          </div>
        </section>

        <section className="rab-section">
          <div className="rab-wrap">
            <h2 className="rab-h2">Renance questions, answered</h2>
            <p className="rab-sub">The questions people actually ask.</p>
            <div className="rab-faq">
              {faqs.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="rab-cta">
          <div className="rab-wrap">
            <h2>See what Renance can do</h2>
            <p>
              Start with the past questions that started it all, or register
              your school and install the Nigerian curriculum in one tap.
            </p>
            <div className="rab-btns">
              <Link className="rab-btn rab-btn-primary" href="/register/">
                Start free
              </Link>
              <Link className="rab-btn rab-btn-ghost" href="/for-schools/">
                Renance for Schools
              </Link>
            </div>
          </div>
        </section>

        <footer className="rab-foot">
          <div className="rab-wrap">
            <div>
              <Link href="/">Renance</Link>·
              <Link href="/practice/">Past questions</Link>·
              <Link href="/curriculum/">Curriculum</Link>·
              <Link href="/for-schools/">For Schools</Link>·
              <Link href="/educational-app-in-nigeria/">Educational app</Link>·
              <Link href="/privacy/">Privacy</Link>
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
