#!/usr/bin/env python3
"""Vercel entry for the bundle bake.

The Vercel project builds with apps/web as the working directory, so the
root-level invocation `python3 scripts/web_bundles.py` resolves here
first. The single source of truth stays at the repo root; this shim just
hands over to it. The root script is working-directory independent (every
path is derived from its own __file__), so handing over is safe from any
cwd.

Usage:  python3 scripts/web_bundles.py   # from apps/web or the repo root
"""
import runpy
import sys
from pathlib import Path

SHIM = Path(__file__).resolve()
ROOT_SCRIPT = SHIM.parents[3] / "scripts" / "web_bundles.py"

if not ROOT_SCRIPT.exists():
    sys.exit(f"web_bundles shim: root script not found at {ROOT_SCRIPT}")

# run_name="__main__" so the root script's main() runs; its sys.exit()
# propagates the real exit code (it fails the build when a bundle source
# is missing, which is exactly what we want on Vercel).
runpy.run_path(str(ROOT_SCRIPT), run_name="__main__")
