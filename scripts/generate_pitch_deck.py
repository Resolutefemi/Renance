import os
import pptx
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

def create_deck(output_pptx_path):
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Color Palette
    C_BG = RGBColor(10, 15, 29)          # Deep Midnight Navy #0A0F1D
    C_CARD_BG = RGBColor(19, 30, 54)     # Rich Navy Card #131E36
    C_CARD_ALT = RGBColor(15, 23, 42)    # Slate Navy #0F172A
    C_BORDER = RGBColor(35, 50, 82)      # Subtle Border #233252
    C_EMERALD = RGBColor(16, 185, 129)   # Vibrant Emerald #10B981
    C_AMBER = RGBColor(245, 158, 11)     # Warm Gold/Amber #F59E0B
    C_SKY = RGBColor(56, 189, 248)       # Sky Cyan #38BDF8
    C_PURPLE = RGBColor(168, 85, 247)    # Accent Purple #A855F7
    C_RED = RGBColor(239, 68, 68)        # Accent Crimson #EF4444
    C_WHITE = RGBColor(255, 255, 255)    # Pure White #FFFFFF
    C_SLATE_50 = RGBColor(248, 250, 252) # Slate 50
    C_MUTED = RGBColor(148, 163, 184)    # Slate 400 #94A3B8

    def set_font(run_or_para, size=None, bold=False, color=None):
        run_or_para.font.name = "Segoe UI"
        if size is not None:
            run_or_para.font.size = size
        if bold:
            run_or_para.font.bold = True
        if color is not None:
            run_or_para.font.color.rgb = color

    def add_background(slide):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, prs.slide_width, prs.slide_height)
        bg.fill.solid()
        bg.fill.fore_color.rgb = C_BG
        bg.line.fill.background()
        return bg

    def add_header(slide, tag_text, title_text, subtitle_text, tag_color=C_EMERALD):
        # Pill Tag
        tag = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.45), Inches(3.6), Inches(0.32))
        tag.fill.solid()
        tag.fill.fore_color.rgb = C_CARD_BG
        tag.line.color.rgb = tag_color
        tag.line.width = Pt(1)
        tf_t = tag.text_frame
        tf_t.word_wrap = False
        tf_t.vertical_anchor = MSO_ANCHOR.MIDDLE
        p_t = tf_t.paragraphs[0]
        p_t.text = tag_text.upper()
        set_font(p_t, Pt(9.5), bold=True, color=tag_color)
        p_t.alignment = PP_ALIGN.CENTER

        # Title
        t_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.85), Inches(11.733), Inches(0.65))
        tf_title = t_box.text_frame
        tf_title.word_wrap = True
        tf_title.margin_left = tf_title.margin_right = tf_title.margin_top = tf_title.margin_bottom = 0
        p_title = tf_title.paragraphs[0]
        p_title.text = title_text
        set_font(p_title, Pt(24), bold=True, color=C_WHITE)

        # Subtitle
        s_box = slide.shapes.add_textbox(Inches(0.8), Inches(1.48), Inches(11.733), Inches(0.45))
        tf_sub = s_box.text_frame
        tf_sub.word_wrap = True
        tf_sub.margin_left = tf_sub.margin_right = tf_sub.margin_top = tf_sub.margin_bottom = 0
        p_sub = tf_sub.paragraphs[0]
        p_sub.text = subtitle_text
        set_font(p_sub, Pt(12), color=C_SKY)

    def add_footer(slide, slide_num):
        # Footer dividing line
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(6.9), Inches(11.733), Inches(0.02))
        line.fill.solid()
        line.fill.fore_color.rgb = C_BORDER
        line.line.fill.background()

        # Left text
        box_l = slide.shapes.add_textbox(Inches(0.8), Inches(6.95), Inches(8.5), Inches(0.35))
        tf_l = box_l.text_frame
        tf_l.margin_left = tf_l.margin_top = tf_l.margin_right = tf_l.margin_bottom = 0
        p_l = tf_l.paragraphs[0]
        p_l.text = "RENANCE • Nigeria's Sovereign Dual-Engine Educational Operating System (renance.app)"
        set_font(p_l, Pt(10), color=C_MUTED)

        # Right text
        box_r = slide.shapes.add_textbox(Inches(9.5), Inches(6.95), Inches(3.033), Inches(0.35))
        tf_r = box_r.text_frame
        tf_r.margin_left = tf_r.margin_top = tf_r.margin_right = tf_r.margin_bottom = 0
        p_r = tf_r.paragraphs[0]
        p_r.text = f"Slide {slide_num} of 15"
        set_font(p_r, Pt(10), bold=True, color=C_EMERALD)
        p_r.alignment = PP_ALIGN.RIGHT

    def add_card(slide, left, top, width, height, title="", border_color=C_BORDER, fill_color=C_CARD_BG):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height))
        card.fill.solid()
        card.fill.fore_color.rgb = fill_color
        card.line.color.rgb = border_color
        card.line.width = Pt(1.2)
        tf = card.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.25)
        tf.margin_right = Inches(0.25)
        tf.margin_top = Inches(0.2)
        tf.margin_bottom = Inches(0.2)
        if title:
            p = tf.paragraphs[0]
            p.text = title
            set_font(p, Pt(15), bold=True, color=C_WHITE)
        return card

    # ==========================================
    # SLIDE 1: Title & Sovereign Value Prop
    # ==========================================
    s1 = prs.slides.add_slide(blank_layout)
    add_background(s1)
    
    # Title badge
    tag1 = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.6), Inches(4.2), Inches(0.35))
    tag1.fill.solid()
    tag1.fill.fore_color.rgb = C_CARD_BG
    tag1.line.color.rgb = C_EMERALD
    p = tag1.text_frame.paragraphs[0]
    p.text = "SOVEREIGN EDUCATIONAL INFRASTRUCTURE"
    set_font(p, Pt(10), bold=True, color=C_EMERALD)
    p.alignment = PP_ALIGN.CENTER

    # Main Big Title
    t1 = s1.shapes.add_textbox(Inches(0.8), Inches(1.1), Inches(11.733), Inches(1.1))
    tf1 = t1.text_frame
    tf1.word_wrap = True
    tf1.margin_left = tf1.margin_top = 0
    p = tf1.paragraphs[0]
    p.text = "RENANCE"
    set_font(p, Pt(40), bold=True, color=C_WHITE)

    p2 = tf1.add_paragraph()
    p2.text = "Nigeria's Sovereign Dual-Engine Educational Operating System"
    set_font(p2, Pt(20), bold=True, color=C_EMERALD)

    # Subtitle hook
    hook1 = s1.shapes.add_textbox(Inches(0.8), Inches(2.25), Inches(11.733), Inches(0.45))
    p = hook1.text_frame.paragraphs[0]
    p.text = "Eliminating Examination Panic for Candidates  •  Ending Paper & Administrative Drain for Schools"
    set_font(p, Pt(13), color=C_SKY)

    # 2 Big Pillar Cards
    c1_left = add_card(s1, 0.8, 2.85, 5.7, 2.7, "PILLAR I: Institutional School OS", C_SKY)
    tf = c1_left.text_frame
    bullets_p1 = [
        "1-Tap NERDC National Curriculum auto-installation (Primary 1 - SSS 3)",
        "Ink-Saving single-topic B&W lesson notes (Slashing paper costs by 70%+)",
        "30-Second mobile attendance roll call, gate kiosk & conflict-free timetables",
        "Automated continuous assessment (CA 20/20/60) & student rank computation",
        "Kobo-safe integer fee ledger with live debtor roster & serialized ID cards"
    ]
    for b in bullets_p1:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(4)

    c1_right = add_card(s1, 6.833, 2.85, 5.7, 2.7, "PILLAR II: Cognitive Student Study OS", C_EMERALD)
    tf = c1_right.text_frame
    bullets_p2 = [
        "207,172+ verified questions across 681 packs (JAMB, WAEC, NECO, Post-UTME, Uni)",
        "Proprietary CBT Exam Clock Coach & post-exam Panic Forensics autopsy",
        "Everyday Relatable Scenarios translating abstract STEM formulas into Nigerian reality",
        "Socratic AI Tutor providing hint-first guided inquiry without spoon-feeding",
        "1v1 Multiplayer CBT Arena with WebSocket live sync & Spaced Repetition Queue"
    ]
    for b in bullets_p2:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(4)

    # 4 Stat Pillars at Bottom
    stats = [
        ("207,172+", "VERIFIED PAST QUESTIONS", C_EMERALD),
        ("681 PACKS", "1978 - 2025 COVERAGE", C_SKY),
        ("774 LGAs", "SOVEREIGN ROLLOUT SURFACE", C_AMBER),
        ("100% OFFLINE", "ZERO-DATA ANDROID SQLITE", C_WHITE)
    ]
    for idx, (num, lbl, col) in enumerate(stats):
        bx = add_card(s1, 0.8 + idx * 3.0, 5.7, 2.733, 0.95, "", C_BORDER)
        tf = bx.text_frame
        p = tf.paragraphs[0]
        p.text = num
        set_font(p, Pt(20), bold=True, color=col)
        p.alignment = PP_ALIGN.CENTER
        p2 = tf.add_paragraph()
        p2.text = lbl
        set_font(p2, Pt(9.5), bold=True, color=C_MUTED)
        p2.alignment = PP_ALIGN.CENTER

    add_footer(s1, 1)

    # ==========================================
    # SLIDE 2: The Dual Crisis
    # ==========================================
    s2 = prs.slides.add_slide(blank_layout)
    add_background(s2)
    add_header(s2, "THE NATIONAL CRISIS", "The Twin Bottlenecks Crippling Nigerian Education", 
               "Why Millions Fail High-Stakes Exams While School Administrators Drown in Paper Chaos", C_RED)

    c2_left = add_card(s2, 0.8, 2.1, 5.7, 3.7, "The Student Crisis: Clock Panic & Rote Recall", C_RED)
    tf = c2_left.text_frame
    bullets_s2_left = [
        "1.4M+ UTME Candidates Fail Cutoffs: Over 75% of applicants fail to secure tertiary admission annually; 76% struggle in WAEC science and mathematics.",
        "The Exam Hall Clock Trap: Candidates freeze on complex early questions, spending 4-5 minutes on a single mark. Acute panic sets in, working memory collapses, and 10-15 marks are lost to frantic blind guessing.",
        "Abstract Textbook Alienation: Imported Western pedagogy encourages rote memorization. Students recite formulas verbatim without physical comprehension.",
        "The Bandwidth Barrier: High telecommunications tariffs price out 85% of Nigerian candidates who cannot stream heavy 40-minute educational videos."
    ]
    for b in bullets_s2_left:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    c2_right = add_card(s2, 6.833, 2.1, 5.7, 3.7, "The School Crisis: Administrative & Financial Hemorrhage", C_AMBER)
    tf = c2_right.text_frame
    bullets_s2_right = [
        "Astronomical Paper & Toner Drain: Schools spend over NGN 300,000 every term on paper registers, handwritten lesson plan notebooks, and terminal exam photocopies.",
        "Chaotic Fee Accounting & Debtors: Bursars rely on paper ledgers or loose desktop spreadsheets. Parents exploit poor records, causing millions in uncollected fee arrears.",
        "Rampant Report Card Forgery: Razor-blade alterations and NGN 500 cyber-cafe counterfeit report sheets destroy academic credibility and parent trust.",
        "Teacher Administrative Burnout: Exhausting late-night lesson plan copying robs educators of teaching energy, while manual CA calculation breeds human error."
    ]
    for b in bullets_s2_right:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    # Bottom Callout Bar
    callout2 = add_card(s2, 0.8, 6.0, 11.733, 0.7, "", C_SKY, C_CARD_ALT)
    tf = callout2.text_frame
    p = tf.paragraphs[0]
    p.text = "KEY INSIGHT: Commercial 'quiz dump' apps fail because they test without teaching; video portals fail because data is unaffordable. Nigeria requires an infrastructure-level Operating System."
    set_font(p, Pt(11), bold=True, color=C_WHITE)
    p.alignment = PP_ALIGN.CENTER

    add_footer(s2, 2)

    # ==========================================
    # SLIDE 3: The Dual-Engine Solution
    # ==========================================
    s3 = prs.slides.add_slide(blank_layout)
    add_background(s3)
    add_header(s3, "ARCHITECTURAL INNOVATION", "A Sovereign Dual-Engine Operating System", 
               "Unifying Institutional School Governance and Cognitive Student Learning into One Sovereign Platform", C_EMERALD)

    c3_1 = add_card(s3, 0.8, 2.1, 3.65, 4.5, "Pillar I: Institutional School OS", C_SKY)
    tf = c3_1.text_frame
    bullets_3_1 = [
        "1-Tap NERDC Installation: Pre-populates Primary 1 to SSS 3 curriculum across Science, Arts, Commercial & Technical.",
        "Ink-Saving B&W Print Engine: Strict single-topic lesson note exports cut paper/toner costs by 70%+.",
        "30-Second Morning Roll Call: Intuitive mobile roster and entrance gate kiosk mode with SUBEB CSV exports.",
        "Conflict-Free Timetable: Atomic commit prevents classroom or teacher scheduling collisions.",
        "CA 20/20/60 & Public Checker: Automated grading + 6-digit scratch PIN at /school/check.",
        "Kobo-Integer Fee Ledger: Exact accounting eliminates rounding loss; live debtor tracking prevents evasion."
    ]
    for b in bullets_3_1:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c3_2 = add_card(s3, 4.84, 2.1, 3.65, 4.5, "Pillar II: Cognitive Student OS", C_EMERALD)
    tf = c3_2.text_frame
    bullets_3_2 = [
        "207k+ Verified Questions: Curated past papers across 681 packs spanning JAMB, WAEC, NECO, and Tertiary.",
        "CBT Exam Clock Coach: Real-time pacing gauge (ON TRACK, LINGERING, TRAP RISK) eliminates hall panic.",
        "Post-Exam Panic Forensics: Pinpoints exact time-traps and calculates marks lost to clock mismanagement.",
        "Everyday Relatable Scenarios: Explains Newton's laws through Danfo buses, and osmosis through honey beans.",
        "Socratic AI Tutor: Guided hints without spoon-feeding correct letters; deterministic offline matrices.",
        "1v1 CBT Multiplayer Arena: High-energy 5-min academic duels, leaderboards, and spaced review queue."
    ]
    for b in bullets_3_2:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c3_3 = add_card(s3, 8.88, 2.1, 3.65, 4.5, "Unified Cross-Platform Surfaces", C_AMBER)
    tf = c3_3.text_frame
    bullets_3_3 = [
        "Web Launcher (Next.js 15): Over 1,446 pre-rendered static routes deployed on global edge networks with sub-second loading.",
        "Mobile Shell (Flutter Android APK): Ultra-lightweight APK packing embedded SQLite; 5 dedicated Offline Desks.",
        "Zero-Data Operation: Download exam packs once via Wi-Fi; practice 100% offline in remote villages without airtime.",
        "Desktop Gate Kiosk: Plug-and-play attendance and gate verification on inexpensive Windows/Linux laptops.",
        "ADR-0003 Anti-Cheat Security: Sealed answer keys kept strictly server-side; sha256 checksums verify bundle integrity."
    ]
    for b in bullets_3_3:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    add_footer(s3, 3)

    # ==========================================
    # SLIDE 4: The 207k Question Arsenal
    # ==========================================
    s4 = prs.slides.add_slide(blank_layout)
    add_background(s4)
    add_header(s4, "CURRICULUM VAULT", "Unrivaled National Question Repository: 207,172+ Banked", 
               "681 Specialized Academic Packs Spanning 1978 to 2025 Across Secondary, Screening, and Tertiary Levels", C_SKY)

    grid_data = [
        ("JAMB UTME GATEWAY", "43,553 Verified Questions  |  46 Subject Packs", 
         ["Full 4-Subject Official Configuration (Use of English + 3 electives)",
          "Realistic 2-hour official countdown clock with question navigator",
          "Complete coverage: Sciences, Social Sciences, Arts, and Commercial tracks",
          "Full comprehension passages, poetry analysis, and worked step-by-step models"], C_EMERALD, 0.8, 2.1),
        
        ("WAEC WASSCE & NECO SSCE", "40,077 Questions  |  72 Comprehensive Series", 
         ["WAEC (1988-2025): 37,696 questions covering Objective and Theory papers",
          "NECO SSCE & GCE: 2,381 verified curriculum-aligned questions",
          "Worked theory solutions showing step-by-step marking scheme rubrics",
          "Covers Mathematics, English, Physics, Chemistry, Biology, Economics, Lit-in-English"], C_SKY, 6.833, 2.1),
        
        ("POST-UTME SCREENING", "Premier Nigerian Universities Screening Series", 
         ["Authentic screening papers for University of Lagos (UNILAG)",
          "Federal University of Technology, Akure (FUTA) & UI screening series",
          "Obafemi Awolowo University (OAU) & University of Benin (UNIBEN)",
          "Aptitude tests, general paper screening, and speed drills for 200+ cutoffs"], C_AMBER, 0.8, 4.45),
        
        ("TERTIARY UNIVERSITY DESKS", "122,000+ Questions  |  548 Course Modules", 
         ["Foundational 100 & 200 Level Nigerian University course examination banks",
          "AMS 101 Principles of Management, COS 101 Computer Programming",
          "MEE 101 Engineering Mechanics, General Studies (GST 101/102)",
          "Semester lecture notes, past exam pools, and continuous CGPA forecasting"], C_PURPLE, 6.833, 4.45)
    ]

    for title, subtitle, points, col, l, t in grid_data:
        c = add_card(s4, l, t, 5.7, 2.15, title, col)
        tf = c.text_frame
        p = tf.add_paragraph()
        p.text = subtitle
        set_font(p, Pt(11), bold=True, color=col)
        p.space_after = Pt(4)
        for pt in points:
            p = tf.add_paragraph()
            p.text = "•  " + pt
            set_font(p, Pt(10), color=C_SLATE_50)
            p.space_after = Pt(2)

    add_footer(s4, 4)

    # ==========================================
    # SLIDE 5: CBT Exam Clock Coach & Forensics
    # ==========================================
    s5 = prs.slides.add_slide(blank_layout)
    add_background(s5)
    add_header(s5, "PROPRIETARY COGNITIVE ENGINE", "The CBT Exam Clock Coach: Neutralizing Hall Panic", 
               "Dynamic Real-Time Pacing Guidance and Post-Exam Clock Forensics That Recover 10–15 Lost Marks", C_EMERALD)

    c5_l = add_card(s5, 0.8, 2.1, 5.7, 4.5, "Dynamic CBT Pacing Engine: How It Works", C_EMERALD)
    tf = c5_l.text_frame
    bullets_5_l = [
        "The Mathematical Target Dwell Time (T_target):",
        "   T_target = Total Exam Duration / Total Number of Questions",
        "   (In a 40-question, 40-minute paper, baseline is exactly 60 seconds per item).",
        "",
        "Live Ambient Pacing Badge (Non-Intrusive Subconscious Conditioning):",
        "   [ON TRACK - GREEN] (t <= 1.2 x T_target): Answering within steady, optimal cadence.",
        "   [LINGERING - AMBER] (1.2 < t <= 2.0 x T_target): Subtle warning that safety buffer is eroding.",
        "   [TIME TRAP RISK - RED] (t > 2.0 x T_target): Visual circuit breaker prompting candidate to guess, flag, and preserve available marks ahead.",
        "",
        "Psychological Conditioning: Candidates instinctively internalize target velocity, eliminating the sudden 30-minute panic shock common in JAMB centers."
    ]
    for b in bullets_5_l:
        p = tf.add_paragraph()
        p.text = b
        is_highlight = any(k in b for k in ["[ON TRACK", "[LINGERING", "[TIME TRAP", "Target Dwell Time"])
        col = C_EMERALD if "[ON TRACK" in b else (C_AMBER if "[LINGERING" in b else (C_RED if "[TIME TRAP" in b else C_SLATE_50))
        set_font(p, Pt(11), bold=is_highlight, color=col if is_highlight else C_SLATE_50)
        p.space_after = Pt(2)

    c5_r = add_card(s5, 6.833, 2.1, 5.7, 4.5, "Post-Exam Panic Forensics Autopsy", C_AMBER)
    tf = c5_r.text_frame
    bullets_5_r = [
        "Temporal Reconstruction of the Entire Paper:",
        "Compares candidate's actual speed curve against ideal linear velocity.",
        "",
        "Time-Trap Isolation:",
        "Specifically identifies questions where a student sacrificed 3 to 5 minutes on a single item yet still chose an incorrect option.",
        "",
        "Panic Rush Zone Detection:",
        "Exposes late-exam questions answered in under 8 seconds due to expiring timers, proving where working memory collapsed.",
        "",
        "Calculated Lost Marks Metric:",
        "Empowers students by showing: 'You lost 8 marks to clock panic, not intellectual inability.' Transforming practice into scientific calibration."
    ]
    for b in bullets_5_r:
        p = tf.add_paragraph()
        p.text = b
        is_h = any(k in b for k in ["Isolation", "Detection", "Metric"])
        set_font(p, Pt(11), bold=is_h, color=C_AMBER if is_h else C_SLATE_50)
        p.space_after = Pt(2)

    add_footer(s5, 5)

    # ==========================================
    # SLIDE 6: Everyday Relatable Scenarios & Socratic AI
    # ==========================================
    s6 = prs.slides.add_slide(blank_layout)
    add_background(s6)
    add_header(s6, "PEDAGOGICAL INNOVATION", "Everyday Relatable Scenarios & Socratic AI", 
               "Translating Abstract Foreign Theorems into Lived Nigerian Realities and Guided Critical Thinking", C_AMBER)

    c6_l = add_card(s6, 0.8, 2.1, 5.7, 4.5, "Everyday Relatable Scenarios Engine", C_AMBER)
    tf = c6_l.text_frame
    scenarios = [
        ("Newton's First Law (Inertia)", "Standing inside a speeding yellow Danfo bus on Ikorodu Road when the driver abruptly hits the brakes - your upper torso lurches forward because your mass resists change in velocity."),
        ("Newton's Third Law (Action/Reaction)", "Stepping off a wooden canoe onto the muddy shore of a Lagos lagoon - the forward push of your foot exerts an equal and opposite force that kicks the canoe backward into the water."),
        ("Osmosis & Semi-Permeable Membranes", "Soaking rock-hard, wrinkled dried honey beans in fresh water overnight - discovering them swollen and soft by morning as water permeates the bean skin to dilute concentrated starches."),
        ("Opportunity Cost & Scarcity (Economics)", "Holding only NGN 1,500 and deciding between an internet data bundle for school assignments or a hot plate of cafeteria jollof rice - the true cost is the meal forfeited.")
    ]
    for title, desc in scenarios:
        p = tf.add_paragraph()
        p.text = ">>  " + title
        set_font(p, Pt(12), bold=True, color=C_AMBER)
        p2 = tf.add_paragraph()
        p2.text = desc
        set_font(p2, Pt(10), color=C_SLATE_50)
        p2.space_after = Pt(6)

    c6_r = add_card(s6, 6.833, 2.1, 5.7, 4.5, "Socratic AI Tutor (Hint-First Pedagogy)", C_SKY)
    tf = c6_r.text_frame
    bullets_6_r = [
        "Anti-Spoon-Feeding Law: Refuses to reveal multiple-choice letters (A, B, C, D) or copy-paste answers, preventing intellectual dependency.",
        "Diagnostic Guided Inquiry: When a student misses a question, the AI asks probing questions to isolate the core rule, variable, or grammar distinction.",
        "Step-by-Step Walking: Guides the candidate through equations (e.g. 'Look at Kinetic Energy Ek = 1/2mv^2. If speed doubles, what happens to velocity squared?').",
        "Deterministic Offline Hint Matrices: If internet connectivity drops, the system falls back to pre-compiled rule matrices stored inside local SQLite.",
        "Curriculum-Grounded: Trained exclusively on verified NERDC, JAMB, and WAEC syllabi, eliminating AI hallucinations."
    ]
    for b in bullets_6_r:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    add_footer(s6, 6)

    # ==========================================
    # SLIDE 7: 1v1 Arena & Spaced-Repetition Queue
    # ==========================================
    s7 = prs.slides.add_slide(blank_layout)
    add_background(s7)
    add_header(s7, "RETENTION & GAMIFICATION", "1v1 Multiplayer CBT Arena & Spaced Repetition", 
               "Turning Solitary Exam Drills into an Electrifying Social Sport While Halting Cognitive Decay", C_PURPLE)

    c7_l = add_card(s7, 0.8, 2.1, 5.7, 4.5, "1v1 Multiplayer CBT Arena (/arena)", C_PURPLE)
    tf = c7_l.text_frame
    bullets_7_l = [
        "Electrifying 5-Minute Academic Duels: Two candidates anywhere in Nigeria enter a virtual ring for a 15-question rapid-fire clash drawn from their shared syllabus.",
        "Ultra-Low Latency WebSocket Sync: Live synchronized score counters tick upward with sub-100ms response times, consuming negligible data bytes.",
        "Automated Study Bot Sparring: If no human peer matches within 20 seconds at odd hours, an intelligent study bot matched to candidate skill steps in.",
        "Gamified XP & Daily Streaks: Duels earn Experience Points (XP), level up avatars, and maintain consecutive study streaks.",
        "National School Leaderboards: Weekly state and school rankings foster healthy academic rivalry and pride."
    ]
    for b in bullets_7_l:
        p = tf.add_paragraph()
        p.text = "[*]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    c7_r = add_card(s7, 6.833, 2.1, 5.7, 4.5, "Spaced-Repetition Review Queue (/review)", C_EMERALD)
    tf = c7_r.text_frame
    bullets_7_r = [
        "Automated Mistake Harvesting: Every incorrect or skipped question from CBT mocks or practice sessions is instantly queued for retention.",
        "Ebbinghaus Forgetting Curve Calibration: Vulnerabilities resurface at scientifically calculated intervals: 24 Hours, 72 Hours, and 7 Days later.",
        "Targeted Remediation vs Blind Cramming: Eliminates the waste of re-sitting entire 50-question papers; targets only documented cognitive gaps.",
        "Permanent Memory Consolidation: Questions are graduated from the queue only after two consecutive correct answers under timed pressure.",
        "Seamless Sync: Fully synchronized between online web sessions and offline Android SQLite databases."
    ]
    for b in bullets_7_r:
        p = tf.add_paragraph()
        p.text = "[*]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    add_footer(s7, 7)

    # ==========================================
    # SLIDE 8: Zero-Data Sovereign Architecture
    # ==========================================
    s8 = prs.slides.add_slide(blank_layout)
    add_background(s8)
    add_header(s8, "TECHNICAL INFRASTRUCTURE", "Zero-Data Sovereign Architecture & 5 Offline Desks", 
               "Engineered to Flourish Where Mobile Broadband Fails and Electrical Power Fluctuates Across Nigeria", C_SKY)

    c8_1 = add_card(s8, 0.8, 2.1, 3.65, 4.5, "The 5 Offline Desks", C_EMERALD)
    tf = c8_1.text_frame
    bullets_8_1 = [
        "1. JAMB UTME Offline Desk: Full 46 subject packs with official 180-question mock generator.",
        "2. WAEC WASSCE Offline Desk: 61 packs with objective and worked theory solutions.",
        "3. NECO SSCE Offline Desk: 11 series covering standard secondary school testing.",
        "4. Post-UTME University Desk: Direct screening questions for UNILAG, FUTA, UI, OAU.",
        "5. School Workspace Desk: Complete teacher lesson notes, schemes, and question banks."
    ]
    for b in bullets_8_1:
        p = tf.add_paragraph()
        p.text = "[Desk]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c8_2 = add_card(s8, 4.84, 2.1, 3.65, 4.5, "Android SQLite Shell", C_SKY)
    tf = c8_2.text_frame
    bullets_8_2 = [
        "Native Flutter Performance: Runs smoothly even on low-cost entry-level Android smartphones.",
        "Embedded SQLite Database: Stores tens of thousands of questions and syllabi locally on the device.",
        "One-Time 5-Minute Sync: Connect to Wi-Fi once, download packs, and study for 6 months completely offline.",
        "Zero Data Consumption: Full CBT mock exams, Clock Coach, and everyday scenarios function in Airplane Mode.",
        "Standalone APK Distribution: Direct download without requiring high-friction app store accounts."
    ]
    for b in bullets_8_2:
        p = tf.add_paragraph()
        p.text = "[Mobile]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c8_3 = add_card(s8, 8.88, 2.1, 3.65, 4.5, "Go Backend & Edge Web", C_AMBER)
    tf = c8_3.text_frame
    bullets_8_3 = [
        "Go 1.27 Study API: Sub-15ms execution latency using goroutine worker pools for async grading.",
        "Next.js 15 Static Generation: Over 1,446 pre-rendered static routes on zero-cost edge networks.",
        "ADR-0003 Sealed Answer Keys: Questions contain only stems and choices; keys live strictly server-side.",
        "Cryptographic Bundle Checksums: SHA-256 integrity verification prevents client-side question tampering.",
        "Multi-Tenant PostgreSQL: Strict separation between student study data and institutional school records."
    ]
    for b in bullets_8_3:
        p = tf.add_paragraph()
        p.text = "[Cloud]  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    add_footer(s8, 8)

    # ==========================================
    # SLIDE 9: School OS: NERDC & Paper Slashing
    # ==========================================
    s9 = prs.slides.add_slide(blank_layout)
    add_background(s9)
    add_header(s9, "INSTITUTIONAL EFFICIENCY", "NERDC Curriculum Auto-Install & 70% Paper Slashing", 
               "Standardizing Academic Operations in 60 Seconds While Eradicating Crushing Printing Expenses", C_EMERALD)

    c9_l = add_card(s9, 0.8, 2.1, 5.7, 4.5, "1-Tap NERDC Statutory Curriculum Installation", C_EMERALD)
    tf = c9_l.text_frame
    bullets_9_l = [
        "Zero Manual Data Entry: Upon registration, Renance auto-provisions the official NERDC curriculum framework in 60 seconds.",
        "Complete National Ladder: Pre-populates Primary 1 to Primary 6, JSS 1 to JSS 3, and SSS 1 to SSS 3.",
        "All Secondary Streams: Covers Science, Arts, Commercial, and Technical subject pathways aligned with WAEC/NECO.",
        "12-Week Schemes of Work: Instant term schemes pre-fill every subject slot. Teachers customize rather than staring at blank pages.",
        "Multi-Tier Role Isolation: Proprietors hold sovereign administrative/financial keys; teachers access only assigned classes."
    ]
    for b in bullets_9_l:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    c9_r = add_card(s9, 6.833, 2.1, 5.7, 4.5, "Ink-Saving B&W Print Architecture (70%+ Savings)", C_AMBER)
    tf = c9_r.text_frame
    bullets_9_r = [
        "Strict Black-and-White Standard: Decorative color backgrounds and fills are banned, optimizing output for office laser printers.",
        "Single-Topic Print Optimization: Exports clean, 1-topic lesson sheets, ending wasteful 50-page notebook bulk printing.",
        "Economic Impact on School Budgets: In an era where a paper ream costs NGN 9,000 and toner cartridges cost small fortunes, Renance slashes paper expenditure from NGN 300,000+ to under NGN 90,000 per term.",
        "NERDC School Exam Pool: 1-click terminal examination generation pulls balanced, randomized papers ready for instant printing."
    ]
    for b in bullets_9_r:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(8)

    add_footer(s9, 9)

    # ==========================================
    # SLIDE 10: Institutional Daily Operations
    # ==========================================
    s10 = prs.slides.add_slide(blank_layout)
    add_background(s10)
    add_header(s10, "DAILY OPERATIONS", "Attendance Roster, Gate Kiosk & Collision-Free Timetable", 
               "Streamlining Morning Roll Call, Gate Entry, and Weekly Scheduling into Synchronized Workflows", C_SKY)

    c10_l = add_card(s10, 0.8, 2.1, 5.7, 4.5, "30-Second Attendance & Gate Kiosk Mode", C_SKY)
    tf = c10_l.text_frame
    bullets_10_l = [
        "30-Second Classroom Roll Call: Mobile tap-toggle roster eliminates 15 minutes of wasted morning roll calls.",
        "Gate Kiosk Mode: Tablet or laptop mounted at the school gate logs arrivals in real time, alerting management to truancy.",
        "SUBEB Regulatory Compliance: One-click export of monthly attendance registers in CSV/JSON format for state inspections.",
        "PTA Attendance Analytics: Generates termly student attendance percentages printed directly on verified terminal report cards."
    ]
    for b in bullets_10_l:
        p = tf.add_paragraph()
        p.text = "[*]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    c10_r = add_card(s10, 6.833, 2.1, 5.7, 4.5, "Collision-Free Timetable Matrix", C_PURPLE)
    tf = c10_r.text_frame
    bullets_10_r = [
        "Visual Weekly Matrix Builder: Intuitive grid mapping subjects, academic periods, assemblies, and recreation breaks.",
        "Atomic Single-Transaction Commit: Validates entire weekly schedule at once, preventing double-booked classrooms or overlapping teachers.",
        "Instant Staff Distribution: Once approved by management, timetable instantly propagates to all teacher personal mobile dashboards.",
        "Offline Classroom Reference: Teachers view assigned weekly schedules directly on their phones without paper printouts."
    ]
    for b in bullets_10_r:
        p = tf.add_paragraph()
        p.text = "[*]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    add_footer(s10, 10)

    # ==========================================
    # SLIDE 11: Tamper-Proof Grading & Result Checker
    # ==========================================
    s11 = prs.slides.add_slide(blank_layout)
    add_background(s11)
    add_header(s11, "ACADEMIC INTEGRITY", "Tamper-Proof Continuous Assessment & Result Checker", 
               "Eradicating Report Card Forgery and Eliminating Human Error from Terminal Grade Computation", C_EMERALD)

    c11_l = add_card(s11, 0.8, 2.1, 5.7, 4.5, "Universal Continuous Assessment Model", C_EMERALD)
    tf = c11_l.text_frame
    bullets_11_l = [
        "Nigerian Statutory Formula: CA1 (20%) + CA2 (20%) + Terminal Exam (60%) = 100%.",
        "Automated Calculations: Instantly calculates student totals, subject averages, grade boundaries (A1 to F9), and class rankings.",
        "Classroom Isolation: Teachers enter scores only for their assigned class and subject, preventing unauthorized grade manipulation.",
        "Lock & Certify Workflow: Management reviews and signs off on results; finalized records lock against retroactive tampering."
    ]
    for b in bullets_11_l:
        p = tf.add_paragraph()
        p.text = "[+]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    c11_r = add_card(s11, 6.833, 2.1, 5.7, 4.5, "Public Parent Result Checker (/school/check)", C_SKY)
    tf = c11_r.text_frame
    bullets_11_r = [
        "6-Digit Cryptographic Scratch PIN: Unique session-scoped PIN generated for each enrolled pupil at term end.",
        "Zero-Travel Smartphone Access: Parents navigate to /school/check, enter Student ID + PIN, and unlock verified digital report cards.",
        "Complete Forgery Eradication: Halts razor-blade grade alterations, correction fluid tampering, and NGN 500 counterfeit cyber-cafe prints.",
        "Official Institutional Seals: Displays verified school logo, principal endorsement, subject remarks, and tamper-proof security hash."
    ]
    for b in bullets_11_r:
        p = tf.add_paragraph()
        p.text = "[*]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    add_footer(s11, 11)

    # ==========================================
    # SLIDE 12: Financial Governance & ID Cards
    # ==========================================
    s12 = prs.slides.add_slide(blank_layout)
    add_background(s12)
    add_header(s12, "FINANCIAL GOVERNANCE", "Integer-Safe Kobo Accounting & Serialized ID Cards", 
               "Halting Revenue Leakage, Tracking Tuition Debtors, and Automating Student Identity Verification", C_AMBER)

    c12_l = add_card(s12, 0.8, 2.1, 5.7, 4.5, "Integer-Safe Kobo Accounting Ledger", C_AMBER)
    tf = c12_l.text_frame
    bullets_12_l = [
        "Exact Integer Accounting: Calculates every transaction in integer kobo (100 kobo = NGN 1.00), preventing floating-point rounding loss.",
        "Multi-Tier Fee Structures: Configures tuition, lab levies, uniforms, and PTA dues universally or by specific class cohorts.",
        "Multi-Channel Digital Receipts: Logs cash, verified bank transfer, POS, and drafts with immutable transaction receipt hashes.",
        "Real-Time Debtor Defaulter Roster: Principals view searchable rosters of unpaid fees, preventing exam-week fee evasion."
    ]
    for b in bullets_12_l:
        p = tf.add_paragraph()
        p.text = "[Naira]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    c12_r = add_card(s12, 6.833, 2.1, 5.7, 4.5, "Automated Serialized ID Card Engine", C_PURPLE)
    tf = c12_r.text_frame
    bullets_12_r = [
        "National Matriculation Serials: Standardized institutional format: REN-2026-NNNNNN (e.g., REN-2026-000142).",
        "Print-Ready 8-Card Batch Sheets: Exports printable sheets with pupil photographs, blood groups, emergency contacts, barcodes, and seals.",
        "Bypasses External Graphic Vendors: Schools print directly on office cardstock and laminate in-house, saving NGN 150,000+ yearly.",
        "Instant Anti-Fraud Revocation: Stolen or lost credentials are blacklisted instantly without deleting historical academic records."
    ]
    for b in bullets_12_r:
        p = tf.add_paragraph()
        p.text = "[ID]  " + b
        set_font(p, Pt(11), color=C_SLATE_50)
        p.space_after = Pt(10)

    add_footer(s12, 12)

    # ==========================================
    # SLIDE 13: Market Opportunity Across 774 LGAs
    # ==========================================
    s13 = prs.slides.add_slide(blank_layout)
    add_background(s13)
    add_header(s13, "MARKET OPPORTUNITY", "Massive National Footprint Across 774 LGAs", 
               "Capturing Nigeria's Expanding EdTech Frontier with an Unfair Offline Distribution Advantage", C_SKY)

    c13_1 = add_card(s13, 0.8, 2.1, 3.65, 4.5, "Total Addressable Market (TAM)", C_SKY)
    tf = c13_1.text_frame
    p = tf.add_paragraph()
    p.text = "NGN 120B+"
    set_font(p, Pt(26), bold=True, color=C_SKY)
    p.space_after = Pt(4)
    bullets_13_1 = [
        "1.4M+ Annual JAMB UTME candidates seeking university admission.",
        "1.6M+ Annual WAEC WASSCE candidates writing secondary school leaver exams.",
        "1.2M+ Annual NECO SSCE candidates across public and private centers.",
        "Millions of basic education pupils in Primary 1 to JSS 3 requiring curriculum support."
    ]
    for b in bullets_13_1:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c13_2 = add_card(s13, 4.84, 2.1, 3.65, 4.5, "Serviceable Market (SAM)", C_EMERALD)
    tf = c13_2.text_frame
    p = tf.add_paragraph()
    p.text = "40,000+ Schools"
    set_font(p, Pt(26), bold=True, color=C_EMERALD)
    p.space_after = Pt(4)
    bullets_13_2 = [
        "Primary and secondary institutions across 36 States + FCT seeking digital transformation.",
        "250+ Tertiary Institutions (Universities, Polytechnics, Colleges of Education).",
        "774 Local Government Areas: One sovereign deployment surface capable of operating offline.",
        "UBEC & SUBEB Partnerships: Direct institutional compliance with national digital mandates."
    ]
    for b in bullets_13_2:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    c13_3 = add_card(s13, 8.88, 2.1, 3.65, 4.5, "Teacher Income & Job Creation", C_AMBER)
    tf = c13_3.text_frame
    p = tf.add_paragraph()
    p.text = "Two-Sided Scale"
    set_font(p, Pt(26), bold=True, color=C_AMBER)
    p.space_after = Pt(4)
    bullets_13_3 = [
        "Earning Platform for Nigeria's Teachers: Qualified educators monetize revision notes, test pools & live lessons.",
        "Monetizing Real Demand: Tutors reach candidates across all 774 LGAs without physical travel.",
        "Unfair Distribution Advantage: Zero-data offline capability unlocks deep rural markets inaccessible to competitors.",
        "Low-Cost Android First: Works on inexpensive smartphones, eliminating expensive hardware requirements."
    ]
    for b in bullets_13_3:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(6)

    add_footer(s13, 13)

    # ==========================================
    # SLIDE 14: Business Model & Unit Economics
    # ==========================================
    s14 = prs.slides.add_slide(blank_layout)
    add_background(s14)
    add_header(s14, "BUSINESS MODEL", "Dual-Engine Monetization & High-Margin Unit Economics", 
               "Predictable High-Volume Consumer Subscriptions Paired with Recurring Institutional B2B SaaS", C_EMERALD)

    c14_l = add_card(s14, 0.8, 2.1, 5.7, 3.6, "Student Consumer Economy (B2C)", C_SKY)
    tf = c14_l.text_frame
    bullets_14_l = [
        "Free Frictionless Onboarding: 1 free full CBT simulation + 20 questions/session.",
        "NGN 500 / 1 Week Pass: Perfect for rapid pre-exam cramming sprints.",
        "NGN 1,500 / 1 Month Pass: Full access to all 681 packs and Socratic AI tutor.",
        "NGN 2,500 / 3 Months Pass: Termly prep for WAEC, NECO, or JAMB.",
        "NGN 5,000 / 1 Year All-Access (Best Value): Unrestricted web & mobile offline desks.",
        "REN Coin Economy: Win duels (+1 REN$), refer peers (+3 REN$), redeem 250 REN$ for 1 month premium - driving viral organic growth."
    ]
    for b in bullets_14_l:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(3)

    c14_r = add_card(s14, 6.833, 2.1, 5.7, 3.6, "Institutional School SaaS Tiers (B2B)", C_EMERALD)
    tf = c14_r.text_frame
    bullets_14_r = [
        "Basic (NGN 3,000/mo or NGN 10,000/yr): Up to 100 students. View-only notes, curriculum, attendance & results.",
        "Standard (NGN 6,000/mo or NGN 25,000/yr) - Most Popular: Up to 300 students. Exam bank, timetable, fee ledger, and ID cards.",
        "Premium (NGN 20,000/mo or NGN 60,000/yr): Unlimited students. Full PDF downloads, complete operations + 10 free annual student passes.",
        "Proprietor Friendly: School pays a flat predictable fee. Zero per-teacher or per-parent micro-charges.",
        "High Retention: Once curriculum, attendance, and ledgers are established, annual churn is under 5%."
    ]
    for b in bullets_14_r:
        p = tf.add_paragraph()
        p.text = "•  " + b
        set_font(p, Pt(10.5), color=C_SLATE_50)
        p.space_after = Pt(3)

    margin_bar = add_card(s14, 0.8, 5.85, 11.733, 0.9, "", C_AMBER, C_CARD_ALT)
    tf = margin_bar.text_frame
    p = tf.paragraphs[0]
    p.text = "HIGH-MARGIN UNIT ECONOMICS: OVER 85% GROSS MARGINS"
    set_font(p, Pt(12), bold=True, color=C_AMBER)
    p2 = tf.add_paragraph()
    p2.text = "Static Site Generation on edge CDNs combined with local SQLite on Android means marginal server cost per active offline student approaches NGN 0.00. Every additional subscriber drops straight to the bottom line."
    set_font(p2, Pt(10.5), color=C_WHITE)

    add_footer(s14, 14)

    # ==========================================
    # SLIDE 15: The Team, Capital Ask & Vision
    # ==========================================
    s15 = prs.slides.add_slide(blank_layout)
    add_background(s15)
    add_header(s15, "THE BUILDERS & THE ASK", "The Engineering Team, Capital Allocation & Vision", 
               "A Lean Technical Team Shipping Sovereign Educational Infrastructure for 774 Local Government Areas", C_EMERALD)

    c15_l = add_card(s15, 0.8, 2.1, 5.7, 4.5, "The Builders: Lean Technical Leadership", C_SKY)
    tf = c15_l.text_frame
    team = [
        ("Chief Technology Officer (CTO)", "Core Go Architecture & Renance AI Training", "Owns the high-throughput Go grading engine (<15ms), PostgreSQL schemas, and pedagogical AI models."),
        ("Lead Cybersecurity Engineer", "Device-Lock & Anti-Cheat Doctrine", "Owns 1-device hardware binding, ADR-0003 sealed answer keys, result encryption, and anti-fraud PINs."),
        ("Chief Product Engineer", "Cross-Platform UX/UI & Mobile SQLite Shell", "Owns the Next.js Web Launcher, Flutter Android APK, and offline-first desk performance.")
    ]
    for role, focus, desc in team:
        p = tf.add_paragraph()
        p.text = "[Leadership]  " + role
        set_font(p, Pt(12), bold=True, color=C_WHITE)
        p2 = tf.add_paragraph()
        p2.text = "Focus: " + focus
        set_font(p2, Pt(10.5), bold=True, color=C_SKY)
        p3 = tf.add_paragraph()
        p3.text = desc
        set_font(p3, Pt(10), color=C_SLATE_50)
        p3.space_after = Pt(6)

    c15_r = add_card(s15, 6.833, 2.1, 5.7, 2.6, "Funding Utilization (The Ask)", C_AMBER)
    tf = c15_r.text_frame
    ask_items = [
        ("40%", "Awareness Campaigns & Proprietor Workshops", "Direct roadshows onboarding 500+ private and public schools across primary education clusters."),
        ("35%", "AI Token Reserves & Cloud Storage Reserves", "High-throughput inference tokens for Socratic AI and multi-region database backups."),
        ("25%", "Ecosystem Developer Accounts & Distribution", "Apple Developer ($99), Google Play ($25), Microsoft Partner ($19), and APK distribution mirrors.")
    ]
    for pct, label, desc in ask_items:
        p = tf.add_paragraph()
        p.text = f"{pct}  -  {label}"
        set_font(p, Pt(11), bold=True, color=C_AMBER)
        p2 = tf.add_paragraph()
        p2.text = desc
        set_font(p2, Pt(9.5), color=C_SLATE_50)
        p2.space_after = Pt(4)

    vis_card = add_card(s15, 6.833, 4.85, 5.7, 1.75, "The Sovereign Horizon", C_EMERALD, C_CARD_ALT)
    tf = vis_card.text_frame
    p = tf.paragraphs[0]
    p.text = "Modernizing Nigerian Education."
    set_font(p, Pt(15), bold=True, color=C_WHITE)
    p2 = tf.add_paragraph()
    p2.text = "One sovereign platform. Two engines. 774 Local Government Areas."
    set_font(p2, Pt(11), bold=True, color=C_EMERALD)
    p3 = tf.add_paragraph()
    p3.text = "renance.app  •  Learn. Practice. Rise."
    set_font(p3, Pt(12), bold=True, color=C_SKY)
    p3.space_before = Pt(4)

    add_footer(s15, 15)

    # Save presentation
    os.makedirs(os.path.dirname(output_pptx_path), exist_ok=True)
    prs.save(output_pptx_path)
    print(f"Presentation saved successfully to: {output_pptx_path}")

if __name__ == "__main__":
    out_path = os.path.abspath("docs/RENANCE_15_SLIDE_PITCH_DECK.pptx")
    create_deck(out_path)
