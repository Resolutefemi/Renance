#!/usr/bin/env python3
"""Render scripts/og/og-2026.html into the OG card files.

Screenshot at 2x for crisp text, downscale to exactly 1200x630, write:
  apps/web/public/og-2026.jpg  (the canonical, cache-busting card)
  apps/web/public/og.jpg       (kept fresh for every existing link)
  apps/web/public/og.png       (kept fresh for older scrapers)
"""
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

REPO = Path("/home/z/my-project/renance")
SRC = REPO / "scripts" / "og" / "og-2026.html"
OUT = REPO / "apps" / "web" / "public"


def main():
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(
            viewport={"width": 1200, "height": 630}, device_scale_factor=2
        )
        page.goto(SRC.as_uri())
        page.wait_for_timeout(400)  # let the webfonts settle
        page.screenshot(path="/tmp/og-2x.png")
        browser.close()

    img = Image.open("/tmp/og-2x.png").convert("RGB")
    if img.size != (2400, 1260):
        img = img.resize((2400, 1260), Image.LANCZOS)
    img = img.resize((1200, 630), Image.LANCZOS)
    img.save(OUT / "og-2026.jpg", "JPEG", quality=90, optimize=True, progressive=True)
    img.save(OUT / "og.jpg", "JPEG", quality=90, optimize=True, progressive=True)
    img.save(OUT / "og.png", "PNG", optimize=True)
    for name in ("og-2026.jpg", "og.jpg", "og.png"):
        p = OUT / name
        print(f"{p.name}: {p.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
