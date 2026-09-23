#!/usr/bin/env python3
"""no_long_hyphen - enforce the founder content rule: Renance never ships
the long hyphen. Em dashes, en dashes and visible double hyphens in
user-facing content become a single plain hyphen.

Fix mode (default):  python3 scripts/no_long_hyphen.py           # rewrite files
Check mode (CI):     python3 scripts/no_long_hyphen.py --check   # exit 1 on violation

Scope: shipped content only. Code semantics are preserved:
  - CSS custom properties (--color-x) are never touched
  - decrement operators (i--, --i) are never touched
  - SQL comments inside Go/SQL files are developer-facing and skipped
  - markdown code fences are skipped
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# long-dash characters: em, en, figure, horizontal bar, non-breaking hyphen
DASH_CHARS = "\u2010\u2012\u2013\u2014\u2015"
DASH_RE = re.compile("[" + DASH_CHARS + "]")

TSX_GLOBS = ["apps/web/**/*.ts", "apps/web/**/*.tsx", "apps/web/**/*.md"]
DART_GLOBS = ["apps/mobile/lib/**/*.dart"]
GO_GLOBS = ["apps/study-api/**/*.go"]
DATA_GLOBS = [
    "data/**/*.json",
    "data/**/*.md",
    "docs/**/*.md",
    "README.md",
    "apps/web/public/**/*.txt",
]

# `--` inside a quoted string on a single line (user-visible), while the
# line does not look like a decrement or a CSS variable.
STRING_RE = re.compile(r"""(['"`])((?:\\.|(?!\1).)*?--(?:(?!\1).)*?)\1""")
DECREMENT_RE = re.compile(r"--\s*[;,\)\]}]|[\w\)\]]--|--\s*[\w\$]")
CSSVAR_RE = re.compile("--[a-zA-Z][\\w-]*\\s*:")
DASH_ONLY_RE = re.compile(r"^\s*[-\s]*$")  # '---' frontmatter delimiters in code
MARKDOWN_FENCE_RE = re.compile(r"```")
SQL_LINE_RE = re.compile(r"^\s*--")
HR_LINE_RE = re.compile(r"^\s*(:?-{3,}\s*)$")
TABLE_SEP_RE = re.compile(r"^\s*\|[\s:|-]+\|?\s*$")


def fix_dashes(text: str) -> str:
    return DASH_RE.sub("-", text)


def visible_double_hyphens(text: str, lang: str):
    """Yield (line_no, line) where a quoted string contains '--'."""
    fence_open = False
    for i, line in enumerate(text.splitlines(), 1):
        if lang == "md":
            if MARKDOWN_FENCE_RE.search(line):
                fence_open = not fence_open
                continue
            if fence_open or SQL_LINE_RE.match(line):
                continue
            if "--" in line:
                yield i, line
            continue
        if DECREMENT_RE.search(line) or CSSVAR_RE.search(line):
            continue
        for m in STRING_RE.finditer(line):
            inner = m.group(2)
            if "--" in inner and not DASH_ONLY_RE.match(inner):
                yield i, line
                break


def iter_files(globs):
    seen = set()
    for g in globs:
        for p in REPO.glob(g):
            if p.is_file() and not p.is_symlink():
                s = str(p)
                if s not in seen:
                    seen.add(s)
                    yield p


def main():
    check = "--check" in sys.argv
    problems = []

    for p in iter_files(TSX_GLOBS + DART_GLOBS + GO_GLOBS + DATA_GLOBS):
        rel = p.relative_to(REPO)
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, IsADirectoryError):
            continue
        lang = "md" if p.suffix in {".md"} else None
        original = text

        # 1. every long-dash char becomes a plain hyphen (any file kind)
        text = fix_dashes(text)

        # 2. visible '--' in content
        if lang == "md":
            fence_open = False
            in_frontmatter = p.suffix == ".md" and text.startswith("---")
            fm_count = 0
            fixed_lines = []
            for line in text.splitlines(keepends=True):
                stripped = line.rstrip("\n")
                if MARKDOWN_FENCE_RE.search(stripped):
                    fence_open = not fence_open
                    fixed_lines.append(line)
                    continue
                if fence_open:
                    fixed_lines.append(line)
                    continue
                if in_frontmatter:
                    # the opening/closing --- delimiters of YAML frontmatter
                    if HR_LINE_RE.match(stripped):
                        fm_count += 1
                        if fm_count == 2:
                            in_frontmatter = False
                        fixed_lines.append(line)
                        continue
                    fixed_lines.append(line)
                    continue
                # structural: horizontal rules and table separator rows
                if HR_LINE_RE.match(stripped) or TABLE_SEP_RE.match(stripped):
                    fixed_lines.append(line)
                    continue
                parts = stripped.split("`")
                changed = False
                for i in range(0, len(parts), 2):  # even indices = outside code
                    if "--" in parts[i]:
                        problems.append(
                            f"{rel}: visible '--' in prose: {stripped.strip()[:90]}"
                        )
                        parts[i] = parts[i].replace("--", "-")
                        changed = True
                if changed:
                    fixed_lines.append("`".join(parts) + line[len(stripped):])
                else:
                    fixed_lines.append(line)
            text = "".join(fixed_lines)
        elif p.suffix in {".json"}:
            # data files: '--' anywhere in a value is content. Provenance
            # metadata (_sources.json) carries repo slugs and URLs where
            # '--' is a real identifier, so those files are exempt.
            exempt = "_sources.json" == p.name
            for i, line in enumerate(text.splitlines(), 1):
                if "--" in line and '"' in line and not exempt:
                    problems.append(f"{rel}:{i}: visible '--' in data: {line.strip()[:90]}")
            if not exempt:
                text = text.replace("--", "-")
        else:
            for i, line in visible_double_hyphens(text, lang or "code"):
                problems.append(f"{rel}:{i}: visible '--' in string: {line.strip()[:90]}")

        if text != original:
            if check:
                problems.append(f"{rel}: long-dash characters present")
            else:
                p.write_text(text, encoding="utf-8")
                print(f"fixed {rel}")

    # JSON validity guard after rewriting data files
    for p in iter_files(["data/**/*.json"]):
        try:
            json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            problems.append(f"{p.relative_to(REPO)}: JSON now invalid: {e}")

    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} problem(s)")
        sys.exit(1)
    print("OK: no long hyphens in shipped content." if check else "Sweep complete.")


if __name__ == "__main__":
    main()
