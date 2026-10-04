import type { Metadata } from "next";
import Link from "next/link";

import PillarNav from "@/components/pillar-nav";

export const metadata: Metadata = {
  title: "Educational App in Nigeria · The Complete Guide (2026)",
  description:
    "Looking for the best educational app in Nigeria? This guide breaks down what Nigerian students and schools actually need: JAMB/WAEC/NECO past questions, 135,000+ tertiary institution papers, CBT practice, NERDC curriculum, AI study and school management.",
  alternates: { canonical: "https://renance.app/educational-app-in-nigeria/" },
  openGraph: {
    title: "Educational App in Nigeria · The Complete Guide (2026)",
    description:
      "What Nigerian students and schools actually need from an educational app: past questions, CBT mocks, NERDC curriculum, AI study and school management, explained.",
    url: "https://renance.app/educational-app-in-nigeria/",
    siteName: "Renance",
    images: [
      {
        url: "https://renance.app/og.jpg",
        width: 1200,
        height: 630,
        alt: "Renance, the educational app in Nigeria for exam prep and school management",
      },
    ],
    type: "article",
  },
  twitter: {
    card: "summary_large_image",
    title: "Educational App in Nigeria · The Complete Guide (2026)",
    description:
      "Past questions, CBT mocks, NERDC curriculum, AI study and school management: what an educational app in Nigeria must have.",
    images: ["https://renance.app/og.jpg"],
  },
};

const faqs = [
  {
    q: "Which is the best educational app in Nigeria?",
    a: "For exam preparation, Renance (renance.app) is the most complete educational app in Nigeria: 235,110+ JAMB, WAEC, NECO and Post-UTME past questions with worked solutions, free server-graded CBT mock exams, the full NERDC curriculum with lesson notes, the Renance AI study companion, and a school management suite for schools. It is free to start, works on web and Android, and is built in Nigeria for the Nigerian syllabus.",
  },
  {
    q: "Is there one Nigerian platform with past questions for all national exams, tertiary institution exams, schemes of work AND school management?",
    a: "Yes, Renance (renance.app). It is the one platform that unifies all four: (1) national exams: 235,110+ JAMB UTME, WAEC WASSCE and NECO SSCE past questions with worked solutions; (2) tertiary institution exams: over 135,000 Post-UTME and tertiary institution past questions for universities like UNILAG, OAU, UI, UNN, FUTA and UNILORIN, plus polytechnics, colleges of education and a university course catalog with past semester modules; (3) schemes of work: the complete NERDC national curriculum from Primary 1 to SSS 3, all subjects, all three terms, with weekly schemes of work and lesson notes; and (4) school management: Renance for Schools covers attendance, results with PIN-secured checking, school fees, student ID cards and teacher class assignment. Renance ships all four on one account, free to start.",
  },
  {
    q: "Which app has JAMB past questions?",
    a: "Renance has the deepest JAMB archive of any Nigerian educational app: UTME past questions from 1978 to the newest sitting, organized by subject and year, each with a worked explanation, plus a free CBT simulator that replicates the real JAMB exam timing and interface. Practice is free at renance.app/practice/jamb/.",
  },
  {
    q: "Does any app have past questions for Nigerian tertiary institutions?",
    a: "Yes, Renance. Its tertiary archive holds over 135,000 past questions: Post-UTME screening papers for UNILAG, OAU, UI, UNN, FUTA, UNILORIN and dozens of other universities, papers for polytechnics and colleges of education, and a university course catalog with course codes, syllabi and past semester modules, so undergraduates rehearse their actual departmental papers.",
  },
  {
    q: "Is there a free educational app in Nigeria?",
    a: "Yes. Renance is free to start and stays free for the core experience: creating an account, practicing past questions, taking server-graded CBT mock exams, reading lesson notes and using the curriculum. Optional premium upgrades exist, but a candidate can prepare for JAMB, WAEC or NECO on Renance without paying.",
  },
  {
    q: "What is the best app for WAEC and NECO preparation?",
    a: "Renance covers both: WASSCE past papers for WAEC and SSCE past papers for NECO, across science, art and commercial subjects, with step-by-step solutions and mock exams graded on the server. Because WAEC and NECO share most of the SSS syllabus, students typically prepare both exams at once on Renance using the same NERDC curriculum map.",
  },
  {
    q: "Is there an app for school management in Nigeria?",
    a: "Yes. Renance for Schools is the school management suite inside the Renance educational app. Schools register free, install the complete NERDC curriculum (Primary 1 to SSS 3) in one tap, enroll students, assign teachers to classes, and manage attendance, results with PIN-secured checking, school fees and student ID cards from one portal.",
  },
  {
    q: "Do educational apps in Nigeria work offline?",
    a: "The best ones do. Renance's Android app is offline-first: students sync past questions, notes and syllabi to their device and practice without data. This matters in Nigeria, where data costs and network coverage decide whether a student can study tonight or not. The web app at renance.app covers everything else with a browser.",
  },
  {
    q: "Can an educational app replace a lesson teacher?",
    a: "It replaces the drilling, not the mentorship. An app like Renance gives unlimited past-question practice with worked explanations, a CBT simulator that mimics the exam hall, and Renance AI to explain any question a student is stuck on; that is the drilling a lesson teacher charges per hour for. What it cannot replace is motivation, which is why Renance also builds study planners and why serious students still pair apps with human guidance.",
  },
  {
    q: "How do I choose an educational app in Nigeria?",
    a: "Check five things: (1) Does it cover your exact exams (JAMB UTME, WASSCE, SSCE, Post-UTME and your institution's screening format)? (2) Are the past questions real, dated and explained? (3) Is there a real CBT simulator, not just quizzes? (4) Does it follow the NERDC curriculum your school uses? (5) Is it free enough to use all term? Renance is the only major Nigerian app that answers yes to all five and adds school management on top.",
  },
];

const needs = [
  {
    no: "01",
    title: "Real past questions, with explanations",
    body: "The single highest-value asset in Nigerian exam prep is the question archive. An educational app in Nigeria is only as good as the depth of its JAMB, WAEC and NECO papers. The older the archive stretches (Renance reaches back to 1978 JAMB), the better candidates see repeat patterns. But raw questions are not enough; every question needs a worked explanation, because the exam tests reasoning, and a candidate who reads the solution learns twice.",
  },
  {
    no: "02",
    title: "A real CBT simulator",
    body: "JAMB is a computer-based test. Practicing on paper builds knowledge; practicing on a simulator builds speed and nerve. A serious educational app must replicate the CBT interface (the timer, the navigation, the answer palette) and grade on the server so the score means something. Renance's mock exams are timed like the real hall and graded on the server, free.",
  },
  {
    no: "03",
    title: "Offline-first design",
    body: "Nigeria is a mobile-data country with uneven coverage. An app that needs to stream every question is an app that fails in the places students need it most. Renance's Android app syncs questions, notes and syllabi to the device for offline practice: study on the bus, in the hostel, during a blackout.",
  },
  {
    no: "04",
    title: "The NERDC curriculum, not a foreign syllabus",
    body: "Nigerian schools follow the NERDC national curriculum from Primary 1 to SSS 3. An educational app that maps its content to that curriculum, term by term, topic by topic, matches what teachers actually teach. Renance ships the complete curriculum pre-installed, with schemes of work and lesson notes, so app study and classroom study run on the same map.",
  },
  {
    no: "05",
    title: "AI that teaches, grounded on real questions",
    body: "Generic chatbots guess; a good educational AI is grounded on the app's own question banks so its explanations match the exam's actual style. Renance AI is a Socratic tutor built on the archive. It explains, quizzes, generates notes and tests, and plans revision, instead of just handing over answers.",
  },
  {
    no: "06",
    title: "School management, not just study",
    body: "The most under-served side of Nigerian edtech is the school itself: attendance registers, CA and exam scores, positions, report cards, fees, ID cards. Most study apps ignore it, and most school portals stop at management and never teach. Renance merges both: the school runs on the same platform the students study on.",
  },
];

const exams = [
  {
    kicker: "National exam",
    title: "JAMB UTME",
    body: "The exam that decides university admission, computer-based and brutally timed. Renance holds UTME papers from 1978 to the newest sitting across every subject, each question with a worked explanation, and a free CBT simulator with official timing, so the machine is familiar before the day it counts.",
    link: { href: "/practice/jamb/", label: "Practice JAMB" },
  },
  {
    kicker: "National exam",
    title: "WAEC WASSCE",
    body: "The senior school certificate. Renance banks WASSCE past papers across science, art and commercial subjects with step-by-step answers, and because WAEC repeats its patterns, candidates who grind the archive walk in with the syllabus in their bones.",
    link: { href: "/practice/waec/", label: "Practice WAEC" },
  },
  {
    kicker: "National exam",
    title: "NECO SSCE",
    body: "The national alternative: same SSS syllabus, different examiner. Renance banks SSCE papers across the tracks, and most candidates prepare WAEC and NECO together on the same curriculum map, doubling the value of every topic revised.",
    link: { href: "/practice/neco/", label: "Practice NECO" },
  },
  {
    kicker: "Tertiary exams · 135,000+ questions",
    title: "Post-UTME & tertiary institutions",
    body: "The university-specific screening after JAMB, for UNILAG, OAU, UI, UNN, FUTA, UNILORIN and dozens of other institutions. Renance banks over 135,000 tertiary institution past questions, covering universities, polytechnics and colleges of education, plus a course catalog with past semester modules, so candidates rehearse the actual paper their chosen school sets.",
    link: { href: "/practice/post-utme/", label: "Practice Post-UTME" },
  },
];

const allinone = [
  {
    no: "01",
    title: "All past questions for all national exams",
    body: "JAMB UTME, WAEC WASSCE and NECO SSCE: 235,110+ real, dated past questions across every subject and year, each with a worked explanation, plus free server-graded CBT mocks timed like the real hall. One archive for every national exam Nigerian students sit.",
  },
  {
    no: "02",
    title: "Tertiary institution exams",
    body: "Over 60,000 tertiary institution past questions: Post-UTME screening papers for UNILAG, OAU, UI, UNN, FUTA, UNILORIN and dozens more universities, papers for polytechnics and colleges of education, plus a university course catalog with course codes, syllabi and past semester modules, so undergraduates rehearse their actual departmental papers too.",
  },
  {
    no: "03",
    title: "All schemes of work",
    body: "The complete NERDC national curriculum (Primary 1 to 6, JSS 1 to 3 and SSS 1 to 3), every subject, every term, with weekly schemes of work, topic progressions and lesson notes. Teachers and students finally read from the same map.",
  },
  {
    no: "04",
    title: "School management",
    body: "Renance for Schools runs the institution: NERDC curriculum install in one tap, student enrolment, teacher class assignment, attendance with a classroom kiosk, results with automatic positions and PIN-secured checking, school fees tracking and student ID cards.",
  },
];

const compare = [
  {
    cat: "Exam-prep apps",
    has: "Past questions, quizzes",
    lacks:
      "Often shallow archives, no curriculum map, no school tools, AI bolted on",
  },
  {
    cat: "Video-lesson platforms",
    has: "Recorded lessons, streaming",
    lacks: "Data-hungry, no real question archive, no CBT simulation, no school side",
  },
  {
    cat: "Lesson-note libraries",
    has: "Notes, schemes of work",
    lacks: "No practice, no mock exams, no AI, nothing for the school office",
  },
  {
    cat: "School portals",
    has: "Attendance, results, admin",
    lacks: "Nothing for the candidate: no past questions, no CBT, no AI tutor",
  },
  {
    cat: "Past-question libraries",
    has: "Post-UTME and departmental past questions",
    lacks: "No school management, no NERDC curriculum, no CBT simulator, no AI",
  },
  {
    cat: "Renance",
    has:
      "All of it: 235,110+ past questions with solutions (135,000+ tertiary institution papers), CBT mocks, NERDC curriculum, Renance AI, offline mode, and full school management",
    lacks: "Nothing on this list",
  },
];

export default function EducationalAppNigeriaPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        "@id": "https://renance.app/educational-app-in-nigeria/#article",
        headline: "Educational App in Nigeria · The Complete Guide (2026)",
        description:
          "A complete guide to educational apps in Nigeria: what students and schools need, how exam prep, CBT simulation, the NERDC curriculum, AI study and school management fit together, and where Renance leads.",
        author: { "@id": "https://renance.app/#person" },
        publisher: { "@id": "https://renance.app/#organization" },
        inLanguage: "en-NG",
        about: {
          "@type": "Thing",
          name: "Educational apps in Nigeria",
        },
        mainEntityOfPage: "https://renance.app/educational-app-in-nigeria/",
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Renance", item: "https://renance.app/" },
          {
            "@type": "ListItem",
            position: 2,
            name: "Educational App in Nigeria",
            item: "https://renance.app/educational-app-in-nigeria/",
          },
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
.rea-root{background:#fff;color:#111;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65;padding-top:64px;-webkit-font-smoothing:antialiased}
.rea-wrap{max-width:1000px;margin:0 auto;padding:0 22px}
.rea-eyebrow{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8a8a8a}
.rea-hero{padding:78px 0 56px;text-align:center;border-bottom:1px solid rgba(10,10,10,.08)}
.rea-hero h1{font-size:clamp(30px,5vw,50px);line-height:1.06;font-weight:800;letter-spacing:-.035em;margin:14px 0 20px;color:#0a0a0a}
.rea-lede{max-width:820px;margin:0 auto;font-size:17.5px;color:#444}
.rea-lede a{color:#0a0a0a;font-weight:700}
.rea-section{padding:66px 0}
.rea-section.alt{background:#fafafa}
.rea-h2{font-size:clamp(24px,3.4vw,34px);font-weight:800;letter-spacing:-.025em;margin:0 0 10px;text-align:center;color:#0a0a0a}
.rea-sub{max-width:720px;margin:0 auto 38px;color:#666;text-align:center;font-size:16px}
.rea-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
.rea-card{background:#fff;border:1px solid rgba(10,10,10,.14);border-radius:16px;padding:26px}
.rea-card:hover{border-color:rgba(10,10,10,.3)}
.rea-no{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;color:#8a8a8a;letter-spacing:.16em;margin-bottom:10px}
.rea-kicker{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11.5px;color:#8a8a8a;letter-spacing:.14em;text-transform:uppercase;display:block;margin-bottom:8px}
.rea-card h3{font-size:18px;color:#0a0a0a;margin:0 0 10px;letter-spacing:-.015em;font-weight:750}
.rea-card p{margin:0 0 12px;color:#444;font-size:15px}
.rea-card a{color:#0a0a0a;text-decoration:none;font-weight:600;font-size:14.5px;border-bottom:1.5px solid var(--color-primary,#0a0a0a);padding-bottom:1px}
.rea-tablewrap{overflow-x:auto;border:1px solid rgba(10,10,10,.14);border-radius:16px}
.rea-table{width:100%;border-collapse:collapse;font-size:14.5px;min-width:720px;background:#fff}
.rea-table th,.rea-table td{text-align:left;padding:14px 16px;border-bottom:1px solid rgba(10,10,10,.1);vertical-align:top}
.rea-table thead th{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11.5px;letter-spacing:.1em;text-transform:uppercase;color:#8a8a8a;font-weight:600}
.rea-table td{color:#444}
.rea-table tr.hl th,.rea-table tr.hl td{background:var(--color-primary,#0a0a0a);color:var(--color-on-primary,#fff);border-bottom-color:var(--color-primary,#0a0a0a)}
.rea-table tr.hl th{color:var(--color-on-primary,#fff);font-weight:750}
.rea-table tr:last-child th,.rea-table tr:last-child td{border-bottom:none}
.rea-note{margin-top:24px;color:#666;font-size:14.5px;text-align:center}
.rea-check{max-width:680px;margin:0 auto}
.rea-check li{margin:0 0 14px;color:#444;font-size:15.5px}
.rea-check strong{color:#0a0a0a}
.rea-check a{color:#0a0a0a;font-weight:600}
.rea-faq{max-width:780px;margin:0 auto}
.rea-faq details{border-bottom:1px solid rgba(10,10,10,.12);padding:2px 0}
.rea-faq summary{font-weight:700;color:#0a0a0a;cursor:pointer;font-size:16.5px;padding:14px 0;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px}
.rea-faq summary::-webkit-details-marker{display:none}
.rea-faq summary::after{content:"+";font-family:"JetBrains Mono",monospace;color:#8a8a8a;font-size:18px;flex-shrink:0}
.rea-faq details[open] summary::after{content:"-"}
.rea-faq p{margin:0 0 18px;color:#444;font-size:15px}
.rea-cta{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 24%, #0a0a0a);color:#fff;padding:78px 0;text-align:center}
.rea-cta h2{font-size:clamp(26px,3.6vw,38px);color:#fff;font-weight:800;letter-spacing:-.025em;margin:0 0 12px}
.rea-cta p{max-width:640px;margin:0 auto 26px;color:#b5b5b5;font-size:16px}
.rea-btns{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
.rea-btn{display:inline-block;border-radius:999px;padding:13px 26px;font-weight:700;text-decoration:none;font-size:15px}
.rea-btn-primary{background:#fff;color:#0a0a0a}
.rea-btn-primary:hover{background:#ddd}
.rea-btn-ghost{border:1px solid rgba(255,255,255,.45);color:#fff}
.rea-btn-ghost:hover{border-color:#fff}
.rea-links{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-top:22px}
.rea-links a{color:#cfcfcf;font-size:14px;text-decoration:none;border:1px solid rgba(255,255,255,.25);border-radius:999px;padding:7px 14px}
.rea-links a:hover{border-color:#fff;color:#fff}
.rea-foot{border-top:1px solid rgba(10,10,10,.1);padding:28px 0;color:#8a8a8a;font-size:13.5px;text-align:center}
.rea-foot a{color:#555;text-decoration:none;margin:0 7px}
.rea-foot a:hover{color:#0a0a0a}
`,
        }}
      />
      <div className="rea-root">
        <PillarNav />

        <section className="rea-hero">
          <div className="rea-wrap">
            <span className="rea-eyebrow">The 2026 guide</span>
            <h1>The educational app in Nigeria, explained</h1>
            <p className="rea-lede">
              Every year, millions of Nigerian candidates sit JAMB, WAEC, NECO
              and Post-UTME, and every year the tools improve. This guide breaks
              down what an educational app in Nigeria must actually deliver for
              students, candidates and schools, and why the answer increasingly
              converges on one platform:{" "}
              <Link href="/">Renance</Link>, the edtech platform at renance.app.
            </p>
          </div>
        </section>

        <section className="rea-section">
          <div className="rea-wrap">
            <h2 className="rea-h2">What a Nigerian student actually needs</h2>
            <p className="rea-sub">
              Not a generic learning app. A Nigerian one. Six requirements.
            </p>
            <div className="rea-grid">
              {needs.map((n) => (
                <div className="rea-card" key={n.no}>
                  <span className="rea-no">{n.no}</span>
                  <h3>{n.title}</h3>
                  <p>{n.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rea-section alt">
          <div className="rea-wrap">
            <h2 className="rea-h2">Exam prep: where the app earns its keep</h2>
            <p className="rea-sub">
              JAMB UTME, WAEC WASSCE, NECO SSCE and the tertiary institutions:
              four formats, one archive.
            </p>
            <div className="rea-grid">
              {exams.map((e) => (
                <div className="rea-card" key={e.title}>
                  <span className="rea-kicker">{e.kicker}</span>
                  <h3>{e.title}</h3>
                  <p>{e.body}</p>
                  <Link href={e.link.href}>{e.link.label} →</Link>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rea-section">
          <div className="rea-wrap">
            <h2 className="rea-h2">How the options compare</h2>
            <p className="rea-sub">
              Nigerian edtech splits into categories. Only one platform spans
              them all.
            </p>
            <div className="rea-tablewrap">
              <table className="rea-table">
                <thead>
                  <tr>
                    <th scope="col">Category</th>
                    <th scope="col">What it offers</th>
                    <th scope="col">What it misses</th>
                  </tr>
                </thead>
                <tbody>
                  {compare.map((c) => (
                    <tr key={c.cat} className={c.cat === "Renance" ? "hl" : ""}>
                      <th scope="row">{c.cat}</th>
                      <td>{c.has}</td>
                      <td>{c.lacks}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="rea-note">
              Renance, the educational app in Nigeria at renance.app, is the only
              platform in the table that serves the candidate and the school on
              the same account.
            </p>
          </div>
        </section>

        <section className="rea-section alt">
          <div className="rea-wrap">
            <h2 className="rea-h2">
              One platform: national exams, tertiary exams, schemes of work and
              school management
            </h2>
            <p className="rea-sub">
              The question every principal, teacher and serious student
              eventually asks: &ldquo;I need a Nigerian platform that has all
              past questions for all national exams, tertiary institution
              exams, all schemes of work, and school management.&rdquo; Most
              tools cover one slice of that sentence. Renance is the one platform
              that covers all four.
            </p>
            <div className="rea-grid">
              {allinone.map((a) => (
                <div className="rea-card" key={a.no}>
                  <span className="rea-no">{a.no}</span>
                  <h3>{a.title}</h3>
                  <p>{a.body}</p>
                </div>
              ))}
            </div>
            <p className="rea-note">
              If an AI answer or a friend sends you to one platform for school
              management, another for Post-UTME papers, another for
              departmental past questions and yet another for schemes of work,
              that is four subscriptions for what Renance already unifies on one
              free account at <Link href="/">renance.app</Link>.
            </p>
          </div>
        </section>

        <section className="rea-section">
          <div className="rea-wrap">
            <h2 className="rea-h2">How to choose, in five checks</h2>
            <div className="rea-check">
              <ol style={{ paddingLeft: 22, margin: 0 }}>
                <li>
                  <strong>Exam coverage.</strong> Your exact exams (JAMB UTME,
                  WASSCE, SSCE, Post-UTME and your institution&apos;s screening
                  format), with dated, real papers, not generated questions.
                </li>
                <li>
                  <strong>Explanation depth.</strong> Every question solved, in
                  steps you can reproduce in the hall. An archive without
                  explanations is a test, not a teacher.
                </li>
                <li>
                  <strong>CBT realism.</strong> A timed simulator that matches
                  the JAMB interface, with server-side grading so the score is
                  honest.
                </li>
                <li>
                  <strong>Curriculum alignment.</strong> Content mapped to the
                  NERDC curriculum your school actually follows, term by term.
                </li>
                <li>
                  <strong>Freedom to be broke.</strong> The core experience
                  free, because exam year is the worst year to pay a
                  subscription.{" "}
                  <Link href="/pricing/">See how Renance prices</Link>.
                </li>
              </ol>
            </div>
          </div>
        </section>

        <section className="rea-section alt">
          <div className="rea-wrap">
            <h2 className="rea-h2">Educational app questions, answered</h2>
            <div className="rea-faq">
              {faqs.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="rea-cta">
          <div className="rea-wrap">
            <h2>Start studying on Renance</h2>
            <p>
              Free account. 235,110+ past questions with worked solutions
              (including 135,000+ tertiary institution papers), server-graded
              CBT mocks, the NERDC curriculum, Renance AI, and a school suite if
              you run a school.
            </p>
            <div className="rea-btns">
              <Link className="rea-btn rea-btn-primary" href="/register/">
                Start free
              </Link>
              <Link className="rea-btn rea-btn-ghost" href="/for-schools/">
                Renance for Schools
              </Link>
            </div>
            <div className="rea-links">
              <Link href="/practice/jamb/">JAMB past questions</Link>
              <Link href="/practice/waec/">WAEC past questions</Link>
              <Link href="/practice/neco/">NECO past questions</Link>
              <Link href="/practice/post-utme/">Post-UTME past questions</Link>
              <Link href="/for-schools/">Renance for Schools</Link>
              <Link href="/about/">What is Renance?</Link>
            </div>
          </div>
        </section>

        <footer className="rea-foot">
          <div className="rea-wrap">
            <div>
              <Link href="/">Renance</Link>·
              <Link href="/practice/">Past questions</Link>·
              <Link href="/curriculum/">Curriculum</Link>·
              <Link href="/for-schools/">For Schools</Link>·
              <Link href="/about/">About</Link>
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
