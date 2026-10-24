#!/usr/bin/env python3
"""make_hand_donors.py - author the two zero-donor Python lessons:
  (sig 12511240236317792027, sec 10, pos 6)  'Third-party packages and pip environments'
  (sig 12511240236317792027, sec 14, pos 10) 'The next decade: AI, policy and opportunity'
Subject slot uses the placeholder phrase 'hybrid basketry design', woven ONLY through
whitelisted framing signatures so the assembler can swap in real subjects.
Validates: 10 notes, bodies 55..300 words, no '--', quiz shape, summary formula.
"""
import json, gzip, re, datetime, collections

R = "/home/z/my-project/content/tertiary/recover"
P = "hybrid basketry design"
TAIL = ": what it is, how it works, and where the marks are."

def wc(t):
    return len(re.findall(r"[A-Za-z0-9']+", t))

def mcq(stem, opts, ans, expl):
    return {"type": "mcq", "stem": stem, "options": {"A": opts[0], "B": opts[1], "C": opts[2], "D": opts[3]},
            "answer": ans, "explanation": expl}

def tf(stem, ans, expl):
    return {"type": "true_false", "stem": stem, "options": {"A": "True", "B": "False"},
            "answer": ans, "explanation": expl}

def fb(stem, ans, expl):
    return {"type": "fill_blank", "stem": stem, "answer": ans, "explanation": expl}

# ---------------- LESSON 1: Third-party packages and pip environments ----------------
T1 = "Third-party packages and pip environments"
L1_notes = [
    (f"{T1} and its place in {P}",
     f"Every serious course in {P} reaches third party packages and pip environments sooner or later, because the topic answers a question students actually ask: how do I use code other people have already tested instead of rewriting it badly. This unit answers it with mechanisms, examples and the honest traps. A package is a folder of modules that someone else maintains, documents and versions, so your own file stays short. The quiz that follows rewards exactly this preparation."),
    ("pip install: what actually happens",
     f"In {P} practice, examiners rarely ask for the command alone; they ask what the command does to the machine. Typing pip install pandas sets a short pipeline in motion: pip contacts PyPI, the public Python Package Index, finds the newest compatible release, downloads a wheel, which is a built archive ending in .whl, unpacks it into the active environment, and pulls in any dependencies the package declares. Installing pandas therefore also installs numpy, because pandas declares it."),
    ("Virtual environments and why they exist",
     f"Two projects on one laptop often need different versions of the same library, and the global interpreter can only hold one. A virtual environment solves this: python -m venv .venv creates a folder containing its own interpreter and its own site packages directory. Activating it, with .venv backslash Scripts backslash activate on Windows or source dot venv slash bin slash activate on Linux and macOS, points python and pip at that copy. A student of {P} must be able to explain why isolation is not optional on real projects."),
    ("requirements.txt and reproducible installs",
     f"An environment is only useful if it can be rebuilt. pip freeze prints every installed package with an exact version, and redirecting that output into requirements.txt records the recipe. On another machine, or after a failure, pip install with the r flag restores the same versions. Pinning with two equals signs, as in pandas equals equals 2.2.0, prevents silent upgrades. Working in {P} keeps this habit: no shared project leaves the door without a frozen file, because unexplained version drift wastes whole afternoons."),
    ("Dependency resolution and conflicts",
     f"When two installed packages demand different versions of the same library, pip reports a resolver conflict instead of guessing. The message names the packages and the versions each one requires, which is the raw material for a fix: relax one pin, upgrade a lagging package, or choose an alternative library. This is why {P} teaches you to read the whole error, not just the last line. Conflicts are ordinary engineering facts, not personal failures, and every professional meets them weekly."),
    ("Importing installed packages",
     f"After installation, import pandas as pd simply works, because the environment's site packages folder sits on the module search path that sys.path shows. One trap deserves its own paragraph: if your own file is named pandas.py, your file shadows the real package and the import returns your half written script instead. In every {P} course, this classic slip is graded without mercy, so never name a file after a package you plan to import, and inspect sys.path whenever imports behave strangely."),
    ("Where packages live and how to inspect them",
     f"pip list shows every package in the active environment with its version, and pip show pandas adds the homepage, licence, location and dependencies of one package. The location reported is the site packages directory, the only place pip should ever write. Uninstalling with pip uninstall pandas removes that code but leaves your own files untouched. Examiners in {P} set questions on these inspection commands, because professionals debug with them daily instead of guessing what is installed where."),
    ("Choosing packages wisely",
     f"Before adopting a package, look at four honest signals: the date of the last release, the quality of the documentation, the number of open issues, and the licence under which it ships. A student of {P} learns to distrust near copies of famous names, a supply chain trick called typosquatting, where a misspelled package imitates a popular one to catch careless installs. One minute of checking beats one week of cleaning up a broken dependency chain."),
    ("Common exam traps with pip",
     f"Three slips dominate examiner reports. First, installing without activating the environment, which quietly writes to the global interpreter and poisons every other project. Second, running bare pip when several Pythons exist, where python -m pip install guarantees that the interpreter you actually run receives the package. Third, confusing the install step with the import step: installing happens once per environment, importing happens once per file that needs it. In a {P} classroom, these three traps are worth more marks than any single command."),
    ("Real use and the classic slips",
     f"Picture a report pipeline shared by a small team: each member creates a fresh environment, activates it, installs from requirements.txt, runs the pipeline, and gets the same tables and charts. A month later, a new laptop repeats the same four commands and the pipeline runs again without drama. That reproducibility, not the command syntax, is the real lesson of this unit, and it separates a script that works on one machine from a tool a team can trust. Practice the sequence until it is reflex."),
]
L1_kp = [
    "A package is maintained, versioned code from an index such as PyPI; pip installs it into the active environment, never into the project folder.",
    "python -m venv followed by a folder name creates an isolated environment; activate it before installing or running so versions never collide.",
    "pip freeze pins exact versions into requirements.txt, and pip install with the r flag rebuilds the set on any machine.",
    "Inspect with pip list and pip show; read resolver conflicts fully; never name your files after packages you import.",
]
L1_quiz = [
    mcq("PyPI is best described as",
        ["the public package index that pip searches by default", "the standard library folder", "a virtual environment tool", "a code editor for packages"], "A",
        "pip resolves package names against PyPI unless another index is configured."),
    mcq("Running pip install pandas also installs numpy because",
        ["numpy is free", "pandas declares numpy as a dependency", "pip always installs two packages", "numpy is the wheel format"], "B",
        "Declared dependencies are pulled automatically from package metadata."),
    mcq("python -m venv .venv creates",
        ["a requirements file", "a compressed backup", "a PyPI account", "a folder with its own interpreter and site packages"], "D",
        "The folder holds an isolated interpreter copy and its own packages directory."),
    mcq("Before pip install inside a project you must first",
        ["activate the project's virtual environment", "delete the global site packages", "publish the project to PyPI", "rename the project folder"], "A",
        "Without activation pip writes into the global interpreter."),
    mcq("The command that records installed versions for rebuilding is",
        ["pip freeze", "pip audit", "pip cache", "pip show"], "A",
        "pip freeze lists each package with its exact installed version."),
    mcq("pandas with two equals signs and 2.2.0 in a requirements file means",
        ["any 2.2 release", "the newest release above 2.2.0", "exactly version 2.2.0", "pandas plus its documentation"], "C",
        "Two equals signs pin one exact version."),
    mcq("A resolver conflict message tells you",
        ["the network failed", "the disk is full", "Python must be reinstalled", "two packages need different versions of one library"], "D",
        "The resolver names the packages and the incompatible versions."),
    mcq("Naming your script pandas.py breaks imports because",
        ["pip deletes the file", "Python renames the file", "the file shadows the installed package on the search path", "the licence forbids it"], "C",
        "Your folder comes first on sys.path, so your file wins."),
    mcq("pip show pandas reports",
        ["only the size", "the location, licence, version and dependencies", "the author's salary", "the global install count"], "B",
        "It prints metadata including where the package lives."),
    mcq("Typosquatting in the package world means",
        ["a typing speed test", "a licence violation", "an offline installer", "a misspelled package imitating a popular one to catch careless installs"], "D",
        "Near copies of famous names are a known supply chain trick."),
    mcq("python -m pip install is preferred to bare pip because",
        ["it downloads faster", "it skips dependencies", "it signs packages", "it targets the interpreter you actually run"], "D",
        "The m form guarantees the install lands in the interpreter you invoked."),
    mcq("A wheel file is",
        ["a test suite", "an environment folder", "a built distribution archive ending in .whl", "a licence document"], "C",
        "Wheels are ready built archives pip can unpack without compiling."),
    mcq("A teammate's identical code fails on your machine. First check",
        ["whether the same package versions are pinned and installed", "the weather", "the keyboard layout", "the editor theme"], "A",
        "Version drift without a requirements file is the usual culprit."),
    mcq("The safest habit before adopting a package is checking",
        ["its price", "its name length", "release recency, documentation, issues and licence", "its download colour"], "C",
        "Those four signals expose abandoned or risky packages."),
    mcq(f"In every {P} course, the reproducible setup order is",
        ["write code, freeze, create an environment", "create an environment, activate, install, freeze", "install globally, then freeze", "freeze first, activate later"], "B",
        "Environment first, activation next, installs after, freeze last."),
    tf("Installing a package writes code into the project folder itself.", "B",
       "Installs go to the environment's site packages directory, not your files."),
    tf("pip uninstall pandas removes the package only from the active environment.", "A",
       "Uninstall removes that package's code from the environment it lives in."),
    tf("Two projects can safely use different versions of one library when each has its own environment.", "A",
       "Isolation is exactly what virtual environments provide."),
    tf("Editing files inside site packages by hand is the recommended way to fix a bug.", "B",
       "Never hand edit installed code; reinstall a patched version instead."),
    fb("Fill: the file that pins exact versions so any machine can rebuild the environment is ____.", "requirements.txt",
       "pip freeze writes it; pip install with the r flag reads it."),
]

# ---------------- LESSON 2: The next decade: AI, policy and opportunity ----------------
T2 = "The next decade: AI, policy and opportunity"
L2_notes = [
    (f"{T2} and its place in {P}",
     f"Every serious course in {P} reaches its forward look sooner or later, because the tools you will use in ten years are being decided right now. Artificial intelligence is reshaping how software is written, how work is priced and how governments regulate data. This unit stands back from syntax and asks three plain questions: what is changing, which rules are arriving, and where a careful student can still win. The quiz that follows rewards preparation on all three fronts."),
    ("AI in plain terms and where Python fits",
     f"Modern artificial intelligence is statistics at scale: models learn patterns from large datasets and then make predictions on new cases. The working language of that field is Python, because serious tools such as scikit-learn, PyTorch and TensorFlow expose their power through Python interfaces. A student of {P} learns to see this clearly: the model is a component, and the pipeline around it, from data cleaning to deployment, is still ordinary programming done well."),
    ("Nigeria's national direction",
     f"In {P} practice, these documents matter to every project that touches personal data, from admission systems to loan scoring, because compliance is now a grading criterion in the real world. Nigeria published its National Artificial Intelligence Strategy draft through NITDA in 2024, after wide consultation, aiming at talent, data, infrastructure and regulation. The data layer is already law: the Nigeria Data Protection Act 2023 replaced the older NDPR framework and created the Nigeria Data Protection Commission to enforce it."),
    ("Global policy landmarks",
     f"Two global references frame the decade. The UNESCO Recommendation on the Ethics of Artificial Intelligence, adopted in 2021, set shared values for member states, including fairness, transparency and human oversight. The European Union Artificial Intelligence Act, which entered into force in 2024, sorts uses into risk tiers, from practices that are banned outright to high risk systems carrying heavy duties and low risk ones that stay mostly free. Examiners in {P} set questions on these tiers because they are becoming the world's template."),
    ("Data protection as the floor",
     f"Every AI system consumes data, and most useful data about people is protected. The Nigeria Data Protection Act 2023 requires a lawful basis before processing personal data, demands accuracy and security, and backs its rules with fines that can reach 10 million naira or two percent of annual gross revenue. Working in {P} keeps this habit: ask who owns the data and who consented before asking what the model might predict, because the second question has no legal meaning without the first."),
    ("Jobs the decade will pay for",
     f"The visible AI jobs are only part of the market. Annotation and data quality work feeds the models; data engineering moves the pipelines; machine learning engineering turns notebooks into services; product people translate between users and models. In a {P} classroom, the honest message is that AI also removes tasks, so the durable roles combine domain knowledge with technical fluency: a person who understands the farm, the clinic or the ledger and can still read the code."),
    ("Skills that survive automation",
     f"Three skills travel well through any automation wave. First, statistics literacy, because a student of {P} must judge whether a number is signal or noise. Second, disciplined coding, meaning small readable functions, tests and version control. Third, communication, the ability to carry a finding from a notebook into a decision a manager can defend. This is why {P} teaches fundamentals beside tools; the tools change every few years, the fundamentals compound for decades."),
    ("Ethics you can be graded on",
     f"Bias enters models through unrepresentative training data and shows up as unequal error across groups. Transparency means saying plainly where a system is automated and where a human decides. Accountability means someone identifiable owns each deployment. In every {P} course, these three words are graded, because employers now ask about them in interviews. A student who can name a biased dataset example and a mitigation earns the marks; a student who only says AI must be fair does not."),
    ("Guardrails for using AI tools in study",
     f"In {P} practice, the portfolios that impress combine human judgement on top with clean evidence of honest tool use. Code assistants and chat models are study tools with rules. Use them to explain a concept you half understand, to quiz you before an examination, and to critique a draft you wrote yourself. Do not submit generated text as your own reasoning, because the examination room still tests your unassisted mind. Keep a record of prompts and outputs where policy requires disclosure."),
    ("Where the road leads",
     f"The next decade will pay people who pair fast AI tools with slow, careful fundamentals: statistics, clean code, domain knowledge and honesty about limits. Policy will keep tightening around data, models and disclosure, and that is good news for prepared students, because rules reward the disciplined. A student of {P} writes the plan into a portfolio: one real data project this term, one national strategy document read this year, one classmate taught. Opportunity in this decade is not found; it is prepared for."),
]
L2_kp = [
    "AI is statistics at scale, and Python is its working language through tools such as scikit-learn, PyTorch and TensorFlow.",
    "Nigeria's National AI Strategy draft came through NITDA in 2024, and the Nigeria Data Protection Act 2023 governs personal data with real fines.",
    "The UNESCO 2021 recommendation and the EU AI Act 2024 supply the ethics and risk tier templates examiners ask about.",
    "Durable skills are statistics literacy, disciplined coding and communication, plus honest, disclosed use of AI study tools.",
]
L2_quiz = [
    mcq("The National Artificial Intelligence Strategy draft was published through which body in 2024?",
        ["NITDA", "NNPC", "NIMET", "JAMB"], "A",
        "NITDA led the national strategy drafting after wide consultation."),
    mcq("The Nigeria Data Protection Act became law in",
        ["2023", "2019", "2003", "2024"], "A",
        "The Act was passed in 2023."),
    mcq("The EU Artificial Intelligence Act, in force from 2024, organises AI uses by",
        ["price", "programming language", "risk tiers", "country size"], "C",
        "Uses run from banned practices to high, limited and minimal risk tiers."),
    mcq("The UNESCO Recommendation on the Ethics of Artificial Intelligence was adopted in",
        ["2021", "2015", "2019", "2023"], "A",
        "Member states adopted the recommendation in 2021."),
    mcq("Under the Nigeria Data Protection Act 2023, fines can reach",
        ["10 million naira or two percent of annual gross revenue", "1 thousand naira", "5 naira per record", "no limit exists"], "A",
        "The Act backs duties with a real financial ceiling."),
    mcq("The body created to enforce the Nigeria Data Protection Act is",
        ["NDLEA", "NAFDAC", "the Central Bank", "the Nigeria Data Protection Commission"], "D",
        "The Commission enforces the 2023 Act."),
    mcq("Bias in an AI model most often enters through",
        ["the colour of the server", "the keyboard used", "Python's version", "unrepresentative training data"], "D",
        "Skewed data in produces skewed predictions out."),
    mcq("Which pair belongs to Python's AI tooling?",
        ["Word and Excel", "Chrome and Firefox", "Bluetooth and USB", "scikit-learn and PyTorch"], "D",
        "Both libraries expose machine learning through Python."),
    mcq("A durable skill for the AI decade is",
        ["memorising one framework's menus", "statistics literacy with communication", "typing speed only", "avoiding all code"], "B",
        "Fundamentals compound while tools churn."),
    mcq("Acceptable study use of an AI assistant is",
        ["submitting its text as your own", "hiding its use where disclosure is required", "using it to explain concepts and quiz yourself", "skipping practice because answers exist"], "C",
        "Explanation and self testing keep the learning yours."),
    mcq("High risk systems under the EU AI Act",
        ["are banned outright", "carry heavy compliance duties", "are always illegal", "need no documentation"], "B",
        "High risk uses are allowed under strict obligations."),
    mcq("Fintech fraud scoring illustrates",
        ["manual accounting", "banking without data", "AI in financial services", "hardware design"], "C",
        "Banks score transactions with models to catch fraud."),
    mcq("The older data rules replaced by the 2023 Act were the",
        ["Land Use Act", "CAMA", "NDPR framework", "Finance Act"], "C",
        "The NDPR framework preceded the 2023 Act."),
    mcq(f"In every {P} course, the decade's recipe is",
        ["tools alone", "fundamentals alone", "luck", "fundamentals paired with AI tools"], "D",
        "The durable pairing wins the decade."),
    mcq("Annotation and data quality work matter because",
        ["models learn from labelled, cleaned data", "they fill disk space", "regulators require busywork", "they slow projects"], "A",
        "Model quality is capped by its data."),
    tf("The Nigeria Data Protection Act 2023 replaced the older NDPR framework.", "A",
       "The 2023 Act superseded the 2019 regulations."),
    tf("The UNESCO 2021 recommendation bans all artificial intelligence research.", "B",
       "It guides ethical use; it bans no research."),
    tf("Advisory systems can deliver crop suggestions to farmers through ordinary SMS.", "A",
       "Simple channels carry model advice where smartphones are scarce."),
    tf("Prompt literacy without fundamentals guarantees a decade long career.", "B",
       "Prompts layer on fundamentals; they do not replace them."),
    fb("Fill: the EU act that sorts artificial intelligence uses into risk tiers took effect in ____.", "2024",
       "The Artificial Intelligence Act entered into force in 2024."),
]

def build(title, notes, kps, quiz, label):
    # assemble + validate
    assert len(notes) == 10, len(notes)
    assert len(quiz) == 20, len(quiz)
    assert len(kps) == 4
    blob = {
        "topic_id": label,
        "title": title,
        "summary": f"{title} in {P}{TAIL}",
        "notes": [{"heading": h, "body": b} for h, b in notes],
        "key_points": kps,
        "quiz": [dict(q, id=f"{label}-q{i+1:02d}") for i, q in enumerate(quiz)],
        "drawings": [],
        "source": "curated-v2",
        "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    # validation
    for h, b in notes:
        w = wc(b)
        assert 55 <= w <= 300, (h, w)
    all_text = blob["summary"] + " " + " ".join(h + " " + b for h, b in notes) + " " + " ".join(kps)
    for q in quiz:
        all_text += " " + q["stem"] + " " + q["explanation"]
        for v in (q.get("options") or {}).values():
            all_text += " " + v
    assert "--" not in all_text, "dash dash found"
    assert all_text.isascii(), "non ascii"
    n_mcq = sum(1 for q in quiz if q["type"] == "mcq")
    letters = [q["answer"] for q in quiz if q["type"] == "mcq"]
    print(f"{label}: notes={len(notes)} quiz={len(quiz)} mcq={n_mcq} "
          f"answer letters={collections.Counter(letters)} "
          f"note words min={min(wc(b) for _, b in notes)} max={max(wc(b) for _, b in notes)}")
    return blob

b1 = build(T1, L1_notes, L1_kp, L1_quiz, "HAND-PYS10P6")
b2 = build(T2, L2_notes, L2_kp, L2_quiz, "HAND-PYS14P10")

# save as donor files with explicit subject marker
for key, blob in [((12511240236317792027, 10, 6), b1), ((12511240236317792027, 14, 10), b2)]:
    fn = f"{R}/donors/hand_{key[0]}_{key[1]}_{key[2]}.json.gz"
    with gzip.open(fn, "wt") as f:
        json.dump({"uid": blob["topic_id"], "subject": P, "blob": blob}, f)
    print("saved", fn)

# register in donor index
di = json.load(open(f"{R}/donor_index.json"))
for key, label in [((12511240236317792027, 10, 6), "HAND-PYS10P6"),
                   ((12511240236317792027, 14, 10), "HAND-PYS14P10")]:
    k = f"{key[0]}_{key[1]}_{key[2]}"
    di.setdefault(k, [])
    if label not in di[k]:
        di[k].append(label)
json.dump(di, open(f"{R}/donor_index.json", "w"))
print("donor_index updated")
