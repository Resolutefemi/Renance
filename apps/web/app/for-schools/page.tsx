import type { Metadata } from "next";
import Link from "next/link";

import PillarNav from "@/components/pillar-nav";

export const metadata: Metadata = {
  /* absolute: the brand already leads the string - the %s · Renance
   * template would double-brand the title and push "Nigeria" past
   * Google's ~60-char truncation point. */
  title: {
    absolute: "Renance for Schools | School Management Software in Nigeria",
  },
  description:
    "Renance for Schools is the school management suite inside Nigeria's educational app: the NERDC curriculum pre-installed, attendance kiosk, PIN-secured results, school fees and student ID cards, free to start on renance.app.",
  alternates: { canonical: "https://renance.app/for-schools/" },
  openGraph: {
    title: "Renance for Schools | School Management Software in Nigeria",
    description:
      "Run your school on Renance: NERDC curriculum in one tap, attendance kiosk, results with PIN-secured checking, fees and student ID cards.",
    url: "https://renance.app/for-schools/",
    siteName: "Renance",
    images: [
      {
        url: "https://renance.app/og.jpg",
        width: 1200,
        height: 630,
        alt: "Renance for Schools, the school management suite in Nigeria's educational app",
      },
    ],
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Renance for Schools | School Management Software in Nigeria",
    description:
      "NERDC curriculum, attendance, results, fees and ID cards: run your school on Renance, Nigeria's educational app.",
    images: ["https://renance.app/og.jpg"],
  },
};

const faqs = [
  {
    q: "Is Renance a school management software?",
    a: "Yes. Renance is an edtech platform in Nigeria with two sides: an educational app for candidates (JAMB, WAEC, NECO and Post-UTME past questions, including over 135,000 tertiary institution past questions, CBT mocks, lesson notes and Renance AI) and Renance for Schools, a full school management suite that covers the NERDC curriculum, syllabuses, lesson notes, attendance, results, school fees and student ID cards. Schools register free and manage everything from one desk.",
  },
  {
    q: "How much does Renance for Schools cost?",
    a: "Registering your school on Renance is free. Installing the Nigerian curriculum, enrolling students, assigning teachers to classes, attendance, notes and results are all part of the free school portal. Renance keeps premium upgrades optional, so a school can run a full term without paying.",
  },
  {
    q: "Does Renance for Schools follow the NERDC curriculum?",
    a: "Yes. The moment a school registers, the complete NERDC national curriculum (Primary 1 to 6, JSS 1 to 3 and SSS 1 to 3) is pre-installed in the school portal, including the official subject list, term-by-term schemes of work and weekly topics. Senior classes compose their subjects from Core, Art, Science and Commercial tracks.",
  },
  {
    q: "How do students check their results on Renance?",
    a: "When a term is finalized, each student receives a private 6-digit result PIN. The student or parent visits renance.app/school/check/, enters the PIN, and sees the result instantly, with positions, grades and class averages computed by the portal. No login is required to check a result.",
  },
  {
    q: "Can Renance replace my school's current management portal?",
    a: "Renance for Schools covers attendance, results and report cards, school fees, student ID cards, teacher class assignments, syllabuses and the note library. Because the same platform also gives every student past questions, CBT mocks and Renance AI, most schools use Renance as their single system instead of juggling a separate school portal and separate study apps.",
  },
  {
    q: "Is Renance for Schools available outside Nigeria?",
    a: "Renance is built in Nigeria for Nigerian schools first: the curriculum, grading patterns and exam formats all follow national standards like NERDC, WAEC, NECO and JAMB. Schools in other West African countries that follow similar schemes of work can also use it.",
  },
];

const features = [
  {
    no: "01",
    title: "The Nigerian curriculum, pre-installed",
    body: "Primary 1 to 6, JSS 1 to 3 and SSS 1 to 3 with the full NERDC subject list land in your portal the moment you register your school. Senior classes compose their subjects from Core, Art, Science and Commercial tracks. No manual setup, no data entry; one tap and the term's scheme of work is ready.",
  },
  {
    no: "02",
    title: "Syllabuses, topics and a real note library",
    body: "Every term syllabus carries its topics, the weekly scheme of work and lesson notes your teachers can edit and extend. Notes come from classnotes.ng and NERDC-sourced material, credited and kept legal, and your teachers can pour in the school's own notes any time.",
  },
  {
    no: "03",
    title: "Attendance with a classroom kiosk",
    body: "Mark the daily register in seconds, or project the attendance kiosk on the classroom screen and let pupils tap themselves present. Every term automatically rolls up into per-student attendance rates, so troublesome patterns surface before they cost a student their exam entry.",
  },
  {
    no: "04",
    title: "Results with positions and PIN-secured checking",
    body: "Fill CA1, CA2 and exam scores per subject, finalize the term, and the portal computes positions, grades and class averages automatically. Each student gets a private 6-digit PIN to check their own result at renance.app/school/check/. Parents love it, and it ends the queue at the staff room door.",
  },
  {
    no: "05",
    title: "School fees, tracked without the spreadsheets",
    body: "Record fee structures and payments per student per term, see who has paid and who has not at a glance, and stop reconciling fees from a battered notebook. The fees desk is part of the same portal as attendance and results, so a student's whole record lives in one place.",
  },
  {
    no: "06",
    title: "Student ID cards, printed from your portal",
    body: "Every enrolled student gets a clean digital identity record, and the school can generate student ID cards straight from the portal. Enrolment captures full student details, so the same data flows into attendance, results, fees and ID cards without being typed twice.",
  },
];

const steps = [
  {
    n: "1",
    t: "Register your school",
    d: "Create the school account free at renance.app/register/?audience=school. No license fee, no installation, no sales call.",
  },
  {
    n: "2",
    t: "Install the curriculum",
    d: "One tap installs the complete NERDC national curriculum: all classes, all subjects, all terms, with schemes of work.",
  },
  {
    n: "3",
    t: "Enroll your students",
    d: "Capture full student details into the portal. The same record feeds attendance, results, fees and ID cards.",
  },
  {
    n: "4",
    t: "Hand teachers their classes",
    d: "Assign classes and subjects to teachers. They take over syllabuses, notes, the attendance register and score entry.",
  },
  {
    n: "5",
    t: "Run the term",
    d: "Attendance rolls up daily, scores finalize into positions and grades, fees reconcile, and students check results with their PINs.",
  },
];

export default function ForSchoolsPage() {
  const faqJsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Renance", item: "https://renance.app/" },
          { "@type": "ListItem", position: 2, name: "For Schools", item: "https://renance.app/for-schools/" },
        ],
      },
      {
        "@type": "SoftwareApplication",
        "@id": "https://renance.app/for-schools/#school-suite",
        name: "Renance for Schools",
        alternateName: [
          "Renance School Management",
          "Renance school portal",
        ],
        applicationCategory: "BusinessApplication",
        applicationSubCategory: "School management software",
        operatingSystem: "Web, Android",
        url: "https://renance.app/for-schools/",
        description:
          "Renance for Schools is the school management suite inside Renance, Nigeria's educational app. It ships with the complete NERDC curriculum pre-installed (Primary 1 to SSS 3), term syllabuses and an editable lesson-note library, a classroom attendance kiosk, results with automatic positions and PIN-secured student checking, school fees tracking and student ID card generation. Schools register free at renance.app.",
        featureList: [
          "NERDC national curriculum pre-installed for Primary 1 to SSS 3",
          "Term syllabuses with weekly schemes of work and editable lesson notes",
          "Classroom attendance kiosk with per-student attendance rates",
          "CA and exam score entry with automatic positions, grades and class averages",
          "PIN-secured student result checking at renance.app/school/check/",
          "School fees tracking per student per term",
          "Student ID card generation",
          "Teacher class and subject assignment",
        ],
        audience: {
          "@type": "EducationalAudience",
          educationalRole: ["school owner", "principal", "teacher", "bursar"],
        },
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "NGN",
          description: "Free school registration with the curriculum, attendance, results, fees and ID card suite.",
        },
        publisher: { "@id": "https://renance.app/#organization" },
        inLanguage: "en-NG",
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
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <style
        dangerouslySetInnerHTML={{
          __html: `
.rfs-root{background:#fff;color:#111;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.65;padding-top:64px;-webkit-font-smoothing:antialiased}
.rfs-wrap{max-width:1060px;margin:0 auto;padding:0 22px}
.rfs-eyebrow{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8a8a8a}
.rfs-hero{padding:78px 0 58px;text-align:center;border-bottom:1px solid rgba(10,10,10,.08)}
.rfs-hero h1{font-size:clamp(32px,5.2vw,54px);line-height:1.06;font-weight:800;letter-spacing:-.035em;margin:14px 0 20px;color:#0a0a0a}
.rfs-hero h1 em{font-style:italic;font-weight:800}
.rfs-lede{max-width:760px;margin:0 auto 30px;font-size:17.5px;color:#444}
.rfs-ctas{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
.rfs-btn{display:inline-block;border-radius:999px;padding:13px 26px;font-weight:700;text-decoration:none;font-size:15px}
.rfs-btn-primary{background:#0a0a0a;color:#fff}
.rfs-btn-primary:hover{background:#333}
.rfs-btn-ghost{border:1px solid rgba(10,10,10,.35);color:#0a0a0a}
.rfs-btn-ghost:hover{border-color:#0a0a0a;background:#0a0a0a;color:#fff}
.rfs-section{padding:66px 0}
.rfs-section.alt{background:#fafafa}
.rfs-h2{font-size:clamp(24px,3.4vw,34px);font-weight:800;letter-spacing:-.025em;margin:0 0 10px;text-align:center;color:#0a0a0a}
.rfs-sub{max-width:680px;margin:0 auto 38px;color:#666;text-align:center;font-size:16px}
.rfs-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:16px}
.rfs-card{background:#fff;border:1px solid rgba(10,10,10,.14);border-radius:16px;padding:26px}
.rfs-card:hover{border-color:rgba(10,10,10,.3)}
.rfs-card h3{font-size:17.5px;color:#0a0a0a;margin:0 0 10px;letter-spacing:-.015em;font-weight:750}
.rfs-card p{margin:0;color:#444;font-size:15px}
.rfs-no{display:block;font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;color:#8a8a8a;letter-spacing:.16em;margin-bottom:10px}
.rfs-kicker{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:11.5px;color:#8a8a8a;letter-spacing:.14em;text-transform:uppercase;display:block;margin-bottom:8px}
.rfs-steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:14px;counter-reset:rfsstep}
.rfs-step{background:#fff;border:1px solid rgba(10,10,10,.14);border-radius:16px;padding:22px}
.rfs-step .n{display:inline-flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:10px;background:#0a0a0a;color:#fff;font-weight:800;margin-bottom:12px;font-family:"JetBrains Mono",monospace;font-size:14px}
.rfs-step h3{font-size:15.5px;color:#0a0a0a;margin:0 0 8px;font-weight:750}
.rfs-step p{margin:0;font-size:13.5px;color:#555}
.rfs-why{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:44px;max-width:880px;margin:0 auto}
.rfs-why h3{font-size:19px;color:#0a0a0a;margin:0 0 10px;font-weight:750;letter-spacing:-.01em}
.rfs-why p{margin:0 0 26px;color:#444;font-size:15.5px}
.rfs-faq{max-width:780px;margin:0 auto}
.rfs-faq details{border-bottom:1px solid rgba(10,10,10,.12);padding:2px 0}
.rfs-faq summary{font-weight:700;color:#0a0a0a;cursor:pointer;font-size:16.5px;padding:14px 0;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px}
.rfs-faq summary::-webkit-details-marker{display:none}
.rfs-faq summary::after{content:"+";font-family:"JetBrains Mono",monospace;color:#8a8a8a;font-size:18px;flex-shrink:0}
.rfs-faq details[open] summary::after{content:"-"}
.rfs-faq p{margin:0 0 18px;color:#444;font-size:15px}
.rfs-cta{background:#0a0a0a;color:#fff;padding:78px 0;text-align:center}
.rfs-cta h2{font-size:clamp(26px,3.6vw,38px);color:#fff;font-weight:800;letter-spacing:-.025em;margin:0 0 12px}
.rfs-cta p{max-width:620px;margin:0 auto 28px;color:#b5b5b5;font-size:16px}
.rfs-cta .rfs-btn-primary{background:#fff;color:#0a0a0a}
.rfs-cta .rfs-btn-primary:hover{background:#ddd}
.rfs-cta .rfs-btn-ghost{border-color:rgba(255,255,255,.45);color:#fff}
.rfs-cta .rfs-btn-ghost:hover{border-color:#fff;background:transparent}
.rfs-foot{border-top:1px solid rgba(10,10,10,.1);padding:28px 0;color:#8a8a8a;font-size:13.5px;text-align:center}
.rfs-foot a{color:#555;text-decoration:none;margin:0 7px}
.rfs-foot a:hover{color:#0a0a0a}
.rfs-note{max-width:800px;margin:38px auto 0;text-align:center;color:#8a8a8a;font-size:13.5px}
`,
        }}
      />
      <div className="rfs-root">
        <PillarNav />

        <section className="rfs-hero">
          <div className="rfs-wrap">
            <span className="rfs-eyebrow">Renance for Schools</span>
            <h1>
              School management, built into{" "}
              <em>Nigeria&apos;s educational app</em>
            </h1>
            <p className="rfs-lede">
              Renance is an edtech platform in Nigeria with two sides: the
              educational app candidates use for JAMB, WAEC and NECO past
              questions, and Renance for Schools, the school management suite
              that runs your curriculum, attendance, results, fees and ID cards
              from one desk. Register your school free and the entire NERDC
              curriculum is installed in one tap.
            </p>
            <div className="rfs-ctas">
              <Link
                className="rfs-btn rfs-btn-primary"
                href="/register/?audience=school"
              >
                Register your school free
              </Link>
              <Link className="rfs-btn rfs-btn-ghost" href="/school/check/">
                Check a result PIN
              </Link>
            </div>
          </div>
        </section>

        <section className="rfs-section">
          <div className="rfs-wrap">
            <h2 className="rfs-h2">One platform, two jobs</h2>
            <p className="rfs-sub">
              Most schools juggle three systems: a school portal for
              management, a lesson-note subscription, and a separate app
              students use to study. Renance collapses all of it into one
              edtech platform.
            </p>
            <div className="rfs-grid">
              <div className="rfs-card">
                <span className="rfs-kicker">For your students</span>
                <p>
                  Every student you enroll inherits the Renance educational app:
                  235,110+ JAMB, WAEC, NECO and Post-UTME past questions with
                  worked solutions, including over 135,000 tertiary institution
                  past questions for universities, polytechnics and colleges of
                  education. They get free server-graded CBT mock exams that
                  feel like the real exam hall, NERDC lesson notes, and the
                  Renance AI study companion. The same account that checks their
                  result also rehearses their JAMB CBT.
                </p>
              </div>
              <div className="rfs-card">
                <span className="rfs-kicker">For your school</span>
                <p>
                  The school side manages the NERDC curriculum, term syllabuses
                  and schemes of work, an editable note library your teachers
                  actually own, the daily attendance register (with a
                  projectable classroom kiosk), CA and exam score entry that
                  finalizes into positions and grades, school fees tracking,
                  and student ID card generation.
                </p>
              </div>
              <div className="rfs-card">
                <span className="rfs-kicker">For parents</span>
                <p>
                  When the term ends, each student gets a private 6-digit PIN.
                  Parents check results themselves at
                  renance.app/school/check/, with positions, grades and class
                  averages, without waiting on the school or begging a teacher.
                  Transparency becomes your school&apos;s marketing.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="rfs-section alt">
          <div className="rfs-wrap">
            <h2 className="rfs-h2">The school management suite</h2>
            <p className="rfs-sub">
              Everything Renance for Schools does, from the moment you register.
            </p>
            <div className="rfs-grid">
              {features.map((f) => (
                <div className="rfs-card" key={f.no}>
                  <span className="rfs-no">{f.no}</span>
                  <h3>{f.title}</h3>
                  <p>{f.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rfs-section">
          <div className="rfs-wrap">
            <h2 className="rfs-h2">From registration to results day</h2>
            <p className="rfs-sub">
              Five steps. The first one takes about two minutes.
            </p>
            <div className="rfs-steps">
              {steps.map((s) => (
                <div className="rfs-step" key={s.n}>
                  <span className="n">{s.n}</span>
                  <h3>{s.t}</h3>
                  <p>{s.d}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rfs-section alt">
          <div className="rfs-wrap">
            <h2 className="rfs-h2">Why schools choose Renance</h2>
            <div className="rfs-why">
              <div>
                <h3>It is Nigerian to the last comma</h3>
                <p>
                  The curriculum is the NERDC national curriculum, not a
                  foreign framework squeezed into Nigerian shoes. The exams are
                  the exams your students actually sit: JAMB&apos;s CBT layout,
                  WAEC&apos;s WASSCE format, NECO&apos;s SSCE papers. Even the
                  grading follows the CA1, CA2 and exam structure Nigerian
                  schools already use.
                </p>
                <h3>One record, everywhere</h3>
                <p>
                  Enroll a student once and that record flows into attendance,
                  results, fees and ID cards. Teachers stop retyping names;
                  bursars stop reconciling from notebooks; principals see the
                  whole school from one desk.
                </p>
              </div>
              <div>
                <h3>The study app is included</h3>
                <p>
                  A school management portal that only manages is half a
                  solution. On Renance, the school runs on the same platform the
                  students study on, so when a school enrolls its SSS 3 class,
                  those students are already inside the JAMB CBT simulator that
                  will decide their next step in life.
                </p>
                <h3>Free to start, honest to keep</h3>
                <p>
                  Registration is free, the curriculum install is free, and
                  attendance, notes and results are free. Renance keeps its
                  premium upgrades optional, which is why schools that could
                  afford anything still run their term on it.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="rfs-section">
          <div className="rfs-wrap">
            <h2 className="rfs-h2">Schools questions, answered</h2>
            <div className="rfs-faq">
              {faqs.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
            <p className="rfs-note">
              Renance is an edtech platform in Nigeria: the educational app for
              JAMB, WAEC, NECO and Post-UTME preparation, plus the school
              management suite described on this page. The only official
              website is <Link href="/">renance.app</Link>.
            </p>
          </div>
        </section>

        <section className="rfs-cta">
          <div className="rfs-wrap">
            <h2>Run your school on Renance</h2>
            <p>
              Register your school free, install the Nigerian curriculum in one
              tap, and give your teachers, students and parents one platform
              instead of five.
            </p>
            <div className="rfs-ctas">
              <Link
                className="rfs-btn rfs-btn-primary"
                href="/register/?audience=school"
              >
                Register your school free
              </Link>
              <Link className="rfs-btn rfs-btn-ghost" href="/faq/">
                Read the FAQ
              </Link>
            </div>
          </div>
        </section>

        <footer className="rfs-foot">
          <div className="rfs-wrap">
            <div>
              <Link href="/">Renance</Link>·
              <Link href="/practice/">Past questions</Link>·
              <Link href="/curriculum/">Curriculum</Link>·
              <Link href="/educational-app-in-nigeria/">Educational app</Link>·
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
