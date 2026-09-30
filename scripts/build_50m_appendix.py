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

def set_cell_margins(cell, top=70, bottom=70, left=110, right=110):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def make_row_cant_split(row):
    pass

def make_row_header(row):
    pass

def set_table_borders(table, color="CBD5E1", sz="4", val="single"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'  <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'  <w:left w:val="none"/>'
        f'  <w:right w:val="none"/>'
        f'  <w:insideV w:val="none"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def add_callout(doc, text_paragraphs, border_color="00A859", bg_color="F8FAFC"):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    cell = table.rows[0].cells[0]
    cell.width = Inches(6.9)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=90, bottom=90, left=150, right=130)
    make_row_cant_split(table.rows[0])
    
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>'
        f'  <w:left w:val="single" w:sz="24" w:space="0" w:color="{border_color}"/>'
        f'  <w:top w:val="none"/>'
        f'  <w:bottom w:val="none"/>'
        f'  <w:right w:val="none"/>'
        f'</w:tcBorders>'
    )
    tcPr.append(borders)
    
    p_first = cell.paragraphs[0]
    for idx, (title, content, is_bold_title) in enumerate(text_paragraphs):
        if idx == 0:
            p = p_first
        else:
            p = cell.add_paragraph()
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.1
        
        if title:
            r_t = p.add_run(title + (" " if not is_bold_title else ": "))
            r_t.font.name = "Calibri"
            r_t.font.size = Pt(8.5)
            r_t.font.bold = True
            r_t.font.color.rgb = RGBColor(11, 19, 43)
            
        r_c = p.add_run(content)
        r_c.font.name = "Calibri"
        r_c.font.size = Pt(8.5)
        r_c.font.color.rgb = RGBColor(30, 41, 59)

def format_cell(cell, text, bold=False, color_rgb=(30, 41, 59), font_size=8.0, align=WD_ALIGN_PARAGRAPH.LEFT, bg_hex=None, width_in=None):
    if bg_hex:
        set_cell_background(cell, bg_hex)
    set_cell_margins(cell, top=65, bottom=65, left=90, right=90)
    if width_in:
        cell.width = Inches(width_in)
    p = cell.paragraphs[0]
    p.alignment = align
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.05
    r = p.add_run(text)
    r.font.name = "Calibri"
    r.font.size = Pt(font_size)
    r.font.bold = bold
    r.font.color.rgb = RGBColor(*color_rgb)
    return p

def create_appendix(output_docx_path):
    doc = Document()
    
    # Page setup - 0.75 inch margins
    for section in doc.sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)
        
        footer = section.footer
        p_ft = footer.paragraphs[0]
        p_ft.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        r_ft = p_ft.add_run("Project Renance • Executive Supplementary Appendix — ₦50M Capital Allocation Dossier • renance.app")
        r_ft.font.name = "Calibri"
        r_ft.font.size = Pt(8)
        r_ft.font.color.rgb = RGBColor(148, 163, 184)

    # =============================================================
    # PAGE 1: COVER, METADATA & OFFICIAL LETTER OF TRANSMITTAL
    # =============================================================
    p_badge = doc.add_paragraph()
    p_badge.paragraph_format.space_before = Pt(0)
    p_badge.paragraph_format.space_after = Pt(2)
    run_badge = p_badge.add_run("FEDERAL MINISTRY OF EDUCATION • INNOVATION GRANT APPLICATION DOSSIER")
    run_badge.font.name = "Calibri"
    run_badge.font.size = Pt(8.5)
    run_badge.font.bold = True
    run_badge.font.color.rgb = RGBColor(0, 168, 89)

    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(2)
    p_title.paragraph_format.space_after = Pt(1)
    run_title = p_title.add_run("EXECUTIVE SUPPLEMENTARY APPENDIX")
    run_title.font.name = "Calibri"
    run_title.font.size = Pt(22)
    run_title.font.bold = True
    run_title.font.color.rgb = RGBColor(11, 19, 43)

    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(1)
    p_sub.paragraph_format.space_after = Pt(10)
    run_sub = p_sub.add_run("₦50,000,000 Capital Allocation, 18-Month Operational Runway, Offline Learning Architecture & National School Integration")
    run_sub.font.name = "Calibri"
    run_sub.font.size = Pt(10.5)
    run_sub.font.color.rgb = RGBColor(71, 85, 105)

    # Metadata Table
    meta_table = doc.add_table(rows=6, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.autofit = False

    meta_data = [
        ("Venture Initiative:", "RENANCE: Nigeria's Sovereign Dual-Engine Educational Operating System"),
        ("Applicant Consortium:", "Renance Engineering Consortium (Ayoola-tech & Resolutefemi Ecosystem)"),
        ("Grant Program & Capital:", "Federal Innovation & EdTech Acceleration Grant (₦50,000,000 Capital Grant)"),
        ("Submission Destination:", "Federal Ministry of Education Innovation Portal (vcg.education.gov.ng — Step 4 Slot)"),
        ("Official Web Portal:", "https://renance.app (Verification: https://renance.app/school/check)"),
        ("Deployment Beachhead:", "Ondo State (FUTA / Akure Tech Hub) → Southwest Geopolitical Zone → All 774 LGAs")
    ]

    for idx, (lbl, val) in enumerate(meta_data):
        row = meta_table.rows[idx]
        make_row_cant_split(row)
        cell_l = row.cells[0]
        cell_r = row.cells[1]
        cell_l.width = Inches(2.2)
        cell_r.width = Inches(4.7)
        set_cell_background(cell_l, "F1F5F9")
        set_cell_background(cell_r, "F8FAFC")
        set_cell_margins(cell_l, 40, 40, 80, 80)
        set_cell_margins(cell_r, 40, 40, 80, 80)
        
        pl = cell_l.paragraphs[0]
        pl.paragraph_format.space_before = pl.paragraph_format.space_after = Pt(0)
        rl = pl.add_run(lbl)
        rl.font.name = "Calibri"
        rl.font.size = Pt(8.5)
        rl.font.bold = True
        rl.font.color.rgb = RGBColor(30, 41, 59)
        
        pr = cell_r.paragraphs[0]
        pr.paragraph_format.space_before = pr.paragraph_format.space_after = Pt(0)
        rr = pr.add_run(val)
        rr.font.name = "Calibri"
        rr.font.size = Pt(8.5)
        rr.font.color.rgb = RGBColor(51, 65, 85)

    set_table_borders(meta_table, color="E2E8F0", sz="4")
    doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # Official Letter of Transmittal
    p_trans = doc.add_paragraph()
    p_trans.paragraph_format.space_before = Pt(6)
    p_trans.paragraph_format.space_after = Pt(2)
    p_trans.paragraph_format.keep_with_next = True
    run_trans_head = p_trans.add_run("OFFICIAL LETTER OF TRANSMITTAL")
    run_trans_head.font.name = "Calibri"
    run_trans_head.font.size = Pt(11)
    run_trans_head.font.bold = True
    run_trans_head.font.color.rgb = RGBColor(11, 19, 43)

    p_to = doc.add_paragraph()
    p_to.paragraph_format.space_before = Pt(1)
    p_to.paragraph_format.space_after = Pt(6)
    p_to.paragraph_format.keep_with_next = True
    run_to = p_to.add_run("TO: The Ministerial Evaluation Board & Innovation Assessment Directorate\nFederal Ministry of Education, Federal Secretariat Complex, Shehu Shagari Way, Abuja, Nigeria.")
    run_to.font.name = "Calibri"
    run_to.font.size = Pt(9.0)
    run_to.font.bold = True
    run_to.font.color.rgb = RGBColor(71, 85, 105)

    trans_text_1 = (
        "Distinguished Evaluation Panelists,\n\n"
        "We respectfully tender this Executive Supplementary Appendix in formal support of our Step 4 submission for Project Renance. "
        "While our primary 15-slide pitch deck provides a concise summary of our mission and vision, this document details the exact 18-month "
        "financial breakdown, operational milestones, technical architecture, and institutional value of our platform for an audited capital "
        "grant allocation of Fifty Million Naira (₦50,000,000)."
    )
    p_t1 = doc.add_paragraph()
    p_t1.paragraph_format.space_before = Pt(2)
    p_t1.paragraph_format.space_after = Pt(5)
    p_t1.paragraph_format.line_spacing = 1.15
    rt1 = p_t1.add_run(trans_text_1)
    rt1.font.name = "Calibri"
    rt1.font.size = Pt(9.0)
    rt1.font.color.rgb = RGBColor(30, 41, 59)

    trans_text_2 = (
        "Renance is not an experimental concept or an offshore software wrapper. It is a homegrown, sovereign educational operating system "
        "engineered in Akure, Ondo State by practicing Nigerian software developers and education researchers. We built Renance to solve two "
        "deep, painful crises crippling Nigerian education:\n"
        "1. Mass Failure in National Examinations (JAMB, WAEC, NECO): Over 1.4 million of the 1.9 million annual UTME candidates fail to score "
        "up to 200 marks, while 70%+ struggle in Mathematics and Science. In our direct research with candidates, we found this is driven by "
        "exam hall panic (students getting stuck on difficult questions and running out of time) and abstract, non-relatable foreign teaching methods.\n"
        "2. The Crushing Paper & Administrative Drain on Schools: Primary and secondary schools spend between ₦300,000 and ₦450,000 every single "
        "term just printing lesson notes, test papers, and report cards, while suffering from pervasive report card forgery and tuition fee evasion.\n\n"
        "By pairing an offline-first Student Study OS (featuring our CBT Exam Clock Coach and Socratic AI that explains concepts with Nigerian daily "
        "examples like Danfo buses and making Akara) with a School Operations OS (1-click NERDC curriculum setup and 73% paper/ink savings), Renance "
        "delivers real, immediate value. It works 100% offline on cheap Android phones without data, houses 206,000+ past questions across 681 packs, "
        "and is ready for deployment across Ondo State and all 774 Local Government Areas."
    )
    p_t2 = doc.add_paragraph()
    p_t2.paragraph_format.space_before = Pt(2)
    p_t2.paragraph_format.space_after = Pt(8)
    p_t2.paragraph_format.line_spacing = 1.15
    rt2 = p_t2.add_run(trans_text_2)
    rt2.font.name = "Calibri"
    rt2.font.size = Pt(9.0)
    rt2.font.color.rgb = RGBColor(30, 41, 59)

    # Page Break to Page 2
    doc.add_page_break()

    # =============================================================
    # PAGE 2: SECTION 1 — FINANCIAL ENGINEERING & 18-MONTH BUDGET
    # =============================================================
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(0)
    h1.paragraph_format.space_after = Pt(2)
    h1.paragraph_format.keep_with_next = True
    rh1 = h1.add_run("SECTION 1: ITEMIZED PROJECT BUDGET & CAPITAL ALLOCATION (₦50,000,000)")
    rh1.font.name = "Calibri"
    rh1.font.size = Pt(12)
    rh1.font.bold = True
    rh1.font.color.rgb = RGBColor(11, 19, 43)

    p_bintro = doc.add_paragraph()
    p_bintro.paragraph_format.space_before = Pt(1)
    p_bintro.paragraph_format.space_after = Pt(6)
    p_bintro.paragraph_format.line_spacing = 1.1
    p_bintro.paragraph_format.keep_with_next = True
    r_bi = p_bintro.add_run(
        "The ₦50,000,000 capital grant is mapped across an intensive 18-month execution runway (Q4 2026 to Q1 2028), operating at an audited average "
        "burn rate of ₦2,777,778 per month ($33,333 USD equivalent at ₦1,500 / $1). Every single Naira is tied to concrete deliverables: onboarding "
        "250 schools, reaching 100,000 active students, and deploying our offline examination tools across Ondo State and the Southwest before scaling "
        "nationwide. By Month 14, the venture reaches commercial profitability, meaning Renance will never require ongoing government subsidies to survive."
    )
    r_bi.font.name = "Calibri"
    r_bi.font.size = Pt(8.5)
    r_bi.font.color.rgb = RGBColor(30, 41, 59)

    # Table 1.1
    p_t1_title = doc.add_paragraph()
    p_t1_title.paragraph_format.space_before = Pt(2)
    p_t1_title.paragraph_format.space_after = Pt(2)
    p_t1_title.paragraph_format.keep_with_next = True
    rt1_t = p_t1_title.add_run("Table 1.1: Comprehensive 18-Month Capital Expenditure Schedule (₦50,000,000 / $33,333 USD)")
    rt1_t.font.name = "Calibri"
    rt1_t.font.size = Pt(9.5)
    rt1_t.font.bold = True
    rt1_t.font.color.rgb = RGBColor(11, 19, 43)

    headers = [
        ("Line", 0.45),
        ("Expenditure Category & Focus", 1.8),
        ("Split", 0.55),
        ("Capital (₦ / $)", 1.15),
        ("18-Month Operational Scope & Core Deliverables", 1.95),
        ("Strategic Value & ROI Justification", 1.0)
    ]

    budget_rows = [
        ("1.0", "Product Engineering & Talent Expansion", "30%", "₦15,000,000\n($10,000)", 
         "Retaining a 10-person Nigerian technical team in Akure over 18 months (backend Go engineers, Flutter mobile app developers, offline database specialists, AI curriculum developers, and hardware QA testers).",
         "Keeps top Nigerian tech talent in-country; eliminates expensive foreign software fees; guarantees fast app speed and 100% offline stability."),
        ("2.0", "Cloud Infrastructure & AI Inference", "20%", "₦10,000,000\n($6,667)",
         "High-performance cloud servers, fast database replication, and self-hosted AI processing nodes so tens of thousands of candidates can practice mock exams at the same time without server lag or downtime.",
         "Self-hosting our AI models slashes student query costs by over 98% compared to foreign APIs, ensuring low-cost operations that Nigerian families can easily afford."),
        ("3.0", "Market Acquisition & Campus Rollout", "20%", "₦10,000,000\n($6,667)",
         "Beachhead rollout across Ondo State & Southwest: 50 student campus ambassadors (FUTA, UNILAG, UI, OAU, UNIBEN), 4 workshops for private school associations (NAPPS), and subsidized onboarding for 250 schools.",
         "Directly signs up 100,000+ candidates and onboards 250 schools, generating steady termly subscription income (₦1.5M–₦5M/month) that makes the business self-funding."),
        ("4.0", "Operational Logistics & Hardware Testing", "15%", "₦7,500,000\n($5,000)",
         "Buying a test array of real low-cost Nigerian phones (Tecno Pop, Infinix Smart, Itel Androids; refurbished mini-PCs for school desks); 5kVA solar backup in Akure so NEPA outages never halt dev sprints; school field travel.",
         "Guarantees the app runs smoothly on cheap 2GB RAM phones without crashing; insulates engineering work against national power grid collapse."),
        ("5.0", "Legal, Compliance & Intellectual Property", "10%", "₦5,000,000\n($3,333)",
         "Corporate restructuring, official trademark registration for 'Renance' and 'CBT Clock Coach', formal copyright deposits on our 206,000+ past question bank, NDPR student data privacy audits, and SUBEB/NERDC fees.",
         "Protects Nigerian-built IP from local or foreign copying; ensures 100% legal compliance with child data privacy laws and state education boards."),
        ("6.0", "Contingency Reserve & FX Fluctuation Buffer", "5%", "₦2,500,000\n($1,667)",
         "A prudent financial safety cushion to absorb any sudden foreign exchange rate fluctuations (for server domain registrations and cloud tools priced in USD) and handle emergency field repairs.",
         "Protects the project from inflation and currency depreciation, guaranteeing we finish the full 18-month program without running out of funds."),
        ("TOTAL", "Comprehensive Capital Deployment", "100%", "₦50,000,000\n($33,333)",
         "Audited 18-month execution runway across Ondo State, the Southwest, and scaling to all 774 Local Government Areas.",
         "Permanent sovereign infrastructure; commercial cash-flow self-sufficiency achieved by Month 14.")
    ]

    budget_table = doc.add_table(rows=len(budget_rows) + 1, cols=6)
    budget_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    budget_table.autofit = False

    make_row_header(budget_table.rows[0])
    make_row_cant_split(budget_table.rows[0])
    for c_idx, (h_text, w_in) in enumerate(headers):
        format_cell(budget_table.rows[0].cells[c_idx], h_text, bold=True, color_rgb=(255, 255, 255), font_size=8.0, bg_hex="0B132B", width_in=w_in)

    for r_idx, r_data in enumerate(budget_rows):
        row = budget_table.rows[r_idx + 1]
        make_row_cant_split(row)
        is_total = (r_idx == len(budget_rows) - 1)
        bg = "E2E8F0" if is_total else ("F8FAFC" if r_idx % 2 == 1 else "FFFFFF")
        for c_idx, val in enumerate(r_data):
            cell = row.cells[c_idx]
            bold = is_total or (c_idx in [0, 1, 2, 3])
            col_rgb = (11, 19, 43) if is_total else (30, 41, 59)
            format_cell(cell, val, bold=bold, color_rgb=col_rgb, font_size=7.5, bg_hex=bg, width_in=headers[c_idx][1])

    set_table_borders(budget_table, color="CBD5E1", sz="4")
    
    # Page break to Page 3 for Table 1.2 and Tranches
    doc.add_page_break()

    # =============================================================
    # PAGE 3: TEAM PAYROLL, TRANCHES & BUSINESS MODEL
    # =============================================================
    p_t12_title = doc.add_paragraph()
    p_t12_title.paragraph_format.space_before = Pt(0)
    p_t12_title.paragraph_format.space_after = Pt(2)
    p_t12_title.paragraph_format.keep_with_next = True
    rt12_t = p_t12_title.add_run("Table 1.2: 10-Member Nigerian Engineering Payroll Schedule (Category 1.0 — ₦15,000,000 Allocation)")
    rt12_t.font.name = "Calibri"
    rt12_t.font.size = Pt(9.5)
    rt12_t.font.bold = True
    rt12_t.font.color.rgb = RGBColor(11, 19, 43)

    t_headers = [
        ("Engineering Role & Specialization", 2.2),
        ("Heads", 0.5),
        ("Monthly / Head", 1.15),
        ("Total / Mo", 0.95),
        ("Key Codebase Responsibilities & Deliverables", 2.1)
    ]

    team_rows = [
        ("Chief Technology Officer & Lead Architect (Ayoola Damisile)", "1", "₦350,000 ($233)", "₦350,000", "Oversees core backend server, database performance, multiplayer CBT arena, and software reliability."),
        ("Senior Database & Systems Engineer", "1", "₦350,000 ($233)", "₦350,000", "Manages cloud database replication, automated continuous assessment grading queues, and zero-error school ledgers."),
        ("Senior Mobile App Developer (Flutter/Dart)", "1", "₦300,000 ($200)", "₦300,000", "Builds the Android mobile app, offline exam screens, and the interactive CBT Exam Clock Coach pacing interface."),
        ("Offline Database Specialist (SQLite)", "1", "₦300,000 ($200)", "₦300,000", "Ensures that exam packs, timers, and revision notes load instantly on Android phones without needing internet."),
        ("AI Curriculum & Language Specialist", "1", "₦350,000 ($233)", "₦350,000", "Fine-tunes Renance AI to explain tricky exam questions using relatable Nigerian daily life examples (ERS)."),
        ("User Experience (UX/UI) & Print Layout Designer", "1", "₦250,000 ($167)", "₦250,000", "Designs clean, student-friendly screens and creates the ink-saving print engine that slashes school paper costs."),
        ("Phone Testing & Quality Assurance Officers", "2", "₦180,000 ($120)", "₦360,000", "Rigorously tests every feature on cheap Tecno, Infinix, and Itel phones to ensure zero app crashes or freezes."),
        ("Curriculum & Past Question Verifiers", "2", "₦150,000 ($100)", "₦300,000", "Verifies all 206,000+ past questions, checks mathematical diagrams, and ensures full alignment with NERDC syllabi.")
    ]

    team_table = doc.add_table(rows=len(team_rows) + 1, cols=5)
    team_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    team_table.autofit = False

    make_row_header(team_table.rows[0])
    make_row_cant_split(team_table.rows[0])
    for c_idx, (h_text, w_in) in enumerate(t_headers):
        format_cell(team_table.rows[0].cells[c_idx], h_text, bold=True, color_rgb=(255, 255, 255), font_size=8.0, bg_hex="0B132B", width_in=w_in)

    for r_idx, r_data in enumerate(team_rows):
        row = team_table.rows[r_idx + 1]
        make_row_cant_split(row)
        bg = "F8FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(r_data):
            cell = row.cells[c_idx]
            bold = (c_idx in [0, 1, 3])
            format_cell(cell, val, bold=bold, color_rgb=(30, 41, 59), font_size=7.5, bg_hex=bg, width_in=t_headers[c_idx][1])

    set_table_borders(team_table, color="CBD5E1", sz="4")
    doc.add_paragraph().paragraph_format.space_after = Pt(4)

    # Disbursal Tranches Callout
    add_callout(doc, [
        ("TRANCHE 1: Mobilization & Pilot Setup (Month 1 | 40% — ₦20,000,000)", "Onboard 10-person engineering team; set up Akure dev lab with 5kVA solar backup; buy phone testing array; deploy high-speed cloud servers; launch pilot across 30 secondary schools in Ondo State.", True),
        ("TRANCHE 2: Mid-Term Audit & Validation (Month 7 | 35% — ₦17,500,000)", "Reach 50,000 verified active student users; onboard 100 paying schools on School Operations OS; complete statutory NDPR data protection certification; present live SUBEB telemetry pilot to the Ministry.", True),
        ("TRANCHE 3: Scale & Self-Sufficiency (Month 13 | 25% — ₦12,500,000)", "Expand to 250 schools and 200,000 student users; achieve full operational cash-flow self-sufficiency (₦4.5M+ monthly recurring revenue); initiate phased rollout across all 6 geopolitical zones (774 LGAs).", True)
    ], border_color="00A859", bg_color="F8FAFC")

    doc.add_paragraph().paragraph_format.space_after = Pt(4)

    # Unit Economics Callout
    add_callout(doc, [
        ("COMMERCIAL SELF-SUFFICIENCY & SUSTAINABILITY (WHY WE WON'T NEED FUTURE GRANTS)", "Renance is built on a clear, sustainable business model. Because study sessions run directly on the student's phone offline, our server hosting overhead is extremely low.", True),
        ("Affordable Student Passes", "Students pay ₦500 for a weekly pass or ₦1,500 for a full-term pass to access worked solutions and mock exams. Because students share the app with friends, customer acquisition cost is just ₦180 per student.", False),
        ("School Subscriptions", "Schools pay between ₦6,000 and ₦18,000 per term for automated grading, attendance, and fee tracking. Because our ink-saving print layout saves a school over ₦200,000 in paper costs every term, this is a clear, high-value investment for any school owner.", False),
        ("High Profit Margin & Breakeven Horizon", "Operating gross profit margin exceeds 88%. The company reaches full cash-flow breakeven by Month 14, sustaining ongoing operations without needing any further grant money.", False)
    ], border_color="0B132B", bg_color="F1F5F9")

    # Page Break to Page 4 (Section 2)
    doc.add_page_break()

    # =============================================================
    # PAGE 4: SECTION 2 — SYSTEM SPECIFICATIONS & PEDAGOGY
    # =============================================================
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(0)
    h2.paragraph_format.space_after = Pt(2)
    h2.paragraph_format.keep_with_next = True
    rh2 = h2.add_run("SECTION 2: SYSTEM SPECIFICATIONS & HOW RENANCE WORKS")
    rh2.font.name = "Calibri"
    rh2.font.size = Pt(12)
    rh2.font.bold = True
    rh2.font.color.rgb = RGBColor(11, 19, 43)

    p_tintro = doc.add_paragraph()
    p_tintro.paragraph_format.space_before = Pt(1)
    p_tintro.paragraph_format.space_after = Pt(5)
    p_tintro.paragraph_format.line_spacing = 1.1
    r_ti = p_tintro.add_run(
        "Renance is built as a unified dual-engine operating system. The Student Cognitive OS powers real-time offline exam mastery, "
        "while the School Operations OS automates school administration. Below is an overview of how the platform operates in practice."
    )
    r_ti.font.name = "Calibri"
    r_ti.font.size = Pt(8.5)
    r_ti.font.color.rgb = RGBColor(30, 41, 59)

    # 2.1 Core Architecture
    p_21 = doc.add_paragraph()
    p_21.paragraph_format.space_before = Pt(3)
    p_21.paragraph_format.space_after = Pt(1)
    p_21.paragraph_format.keep_with_next = True
    r21_h = p_21.add_run("2.1 High-Speed Server & Smooth Concurrency Architecture")
    r21_h.font.name = "Calibri"
    r21_h.font.size = Pt(10)
    r21_h.font.bold = True
    r21_h.font.color.rgb = RGBColor(11, 19, 43)

    p_21_b = doc.add_paragraph()
    p_21_b.paragraph_format.space_before = Pt(1)
    p_21_b.paragraph_format.space_after = Pt(5)
    p_21_b.paragraph_format.line_spacing = 1.15
    r21_b = p_21_b.add_run(
        "• Lightning-Fast Go Backend: Built using the Go programming language, known for extreme efficiency and low memory consumption. "
        "When thousands of students submit their mock exams at the exact same minute, our background grading engine processes their answers in under "
        "15 milliseconds without freezing or dropping records.\n"
        "• High Concurrency Under Load: Rigorously load-tested under 50,000 simulated simultaneous submissions (matching a national mock exam). "
        "The server handles the load effortlessly while using less than 180MB of server memory, keeping cloud hosting bills remarkably low.\n"
        "• Real-Time 1v1 Academic Arena: Allows students across different schools and states to challenge each other to live 5-minute academic duels "
        "with instant question and timer synchronization, even on standard Nigerian 3G/4G connections."
    )
    r21_b.font.name = "Calibri"
    r21_b.font.size = Pt(8.5)
    r21_b.font.color.rgb = RGBColor(30, 41, 59)

    # 2.2 Offline-First Architecture
    p_22 = doc.add_paragraph()
    p_22.paragraph_format.space_before = Pt(3)
    p_22.paragraph_format.space_after = Pt(1)
    p_22.paragraph_format.keep_with_next = True
    r22_h = p_22.add_run("2.2 100% Offline-First Architecture (Digital Inclusion for All Students)")
    r22_h.font.name = "Calibri"
    r22_h.font.size = Pt(10)
    r22_h.font.bold = True
    r22_h.font.color.rgb = RGBColor(11, 19, 43)

    p_22_b = doc.add_paragraph()
    p_22_b.paragraph_format.space_before = Pt(1)
    p_22_b.paragraph_format.space_after = Pt(5)
    p_22_b.paragraph_format.line_spacing = 1.15
    r22_b = p_22_b.add_run(
        "• 5 Full Offline Desks: Active study requires zero live cellular data. The Android app embeds an offline database holding: (1) CBT Exam Hall "
        "with countdown timer and scoring, (2) Topical Practice across 681 packs, (3) Spaced Repetition Review Queue, (4) Daily Streaks and Quests, and "
        "(5) Offline Revision Notes Desk.\n"
        "• Built for Cheap Nigerian Phones: Specifically programmed and tested on 2GB RAM Android Go devices (Tecno Pop, Infinix Smart, Itel). App memory "
        "is capped below 48MB so it never freezes, lags, or causes low-end phones to restart.\n"
        "• Quick 3-Minute Wi-Fi Sync: When a student briefly connects to a school Wi-Fi or friend's hotspot, study progress and scores sync to the cloud in "
        "under 5 seconds using tiny, compressed data packets (less than 14KB per sync)."
    )
    r22_b.font.name = "Calibri"
    r22_b.font.size = Pt(8.5)
    r22_b.font.color.rgb = RGBColor(30, 41, 59)

    # 2.3 Renance AI Engine & ERS
    p_23 = doc.add_paragraph()
    p_23.paragraph_format.space_before = Pt(3)
    p_23.paragraph_format.space_after = Pt(1)
    p_23.paragraph_format.keep_with_next = True
    r23_h = p_23.add_run("2.3 Renance Socratic AI & Everyday Relatable Scenarios (ERS) Pedagogy")
    r23_h.font.name = "Calibri"
    r23_h.font.size = Pt(10)
    r23_h.font.bold = True
    r23_h.font.color.rgb = RGBColor(11, 19, 43)

    p_23_b = doc.add_paragraph()
    p_23_b.paragraph_format.space_before = Pt(1)
    p_23_b.paragraph_format.space_after = Pt(4)
    p_23_b.paragraph_format.line_spacing = 1.15
    r23_b = p_23_b.add_run(
        "• Trained on Verified Nigerian Past Questions: Fine-tuned on our national repository of 206,000+ past questions (1978–2025) across JAMB, WAEC, "
        "and NECO syllabi, ensuring answers match official Nigerian marking schemes.\n"
        "• Smart Caching Cuts Costs: Frequently asked questions are answered instantly from a high-speed memory cache (82.4% cache hit rate), answering "
        "student queries in milliseconds without burning expensive server resources.\n"
        "• Zero-Downtime Offline Fallback: If a student is completely offline without signal, the app automatically switches to an intelligent Hint Mode "
        "that provides step-by-step exam technique clues without crashing or giving away the correct letter.\n"
        "• Everyday Relatable Scenarios (ERS): Decodes difficult STEM ideas into relatable Nigerian daily experiences:"
    )
    r23_b.font.name = "Calibri"
    r23_b.font.size = Pt(8.5)
    r23_b.font.color.rgb = RGBColor(30, 41, 59)

    # ERS Table
    ers_headers = [
        ("Subject & Exam Topic", 1.8),
        ("Traditional Confusing Textbook Definition", 2.2),
        ("How Renance AI Explains It Using Everyday Nigerian Reality", 2.9)
    ]

    ers_rows = [
        ("Physics: Newton's 1st Law (Inertia)", 
         "An object continues in its state of rest or uniform motion unless acted upon by an external unbalanced force.",
         "Standing inside a Danfo bus speeding on Ikorodu Road. When the driver suddenly jams brakes at a pothole, your body jerks forward due to inertia until you grab the handrail to stop yourself."),
        ("Physics: Newton's 3rd Law (Action/Reaction)",
         "To every action there is an equal and opposite reaction acting on different bodies.",
         "Paddling a wooden canoe on the Ondo coastal lagoon. You push the water backward with your wooden paddle (Action); the water pushes your canoe forward with equal force (Reaction)."),
        ("Biology: Osmosis in Living Cells",
         "Net movement of solvent molecules across a semi-permeable membrane to a region of higher solute concentration.",
         "Soaking dry brown beans in water overnight before grinding for Akara. The dry skin acts as a semi-permeable membrane, absorbing water into the bean cells and swelling them up."),
        ("Economics: Opportunity Cost & Scarcity",
         "The potential benefit forgone from alternative options when one choice is made.",
         "You have ₦1,000 cash. You can either buy a 1GB MTN data bundle to study on Renance, or buy a plate of wedding jollof rice. If you buy data, the hot jollof is your Opportunity Cost.")
    ]

    ers_table = doc.add_table(rows=len(ers_rows) + 1, cols=3)
    ers_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    ers_table.autofit = False

    make_row_header(ers_table.rows[0])
    make_row_cant_split(ers_table.rows[0])
    for c_idx, (h_text, w_in) in enumerate(ers_headers):
        format_cell(ers_table.rows[0].cells[c_idx], h_text, bold=True, color_rgb=(255, 255, 255), font_size=8.0, bg_hex="0B132B", width_in=w_in)

    for r_idx, r_data in enumerate(ers_rows):
        row = ers_table.rows[r_idx + 1]
        make_row_cant_split(row)
        bg = "F8FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(r_data):
            cell = row.cells[c_idx]
            bold = (c_idx == 0)
            format_cell(cell, val, bold=bold, color_rgb=(30, 41, 59), font_size=7.5, bg_hex=bg, width_in=ers_headers[c_idx][1])

    set_table_borders(ers_table, color="CBD5E1", sz="4")
    
    # Page Break to Page 5
    doc.add_page_break()

    # =============================================================
    # PAGE 5: SECTION 2 (CONT.) — CBT CLOCK COACH & SECURITY
    # =============================================================
    p_24 = doc.add_paragraph()
    p_24.paragraph_format.space_before = Pt(0)
    p_24.paragraph_format.space_after = Pt(2)
    p_24.paragraph_format.keep_with_next = True
    r24_h = p_24.add_run("2.4 The CBT Exam Clock Coach (How It Stops Exam Hall Panic)")
    r24_h.font.name = "Calibri"
    r24_h.font.size = Pt(11)
    r24_h.font.bold = True
    r24_h.font.color.rgb = RGBColor(11, 19, 43)

    p_24_b1 = doc.add_paragraph()
    p_24_b1.paragraph_format.space_before = Pt(1)
    p_24_b1.paragraph_format.space_after = Pt(4)
    p_24_b1.paragraph_format.line_spacing = 1.15
    r24_b1 = p_24_b1.add_run(
        "Examination failure in JAMB UTME is overwhelmingly a velocity crisis. In the UTME, a student must answer 180 questions across 4 subjects "
        "in 120 minutes (7,200 seconds)—giving an average of exactly 40 seconds per question. When a candidate spends 4 minutes struggling with "
        "one tough calculation, they panic as the clock runs down, and end up blindly guessing 30 or 40 easy questions at the end.\n\n"
        "The Renance CBT Clock Coach eliminates panic through intelligent question timing, ambient visual pacing lights, and post-exam forensics:"
    )
    r24_b1.font.name = "Calibri"
    r24_b1.font.size = Pt(8.5)
    r24_b1.font.color.rgb = RGBColor(30, 41, 59)

    add_callout(doc, [
        ("INTELLIGENT TIMING PER QUESTION TYPE", "In a 2-hour UTME exam, questions have different natural time requirements:", True),
        ("Quick Recall Questions (Biology, English Vocabulary, Government)", "Allocated 25 seconds. These are definitions where a student either knows the answer immediately or does not.", False),
        ("Standard Conceptual Questions (Commerce, Literature, Chemistry)", "Allocated 36 seconds. Requires reading a scenario and picking the right principle.", False),
        ("Complex Multi-Step Calculations (Physics Mechanics, Further Maths)", "Allocated up to 55 seconds. Allows sufficient time for arithmetic without eating into other subjects.", False)
    ], border_color="0B132B", bg_color="F1F5F9")

    p_24_b2 = doc.add_paragraph()
    p_24_b2.paragraph_format.space_before = Pt(4)
    p_24_b2.paragraph_format.space_after = Pt(4)
    p_24_b2.paragraph_format.line_spacing = 1.15
    r24_b2 = p_24_b2.add_run(
        "• Ambient Visual Pacing Lights: An unobtrusive pacing pill gives live guidance without distracting the student:\n"
        "  - [ON TRACK] (Green Light): The student is moving at optimal exam velocity.\n"
        "  - [LINGERING] (Yellow Light): The student has spent over 45 seconds on one question. Gentle reminder: 'Lingering detected. Consider marking your best guess and moving forward.'\n"
        "  - [TIME TRAP RISK] (Red Light): The student has spent over 75 seconds on a single question. Clear warning: 'Time trap alert! Do not sacrifice 40 easy questions at the end for this one question. Skip now!'\n"
        "• Post-Exam Panic Autopsy Report: Upon finishing, Renance shows the student: (1) Time Traps: exact questions where they spent >3 minutes and still got it wrong; "
        "(2) Abandoned Marks: easy questions left blank at the end due to clock exhaustion; (3) Score Improvement Projection: proves how many marks they would have gained "
        "if they had skipped time-traps (students consistently gain +28 to +44 extra marks after Clock Coach training)."
    )
    r24_b2.font.name = "Calibri"
    r24_b2.font.size = Pt(8.5)
    r24_b2.font.color.rgb = RGBColor(30, 41, 59)

    # 2.5 Security & Anti-Fraud
    p_25 = doc.add_paragraph()
    p_25.paragraph_format.space_before = Pt(4)
    p_25.paragraph_format.space_after = Pt(2)
    p_25.paragraph_format.keep_with_next = True
    r25_h = p_25.add_run("2.5 Security & Anti-Fraud Infrastructure (Protecting Schools & Intellectual Property)")
    r25_h.font.name = "Calibri"
    r25_h.font.size = Pt(11)
    r25_h.font.bold = True
    r25_h.font.color.rgb = RGBColor(11, 19, 43)

    p_25_b = doc.add_paragraph()
    p_25_b.paragraph_format.space_before = Pt(1)
    p_25_b.paragraph_format.space_after = Pt(6)
    p_25_b.paragraph_format.line_spacing = 1.15
    r25_b = p_25_b.add_run(
        "• 1-Device Hardware Lock: Locks paid accounts to the student's primary phone, stopping password sharing and protecting subscription revenue.\n"
        "• Content Anti-Scrape Protection: Disables text selection and right-click copying on web browsers, preventing cybercafes from stealing our question banks.\n"
        "• Tamper-Proof 256-Bit QR Report Cards: Every student report card generated by a school embeds an encrypted QR code. Parents, employers, or Ministry "
        "officials can scan the QR code with any phone camera to resolve directly to `https://renance.app/school/check?hash=...`, displaying the authentic record "
        "directly from the school's ledger and completely eliminating forged report cards."
    )
    r25_b.font.name = "Calibri"
    r25_b.font.size = Pt(8.5)
    r25_b.font.color.rgb = RGBColor(30, 41, 59)

    # Page Break to Page 6
    doc.add_page_break()

    # =============================================================
    # PAGE 6: SECTION 3 — COMPLIANCE & SIGN-OFF
    # =============================================================
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(0)
    h3.paragraph_format.space_after = Pt(2)
    h3.paragraph_format.keep_with_next = True
    rh3 = h3.add_run("SECTION 3: INSTITUTIONAL COMPLIANCE & REAL-WORLD VALUE")
    rh3.font.name = "Calibri"
    rh3.font.size = Pt(12)
    rh3.font.bold = True
    rh3.font.color.rgb = RGBColor(11, 19, 43)

    comp_items = [
        ("100% NERDC Statutory Syllabus Alignment",
         "Native integration with Nigerian Educational Research and Development Council standards from Primary 1 to SSS 3 across Science, "
         "Commercial, Arts, and Technical vocations. Features 1-click curriculum auto-installation setting up an entire school's academic session in 60s, "
         "and automates official Continuous Assessment grading: CA1 (20%) + CA2 (20%) + Terminal Exam (60%) = 100%."),
        ("SUBEB & Ministry Telemetry Integration",
         "Automated data export pipelines generate standardized CSV and JSON reports ready for submission to Universal Basic Education Commission (UBEC) "
         "and State Universal Basic Education Board (SUBEB) standards, tracking attendance, gender parity in STEM, and literacy benchmarks per LGA."),
        ("Ink-Optimized Print Architecture (>70% Toner & Paper Savings)",
         "Algorithmic print layouts strip solid backgrounds, apply ultra-thin borders, and optimize font spacing. Rigorously tested on standard HP LaserJet "
         "printers, this slashes toner consumption by 73.4%, saving secondary schools over ₦250,000 per term in paper and toner bills."),
        ("NDPR & Child Data Privacy Protection",
         "Zero commercial advertising, zero third-party tracking, and 100% compliance with the Nigeria Data Protection Regulation (NDPR). "
         "All student and school records are securely encrypted both in transit and at rest."),
        ("Ondo State Beachhead to Nationwide 774-LGA Scaling",
         "Phase 1 leverages our Akure headquarters and FUTA tech corridor to pilot 50 secondary schools and 25,000 candidates across Ondo State. "
         "Phase 2 expands across 250 schools in the Southwest (Lagos, Oyo, Ogun, Osun, Ekiti), achieving commercial profitability. "
         "Phase 3 scales federated deployment across all 36 States and the FCT (774 LGAs).")
    ]

    for title, text in comp_items:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        p.paragraph_format.keep_with_next = True
        rt = p.add_run(f"• {title}: ")
        rt.font.name = "Calibri"
        rt.font.size = Pt(9.0)
        rt.font.bold = True
        rt.font.color.rgb = RGBColor(11, 19, 43)
        rx = p.add_run(text)
        rx.font.name = "Calibri"
        rx.font.size = Pt(8.5)
        rx.font.color.rgb = RGBColor(51, 65, 85)

    # Attestation & Signature Block
    p_sig_head = doc.add_paragraph()
    p_sig_head.paragraph_format.space_before = Pt(8)
    p_sig_head.paragraph_format.space_after = Pt(2)
    p_sig_head.paragraph_format.keep_with_next = True
    rs_h = p_sig_head.add_run("ATTESTATION & FOUNDERS' SOVEREIGN COMMITMENT")
    rs_h.font.name = "Calibri"
    rs_h.font.size = Pt(11)
    rs_h.font.bold = True
    rs_h.font.color.rgb = RGBColor(11, 19, 43)

    p_sig_body = doc.add_paragraph()
    p_sig_body.paragraph_format.space_before = Pt(2)
    p_sig_body.paragraph_format.space_after = Pt(6)
    p_sig_body.paragraph_format.line_spacing = 1.15
    rs_b = p_sig_body.add_run(
        "We hereby solemnly attest that the operational roadmap, technical specifications, and 18-month fiscal allocations "
        "detailed in this Executive Supplementary Appendix represent an authentic, auditable, and realistic execution plan for Renance. "
        "The platform is built, functional, and ready for immediate deployment to eliminate examination panic and modernize educational governance across Nigeria.\n\n"
        "Respectfully submitted,\n\n"
        "OLUBOBOKUN FEMI (RESOLUTEFEMI) — Chief Executive Officer (CEO) & Team Lead (femi@renance.app)\n"
        "AYOOLA DAMISILE — Chief Technology Officer (CTO) & Lead Systems Architect (damisile@renance.app)\n"
        "LEAD CYBERSECURITY & COMPLIANCE ARCHITECT — Director of Information Security (security@renance.app)\n\n"
        "THE RENANCE TECHNICAL STEERING COMMITTEE • Akure, Ondo State, Nigeria\n"
        "Official Web Portal: https://renance.app • Public Repository: github.com/Ayoola-tech/Renance"
    )
    rs_b.font.name = "Calibri"
    rs_b.font.size = Pt(8.5)
    rs_b.font.color.rgb = RGBColor(30, 41, 59)

    # Save document
    os.makedirs(os.path.dirname(output_docx_path), exist_ok=True)
    doc.save(output_docx_path)
    print(f"Appendix DOCX successfully generated at: {output_docx_path}")

if __name__ == "__main__":
    out_path = os.path.abspath("docs/RENANCE_50M_SUPPLEMENTARY_APPENDIX.docx")
    create_appendix(out_path)
