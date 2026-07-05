#!/usr/bin/env python3
"""Emballe un build (index*.built.html) en document HTML autonome prêt pour
l'impression PDF : thème clair forcé, sections `[reveal]` rendues visibles
(sinon l'IntersectionObserver ne fire pas en headless → pages blanches),
et règles @page / break-inside pour une pagination propre.

Usage : python3 make_print_html.py <built.html> <out.print.html> <lang>
"""
import pathlib, sys

HERE = pathlib.Path(__file__).parent
built = (HERE / sys.argv[1]).read_text(encoding="utf-8")
out_name = sys.argv[2]
lang = sys.argv[3] if len(sys.argv) > 3 else "fr"

PRINT_CSS = """
  /* --- Overrides impression PDF --- */
  html, body { background: #ffffff !important; }
  [reveal] { opacity: 1 !important; transform: none !important; transition: none !important; }
  .search .cursor { animation: none !important; }
  header.site { position: static !important; backdrop-filter: none !important; }
  @page { margin: 14mm; }
  section { padding: 40px 0 !important; }
  .card, .mock, .phone-fig, .screen, .callout, .notplace, .result, .alert-row, figure {
    break-inside: avoid;
  }
  h1, h2, h3 { break-after: avoid; }
"""

doc = (
    f"<!doctype html>\n<html lang=\"{lang}\" data-theme=\"light\">\n<head>\n"
    "<meta charset=\"utf-8\">\n"
    "<meta name=\"viewport\" content=\"width=1000\">\n"
    f"<style>{PRINT_CSS}</style>\n"
    "</head>\n<body>\n"
    f"{built}\n"
    "</body>\n</html>\n"
)

(HERE / out_name).write_text(doc, encoding="utf-8")
print("OK →", out_name, f"({len(doc)//1024} KB)")
