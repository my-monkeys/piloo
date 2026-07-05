#!/usr/bin/env python3
"""Injecte le base64 de la capture + les icônes SVG (lucide) dans un source HTML → build.

Usage :
  python3 build_html.py                          # index.html → index.built.html (FR)
  python3 build_html.py index.en.html index.en.built.html   # variante (EN)
"""
import base64, pathlib, re, sys

HERE = pathlib.Path(__file__).parent
SRC_NAME = sys.argv[1] if len(sys.argv) > 1 else "index.html"
OUT_NAME = sys.argv[2] if len(sys.argv) > 2 else "index.built.html"
src = (HERE / SRC_NAME).read_text(encoding="utf-8")

# --- images ---
def img_b64(name):
    return base64.b64encode((HERE / "assets" / name).read_bytes()).decode()

b64 = img_b64("landing.jpg")
today_b64 = img_b64("mobile-today.jpg")
officine_b64 = img_b64("mobile-officine.jpg")

def svg(paths, w=20, h=20):
    return (f'<svg width="{w}" height="{h}" viewBox="0 0 24 24" fill="none" '
            f'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
            f'stroke-linejoin="round" aria-hidden="true">{paths}</svg>')

ICONS = {
    "__IC_SCAN__": svg('<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><path d="M7 12h10"/>'),
    "__IC_BOX__": svg('<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="M3.3 7 12 12l8.7-5"/><path d="M12 22V12"/>'),
    "__IC_CLOCK__": svg('<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>'),
    "__IC_DOC__": svg('<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/>'),
    "__IC_BELL__": svg('<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>'),
    "__IC_USERS__": svg('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>'),
    "__IC_STETH__": svg('<path d="M11 2v2"/><path d="M5 2v2"/><path d="M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1"/><path d="M8 15a6 6 0 0 0 12 0v-3"/><circle cx="20" cy="10" r="2"/>'),
    "__IC_WIFI__": svg('<path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.86a10 10 0 0 1 14 0"/><path d="M8.5 16.43a5 5 0 0 1 7 0"/>'),
    "__IC_DB__": svg('<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>'),
    "__IC_PILL__": svg('<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/>', 22, 22),
    "__IC_PILL_SM__": svg('<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/>', 18, 18),
    "__IC_SEARCH__": svg('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>', 18, 18),
    "__IC_INFO__": svg('<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>', 16, 16),
    "__IC_WARN__": svg('<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/>', 22, 22),
    "__IC_SPARK__": svg('<path d="M12 3v4"/><path d="M12 17v4"/><path d="M3 12h4"/><path d="M17 12h4"/><path d="m6 6 2.5 2.5"/><path d="m15.5 15.5 2.5 2.5"/><path d="m18 6-2.5 2.5"/><path d="m8.5 15.5-2.5 2.5"/>', 14, 14),
}

out = src.replace("__LANDING_B64__", b64)
out = out.replace("__TODAY_B64__", today_b64)
out = out.replace("__OFFICINE_B64__", officine_b64)
for k, v in ICONS.items():
    out = out.replace(k, v)

# Rendu robuste quel que soit le charset servi : accents & symboles → entités
# HTML numériques (ASCII). CSS/JS/base64 sont déjà 100% ASCII, donc sans risque.
out = out.encode("ascii", "xmlcharrefreplace").decode("ascii")

# garde-fou : aucun placeholder oublié
leftover = re.findall(r"__[A-Z0-9_]+__", out)
if leftover:
    raise SystemExit(f"Placeholders non résolus: {set(leftover)}")

(HERE / OUT_NAME).write_text(out, encoding="utf-8")
print("OK →", (HERE / OUT_NAME), f"({len(out)//1024} KB)")
