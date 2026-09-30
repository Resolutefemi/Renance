import os

html_content = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RENANCE — Nigeria's Sovereign Dual-Engine Educational Operating System</title>
    
    <!-- Distinctive High-Fidelity Typography via Fontshare & Google Fonts -->
    <link href="https://api.fontshare.com/v2/css?f[]=clash-display@500,600,700&f[]=satoshi@400,500,700&display=swap" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&display=swap" rel="stylesheet">

    <style>
        /* ===========================================
           CSS VARIABLES & PALETTE (SOVEREIGN THEME)
           =========================================== */
        :root {
            --stage-bg: #040711;
            --bg-primary: #070B16;
            --bg-secondary: #0D1527;
            --card-bg: rgba(16, 26, 48, 0.75);
            --card-border: rgba(56, 189, 248, 0.15);
            --card-border-glow: rgba(16, 185, 129, 0.35);
            
            --text-primary: #FFFFFF;
            --text-secondary: #94A3B8;
            --text-muted: #64748B;
            
            --accent-emerald: #10B981;
            --emerald-glow: rgba(16, 185, 129, 0.25);
            --accent-cyan: #38BDF8;
            --cyan-glow: rgba(56, 189, 248, 0.25);
            --accent-amber: #F59E0B;
            --amber-glow: rgba(245, 158, 11, 0.25);
            --accent-rose: #F43F5E;
            --accent-purple: #A855F7;

            --font-display: 'Clash Display', -apple-system, BlinkMacSystemFont, sans-serif;
            --font-body: 'Satoshi', -apple-system, BlinkMacSystemFont, sans-serif;
            --font-mono: 'JetBrains Mono', monospace;

            --ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
            --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
        }

        /* ===========================================
           FIXED 16:9 STAGE MODEL (viewport-base.css)
           =========================================== */
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            overflow: hidden;
            background: var(--stage-bg);
            font-family: var(--font-body);
            color: var(--text-primary);
            -webkit-font-smoothing: antialiased;
        }

        .deck-viewport {
            position: fixed;
            inset: 0;
            overflow: hidden;
            background: radial-gradient(circle at 50% 20%, #0F1D38 0%, #060A14 70%, #03050B 100%);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .deck-stage {
            position: absolute;
            width: 1920px;
            height: 1080px;
            overflow: hidden;
            transform-origin: center center;
            background: #070B16;
            box-shadow: 0 25px 80px rgba(0, 0, 0, 0.8), 0 0 1px rgba(255, 255, 255, 0.1);
        }

        /* Subtle Ambient Grid Background */
        .stage-grid {
            position: absolute;
            inset: 0;
            background-image: 
                linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
            background-size: 80px 80px;
            pointer-events: none;
            opacity: 0.6;
        }

        .stage-glow-1 {
            position: absolute;
            top: -200px;
            right: -100px;
            width: 700px;
            height: 700px;
            background: radial-gradient(circle, var(--emerald-glow) 0%, transparent 70%);
            filter: blur(100px);
            pointer-events: none;
        }

        .stage-glow-2 {
            position: absolute;
            bottom: -200px;
            left: -100px;
            width: 800px;
            height: 800px;
            background: radial-gradient(circle, var(--cyan-glow) 0%, transparent 70%);
            filter: blur(120px);
            pointer-events: none;
        }

        /* Slide Stacking */
        .slide {
            position: absolute;
            inset: 0;
            width: 1920px;
            height: 1080px;
            padding: 80px 100px 90px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            visibility: hidden;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.5s var(--ease-out-expo), transform 0.5s var(--ease-out-expo);
            transform: scale(0.98) translateY(10px);
        }

        .slide.active {
            visibility: visible;
            opacity: 1;
            pointer-events: auto;
            transform: scale(1) translateY(0);
            z-index: 10;
        }

        /* Slide Header */
        .slide-header {
            display: flex;
            flex-direction: column;
            gap: 12px;
            margin-bottom: 48px;
            position: relative;
            z-index: 2;
        }

        .pill-badge {
            align-self: flex-start;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 6px 16px;
            border-radius: 9999px;
            font-family: var(--font-mono);
            font-size: 13px;
            font-weight: 600;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            background: rgba(16, 185, 129, 0.1);
            color: var(--accent-emerald);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .pill-badge.red {
            background: rgba(244, 63, 94, 0.1);
            color: var(--accent-rose);
            border-color: rgba(244, 63, 94, 0.3);
        }
        .pill-badge.amber {
            background: rgba(245, 158, 11, 0.1);
            color: var(--accent-amber);
            border-color: rgba(245, 158, 11, 0.3);
        }
        .pill-badge.purple {
            background: rgba(168, 85, 247, 0.1);
            color: var(--accent-purple);
            border-color: rgba(168, 85, 247, 0.3);
        }
        .pill-badge.cyan {
            background: rgba(56, 189, 248, 0.1);
            color: var(--accent-cyan);
            border-color: rgba(56, 189, 248, 0.3);
        }

        .slide-title {
            font-family: var(--font-display);
            font-size: 46px;
            font-weight: 700;
            letter-spacing: -0.02em;
            line-height: 1.15;
            color: var(--text-primary);
        }

        .slide-subtitle {
            font-size: 20px;
            font-weight: 400;
            color: var(--accent-cyan);
            line-height: 1.4;
        }

        /* Slide Content Area */
        .slide-body {
            flex: 1;
            display: grid;
            gap: 36px;
            position: relative;
            z-index: 2;
        }

        .grid-2 { grid-template-columns: 1fr 1fr; }
        .grid-3 { grid-template-columns: 1fr 1fr 1fr; }
        .grid-4 { grid-template-columns: repeat(4, 1fr); }

        /* Cards */
        .card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 20px;
            padding: 36px;
            display: flex;
            flex-direction: column;
            gap: 20px;
            backdrop-filter: blur(16px);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .card::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 3px;
            background: linear-gradient(90deg, transparent, var(--card-accent, var(--accent-emerald)), transparent);
            opacity: 0.8;
        }

        .card.emerald { --card-accent: var(--accent-emerald); }
        .card.cyan { --card-accent: var(--accent-cyan); }
        .card.amber { --card-accent: var(--accent-amber); }
        .card.purple { --card-accent: var(--accent-purple); }
        .card.rose { --card-accent: var(--accent-rose); }

        .card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .card-title {
            font-family: var(--font-display);
            font-size: 24px;
            font-weight: 600;
            color: var(--text-primary);
        }

        .card-metric {
            font-family: var(--font-mono);
            font-size: 40px;
            font-weight: 700;
            color: var(--card-accent, var(--accent-emerald));
            line-height: 1;
        }

        .bullet-list {
            display: flex;
            flex-direction: column;
            gap: 16px;
            list-style: none;
        }

        .bullet-item {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            font-size: 17px;
            color: #CBD5E1;
            line-height: 1.5;
        }

        .bullet-icon {
            color: var(--card-accent, var(--accent-emerald));
            font-size: 16px;
            margin-top: 3px;
            flex-shrink: 0;
            font-family: var(--font-mono);
        }

        /* Slide Footer Bar */
        .slide-footer {
            margin-top: auto;
            padding-top: 24px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: 14px;
            color: var(--text-muted);
            font-family: var(--font-mono);
            position: relative;
            z-index: 2;
        }

        .footer-brand {
            display: flex;
            align-items: center;
            gap: 10px;
            color: var(--text-secondary);
        }

        .brand-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--accent-emerald);
            box-shadow: 0 0 10px var(--accent-emerald);
        }

        .slide-counter {
            color: var(--accent-emerald);
            font-weight: 700;
        }

        /* Interactive Ambient Controls HUD */
        .deck-controls {
            position: fixed;
            bottom: 24px;
            left: 50%;
            transform: translateX(-50%);
            display: flex;
            align-items: center;
            gap: 16px;
            padding: 10px 24px;
            background: rgba(13, 21, 39, 0.85);
            border: 1px solid rgba(255, 255, 255, 0.12);
            backdrop-filter: blur(20px);
            border-radius: 9999px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
            z-index: 1000;
        }

        .ctrl-btn {
            background: transparent;
            border: none;
            color: #94A3B8;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            padding: 6px 12px;
            border-radius: 8px;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 6px;
            font-family: var(--font-body);
        }

        .ctrl-btn:hover {
            color: #FFFFFF;
            background: rgba(255, 255, 255, 0.1);
        }

        .ctrl-dots {
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .ctrl-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.2);
            cursor: pointer;
            transition: all 0.3s;
        }

        .ctrl-dot.active {
            background: var(--accent-emerald);
            width: 22px;
            border-radius: 9999px;
            box-shadow: 0 0 10px var(--accent-emerald);
        }

        /* Interactive Pacing Pill Demo */
        .interactive-pacing {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 18px;
            border-radius: 12px;
            background: rgba(0,0,0,0.3);
            border: 1px solid rgba(255,255,255,0.08);
            cursor: pointer;
            transition: all 0.2s;
        }
        .interactive-pacing:hover {
            border-color: rgba(255,255,255,0.2);
            transform: translateY(-2px);
        }

        /* Animation reveals */
        .reveal {
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.5s var(--ease-out-expo), transform 0.5s var(--ease-out-expo);
        }

        .slide.active .reveal {
            opacity: 1;
            transform: translateY(0);
        }

        .reveal:nth-child(1) { transition-delay: 0.05s; }
        .reveal:nth-child(2) { transition-delay: 0.12s; }
        .reveal:nth-child(3) { transition-delay: 0.18s; }
        .reveal:nth-child(4) { transition-delay: 0.25s; }

        @media print {
            .deck-viewport, body, html {
                overflow: visible !important;
                position: static !important;
                background: #070B16 !important;
            }
            .deck-stage {
                position: static !important;
                transform: none !important;
                width: 100% !important;
                height: auto !important;
            }
            .slide {
                position: relative !important;
                visibility: visible !important;
                opacity: 1 !important;
                page-break-after: always;
                display: flex !important;
                height: 100vh !important;
            }
            .deck-controls { display: none !important; }
        }
    </style>
</head>
<body>
    <div class="deck-viewport">
        <main class="deck-stage" id="deckStage">
            <div class="stage-grid"></div>
            <div class="stage-glow-1"></div>
            <div class="stage-glow-2"></div>

            <!-- ==========================================
                 SLIDE 1: Title & Sovereign Proposition
                 ========================================== -->
            <section class="slide active" id="slide-1">
                <div class="slide-header">
                    <span class="pill-badge">SOVEREIGN NATIONAL INFRASTRUCTURE</span>
                    <h1 class="slide-title" style="font-size: 64px; margin-top: 8px;">
                        RENANCE<span style="color: var(--accent-emerald)">.</span>
                    </h1>
                    <p class="slide-subtitle" style="font-size: 28px; color: #FFFFFF; font-weight: 600;">
                        Nigeria's Sovereign Dual-Engine Educational Operating System
                    </p>
                    <p style="font-size: 18px; color: var(--accent-cyan);">
                        Eliminating Examination Panic for Students • Ending Paper & Administrative Drain for Schools
                    </p>
                </div>

                <div class="slide-body grid-2" style="margin-top: 20px;">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">PILLAR I: Institutional School OS</span>
                            <span class="pill-badge cyan">ADMINISTRATION</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> 1-Tap NERDC National Curriculum auto-installation (Primary 1 to SSS 3)</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> Ink-Saving single-topic B&W lesson notes & worksheets (Slashes print bills by 70%+)</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> 30-Second mobile attendance roll call, gate kiosk mode & SUBEB CSV reports</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> Automated Continuous Assessment (CA 20/20/60) & parent scratch PIN checker</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> Kobo-safe integer fee ledger with live debtor tracking & serialized student IDs</li>
                        </ul>
                    </div>

                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">PILLAR II: Cognitive Student Study OS</span>
                            <span class="pill-badge">COGNITION</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> 207,172+ verified questions across 681 packs (JAMB, WAEC, NECO, Post-UTME, Uni)</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> CBT Exam Clock Coach: ambient pacing gauge (On Track / Lingering / Trap Risk)</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> Post-exam Panic Forensics autopsy isolating time traps & recovered marks</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> Everyday Relatable Scenarios translating abstract STEM formulas into Nigerian reality</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> 1v1 Multiplayer CBT Arena with WebSocket live sync & Spaced Repetition Queue</li>
                        </ul>
                    </div>
                </div>

                <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-top: 30px;">
                    <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 18px 24px; border-radius: 14px; text-align: center;">
                        <div style="font-family: var(--font-mono); font-size: 32px; font-weight: 700; color: var(--accent-emerald);">207,172+</div>
                        <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Verified Past Questions</div>
                    </div>
                    <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 18px 24px; border-radius: 14px; text-align: center;">
                        <div style="font-family: var(--font-mono); font-size: 32px; font-weight: 700; color: var(--accent-cyan);">681 Packs</div>
                        <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">1978 – 2025 Coverage</div>
                    </div>
                    <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 18px 24px; border-radius: 14px; text-align: center;">
                        <div style="font-family: var(--font-mono); font-size: 32px; font-weight: 700; color: var(--accent-amber);">774 LGAs</div>
                        <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Sovereign Rollout Surface</div>
                    </div>
                    <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); padding: 18px 24px; border-radius: 14px; text-align: center;">
                        <div style="font-family: var(--font-mono); font-size: 32px; font-weight: 700; color: #FFFFFF;">100% Offline</div>
                        <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Android SQLite Shell</div>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">01 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 2: The Dual Crisis
                 ========================================== -->
            <section class="slide" id="slide-2">
                <div class="slide-header">
                    <span class="pill-badge red">THE NATIONAL CRISIS</span>
                    <h2 class="slide-title">The Twin Bottlenecks Crippling Nigerian Education</h2>
                    <p class="slide-subtitle">Why Millions Fail High-Stakes Exams While School Administrators Drown in Paper Chaos</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card rose">
                        <div class="card-header">
                            <span class="card-title">Student Crisis: Clock Panic & Rote Failure</span>
                            <span class="pill-badge red">COGNITIVE DEFICIT</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>1.4M+ UTME Candidates Fail Cutoffs:</strong> Over 75% of applicants fail to secure university admission yearly; 76% struggle in WAEC science and math.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>The Hall Clock Trap:</strong> Candidates spend 4–5 minutes stuck on single complex questions. Acute panic sets in, working memory collapses, and 10–15 marks are lost to frantic blind guessing.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>Foreign Pedagogical Alienation:</strong> Dry textbook definitions force rote memorization. Students recite formulas verbatim without intuitive physical understanding.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>The Bandwidth Tariff Barrier:</strong> High mobile data costs exclude 85% of Nigerian students who survive on micro-data bundles and cannot stream heavy videos.</li>
                        </ul>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">School Crisis: Paper Chaos & Fiscal Drain</span>
                            <span class="pill-badge amber">ADMINISTRATIVE COLLAPSE</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>Crushing Stationery Overhead:</strong> Schools hemorrhage over ₦300,000 every term on paper registers, handwritten lesson plan notebooks, and terminal exam photocopies.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>Chaotic Fee Accounting & Debtors:</strong> Bursars rely on paper ledgers or loose desktop spreadsheets. Parents exploit poor records, leaving millions in uncollected fee arrears.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>Rampant Report Card Forgery:</strong> Razor-blade alterations and ₦500 cyber-cafe counterfeit report sheets destroy institutional trust and parent confidence.</li>
                            <li class="bullet-item"><span class="bullet-icon">✕</span> <strong>Teacher Burnout:</strong> Late-night handwriting of weekly lesson notes robs educators of instructional energy, while manual CA calculation breeds human error.</li>
                        </ul>
                    </div>
                </div>

                <div style="background: rgba(56, 189, 248, 0.08); border: 1px solid rgba(56, 189, 248, 0.25); padding: 18px 28px; border-radius: 14px; text-align: center; margin-top: 24px;">
                    <span style="font-size: 16px; font-weight: 600; color: #FFFFFF;">
                        💡 <strong>The Failure of Legacy EdTech:</strong> Commercial quiz apps dump multiple-choice questions without teaching; video portals demand bandwidth Nigerian students cannot afford. Nigeria needs a foundational Operating System.
                    </span>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">02 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 3: The Dual-Engine Solution
                 ========================================== -->
            <section class="slide" id="slide-3">
                <div class="slide-header">
                    <span class="pill-badge">ARCHITECTURAL INNOVATION</span>
                    <h2 class="slide-title">A Sovereign Dual-Engine Operating System</h2>
                    <p class="slide-subtitle">Unifying Institutional Governance and Cognitive Mastery Across 3 Native Surfaces</p>
                </div>

                <div class="slide-body grid-3">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Pillar I: School OS</span>
                            <span class="pill-badge cyan">INSTITUTION</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>1-Tap NERDC Install:</strong> Pre-populates Primary 1 to SSS 3 across Science, Arts, Commercial & Technical.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Ink-Saving Print Engine:</strong> Single-topic B&W lesson notes cut paper/toner costs by 70%+.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>30s Attendance Roster:</strong> Fast roll call, gate kiosk mode, and SUBEB CSV exports.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Collision-Free Timetable:</strong> Atomic commit prevents room or teacher double-booking.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>CA 20/20/60 & Checker:</strong> Automated grades + 6-digit scratch PIN on /school/check.</li>
                        </ul>
                    </div>

                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Pillar II: Study OS</span>
                            <span class="pill-badge">STUDENT</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>207k+ Question Arsenal:</strong> Curated past papers across 681 packs spanning JAMB, WAEC, NECO & Uni.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>CBT Clock Coach:</strong> Real-time pacing gauge eliminates hall panic and time traps.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Panic Forensics:</strong> Pinpoints exact questions where panic set in and lost marks occurred.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Everyday Scenarios:</strong> Explains physics via Danfo buses, and osmosis via honey beans.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>1v1 Multiplayer Arena:</strong> High-energy 5-minute academic duels with WebSocket sync.</li>
                        </ul>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">3 Unified Surfaces</span>
                            <span class="pill-badge amber">SURFACES</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Web Launcher (Next.js 15):</strong> 1,446+ pre-rendered edge routes loading in milliseconds.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Mobile Shell (Flutter APK):</strong> Lightweight APK with embedded SQLite and 5 Offline Desks.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Zero-Data Operation:</strong> Download packs once via Wi-Fi; study 100% offline in Airplane Mode.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Desktop Gate Kiosk:</strong> Plug-and-play attendance logging on standard office laptops.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>ADR-0003 Security:</strong> Sealed answer keys kept strictly server-side with sha256 checksums.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">03 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 4: The 207k Question Arsenal
                 ========================================== -->
            <section class="slide" id="slide-4">
                <div class="slide-header">
                    <span class="pill-badge cyan">CURRICULUM VAULT</span>
                    <h2 class="slide-title">Unrivaled National Question Repository: 207,172+ Banked</h2>
                    <p class="slide-subtitle">681 Specialized Academic Packs Spanning 1978 to 2025 Across Secondary, Screening & Tertiary Levels</p>
                </div>

                <div class="slide-body grid-2" style="grid-template-rows: 1fr 1fr; gap: 24px;">
                    <div class="card emerald" style="padding: 24px 30px;">
                        <div class="card-header">
                            <span class="card-title" style="font-size: 20px;">JAMB UTME GATEWAY</span>
                            <span style="font-family: var(--font-mono); color: var(--accent-emerald); font-weight: 700;">43,553 Qs • 46 Packs</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 14px; gap: 8px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> Full 4-subject official configuration (Compulsory English + 3 chosen electives)</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Official 120-minute countdown clock simulation with question palette navigator</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Full comprehension reading passages, poetry analysis, and worked step-by-step models</li>
                        </ul>
                    </div>

                    <div class="card cyan" style="padding: 24px 30px;">
                        <div class="card-header">
                            <span class="card-title" style="font-size: 20px;">WAEC WASSCE & NECO SSCE</span>
                            <span style="font-family: var(--font-mono); color: var(--accent-cyan); font-weight: 700;">40,077 Qs • 72 Series</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 14px; gap: 8px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> WAEC (1988–2025): 37,696 questions covering Objective and Theory papers</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> NECO SSCE & GCE: 2,381 verified curriculum-aligned questions across all tracks</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Worked theory walkthroughs illustrating official West African marking scheme rubrics</li>
                        </ul>
                    </div>

                    <div class="card amber" style="padding: 24px 30px;">
                        <div class="card-header">
                            <span class="card-title" style="font-size: 20px;">POST-UTME SCREENING PACKS</span>
                            <span style="font-family: var(--font-mono); color: var(--accent-amber); font-weight: 700;">Premier Universities</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 14px; gap: 8px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> Authentic screening papers for University of Lagos (UNILAG) and FUTA</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> University of Ibadan (UI), Obafemi Awolowo University (OAU) & UNIBEN screening series</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> General paper aptitude drills, logic tests, and speed calibration for 250+ cutoffs</li>
                        </ul>
                    </div>

                    <div class="card purple" style="padding: 24px 30px;">
                        <div class="card-header">
                            <span class="card-title" style="font-size: 20px;">TERTIARY UNIVERSITY DESKS</span>
                            <span style="font-family: var(--font-mono); color: var(--accent-purple); font-weight: 700;">122,000+ Qs • 548 Modules</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 14px; gap: 8px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> Foundational 100 & 200 Level Nigerian university course examination repositories</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> AMS 101 Principles of Management, COS 101 Computer Programming, MEE 101 Mechanics</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Semester lecture notes, past exam pools, and continuous CGPA forecasting models</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">04 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 5: CBT Exam Clock Coach & Forensics
                 ========================================== -->
            <section class="slide" id="slide-5">
                <div class="slide-header">
                    <span class="pill-badge">PROPRIETARY COGNITIVE ENGINE</span>
                    <h2 class="slide-title">The CBT Exam Clock Coach: Neutralizing Hall Panic</h2>
                    <p class="slide-subtitle">Dynamic Real-Time Pacing Guidance and Post-Exam Clock Forensics That Recover 10–15 Lost Marks</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Dynamic Real-Time Pacing Engine</span>
                            <span class="pill-badge">ALGORITHM</span>
                        </div>
                        <div style="background: rgba(0,0,0,0.3); padding: 14px 20px; border-radius: 12px; font-family: var(--font-mono); font-size: 14px; color: var(--accent-emerald);">
                            Target Dwell Time (T_target) = Total Duration / Total Questions<br>
                            (In a 40-question, 40-min paper: Baseline = 60.0s / question)
                        </div>

                        <div style="display: flex; flex-direction: column; gap: 12px; margin-top: 6px;">
                            <div class="interactive-pacing" style="border-left: 4px solid var(--accent-emerald);">
                                <span style="color: var(--accent-emerald); font-weight: 700; font-family: var(--font-mono);">[ON TRACK - GREEN]</span>
                                <span style="font-size: 14px; color: #CBD5E1;">(t ≤ 1.2 × T_target) — Steady, rhythmic, optimal velocity.</span>
                            </div>
                            <div class="interactive-pacing" style="border-left: 4px solid var(--accent-amber);">
                                <span style="color: var(--accent-amber); font-weight: 700; font-family: var(--font-mono);">[LINGERING - AMBER]</span>
                                <span style="font-size: 14px; color: #CBD5E1;">(1.2 &lt; t ≤ 2.0 × T_target) — Warning: your time buffer is evaporating.</span>
                            </div>
                            <div class="interactive-pacing" style="border-left: 4px solid var(--accent-rose);">
                                <span style="color: var(--accent-rose); font-weight: 700; font-family: var(--font-mono);">[TIME TRAP RISK - RED]</span>
                                <span style="font-size: 14px; color: #CBD5E1;">(t &gt; 2.0 × T_target) — Circuit breaker: guess, flag, and preserve easy marks ahead!</span>
                            </div>
                        </div>

                        <p style="font-size: 14px; color: var(--text-secondary); margin-top: 6px;">
                            Subconscious conditioning trains internal rhythm, preventing the sudden 30-minute panic shock in CBT halls.
                        </p>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Post-Exam Panic Forensics Autopsy</span>
                            <span class="pill-badge amber">DIAGNOSTICS</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">🔍</span> <strong>Temporal Paper Reconstruction:</strong> Plots candidate actual pace curve against theoretical optimal velocity across the entire exam.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚠️</span> <strong>Time-Trap Isolation:</strong> Specifically identifies questions where a candidate sacrificed 3 to 5 minutes on a single item yet still chose an incorrect option.</li>
                            <li class="bullet-item"><span class="bullet-icon">⏱️</span> <strong>Panic Rush Zone Detection:</strong> Exposes late-exam questions answered in under 8 seconds due to expiring timers, proving where working memory collapsed.</li>
                            <li class="bullet-item"><span class="bullet-icon">📈</span> <strong>Calculated Lost Marks Metric:</strong> Empowers students by showing: <em>"You lost 8 marks to clock panic, not intellectual inability."</em> Transforming practice into scientific calibration.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">05 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 6: Everyday Relatable Scenarios & Socratic AI
                 ========================================== -->
            <section class="slide" id="slide-6">
                <div class="slide-header">
                    <span class="pill-badge amber">PEDAGOGICAL INNOVATION</span>
                    <h2 class="slide-title">Everyday Relatable Scenarios & Socratic AI</h2>
                    <p class="slide-subtitle">Translating Abstract Foreign Theorems into Lived Nigerian Realities and Guided Critical Thinking</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Everyday Relatable Scenarios Bank</span>
                            <span class="pill-badge amber">CONTEXTUAL</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px; gap: 14px;">
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-amber);">🚌</span>
                                <div>
                                    <strong style="color: #FFFFFF;">Newton's 1st Law (Inertia):</strong>
                                    <div style="font-size: 13.5px; color: #CBD5E1; margin-top: 2px;">Standing inside a speeding yellow Danfo bus on Ikorodu Road when the driver abruptly hits the brakes — your upper torso lurches forward because your mass resists change in velocity.</div>
                                </div>
                            </li>
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-amber);">🛶</span>
                                <div>
                                    <strong style="color: #FFFFFF;">Newton's 3rd Law (Action/Reaction):</strong>
                                    <div style="font-size: 13.5px; color: #CBD5E1; margin-top: 2px;">Stepping off a wooden canoe onto the muddy shore of a Lagos lagoon — the forward push of your leg exerts an equal and opposite force that kicks the canoe backward into the water.</div>
                                </div>
                            </li>
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-amber);">🍲</span>
                                <div>
                                    <strong style="color: #FFFFFF;">Osmosis & Semi-Permeable Membranes:</strong>
                                    <div style="font-size: 13.5px; color: #CBD5E1; margin-top: 2px;">Soaking rock-hard, wrinkled dried honey beans in fresh water overnight — discovering them swollen and soft by morning as water permeates the bean skin to dilute concentrated starches.</div>
                                </div>
                            </li>
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-amber);">🍛</span>
                                <div>
                                    <strong style="color: #FFFFFF;">Opportunity Cost & Scarcity (Economics):</strong>
                                    <div style="font-size: 13.5px; color: #CBD5E1; margin-top: 2px;">Holding only ₦1,500 and deciding between an internet data bundle for school assignments or a hot plate of cafeteria jollof rice — the true economic cost is the meal forfeited.</div>
                                </div>
                            </li>
                        </ul>
                    </div>

                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Socratic AI Tutor (Hint-First Mode)</span>
                            <span class="pill-badge cyan">SOCRATIC AI</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Anti-Spoon-Feeding Law:</strong> Refuses to reveal multiple-choice letters (A, B, C, D) or copy-paste answers, preventing intellectual dependency.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Diagnostic Guided Inquiry:</strong> When a student misses a question, the AI asks probing questions to isolate the core rule, variable, or grammar distinction.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Step-by-Step Walking:</strong> Guides the candidate through equations (e.g. <em>"Look at Kinetic Energy Ek = 1/2mv^2. If speed doubles, what happens to velocity squared?"</em>).</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Deterministic Offline Hint Matrices:</strong> If internet connectivity drops, the system falls back to pre-compiled rule matrices stored inside local SQLite.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Curriculum-Grounded:</strong> Trained exclusively on verified NERDC, JAMB, and WAEC syllabi, eliminating AI hallucinations.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">06 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 7: 1v1 Arena & Spaced Repetition
                 ========================================== -->
            <section class="slide" id="slide-7">
                <div class="slide-header">
                    <span class="pill-badge purple">RETENTION & GAMIFICATION</span>
                    <h2 class="slide-title">1v1 Multiplayer CBT Arena & Spaced Repetition</h2>
                    <p class="slide-subtitle">Turning Solitary Exam Drills into an Electrifying Social Sport While Halting Cognitive Decay</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card purple">
                        <div class="card-header">
                            <span class="card-title">1v1 Multiplayer CBT Arena (/arena)</span>
                            <span class="pill-badge purple">REAL-TIME</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Electrifying 5-Minute Academic Duels:</strong> Two candidates anywhere in Nigeria enter a virtual ring for a 15-question rapid-fire clash drawn from their shared syllabus.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Ultra-Low Latency WebSocket Sync:</strong> Live synchronized score counters tick upward with sub-100ms response times, consuming negligible data bytes.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Automated Study Bot Sparring:</strong> If no human peer matches within 20 seconds at odd hours, an intelligent study bot matched to candidate skill steps in.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Gamified XP & Daily Streaks:</strong> Duels earn Experience Points (XP), level up avatars, and maintain consecutive daily study streaks.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>National School Leaderboards:</strong> Weekly state and school rankings foster healthy academic rivalry and pride.</li>
                        </ul>
                    </div>

                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Spaced-Repetition Review Queue (/review)</span>
                            <span class="pill-badge">MEMORY RETENTION</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">🔄</span> <strong>Automated Mistake Harvesting:</strong> Every incorrect or skipped question from CBT mocks or practice sessions is instantly queued for retention.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔄</span> <strong>Ebbinghaus Forgetting Curve Calibration:</strong> Vulnerabilities resurface at scientifically calculated intervals: <strong>24 Hours, 72 Hours, and 7 Days later</strong>.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔄</span> <strong>Targeted Remediation vs Blind Cramming:</strong> Eliminates the waste of re-sitting entire 50-question papers; targets only documented cognitive gaps.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔄</span> <strong>Permanent Memory Consolidation:</strong> Questions graduate from the queue only after two consecutive correct answers under timed pressure.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔄</span> <strong>Seamless Multi-Platform Sync:</strong> Synchronizes between online web sessions and offline Android SQLite databases.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">07 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 8: Zero-Data Sovereign Architecture
                 ========================================== -->
            <section class="slide" id="slide-8">
                <div class="slide-header">
                    <span class="pill-badge cyan">TECHNICAL INFRASTRUCTURE</span>
                    <h2 class="slide-title">Zero-Data Sovereign Architecture & 5 Offline Desks</h2>
                    <p class="slide-subtitle">Engineered to Flourish Where Mobile Broadband Fails and Electrical Power Fluctuates Across Nigeria</p>
                </div>

                <div class="slide-body grid-3">
                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">The 5 Offline Desks</span>
                            <span class="pill-badge">PACKAGES</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">📦</span> <strong>JAMB UTME Offline Desk:</strong> Full 46 subject packs with official 180-question mock generator.</li>
                            <li class="bullet-item"><span class="bullet-icon">📦</span> <strong>WAEC WASSCE Desk:</strong> 61 packs with objective and worked theory solutions.</li>
                            <li class="bullet-item"><span class="bullet-icon">📦</span> <strong>NECO SSCE Desk:</strong> 11 series covering standard secondary school testing.</li>
                            <li class="bullet-item"><span class="bullet-icon">📦</span> <strong>Post-UTME Desk:</strong> Direct screening questions for UNILAG, FUTA, UI, OAU.</li>
                            <li class="bullet-item"><span class="bullet-icon">📦</span> <strong>School Workspace Desk:</strong> Complete teacher lesson notes, schemes, and banks.</li>
                        </ul>
                    </div>

                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Android SQLite Shell</span>
                            <span class="pill-badge cyan">MOBILE</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">📱</span> <strong>Native Flutter Performance:</strong> Runs smoothly even on low-cost entry-level Android smartphones.</li>
                            <li class="bullet-item"><span class="bullet-icon">📱</span> <strong>Embedded SQLite DB:</strong> Stores tens of thousands of questions and syllabi locally on the device.</li>
                            <li class="bullet-item"><span class="bullet-icon">📱</span> <strong>One-Time 5-Minute Sync:</strong> Connect to Wi-Fi once, download packs, and study for 6 months offline.</li>
                            <li class="bullet-item"><span class="bullet-icon">📱</span> <strong>Zero Data Consumption:</strong> Full CBT mocks, Clock Coach, and scenarios function in Airplane Mode.</li>
                            <li class="bullet-item"><span class="bullet-icon">📱</span> <strong>Standalone APK:</strong> Direct download without requiring high-friction app store accounts.</li>
                        </ul>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Go Backend & Edge Web</span>
                            <span class="pill-badge amber">CLOUD</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Go 1.27 Study API:</strong> Sub-15ms execution latency using goroutine worker pools for async grading.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Next.js 15 Static Gen:</strong> Over 1,446 pre-rendered static routes on zero-cost edge networks.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>ADR-0003 Sealed Keys:</strong> Questions contain only stems and choices; keys live strictly server-side.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>SHA-256 Checksums:</strong> Integrity verification prevents client-side question tampering.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Multi-Tenant Postgres:</strong> Strict separation between student data and school records.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">08 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 9: School OS: NERDC & Paper Slashing
                 ========================================== -->
            <section class="slide" id="slide-9">
                <div class="slide-header">
                    <span class="pill-badge">INSTITUTIONAL EFFICIENCY</span>
                    <h2 class="slide-title">NERDC Curriculum Auto-Install & 70% Paper Slashing</h2>
                    <p class="slide-subtitle">Standardizing Academic Operations in 60 Seconds While Eradicating Crushing Printing Expenses</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">1-Tap NERDC Statutory Installation</span>
                            <span class="pill-badge">CURRICULUM</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Zero Manual Data Entry:</strong> Upon registration, Renance auto-provisions the official NERDC curriculum framework in 60 seconds.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Complete National Ladder:</strong> Pre-populates Primary 1 to Primary 6, JSS 1 to JSS 3, and SSS 1 to SSS 3.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>All Secondary Streams:</strong> Covers Science, Arts, Commercial, and Technical subject pathways aligned with WAEC/NECO.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>12-Week Schemes of Work:</strong> Instant term schemes pre-fill every subject slot. Teachers customize rather than staring at blank pages.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Multi-Tier Role Isolation:</strong> Proprietors hold sovereign administrative/financial keys; teachers access only assigned classes.</li>
                        </ul>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Ink-Saving B&W Print Architecture</span>
                            <span class="pill-badge amber">70%+ SAVINGS</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">📄</span> <strong>Strict Black-and-White Standard:</strong> Decorative color backgrounds and fills are banned, optimizing output for office laser printers.</li>
                            <li class="bullet-item"><span class="bullet-icon">📄</span> <strong>Single-Topic Print Optimization:</strong> Exports clean, 1-topic lesson sheets, ending wasteful 50-page notebook bulk printing.</li>
                            <li class="bullet-item"><span class="bullet-icon">📄</span> <strong>Economic Impact on School Budgets:</strong> In an era where paper reams cost ₦9,000, Renance slashes paper expenditure from ₦300k+ to under ₦90k per term.</li>
                            <li class="bullet-item"><span class="bullet-icon">📄</span> <strong>NERDC School Exam Pool:</strong> 1-click terminal examination generation pulls balanced, randomized papers ready for instant printing.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">09 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 10: Institutional Daily Operations
                 ========================================== -->
            <section class="slide" id="slide-10">
                <div class="slide-header">
                    <span class="pill-badge cyan">DAILY OPERATIONS</span>
                    <h2 class="slide-title">Attendance Roster, Gate Kiosk & Collision-Free Timetable</h2>
                    <p class="slide-subtitle">Streamlining Morning Roll Call, Gate Entry, and Weekly Scheduling into Synchronized Workflows</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">30-Second Attendance & Gate Kiosk Mode</span>
                            <span class="pill-badge cyan">LOGISTICS</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">⏱️</span> <strong>30-Second Classroom Roll Call:</strong> Mobile tap-toggle roster eliminates 15 minutes of wasted morning roll calls.</li>
                            <li class="bullet-item"><span class="bullet-icon">⏱️</span> <strong>Gate Kiosk Mode:</strong> Tablet or laptop mounted at the school gate logs arrivals in real time, alerting management to truancy.</li>
                            <li class="bullet-item"><span class="bullet-icon">⏱️</span> <strong>SUBEB Regulatory Compliance:</strong> One-click export of monthly attendance registers in CSV/JSON format for state inspections.</li>
                            <li class="bullet-item"><span class="bullet-icon">⏱️</span> <strong>PTA Attendance Analytics:</strong> Generates termly student attendance percentages printed directly on verified terminal report cards.</li>
                        </ul>
                    </div>

                    <div class="card purple">
                        <div class="card-header">
                            <span class="card-title">Collision-Free Timetable Matrix</span>
                            <span class="pill-badge purple">SCHEDULING</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">📅</span> <strong>Visual Weekly Matrix Builder:</strong> Intuitive grid mapping subjects, academic periods, assemblies, and recreation breaks.</li>
                            <li class="bullet-item"><span class="bullet-icon">📅</span> <strong>Atomic Single-Transaction Commit:</strong> Validates entire weekly schedule at once, preventing double-booked classrooms or overlapping teachers.</li>
                            <li class="bullet-item"><span class="bullet-icon">📅</span> <strong>Instant Staff Distribution:</strong> Once approved by management, timetable instantly propagates to all teacher personal mobile dashboards.</li>
                            <li class="bullet-item"><span class="bullet-icon">📅</span> <strong>Offline Classroom Reference:</strong> Teachers view assigned weekly schedules directly on their phones without paper printouts.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">10 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 11: Tamper-Proof Grading & Result Checker
                 ========================================== -->
            <section class="slide" id="slide-11">
                <div class="slide-header">
                    <span class="pill-badge">ACADEMIC INTEGRITY</span>
                    <h2 class="slide-title">Tamper-Proof Continuous Assessment & Result Checker</h2>
                    <p class="slide-subtitle">Eradicating Report Card Forgery and Eliminating Human Error from Terminal Grade Computation</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Universal Continuous Assessment Model</span>
                            <span class="pill-badge">STATUTORY CA</span>
                        </div>
                        <div style="background: rgba(0,0,0,0.3); padding: 14px 20px; border-radius: 12px; font-family: var(--font-mono); font-size: 14px; color: var(--accent-emerald);">
                            Final Score (100%) = CA1 (20%) + CA2 (20%) + Terminal Exam (60%)
                        </div>
                        <ul class="bullet-list" style="margin-top: 10px;">
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Automated Calculations:</strong> Instantly calculates student totals, subject averages, grade boundaries (A1 to F9), and class rankings.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Classroom Isolation:</strong> Teachers enter scores only for their assigned class and subject, preventing unauthorized grade manipulation.</li>
                            <li class="bullet-item"><span class="bullet-icon">✔</span> <strong>Lock & Certify Workflow:</strong> Management reviews and signs off on results; finalized records lock against retroactive tampering.</li>
                        </ul>
                    </div>

                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Public Parent Result Checker (/school/check)</span>
                            <span class="pill-badge cyan">FRAUD-PROOF</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">🔒</span> <strong>6-Digit Cryptographic Scratch PIN:</strong> Unique session-scoped PIN generated for each enrolled pupil at term end.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔒</span> <strong>Zero-Travel Smartphone Access:</strong> Parents navigate to /school/check, enter Student ID + PIN, and unlock verified digital report cards.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔒</span> <strong>Complete Forgery Eradication:</strong> Halts razor-blade grade alterations, correction fluid tampering, and ₦500 counterfeit cyber-cafe prints.</li>
                            <li class="bullet-item"><span class="bullet-icon">🔒</span> <strong>Official Institutional Seals:</strong> Displays verified school logo, principal endorsement, subject remarks, and tamper-proof security hash.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">11 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 12: Financial Governance & ID Cards
                 ========================================== -->
            <section class="slide" id="slide-12">
                <div class="slide-header">
                    <span class="pill-badge amber">FINANCIAL GOVERNANCE</span>
                    <h2 class="slide-title">Integer-Safe Kobo Accounting & Serialized ID Cards</h2>
                    <p class="slide-subtitle">Halting Revenue Leakage, Tracking Tuition Debtors, and Automating Student Identity Verification</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Integer-Safe Kobo Accounting Ledger</span>
                            <span class="pill-badge amber">FINANCIAL</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">💰</span> <strong>Exact Integer Accounting:</strong> Calculates every transaction in integer kobo (100 kobo = ₦1.00), preventing floating-point rounding loss.</li>
                            <li class="bullet-item"><span class="bullet-icon">💰</span> <strong>Multi-Tier Fee Structures:</strong> Configures tuition, lab levies, uniforms, and PTA dues universally or by specific class cohorts.</li>
                            <li class="bullet-item"><span class="bullet-icon">💰</span> <strong>Multi-Channel Digital Receipts:</strong> Logs cash, verified bank transfer, POS, and drafts with immutable transaction receipt hashes.</li>
                            <li class="bullet-item"><span class="bullet-icon">💰</span> <strong>Real-Time Debtor Defaulter Roster:</strong> Principals view searchable rosters of unpaid fees, preventing exam-week fee evasion.</li>
                        </ul>
                    </div>

                    <div class="card purple">
                        <div class="card-header">
                            <span class="card-title">Automated Serialized ID Card Engine</span>
                            <span class="pill-badge purple">IDENTITY</span>
                        </div>
                        <ul class="bullet-list">
                            <li class="bullet-item"><span class="bullet-icon">🪪</span> <strong>National Matriculation Serials:</strong> Standardized institutional format: <code>REN-2026-NNNNNN</code> (e.g., <code>REN-2026-000142</code>).</li>
                            <li class="bullet-item"><span class="bullet-icon">🪪</span> <strong>Print-Ready 8-Card Batch Sheets:</strong> Exports printable sheets with pupil photographs, blood groups, emergency contacts, barcodes, and seals.</li>
                            <li class="bullet-item"><span class="bullet-icon">🪪</span> <strong>Bypasses External Graphic Vendors:</strong> Schools print directly on office cardstock and laminate in-house, saving ₦150k+ yearly.</li>
                            <li class="bullet-item"><span class="bullet-icon">🪪</span> <strong>Instant Anti-Fraud Revocation:</strong> Stolen or lost credentials are blacklisted instantly without deleting historical academic records.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">12 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 13: Market Opportunity Across 774 LGAs
                 ========================================== -->
            <section class="slide" id="slide-13">
                <div class="slide-header">
                    <span class="pill-badge cyan">MARKET OPPORTUNITY</span>
                    <h2 class="slide-title">Massive National Footprint Across 774 LGAs</h2>
                    <p class="slide-subtitle">Capturing Nigeria's Expanding EdTech Frontier with an Unfair Offline Distribution Advantage</p>
                </div>

                <div class="slide-body grid-3">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Total Addressable Market</span>
                            <span class="pill-badge cyan">TAM</span>
                        </div>
                        <div class="card-metric" style="color: var(--accent-cyan);">₦120B+</div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> 1.4M+ Annual JAMB UTME candidates seeking university admission.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> 1.6M+ Annual WAEC WASSCE candidates writing secondary leaver exams.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> 1.2M+ Annual NECO SSCE candidates across public and private centers.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Millions of basic education pupils requiring curriculum support.</li>
                        </ul>
                    </div>

                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Serviceable Market</span>
                            <span class="pill-badge">SAM</span>
                        </div>
                        <div class="card-metric" style="color: var(--accent-emerald);">40,000+</div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> Primary & secondary schools across 36 States + FCT needing digital tools.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> 250+ Tertiary Institutions (Universities, Polytechnics, Colleges of Ed).</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> 774 Local Government Areas: One sovereign deployment surface.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> UBEC & SUBEB Partnerships: Direct compliance with digital mandates.</li>
                        </ul>
                    </div>

                    <div class="card amber">
                        <div class="card-header">
                            <span class="card-title">Teacher Income & Jobs</span>
                            <span class="pill-badge amber">SCALE</span>
                        </div>
                        <div class="card-metric" style="color: var(--accent-amber);">2-Sided</div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">•</span> Earning Platform for Teachers: Verified educators monetize revision notes.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Monetizing Real Demand: Tutors reach candidates across 774 LGAs.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Unfair Advantage: Zero-data offline capability unlocks deep rural markets.</li>
                            <li class="bullet-item"><span class="bullet-icon">•</span> Works on inexpensive Android phones without high data bills.</li>
                        </ul>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">13 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 14: Business Model & Unit Economics
                 ========================================== -->
            <section class="slide" id="slide-14">
                <div class="slide-header">
                    <span class="pill-badge">BUSINESS MODEL</span>
                    <h2 class="slide-title">Dual-Engine Monetization & High-Margin Unit Economics</h2>
                    <p class="slide-subtitle">Predictable High-Volume Consumer Subscriptions Paired with Recurring Institutional B2B SaaS</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">Student Consumer Economy (B2C)</span>
                            <span class="pill-badge cyan">SUBSCRIPTIONS</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>Free Frictionless Tier:</strong> 1 free full CBT simulation + 20 questions/session.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>₦500 / 1 Week Pass:</strong> Ideal for rapid pre-exam cramming sprints.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>₦1,500 / 1 Month Pass:</strong> Full access to all 681 packs and Socratic AI tutor.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>₦2,500 / 3 Months Pass:</strong> Termly prep for WAEC, NECO, or JAMB.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>₦5,000 / 1 Year All-Access (Best Value):</strong> Unrestricted web & mobile offline desks.</li>
                            <li class="bullet-item"><span class="bullet-icon">⚡</span> <strong>REN Coin In-App Economy:</strong> Win duels (+1 REN$), refer peers (+3 REN$), redeem 250 REN$ for 1 month premium.</li>
                        </ul>
                    </div>

                    <div class="card emerald">
                        <div class="card-header">
                            <span class="card-title">Institutional School SaaS Tiers (B2B)</span>
                            <span class="pill-badge">SCHOOL SAAS</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px;">
                            <li class="bullet-item"><span class="bullet-icon">🏫</span> <strong>Basic (₦3,000/mo or ₦10,000/yr):</strong> Up to 100 students. View-only notes, curriculum, attendance & results.</li>
                            <li class="bullet-item"><span class="bullet-icon">🏫</span> <strong>Standard (₦6,000/mo or ₦25,000/yr) — Most Popular:</strong> Up to 300 students. Exam bank, timetable, fee ledger, and ID cards.</li>
                            <li class="bullet-item"><span class="bullet-icon">🏫</span> <strong>Premium (₦20,000/mo or ₦60,000/yr):</strong> Unlimited students. Full PDF downloads, complete operations + 10 free annual student passes.</li>
                            <li class="bullet-item"><span class="bullet-icon">🏫</span> <strong>Proprietor Friendly:</strong> School pays a flat predictable fee. Zero per-teacher micro-charges.</li>
                            <li class="bullet-item"><span class="bullet-icon">🏫</span> <strong>High Retention:</strong> Once academic records and ledgers are established, annual churn is &lt;5%.</li>
                        </ul>
                    </div>
                </div>

                <div style="background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); padding: 18px 28px; border-radius: 14px; text-align: center; margin-top: 14px;">
                    <div style="font-size: 16px; font-weight: 700; color: var(--accent-amber);">HIGH-MARGIN UNIT ECONOMICS: OVER 85% GROSS MARGINS</div>
                    <div style="font-size: 14px; color: #CBD5E1; margin-top: 4px;">Static Site Generation on edge CDNs combined with local SQLite on Android means marginal server cost per active offline student approaches ₦0.00. Every additional subscriber drops straight to the bottom line.</div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">14 / 15</span>
                </div>
            </section>

            <!-- ==========================================
                 SLIDE 15: The Builders & Ask
                 ========================================== -->
            <section class="slide" id="slide-15">
                <div class="slide-header">
                    <span class="pill-badge">THE BUILDERS & THE ASK</span>
                    <h2 class="slide-title">The Engineering Team, Capital Allocation & Vision</h2>
                    <p class="slide-subtitle">A Lean Technical Team Shipping Sovereign Educational Infrastructure for 774 Local Government Areas</p>
                </div>

                <div class="slide-body grid-2">
                    <div class="card cyan">
                        <div class="card-header">
                            <span class="card-title">The Builders: Lean Technical Leadership</span>
                            <span class="pill-badge cyan">TEAM</span>
                        </div>
                        <ul class="bullet-list" style="font-size: 15px; gap: 14px;">
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-cyan);">👤</span>
                                <div>
                                    <strong style="color: #FFFFFF; font-size: 16px;">Chief Technology Officer (CTO)</strong>
                                    <div style="font-size: 13.5px; color: var(--accent-cyan); font-weight: 600;">Core Go Architecture & Renance AI Training</div>
                                    <div style="font-size: 13px; color: #CBD5E1; margin-top: 2px;">Owns the high-throughput Go grading engine (&lt;15ms), PostgreSQL schemas, and pedagogical AI models.</div>
                                </div>
                            </li>
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-cyan);">👤</span>
                                <div>
                                    <strong style="color: #FFFFFF; font-size: 16px;">Lead Cybersecurity Engineer</strong>
                                    <div style="font-size: 13.5px; color: var(--accent-cyan); font-weight: 600;">Device-Lock & Anti-Cheat Doctrine</div>
                                    <div style="font-size: 13px; color: #CBD5E1; margin-top: 2px;">Owns 1-device hardware binding, ADR-0003 sealed answer keys, result encryption, and anti-fraud PINs.</div>
                                </div>
                            </li>
                            <li class="bullet-item">
                                <span class="bullet-icon" style="color: var(--accent-cyan);">👤</span>
                                <div>
                                    <strong style="color: #FFFFFF; font-size: 16px;">Chief Product Engineer</strong>
                                    <div style="font-size: 13.5px; color: var(--accent-cyan); font-weight: 600;">Cross-Platform UX/UI & Mobile SQLite Shell</div>
                                    <div style="font-size: 13px; color: #CBD5E1; margin-top: 2px;">Owns the Next.js Web Launcher, Flutter Android APK, and offline-first desk performance.</div>
                                </div>
                            </li>
                        </ul>
                    </div>

                    <div style="display: flex; flex-direction: column; gap: 20px;">
                        <div class="card amber" style="padding: 24px 28px;">
                            <div class="card-header">
                                <span class="card-title" style="font-size: 20px;">Funding Utilization (The Ask)</span>
                                <span class="pill-badge amber">CAPITAL ASK</span>
                            </div>
                            <ul class="bullet-list" style="font-size: 14px; gap: 10px;">
                                <li class="bullet-item"><span class="bullet-icon" style="color: var(--accent-amber);">40%</span> <strong>Awareness Campaigns & Workshops:</strong> Onboarding 500+ private and public schools.</li>
                                <li class="bullet-item"><span class="bullet-icon" style="color: var(--accent-amber);">35%</span> <strong>AI Token Reserves & Cloud Storage:</strong> High-throughput inference and geo-redundant backups.</li>
                                <li class="bullet-item"><span class="bullet-icon" style="color: var(--accent-amber);">25%</span> <strong>Developer Accounts & Distribution:</strong> Apple ($99), Google ($25), Microsoft ($19), and APK mirrors.</li>
                            </ul>
                        </div>

                        <div class="card emerald" style="padding: 28px 32px; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.4);">
                            <div style="font-family: var(--font-display); font-size: 24px; font-weight: 700; color: #FFFFFF;">Modernizing Nigerian Education.</div>
                            <div style="font-size: 16px; color: var(--accent-emerald); font-weight: 600; margin-top: 4px;">One sovereign platform. Two engines. 774 Local Government Areas.</div>
                            <div style="font-family: var(--font-mono); font-size: 15px; color: var(--accent-cyan); margin-top: 10px; font-weight: 700;">renance.app • Learn. Practice. Rise.</div>
                        </div>
                    </div>
                </div>

                <div class="slide-footer">
                    <span class="footer-brand"><span class="brand-dot"></span> RENANCE • Sovereign Educational OS (renance.app)</span>
                    <span class="slide-counter">15 / 15</span>
                </div>
            </section>
        </main>
    </div>

    <!-- Floating HUD Controls -->
    <div class="deck-controls">
        <button class="ctrl-btn" id="prevBtn" title="Previous Slide (Left Arrow)">◀ Prev</button>
        <div class="ctrl-dots" id="dotsContainer"></div>
        <button class="ctrl-btn" id="nextBtn" title="Next Slide (Right Arrow or Space)">Next ▶</button>
        <span style="width: 1px; height: 16px; background: rgba(255,255,255,0.2); margin: 0 4px;"></span>
        <button class="ctrl-btn" id="fullscreenBtn" title="Toggle Fullscreen (F)">⛶ Fullscreen</button>
    </div>

    <script>
        /* ===========================================
           STAGE SCALING & KEYBOARD NAVIGATION ENGINE
           =========================================== */
        const STAGE_WIDTH = 1920;
        const STAGE_HEIGHT = 1080;
        const stage = document.getElementById('deckStage');
        const slides = Array.from(document.querySelectorAll('.slide'));
        const dotsContainer = document.getElementById('dotsContainer');
        const prevBtn = document.getElementById('prevBtn');
        const nextBtn = document.getElementById('nextBtn');
        const fullscreenBtn = document.getElementById('fullscreenBtn');

        let currentSlide = 0;

        // Auto Scale Stage
        function updateStageScale() {
            const vw = window.innerWidth;
            const vh = window.innerHeight;
            const scale = Math.min(vw / STAGE_WIDTH, vh / STAGE_HEIGHT);
            const x = (vw - STAGE_WIDTH * scale) / 2;
            const y = (vh - STAGE_HEIGHT * scale) / 2;
            stage.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
        }

        window.addEventListener('resize', updateStageScale);
        updateStageScale();

        // Render Navigation Dots
        slides.forEach((_, idx) => {
            const dot = document.createElement('div');
            dot.className = 'ctrl-dot' + (idx === 0 ? ' active' : '');
            dot.title = `Slide ${idx + 1}`;
            dot.addEventListener('click', () => goToSlide(idx));
            dotsContainer.appendChild(dot);
        });

        const dots = Array.from(document.querySelectorAll('.ctrl-dot'));

        function goToSlide(index) {
            if (index < 0 || index >= slides.length) return;
            slides[currentSlide].classList.remove('active');
            dots[currentSlide].classList.remove('active');

            currentSlide = index;

            slides[currentSlide].classList.add('active');
            dots[currentSlide].classList.add('active');
        }

        function nextSlide() { goToSlide(currentSlide + 1); }
        function prevSlide() { goToSlide(currentSlide - 1); }

        nextBtn.addEventListener('click', nextSlide);
        prevBtn.addEventListener('click', prevSlide);

        // Keyboard Controls
        window.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') {
                e.preventDefault();
                nextSlide();
            } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
                e.preventDefault();
                prevSlide();
            } else if (e.key === 'Home') {
                e.preventDefault();
                goToSlide(0);
            } else if (e.key === 'End') {
                e.preventDefault();
                goToSlide(slides.length - 1);
            } else if (e.key === 'f' || e.key === 'F') {
                e.preventDefault();
                toggleFullscreen();
            }
        });

        // Fullscreen Toggle
        function toggleFullscreen() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen().catch(err => console.log(err));
            } else {
                document.exitFullscreen();
            }
        }
        fullscreenBtn.addEventListener('click', toggleFullscreen);

        // Touch & Swipe Support
        let touchStartX = 0;
        window.addEventListener('touchstart', e => { touchStartX = e.changedTouches[0].screenX; }, false);
        window.addEventListener('touchend', e => {
            let touchEndX = e.changedTouches[0].screenX;
            if (touchEndX < touchStartX - 50) nextSlide();
            if (touchEndX > touchStartX + 50) prevSlide();
        }, false);
    </script>
</body>
</html>
'''

with open('docs/RENANCE_15_SLIDE_PRESENTATION.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("Generated docs/RENANCE_15_SLIDE_PRESENTATION.html successfully!")
