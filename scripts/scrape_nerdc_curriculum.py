#!/usr/bin/env python3
"""Scrape the official NERDC curriculum PDFs off the NERDC LMIS portal.

Source: https://nerdc.gov.ng/content_manager/new_curriculum_home.html
which links the per-class portals at https://lmis.nerdcportals.com.ng/{level}.

For every level the portal publishes (pry_1..pry_5, jss_1..jss_2,
sss_1..sss_2 as of 2026-09), the script:
  1. parses the subject (or SSS field-of-study) table,
  2. resolves every "Click to View" entry to its PDF on the same portal,
  3. downloads the PDF, extracts the text with pypdf,
  4. pulls THEME / TOPIC lines into a scheme-shaped outline,
  5. writes one JSON per level plus an index into data/school-schemes/nerdc/.

Usage: python3 scripts/scrape_nerdc_curriculum.py [--download-dir DIR]
"""
import json
import os
import re
import subprocess
import sys
import time

BASE = "https://lmis.nerdcportals.com.ng"
LEVELS = [
    ("pry_1", "Primary 1", {}),
    ("pry_2", "Primary 2", {}),
    ("pry_4", "Primary 4", {}),
    ("pry_5", "Primary 5", {}),
    ("jss_1", "JSS 1", {}),
    ("jss_2", "JSS 2", {}),
    ("sss_1", "SSS 1", {
        "s1_core": "Core and Compulsory",
        "s1_science": "Science",
        "s1_humanities": "Humanities",
        "s1_business": "Business",
        "s1_trades": "Trades",
    }),
    ("sss_2", "SSS 2", {
        "s2_core": "Core and Compulsory",
        "s2_science": "Science",
        "s2_humanities": "Humanities",
        "s2_business": "Business",
        "s2_trades": "Trades",
    }),
]
OUT_DIR = "/home/z/my-project/renance/data/school-schemes/nerdc"

ROW = re.compile(
    r'<tr[^>]*>(?:(?!</tr>).)*?href="(' + re.escape(BASE) + r'/viewer/[^"]+)"(?:(?!</tr>).)*?</tr>',
    re.S,
)
CELL = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.S)
TAG = re.compile(r"<[^>]+>")
VIEWER_FILE = re.compile(r'necurrdc/viewer\.html\?file=([^"]+\.pdf)')


def fetch(url, binary=False, tries=3):
    """Fetch through curl: the portal's WAF rejects python-urllib handshakes."""
    last = None
    for attempt in range(tries):
        cmd = [
            "curl", "-sL", "--max-time", "420",
            "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            url,
        ]
        res = subprocess.run(cmd, capture_output=True)
        if res.returncode == 0 and res.stdout:
            return res.stdout if binary else res.stdout.decode("utf-8", "replace")
        last = f"curl exit {res.returncode}"
        time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"fetch failed {url}: {last}")


def clean(fragment):
    return " ".join(h.unescape(TAG.sub(" ", fragment)).split()) if (h := __import__("html")) else ""


def parse_rows(level_page):
    rows = []
    for m in ROW.finditer(level_page):
        cells = [clean(c) for c in CELL.findall(m.group(0))]
        name = next((c for c in cells if c and c.lower() not in ("click to view",) and not c[0].isdigit()), "")
        if not name:
            continue
        rows.append({"name": name, "viewer": m.group(1)})
    return rows


def resolve_pdf(viewer_url):
    page = fetch(viewer_url)
    m = VIEWER_FILE.search(page)
    if not m:
        return None
    # The iframe source is absolute like .../{level}/necurrdc/viewer.html?file=N.pdf
    root = re.match(r"(https://lmis\.nerdcportals\.com\.ng/[^/]+)/", viewer_url.replace("/viewer/", "/", 0))
    # viewer URL shape: {BASE}/viewer/{level}/{n}
    lm = re.match(re.escape(BASE) + r"/viewer/([^/]+)/\d+", viewer_url)
    level = lm.group(1) if lm else "unknown"
    return f"{BASE}/{level}/necurrdc/{m.group(1)}"


def pdf_text(data):
    import io
    from pypdf import PdfReader
    try:
        reader = PdfReader(io.BytesIO(data))
        pages = []
        for p in reader.pages:
            try:
                pages.append(p.extract_text() or "")
            except Exception:
                pages.append("")
        return pages, "\n".join(pages)
    except Exception as e:
        return [], f"__EXTRACT_ERROR__ {e}"


THEME = re.compile(r"(?:THEME|THEME\s*/?\s*DOMAIN|DOMAIN)\s*[0-9IVX]*\s*[:.]?\s*(.+)", re.I)
TOPIC = re.compile(r"(?:TOPIC|SUB\s*-?\s*THEME|UNIT)\s*[:.]?\s*(.+)", re.I)


def outline(text, limit=400):
    """Best-effort THEME/TOPIC outline from a NERDC curriculum PDF."""
    entries = []
    current = None
    for raw in text.splitlines():
        line = " ".join(raw.split())
        if not line or len(line) < 4:
            continue
        tm = THEME.match(line)
        pm = TOPIC.match(line)
        if tm and len(tm.group(1)) < 160 and not pm:
            current = tm.group(1).strip(" :-.")
            entries.append({"theme": current, "topics": []})
        elif pm and len(pm.group(1)) < 160:
            topic = pm.group(1).strip(" :-.")
            if entries:
                entries[-1]["topics"].append(topic)
            else:
                entries.append({"theme": "", "topics": [topic]})
        if len(entries) >= limit:
            break
    return entries


def plan(only=None):
    """Emit a TSV: slug<TAB>ordinal<TAB>subject<TAB>pdf_url."""
    os.makedirs(OUT_DIR, exist_ok=True)
    n = 0
    for slug, label, fields in LEVELS:
        if only and slug not in only:
            continue
        rows = []
        if fields:
            ordinal = 1
            for page_slug, field_name in fields.items():
                frows = parse_rows(fetch(f"{BASE}/{page_slug}"))
                for r in frows:
                    rows.append({"name": f"{r['name']} ({field_name})", "viewer": r["viewer"], "ordinal": ordinal})
                    ordinal += 1
                print(f"  {page_slug}: {len(frows)} subjects", file=sys.stderr)
        else:
            rows = [{"name": r["name"], "viewer": r["viewer"], "ordinal": i + 1}
                    for i, r in enumerate(parse_rows(fetch(f"{BASE}/{slug}")))]
        print(f"{slug} ({label}): {len(rows)} documents", file=sys.stderr)
        for row in rows:
            i = row["ordinal"]
            pdf_url = resolve_pdf(row["viewer"])
            if not pdf_url:
                print(f"  ! no pdf for {row['name']}", file=sys.stderr)
                continue
            fname = f"{slug}-{i:02d}-" + re.sub(r"[^a-z0-9]+", "-", row["name"].lower()).strip("-") + ".pdf"
            print(f"{fname}\t{slug}\t{label}\t{row['name']}\t{pdf_url}")
            n += 1
    print(f"planned {n} documents", file=sys.stderr)


def extract():
    """Build the level JSONs from whatever PDFs are already downloaded."""
    import glob
    os.makedirs(OUT_DIR, exist_ok=True)
    for slug, label, _fields in LEVELS:
        docs = []
        for fpath in sorted(glob.glob(os.path.join(OUT_DIR, "_pdf", f"{slug}-*.pdf"))):
            base = os.path.basename(fpath)[:-4]
            m = re.match(rf"{slug}-(\d+)-(.+)", base)
            if not m:
                continue
            name = m.group(2).replace("-", " ").title()
            # recover the real subject name from the plan cache if present
            for pslug, pname, pdf_url in PLAN_CACHE:
                if pslug == slug and re.sub(r"[^a-z0-9]+", "-", pname.lower()).strip("-") == m.group(2):
                    name, pdf_url = pname, pdf_url
                    break
            else:
                pdf_url = f"{BASE}/{slug}/necurrdc/unknown.pdf"
            with open(fpath, "rb") as fh:
                data = fh.read()
            pages, text = pdf_text(data)
            docs.append({
                "subject": name,
                "sourceUrl": pdf_url,
                "pages": len(pages),
                "file": base + ".pdf",
                "outline": outline(text) if pages else [],
                "text": re.sub(r"\n{3,}", "\n\n", text).strip() if pages else "",
            })
            print(f"  {slug} {name}: {len(pages)}p {len(data)//1024}KB outline={len(docs[-1]['outline'])}")
        if docs:
            with open(os.path.join(OUT_DIR, f"{slug}.json"), "w") as fh:
                json.dump({"level": slug, "label": label, "source": f"{BASE}/{slug}", "documents": docs}, fh, indent=1)
    # combined index
    index = []
    for slug, label, _fields in LEVELS:
        lpath = os.path.join(OUT_DIR, f"{slug}.json")
        if os.path.exists(lpath):
            with open(lpath) as fh:
                index.extend(json.load(fh)["documents"])
    with open(os.path.join(OUT_DIR, "index.json"), "w") as fh:
        json.dump({"source": "https://nerdc.gov.ng/content_manager/new_curriculum_home.html",
                   "portal": BASE, "scrapedOn": time.strftime("%Y-%m-%d"), "documents": index}, fh, indent=1)
    print(f"TOTAL documents: {len(index)}")


PLAN_CACHE = []


def load_plan_cache():
    """Cache subject-name/url pairs from the plan file (if produced)."""
    global PLAN_CACHE
    ppath = os.path.join(OUT_DIR, "plan.tsv")
    if os.path.exists(ppath):
        with open(ppath) as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 5:
                    PLAN_CACHE.append((parts[1], parts[3], parts[4]))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    dl_dir = os.path.join(OUT_DIR, "_pdf")
    os.makedirs(dl_dir, exist_ok=True)
    only = set(sys.argv[1:])
    index = []
    for slug, label, _fields in LEVELS:
        if only and slug not in only:
            continue
        page_url = f"{BASE}/{slug}"
        try:
            page = fetch(page_url)
        except RuntimeError as e:
            print(f"SKIP {slug}: {e}")
            continue
        rows = parse_rows(page)
        print(f"{slug} ({label}): {len(rows)} documents")
        docs = []
        for i, row in enumerate(rows, 1):
            pdf_url = resolve_pdf(row["viewer"])
            if not pdf_url:
                print(f"  ! no pdf for {row['name']}")
                continue
            fname = f"{slug}-{i:02d}-" + re.sub(r"[^a-z0-9]+", "-", row["name"].lower()).strip("-") + ".pdf"
            fpath = os.path.join(dl_dir, fname)
            if os.path.exists(fpath) and os.path.getsize(fpath) > 1000:
                data = open(fpath, "rb").read()
            else:
                data = fetch(pdf_url, binary=True)
                with open(fpath, "wb") as fh:
                    fh.write(data)
                time.sleep(1.0)
            pages, text = pdf_text(data)
            docs.append({
                "subject": row["name"],
                "sourceUrl": pdf_url,
                "pages": len(pages),
                "file": fname,
                "outline": outline(text) if pages else [],
                "textChars": len(text),
            })
            print(f"  {i:2d}. {row['name']} -> {len(pages)} pages, {len(data)//1024} KB")
            index.append({"level": slug, "levelLabel": label, **docs[-1]})
        with open(os.path.join(OUT_DIR, f"{slug}.json"), "w") as fh:
            json.dump({"level": slug, "label": label, "source": page_url, "documents": docs}, fh, indent=1)
    # Rebuild the combined index from every level file present so partial
    # per-level runs keep the whole picture in sync.
    index = []
    for slug, label, _fields in LEVELS:
        lpath = os.path.join(OUT_DIR, f"{slug}.json")
        if os.path.exists(lpath):
            with open(lpath) as fh:
                index.extend(json.load(fh)["documents"])
    with open(os.path.join(OUT_DIR, "index.json"), "w") as fh:
        json.dump({"source": "https://nerdc.gov.ng/content_manager/new_curriculum_home.html",
                   "portal": BASE, "scrapedOn": time.strftime("%Y-%m-%d"), "documents": index}, fh, indent=1)
    print(f"TOTAL documents: {len(index)}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode == "plan":
        plan(set(sys.argv[2:]) or None)
    elif mode == "extract":
        load_plan_cache()
        extract()
    else:
        main()
