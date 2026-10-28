import pg from "/app/applet/node_modules/pg/lib/index.js";
import fs from "fs";

const DSN = "postgresql://postgres.zfxrmcwdnmmxjawmsiyp:Stephen2474life%23@aws-1-eu-west-3.pooler.supabase.com:5432/postgres";

export function cleanNoHyphen(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "and")
    .replace(/[\u002D\u2010\u2011\u2012\u2013\u2014\u2015\u2212]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function routeDomain(course) {
  const title = (course.title || "").toLowerCase();
  const dept = (course.dept_name || "").toLowerCase();
  const fac = (course.faculty || "").toLowerCase();
  const blob = `${title} ${dept} ${fac}`;

  // 1. Sports, Physical & Health Education, Games & Athletics, Human Kinetics
  if (/\b(games|athletics|sports?|physical\s*(and|&)\s*health|human\s*kinetics|kinesiol|coaching|recreation|pe\s+practicum|fitness|gymnastics)\b/i.test(blob)) {
    return "sports_phe";
  }
  // 2. Information Literacy & Library Science
  if (/\b(information\s*literacy|library|archival|bibliograph|cataloguing|indexing|documentation)\b/i.test(blob)) {
    return "info_literacy";
  }
  // 3. World & African Languages (French, Hausa, Igbo, Yoruba, Arabic, Chinese, etc.)
  if (/\b(french|hausa|igbo|yoruba|arabic|mandarin|chinese|german|spanish|swahili|portuguese|edo|efik|ibibio|kanuri|fulfulde|tiv|nupe|urhobo|ijaw)\b/i.test(blob)) {
    return "world_african_lang";
  }
  // 4. English & Communication Skills
  if (/\b(communication\s+in\s+english|use\s+of\s+english|english\s+grammar|phonetics|phonology|academic\s+writing|report\s+writing|public\s+speaking|reading\s*(and|&)\s*comprehension|minute\s*writing|summary\s+writing|oral\s+english|business\s*(and|&)\s*professional\s+communication|communication\s+skills|language\s*(and|&)\s*academic\s+discourse)\b/i.test(title) || /\b(english)\b/i.test(dept)) {
    return "english_comm";
  }
  // 5. Computer Science, Software, IT, AI, Cyber, Data Science
  if (/\b(computer|computing|software|programming|algorithm|data\s+structure|operating\s+system|database|cyber\s*security|artificial\s+intelligence|machine\s+learning|data\s+science|information\s+system|information\s+technology|multimedia|network|web\s+application|mobile\s+application|cloud\s+computing|compiler|automata|cryptograph|telecommunication\s+science|digital\s+logic|ict)\b/i.test(blob)) {
    return "computer_science";
  }
  // 6. Mathematics & Statistics
  if (/\b(mathematic|calculus|algebra|trigonometr|geometry|topology|real\s+analysis|complex\s+analysis|differential\s+equation|numerical\s+analysis|statistics|statistical|probability|biometrics|actuarial|operations\s+research|quantitative\s+methods)\b/i.test(title) || /\b(mathematics|statistics)\b/i.test(dept)) {
    return "math_stats";
  }
  // 7. Pure & Applied Chemistry
  if (/\b(chemistry|chemical\s+bonding|organic\s+chemistry|inorganic\s+chemistry|physical\s+chemistry|analytical\s+chemistry|industrial\s+chemistry|polymer\s+chemistry|medicinal\s+chemistry|spectroscop|stoichiometr)\b/i.test(title) || /\b(chemistry)\b/i.test(dept)) {
    return "chemistry_pure";
  }
  // 8. Pure & Applied Physics
  if (/\b(physics|electromagnet|thermodynamics|optics|quantum|nuclear\s+physics|solid\s+state|astrophysics|geophysics|acoustics|relativity|semiconductor)\b/i.test(title) || /\b(physics)\b/i.test(dept)) {
    return "physics_pure";
  }
  // 9. Biological Sciences & Biochemistry
  if (/\b(biology|biological|biochemistry|botany|zoology|microbiology|genetics|ecology|mycology|parasitology|entomology|physiology|cell\s+biology|molecular\s+biology|biotechnology|marine\s+biology|science\s+laboratory)\b/i.test(blob)) {
    return "bio_biochem";
  }
  // 10. Engineering & Technology
  if (/\b(engineering|mechatronic|metallurg|structural|geotechnical|hydraulics|thermFluid|power\s+system|control\s+system|chemical\s+process|unit\s+operation|petroleum|reservoir|drilling|foundry|welding|automotive|aeronautic|foundry|ceramic|polymer\s+tech|wood\s+products|textile|leather)\b/i.test(blob)) {
    return "engineering_tech";
  }
  // 11. Medicine, Nursing, Pharmacy & Allied Health
  if (/\b(medicine|medical|surgery|surgical|nursing|midwifery|pharmac|anatomy|pathology|epidemiology|public\s+health|radiography|physiotherapy|optometry|dentistry|dental|nutrition|dietetics|veterinary|clinical|paediatric|obstetric|gynaecolog|anaesthesia|psychiatry|community\s+health|environmental\s+health|health\s+information)\b/i.test(blob)) {
    return "medicine_health";
  }
  // 12. Agriculture, Forestry, Fisheries & Food Science
  if (/\b(agricultur|agronom|crop|soil\s+science|animal\s+science|animal\s+production|poultry|fisheries|aquaculture|forestry|wildlife|horticultur|pasture|food\s+science|food\s+technology|postharvest|agribusiness)\b/i.test(blob)) {
    return "agriculture_food";
  }
  // 13. Law, Legal Studies & Criminology
  if (/\b(law|legal|jurisprudence|constitutional|contract|tort|criminal\s+justice|criminology|arbitration|evidence|conveyancing|sharia|islamic\s+law|customary\s+law)\b/i.test(blob)) {
    return "law_criminology";
  }
  // 14. Accounting, Banking, Finance, Taxation & Economics
  if (/\b(accounting|accountancy|auditing|taxation|banking|finance|financial|insurance|econom|microeconom|macroeconom|econometrics|public\s+finance)\b/i.test(blob)) {
    return "accounting_finance_econ";
  }
  // 15. Business, Management, Entrepreneurship, Marketing, Hospitality
  if (/\b(business|management|entrepreneurship|marketing|human\s+resource|public\s+administration|cooperative|logistics|supply\s+chain|procurement|purchasing|office\s+technology|secretarial|hospitality|tourism|hotel|industrial\s+training|siwes|industrial\s+attachment)\b/i.test(blob)) {
    return "business_management";
  }
  // 16. Environment, Architecture, Surveying, Urban Planning, Geography, Geology
  if (/\b(architecture|architectural|urban|regional\s+planning|estate\s+management|surveying|geoinformatics|quantity\s+surveying|building|geography|environmental|meteorology|geology|earth\s+science|cartography|remote\s+sensing|climate\s+change)\b/i.test(blob)) {
    return "environment_design";
  }
  // 17. Education, Curriculum & Guidance/Counselling
  if (/\b(education|educational|curriculum|pedagogy|teaching|counselling|guidance|early\s+childhood|special\s+needs|adult\s+education|classroom)\b/i.test(blob)) {
    return "education_counselling";
  }
  // 18. Arts, Humanities & Social Sciences
  return "arts_humanities_social";
}

const DOMAIN_BLUEPRINTS = {
  sports_phe: {
    sections: [
      "Foundational Principles and Historical Evolution of {C}",
      "Functional Anatomy and Exercise Physiology in {C}",
      "Track Sprint Hurdle and Relay Mechanics in {C}",
      "Middle and Long Distance Endurance Conditioning in {C}",
      "Field Jumping and Vaulting Biomechanics in {C}",
      "Field Throwing Events Technique and Power in {C}",
      "Team Invasion Ball Games Tactics and Skills in {C}",
      "Court Net and Wall Ball Games Execution in {C}",
      "Racket and Striking Games Technique in {C}",
      "Motor Learning Skill Acquisition and Drills in {C}",
      "Officiating Rules Scoring and Match Governance in {C}",
      "Sports Injury Prevention First Aid and Rehabilitation in {C}",
      "Athletic Facility Layout Equipment Calibration and Safety in {C}",
      "Tournament Administration Performance Evaluation and Mastery in {C}"
    ],
    unitPatterns: [
      "Core concepts terminology and institutional scope of {S}",
      "Biomechanical posture movement phases and force generation in {S}",
      "Standard rules dimensions and regulatory specifications for {S}",
      "Progressive skill drills coordination and footwork routines in {S}",
      "Energy systems conditioning and physiological adaptation during {S}",
      "Tactical formations spatial awareness and decision making in {S}",
      "Officiating signals foul adjudication and scorekeeping in {S}",
      "Equipment selection surface inspection and safety compliance in {S}",
      "Common performance errors video diagnostics and corrective coaching in {S}",
      "Practical field assessment grading rubrics and mastery benchmarking in {S}"
    ]
  },
  info_literacy: {
    sections: [
      "Conceptual Foundations and Scope of {C}",
      "Typology of Academic Primary Secondary and Tertiary Sources in {C}",
      "Library Classification Systems and Cataloguing Architecture in {C}",
      "Boolean Logic Search Syntax and Query Formulation in {C}",
      "Scholarly Databases Digital Repositories and Open Access in {C}",
      "Critical Source Evaluation Authority Accuracy and Objectivity in {C}",
      "Reference Management Citation Styles and Bibliographic Control in {C}",
      "Academic Integrity Plagiarism Prevention and Fair Use in {C}",
      "Digital Media Verification Fact Checking and Source Provenance in {C}",
      "Research Data Organization Metadata and Archival Preservation in {C}",
      "Quantitative and Qualitative Evidence Synthesis in {C}",
      "Institutional Repositories Nigerian National Archives and Policy Portals in {C}",
      "Information Security Privacy Ethics and Intellectual Property in {C}",
      "Comprehensive Literature Review Design and Research Capstone in {C}"
    ],
    unitPatterns: [
      "Fundamental definitions principles and analytical standards of {S}",
      "Structural taxonomy classification rules and metadata schema in {S}",
      "Precision search strategies query refinement and filtering for {S}",
      "Source credibility verification bias detection and authority checks in {S}",
      "Documentation conventions citation formatting and indexing in {S}",
      "Digital platform workflows database navigation and retrieval in {S}",
      "Ethical governance copyright compliance and attribution rules in {S}",
      "Comparative synthesis cross source triangulation and note structuring in {S}",
      "Institutional case workflows in Nigerian university libraries for {S}",
      "Diagnostic evaluation practical audit and mastery verification in {S}"
    ]
  },
  world_african_lang: {
    sections: [
      "Sound System Phonetics and Orthographic Conventions of {C}",
      "Tonal Patterns Prosody and Spoken Articulation in {C}",
      "Nominal Morphology Noun Classes Gender and Number in {C}",
      "Pronouns Determiners and Agreement Concord in {C}",
      "Verbal Morphology Tense Aspect and Mood Conjugation in {C}",
      "Clause Structure Word Order and Sentence Syntax in {C}",
      "Lexical Semantics Idioms Proverbs and Figurative Expression in {C}",
      "Listening Comprehension and Oral Dialogue Fluency in {C}",
      "Reading Comprehension and Textual Analysis in {C}",
      "Bidirectional Translation Principles and Lexical Equivalence in {C}",
      "Descriptive Narrative and Expository Composition in {C}",
      "Formal Correspondence Registers and Official Discourse in {C}",
      "Oral Literature Cultural Context and Sociolinguistics of {C}",
      "Comprehensive Editing Oral Proficiency and Examination Mastery in {C}"
    ],
    unitPatterns: [
      "Phonemic inventory orthography and pronunciation standards in {S}",
      "Morphological inflection derivation and word structure rules in {S}",
      "Syntactic arrangement grammatical agreement and clause patterns in {S}",
      "Core vocabulary thematic lexicons and contextual usage in {S}",
      "Oral dialogue practice conversational turn taking and intonation in {S}",
      "Idiomatic usage cultural proverbs and pragmatic appropriateness in {S}",
      "Passage reading comprehension inference and structural summary in {S}",
      "Translation accuracy semantic equivalence and register shifts in {S}",
      "Guided composition sentence combining and paragraph coherence in {S}",
      "Error diagnosis grammatical proofreading and proficiency drills in {S}"
    ]
  },
  english_comm: {
    sections: [
      "Phonetics Phonology and Spoken Articulation in {C}",
      "Stress Intonation and Rhythm in {C}",
      "Morphology Word Formation and Lexical Development in {C}",
      "Word Classes Phrases and Clause Architecture in {C}",
      "Sentence Structure Concord and Grammatical Agreement in {C}",
      "Tense Aspect Modality and Voice Transformation in {C}",
      "Reading Comprehension Critical Inference and Retention in {C}",
      "Summary Writing Paraphrasing and Information Condensation in {C}",
      "Paragraph Unity Coherence and Expository Essay Composition in {C}",
      "Argumentative Analytical and Persuasive Writing in {C}",
      "Official Correspondence Memoranda Reports and Minutes in {C}",
      "Professional Registers Academic Style and Documentation in {C}",
      "Public Speaking Oral Presentation and Listening Skills in {C}",
      "Comprehensive Editing Proofreading and Discourse Mastery in {C}"
    ],
    unitPatterns: [
      "Foundational linguistic principles and communicative scope of {S}",
      "Structural rules grammatical patterns and usage conventions in {S}",
      "Lexical precision collocation and register selection within {S}",
      "Analytical reading textual dissection and main idea extraction in {S}",
      "Sentence construction syntactic variety and transition flow in {S}",
      "Common usage errors ambiguity elimination and stylistic repair in {S}",
      "Audience adaptation tone calibration and rhetorical clarity in {S}",
      "Formal formatting structural organization and institutional standards in {S}",
      "Practical application in Nigerian academic and workplace contexts for {S}",
      "Comprehensive revision diagnostic editing and examination mastery in {S}"
    ]
  },
  computer_science: {
    sections: [
      "Computational Foundations and Architectural Scope of {C}",
      "Data Representation Abstraction and Type Systems in {C}",
      "Algorithmic Logic Control Structures and Modular Design in {C}",
      "Linear and Hierarchical Data Structures in {C}",
      "Asymptotic Complexity Time and Space Efficiency in {C}",
      "System Architecture Memory Management and Execution Models in {C}",
      "Concurrency Synchronization and Parallel Processing in {C}",
      "Relational Data Modelling Query Processing and Storage in {C}",
      "Networking Protocols Distributed Communication and APIs in {C}",
      "Software Engineering Lifecycle Specification and Architecture in {C}",
      "Defensive Programming Cryptography and System Security in {C}",
      "Verification Unit Testing Debugging and Static Analysis in {C}",
      "Performance Profiling Optimization and Scalability in {C}",
      "Production Deployment Reliability and Capstone Synthesis in {C}"
    ],
    unitPatterns: [
      "Formal definitions architectural models and core invariants of {S}",
      "Algorithmic step by step trace and state transition logic in {S}",
      "Data layout memory representation and pointer or index addressing in {S}",
      "Asymptotic runtime and memory complexity derivation for {S}",
      "Modular interface design parameterization and encapsulation in {S}",
      "Boundary conditions edge cases and exception handling in {S}",
      "Security vulnerabilities threat vectors and defensive validation in {S}",
      "Automated test specification assertions and verification for {S}",
      "Throughput latency benchmarking and engineering optimization in {S}",
      "Production case architecture and system design trade offs in {S}"
    ]
  },
  math_stats: {
    sections: [
      "Axiomatic Foundations Sets and Number Systems in {C}",
      "Algebraic Structures Equations and Inequalities in {C}",
      "Functions Mappings and Analytic Geometry in {C}",
      "Sequences Series and Mathematical Induction in {C}",
      "Limits Continuity and Differential Calculus in {C}",
      "Applications of Derivatives Optimization and Rates in {C}",
      "Riemann Integration and Methods of Integration in {C}",
      "Ordinary and Partial Differential Equations in {C}",
      "Vectors Matrices and Linear Algebra Transformations in {C}",
      "Combinatorics Sample Spaces and Probability Axioms in {C}",
      "Discrete and Continuous Probability Distributions in {C}",
      "Sampling Theory Point Estimation and Confidence Intervals in {C}",
      "Hypothesis Testing ANOVA and Regression Modelling in {C}",
      "Numerical Approximation Mathematical Modelling and Problem Mastery in {C}"
    ],
    unitPatterns: [
      "Definitions axioms and formal mathematical notation in {S}",
      "Fundamental theorems proof structure and necessary conditions in {S}",
      "Step by step algebraic and analytical derivation techniques in {S}",
      "Geometric and graphical interpretation of behaviour in {S}",
      "Boundary values convergence criteria and domain constraints in {S}",
      "Worked quantitative problem solving and parameter sensitivity in {S}",
      "Computational algorithms and numerical approximation errors in {S}",
      "Statistical and physical modelling applications of {S}",
      "Diagnostic verification of solutions and common algebraic traps in {S}",
      "Advanced synthesis multi step proofs and examination mastery in {S}"
    ]
  },
  chemistry_pure: {
    sections: [
      "Atomic Structure Quantum Numbers and Periodicity in {C}",
      "Ionic Covalent and Metallic Chemical Bonding in {C}",
      "Molecular Geometry Hybridization and Intermolecular Forces in {C}",
      "Stoichiometry Mole Concept and Volumetric Calculations in {C}",
      "Gases Liquids Solids and Phase Equilibria in {C}",
      "Chemical Thermodynamics Enthalpy Entropy and Free Energy in {C}",
      "Chemical Kinetics Rate Laws and Reaction Mechanisms in {C}",
      "Chemical Equilibrium Le Chatelier Principle and Phase Systems in {C}",
      "Acids Bases Buffers and Solubility Equilibria in {C}",
      "Oxidation Reduction Reactions and Electrochemistry in {C}",
      "Inorganic Coordination and Transition Element Chemistry in {C}",
      "Organic Functional Groups Stereochemistry and Reactions in {C}",
      "Quantitative Titrimetric and Spectroscopic Analysis in {C}",
      "Chemical Laboratory Safety Industrial Processes and Synthesis in {C}"
    ],
    unitPatterns: [
      "Fundamental chemical principles definitions and IUPAC nomenclature in {S}",
      "Electronic and molecular structure interactions governing {S}",
      "Balanced chemical equations and stoichiometric mole calculations in {S}",
      "Thermodynamic driving forces and equilibrium constants in {S}",
      "Reaction rate dependencies activation energy and catalysis in {S}",
      "Solution behaviour pH calculation and ionic strength effects in {S}",
      "Analytical instrumentation spectral interpretation and titration in {S}",
      "Laboratory reagent handling hazard control and experimental technique in {S}",
      "Industrial chemical manufacturing and quality control applications of {S}",
      "Comprehensive quantitative problem solving and mastery verification in {S}"
    ]
  },
  physics_pure: {
    sections: [
      "Physical Quantities Dimensional Analysis and Vector Algebra in {C}",
      "Kinematics in One Two and Three Dimensions in {C}",
      "Newtonian Dynamics Force Work Energy and Momentum in {C}",
      "Rotational Mechanics Rigid Bodies and Gravitation in {C}",
      "Elasticity Hydrostatics and Fluid Dynamics in {C}",
      "Temperature Calorimetry and Laws of Thermodynamics in {C}",
      "Simple Harmonic Motion Mechanical Waves and Acoustics in {C}",
      "Geometrical Optics Reflection Refraction and Optical Instruments in {C}",
      "Wave Optics Interference Diffraction and Polarization in {C}",
      "Electrostatics Electric Fields Gauss Law and Capacitance in {C}",
      "Direct Current Circuits Kirchhoff Laws and Electrical Measurements in {C}",
      "Magnetism Electromagnetic Induction and Alternating Current Circuits in {C}",
      "Quantum Physics Atomic Spectra and Semiconductor Devices in {C}",
      "Nuclear Physics Radioactivity and Experimental Physics Mastery in {C}"
    ],
    unitPatterns: [
      "Physical definitions SI units and vector formulation of {S}",
      "Governing physical laws differential relations and conservation principles in {S}",
      "Free body diagrams field geometry and boundary conditions in {S}",
      "Mathematical derivation of equations of motion and energy balance in {S}",
      "Quantitative numerical problem solving and order of magnitude checks in {S}",
      "Experimental apparatus calibration uncertainty propagation and plotting in {S}",
      "Limiting regimes resonance behaviour and stability criteria in {S}",
      "Engineering and technological device applications of {S}",
      "Diagnosis of conceptual misconceptions and sign convention errors in {S}",
      "Multi concept physics problem synthesis and examination mastery in {S}"
    ]
  },
  bio_biochem: {
    sections: [
      "Cellular Architecture Organelles and Biomembranes in {C}",
      "Structure and Function of Carbohydrates Lipids and Proteins in {C}",
      "Enzymology Kinetics Cofactors and Metabolic Regulation in {C}",
      "Bioenergetics Cellular Respiration and Photosynthesis in {C}",
      "Nucleic Acids DNA Replication Transcription and Translation in {C}",
      "Mendelian Inheritance Chromosomal Mapping and Population Genetics in {C}",
      "Microbial Diversity Growth Kinetics and Host Pathogen Interactions in {C}",
      "Plant Anatomy Water Transport Mineral Nutrition and Reproduction in {C}",
      "Animal Physiology Homeostasis Circulation Respiration and Excretion in {C}",
      "Neurobiology Endocrine Signaling and Immune Defense in {C}",
      "Systematics Phylogenetics and Evolutionary Mechanisms in {C}",
      "Ecology Energy Flow Biogeochemical Cycles and Conservation in {C}",
      "Microscopy Spectrophotometry Chromatography and Bioassays in {C}",
      "Biostatistics Experimental Design Biosafety and Research Synthesis in {C}"
    ],
    unitPatterns: [
      "Structural organization biological nomenclature and classification in {S}",
      "Biochemical pathways enzymatic catalysis and molecular mechanisms in {S}",
      "Homeostatic regulation physiological feedback and transport dynamics in {S}",
      "Genetic inheritance expression control and phenotypic variation in {S}",
      "Ecological adaptation trophic interaction and environmental response in {S}",
      "Laboratory microscopy staining extraction and assay protocols for {S}",
      "Quantitative data logging serial dilution and biostatistical testing in {S}",
      "Pathological disruption diagnostic indicators and preventive control in {S}",
      "Biotechnological agricultural and tropical biodiversity applications of {S}",
      "Experimental interpretation case synthesis and mastery evaluation in {S}"
    ]
  },
  engineering_tech: {
    sections: [
      "Engineering Principles Codes Standards and Governing Equations in {C}",
      "Engineering Materials Stress Strain and Constitutive Behaviour in {C}",
      "Conservation of Mass Momentum and Energy Balances in {C}",
      "Thermodynamic Fluid and Transport Phenomena in {C}",
      "System Modelling Load Analysis and Dimensional Sizing in {C}",
      "Mechanical Electrical and Process Component Design in {C}",
      "Instrumentation Sensors Actuators and Feedback Control in {C}",
      "CAD Simulation Numerical Finite Element and Network Analysis in {C}",
      "Manufacturing Fabrication Construction and Workshop Processes in {C}",
      "Quality Control Non Destructive Testing and Metrology in {C}",
      "Reliability Engineering Fault Diagnosis and Preventive Maintenance in {C}",
      "Health Safety Environment and Regulatory Compliance in {C}",
      "Engineering Economics Project Costing and Procurement in {C}",
      "Plant Commissioning Field Testing and Capstone Engineering Design in {C}"
    ],
    unitPatterns: [
      "Governing physical laws engineering assumptions and design codes for {S}",
      "Free body control volume and circuit schematic formulation in {S}",
      "Analytical sizing load calculation and safety factor selection in {S}",
      "Material selection fatigue creep and corrosion resistance in {S}",
      "Steady state and transient dynamic response calculations in {S}",
      "Instrumentation calibration signal conditioning and tolerance verification in {S}",
      "Fabrication assembly sequences and quality assurance checks in {S}",
      "Failure mode effects analysis troubleshooting and maintenance in {S}",
      "Nigerian COREN and SON regulatory compliance and costing for {S}",
      "Integrated design verification sensitivity audit and mastery review in {S}"
    ]
  },
  medicine_health: {
    sections: [
      "Anatomical and Physiological Foundations of {C}",
      "Cellular Pathology Etiology and Disease Mechanisms in {C}",
      "Clinical History Taking Physical Examination and Triage in {C}",
      "Diagnostic Laboratory Hematology and Biochemical Profiling in {C}",
      "Diagnostic Imaging Physiological Monitoring and Biomarkers in {C}",
      "Pharmacokinetics Pharmacodynamics and Rational Prescribing in {C}",
      "Clinical Care Pathways Nursing Interventions and Patient Monitoring in {C}",
      "Asepsis Sterilization Infection Prevention and Clinical Safety in {C}",
      "Maternal Child Reproductive and Nutritional Health in {C}",
      "Communicable and Non Communicable Disease Management in {C}",
      "Epidemiological Surveillance Biostatistics and Outbreak Control in {C}",
      "Emergency Resuscitation Stabilization and Referral Systems in {C}",
      "Medical Ethics Informed Consent Confidentiality and Health Law in {C}",
      "Rehabilitation Multidisciplinary Audit and Clinical Case Mastery in {C}"
    ],
    unitPatterns: [
      "Anatomical structures physiological baselines and homeostasis in {S}",
      "Etiological agents pathophysiology and clinical manifestations of {S}",
      "Patient history red flag identification and physical examination in {S}",
      "Diagnostic test selection reference ranges and result interpretation in {S}",
      "Evidence based therapeutic and pharmacological protocols for {S}",
      "Dosage calculation administration routes and adverse effect monitoring in {S}",
      "Infection control aseptic technique and clinical documentation in {S}",
      "Patient education preventive counselling and community follow up in {S}",
      "Primary secondary and tertiary healthcare referral workflows in {S}",
      "Clinical scenario decision making audit and competency assessment in {S}"
    ]
  },
  agriculture_food: {
    sections: [
      "Agroecological Zones Climate and Production Systems in {C}",
      "Soil Physics Chemistry Fertility and Conservation in {C}",
      "Genetics Germplasm Selection and Breeding Programmes in {C}",
      "Seed Science Propagation Nursery and Establishment Practices in {C}",
      "Physiology Nutrition and Water Management in {C}",
      "Agronomic Husbandry Housing and Feeding Management in {C}",
      "Integrated Pest Disease Weed and Biosecurity Management in {C}",
      "Farm Mechanization Irrigation Structures and Power Systems in {C}",
      "Harvesting Maturity Indices and Postharvest Physiology in {C}",
      "Food Processing Preservation Packaging and Cold Chain in {C}",
      "Quality Assurance Proximate Analysis and Food Safety Standards in {C}",
      "Farm Records Production Economics and Agribusiness Marketing in {C}",
      "Agricultural Extension Rural Sociology and Farmer Adoption in {C}",
      "Climate Smart Agriculture Sustainability and Practical Field Mastery in {C}"
    ],
    unitPatterns: [
      "Biological and environmental requirements governing {S}",
      "Field site selection soil or water testing and preparation in {S}",
      "Input calculation stocking or seeding rate and nutrient dosing in {S}",
      "Routine cultural husbandry and growth monitoring protocols in {S}",
      "Pest pathogen diagnosis threshold scouting and biosecurity in {S}",
      "Harvest timing yield estimation and loss reduction techniques in {S}",
      "Processing preservation moisture control and quality grading in {S}",
      "Enterprise budgeting cost return analysis and value chain marketing in {S}",
      "Extension communication and Nigerian agroecological adaptation of {S}",
      "Practical field trial design randomized block analysis and mastery in {S}"
    ]
  },
  law_criminology: {
    sections: [
      "Historical Evolution Jurisprudential Foundations and Sources of {C}",
      "Constitutional Framework Hierarchy of Courts and Jurisdiction in {C}",
      "Statutory Interpretation Legal Maxims and Judicial Precedent in {C}",
      "Substantive Elements Legal Rights and Correlative Duties in {C}",
      "Formation Capacity Validity and Enforceability in {C}",
      "Liability Mens Rea Actus Reus Fault and Causation in {C}",
      "Statutory Defences Exemptions and Mitigating Circumstances in {C}",
      "Law of Evidence Admissibility Burden and Standard of Proof in {C}",
      "Civil and Criminal Procedure Pleadings and Trial Advocacy in {C}",
      "Equitable Remedies Damages Injunctions and Restitution in {C}",
      "Regulatory Agencies Compliance Enforcement and Administrative Review in {C}",
      "Alternative Dispute Resolution Arbitration Conciliation and Mediation in {C}",
      "Comparative Customary Islamic and International Perspectives in {C}",
      "Legal Drafting Case Brief Analysis and Professional Ethics in {C}"
    ],
    unitPatterns: [
      "Jurisprudential definitions statutory sources and scope of {S}",
      "Constitutional provisions and enabling legislation governing {S}",
      "Landmark judicial precedents ratio decidendi and obiter dicta in {S}",
      "Essential legal elements tests of liability and proof requirements in {S}",
      "Statutory exceptions defences and limitation periods applicable to {S}",
      "Evidentiary admissibility documentary proof and witness examination in {S}",
      "Procedural filing jurisdiction rules and court orders in {S}",
      "Available legal and equitable remedies quantum of damages in {S}",
      "Legal drafting clauses statutory notices and ethical duties in {S}",
      "IRAC problem question analysis and appellate case synthesis in {S}"
    ]
  },
  accounting_finance_econ: {
    sections: [
      "Conceptual Framework Regulatory Standards and Principles of {C}",
      "Source Documents Double Entry Bookkeeping and Trial Balance in {C}",
      "Accruals Prepayments Depreciation and Valuation Adjustments in {C}",
      "Financial Statements Statement of Profit or Loss and Financial Position in {C}",
      "Cash Flow Statements Ratio Analysis and Financial Interpretation in {C}",
      "Cost Classification Overhead Absorption and Marginal Costing in {C}",
      "Budgetary Control Standard Costing and Variance Reconciliation in {C}",
      "Time Value of Money Capital Budgeting and Investment Appraisal in {C}",
      "Working Capital Portfolio Risk and Corporate Capital Structure in {C}",
      "Microeconomic Demand Supply Elasticity and Market Structures in {C}",
      "Macroeconomic National Income Inflation Fiscal and Monetary Policy in {C}",
      "Taxation Computation Statutory Allowances and Revenue Compliance in {C}",
      "Internal Control Audit Evidence Vouching and Assurance Standards in {C}",
      "Quantitative Econometric Financial Modelling and Capstone Mastery in {C}"
    ],
    unitPatterns: [
      "Regulatory framework IFRS or economic axioms and definitions in {S}",
      "Recognition measurement and classification criteria for {S}",
      "Double entry ledger posting and schedule computation in {S}",
      "Quantitative formula derivation and financial schedule preparation in {S}",
      "Variance sensitivity and financial ratio interpretation for {S}",
      "Internal control checks audit trail verification and reconciliation in {S}",
      "Statutory compliance Nigerian tax and CBN regulatory rules in {S}",
      "Risk return trade offs and capital allocation decisions in {S}",
      "Detection of computational errors and misstatement adjustments in {S}",
      "Comprehensive case computation financial reporting and exam mastery in {S}"
    ]
  },
  business_management: {
    sections: [
      "Foundational Theories Evolution and Strategic Scope of {C}",
      "Organizational Structure Governance and Environmental Scanning in {C}",
      "Strategic Planning Forecasting and Executive Decision Making in {C}",
      "Entrepreneurial Opportunity Identification and Venture Feasibility in {C}",
      "Market Segmentation Consumer Behaviour and Value Proposition in {C}",
      "Product Pricing Distribution and Integrated Marketing Communication in {C}",
      "Operations Management Capacity Planning and Quality Assurance in {C}",
      "Procurement Inventory Control Logistics and Supply Chain Management in {C}",
      "Human Resource Planning Recruitment Training and Performance Appraisal in {C}",
      "Leadership Motivation Team Dynamics and Organizational Culture in {C}",
      "Managerial Communication Negotiation and Conflict Resolution in {C}",
      "Business Finance Working Capital Budgeting and Cost Control in {C}",
      "Corporate Social Responsibility Ethics Labour Law and CAMA Compliance in {C}",
      "Digital Transformation Key Performance Indicators and Case Mastery in {C}"
    ],
    unitPatterns: [
      "Core management concepts theoretical models and scope of {S}",
      "Environmental scanning SWOT and PESTEL diagnostic analysis in {S}",
      "Strategic objective setting KPI definition and resource allocation in {S}",
      "Operational workflow design scheduling and bottleneck removal in {S}",
      "Quantitative decision trees break even and cost benefit metrics in {S}",
      "Stakeholder communication negotiation and team coordination in {S}",
      "Risk identification internal controls and contingency planning in {S}",
      "Nigerian regulatory compliance labour law and CAMA governance in {S}",
      "Performance audit service quality metrics and continuous improvement in {S}",
      "Executive case study analysis and strategic decision mastery in {S}"
    ]
  },
  environment_design: {
    sections: [
      "Spatial Physical and Environmental Foundations of {C}",
      "Geodetic Surveying Levelling Traversing and Site Measurement in {C}",
      "Cartography Photogrammetry Remote Sensing and GIS in {C}",
      "Geomorphology Climatology Hydrology and Environmental Processes in {C}",
      "Architectural and Urban Spatial Design Principles in {C}",
      "Construction Materials Structural Systems and Building Services in {C}",
      "Measurement of Building Works Taking Off and Bills of Quantities in {C}",
      "Land Economics Property Valuation and Estate Feasibility in {C}",
      "Urban and Regional Planning Zoning and Development Control in {C}",
      "Environmental Impact Assessment Pollution Control and Waste Management in {C}",
      "Housing Delivery Infrastructure Provision and Urban Regeneration in {C}",
      "Building Codes Land Use Act and Statutory Regulation in {C}",
      "Construction Project Management Tendering and Contract Administration in {C}",
      "Sustainable Design Climate Resilience and Studio Field Capstone in {C}"
    ],
    unitPatterns: [
      "Fundamental spatial environmental principles and definitions in {S}",
      "Field survey reconnaissance instrument setup and data booking in {S}",
      "Spatial coordinates scale conversion and cartographic plotting in {S}",
      "Design brief analysis anthropometrics and functional zoning in {S}",
      "Material specification structural load paths and service integration in {S}",
      "Quantity measurement cost estimation and valuation calculation in {S}",
      "Environmental baseline auditing and impact mitigation in {S}",
      "Statutory planning standards Nigerian Land Use Act and building codes in {S}",
      "Contract documentation tendering and site supervision in {S}",
      "Studio design critique field verification and professional mastery in {S}"
    ]
  },
  education_counselling: {
    sections: [
      "Philosophical Historical and Sociological Foundations of {C}",
      "Developmental Psychology Cognitive Growth and Individual Differences in {C}",
      "Theories of Learning Motivation and Classroom Behaviour in {C}",
      "Curriculum Design Taxonomy of Objectives and Scheme of Work in {C}",
      "Pedagogical Methods Lesson Planning and Microteaching in {C}",
      "Instructional Media Educational Technology and Digital Resources in {C}",
      "Guidance and Counselling Theories Career Development and Ethics in {C}",
      "Psychological Testing Vocational Inventory and Client Interviewing in {C}",
      "Classroom Management Discipline and Inclusive Special Education in {C}",
      "Test Construction Continuous Assessment and Marking Schemes in {C}",
      "Psychometrics Item Analysis Reliability and Validity in {C}",
      "Educational Administration School Supervision and Leadership in {C}",
      "National Policy on Education TRCN Standards and Quality Assurance in {C}",
      "Educational Action Research Practicum Evaluation and Mastery in {C}"
    ],
    unitPatterns: [
      "Foundational educational theories policy frameworks and scope of {S}",
      "Learner developmental readiness and diagnostic needs assessment in {S}",
      "Behavioral objectives measurable outcomes and taxonomy alignment in {S}",
      "Step by step lesson or counselling session structure in {S}",
      "Instructional resource selection adaptation and classroom delivery in {S}",
      "Formative questioning learner engagement and inclusive differentiation in {S}",
      "Assessment rubric design test blueprinting and scoring reliability in {S}",
      "Counselling ethics confidentiality referral and learner support in {S}",
      "Alignment with Nigerian National Policy on Education and NERDC in {S}",
      "Reflective practicum evaluation action research and mastery review in {S}"
    ]
  },
  arts_humanities_social: {
    sections: [
      "Conceptual Foundations Historiography and Scope of {C}",
      "Classical and Contemporary Theoretical Frameworks in {C}",
      "Primary Sources Archival Evidence and Textual Criticism in {C}",
      "Social Institutions Political Structures and Power Dynamics in {C}",
      "Precolonial Colonial and Postcolonial Nigerian Perspectives in {C}",
      "African Continental and Global Comparative Dynamics in {C}",
      "Logic Epistemology Ethics and Normative Reasoning in {C}",
      "Cultural Expression Aesthetics Symbolism and Media Discourse in {C}",
      "Identity Stratification Gender and Demographic Change in {C}",
      "Conflict Analysis Peacebuilding Diplomacy and Governance in {C}",
      "Qualitative Ethnographic Survey and Historical Research Methods in {C}",
      "Public Policy Analysis Civic Responsibility and Development in {C}",
      "Critical Argumentation Hermeneutics and Scholarly Debate in {C}",
      "Historiographical Synthesis Research Writing and Examination Mastery in {C}"
    ],
    unitPatterns: [
      "Core concepts foundational definitions and analytical scope of {S}",
      "Major theoretical paradigms intellectual schools and critiques in {S}",
      "Primary and secondary source evaluation and provenance in {S}",
      "Historical chronology structural causation and institutional change in {S}",
      "Nigerian and West African empirical case studies illustrating {S}",
      "Comparative cross national and global perspectives on {S}",
      "Ethical dilemmas normative arguments and logical validity in {S}",
      "Research design sampling interviewing and content analysis in {S}",
      "Policy implications governance reforms and societal impact of {S}",
      "Critical essay structuring scholarly synthesis and exam mastery in {S}"
    ]
  }
};

export function generateCourseSyllabus(course) {
  const domain = routeDomain(course);
  const blueprint = DOMAIN_BLUEPRINTS[domain] || DOMAIN_BLUEPRINTS.arts_humanities_social;
  const cleanTitle = cleanNoHyphen(course.title);
  const cleanDept = cleanNoHyphen(course.dept_name || "General Studies");

  const sections = [];
  const units = [];

  for (let sIdx = 0; sIdx < 14; sIdx++) {
    const secNum = sIdx + 1;
    const rawSecTitle = blueprint.sections[sIdx].replace(/\{C\}/g, cleanTitle).replace(/\{D\}/g, cleanDept);
    const secTitle = cleanNoHyphen(rawSecTitle);
    sections.push({
      course_id: course.course_id,
      section: secNum,
      title: secTitle
    });

    // Core theme of this section (without the trailing " in {C}" for concise unit titles that still name the course)
    const secCore = cleanNoHyphen(
      blueprint.sections[sIdx]
        .replace(/\s+in\s+\{C\}$/i, "")
        .replace(/\s+of\s+\{C\}$/i, "")
        .replace(/\{C\}/g, cleanTitle)
    );

    const cat =
      secNum <= 3 ? "Core Principles" :
      secNum <= 7 ? "Analytical Methods" :
      secNum <= 11 ? "Applied Practice" :
      "Synthesis and Mastery";

    for (let uIdx = 0; uIdx < 10; uIdx++) {
      const seq = sIdx * 10 + uIdx + 1;
      const euSec = String(secNum + 1).padStart(2, "0");
      const euUnit = String(uIdx + 1).padStart(2, "0");
      const unitId = `${course.course_id}-EU${euSec}${euUnit}`;

      const pat = blueprint.unitPatterns[uIdx];
      const rawUnitTitle = pat.replace(/\{S\}/g, `${secCore} in ${cleanTitle}`);
      const unitTitle = cleanNoHyphen(rawUnitTitle);

      units.push({
        unit_id: unitId,
        course_id: course.course_id,
        seq,
        section: secNum,
        title: unitTitle,
        category: cat
      });
    }
  }

  return { domain, cleanTitle, cleanDept, sections, units };
}

async function main() {
  if (process.argv[1] !== new URL(import.meta.url).pathname) return;

  const client = new pg.Client({ connectionString: DSN });
  await client.connect();

  console.log("Fetching all tertiary courses from Supabase...");
  const coursesRes = await client.query(`
    SELECT c.course_id, c.dept_id, c.code, c.title, c.level, c.category,
           COALESCE(d.name, 'General Studies') AS dept_name,
           COALESCE(d.faculty, 'General Studies') AS faculty,
           COALESCE(d.itype, 'university') AS itype
    FROM learn.courses c
    LEFT JOIN learn.departments d ON d.dept_id = c.dept_id
    WHERE c.body = 'tertiary'
    ORDER BY c.course_id
  `);

  const courses = coursesRes.rows;
  console.log(`Loaded ${courses.length} tertiary courses.`);

  // Ensure GST 113 has its 140 unit rows inserted if missing
  const gst113Syllabus = generateCourseSyllabus(courses.find(c => c.course_id === "GST 113"));
  if (gst113Syllabus) {
    for (const u of gst113Syllabus.units) {
      await client.query(`
        INSERT INTO learn.units (unit_id, course_id, seq, title, category, section, keywords, figures)
        VALUES ($1, $2, $3, $4, $5, $6, '{}', '{}')
        ON CONFLICT (unit_id) DO UPDATE SET
          title = EXCLUDED.title,
          category = EXCLUDED.category,
          section = EXCLUDED.section,
          seq = EXCLUDED.seq
      `, [u.unit_id, u.course_id, u.seq, u.title, u.category, u.section]);
    }
    console.log("Inserted/updated 140 units for GST 113 Information Literacy.");
  }

  const allSecRows = [];
  const allUnitRows = [];
  const catalogOut = [];

  let hyphenViolations = 0;
  for (const c of courses) {
    const syl = generateCourseSyllabus(c);
    for (const s of syl.sections) {
      if (/[\u002D\u2010\u2011\u2012\u2013\u2014\u2015\u2212]/.test(s.title)) hyphenViolations++;
      allSecRows.push(s);
    }
    for (const u of syl.units) {
      if (/[\u002D\u2010\u2011\u2012\u2013\u2014\u2015\u2212]/.test(u.title)) hyphenViolations++;
      allUnitRows.push(u);
    }
    catalogOut.push({
      ...c,
      domain: syl.domain,
      sections: syl.sections,
      units: syl.units
    });
  }

  console.log(`Generated ${allSecRows.length} sections and ${allUnitRows.length} units. Hyphen violations: ${hyphenViolations}`);
  if (hyphenViolations > 0) throw new Error("Hyphen violation detected!");

  fs.writeFileSync("/tmp/supabase_3677_catalog.json", JSON.stringify(catalogOut));
  console.log("Saved /tmp/supabase_3677_catalog.json");

  // Delete any orphan sections outside 1..14 for tertiary courses
  await client.query(`
    DELETE FROM learn.course_sections cs
    USING learn.courses c
    WHERE cs.course_id = c.course_id AND c.body = 'tertiary' AND (cs.section < 1 OR cs.section > 14)
  `);

  // Bulk upsert course_sections in batches of 2500
  const SEC_BATCH = 2500;
  const nowIso = new Date().toISOString();
  for (let i = 0; i < allSecRows.length; i += SEC_BATCH) {
    const batch = allSecRows.slice(i, i + SEC_BATCH);
    const values = [];
    const params = [];
    let pIdx = 1;
    for (const r of batch) {
      values.push(`($${pIdx++}, $${pIdx++}::int, $${pIdx++}, $${pIdx++}::timestamptz)`);
      params.push(r.course_id, r.section, r.title, nowIso);
    }
    await client.query(`
      INSERT INTO learn.course_sections (course_id, section, title, generated_at)
      VALUES ${values.join(",")}
      ON CONFLICT (course_id, section) DO UPDATE SET
        title = EXCLUDED.title,
        generated_at = EXCLUDED.generated_at
    `, params);
    if ((i / SEC_BATCH) % 5 === 0 || i + SEC_BATCH >= allSecRows.length) {
      console.log(`Upserted sections: ${Math.min(i + SEC_BATCH, allSecRows.length)} / ${allSecRows.length}`);
    }
  }

  // Bulk update learn.units in batches of 5000
  const UNIT_BATCH = 5000;
  const t0 = Date.now();
  for (let i = 0; i < allUnitRows.length; i += UNIT_BATCH) {
    const batch = allUnitRows.slice(i, i + UNIT_BATCH);
    const uids = batch.map(r => r.unit_id);
    const titles = batch.map(r => r.title);
    const cats = batch.map(r => r.category);

    await client.query(`
      UPDATE learn.units AS u
      SET title = v.title,
          category = v.category
      FROM unnest($1::text[], $2::text[], $3::text[]) AS v(unit_id, title, category)
      WHERE u.unit_id = v.unit_id
    `, [uids, titles, cats]);

    if ((i / UNIT_BATCH) % 10 === 0 || i + UNIT_BATCH >= allUnitRows.length) {
      const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
      console.log(`Updated units: ${Math.min(i + UNIT_BATCH, allUnitRows.length)} / ${allUnitRows.length} (${elapsed}s)`);
    }
  }

  // Verify CRS-09821, GST 101, GST 113, CRS-02004, CRS-06207
  const sampleCheck = await client.query(`
    SELECT c.course_id, c.title AS course_title, cs.section, cs.title AS section_title, u.seq, u.title AS unit_title
    FROM learn.courses c
    JOIN learn.course_sections cs ON cs.course_id = c.course_id AND cs.section = 1
    JOIN learn.units u ON u.course_id = c.course_id AND u.seq = 1
    WHERE c.course_id IN ('CRS-09821', 'GST 101', 'GST 113', 'CRS-02004', 'CRS-05964', 'CRS-06207', 'CRS-10185')
    ORDER BY c.course_id
  `);
  console.log("Sample verified courses in Supabase:", sampleCheck.rows);

  await client.end();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
