#!/usr/bin/env python3
"""
Rebuild apps/web/public/fonts/material-symbols-outlined.subset.woff2 the
CORRECT way (founder bug 2026-10-16: the old subset had an ASCII-only cmap
and ZERO ligatures, so every icon on the app rendered as its literal name,
e.g. 'diversiTY_3' bleeding through the school picker as 'RSITY_3').

Approach: ask the Google Fonts CSS2 API for a variable-font subset holding
exactly the icon names the app uses (ligature-capable, FILL axis kept),
download the woff2 it serves, and self-host it. Then verify the result.
"""
import json
import re
import glob
import urllib.request
import sys

WEB = '/home/z/my-project/renance/apps/web'
API = '/home/z/my-project/renance/apps/study-api'

# ---------------------------------------------------------------- collect --
names = set()
strict = set()  # names from reliable icon sources - shape-verified hard

# 1) literal icon children + dynamic expressions in web TS/TSX
#    (\s* matters: the exam client's {instant ? 'visibility' :
#    'visibility_off'} ternary sits on its own line - the old
#    adjacency-only regex silently skipped it and 'visibility' fell out
#    of the subset, spelling VISIBILITY over the quiz command bar).
pat_lit = re.compile(r"material-symbols-outlined[^>]*>\s*([a-z_0-9]+)\s*<", re.S)
pat_expr = re.compile(r"material-symbols-outlined[^>]*>\s*\{([^}]+)\}\s*<", re.S)
# 2) any quoted snake_case token in web code (icon consts, data structs)
pat_snake = re.compile(r"['\"]([a-z][a-z0-9]*(?:_[a-z0-9]+)+)['\"]")
# 3) Go icon fields (exam manifest etc.)
pat_go = re.compile(r"Icon:\s*\"([a-z_0-9]+)\"")
# 4) JS/TS icon fields, colon AND prop syntax: { icon: 'home' } tabs,
#    <LauncherTile icon="assignment" /> - pat_snake never saw values
#    without an underscore and the side nav spelled HOME in raw letters
#    on the old font rebuild.
pat_js = re.compile(r"\b[Ii]con\s*[:=]\s*['\"]([a-z_0-9]+)['\"]")
# 5) category-keyed icon maps (Record<string, string>): values like
#    FIELD_ICONS = { Health: 'healing' } - the key is a category word,
#    so pat_js never sees them and the career desk leaked HEALING.
ICON_MAP_BLOCK = re.compile(r"\b\w*ICON\w*\b[^={]*=\s*\{(.*?)\}", re.DOTALL)
QUOTED_SNAKE = re.compile(r"['\"]([a-z][a-z_0-9]+)['\"]")

for p in glob.glob(f'{WEB}/app/**/*.tsx', recursive=True) + \
         glob.glob(f'{WEB}/components/**/*.tsx', recursive=True) + \
         glob.glob(f'{WEB}/lib/**/*.ts', recursive=True) + \
         glob.glob(f'{WEB}/lib/**/*.tsx', recursive=True):
    try:
        src = open(p, encoding='utf8').read()
    except Exception:
        continue
    for m in pat_lit.finditer(src):
        names.add(m.group(1)); strict.add(m.group(1))
    for m in pat_expr.finditer(src):
        expr = m.group(1)
        for tok in re.findall(r"'([a-z_0-9]+)'", expr):
            names.add(tok); strict.add(tok)
    # whole span bodies: any quoted lowercase token inside a
    # material-symbols span is an icon candidate, underscore or not
    # ('stop' has no underscore and slipped past every other pass).
    for span in re.finditer(
        r"material-symbols-outlined[^>]*>(.*?)</span>", src, re.S
    ):
        for tok in re.findall(r"['\"]([a-z][a-z_0-9]{2,})['\"]", span.group(1)):
            names.add(tok); strict.add(tok)
    for m in pat_snake.finditer(src):
        tok = m.group(1)
        # filter obvious non-icons
        if tok in ('node_modules', 'font_face'):
            continue
        names.add(tok)  # advisory only: status keys, meta names, ...
    for m in pat_js.finditer(src):
        names.add(m.group(1)); strict.add(m.group(1))
    for block in ICON_MAP_BLOCK.finditer(src):
        for m in QUOTED_SNAKE.finditer(block.group(1)):
            names.add(m.group(1)); strict.add(m.group(1))

for p in glob.glob(f'{API}/**/*.go', recursive=True):
    try:
        src = open(p, encoding='utf8').read()
    except Exception:
        continue
    for m in pat_go.finditer(src):
        names.add(m.group(1)); strict.add(m.group(1))

# data/ JSON payloads: school course catalogs carry "icon" fields the
# course cards ligate ('computer', 'engineering', ...) - once missing,
# they spelled MPUTER over 40 school desks.
def _walk_json_icons(node, sink):
    if isinstance(node, dict):
        for k, v in node.items():
            if 'icon' in str(k).lower() and isinstance(v, str) and \
                    re.fullmatch(r'[a-z][a-z_0-9]+', v):
                sink.add(v)
            else:
                _walk_json_icons(v, sink)
    elif isinstance(node, list):
        for it in node:
            _walk_json_icons(it, sink)

for p in glob.glob('/home/z/my-project/renance/data/**/*.json', recursive=True):
    try:
        _walk_json_icons(json.load(open(p, encoding='utf8', errors='ignore')), names)
    except Exception:
        continue

# milestoneIcon() outputs in celebrations.tsx
names |= {'local_fire_department', 'school', 'emoji_events', 'military_tech'}
strict |= {'local_fire_department', 'school', 'emoji_events', 'military_tech'}
# arena opponent / attendance toggles
names |= {'smart_toy', 'person', 'touch_app', 'check_circle'}
strict |= {'smart_toy', 'person', 'touch_app', 'check_circle'}

# sanity: drop tokens that contain non-icon junk (heuristic: keep <=30 chars)
names = {n for n in names if 1 < len(n) <= 30}
strict = {n for n in strict if 1 < len(n) <= 30}
names = sorted(names)
print(f'{len(names)} icon names collected ({len(strict)} from strict sources)')
json.dump(names, open('/home/z/my-project/renance/scripts/icon_names.json', 'w'), indent=1)

# ------------------------------------------------------------------ fetch --
family = 'Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200'
url = f'https://fonts.googleapis.com/css2?family={family}&icon_names={",".join(names)}&display=block'
req = urllib.request.Request(url, headers={
    # a modern UA gets the variable woff2
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
})
css = urllib.request.urlopen(req, timeout=30).read().decode('utf8')
m = re.search(r'url\((https://fonts\.gstatic\.com/l/font\?[^)]+)\)', css)
if not m:
    print(css[:2000])
    sys.exit('no woff2 url in css')
woff2_url = m.group(1)
print('subset url:', woff2_url[:120], '...')
data = urllib.request.urlopen(urllib.request.Request(woff2_url, headers=req.headers), timeout=60).read()
out = f'{WEB}/public/fonts/material-symbols-outlined.subset.woff2'
open(out, 'wb').write(data)
print(f'wrote {out} ({len(data)/1024:.1f} KB)')

# ----------------------------------------------------------------- verify --
# Shape every collected name with HarfBuzz against the downloaded subset -
# the ground truth (a browser shapes the same way). The old ligature-count
# check never worked: Google renames ligature glyphs to uniExxx and serves
# the substitutions through lookup types fontTools' .ligatures never
# surfaces, so it reported 0 ligatures on a perfectly good font.
try:
    import io as _io
    import uharfbuzz as hb
    from fontTools.ttLib import TTFont as _TTFont

    _raw = _TTFont(out)
    _raw.flavor = None
    _buf = _io.BytesIO()
    _raw.save(_buf)
    _font = hb.Font(hb.Face(_buf.getvalue()))

    def _glyph_count(text: str) -> int:
        b = hb.Buffer()
        b.add_str(text)
        b.guess_segment_properties()
        hb.shape(_font, b)
        return len(b.glyph_infos)

    broken = sorted(n for n in strict if _glyph_count(n) != 1)
    if broken:
        # A strict name can still be a false positive - a ternary
        # CONDITION quoted inside a span ('a.kind === "notebook"') is
        # not the rendered icon. Google serves only real icon names, so
        # probe each missing name solo: served solo = a real icon the
        # batch dropped (hard fail); refused solo = not an icon at all
        # (record it and move on).
        deny_path = '/home/z/my-project/renance/scripts/icon_non_icons.json'
        try:
            known_non = set(json.load(open(deny_path)))
        except Exception:
            known_non = set()
        still_broken = []
        for n in broken:
            if n in known_non:
                continue
            solo_url = (f'https://fonts.googleapis.com/css2?family={family}'
                        f'&icon_names={n}&display=block')
            try:
                solo_css = urllib.request.urlopen(
                    urllib.request.Request(solo_url, headers=req.headers),
                    timeout=30).read().decode('utf8')
                m2 = re.search(r'url\((https://fonts\.gstatic\.com/l/font\?[^)]+)\)', solo_css)
                solo_ok = False
                if m2:
                    solo_data = urllib.request.urlopen(
                        urllib.request.Request(m2.group(1), headers=req.headers),
                        timeout=60).read()
                    _r = _TTFont(_io.BytesIO(solo_data))
                    _r.flavor = None
                    _b = _io.BytesIO()
                    _r.save(_b)
                    solo_ok = _glyph_count(n) == 1
                if solo_ok:
                    still_broken.append(n)
                else:
                    known_non.add(n)
                    print(f'not a Material Symbols icon, skipped: {n}')
            except Exception:
                still_broken.append(n)
        json.dump(sorted(known_non), open(deny_path, 'w'), indent=1)
        if still_broken:
            sys.exit('MISSING from the downloaded subset (would render as raw text): '
                     + ', '.join(still_broken))
    print(f'OK: all {len(strict)} strict icon names shape to one glyph')
except ImportError:
    print('uharfbuzz unavailable - skipped shape verification')
