---
marp: true
theme: default
paginate: true
size: 16:9
backgroundColor: #070B16
color: #FFFFFF
style: |
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap');
  
  section {
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    padding: 60px 80px;
    background-color: #070B16;
    background-image: radial-gradient(circle at 80% 20%, rgba(16, 185, 129, 0.08) 0%, transparent 60%),
                      radial-gradient(circle at 20% 80%, rgba(56, 189, 248, 0.08) 0%, transparent 60%);
    color: #F8FAFC;
    font-size: 20px;
  }
  
  h1 {
    font-size: 54px;
    font-weight: 800;
    color: #FFFFFF;
    letter-spacing: -0.02em;
    margin-bottom: 12px;
  }
  
  h2 {
    font-size: 38px;
    font-weight: 700;
    color: #FFFFFF;
    letter-spacing: -0.02em;
    margin-bottom: 8px;
  }
  
  h3 {
    font-size: 24px;
    font-weight: 600;
    color: #38BDF8;
    margin-bottom: 8px;
  }
  
  .badge {
    display: inline-block;
    padding: 4px 14px;
    border-radius: 9999px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    background: rgba(16, 185, 129, 0.15);
    color: #10B981;
    border: 1px solid rgba(16, 185, 129, 0.4);
    margin-bottom: 16px;
  }
  
  .badge.cyan {
    background: rgba(56, 189, 248, 0.15);
    color: #38BDF8;
    border-color: rgba(56, 189, 248, 0.4);
  }
  
  .badge.amber {
    background: rgba(245, 158, 11, 0.15);
    color: #F59E0B;
    border-color: rgba(245, 158, 11, 0.4);
  }
  
  .badge.rose {
    background: rgba(244, 63, 94, 0.15);
    color: #F43F5E;
    border-color: rgba(244, 63, 94, 0.4);
  }

  .grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 32px;
    margin-top: 24px;
  }
  
  .grid-3 {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 24px;
    margin-top: 24px;
  }
  
  .grid-4 {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 20px;
    margin-top: 24px;
  }
  
  .card {
    background: rgba(16, 26, 48, 0.7);
    border: 1px solid rgba(56, 189, 248, 0.18);
    border-radius: 18px;
    padding: 26px 30px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
  }
  
  .card.emerald { border-color: rgba(16, 185, 129, 0.35); }
  .card.amber { border-color: rgba(245, 158, 11, 0.35); }
  .card.rose { border-color: rgba(244, 63, 94, 0.35); }
  
  .stat-number {
    font-family: 'JetBrains Mono', monospace;
    font-size: 34px;
    font-weight: 700;
    color: #10B981;
    margin-bottom: 4px;
  }
  
  .stat-label {
    font-size: 13px;
    font-weight: 600;
    color: #94A3B8;
    text-transform: uppercase;
  }
  
  ul {
    margin: 0;
    padding-left: 20px;
  }
  
  li {
    font-size: 16px;
    color: #CBD5E1;
    line-height: 1.5;
    margin-bottom: 10px;
  }
  
  li strong { color: #FFFFFF; }
  
  footer {
    font-family: 'JetBrains Mono', monospace;
    font-size: 13px;
    color: #64748B;
  }
---

<!-- Slide 1 -->
<div class="badge">SOVEREIGN NATIONAL INFRASTRUCTURE</div>

# RENANCE<span style="color: #10B981;">.</span>
### Nigeria's Sovereign Dual-Engine Educational Operating System
*Eliminating Exam Hall Panic for Students • Ending Paper & Administrative Drain for Schools*

<div class="grid-2">
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 12px;">PILLAR I: School Operations OS</div>
    <ul>
      <li><strong>1-Tap NERDC Auto-Install:</strong> Primary 1 to SSS 3 curriculum mapped in 60s</li>
      <li><strong>70%+ Paper Slashing:</strong> Single-topic ink-saving black & white lesson sheets</li>
      <li><strong>30s Attendance:</strong> Instant classroom roll call and gate kiosk check-in</li>
      <li><strong>CA 20/20/60 & Check:</strong> Tamper-proof grades + 6-digit PIN on /school/check</li>
    </ul>
  </div>
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">PILLAR II: Student Study OS</div>
    <ul>
      <li><strong>207k+ Question Arsenal:</strong> 681 packs covering JAMB, WAEC, NECO & Uni</li>
      <li><strong>CBT Clock Coach:</strong> Real-time Target Dwell Time pacing indicator</li>
      <li><strong>Panic Forensics:</strong> Post-exam autopsy identifying time traps</li>
      <li><strong>Everyday Scenarios:</strong> Explains physics via Danfos and beans</li>
    </ul>
  </div>
</div>

<div class="grid-4" style="margin-top: 20px; text-align: center;">
  <div class="card" style="padding: 14px;"><div class="stat-number">207,172+</div><div class="stat-label">Past Questions</div></div>
  <div class="card" style="padding: 14px;"><div class="stat-number" style="color: #38BDF8;">681 Packs</div><div class="stat-label">1978–2025</div></div>
  <div class="card" style="padding: 14px;"><div class="stat-number" style="color: #F59E0B;">774 LGAs</div><div class="stat-label">National Rollout</div></div>
  <div class="card" style="padding: 14px;"><div class="stat-number" style="color: #FFFFFF;">100%</div><div class="stat-label">Offline SQLite</div></div>
</div>

---

<!-- Slide 2 -->
<div class="badge rose">THE NATIONAL CRISIS</div>

## The Twin Bottlenecks Crippling Nigerian Education
### Why Millions Fail National Exams While School Administrators Drown in Paper Chaos

<div class="grid-2">
  <div class="card rose">
    <div style="font-weight: 700; font-size: 20px; color: #F43F5E; margin-bottom: 12px;">Student Crisis: Clock Panic & Rote Failure</div>
    <ul>
      <li><strong>1.4M+ UTME Failures:</strong> Over 75% fail cutoffs yearly; 76% struggle in WAEC science/math.</li>
      <li><strong>The Hall Clock Trap:</strong> Students spend 4–5 minutes on single items, losing working memory and surrendering 10–15 marks to frantic blind guessing.</li>
      <li><strong>Abstract Textbook Alienation:</strong> Dry definitions force rote memorization without physical comprehension.</li>
      <li><strong>Bandwidth Barrier:</strong> 85% of candidates cannot afford heavy video streaming.</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 20px; color: #F59E0B; margin-bottom: 12px;">School Crisis: Paper Chaos & Fiscal Drain</div>
    <ul>
      <li><strong>Stationery Overhead:</strong> Schools spend ₦300k+ every term on registers, lesson notebooks, and exam printing.</li>
      <li><strong>Chaotic Fee Accounting:</strong> Disorganized records cause millions in uncollected fee arrears.</li>
      <li><strong>Report Card Forgery:</strong> Razor-blade alterations and ₦500 cyber-cafe counterfeit prints ruin trust.</li>
      <li><strong>Teacher Burnout:</strong> Late-night handwriting of lesson notes robs teachers of energy.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 3 -->
<div class="badge">ARCHITECTURAL INNOVATION</div>

## A Sovereign Dual-Engine Operating System
### Bridging Institutional Governance and Student Cognition Across 3 Native Surfaces

<div class="grid-3">
  <div class="card">
    <div style="font-weight: 700; font-size: 19px; color: #38BDF8; margin-bottom: 12px;">Pillar I: School OS</div>
    <ul>
      <li><strong>1-Tap NERDC Setup:</strong> Primary 1 to SSS 3 pre-loaded in 60s.</li>
      <li><strong>Ink-Saving Notes:</strong> Single-topic B&W sheets slash print bills by 70%+.</li>
      <li><strong>30s Attendance:</strong> Fast mobile roll call + gate kiosk mode.</li>
      <li><strong>Timetable Matrix:</strong> Atomic commits prevent room collisions.</li>
      <li><strong>Kobo Fee Ledger:</strong> Integer accounting halts rounding errors.</li>
    </ul>
  </div>
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 19px; color: #10B981; margin-bottom: 12px;">Pillar II: Study OS</div>
    <ul>
      <li><strong>207k+ Question Bank:</strong> 681 packs across JAMB, WAEC, NECO & Uni.</li>
      <li><strong>CBT Clock Coach:</strong> Real-time pacing eliminates panic.</li>
      <li><strong>Panic Forensics:</strong> Identifies time traps & lost marks.</li>
      <li><strong>Everyday Scenarios:</strong> Newton's laws via Danfo buses.</li>
      <li><strong>1v1 CBT Arena:</strong> 5-min live academic duels with WebSockets.</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 19px; color: #F59E0B; margin-bottom: 12px;">3 Native Surfaces</div>
    <ul>
      <li><strong>Web Launcher:</strong> Next.js 15 SSG with 1,446+ edge routes.</li>
      <li><strong>Mobile Shell:</strong> Flutter Android APK with embedded SQLite.</li>
      <li><strong>Zero Data Use:</strong> Download once via Wi-Fi; study offline in Airplane Mode.</li>
      <li><strong>Gate Kiosk:</strong> Plug-and-play desktop attendance terminal.</li>
      <li><strong>ADR-0003 Security:</strong> Sealed answer keys kept server-side.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 4 -->
<div class="badge cyan">CURRICULUM VAULT</div>

## Unrivaled National Question Repository: 207,172+ Banked
### 681 Specialized Academic Packs Spanning 1978 to 2025 Across All Levels

<div class="grid-2">
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 19px; color: #10B981; margin-bottom: 10px;">JAMB UTME GATEWAY (43,553 Qs • 46 Packs)</div>
    <ul>
      <li>Official 4-subject configuration (Use of English + 3 electives)</li>
      <li>Realistic 120-minute countdown clock with question navigator</li>
      <li>Full comprehension passages, poetry analysis, and worked models</li>
    </ul>
  </div>
  <div class="card">
    <div style="font-weight: 700; font-size: 19px; color: #38BDF8; margin-bottom: 10px;">WAEC & NECO SSCE (40,077 Qs • 72 Series)</div>
    <ul>
      <li>WAEC (1988–2025): 37,696 questions with objective and theory papers</li>
      <li>NECO SSCE & GCE: 2,381 verified curriculum-aligned questions</li>
      <li>Worked theory walkthroughs illustrating official marking rubrics</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 19px; color: #F59E0B; margin-bottom: 10px;">POST-UTME SCREENING (Premier Universities)</div>
    <ul>
      <li>Screening papers for UNILAG, FUTA, UI, OAU, UNIBEN</li>
      <li>Aptitude drills, logic tests, and speed calibration for 250+ cutoffs</li>
    </ul>
  </div>
  <div class="card" style="border-color: rgba(168, 85, 247, 0.4);">
    <div style="font-weight: 700; font-size: 19px; color: #A855F7; margin-bottom: 10px;">TERTIARY COURSE DESKS (122k+ Qs • 548 Modules)</div>
    <ul>
      <li>100 & 200 Level foundational modules: AMS 101, COS 101, MEE 101</li>
      <li>Semester lecture notes, past exam pools, and CGPA forecasting</li>
    </ul>
  </div>
</div>

---

<!-- Slide 5 -->
<div class="badge">PROPRIETARY COGNITIVE ENGINE</div>

## The CBT Exam Clock Coach: Neutralizing Hall Panic
### Dynamic Real-Time Pacing Guidance and Post-Exam Clock Forensics That Recover 10–15 Lost Marks

<div class="grid-2">
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">Dynamic Real-Time Pacing Engine</div>
    <div style="background: rgba(0,0,0,0.3); padding: 10px 16px; border-radius: 10px; font-family: 'JetBrains Mono', monospace; font-size: 14px; color: #10B981; margin-bottom: 14px;">
      T_target = Total Duration / Total Questions (e.g. 60s per item)
    </div>
    <ul>
      <li><strong style="color: #10B981;">[ON TRACK - GREEN]</strong> (t ≤ 1.2 × T_target) — Steady, rhythmic, optimal velocity.</li>
      <li><strong style="color: #F59E0B;">[LINGERING - AMBER]</strong> (1.2 &lt; t ≤ 2.0 × T_target) — Time buffer is eroding.</li>
      <li><strong style="color: #F43F5E;">[TIME TRAP RISK - RED]</strong> (t &gt; 2.0 × T_target) — Guess, flag, and preserve marks ahead!</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 20px; color: #F59E0B; margin-bottom: 12px;">Post-Exam Panic Forensics Autopsy</div>
    <ul>
      <li><strong>Paper Speed Curve:</strong> Plots candidate actual pace against optimal velocity.</li>
      <li><strong>Time-Trap Isolation:</strong> Flags questions where candidate spent &gt;2.5× target time and still got it wrong.</li>
      <li><strong>Panic Rush Zone:</strong> Detects end-of-test frantic guesses answered in &lt;8s.</li>
      <li><strong>Calculated Lost Marks:</strong> <em>"You lost 8 marks to clock panic, not intellectual inability."</em></li>
    </ul>
  </div>
</div>

---

<!-- Slide 6 -->
<div class="badge amber">PEDAGOGICAL INNOVATION</div>

## Everyday Relatable Scenarios & Socratic AI
### Translating Abstract Foreign Theorems into Lived Nigerian Realities and Guided Critical Thinking

<div class="grid-2">
  <div class="card amber">
    <div style="font-weight: 700; font-size: 20px; color: #F59E0B; margin-bottom: 12px;">Everyday Relatable Scenarios Bank</div>
    <ul>
      <li><strong>Newton's 1st Law (Inertia):</strong> Standing in a speeding Danfo bus along Ikorodu Road when the driver hits the brakes — upper torso lurches forward.</li>
      <li><strong>Newton's 3rd Law (Action/Reaction):</strong> Stepping off a wooden canoe onto muddy Lagos lagoon banks — backward push of the boat.</li>
      <li><strong>Osmosis & Membranes:</strong> Soaking rock-hard dried honey beans in water overnight — swollen and soft by morning.</li>
      <li><strong>Opportunity Cost (Economics):</strong> Deciding between a ₦1,500 data bundle vs a hot plate of cafeteria jollof rice.</li>
    </ul>
  </div>
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 12px;">Socratic AI Tutor (Hint-First Mode)</div>
    <ul>
      <li><strong>Anti-Spoon-Feeding Law:</strong> Refuses to reveal direct option letters (A, B, C, D) or copy-paste answers, cultivating intellectual rigor.</li>
      <li><strong>Diagnostic Guided Inquiry:</strong> Asks probing questions to isolate the core formula, variable, or rule distinction.</li>
      <li><strong>Step-by-Step Walkthroughs:</strong> Guides candidates through equations without revealing answers.</li>
      <li><strong>Deterministic Offline Matrices:</strong> Runs offline from local SQLite tables when internet is unreachable.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 7 -->
<div class="badge" style="border-color: rgba(168, 85, 247, 0.4); color: #A855F7; background: rgba(168, 85, 247, 0.15);">RETENTION & GAMIFICATION</div>

## 1v1 Multiplayer CBT Arena & Spaced Repetition
### Turning Solitary Exam Drills into an Electrifying Social Sport While Halting Cognitive Decay

<div class="grid-2">
  <div class="card" style="border-color: rgba(168, 85, 247, 0.35);">
    <div style="font-weight: 700; font-size: 20px; color: #A855F7; margin-bottom: 12px;">1v1 Multiplayer CBT Arena (/arena)</div>
    <ul>
      <li><strong>5-Minute Live Duels:</strong> 15 rapid-fire questions drawn from shared syllabi against peers nationwide.</li>
      <li><strong>Sub-100ms WebSocket Sync:</strong> Real-time ticking scoreboards consuming negligible bandwidth.</li>
      <li><strong>Automated Sparring Bot:</strong> Steps in within 20s if no human peer is available at odd hours.</li>
      <li><strong>Gamified XP & Streaks:</strong> Rewards study habits and fuels national school leaderboards.</li>
    </ul>
  </div>
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">Spaced-Repetition Review Queue (/review)</div>
    <ul>
      <li><strong>Automated Mistake Harvesting:</strong> Missed or skipped questions automatically route to review.</li>
      <li><strong>Ebbinghaus Curve Scheduling:</strong> Resurfaces items at <strong>24 Hours, 72 Hours, and 7 Days later</strong>.</li>
      <li><strong>Targeted Remediation:</strong> Concentrates on documented cognitive gaps instead of repeating full tests.</li>
      <li><strong>Multi-Platform Sync:</strong> Synchronized between web portal and Android SQLite database.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 8 -->
<div class="badge cyan">TECHNICAL INFRASTRUCTURE</div>

## Zero-Data Sovereign Architecture & 5 Offline Desks
### Engineered to Flourish Where Mobile Broadband Fails and Electrical Power Fluctuates Across Nigeria

<div class="grid-3">
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 19px; color: #10B981; margin-bottom: 12px;">The 5 Offline Desks</div>
    <ul>
      <li><strong>JAMB UTME Desk:</strong> Full 46 packs + 180-Q mock generator.</li>
      <li><strong>WAEC WASSCE Desk:</strong> 61 packs with theory walkthroughs.</li>
      <li><strong>NECO SSCE Desk:</strong> 11 series for national secondary tests.</li>
      <li><strong>Post-UTME Desk:</strong> Direct university screening banks.</li>
      <li><strong>School Workspace:</strong> Teacher notes, schemes & pools.</li>
    </ul>
  </div>
  <div class="card">
    <div style="font-weight: 700; font-size: 19px; color: #38BDF8; margin-bottom: 12px;">Android SQLite Shell</div>
    <ul>
      <li><strong>Flutter Performance:</strong> Fast on budget Android phones.</li>
      <li><strong>Embedded SQLite DB:</strong> Stores 207k+ questions locally.</li>
      <li><strong>5-Minute Sync:</strong> Connect to Wi-Fi once; study 6 months offline.</li>
      <li><strong>Airplane Mode:</strong> CBT mocks & Clock Coach work with zero data.</li>
      <li><strong>Standalone APK:</strong> Direct download without app store accounts.</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 19px; color: #F59E0B; margin-bottom: 12px;">Go Backend & Edge Web</div>
    <ul>
      <li><strong>Go 1.27 API:</strong> Sub-15ms latency with async worker pools.</li>
      <li><strong>Next.js 15 SSG:</strong> 1,446+ pre-rendered edge routes.</li>
      <li><strong>ADR-0003 Sealed Keys:</strong> Answers kept strictly server-side.</li>
      <li><strong>SHA-256 Checksums:</strong> Integrity verification on boot.</li>
      <li><strong>Multi-Tenant Postgres:</strong> Complete student/school isolation.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 9 -->
<div class="badge">INSTITUTIONAL EFFICIENCY</div>

## NERDC Curriculum Auto-Install & 70% Paper Slashing
### Standardizing Academic Operations in 60 Seconds While Eradicating Crushing Printing Expenses

<div class="grid-2">
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">1-Tap NERDC Statutory Installation</div>
    <ul>
      <li><strong>Zero Manual Typing:</strong> Provisions the official NERDC curriculum ladder in 60 seconds upon registration.</li>
      <li><strong>Primary 1 to SSS 3:</strong> Complete basic and senior secondary subject pathways (Science, Arts, Commercial, Technical).</li>
      <li><strong>12-Week Schemes of Work:</strong> Pre-populates term slots so teachers refine rather than starting from scratch.</li>
      <li><strong>Multi-Tier Access Control:</strong> Proprietors manage finances; teachers access only their assigned classes.</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 20px; color: #F59E0B; margin-bottom: 12px;">Ink-Saving B&W Print Architecture</div>
    <ul>
      <li><strong>Strict Monochrome Standard:</strong> Eliminates decorative fills and colors to optimize office laser printer life.</li>
      <li><strong>Single-Topic Print Optimization:</strong> Prints only the specific lesson required, preventing bulk paper waste.</li>
      <li><strong>Paper Bill Reduction:</strong> Slashes school printing overhead from ₦300k+ down to under ₦90k per academic term.</li>
      <li><strong>NERDC School Exam Pool:</strong> 1-click terminal exam generator pulls balanced, leak-proof papers ready to print.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 10 -->
<div class="badge cyan">DAILY OPERATIONS</div>

## Attendance Roster, Gate Kiosk & Collision-Free Timetable
### Streamlining Morning Roll Call, Gate Entry, and Weekly Scheduling into Synchronized Workflows

<div class="grid-2">
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 12px;">30-Second Attendance & Gate Kiosk Mode</div>
    <ul>
      <li><strong>30-Second Roll Call:</strong> Mobile tap-toggle roster saves 15 minutes of instructional time each morning.</li>
      <li><strong>Gate Kiosk Mode:</strong> Tablet/laptop at school gate logs arrivals in real time, alerting management to truancy.</li>
      <li><strong>SUBEB Compliance:</strong> 1-click export of monthly attendance registers in CSV/JSON format for state inspections.</li>
      <li><strong>PTA Analytics:</strong> Calculates termly student attendance percentages printed directly on verified report cards.</li>
    </ul>
  </div>
  <div class="card" style="border-color: rgba(168, 85, 247, 0.35);">
    <div style="font-weight: 700; font-size: 20px; color: #A855F7; margin-bottom: 12px;">Collision-Free Timetable Matrix</div>
    <ul>
      <li><strong>Visual Weekly Grid:</strong> Maps academic periods, assemblies, and recreation breaks across the school week.</li>
      <li><strong>Atomic Single-Transaction Commit:</strong> Validates entire weekly schedule at once, preventing double-booked rooms.</li>
      <li><strong>Instant Staff Distribution:</strong> Timetable immediately propagates to all teacher personal mobile dashboards.</li>
      <li><strong>Offline Reference:</strong> Teachers view assigned schedules on their smartphones without paper printouts.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 11 -->
<div class="badge">ACADEMIC INTEGRITY</div>

## Tamper-Proof Continuous Assessment & Result Checker
### Eradicating Report Card Forgery and Eliminating Human Error from Terminal Grade Computation

<div class="grid-2">
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">Universal Continuous Assessment Model</div>
    <div style="background: rgba(0,0,0,0.3); padding: 10px 16px; border-radius: 10px; font-family: 'JetBrains Mono', monospace; font-size: 14px; color: #10B981; margin-bottom: 14px;">
      Final Score (100%) = CA1 (20%) + CA2 (20%) + Terminal Exam (60%)
    </div>
    <ul>
      <li><strong>Automated Computation:</strong> Calculates student totals, class averages, grade boundaries (A1–F9), and positions.</li>
      <li><strong>Classroom Isolation:</strong> Teachers edit scores only for assigned cohorts, eliminating tampering.</li>
      <li><strong>Lock & Certify:</strong> Management signs off on finalized results; records lock against retroactive edits.</li>
    </ul>
  </div>
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 12px;">Parent Result Checker (/school/check)</div>
    <ul>
      <li><strong>6-Digit Scratch PIN:</strong> Unique session-scoped PIN generated for each enrolled pupil.</li>
      <li><strong>Zero-Travel Access:</strong> Parents enter Student ID + PIN on any phone browser to unlock verified digital report cards.</li>
      <li><strong>Forgery Eradication:</strong> Stops razor-blade grade alterations and ₦500 counterfeit cyber-cafe prints.</li>
      <li><strong>Institutional Seals:</strong> Displays verified school emblem, remarks, and cryptographic security hashes.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 12 -->
<div class="badge amber">FINANCIAL GOVERNANCE</div>

## Integer-Safe Kobo Accounting & Serialized ID Cards
### Halting Revenue Leakage, Tracking Tuition Debtors, and Automating Student Identity Verification

<div class="grid-2">
  <div class="card amber">
    <div style="font-weight: 700; font-size: 20px; color: #F59E0B; margin-bottom: 12px;">Integer-Safe Kobo Accounting Ledger</div>
    <ul>
      <li><strong>Zero Rounding Errors:</strong> All transactions calculated in integer kobo (100 kobo = ₦1.00).</li>
      <li><strong>Tiered Fee Structures:</strong> Manages tuition, lab levies, uniforms, and PTA dues by class.</li>
      <li><strong>Multi-Channel Receipts:</strong> Logs cash, bank transfers, POS, and drafts with immutable transaction hashes.</li>
      <li><strong>Real-Time Debtor Defaulter List:</strong> Filtered roster of unpaid fees prevents exam-week evasion.</li>
    </ul>
  </div>
  <div class="card" style="border-color: rgba(168, 85, 247, 0.35);">
    <div style="font-weight: 700; font-size: 20px; color: #A855F7; margin-bottom: 12px;">Automated Serialized ID Card Engine</div>
    <ul>
      <li><strong>Standardized Matriculation:</strong> Official format: <code>REN-2026-NNNNNN</code> (e.g. <code>REN-2026-000142</code>).</li>
      <li><strong>8-Card Print Batch Sheets:</strong> Exports printable sheets with photos, blood groups, barcodes, and seals.</li>
      <li><strong>In-House Card Production:</strong> Schools print on cardstock and laminate in-house, saving ₦150k+ yearly.</li>
      <li><strong>Instant Revocation:</strong> Lost or stolen cards are blacklisted without corrupting academic history.</li>
    </ul>
  </div>
</div>

---

<!-- Slide 13 -->
<div class="badge cyan">MARKET OPPORTUNITY</div>

## Massive National Footprint Across 774 LGAs
### Capturing Nigeria's Expanding EdTech Frontier with an Unfair Offline Distribution Advantage

<div class="grid-3">
  <div class="card">
    <div style="font-weight: 700; font-size: 19px; color: #38BDF8; margin-bottom: 8px;">Total Addressable Market</div>
    <div class="stat-number" style="color: #38BDF8;">₦120B+</div>
    <ul>
      <li>1.4M+ Annual JAMB UTME candidates</li>
      <li>1.6M+ Annual WAEC WASSCE candidates</li>
      <li>1.2M+ Annual NECO SSCE candidates</li>
      <li>Millions of basic education pupils in Primary 1 to JSS 3</li>
    </ul>
  </div>
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 19px; color: #10B981; margin-bottom: 8px;">Serviceable Market</div>
    <div class="stat-number">40,000+</div>
    <ul>
      <li>Primary & secondary schools seeking digital transformation</li>
      <li>250+ Tertiary Institutions nationwide</li>
      <li>774 Local Government Areas: 1 sovereign rollout surface</li>
      <li>UBEC & SUBEB digital telemetry partnerships</li>
    </ul>
  </div>
  <div class="card amber">
    <div style="font-weight: 700; font-size: 19px; color: #F59E0B; margin-bottom: 8px;">Teacher Income & Scale</div>
    <div class="stat-number" style="color: #F59E0B;">Two-Sided</div>
    <ul>
      <li>Earning platform for verified Nigerian teachers</li>
      <li>Tutors monetize revision notes and test pools</li>
      <li>Zero-data offline delivery reaches rural learners</li>
      <li>Works on budget Android phones without data bills</li>
    </ul>
  </div>
</div>

---

<!-- Slide 14 -->
<div class="badge">BUSINESS MODEL</div>

## Dual-Engine Monetization & High-Margin Unit Economics
### Predictable High-Volume Consumer Subscriptions Paired with Recurring Institutional B2B SaaS

<div class="grid-2">
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 12px;">Student Consumer Economy (B2C)</div>
    <ul>
      <li><strong>Free Frictionless Onboarding:</strong> 1 free full CBT test + 20 Qs/session</li>
      <li><strong>₦500 / 1 Week Pass:</strong> Sprints for rapid pre-exam revision</li>
      <li><strong>₦1,500 / 1 Month Pass:</strong> All 681 packs and Socratic AI tutor</li>
      <li><strong>₦2,500 / 3 Months Pass:</strong> Termly prep for WAEC/NECO/JAMB</li>
      <li><strong>₦5,000 / 1 Year All-Access:</strong> Full web & mobile offline access</li>
      <li><strong>REN Coin Economy:</strong> Duels (+1 REN$), referrals (+3 REN$), redeem 250 REN$ = 1 month premium</li>
    </ul>
  </div>
  <div class="card emerald">
    <div style="font-weight: 700; font-size: 20px; color: #10B981; margin-bottom: 12px;">Institutional School SaaS Tiers (B2B)</div>
    <ul>
      <li><strong>Basic (₦3,000/mo or ₦10,000/yr):</strong> Up to 100 students (notes, curriculum, attendance & results)</li>
      <li><strong>Standard (₦6,000/mo or ₦25,000/yr):</strong> Up to 300 students (exam bank, timetable, fee ledger, ID cards)</li>
      <li><strong>Premium (₦20,000/mo or ₦60,000/yr):</strong> Unlimited students (all features + 10 free student passes)</li>
      <li><strong>Predictable Pricing:</strong> Flat annual institutional fee; zero per-teacher micro-charges; &lt;5% churn.</li>
    </ul>
  </div>
</div>

<div style="background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.35); padding: 16px 24px; border-radius: 14px; text-align: center; margin-top: 18px;">
  <strong style="color: #F59E0B;">UNIT ECONOMICS: OVER 85% GROSS MARGINS</strong> — Edge-hosted SSG and local SQLite mean marginal server cost per active offline student approaches ₦0.00.
</div>

---

<!-- Slide 15 -->
<div class="badge">THE BUILDERS & THE ASK</div>

## Executive Leadership & ₦50M Grant Allocation
### Proven Technical Leadership Shipping Sovereign Educational Infrastructure from Akure, Ondo State

<div class="grid-2">
  <div class="card">
    <div style="font-weight: 700; font-size: 20px; color: #38BDF8; margin-bottom: 14px;">The Builders: Executive Leadership</div>
    <div style="margin-bottom: 14px;">
      <strong style="color: #FFFFFF;">Olubobokun Femi (Resolutefemi)</strong> — <span style="color: #10B981; font-weight: 700;">CEO & Team Lead</span><br>
      <span style="color: #38BDF8; font-size: 13px; font-weight: 600;">Product Strategy, School Alliances & Regulatory Compliance</span><br>
      <span style="font-size: 13px; color: #CBD5E1;">Directs school partnerships, SUBEB/NERDC stakeholder relations, and national institutional deployment across 774 LGAs.</span>
    </div>
    <div style="margin-bottom: 14px;">
      <strong style="color: #FFFFFF;">Ayoola Damisile</strong> — <span style="color: #10B981; font-weight: 700;">CTO & Lead Systems Architect</span><br>
      <span style="color: #38BDF8; font-size: 13px; font-weight: 600;">High-Performance Go Systems & Sovereign Offline Engineering</span><br>
      <span style="font-size: 13px; color: #CBD5E1;">Architect of the 681-pack offline SQLite engine, sub-15ms Go CBT scoring pipeline, and Renance AI fine-tuning.</span>
    </div>
    <div style="padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.08); font-size: 12px; color: #94A3B8;">
      📍 <strong>Headquarters:</strong> Akure, Ondo State (Adjacent to FUTA Tech Hub) • <strong>Portal:</strong> renance.app
    </div>
  </div>

  <div style="display: flex; flex-direction: column; gap: 16px;">
    <div class="card amber" style="padding: 18px 22px;">
      <div style="font-weight: 700; font-size: 18px; color: #F59E0B; margin-bottom: 8px;">₦50,000,000 Capital Grant Utilization</div>
      <ul style="font-size: 14px;">
        <li><strong style="color: #F59E0B;">₦15.0M (30%) Talent:</strong> 10 Nigerian engineers & curriculum leads in Akure.</li>
        <li><strong style="color: #F59E0B;">₦10.0M (20%) AI & Cloud:</strong> Sovereign inference nodes & geo-redundant backups.</li>
        <li><strong style="color: #F59E0B;">₦10.0M (20%) Field Rollout:</strong> Ondo State beachhead & 50-ambassador network.</li>
        <li><strong style="color: #F59E0B;">₦7.5M (15%) Hardware:</strong> Low-cost test lab (Tecno/Infinix) + 5kVA solar backup.</li>
        <li><strong style="color: #F59E0B;">₦5.0M (10%) Compliance:</strong> CAC, trademarks, NDPR audit & NERDC certification.</li>
        <li><strong style="color: #F59E0B;">₦2.5M (5%) Buffer:</strong> Contingency reserve & currency inflation hedge.</li>
      </ul>
    </div>

    <div class="card emerald" style="padding: 16px 20px; text-align: center; background: rgba(16, 185, 129, 0.1);">
      <div style="color: #FFFFFF; font-size: 18px; font-weight: 700; margin-bottom: 4px;">Modernizing Nigerian Education.</div>
      <div style="color: #10B981; font-weight: 600; font-size: 14px; margin-bottom: 4px;">Two Sovereign Engines. Zero Data Barriers. 774 LGAs.</div>
      <div style="font-family: 'JetBrains Mono', monospace; font-size: 14px; color: #38BDF8; font-weight: 700;">https://renance.app • Learn. Practice. Rise.</div>
    </div>
  </div>
</div>
