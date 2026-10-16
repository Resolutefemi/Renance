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

# 1) literal icon children + dynamic expressions in web TS/TSX
pat_lit = re.compile(r"material-symbols-outlined[^>]*>\s*([a-z_0-9]+)\s*<", re.S)
pat_expr = re.compile(r"material-symbols-outlined[^>]*>\{([^}]+)\}<", re.S)
# 2) any quoted snake_case token in web code (icon consts, data structs)
pat_snake = re.compile(r"['\"]([a-z][a-z0-9]*(?:_[a-z0-9]+)+)['\"]")
# 3) Go icon fields (exam manifest etc.)
pat_go = re.compile(r"Icon:\s*\"([a-z_0-9]+)\"")

for p in glob.glob(f'{WEB}/app/**/*.tsx', recursive=True) + \
         glob.glob(f'{WEB}/components/**/*.tsx', recursive=True) + \
         glob.glob(f'{WEB}/lib/**/*.ts', recursive=True) + \
         glob.glob(f'{WEB}/lib/**/*.tsx', recursive=True):
    try:
        src = open(p, encoding='utf8').read()
    except Exception:
        continue
    for m in pat_lit.finditer(src):
        names.add(m.group(1))
    for m in pat_expr.finditer(src):
        expr = m.group(1)
        for tok in re.findall(r"'([a-z_0-9]+)'", expr):
            names.add(tok)
    for m in pat_snake.finditer(src):
        tok = m.group(1)
        # filter obvious non-icons
        if tok in ('node_modules', 'font_face'):
            continue
        names.add(tok)

for p in glob.glob(f'{API}/**/*.go', recursive=True):
    try:
        src = open(p, encoding='utf8').read()
    except Exception:
        continue
    for m in pat_go.finditer(src):
        names.add(m.group(1))

# milestoneIcon() outputs in celebrations.tsx
names |= {'local_fire_department', 'school', 'emoji_events', 'military_tech'}
# arena opponent / attendance toggles
names |= {'smart_toy', 'person', 'touch_app', 'check_circle'}

# sanity: drop tokens that contain non-icon junk (heuristic: keep <=30 chars)
names = {n for n in names if 1 < len(n) <= 30}
names = sorted(names)
print(f'{len(names)} icon names collected')
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
from fontTools.ttLib import TTFont
f = TTFont(out)
cmap = f.getBestCmap()
gsub = f['GSUB'].table
lig_glyphs = set()
n_lig = 0
for lookup in gsub.LookupList.Lookup:
    for st in lookup.SubTable:
        if hasattr(st, 'ligatures'):
            for _, ligs in st.ligatures.items():
                for lig in ligs:
                    n_lig += 1
                    lig_glyphs.add(lig.LigGlyph)
glyph_order = set(f.getGlyphOrder())
print(f'ligature substitutions: {n_lig}, distinct icon glyphs: {len(lig_glyphs)}')
print(f'icon glyphs present in font: {len(lig_glyphs & glyph_order)}')
assert n_lig >= len(names) * 0.9, 'missing ligatures - subset wrong'
print('OK: ligature-capable subset installed')
