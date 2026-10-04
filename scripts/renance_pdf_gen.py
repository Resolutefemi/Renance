#!/usr/bin/env python3
"""Renance PDF Restructure Generator.

Rebuilds harvested abstechconnect / gdrive materials into clean, branded,
black-and-white Renance PDFs:

  - one PDF per (university, course): "<UNIVERSITY> <COURSE> by Renance"
  - white background, black text, structured layout
  - cover page with course info + Renance write-up + website + Play Store CTA
  - "by Renance" footer on every content page
  - source watermarks stripped (text is re-rendered, never copied as-is)
  - papers merged when a course has multiple source PDFs
  - image-only pages with no recoverable text are embedded as grayscale
    images inside the same template

Usage:
    python3 renance_pdf_gen.py --plan          # show grouping plan
    python3 renance_pdf_gen.py --school fupre  # generate one school
    python3 renance_pdf_gen.py --all           # generate everything
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, PageBreak,
    HRFlowable, NextPageTemplate,
)

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
GDRIVE = Path("/home/z/my-project/renance/data/src/gdrive")
OUT_ROOT = Path("/home/z/my-project/renance/data/renance_pdfs")
OUT_ROOT.mkdir(parents=True, exist_ok=True)

WEBSITE = "renance.app"
PLAYSTORE = "https://play.google.com/store/apps/details?id=dev.renance.renance"

# ---------------------------------------------------------------- fonts
FONT_DIR_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
]


def register_fonts() -> tuple[str, str, str]:
    reg = bold = mono = "Helvetica"
    try:
        pdfmetrics.registerFont(TTFont("RReg", FONT_DIR_CANDIDATES[0]))
        pdfmetrics.registerFont(TTFont("RBold", FONT_DIR_CANDIDATES[1]))
        pdfmetrics.registerFont(TTFont("RMono", FONT_DIR_CANDIDATES[2]))
        reg, bold, mono = "RReg", "RBold", "RMono"
    except Exception:  # noqa: BLE001
        pass
    return reg, bold, mono


FONT, FONT_B, FONT_M = register_fonts()

# ---------------------------------------------------------------- styles
S_COVER_KICKER = ParagraphStyle("kicker", fontName=FONT_B, fontSize=10,
                                 leading=14, alignment=TA_CENTER,
                                 textColor="black", spaceAfter=6)
S_COVER_TITLE = ParagraphStyle("ctitle", fontName=FONT_B, fontSize=26,
                               leading=32, alignment=TA_CENTER,
                               textColor="black", spaceAfter=4)
S_COVER_SUB = ParagraphStyle("csub", fontName=FONT, fontSize=15,
                             leading=20, alignment=TA_CENTER, textColor="black")
S_COVER_META = ParagraphStyle("cmeta", fontName=FONT, fontSize=10.5,
                              leading=16, alignment=TA_CENTER, textColor="black")
S_WRITEUP = ParagraphStyle("writeup", fontName=FONT, fontSize=10.5,
                           leading=17, alignment=TA_LEFT, textColor="black",
                           spaceBefore=6, spaceAfter=6)
S_SECTION = ParagraphStyle("sect", fontName=FONT_B, fontSize=13, leading=18,
                           spaceBefore=10, spaceAfter=6, textColor="black")
S_BODY = ParagraphStyle("body", fontName=FONT, fontSize=9.6, leading=14.5,
                        spaceAfter=3, textColor="black")
S_META = ParagraphStyle("meta", fontName=FONT, fontSize=8.2, leading=12,
                        textColor="#333333", spaceAfter=8)

WATERMARK_PATTERNS = [
    r"www\.abstechconnect\.com", r"abstechconnect\.com", r"abstech ?connect",
    r"scanned by camscanner", r"camscanner",
    r"download more past questions from", r"www\.preps\.com\.ng", r"prepsng",
    r"preps\.com\.ng",
    r"team asset", r"assettunde", r"08037042205", r"always ?remember ?asset",
    r"successi ?nyour ?exams",
    r"www\.fupreblog\.com", r"fupreblog",
    r"calloraddupassettunde", r"wishyouallsuccess",
    r"powered by abstech",
]


def clean_text(text: str) -> str:
    out_lines = []
    for ln in text.splitlines():
        low = ln.lower()
        if any(re.search(p, low) for p in WATERMARK_PATTERNS):
            continue
        # drop lines that are pure separators/dashes noise
        if re.fullmatch(r"[\s\W_-]*", ln) and len(ln.strip()) > 0:
            if len(ln.strip()) < 4:
                continue
        out_lines.append(ln.rstrip())
    txt = "\n".join(out_lines)
    txt = re.sub(r"\n{3,}", "\n\n", txt)
    return txt.strip()


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


# ---------------------------------------------------------------- grouping
SCHOOL_MAP = {
    "federal university of petroleum resources, effurun-(fupre)": ("fupre", "FUPRE", "Federal University of Petroleum Resources, Effurun"),
    "federal university of petroleum resources, effurun (fupre)": ("fupre", "FUPRE", "Federal University of Petroleum Resources, Effurun"),
    "federal university of petroleum resources effurun": ("fupre", "FUPRE", "Federal University of Petroleum Resources, Effurun"),
    "osun state university osogbo": ("uniosun", "UNIOSUN", "Osun State University, Osogbo"),
    "ambrose alli university, ekpoma": ("aau", "AAU", "Ambrose Alli University, Ekpoma"),
    "university of port harcourt": ("uniport", "UNIPORT", "University of Port Harcourt"),
    "petroleum training institute": ("pti", "PTI", "Petroleum Training Institute, Effurun"),
    "federal university of technology, minna": ("futminna", "FUT MINNA", "Federal University of Technology, Minna"),
    "federal polytechnic, ilaro": ("fedpolyilaro", "FEDPOLY ILARO", "Federal Polytechnic, Ilaro"),
    "delta state polytechnic, otefe-oghara": ("deltapoly", "DELTAPOLY", "Delta State Polytechnic, Otefe-Oghara"),
    "federal university, birnin kebbi": ("fubk", "FUBK", "Federal University, Birnin Kebbi"),
    "university of calabar": ("unical", "UNICAL", "University of Calabar"),
    "federal polytechnic ado-ekiti": ("fedpolyado", "FEDPOLY ADO", "Federal Polytechnic, Ado-Ekiti"),
    "kano state polytechnic": ("kanopoly", "KANOPOLY", "Kano State Polytechnic"),
    "babcock university": ("babcock", "BABCOCK", "Babcock University"),
    "federal university of technology, akure": ("futa", "FUTA", "Federal University of Technology, Akure"),
    "national open university of nigeria (noun)": ("noun", "NOUN", "National Open University of Nigeria"),
    "bingham university": ("bingham", "BINGHAM", "Bingham University"),
    "university of benin": ("uniben", "UNIBEN", "University of Benin"),
    "lagos state university, ojo": ("lasu", "LASU", "Lagos State University"),
    "niger delta university yenagoa": ("ndu", "NDU", "Niger Delta University"),
    "college of education, warri (affiliated to delsu)": ("coewarri", "COE WARRI", "College of Education, Warri"),
    "college of education, warri": ("coewarri", "COE WARRI", "College of Education, Warri"),
    "ekiti state university": ("eksu", "EKSU", "Ekiti State University"),
    "adekunle ajasin university, akungba": ("aaua", "AAUA", "Adekunle Ajasin University, Akungba"),
    "university of ilorin": ("unilorin", "UNILORIN", "University of Ilorin"),
    "university of lagos": ("unilag", "UNILAG", "University of Lagos"),
    "obafemi awolowo university, ile-ife": ("oau", "OAU", "Obafemi Awolowo University, Ile-Ife"),
    "delta state university, abraka": ("delsu", "DELSU", "Delta State University, Abraka"),
    "crawford university igbesa": ("crawford", "CRAWFORD", "Crawford University"),
    "evangel university": ("evangel", "EVANGEL", "Evangel University"),
    "benue state university, makurdi": ("bumsu", "BSU", "Benue State University, Makurdi"),
    "nasarawa state university keffi": ("nsuk", "NSUK", "Nasarawa State University, Keffi"),
    "bowen university": ("bowen", "BOWEN", "Bowen University"),
    "american university of nigeria, yola": ("aun", "AUN", "American University of Nigeria"),
}

COURSE_RE = re.compile(r"\b([A-Z]{2,4})[\s\-/]?(\d{3})\b")


def extract_course(name: str) -> tuple[str, str] | None:
    m = COURSE_RE.search((name or "").upper())
    if not m:
        return None
    dept, num = m.group(1), m.group(2)
    canon = {"MAT": "MTH", "GES": "GST", "GSE": "GST", "GNS": "GNS", "CPT": "CSC",
             "EEE": "EEE", "PEE": "PEE", "PET": "PET", "MEE": "MEE", "CHE": "CHE",
             "STA": "STA", "ACC": "ACC", "ENT": "ENT", "MTS": "MTS", "TCH": "TCH"}
    dept = canon.get(dept, dept)
    return dept + num, f"{dept} {num}"


def best_text(stem: str) -> str:
    """Return the best available text for a pdf stem (layout/raw/recon/ocr).

    Handout stems (h-*) resolve against hpdfs/, PQ stems against pdfs/.
    """
    if stem.startswith("h-"):
        base = SRC / "hpdfs"
        pdf = base / (stem + ".pdf")
        cands = []
        for suffix in (".txt", ".ocr.txt"):
            p = base / (stem + suffix)
            if p.exists():
                cands.append(p.read_text(errors="ignore"))
        if not cands:
            return ""
        return max(cands, key=len)
    pdf = PDF_DIR / (stem + ".pdf")
    candidates = []
    lay = PDF_DIR / (stem + ".txt")
    ocr = PDF_DIR / (stem + ".ocr.txt")
    if ocr.exists():
        candidates.append(ocr.read_text(errors="ignore"))
    if lay.exists():
        candidates.append(lay.read_text(errors="ignore"))
    if not candidates:
        try:
            r = subprocess.run(["pdftotext", "-layout", str(pdf), "-"],
                               capture_output=True, text=True, timeout=120)
            candidates.append(r.stdout)
        except Exception:  # noqa: BLE001
            pass
    if not candidates:
        return ""
    # pick the longest candidate (OCR beats empty text layers)
    return max(candidates, key=len)


def build_groups() -> dict:
    """(school_slug) -> {course: [entries]} from abstech PQ + handouts."""
    details = {}
    for line in (SRC / "details.jsonl").open():
        d = json.loads(line)
        details[d["id"]] = d
    # handout details (sizes only for <=3MB downloads, pdfs on disk in hpdfs/)
    HDIR = SRC / "hpdfs"
    for line in (SRC / "details_handout.jsonl").open():
        d = json.loads(line)
        details[d["id"]] = d

    groups: dict = {}
    for lib_id, rec in details.items():
        inst = (rec.get("institution") or "").strip().lower()
        school = SCHOOL_MAP.get(inst)
        if not school:
            continue
        course = extract_course(rec.get("name") or "")
        if not course:
            continue
        code, display = course
        # stems: PQ pdfs live in pdfs/, handouts in hpdfs/ (h-<id>-<n>.pdf)
        if rec.get("libraryCategory") == "Handout":
            stems = sorted(p.stem for p in HDIR.glob(f"h-{lib_id}-*.pdf")) if HDIR.exists() else []
        else:
            stems = sorted(p.stem for p in PDF_DIR.glob(lib_id + "-*.pdf"))
        if not stems:
            continue
        g = groups.setdefault(school[0], {
            "slug": school[0], "short": school[1], "full": school[2], "courses": {},
        })
        g["courses"].setdefault(code, {
            "display": display, "entries": [],
        })["entries"].append({
            "lib_id": lib_id,
            "name": rec.get("name"),
            "level": rec.get("level"),
            "semester": rec.get("semester"),
            "category": rec.get("libraryCategory"),
            "stems": stems,
            "institution_full": school[2],
        })
    return groups


# ---------------------------------------------------------------- rendering
def cover_flowables(school_full: str, course_display: str, meta_lines: list[str],
                    n_papers: int, n_pages: int) -> list:
    story = []
    story.append(Spacer(1, 18 * mm))
    story.append(Paragraph("R E N A N C E", S_COVER_KICKER))
    story.append(HRFlowable(width="30%", thickness=1, color="black", hAlign="CENTER"))
    story.append(Spacer(1, 10 * mm))
    story.append(Paragraph(esc(school_full.upper()), S_COVER_TITLE))
    story.append(Spacer(1, 3 * mm))
    story.append(Paragraph(f"{esc(course_display)} &mdash; Past Questions &amp; Materials",
                           S_COVER_SUB))
    story.append(Spacer(1, 4 * mm))
    story.append(Paragraph("by Renance", ParagraphStyle(
        "by", parent=S_COVER_SUB, fontName=FONT_B, fontSize=13)))
    story.append(Spacer(1, 10 * mm))
    story.append(HRFlowable(width="100%", thickness=0.6, color="black"))
    story.append(Spacer(1, 4 * mm))
    for m in meta_lines:
        story.append(Paragraph(esc(m), S_COVER_META))
    story.append(Spacer(1, 4 * mm))
    story.append(HRFlowable(width="100%", thickness=0.6, color="black"))
    story.append(Spacer(1, 8 * mm))
    writeup = (
        "This study pack was compiled and restructured by Renance for "
        f"{esc(course_display)} students at {esc(school_full)}. It brings together "
        f"{n_papers} past paper(s)/material(s) into one clean, readable document "
        "so you can revise without chasing scattered PDFs. "
        "Practise these same questions interactively on Renance with instant "
        "answers, AI explanations, and full CBT mock exams &mdash; over 235,000+ "
        "questions across JAMB, Post-UTME, WAEC, NECO and university courses."
    )
    story.append(Paragraph(writeup, S_WRITEUP))
    story.append(Spacer(1, 6 * mm))
    story.append(Paragraph(f"Study online: {WEBSITE}", S_COVER_META))
    story.append(Paragraph(f"Get the app: {PLAYSTORE.replace('https://play.google.com/store/apps/details?id=', 'Google Play — ')}",
                           S_COVER_META))
    story.append(Spacer(1, 6 * mm))
    story.append(Paragraph("Generated by Renance AI", S_COVER_META))
    story.append(NextPageTemplate("content"))
    story.append(PageBreak())
    return story


def header_footer(canvas, doc):
    canvas.saveState()
    # header
    canvas.setFont(FONT_B, 8)
    canvas.drawString(18 * mm, 285 * mm, doc.header_text)
    canvas.setFont(FONT, 8)
    canvas.drawRightString(192 * mm, 285 * mm, "Renanced")
    canvas.line(18 * mm, 283.5 * mm, 192 * mm, 283.5 * mm)
    # footer
    canvas.line(18 * mm, 14 * mm, 192 * mm, 14 * mm)
    canvas.setFont(FONT_B, 8.5)
    canvas.drawCentredString(105 * mm, 9.5 * mm, "by Renance")
    canvas.setFont(FONT, 8)
    canvas.drawCentredString(105 * mm, 5.5 * mm,
                             f"{WEBSITE}  •  Download Renance on Google Play")
    canvas.setFont(FONT, 8)
    canvas.drawRightString(192 * mm, 9.5 * mm, f"{canvas.getPageNumber():,}")
    canvas.restoreState()


def cover_page_deco(canvas, doc):
    canvas.saveState()
    canvas.setFont(FONT, 8.5)
    canvas.drawCentredString(105 * mm, 8 * mm,
                             f"{WEBSITE}  •  Download Renance on Google Play")
    canvas.restoreState()


class Doc(BaseDocTemplate):
    header_text = ""


def render_course_pdf(dest: Path, school_full: str, school_short: str,
                      course_code: str, course_display: str, entries: list) -> dict:
    doc = Doc(str(dest), pagesize=A4,
              leftMargin=18 * mm, rightMargin=18 * mm,
              topMargin=22 * mm, bottomMargin=20 * mm,
              title=f"{school_short} {course_display} by Renance",
              author="Renance")
    doc.header_text = f"{course_display}  |  {school_short}"

    cover_frame = Frame(18 * mm, 16 * mm, 174 * mm, 265 * mm, id="cover")
    content_frame = Frame(18 * mm, 18 * mm, 174 * mm, 262 * mm, id="content")
    doc.addPageTemplates([
        PageTemplate(id="cover", frames=[cover_frame], onPage=cover_page_deco),
        PageTemplate(id="content", frames=[content_frame], onPage=header_footer),
    ])

    n_papers = len(entries)
    meta_lines = [
        f"Course: {course_display}",
        f"Institution: {school_full}",
        f"Papers in this pack: {n_papers}",
        f"Levels: {', '.join(sorted({str(e.get('level') or '—') for e in entries}))}",
    ]
    story = cover_flowables(school_full, course_display, meta_lines, n_papers, 0)

    for i, e in enumerate(entries, 1):
        story.append(Paragraph(
            f"Paper {i} of {n_papers} &mdash; {esc((e.get('name') or course_display)[:90])}",
            S_SECTION))
        story.append(Paragraph(
            f"Level {e.get('level') or '—'} • {esc(e.get('semester') or '')} • "
            f"{esc(e.get('category') or 'PastQuestion')}", S_META))
        story.append(HRFlowable(width="100%", thickness=0.4, color="black"))
        story.append(Spacer(1, 2 * mm))

        any_text = False
        for stem in e["stems"]:
            txt = clean_text(best_text(stem))
            if len(txt.strip()) >= 60:
                any_text = True
                for para in txt.split("\n"):
                    line = para.strip()
                    if not line:
                        story.append(Spacer(1, 1.2 * mm))
                        continue
                    # protect long sequences of spaces
                    line = re.sub(r" {2,}", "  ", line)
                    story.append(Paragraph(esc(line), S_BODY))
            if i < n_papers or stem != e["stems"][-1]:
                story.append(Spacer(1, 3 * mm))

        if not any_text:
            # no recoverable text: embed pages as grayscale images
            story.append(Paragraph(
                "This source paper is a scanned document; its pages are reproduced below.",
                S_META))
            tmpdir = Path(tempfile.mkdtemp(prefix="renpg_"))
            try:
                from reportlab.platypus import Image as RLImage
                src_pdf = (SRC / "hpdfs" / (e["stems"][0] + ".pdf")) if e["stems"][0].startswith("h-") else (PDF_DIR / (e["stems"][0] + ".pdf"))
                r = subprocess.run(
                    ["pdftoppm", "-r", "110", "-gray", "-jpeg", str(src_pdf),
                     str(tmpdir / "pg")], capture_output=True, timeout=420)
                pages = sorted(tmpdir.glob("pg-*"))
                for pi, pg in enumerate(pages[:60], 1):
                    story.append(RLImage(str(pg), width=165 * mm,
                                         height=230 * mm, kind="proportional"))
                    if pi < len(pages[:60]):
                        story.append(PageBreak())
            except Exception:  # noqa: BLE001
                story.append(Paragraph("(scanned pages could not be embedded)", S_META))
            # NOTE: tmpdir cleanup happens after doc.build() in render_course_pdf

        if i < n_papers:
            story.append(PageBreak())

    import shutil
    try:
        doc.build(story)
    finally:
        # clean up any image temp dirs created during story building
        for d in Path(tempfile.gettempdir()).glob("renpg_*"):
            shutil.rmtree(d, ignore_errors=True)
    return {"path": str(dest), "papers": n_papers,
            "size_kb": round(dest.stat().st_size / 1024, 1)}


def main() -> None:
    args = sys.argv[1:]
    groups = build_groups()
    if not args or args[0] == "--plan":
        total = 0
        for slug, g in sorted(groups.items()):
            courses = sorted(g["courses"].keys())
            total += len(courses)
            print(f"{g['short']:<14} {len(courses):>3} courses  ({', '.join(courses[:14])}{'…' if len(courses) > 14 else ''})")
        print(f"\nTOTAL course PDFs to generate: {total}")
        return
    if args[0] == "--school":
        slugs = [args[1]]
    else:
        slugs = sorted(groups.keys())
    report = []
    for slug in slugs:
        g = groups[slug]
        sdir = OUT_ROOT / slug
        sdir.mkdir(parents=True, exist_ok=True)
        for code in sorted(g["courses"].keys()):
            c = g["courses"][code]
            dest = sdir / f"{slug}-{code.lower()}-by-renance.pdf"
            try:
                r = render_course_pdf(dest, g["full"], g["short"], code,
                                      c["display"], c["entries"])
                r["course"] = code
                report.append(r)
                print(f"  {slug}/{code}: {r['papers']} papers, {r['size_kb']} KB", flush=True)
            except Exception as e:  # noqa: BLE001
                print(f"  {slug}/{code}: FAIL {str(e)[:90]}", flush=True)
    (OUT_ROOT / "gen_report.json").write_text(json.dumps(report, indent=1))
    print(f"\ngenerated: {len(report)} PDFs")


if __name__ == "__main__":
    main()
