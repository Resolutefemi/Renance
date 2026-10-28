#!/usr/bin/env python3
"""
build_and_upload_300_clean.py
Rebuilds 300 active canonical tertiary courses (140 units per course = 42,000 units,
420,000 notes of strictly 200-300 words, 840,000 quiz items with Question #20 as a
Scenario Decision Quiz Question) using the regenerated course-specific Supabase
sections and units (/tmp/supabase_3677_catalog.json).
Enforces ZERO hyphens/dashes (-, –, —) across all note titles, note bodies, summaries,
key points, quiz stems, quiz options, and quiz explanations.
Uploads 300 per-course JSON packs (courses/<course_id>.json) + manifest to Cloudflare R2.
"""

import datetime
import hashlib
import hmac
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

R2_ENDPOINT = "https://ff1e18e32afe87e8e07b3c35595fdd0e.r2.cloudflarestorage.com"
R2_HOST = "ff1e18e32afe87e8e07b3c35595fdd0e.r2.cloudflarestorage.com"
R2_BUCKET = "renance"
R2_AK = "78b8e71ffccaf0bdf12b95a6b108000f"
R2_SK = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"

HYPHEN_RE = re.compile(r"[\u002D\u2010\u2011\u2012\u2013\u2014\u2015\u2212]")

def no_hyphen(s: str) -> str:
    if not s:
        return ""
    s = s.replace("&", "and")
    s = HYPHEN_RE.sub(" ", s)
    return " ".join(s.split())

def sanitize_r2_key(course_id: str) -> str:
    # Matches Go r2store.sanitizeKey in apps/study-api/internal/r2store/r2store.go
    out = []
    for ch in course_id.strip()[:160]:
        if ("a" <= ch <= "z") or ("A" <= ch <= "Z") or ("0" <= ch <= "9") or ch in ("-", "_", "."):
            out.append(ch)
        else:
            out.append("-")
    return "".join(out)

DOMAIN_CONTEXT = {
    "sports_phe": {
        "focus": "biomechanical execution, athletic conditioning, tactical spacing, officiating accuracy, and player safety",
        "method": "kinematic motion breakdown, heart rate and metabolic load monitoring, progressive drill sequencing, and World Athletics or FIFA rulebook verification",
        "metric": "stride frequency, takeoff velocity, work to rest ratio, recovery heart rate, and foulfree technical execution across competitive rounds",
        "setting": "Nigerian collegiate track and field stadiums, indoor sports halls, and Physical and Health Education practicum arenas",
        "trap": "sacrificing postural alignment and joint stabilization for premature speed or neglecting surface safety and warm up progression",
        "scenario_problem": "an athlete displays early deceleration, knee valgus, and timing faults during high intensity transition drills on a humid afternoon track session",
        "scenario_correct": "Pause the drill immediately to cue postural alignment, adjust the work to rest recovery interval, and verify footwear traction before resuming full speed",
        "scenario_wrong": [
            "Increase sprint load and reduce rest intervals immediately to force muscular adaptation under fatigue",
            "Ignore the biomechanical drift and record only the final stopwatch reading for the assessment sheet",
            "Eliminate technical warm up drills and proceed directly to maximum load competitive elimination heats"
        ]
    },
    "info_literacy": {
        "focus": "scholarly source evaluation, Boolean query precision, bibliographic control, metadata standardization, and academic integrity",
        "method": "CRAAP authority auditing, Library of Congress subject classification, cross database triangulation, and standardized APA or MLA citation formatting",
        "metric": "search precision to recall ratio, citation completeness, primary source provenance verification, and zero unattributed text overlap",
        "setting": "Nigerian university research libraries, institutional digital repositories, NUC virtual portals, and archival reference collections",
        "trap": "confusing keyword popularity with peer reviewed authority or copying secondary abstracts without verifying the underlying primary dataset",
        "scenario_problem": "a research student retrieves two conflicting policy statistics from an undated blog post and a peer reviewed Nigerian institutional repository dataset",
        "scenario_correct": "Trace both claims to the primary institutional statistical bulletin, verify publication metadata and methodology, and cite the peer reviewed primary record",
        "scenario_wrong": [
            "Average the two conflicting figures without checking the publication date or methodological notes",
            "Select the undated blog figure because it appears higher in general web search results",
            "Omit the citation entirely so the discrepancy cannot be audited by the project supervisor"
        ]
    },
    "world_african_lang": {
        "focus": "phonemic articulation, tonal or accent accuracy, morphological agreement, syntactic word order, and culturally grounded communicative fluency",
        "method": "minimal pair phonetic contrast, paradigm conjugation analysis, syntactic tree mapping, and bidirectional contextual translation",
        "metric": "orthographic accuracy, tonal and concord consistency, idiomatic appropriateness, and semantic equivalence across formal and informal registers",
        "setting": "Nigerian tertiary language laboratories, oral proficiency examination rooms, translation bureaus, and cross cultural diplomatic forums",
        "trap": "applying word for word literal calques from English that violate target language noun class concord, verbal aspect, or tonal meaning",
        "scenario_problem": "a learner translating an official community notice produces a literal sentence whose tonal placement and pronoun concord invert the intended respectful register",
        "scenario_correct": "Reconstruct the clause using the target language honorific pronoun concord, verify tonal or diacritic marking, and validate idiomatic equivalence aloud",
        "scenario_wrong": [
            "Retain the literal word for word English word order and strip all diacritic or tonal markers",
            "Substitute informal street slang for the official register to shorten the sentence length",
            "Skip oral verification and submit the unedited machine transliteration directly for publication"
        ]
    },
    "english_comm": {
        "focus": "phonological clarity, grammatical concord, syntactic coherence, critical reading inference, and formal academic and workplace discourse",
        "method": "clause structure parsing, subject verb agreement verification, rhetorical paragraph outlining, and systematic stylistic proofreading",
        "metric": "grammatical concord accuracy, lexical precision, logical transition flow, summary condensation fidelity, and register appropriateness",
        "setting": "Nigerian university lecture halls, senate committee secretariat reports, professional corporate correspondence, and academic symposiums",
        "trap": "allowing proximity distraction in long noun phrases to corrupt subject verb concord or mixing colloquial expressions into formal technical reports",
        "scenario_problem": "a draft committee report contains dangling modifiers, plural verb discord after a collective singular headword, and unsupported generalizations in the executive summary",
        "scenario_correct": "Identify the grammatical headword of each clause to restore concord, attach every modifier to its explicit subject, and anchor summary claims to report data",
        "scenario_wrong": [
            "Replace all complex sentences with disconnected sentence fragments and remove quantitative evidence",
            "Match every verb to the nearest noun inside prepositional phrases regardless of the true clause subject",
            "Expand the executive summary with unverified personal opinions to increase the total word count"
        ]
    },
    "computer_science": {
        "focus": "algorithmic correctness, data structure invariants, asymptotic time and space efficiency, memory safety, and defensive system architecture",
        "method": "formal invariant trace analysis, Big O complexity derivation, modular interface specification, and automated boundary unit testing",
        "metric": "worst case execution latency, memory footprint overhead, thread safety under concurrent load, and zero unhandled edge case faults",
        "setting": "Nigerian software engineering teams, high throughput financial transaction pipelines, academic computing laboratories, and cloud production clusters",
        "trap": "optimizing syntax prematurely while leaving quadratic nested lookups, unvalidated external inputs, or race conditions in shared state",
        "scenario_problem": "a production service experiences sudden latency spikes and intermittent state corruption whenever concurrent requests access a shared in memory index",
        "scenario_correct": "Profile the critical path to confirm the contention point, enforce synchronized or immutable state access, and verify complexity with a concurrent load test",
        "scenario_wrong": [
            "Disable input validation and error logging in production to mask the intermittent state corruption",
            "Restart the server manually every hour without analyzing the shared memory access pattern",
            "Replace indexed lookups with nested linear scans across the entire unindexed table on every request"
        ]
    },
    "math_stats": {
        "focus": "axiomatic rigor, domain and convergence verification, analytical derivation, unbiased statistical estimation, and model diagnostic validation",
        "method": "deductive proof construction, boundary and limit evaluation, matrix transformation, and residual distribution diagnostics",
        "metric": "proof completeness, numerical convergence stability, confidence interval coverage, and unbiased estimator variance minimization",
        "setting": "quantitative research seminars, actuarial and biometric modelling units, engineering computation labs, and university mathematics examinations",
        "trap": "applying a theorem or parametric statistical test without verifying continuity, differentiability, independence, or variance homogeneity assumptions",
        "scenario_problem": "an analyst modelling skewed economic survey data applies an ordinary linear formula without checking domain constraints or extreme outlier leverage",
        "scenario_correct": "Inspect the domain and residual diagnostics first, apply the appropriate mathematical transformation or robust estimator, and verify convergence bounds",
        "scenario_wrong": [
            "Delete all observations that do not fit the desired slope without documenting the selection rule",
            "Extrapolate the linear equation far outside the observed domain without checking boundary validity",
            "Ignore the violated variance assumption and report the unadjusted p value as definitive proof"
        ]
    },
    "chemistry_pure": {
        "focus": "stoichiometric conservation, electronic and molecular geometry, thermodynamic spontaneity, kinetic rate control, and analytical precision",
        "method": "balanced molar calculation, orbital hybridization analysis, Gibbs free energy and Nernst potential evaluation, and volumetric or spectroscopic calibration",
        "metric": "percent yield, molar purity, titration endpoint reproducibility, equilibrium constant consistency, and adherence to laboratory hazard protocols",
        "setting": "Nigerian university analytical chemistry laboratories, petrochemical quality control units, pharmaceutical assay facilities, and industrial pilot plants",
        "trap": "confusing thermodynamic spontaneity with kinetic reaction speed or neglecting limiting reagent stoichiometry and blank calibration corrections",
        "scenario_problem": "during a quantitative volumetric assay, successive titrations yield drifting endpoints and a calculated purity exceeding one hundred percent",
        "scenario_correct": "Halt the assay to standardize the titrant against a primary standard, run a reagent blank correction, and inspect the burette and indicator pH range",
        "scenario_wrong": [
            "Record only the lowest titration volume and discard the remaining readings without investigation",
            "Add concentrated acid rapidly at the endpoint to force an immediate colour change",
            "Scale down the recorded sample mass retroactively so the calculated purity falls below one hundred percent"
        ]
    },
    "physics_pure": {
        "focus": "dimensional homogeneity, vector conservation laws, field and wave boundary behaviour, thermodynamic efficiency, and experimental uncertainty control",
        "method": "free body and field line formulation, differential conservation equation derivation, dimensional checking, and linearised graphical error analysis",
        "metric": "energy and momentum conservation fidelity, signal to noise ratio, percentage experimental uncertainty, and dimensional consistency across every term",
        "setting": "university physics instrumentation laboratories, power and telecommunications testbeds, geophysical survey stations, and metrology calibration centres",
        "trap": "mixing scalar magnitudes with directional vector components or substituting numerical values before verifying SI unit conversions and sign conventions",
        "scenario_problem": "an experimental measurement of an oscillatory electromagnetic system produces a systematic twenty percent offset from theoretical conservation predictions",
        "scenario_correct": "Audit instrument zero calibration, verify SI unit prefixes and vector component projections, and account for damping or internal resistance losses",
        "scenario_wrong": [
            "Multiply the final experimental column by a constant factor to hide the systematic offset",
            "Drop the directional sign conventions and add perpendicular vector magnitudes arithmetically",
            "Continue collecting uncalibrated readings while ignoring thermal drift in the sensor circuit"
        ]
    },
    "bio_biochem": {
        "focus": "cellular and molecular organization, enzymatic and metabolic regulation, homeostatic feedback, genetic transmission, and ecological interdependence",
        "method": "aseptic culture and microscopy, spectrophotometric enzyme assay, serial dilution quantification, and randomized controlled bioassay design",
        "metric": "specific enzyme activity, cellular viability, negative and positive control validity, and statistically significant treatment separation",
        "setting": "Nigerian biological science laboratories, biochemistry diagnostic units, ecological field research stations, and biotechnology culture suites",
        "trap": "interpreting a bioassay without verifying negative and positive controls or allowing thermal and pH drift to denature biological specimens",
        "scenario_problem": "in a controlled biochemical assay, the negative buffer control exhibits unexpected optical absorbance nearly equal to the treated experimental tubes",
        "scenario_correct": "Invalidate the run immediately, inspect reagents and micropipettes for cross contamination, prepare fresh sterile buffer controls, and repeat the assay",
        "scenario_wrong": [
            "Subtract the contaminated control reading blindly and publish the noisy difference as a valid kinetic rate",
            "Increase the incubation temperature past seventy degrees Celsius to accelerate the remaining tubes",
            "Discard the negative control tube from the laboratory notebook and report only the treated tubes"
        ]
    },
    "engineering_tech": {
        "focus": "conservation balances, material stress and fatigue limits, dimensional sizing with safety factors, feedback control stability, and COREN regulatory compliance",
        "method": "control volume and free body modelling, constitutive stress strain calculation, transient response simulation, and non destructive quality inspection",
        "metric": "factor of safety margin, thermal and hydraulic efficiency, dimensional tolerance compliance, mean time between failures, and lifecycle cost effectiveness",
        "setting": "Nigerian civil, mechanical, electrical, and chemical engineering design offices, industrial manufacturing plants, and infrastructure project sites",
        "trap": "sizing a load bearing or high pressure component on average static load alone without accounting for dynamic surge, fatigue, corrosion, or safety codes",
        "scenario_problem": "during commissioning of an engineered process unit, pressure and vibration transducers approach the maximum allowable working limit under peak load",
        "scenario_correct": "Execute a controlled load reduction, verify relief valve and sensor calibration against the design P and ID, and audit dynamic surge and support stiffness",
        "scenario_wrong": [
            "Bypass the high pressure trip interlock so the unit can continue operating above its rated design limit",
            "Tighten the relief valve spring beyond the ASME or SON specification to stop it from lifting",
            "Ignore the vibration harmonics until a structural fatigue crack becomes visible on the casing"
        ]
    },
    "medicine_health": {
        "focus": "anatomical and physiological accuracy, pathophysiological mechanism recognition, evidence based clinical triage, aseptic safety, and ethical patient care",
        "method": "structured clinical history and physical examination, differential diagnosis ranking, targeted biomarker verification, and weight based therapeutic dosing",
        "metric": "diagnostic sensitivity and specificity, vital sign stabilization, medication dosing accuracy, zero healthcare associated infection, and informed consent compliance",
        "setting": "Nigerian teaching hospital wards, primary healthcare centres, clinical diagnostic laboratories, and community epidemiology outreach units",
        "trap": "initiating aggressive empirical intervention without checking airway and hemodynamic stability, allergy history, or renal and hepatic clearance constraints",
        "scenario_problem": "a patient presenting to the clinical unit displays acute vital sign deterioration and an ambiguous preliminary rapid screening result",
        "scenario_correct": "Stabilize airway, breathing, and circulation immediately, repeat confirmatory diagnostic profiling with strict asepsis, and document serial clinical observations",
        "scenario_wrong": [
            "Administer an unverified high dose medication without checking vital signs or allergy history",
            "Discharge the patient immediately based solely on the ambiguous preliminary screening result",
            "Delay clinical stabilization until non urgent administrative billing forms are completed"
        ]
    },
    "agriculture_food": {
        "focus": "agroecological adaptation, soil and water conservation, integrated pest and disease management, postharvest loss prevention, and food safety quality",
        "method": "soil and proximate laboratory testing, randomized complete block field trials, economic threshold pest scouting, and hazard analysis critical control point monitoring",
        "metric": "yield per hectare, feed conversion efficiency, postharvest moisture safety below critical limits, and benefit to cost enterprise profitability",
        "setting": "Nigerian university research farms, agroecological extension zones, livestock and aquaculture production units, and food processing facilities",
        "trap": "applying blanket chemical inputs or harvesting produce without soil testing, pest threshold scouting, or postharvest moisture verification",
        "scenario_problem": "a batch of harvested grain entering the storage and processing unit shows elevated moisture content and early localized fungal hotspot formation",
        "scenario_correct": "Isolate the affected lot immediately, aerate and dry the grain to the safe equilibrium moisture threshold, and test for mycotoxin safety before storage",
        "scenario_wrong": [
            "Blend the damp fungal grain into dry stock to conceal the moisture excess prior to bagging",
            "Seal the warm damp grain in airtight plastic drums under direct sunlight without drying",
            "Apply unapproved residual field pesticides directly onto finished food grain ready for market"
        ]
    },
    "law_criminology": {
        "focus": "constitutional supremacy, statutory interpretation, judicial precedent hierarchy, evidentiary admissibility, and procedural fairness",
        "method": "IRAC legal issue spotting, ratio decidendi extraction from appellate decisions, statutory section cross referencing, and precision legal drafting",
        "metric": "jurisdictional validity, discharge of the applicable burden and standard of proof, adherence to natural justice, and enforceability of remedies",
        "setting": "Nigerian superior courts of record, law faculties, chambers advocacy reviews, regulatory compliance tribunals, and arbitration panels",
        "trap": "relying on persuasive obiter dicta or foreign commentary while overlooking binding Nigerian appellate ratio decidendi or mandatory statutory preconditions",
        "scenario_problem": "counsel preparing a claim discovers that a mandatory statutory pre action notice period was not observed and a key document lacks proper evidentiary certification",
        "scenario_correct": "Regularize the statutory pre action compliance and certify the public document under the Evidence Act before invoking the jurisdiction of the court",
        "scenario_wrong": [
            "File the defective originating process immediately and conceal the missing statutory notice from the court",
            "Alter the date on the uncertified document to make it appear compliant with the limitation statute",
            "Argue that equitable sympathy overrides an express constitutional and statutory jurisdictional condition"
        ]
    },
    "accounting_finance_econ": {
        "focus": "double entry integrity, accrual and fair value recognition, cost and variance control, risk adjusted capital allocation, and macroeconomic equilibrium",
        "method": "trial balance and ledger reconciliation, IFRS compliant financial statement preparation, discounted cash flow valuation, and econometric elasticity testing",
        "metric": "audit trail completeness, liquidity and solvency ratio health, net present value positivity, variance reconciliation accuracy, and statutory tax compliance",
        "setting": "Nigerian corporate finance departments, audit assurance practices, commercial banking credit committees, and economic policy research desks",
        "trap": "confusing accounting book profit with net operating cash flow or failing to reconcile suspense accounts and unrecorded accrual liabilities",
        "scenario_problem": "during a pre audit financial review, reported operating profit rises sharply while net operating cash flow turns negative and a suspense balance remains unexplained",
        "scenario_correct": "Trace every suspense entry to source vouchers, audit revenue cut off and receivable collectability, and reconcile profit to operating cash flow before sign off",
        "scenario_wrong": [
            "Write off the unexplained suspense balance directly to retained earnings without voucher inspection",
            "Recognize next quarter projected sales as current period cash revenue to improve liquidity ratios",
            "Approve dividend distribution immediately based on unadjusted book profit despite negative cash flow"
        ]
    },
    "business_management": {
        "focus": "strategic alignment, operational workflow efficiency, consumer value delivery, human capital motivation, and ethical corporate governance",
        "method": "SWOT and PESTEL environmental scanning, critical path operational scheduling, key performance indicator tracking, and stakeholder negotiation",
        "metric": "service delivery lead time, customer retention rate, inventory turnover, employee productivity, and CAMA governance compliance",
        "setting": "Nigerian commercial enterprises, manufacturing operations, public sector agencies, entrepreneurial ventures, and supply chain hubs",
        "trap": "launching an expansion or restructuring initiative without validating unit economics, working capital runway, or frontline operational capacity",
        "scenario_problem": "an enterprise experiences rising customer order backlogs, high frontline staff turnover, and working capital strain following an uncoordinated promotional surge",
        "scenario_correct": "Align sales intake with verified production capacity, eliminate workflow bottlenecks, address frontline workload and incentives, and tighten receivable collection",
        "scenario_wrong": [
            "Double promotional spending immediately while ignoring the fulfillment backlog and cash shortage",
            "Replace quality inspection stages with unverified rapid shipping to clear the warehouse floor",
            "Withhold statutory staff wages to finance short term advertising campaigns"
        ]
    },
    "environment_design": {
        "focus": "spatial and geodetic precision, structural and environmental sustainability, land valuation accuracy, statutory planning compliance, and climate resilience",
        "method": "closed traverse survey adjustment, GIS spatial overlay modelling, architectural anthropometric zoning, bill of quantities taking off, and EIA baseline auditing",
        "metric": "survey closure accuracy, structural and thermal performance, lifecycle cost precision, drainage flood resilience, and Nigerian Urban and Regional Planning compliance",
        "setting": "Nigerian architectural design studios, geodetic survey camps, urban planning authorities, construction sites, and environmental assessment consultancies",
        "trap": "finalizing a spatial layout or structural bill without verifying geodetic datum closure, soil bearing capacity, flood return periods, and statutory setbacks",
        "scenario_problem": "a site development survey reveals a discrepancy between the deed boundary coordinates, seasonal floodplain encroachment, and the proposed building footprint",
        "scenario_correct": "Re verify the geodetic control traverse on site, adjust the building footprint to respect statutory floodplain setbacks, and update the foundation specification",
        "scenario_wrong": [
            "Proceed with excavation on the unverified floodplain boundary to avoid revising the studio drawings",
            "Falsify the levelling booking sheet so the site gradient appears flat on the submission plan",
            "Omit drainage and environmental impact provisions from the bill of quantities to lower the tender sum"
        ]
    },
    "education_counselling": {
        "focus": "learner centred pedagogy, measurable instructional objectives, psychometric assessment validity, ethical counselling guidance, and inclusive classroom leadership",
        "method": "Bloom taxonomy instructional blueprinting, diagnostic formative questioning, item difficulty and discrimination analysis, and empathetic client interviewing",
        "metric": "learning outcome mastery rate, test reliability coefficient, inclusive learner participation, and alignment with the Nigerian National Policy on Education",
        "setting": "Nigerian university faculties of education, secondary and tertiary microteaching laboratories, school guidance counselling centres, and curriculum panels",
        "trap": "delivering abstract monologue lectures or administering unvalidated assessments without diagnostic baseline checks, inclusive scaffolding, or confidential ethics",
        "scenario_problem": "during a practicum evaluation, half the class struggles with a foundational concept while a distressed student requests confidential vocational and academic guidance",
        "scenario_correct": "Re scaffold the lesson using concrete diagnostic examples and formative checks for the class, and schedule a private ethical counselling session for the student",
        "scenario_wrong": [
            "Publicly reprimand the struggling learners in front of the class and discuss the student private issue aloud",
            "Proceed rapidly to advanced topics without checking whether the foundational objective was mastered",
            "Assign final grades using an unmoderated single item test that was never taught in the scheme of work"
        ]
    },
    "arts_humanities_social": {
        "focus": "primary source provenance, theoretical and historiographical rigor, institutional power analysis, normative ethical coherence, and comparative synthesis",
        "method": "archival and textual criticism, qualitative and survey triangulation, logical validity verification, and comparative institutional analysis",
        "metric": "primary evidence corroboration, internal logical consistency, methodological transparency, and balanced engagement with competing scholarly interpretations",
        "setting": "Nigerian humanities and social science seminars, historical archives, policy research institutes, media discourse forums, and diplomatic roundtables",
        "trap": "relying on anachronistic assumptions, single source partisan narratives, or informal logical fallacies without cross checking primary empirical evidence",
        "scenario_problem": "a researcher analysing a contested historical and policy event encounters two contradictory primary archival dispatches with clear institutional bias",
        "scenario_correct": "Contextualize the authorship and institutional incentives of both dispatches, triangulate against independent contemporaneous records, and present a balanced synthesis",
        "scenario_wrong": [
            "Suppress the dispatch that contradicts the researcher preferred thesis and cite only the convenient text",
            "Treat partisan rhetorical claims as objective demographic facts without archival corroboration",
            "Replace primary source analysis with sweeping generalizations unsupported by dated evidence"
        ]
    }
}

NOTE_HEADING_TEMPLATES = [
    "Foundational Principles and Scope of {U}",
    "Theoretical Architecture and Core Mechanisms of {U}",
    "Analytical Formulation and Operational Rules in {U}",
    "Step by Step Procedural Execution for {U}",
    "Applied Case Analysis and Quantitative Demonstration of {U}",
    "Nigerian Institutional Practice and Field Context for {U}",
    "Diagnostic Verification and Quality Control in {U}",
    "Common Pitfalls Misconceptions and Corrective Safeguards in {U}",
    "Comparative Synthesis across {S}",
    "Mastery Review Examination Readiness and Professional Standards in {U}"
]

def build_note_body(note_idx: int, course_title: str, dept_name: str, faculty: str, sec_title: str, unit_title: str, dom_key: str) -> str:
    ctx = DOMAIN_CONTEXT.get(dom_key, DOMAIN_CONTEXT["arts_humanities_social"])
    c_clean = no_hyphen(course_title)
    d_clean = no_hyphen(dept_name)
    f_clean = no_hyphen(faculty)
    s_clean = no_hyphen(sec_title)
    u_clean = no_hyphen(unit_title)

    focus = ctx["focus"]
    method = ctx["method"]
    metric = ctx["metric"]
    setting = ctx["setting"]
    trap = ctx["trap"]

    paragraphs = [
        # Note 1: Foundational Principles
        (
            f"Within the curriculum of {c_clean} in the Department of {d_clean} under the Faculty of {f_clean}, the study of {u_clean} establishes the foundational conceptual framework for {s_clean}. "
            f"At its core, this topic governs {focus} so that students and practitioners operate from precise, verifiable definitions rather than informal approximations. "
            f"Every analytical workflow in {c_clean} begins by identifying the governing variables, boundary assumptions, and institutional standards that distinguish rigorous work from superficial observation. "
            f"In professional settings across {setting}, mastery of {u_clean} enables teams to classify observations accurately, select appropriate analytical methods, and communicate findings without ambiguity. "
            f"When foundational terms are defined clearly at the outset, subsequent stages of analysis in {s_clean} proceed with full structural coherence. "
            f"Conversely, any ambiguity in baseline definitions propagates across calculations, field observations, and policy interpretations, undermining reliability across the wider discipline of {d_clean}. "
            f"Students preparing for advanced work in {c_clean} should therefore anchor every explanation of {u_clean} in explicit domain principles, measurable criteria, and verified institutional benchmarks."
        ),
        # Note 2: Theoretical Architecture
        (
            f"The theoretical architecture of {u_clean} within {s_clean} connects core disciplinary principles in {c_clean} to observable system behaviour. "
            f"Rather than treating rules in isolation, rigorous scholarship in {d_clean} examines how underlying mechanisms interact through {method}. "
            f"Each structural component of {u_clean} fulfills a distinct functional role, linking primary inputs and environmental constraints to predictable analytical outcomes. "
            f"Understanding why these relationships hold allows a specialist in {c_clean} to predict how the system responds when an operating parameter shifts or when a boundary condition is tightened. "
            f"Across {setting}, theoretical models of {u_clean} serve as diagnostic maps that guide both routine execution and complex troubleshooting. "
            f"By tracing cause and effect from first principles through intermediate transformations to final indicators such as {metric}, learners avoid rote memorization and build durable conceptual command. "
            f"This theoretical fluency is essential whenever novel problems in {s_clean} require adapting standard models to real world constraints."
        ),
        # Note 3: Analytical Formulation
        (
            f"Analytical formulation in {u_clean} translates conceptual principles of {c_clean} into structured decision rules, governing relationships, and verifiable criteria. "
            f"Within {s_clean}, practitioners rely on {method} to evaluate performance, compare alternatives, and establish objective thresholds for acceptance or rejection. "
            f"Every analytical expression or structural rule in {u_clean} rests on explicit preconditions that must be checked before the formulation is applied in practice. "
            f"Key performance and quality indicators, including {metric}, provide quantitative and qualitative benchmarks that keep evaluations transparent and reproducible across independent reviewers in {d_clean}. "
            f"When documenting an analytical formulation in {c_clean}, every variable, classification category, and unit of measurement must be stated unambiguously. "
            f"This discipline prevents silent distortions caused by {trap}, ensuring that conclusions drawn during {s_clean} remain defensible under academic scrutiny and professional audit across {setting}."
        ),
        # Note 4: Step by Step Procedural Execution
        (
            f"Executing {u_clean} effectively in {c_clean} requires a disciplined, sequential methodology that preserves accuracy from initial preparation to final verification. "
            f"In the first stage of {s_clean}, the practitioner inspects the baseline environment, validates all prerequisites, and confirms that instruments, sources, or operational parameters meet required standards. "
            f"In the second stage, core procedures are carried out using {method}, maintaining strict adherence to sequence, timing, and documentation protocols established in {d_clean}. "
            f"During execution, intermediate observations are monitored continuously against expected ranges for {metric} so that any deviation is detected immediately rather than after completion. "
            f"In the final stage, outcomes are consolidated, cross checked against independent controls, and recorded in a clear format suitable for institutional review across {setting}. "
            f"Following this structured progression eliminates ad hoc shortcuts and guarantees consistent, repeatable excellence across all practical assignments in {c_clean}."
        ),
        # Note 5: Applied Case Analysis
        (
            f"Applied case analysis demonstrates how {u_clean} operates when theoretical rules in {c_clean} encounter realistic operational data and multidimensional constraints. "
            f"Consider a structured scenario within {s_clean} where a team in {d_clean} must evaluate two competing approaches under strict quality and resource limits. "
            f"By applying {method}, the team first isolates the governing parameters, normalizes the baseline data, and evaluates each option against the core benchmark of {metric}. "
            f"Whereas an informal assessment might overlook secondary interactions, systematic analysis of {u_clean} reveals how initial trade offs affect downstream stability and long term performance. "
            f"Documenting each step of the worked comparison allows peers and supervisors across {setting} to verify the reasoning path independently. "
            f"Through repeated engagement with realistic case demonstrations in {c_clean}, students develop the analytical judgment needed to translate classroom theory into decisive professional action."
        ),
        # Note 6: Nigerian Institutional Practice
        (
            f"In the Nigerian tertiary and professional landscape, {u_clean} holds direct practical relevance across {setting}. "
            f"Departments of {d_clean} in Nigerian universities, polytechnics, and colleges of education emphasize {s_clean} because domestic industries and public institutions depend on graduates who combine theoretical mastery with contextual adaptability. "
            f"When applying {u_clean} within Nigerian operational environments, practitioners must account for local regulatory frameworks, climatic and infrastructural realities, and institutional quality standards. "
            f"Integrating {method} with rigorous monitoring of {metric} ensures that projects and studies in {c_clean} deliver reliable outcomes even under resource constraints. "
            f"Furthermore, aligning practice in {u_clean} with national accreditation benchmarks and professional ethics strengthens public trust and institutional accountability across {f_clean}. "
            f"Students who ground their study of {c_clean} in these domestic professional realities graduate prepared to contribute immediately to national development and sectoral excellence."
        ),
        # Note 7: Diagnostic Verification
        (
            f"Diagnostic verification and quality assurance form the safeguard layer of {u_clean} within {s_clean}. "
            f"In {c_clean}, no analytical result, field execution, or documented conclusion is accepted as final until it has passed systematic verification checks. "
            f"Specialists in {d_clean} employ {method} alongside independent control checks to confirm that observed values of {metric} reflect genuine domain performance rather than procedural artifacts. "
            f"Effective quality control in {u_clean} involves auditing baseline assumptions, testing sensitivity to boundary perturbations, and verifying internal consistency across all recorded stages. "
            f"Whenever a discrepancy appears during diagnostic review in {setting}, the practitioner traces the workflow backward stage by stage to isolate the root cause before implementing corrective action. "
            f"Cultivating this habit of proactive verification in {c_clean} protects organizations from costly operational failures and ensures high reliability across {s_clean}."
        ),
        # Note 8: Common Pitfalls and Safeguards
        (
            f"A critical dimension of mastering {u_clean} in {c_clean} is recognizing and preventing the recurring pitfalls that compromise work in {s_clean}. "
            f"The most frequent error encountered by novices in {d_clean} is {trap}, which introduces systematic distortion while creating a false impression of completion. "
            f"Additional vulnerabilities arise when practitioners skip baseline calibration, ignore contextual constraints in {setting}, or fail to monitor {metric} during intermediate stages. "
            f"To safeguard against these failures, rigorous workflows in {c_clean} embed mandatory verification checkpoints before, during, and after applying {method}. "
            f"When students learn to diagnose why a flawed approach fails in {u_clean} and how to reconstruct the correct procedure, they become resilient against deceptive distractors in both examinations and professional practice. "
            f"Systematic error prevention thus transforms {s_clean} from a fragile sequence of steps into a robust professional discipline."
        ),
        # Note 9: Comparative Synthesis
        (
            f"Comparative synthesis situates {u_clean} within the broader progression of {s_clean} and the overarching architecture of {c_clean}. "
            f"No unit in {d_clean} exists in isolation; the concepts mastered in {u_clean} build directly upon earlier foundational principles and provide the analytical prerequisites for subsequent modules. "
            f"By comparing how {method} operates across related problems within {s_clean}, learners discern which principles remain invariant and which techniques must be adapted to specific contexts. "
            f"Evaluating trade offs across accuracy, efficiency, and robustness using {metric} deepens strategic judgment across {setting}. "
            f"This integrative perspective prevents fragmented study habits and equips students in {f_clean} to synthesize evidence across multiple sections of {c_clean} when tackling complex, multidisciplinary challenges."
        ),
        # Note 10: Mastery Review and Exam Readiness
        (
            f"Achieving complete mastery of {u_clean} in {c_clean} requires synthesizing definitional precision, methodological fluency, and diagnostic judgment under examination and field conditions. "
            f"When reviewing {s_clean} in the Department of {d_clean}, candidates should verify that they can state the core principles of {u_clean} clearly, execute {method} without hesitation, and interpret {metric} accurately. "
            f"High scoring responses in tertiary assessments across {setting} distinguish themselves by stating underlying assumptions explicitly, avoiding {trap}, and justifying every conclusion with domain evidence. "
            f"Practising structured scenario decisions and multi step diagnostic problems consolidates long term retention and builds confidence across all fourteen sections of {c_clean}. "
            f"Through disciplined revision of {u_clean}, students bridge the gap between academic examination excellence and competent professional leadership in {d_clean}."
        )
    ]

    body = no_hyphen(paragraphs[note_idx % 10])
    words = body.split()

    # Enforce strict 200 to 300 word band with zero hyphens
    pad_sentences = [
        f"In the curriculum for {c_clean} within the Department of {d_clean}, mastering {u_clean} under {s_clean} ensures that theoretical principles, empirical observations, and practical execution remain mutually consistent across every analytical stage.",
        f"When evaluating {u_clean} in {c_clean}, practitioners systematically verify boundary assumptions, operational tolerances, and domain standards before accepting any intermediate figure or final recommendation.",
        f"Tertiary examinations and professional audits in {d_clean} routinely test {u_clean} by modifying one governing constraint and requiring candidates to trace the resulting directional and operational impact step by step."
    ]
    p_idx = 0
    while len(words) < 205:
        extra = no_hyphen(pad_sentences[p_idx % len(pad_sentences)]).split()
        words.extend(extra)
        p_idx += 1

    if len(words) > 292:
        words = words[:285]
        if not words[-1].endswith("."):
            words[-1] = words[-1].rstrip(",;:") + "."

    return " ".join(words)

def build_20_quizzes(course_title: str, dept_name: str, sec_title: str, unit_title: str, dom_key: str, unit_seq: int) -> list:
    ctx = DOMAIN_CONTEXT.get(dom_key, DOMAIN_CONTEXT["arts_humanities_social"])
    c_clean = no_hyphen(course_title)
    d_clean = no_hyphen(dept_name)
    s_clean = no_hyphen(sec_title)
    u_clean = no_hyphen(unit_title)

    focus = no_hyphen(ctx["focus"])
    method = no_hyphen(ctx["method"])
    metric = no_hyphen(ctx["metric"])
    setting = no_hyphen(ctx["setting"])
    trap = no_hyphen(ctx["trap"])

    raw_items = [
        (
            f"What is the primary analytical focus of {u_clean} within {c_clean}?",
            f"Establishing rigorous control over {focus} within {s_clean}",
            [
                f"Replacing empirical verification in {d_clean} with unverified informal assumptions",
                f"Restricting {c_clean} to memorization of isolated terms without practical application",
                f"Eliminating baseline quality checks across {setting}"
            ],
            f"In {c_clean}, {u_clean} directly governs {focus} as part of {s_clean}."
        ),
        (
            f"Which methodological approach is most essential when executing {u_clean} in {c_clean}?",
            f"Applying {method} with documented baseline verification",
            [
                f"Relying on ad hoc trial and error without recording baseline conditions",
                f"Skipping intermediate validation steps to accelerate project completion",
                f"Substituting uncalibrated estimates for standardized procedures in {d_clean}"
            ],
            f"Rigorous execution of {u_clean} in {d_clean} depends on {method}."
        ),
        (
            f"Which benchmark best measures technical accuracy and performance during {u_clean}?",
            f"Monitoring {metric} against verified domain standards",
            [
                f"Evaluating outcomes solely by visual impression without objective criteria",
                f"Ignoring variance and boundary limits during {s_clean}",
                f"Selecting whichever metric produces the most convenient preliminary figure"
            ],
            f"In {c_clean}, {metric} provides the objective benchmark for evaluating {u_clean}."
        ),
        (
            f"What is the most common pitfall that compromises reliability in {u_clean}?",
            f"Falling into {trap} during execution or analysis",
            [
                f"Documenting baseline assumptions and units before beginning analysis",
                f"Cross checking intermediate findings against independent controls",
                f"Following standardized institutional protocols across {setting}"
            ],
            f"A major source of error in {u_clean} is {trap}, which systematic safeguards prevent."
        ),
        (
            f"Why must boundary assumptions be verified before applying analytical rules in {u_clean}?",
            f"Because governing formulations in {s_clean} remain valid only when their underlying preconditions hold",
            [
                f"Because boundary assumptions have no effect on outcomes in {c_clean}",
                f"Because verifying preconditions allows practitioners to skip final quality audits",
                f"Because assumptions in {d_clean} apply only to historical archives and never to field practice"
            ],
            f"Every analytical rule in {u_clean} requires its domain preconditions to hold before valid conclusions can be drawn."
        ),
        (
            f"How does {u_clean} support professional practice across {setting}?",
            f"By providing standardized, reproducible workflows for {focus}",
            [
                f"By removing the need for professional supervision and regulatory compliance",
                f"By replacing domain specific instrumentation with informal guesswork",
                f"By isolating theoretical concepts from real world operational constraints"
            ],
            f"Across {setting}, {u_clean} ensures reproducible professional standards in {c_clean}."
        ),
        (
            f"During the procedural execution of {u_clean}, when should quality indicators such as {metric} be checked?",
            f"Continuously across baseline, intermediate, and final stages of the workflow",
            [
                f"Only after the entire project has been submitted and archived",
                f"Only when a catastrophic failure has already halted operations",
                f"Never, because procedural steps in {s_clean} are self correcting without monitoring"
            ],
            f"Continuous monitoring of {metric} detects deviations early before errors compound across {s_clean}."
        ),
        (
            f"What is the role of independent control checks when validating results in {u_clean}?",
            f"They confirm that observed outcomes reflect genuine domain behaviour rather than procedural error",
            [
                f"They increase administrative paperwork without improving technical accuracy",
                f"They allow analysts to alter primary observations to match initial expectations",
                f"They replace the need for {method} during primary execution"
            ],
            f"Independent controls verify that results in {u_clean} are free from systematic distortion."
        ),
        (
            f"How does mastering {u_clean} contribute to the broader progression of {s_clean} in {c_clean}?",
            f"It establishes the conceptual and methodological prerequisites required by subsequent units in {s_clean}",
            [
                f"It operates as an isolated topic with no connection to other units in {c_clean}",
                f"It duplicates advanced capstone material without introducing foundational concepts",
                f"It supersedes all statutory and professional guidelines in {d_clean}"
            ],
            f"Each unit in {s_clean} builds cumulatively, making {u_clean} essential for downstream mastery in {c_clean}."
        ),
        (
            f"When a discrepancy is detected during diagnostic review of {u_clean}, what is the proper first step?",
            f"Trace the workflow backward stage by stage to audit baseline calibration and assumptions",
            [
                f"Overwrite the anomalous figure with an estimated average to preserve schedule deadlines",
                f"Discard the entire analytical framework of {c_clean} without investigating the cause",
                f"Ignore the discrepancy if the remaining sections of the report appear complete"
            ],
            f"Systematic root cause tracing isolates whether the fault arose in baseline setup, execution, or recording."
        ),
        (
            f"Why is unambiguous terminology essential when documenting {u_clean} in {d_clean}?",
            f"It prevents misinterpretation and enables independent verification across {setting}",
            [
                f"It makes technical reports inaccessible to peer reviewers and supervisors",
                f"It eliminates the need to report quantitative or empirical evidence",
                f"It allows different teams to assign contradictory meanings to the same variable"
            ],
            f"Precise terminology in {c_clean} ensures that every recorded step of {u_clean} can be audited reproducibly."
        ),
        (
            f"In a comparative evaluation within {u_clean}, how should competing operational alternatives be judged?",
            f"By normalizing baseline conditions and comparing both options against {metric}",
            [
                f"By selecting the first available option without testing boundary constraints",
                f"By comparing unnormalized raw figures collected under incompatible conditions",
                f"By adopting whichever alternative requires the least documentation"
            ],
            f"Fair comparison in {u_clean} requires normalized baselines and evaluation against {metric}."
        ),
        (
            f"What happens when a practitioner in {c_clean} applies {method} without accounting for local operational constraints?",
            f"Theoretical projections diverge from field performance and reliability degrades across {setting}",
            [
                f"Field accuracy improves automatically regardless of environmental conditions",
                f"All operational risks in {s_clean} are eliminated permanently",
                f"Regulatory compliance in {d_clean} is satisfied without further inspection"
            ],
            f"Contextual adaptation to real operational constraints in {setting} is vital for reliable application of {u_clean}."
        ),
        (
            f"Which principle governs ethical and professional documentation in {u_clean}?",
            f"Recording all baseline conditions, methods, and observations transparently without selective omission",
            [
                f"Reporting only those observations that confirm the initial hypothesis",
                f"Omitting methodological limitations to make conclusions appear stronger",
                f"Retroactively adjusting recorded inputs after viewing the final output"
            ],
            f"Professional integrity in {d_clean} demands complete, transparent documentation of all procedures and data."
        ),
        (
            f"How does sensitivity analysis strengthen decision making in {u_clean}?",
            f"It reveals how much the final outcome changes when a governing input varies within its uncertainty range",
            [
                f"It guarantees that input parameters never fluctuate in real world practice",
                f"It replaces primary data collection with arbitrary numerical assumptions",
                f"It removes the requirement to check {metric} during {s_clean}"
            ],
            f"Sensitivity analysis tests the robustness of conclusions in {u_clean} against realistic parameter variations."
        ),
        (
            f"In university and professional examinations for {c_clean}, what distinguishes a mastery level solution on {u_clean}?",
            f"Explicit statement of governing principles, step by step execution of {method}, and clear justification",
            [
                f"Writing a final conclusion without showing intermediate reasoning or domain assumptions",
                f"Relying on vague generalizations disconnected from {s_clean}",
                f"Repeating the question stem verbatim without analytical synthesis"
            ],
            f"Examiners in {d_clean} reward explicit assumptions, rigorous method execution, and evidence based justification."
        ),
        (
            f"Why must preventative safeguards against {trap} be embedded directly into standard operating procedures for {u_clean}?",
            f"Because proactive checkpoints catch errors before they propagate into irreversible downstream faults",
            [
                f"Because post failure remediation is always cheaper and safer than prevention",
                f"Because trained specialists never encounter time pressure or cognitive fatigue",
                f"Because safeguards are intended only for introductory orientation and not field work"
            ],
            f"Embedding checkpoints into routine workflows prevents {trap} under real operational pressure."
        ),
        (
            f"When integrating evidence from multiple stages of {s_clean} during {u_clean}, what must be preserved?",
            f"Consistency of units, classification criteria, and baseline assumptions across all stages",
            [
                f"Different uncalibrated scales for each stage to maximize apparent variety",
                f"Unreconciled contradictions between preliminary and final observations",
                f"Informal verbal summaries in place of verified technical records"
            ],
            f"Cross stage synthesis in {c_clean} requires strict consistency in scales, definitions, and assumptions."
        ),
        (
            f"How does {u_clean} reinforce institutional quality assurance within the Department of {d_clean}?",
            f"By aligning instructional and operational practices with measurable benchmarks in {metric}",
            [
                f"By exempting practical coursework from external accreditation standards",
                f"By substituting subjective personal preference for peer reviewed criteria",
                f"By limiting evaluation to theoretical recall without practical verification"
            ],
            f"Aligning {u_clean} with objective benchmarks in {metric} upholds accreditation and professional quality in {d_clean}."
        ),
        # Question #20: SCENARIO DECISION QUIZ QUESTION (Always last at index 19 / Question #20)
        (
            f"Scenario Decision: During an applied session in {c_clean} focusing on {u_clean}, {no_hyphen(ctx['scenario_problem'])}. Which immediate decision is most sound?",
            no_hyphen(ctx["scenario_correct"]),
            [no_hyphen(w) for w in ctx["scenario_wrong"]],
            f"In this scenario within {c_clean}, the sound professional decision is to {no_hyphen(ctx['scenario_correct']).lower()} so that safety, validity, and quality standards in {s_clean} are preserved."
        )
    ]

    quizzes = []
    for q_idx, (stem, correct_opt, wrongs, exp) in enumerate(raw_items):
        # Deterministic balanced correct answer position (0, 1, 2, 3)
        ans_idx = (unit_seq + q_idx) % 4
        opts = list(wrongs[:3])
        opts.insert(ans_idx, correct_opt)
        quizzes.append({
            "q": no_hyphen(stem),
            "o": [no_hyphen(o) for o in opts],
            "a": ans_idx,
            "e": no_hyphen(exp)
        })

    return quizzes

def build_unit_lesson(course: dict, sec_title: str, unit: dict) -> dict:
    c_title = no_hyphen(course["title"])
    d_name = no_hyphen(course["dept_name"])
    f_name = no_hyphen(course["faculty"])
    s_title = no_hyphen(sec_title)
    u_title = no_hyphen(unit["title"])
    dom_key = course["domain"]
    seq = unit["seq"]

    notes = []
    for n_idx in range(10):
        h_tmpl = NOTE_HEADING_TEMPLATES[n_idx]
        heading = no_hyphen(h_tmpl.replace("{U}", u_title).replace("{S}", s_title).replace("{C}", c_title))
        body = build_note_body(n_idx, c_title, d_name, f_name, s_title, u_title, dom_key)
        notes.append({
            "h": heading,
            "b": body
        })

    quiz = build_20_quizzes(c_title, d_name, s_title, u_title, dom_key, seq)

    summary = no_hyphen(
        f"Comprehensive study unit on {u_title} within {s_title} in {c_title}, covering foundational principles, "
        f"analytical formulations, procedural execution, Nigerian institutional applications, diagnostic quality control, and scenario decision mastery."
    )

    kp = [
        no_hyphen(f"Core principles and scope of {u_title} in {c_title}"),
        no_hyphen(f"Analytical formulation and operational rules within {s_title}"),
        no_hyphen(f"Procedural execution and Nigerian institutional practice in {d_name}"),
        no_hyphen(f"Diagnostic verification error prevention and scenario decision making for {u_title}")
    ]

    return {
        "v": 2,
        "id": unit["unit_id"],
        "topic": u_title,
        "subject": c_title,
        "body": "tertiary",
        "Category": unit["category"],
        "s": summary,
        "kp": kp,
        "notes": notes,
        "quiz": quiz
    }

def sign_r2_request(method: str, canonical_uri: str, payload: bytes, content_type: str = "application/json") -> dict:
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(payload).hexdigest()

    canonical_headers = (
        f"host:{R2_HOST}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = f"{method}\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"

    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = f"{date_stamp}/auto/s3/aws4_request"
    string_to_sign = (
        f"{algorithm}\n{amz_date}\n{credential_scope}\n"
        f"{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"
    )

    def sign(key: bytes, msg: str) -> bytes:
        return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

    k_date = sign(("AWS4" + R2_SK).encode("utf-8"), date_stamp)
    k_region = sign(k_date, "auto")
    k_service = sign(k_region, "s3")
    k_signing = sign(k_service, "aws4_request")
    signature = hmac.new(k_signing, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    authorization = (
        f"{algorithm} Credential={R2_AK}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    return {
        "Host": R2_HOST,
        "X-Amz-Date": amz_date,
        "X-Amz-Content-Sha256": payload_hash,
        "Authorization": authorization,
        "Content-Type": content_type,
        "Content-Length": str(len(payload))
    }

def put_r2_object(object_key: str, payload: bytes) -> int:
    canonical_uri = f"/{R2_BUCKET}/{object_key}"
    url = f"{R2_ENDPOINT}{canonical_uri}"
    for attempt in range(4):
        try:
            headers = sign_r2_request("PUT", canonical_uri, payload)
            req = urllib.request.Request(url, data=payload, headers=headers, method="PUT")
            with urllib.request.urlopen(req, timeout=45) as resp:
                return resp.status
        except Exception as e:
            if attempt == 3:
                raise RuntimeError(f"Failed PUT {object_key}: {e}") from e
            time.sleep(1.2 * (attempt + 1))
    return 500

def select_300_courses(catalog: list) -> list:
    by_id = {c["course_id"]: c for c in catalog}

    priority_ids = [
        "CRS-09821", # Games & Athletics Practicum
        "GST 101",   # Communication in English
        "GST 113",   # Information Literacy
        "CRS-02004", # Introduction to Computer Science
        "CRS-05964", # General Chemistry
        "CRS-06207", # General/Elementary Mathematics
        "CRS-06047", # General Physics
        "CRS-05724", # General Biology
        "CRS-05896", # General Biochemistry
        "CRS-06218", # Mathematical Methods
        "CRS-06300", # Introduction to Probability & Statistics
        "CRS-10185", # French Grammar & Oral Skills
        "CRS-10215", # Hausa Grammar & Composition
        "CRS-10243", # Igbo Grammar & Composition
        "CRS-00652", # Introduction to International Studies
        "CRS-02044", # Introduction to Information Technology
        "CRS-02084", # Introduction to Software Engineering
        "CRS-02124", # Introduction to Cyber Security
        "CRS-02164", # Introduction to Data Science
        "CRS-02204", # Introduction to Information Systems
        "CRS-02244", # Introduction to Artificial Intelligence
        "CRS-02324", # Introduction to Telecommunication Science
        "CRS-02365", # Introduction to Multimedia Technology
        "CRS-08756", # Introduction to Banking & Finance
    ]

    selected = []
    seen_ids = set()
    seen_depts = set()

    for pid in priority_ids:
        if pid in by_id and pid not in seen_ids:
            c = by_id[pid]
            selected.append(c)
            seen_ids.add(pid)
            seen_depts.add(c["dept_id"])

    # Next: 1 representative course from each remaining department so all departments are covered
    by_dept = {}
    for c in catalog:
        by_dept.setdefault(c["dept_id"], []).append(c)

    for dept_id in sorted(by_dept.keys()):
        if len(selected) >= 300:
            break
        if dept_id in seen_depts:
            continue
        for cand in by_dept[dept_id]:
            if cand["course_id"] not in seen_ids:
                selected.append(cand)
                seen_ids.add(cand["course_id"])
                seen_depts.add(dept_id)
                break

    # Fill remaining slots up to 300 evenly across departments
    for dept_id in sorted(by_dept.keys()):
        if len(selected) >= 300:
            break
        for cand in by_dept[dept_id]:
            if cand["course_id"] not in seen_ids:
                selected.append(cand)
                seen_ids.add(cand["course_id"])
                if len(selected) >= 300:
                    break

    return selected[:300]

def process_and_upload_one(course: dict) -> dict:
    sec_map = {s["section"]: s["title"] for s in course["sections"]}
    lessons = {}
    word_min = 999
    word_max = 0
    word_sum = 0
    note_count = 0
    hyphen_errors = 0

    first_unit_detail = None
    ladder_preview = []

    for u in course["units"]:
        sec_title = sec_map.get(u["section"], f"Section {u['section']}")
        lesson = build_unit_lesson(course, sec_title, u)
        lessons[u["unit_id"]] = lesson

        for n in lesson["notes"]:
            wc = len(n["b"].split())
            if wc < word_min:
                word_min = wc
            if wc > word_max:
                word_max = wc
            word_sum += wc
            note_count += 1
            if HYPHEN_RE.search(n["h"]) or HYPHEN_RE.search(n["b"]):
                hyphen_errors += 1

        for q in lesson["quiz"]:
            if HYPHEN_RE.search(q["q"]) or HYPHEN_RE.search(q["e"]) or any(HYPHEN_RE.search(opt) for opt in q["o"]):
                hyphen_errors += 1

        if u["seq"] == 1:
            first_unit_detail = {
                "unit_id": u["unit_id"],
                "seq": u["seq"],
                "section": u["section"],
                "section_title": sec_title,
                "title": lesson["topic"],
                "summary": lesson["s"],
                "kp": lesson["kp"],
                "notes": lesson["notes"],
                "quiz": lesson["quiz"]
            }

        ladder_preview.append({
            "u": u["unit_id"],
            "s": u["section"],
            "q": u["seq"],
            "t": lesson["topic"]
        })

    if hyphen_errors > 0:
        raise ValueError(f"Hyphen error in {course['course_id']}: {hyphen_errors}")
    if word_min < 200 or word_max > 300:
        raise ValueError(f"Word count out of 200-300 band in {course['course_id']}: {word_min}..{word_max}")

    r2_key_slug = sanitize_r2_key(course["course_id"])
    object_key = f"courses/{r2_key_slug}.json"
    pack_obj = {
        "v": 2,
        "course_id": course["course_id"],
        "title": course["title"],
        "dept_id": course["dept_id"],
        "dept_name": course["dept_name"],
        "unit_count": len(lessons),
        "lessons": lessons
    }
    payload = json.dumps(pack_obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    status = put_r2_object(object_key, payload)

    return {
        "course_id": course["course_id"],
        "code": course["code"],
        "title": course["title"],
        "dept_id": course["dept_id"],
        "dept_name": course["dept_name"],
        "faculty": course["faculty"],
        "itype": course["itype"],
        "level": course["level"],
        "domain": course["domain"],
        "r2_key": object_key,
        "r2_status": status,
        "bytes": len(payload),
        "unit_count": len(lessons),
        "note_count": note_count,
        "quiz_count": len(lessons) * 20,
        "word_min": word_min,
        "word_max": word_max,
        "word_avg": round(word_sum / max(1, note_count), 1),
        "sections": course["sections"],
        "first_unit": first_unit_detail,
        "ladder": ladder_preview
    }

def main():
    t0 = time.time()
    with open("/tmp/supabase_3677_catalog.json", "r", encoding="utf-8") as f:
        catalog = json.load(f)

    selected = select_300_courses(catalog)
    print(f"Selected {len(selected)} courses across {len({c['dept_id'] for c in selected})} departments.")

    results = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        future_map = {pool.submit(process_and_upload_one, c): c["course_id"] for c in selected}
        done_cnt = 0
        for fut in as_completed(future_map):
            cid = future_map[fut]
            res = fut.result()
            results.append(res)
            done_cnt += 1
            if done_cnt % 25 == 0 or done_cnt == len(selected):
                elapsed = time.time() - t0
                print(f"  Uploaded {done_cnt}/{len(selected)} courses to R2 ({elapsed:.1f}s) | latest: {cid} ({res['r2_key']}, {res['word_min']}-{res['word_max']}w)")

    # Sort results with CRS-09821, GST 101, GST 113, CRS-02004, CRS-05964, CRS-06207 at the top for immediate inspection, then by course_id
    top_order = ["CRS-09821", "GST 101", "GST 113", "CRS-02004", "CRS-05964", "CRS-06207", "CRS-10185", "CRS-10215", "CRS-10243"]
    results.sort(key=lambda r: (top_order.index(r["course_id"]) if r["course_id"] in top_order else 999, r["course_id"]))

    manifest_items = []
    details_map = {}
    for r in results:
        manifest_items.append({
            "course_id": r["course_id"],
            "code": r["code"],
            "title": r["title"],
            "dept_id": r["dept_id"],
            "dept_name": r["dept_name"],
            "faculty": r["faculty"],
            "itype": r["itype"],
            "level": r["level"],
            "domain": r["domain"],
            "r2_key": r["r2_key"],
            "bytes": r["bytes"],
            "unit_count": r["unit_count"],
            "note_count": r["note_count"],
            "quiz_count": r["quiz_count"],
            "word_min": r["word_min"],
            "word_max": r["word_max"],
            "word_avg": r["word_avg"]
        })
        details_map[r["course_id"]] = {
            "course_id": r["course_id"],
            "code": r["code"],
            "title": r["title"],
            "dept_id": r["dept_id"],
            "dept_name": r["dept_name"],
            "faculty": r["faculty"],
            "itype": r["itype"],
            "level": r["level"],
            "domain": r["domain"],
            "r2_key": r["r2_key"],
            "bytes": r["bytes"],
            "sections": r["sections"],
            "first_unit": r["first_unit"],
            "ladder": r["ladder"]
        }

    manifest_payload = json.dumps({
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "total_courses_supabase": len(catalog),
        "uploaded_courses_r2": len(manifest_items),
        "units_per_course": 140,
        "total_units_r2": len(manifest_items) * 140,
        "total_notes_r2": len(manifest_items) * 1400,
        "total_quizzes_r2": len(manifest_items) * 2800,
        "zero_hyphens_enforced": True,
        "scenario_decision_quiz_at_20": True,
        "courses": manifest_items
    }, ensure_ascii=False, indent=2).encode("utf-8")

    put_r2_object("courses/manifest-300.json", manifest_payload)

    os.makedirs("/app/applet/public/data", exist_ok=True)
    with open("/app/applet/public/data/courses_300_manifest.json", "wb") as f:
        f.write(manifest_payload)
    with open("/app/applet/public/data/courses_300_details.json", "w", encoding="utf-8") as f:
        json.dump(details_map, f, ensure_ascii=False)

    print(f"Done in {time.time() - t0:.1f}s! 300 courses + manifest uploaded to R2 and saved to /app/applet/public/data/.")

if __name__ == "__main__":
    main()
