#!/usr/bin/env python3
"""
Bake the CBT content into the web static export.

GitHub Pages serves the site from a CDN; the study API (Render free
tier) cold-starts. So the web build ships every manifest pack as a
static JSON file under apps/web/public/bundles/ plus the manifest
itself, and the client reads them same-origin first, API second.

Founder directive 2026-09 (supersedes the export-side ADR-0003 strip):
the answers and explanations now LIVE in the question JSON, and the
static export ships them so the browser can grade papers on-device —
signed-out students, offline sittings and API cold starts included.
Raw key-side shapes (answers dumps, correct_letter maps, ...) are still
stripped recursively; only the per-question `answer` / `explanation` /
`video` / `answer_image` fields survive.

Usage:  python3 scripts/web_bundles.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_school_corpus import main as bake_school_corpus  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "data"
OUT = REPO / "apps" / "web" / "public" / "bundles"

# Raw key-side shapes that must never reach a student-visible bundle,
# even though each question now carries its own `answer` / `explanation`
# (the server-side API still sanitises those per-question fields for its
# own responses; the static export is the offline grading source).
FORBIDDEN = {
    "answers", "answer_key", "answerkey",
    "correct", "correct_answer", "correctletter", "correct_letter",
    "correctoption", "correct_option",
    "explanations", "iscorrect", "is_correct",
}


def load_index():
    """code -> relative path under data/questions (founder's grouped layout)."""
    idx = DATA / "questions" / "index.json"
    if idx.exists():
        return json.loads(idx.read_text(encoding="utf-8"))
    return {}


INDEX = load_index()


def bundle_path(code: str) -> Path | None:
    """Resolve a bank code to its question-JSON file.

    Primary source: data/questions/index.json (the grouped layout:
    JAMB/, NECO/, WAEC/, POST_UTME/, All_tertiary_Q/<SCHOOL>/).
    Falls back to the flat layout for local flexibility.
    """
    q = DATA / "questions"
    rel = INDEX.get(code)
    if rel:
        p = q / rel
        if p.exists():
            return p
    flat = q / f"{code}.json"
    if flat.exists():
        return flat
    m = re.fullmatch(r"waec-(.+?)-bank", code)
    if m:
        p = q / "WAEC" / f"{m.group(1)}.json"
        if p.exists():
            return p
    m = re.fullmatch(r"waec-(.+?)-theory", code)
    if m:
        p = q / "WAEC" / f"{m.group(1)}-theory.json"
        if p.exists():
            return p
    m = re.fullmatch(r"uni-([a-z0-9-]+?)-([a-z0-9]+?)-bank", code)
    if m:
        p = q / "All_tertiary_Q" / m.group(1).upper() / f"{m.group(2).upper()}.json"
        if p.exists():
            return p
    return None


def strip_answers(node):
    """Recursively drop answer-material keys; returns (clean, dropped)."""
    if isinstance(node, dict):
        clean = {}
        dropped = 0
        for k, v in node.items():
            if k.lower() in FORBIDDEN:
                dropped += 1
                continue
            c, d = strip_answers(v)
            clean[k] = c
            dropped += d
        return clean, dropped
    if isinstance(node, list):
        out = []
        dropped = 0
        for item in node:
            c, d = strip_answers(item)
            out.append(c)
            dropped += d
        return out, dropped
    return node, 0


def main() -> int:
    manifest_path = DATA / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)

    total_in = 0
    total_out = 0
    missing = []
    stripped_keys = 0
    written = 0

    for exam in manifest["exams"]:
        code = exam["code"]
        src = bundle_path(code)
        if src is None:
            missing.append(code)
            continue
        raw = src.read_text(encoding="utf-8")
        bundle = json.loads(raw)
        clean, dropped = strip_answers(bundle)
        stripped_keys += dropped
        # Fill serve-side meta the client's Bundle type expects.
        for field in ("durationMinutes", "category", "body"):
            if clean.get(field) is None and exam.get(field) is not None:
                clean[field] = exam[field]
        data = json.dumps(clean, ensure_ascii=False, separators=(",", ":"))
        (OUT / f"{code}.json").write_text(data, encoding="utf-8")
        total_in += len(raw.encode("utf-8"))
        total_out += len(data.encode("utf-8"))
        written += 1

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    bake_routes_manifest()
    bake_school_corpus()

    print(f"baked {written}/{len(manifest['exams'])} bundles -> {OUT}")
    print(f"stripped {stripped_keys} answer-material keys")
    print(f"bundle bytes: {total_in / 1e6:.1f} MB pretty -> {total_out / 1e6:.1f} MB minified")
    if missing:
        print("MISSING source files for:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


def bake_routes_manifest() -> None:
    """Drop a minimal routes manifest into public/ so the static export
    carries it in out().

    Why: Vercel's Next.js preset finishes every build by reading
    <outputDirectory>/routes-manifest.json. A static export never writes
    that file into out/, so a correctly-built site still failed the deploy
    with the now-next-routes-manifest error. Files placed in public/ are
    copied verbatim into the export, so baking one here makes the manifest
    exist exactly where the platform looks for it. Harmless on GitHub
    Pages (it is just a small JSON file in the CDN).
    """
    manifest = {
        "version": 3,
        "pages404": True,
        "caseSensitive": False,
        "trailingSlash": True,
        "basePath": "",
        "i18n": None,
        "overrides": {},
        "dynamicRoutes": [],
        "staticRoutes": [],
        "dataRoutes": [],
        "redirects": [],
        "rewrites": {"beforeFiles": [], "afterFiles": [], "fallback": []},
        "hasRewrites": False,
        "headers": [],
    }
    dest = REPO / "apps" / "web" / "public" / "routes-manifest.json"
    dest.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


if __name__ == "__main__":
    sys.exit(main())
