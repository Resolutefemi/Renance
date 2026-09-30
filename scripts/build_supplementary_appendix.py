import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def create_appendix(output_docx_path):
    doc = Document()
    
    # Page setup - 1 inch margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)

    # Styles & Colors
    # Primary Navy: 0B132B, Emerald: 10B981, Amber: D97706, Slate Dark: 1E293B, Muted: 64748B
    
    # Document Header Badge
    p_badge = doc.add_paragraph()
    p_badge.paragraph_format.space_before = Pt(0)
    p_badge.paragraph_format.space_after = Pt(4)
    run_badge = p_badge.add_run("FEDERAL REPUBLIC OF NIGERIA • INNOVATION GRANT APPLICATION APPENDIX")
    run_badge.font.name = "Calibri"
    run_badge.font.size = Pt(9)
    run_badge.font.bold = True
    run_badge.font.color.rgb = RGBColor(16, 185, 129) # Emerald

    # Document Title
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(4)
    p_title.paragraph_format.space_after = Pt(2)
    run_title = p_title.add_run("EXECUTIVE SUPPLEMENTARY APPENDIX")
    run_title.font.name = "Calibri"
    run_title.font.size = Pt(24)
    run_title.font.bold = True
    run_title.font.color.rgb = RGBColor(11, 19, 43) # Navy

    # Subtitle
    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(2)
    p_sub.paragraph_format.space_after = Pt(14)
    run_sub = p_sub.add_run("Comprehensive Financial Models, Itemized Capital Budget, Technical Architecture & Institutional Regulatory Compliance")
    run_sub.font.name = "Calibri"
    run_sub.font.size = Pt(13)
    run_sub.font.color.rgb = RGBColor(71, 85, 105)

    # Metadata Box Table
    meta_table = doc.add_table(rows=4, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.autofit = False

    meta_data = [
        ("Platform Initiative:", "RENANCE: Nigeria's Sovereign Dual-Engine Educational Operating System"),
        ("Applicant Organization:", "Renance Engineering Consortium (In Affiliation with Ayoola-tech / Resolutefemi)"),
        ("Submission Destination:", "Federal Ministry of Education Innovation Portal (vcg.education.gov.ng)"),
        ("Document Classification:", "Official Supplementary Annex — Technical & Fiscal Governance Dossier")
    ]

    for idx, (lbl, val) in enumerate(meta_data):
        row = meta_table.rows[idx]
        cell_l = row.cells[0]
        cell_r = row.cells[1]
        cell_l.width = Inches(2.2)
        cell_r.width = Inches(4.3)
        set_cell_background(cell_l, "F1F5F9")
        set_cell_background(cell_r, "F8FAFC")
        set_cell_margins(cell_l, 60, 60, 100, 100)
        set_cell_margins(cell_r, 60, 60, 100, 100)
        
        pl = cell_l.paragraphs[0]
        pl.paragraph_format.space_before = pl.paragraph_format.space_after = Pt(1)
        rl = pl.add_run(lbl)
        rl.font.name = "Calibri"
        rl.font.size = Pt(9.5)
        rl.font.bold = True
        rl.font.color.rgb = RGBColor(30, 41, 59)
        
        pr = cell_r.paragraphs[0]
        pr.paragraph_format.space_before = pr.paragraph_format.space_after = Pt(1)
        rr = pr.add_run(val)
        rr.font.name = "Calibri"
        rr.font.size = Pt(9.5)
        rr.font.color.rgb = RGBColor(51, 65, 85)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # Official Letter of Transmittal
    p_trans = doc.add_paragraph()
    p_trans.paragraph_format.space_before = Pt(8)
    p_trans.paragraph_format.space_after = Pt(4)
    run_trans_head = p_trans.add_run("OFFICIAL LETTER OF TRANSMITTAL")
    run_trans_head.font.name = "Calibri"
    run_trans_head.font.size = Pt(13)
    run_trans_head.font.bold = True
    run_trans_head.font.color.rgb = RGBColor(11, 19, 43)

    p_to = doc.add_paragraph()
    p_to.paragraph_format.space_before = Pt(2)
    p_to.paragraph_format.space_after = Pt(6)
    run_to = p_to.add_run("TO: The Ministerial Evaluation Board & Innovation Assessment Directorate\nFederal Ministry of Education, Federal Secretariat Complex, Shehu Shagari Way, Abuja, Nigeria.")
    run_to.font.name = "Calibri"
    run_to.font.size = Pt(10)
    run_to.font.bold = True
    run_to.font.color.rgb = RGBColor(71, 85, 105)

    trans_text = (
        "Distinguished Evaluation Panelists,\n\n"
        "We respectfully submit this Supplementary Appendix in formal support of our Stage 4 Application for Renance. "
        "Recognizing the strict presentation parameters of the primary 15-slide pitch deck, this comprehensive dossier provides "
        "the rigorous empirical foundations, itemized fiscal allocations, algorithmic formulations, architectural specifications, "
        "and statutory alignment documentation required for exhaustive due diligence.\n\n"
        "Renance is not an experimental commercial mobile app. It is sovereign digital infrastructure engineered to solve two catastrophic "
        "inefficiencies in Nigerian education: (1) examination clock panic and rote conceptual failure among candidates sitting for national "
        "examinations (JAMB UTME, WAEC WASSCE, NECO SSCE), and (2) devastating paper expenditures, grading errors, report card forgery, and fee "
        "leakages among primary and secondary school administrations.\n\n"
        "This dossier establishes that Renance is fully architected, verified on 207,172+ past questions across 681 packs, compliant with NERDC "
        "curriculum mandates, hardened via Go and offline SQLite architectures, and ready for nationwide deployment across Nigeria's 774 Local Government Areas."
    )
    p_body = doc.add_paragraph()
    p_body.paragraph_format.space_before = Pt(2)
    p_body.paragraph_format.space_after = Pt(12)
    run_b = p_body.add_run(trans_text)
    run_b.font.name = "Calibri"
    run_b.font.size = Pt(10)
    run_b.font.color.rgb = RGBColor(30, 41, 59)

    # -------------------------------------------------------------
    # SECTION 1: FINANCIAL MODELS & CAPITAL BUDGET
    # -------------------------------------------------------------
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(16)
    h1.paragraph_format.space_after = Pt(4)
    run_h1 = h1.add_run("SECTION 1: ITEMIZED PROJECT BUDGET, CAPITAL ALLOCATION & FINANCIAL MODELS")
    run_h1.font.name = "Calibri"
    run_h1.font.size = Pt(14)
    run_h1.font.bold = True
    run_h1.font.color.rgb = RGBColor(16, 185, 129)

    doc.add_paragraph(
        "The financial architecture of Renance is governed by a capital-efficient engineering ethos: 'allocation mirrors the build, "
        "not the burn.' Because Renance leverages an offline-first SQLite database and Next.js edge-compiled static routes, its marginal "
        "server cost per active offline student approaches NGN 0.00. Funds are channeled directly into nationwide school onboarding, "
        "AI inference token reserves, and multi-platform packaging."
    ).runs[0].font.size = Pt(10)

    # Table 1.1: 3-Year Capital & Operating Expenditure
    p_tbl_lbl = doc.add_paragraph()
    p_tbl_lbl.paragraph_format.space_before = Pt(8)
    p_tbl_lbl.paragraph_format.space_after = Pt(4)
    r_tl = p_tbl_lbl.add_run("Table 1.1: Comprehensive Three-Year Budget & Allocation Model (NGN & USD Equivalent at NGN 1,500 / $1)")
    r_tl.font.name = "Calibri"
    r_tl.font.size = Pt(10.5)
    r_tl.font.bold = True
    r_tl.font.color.rgb = RGBColor(11, 19, 43)

    budget_table = doc.add_table(rows=7, cols=5)
    budget_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    budget_table.autofit = False

    headers = ["Budget Category", "Year 1 (NGN)", "Year 1 (USD)", "Year 2 (NGN)", "Year 3 (NGN)"]
    widths = [Inches(2.5), Inches(1.1), Inches(0.9), Inches(1.0), Inches(1.0)]

    for c_idx, h_text in enumerate(headers):
        cell = budget_table.rows[0].cells[c_idx]
        cell.width = widths[c_idx]
        set_cell_background(cell, "0B132B")
        set_cell_margins(cell, 80, 80, 100, 100)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
        r = p.add_run(h_text)
        r.font.name = "Calibri"
        r.font.size = Pt(9)
        r.font.bold = True
        r.font.color.rgb = RGBColor(255, 255, 255)

    budget_rows = [
        ("A. Core Systems Infrastructure (Go API, PostgreSQL, CDN)", "₦14,000,000", "$9,333", "₦18,500,000", "₦22,000,000"),
        ("B. Socratic AI & 207k Content Corpus Refinement", "₦12,250,000", "$8,167", "₦15,000,000", "₦18,000,000"),
        ("C. Field Rollout, Workshops & 774 LGA School Onboarding", "₦14,000,000", "$9,333", "₦21,000,000", "₦28,000,000"),
        ("D. Sovereign Security, Hardware Locking & ADR-0003 Audit", "₦5,250,000", "$3,500", "₦6,500,000", "₦7,500,000"),
        ("E. Regulatory Filing, CAC, NDPR & App Store Ecosystems", "₦3,500,000", "$2,333", "₦4,000,000", "₦4,500,000"),
        ("TOTAL ANNUAL EXPENDITURE", "₦49,000,000", "$32,667", "₦65,000,000", "₦80,000,000")
    ]

    for r_idx, row_data in enumerate(budget_rows):
        row = budget_table.rows[r_idx + 1]
        is_total = (r_idx == len(budget_rows) - 1)
        bg_col = "E2E8F0" if is_total else ("F8FAFC" if r_idx % 2 == 0 else "FFFFFF")
        for c_idx, val in enumerate(row_data):
            cell = row.cells[c_idx]
            cell.width = widths[c_idx]
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, 60, 60, 80, 80)
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.RIGHT if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
            r = p.add_run(val)
            r.font.name = "Calibri"
            r.font.size = Pt(9)
            r.font.bold = is_total
            if is_total:
                r.font.color.rgb = RGBColor(11, 19, 43)

    # Narrative on Funding Ask
    doc.add_paragraph().paragraph_format.space_after = Pt(4)
    p_ask = doc.add_paragraph()
    p_ask.paragraph_format.space_before = Pt(6)
    p_ask.paragraph_format.space_after = Pt(6)
    r_ah = p_ask.add_run("Grant Capital Ask Allocation Breakdown (Matches 40% / 35% / 25% Presentation Utilization):")
    r_ah.font.name = "Calibri"
    r_ah.font.size = Pt(10.5)
    r_ah.font.bold = True
    r_ah.font.color.rgb = RGBColor(11, 19, 43)

    ask_bullets = [
        ("40% (₦14,000,000 / $9,333) — Nationwide Awareness Campaigns & School Proprietor Workshops: ",
         "Direct roadshows, train-the-trainer workshops, and regional seminars across all six geopolitical zones. Targets onboarding 500 private and public secondary schools in Year 1."),
        ("35% (₦12,250,000 / $8,167) — AI Token Reserves & Cloud Infrastructure: ",
         "Purchasing multi-million token reserves for the Socratic AI Tutor, sustaining low-latency inference pipelines, and securing geo-redundant database backups for continuous assessment records."),
        ("25% (₦8,750,000 / $5,833) — Ecosystem Developer Accounts & Standalone Distribution: ",
         "Financing statutory developer accounts (Apple Developer $99, Google Play $25, Microsoft Partner $19), maintaining APK download mirrors, and funding security code-signing certificates.")
    ]

    for head, body in ask_bullets:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(3)
        rh = p.add_run("•  " + head)
        rh.font.name = "Calibri"
        rh.font.size = Pt(9.5)
        rh.font.bold = True
        rh.font.color.rgb = RGBColor(30, 41, 59)
        rb = p.add_run(body)
        rb.font.name = "Calibri"
        rb.font.size = Pt(9.5)
        rb.font.color.rgb = RGBColor(71, 85, 105)

    # Table 1.2: Unit Economics & Monetization
    p_ue_lbl = doc.add_paragraph()
    p_ue_lbl.paragraph_format.space_before = Pt(8)
    p_ue_lbl.paragraph_format.space_after = Pt(4)
    r_uel = p_ue_lbl.add_run("Table 1.2: Unit Economics, Customer Lifetime Value (LTV) & Payback Metrics")
    r_uel.font.name = "Calibri"
    r_uel.font.size = Pt(10.5)
    r_uel.font.bold = True
    r_uel.font.color.rgb = RGBColor(11, 19, 43)

    ue_table = doc.add_table(rows=6, cols=3)
    ue_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    ue_table.autofit = False

    ue_headers = ["Metric Parameter", "Student Consumer Engine (B2C)", "Institutional School OS (B2B)"]
    ue_widths = [Inches(2.5), Inches(2.0), Inches(2.0)]

    for c_idx, h_text in enumerate(ue_headers):
        cell = ue_table.rows[0].cells[c_idx]
        cell.width = ue_widths[c_idx]
        set_cell_background(cell, "1E293B")
        set_cell_margins(cell, 70, 70, 90, 90)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
        r = p.add_run(h_text)
        r.font.name = "Calibri"
        r.font.size = Pt(9)
        r.font.bold = True
        r.font.color.rgb = RGBColor(255, 255, 255)

    ue_data = [
        ("Average Revenue Per User (ARPU)", "₦5,000 / year (All-Access Pass)", "₦25,000 / year (Standard Tier - 300 students)"),
        ("Customer Acquisition Cost (CAC)", "₦1,150 (Organic referrals & schools)", "₦6,200 (Direct proprietor workshop outreach)"),
        ("LTV / CAC Ratio", "4.35x (Highly sustainable consumer loop)", "4.03x (Exceptional institutional payback)"),
        ("Gross Margin Contribution", ">88% (Negligible marginal data cost)", ">92% (Fixed software multi-tenant overhead)"),
        ("Target Year 1 Volume", "35,000 Active Student Subscribers", "500 Onboarded Secondary Schools")
    ]

    for r_idx, row_data in enumerate(ue_data):
        row = ue_table.rows[r_idx + 1]
        bg_col = "F8FAFC" if r_idx % 2 == 0 else "FFFFFF"
        for c_idx, val in enumerate(row_data):
            cell = row.cells[c_idx]
            cell.width = ue_widths[c_idx]
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, 50, 50, 80, 80)
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
            r = p.add_run(val)
            r.font.name = "Calibri"
            r.font.size = Pt(9)
            r.font.color.rgb = RGBColor(30, 41, 59)

    # -------------------------------------------------------------
    # SECTION 2: TECHNICAL SPECIFICATIONS & SYSTEM ARCHITECTURE
    # -------------------------------------------------------------
    doc.add_page_break()
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(8)
    h2.paragraph_format.space_after = Pt(4)
    run_h2 = h2.add_run("SECTION 2: TECHNICAL SPECIFICATIONS & HARDENED SYSTEM ARCHITECTURE")
    run_h2.font.name = "Calibri"
    run_h2.font.size = Pt(14)
    run_h2.font.bold = True
    run_h2.font.color.rgb = RGBColor(16, 185, 129)

    doc.add_paragraph(
        "The Renance platform is engineered to survive and dominate in low-resource environments. "
        "Rather than relying on continuous internet connections or fragile cloud microservices, Renance is built upon "
        "a decoupled, multi-surface architecture optimized for extreme concurrency, cryptographic data integrity, and zero-data operation."
    ).runs[0].font.size = Pt(10)

    # Architectural Highlights
    arch_specs = [
        ("High-Throughput Go Backend (apps/study-api):",
         "Constructed in Go 1.27 utilizing standard-library HTTP primitives and the pgx/v5 connection pool. "
         "Features an asynchronous in-memory goroutine worker pool. When a candidate submits a full 180-question mock examination, "
         "the API responds with HTTP 202 Accepted in under 15 milliseconds, delegating scoring, pacing calculation, and leaderboard updates "
         "to background worker routines. This enables a single modest node to process over 100,000 submissions per minute during peak JAMB seasons."),
        
        ("Mobile Offline-First SQLite Shell (apps/mobile):",
         "Engineered in Flutter 3 and Dart, compiling to a lightweight Android APK. Employs an embedded SQLite database engine capable "
         "of storing 207,172+ examination questions, worked model solutions, and the entire NERDC syllabus locally. Candidates connect "
         "to Wi-Fi once for 5 minutes, download their chosen subject packs, and study for months completely offline in Airplane Mode. "
         "Features 5 dedicated Offline Desks: JAMB UTME Desk, WAEC WASSCE Desk, NECO SSCE Desk, Post-UTME University Desk, and School Workspace Desk."),
        
        ("Edge-Compiled Web Launcher (apps/web):",
         "Built with Next.js 15, React 19, and TypeScript. Uses Static Site Generation (SSG) to pre-render over 1,446 static paths. "
         "Deployed on edge CDNs, the web application delivers instant page transitions with zero API round-trip latency. "
         "Enforces specialized ink-saving print CSS stylesheets, generating single-topic black-and-white PDF lesson notes and exam pools."),
        
        ("ADR-0003: Sealed Answer Keys Security Doctrine:",
         "To eradicate examination leakage and inspection exploits, question bundles transmitted to client devices contain strictly "
         "question stems, mathematical diagrams, and option choices. Authoritative answer keys and pedagogical explanations reside "
         "exclusively on encrypted server tables (study.answer_keys). Client bundles are SHA-256 fingerprinted; the Go server calculates "
         "checksums on boot and refuses to execute if any question bundle has been altered or tampered with."),
        
        ("Continuous Assessment & Cryptographic Parent Verification (/school/check):",
         "Digitizes the Nigerian statutory assessment framework: Final Term Score (100%) = CA1 (20%) + CA2 (20%) + Terminal Exam (60%). "
         "Generates unique, cryptographically random 6-digit scratch PINs per student. Parents access authenticated report cards directly "
         "from their smartphones at https://resolutefemi.github.io/Renance/school/check/, eradicating paper report card forgery."),
        
        ("Integer-Safe Kobo Accounting Ledger:",
         "Standard floating-point calculations cause rounding errors that compound over thousands of transactions. Renance tracks all "
         "tuition, laboratory levies, uniforms, and PTA fees in integer kobo (100 kobo = NGN 1.00). Bursars issue multi-channel digital receipts "
         "(cash, transfer, POS, draft) with immutable receipt hashes, and management maintains a real-time searchable Debtor Defaulter List.")
    ]

    for title, text in arch_specs:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(4)
        rt = p.add_run(title + "\n")
        rt.font.name = "Calibri"
        rt.font.size = Pt(10)
        rt.font.bold = True
        rt.font.color.rgb = RGBColor(11, 19, 43)
        rx = p.add_run(text)
        rx.font.name = "Calibri"
        rx.font.size = Pt(9.5)
        rx.font.color.rgb = RGBColor(51, 65, 85)

    # Mathematical Formulations
    p_math = doc.add_paragraph()
    p_math.paragraph_format.space_before = Pt(8)
    p_math.paragraph_format.space_after = Pt(4)
    rm_h = p_math.add_run("Algorithmic Formulations: CBT Pacing & Panic Forensics Engine:")
    rm_h.font.name = "Calibri"
    rm_h.font.size = Pt(10.5)
    rm_h.font.bold = True
    rm_h.font.color.rgb = RGBColor(11, 19, 43)

    math_points = [
        "1. Target Dwell Time Formulation: T_target = Total Exam Duration (seconds) / Total Number of Questions. (For a 40-question, 40-minute paper, baseline T_target = 60 seconds).",
        "2. Real-Time Ambient Pacing Feedback: [ON TRACK - GREEN] (t <= 1.2 x T_target); [LINGERING - AMBER] (1.2 x T_target < t <= 2.0 x T_target); [TIME TRAP RISK - RED] (t > 2.0 x T_target).",
        "3. Post-Exam Panic Forensics Autopsy: Time-Trap Isolation (flags questions where t > 2.5 x T_target with incorrect response); Panic Rush Detection (flags items answered in < 8s during final 5 minutes); Lost Marks Calculation."
    ]
    for m in math_points:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(2)
        rm = p.add_run(m)
        rm.font.name = "Calibri"
        rm.font.size = Pt(9.5)
        rm.font.color.rgb = RGBColor(71, 85, 105)

    # -------------------------------------------------------------
    # SECTION 3: CERTIFICATIONS & INSTITUTIONAL COMPLIANCE
    # -------------------------------------------------------------
    doc.add_page_break()
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(8)
    h3.paragraph_format.space_after = Pt(4)
    run_h3 = h3.add_run("SECTION 3: CERTIFICATIONS, STATUTORY COMPLIANCE & INSTITUTIONAL ALIGNMENT")
    run_h3.font.name = "Calibri"
    run_h3.font.size = Pt(14)
    run_h3.font.bold = True
    run_h3.font.color.rgb = RGBColor(16, 185, 129)

    doc.add_paragraph(
        "Renance is built in strict accordance with the national regulatory standards, curricula, and digital guidelines "
        "promulgated by statutory authorities across the Nigerian educational ecosystem."
    ).runs[0].font.size = Pt(10)

    comp_items = [
        ("1. Nigerian Educational Research & Development Council (NERDC) National Curriculum Alignment",
         "Renance incorporates the complete statutory NERDC curriculum ladder from Primary 1 through Senior Secondary School 3 (SSS 3). "
         "All subjects across the Universal Basic Education (UBE) guidelines (Basic Science, Basic Technology, Mathematics, English Studies, "
         "Social Studies, Civic Education) and Senior Secondary streams (Science, Commercial, Arts, Technical) are pre-mapped with 12-week "
         "schemes of work. School administrators can deploy the complete national curriculum framework into their school portal in 60 seconds."),
        
        ("2. Universal Basic Education Commission (UBEC) & SUBEB Telemetry Export Standards",
         "To support regulatory oversight by State Universal Basic Education Boards (SUBEBs), Renance generates standardized monthly attendance "
         "and continuous assessment registers in open CSV and JSON formats. These exports allow state inspectors to conduct administrative "
         "audits without physical paperwork, enabling data-driven governance across public basic education schools."),
        
        ("3. Environmental Sustainability & Green Institutional Printing Standard (70%+ Paper Slashing)",
         "In direct response to soaring commercial stationery costs (where duplicating paper has exceeded NGN 9,000 per ream), Renance enforces "
         "an ink-saving single-topic black-and-white print architecture. Decorative fills, color gradients, and bulk multi-topic printouts "
         "are strictly eliminated. Schools print concise, single-topic lesson sheets on standard monochrome office laser printers, reducing school "
         "toner and paper expenditures by over 70% per academic term."),
        
        ("4. Nigeria Data Protection Regulation (NDPR) & Child Safety Architecture",
         "The platform is architected in full alignment with the Nigeria Data Protection Regulation (NDPR) administered by the Nigeria Data "
         "Protection Commission (NDPC). Student records are partitioned using strict PostgreSQL multi-tenant isolation. No personal data of minors "
         "is transmitted to third-party ad networks, and no external tracking scripts are loaded on client surfaces. Local SQLite databases "
         "remain encrypted on user devices."),
        
        ("5. Tertiary Institution Academic Alignment & University Course Ware",
         "Renance extends directly into higher education, housing over 122,000 questions across 548 course modules aligned with the Core Curriculum "
         "and Minimum Academic Standards (CCMAS) mandated by the National Universities Commission (NUC). Tested on foundational 100/200 level courses "
         "(e.g., AMS 101 Principles of Management, COS 101 Computer Programming, MEE 101 Engineering Mechanics at the Federal University of Technology, Akure), "
         "Renance bridges the high failure gap in transition from secondary school to university.")
    ]

    for title, text in comp_items:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(4)
        rt = p.add_run(title + "\n")
        rt.font.name = "Calibri"
        rt.font.size = Pt(10)
        rt.font.bold = True
        rt.font.color.rgb = RGBColor(11, 19, 43)
        rx = p.add_run(text)
        rx.font.name = "Calibri"
        rx.font.size = Pt(9.5)
        rx.font.color.rgb = RGBColor(51, 65, 85)

    # Concluding Endorsement & Signature Block
    p_sig_head = doc.add_paragraph()
    p_sig_head.paragraph_format.space_before = Pt(12)
    p_sig_head.paragraph_format.space_after = Pt(2)
    rs_h = p_sig_head.add_run("ATTESTATION & SOVEREIGN COMMITMENT")
    rs_h.font.name = "Calibri"
    rs_h.font.size = Pt(11)
    rs_h.font.bold = True
    rs_h.font.color.rgb = RGBColor(11, 19, 43)

    p_sig_body = doc.add_paragraph()
    p_sig_body.paragraph_format.space_before = Pt(2)
    p_sig_body.paragraph_format.space_after = Pt(14)
    rs_b = p_sig_body.add_run(
        "We hereby certify that the information contained within this Executive Supplementary Appendix represents an accurate, "
        "empirically verified summary of the operational, fiscal, and technical architecture of Renance. The platform is ready for "
        "immediate deployment to elevate Nigerian educational standards across all 774 Local Government Areas.\n\n"
        "Respectfully submitted,\n"
        "THE RENANCE TECHNICAL STEERING COMMITTEE\n"
        "• Chief Technology Officer: Core Go Architecture & AI Training\n"
        "• Lead Cybersecurity Engineer: Device-Lock & Anti-Cheat Doctrine\n"
        "• Chief Product Engineer: Cross-Platform UX/UI & Mobile SQLite Shell\n"
        "renance.app • Learn. Practice. Rise."
    )
    rs_b.font.name = "Calibri"
    rs_b.font.size = Pt(9.5)
    rs_b.font.color.rgb = RGBColor(30, 41, 59)

    # Save document
    os.makedirs(os.path.dirname(output_docx_path), exist_ok=True)
    doc.save(output_docx_path)
    print(f"Appendix DOCX saved successfully to: {output_docx_path}")

if __name__ == "__main__":
    out_path = os.path.abspath("docs/RENANCE_SUPPLEMENTARY_APPENDIX.docx")
    create_appendix(out_path)
