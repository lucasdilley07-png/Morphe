#!/usr/bin/env python3
"""PRIVACY_POLICY.md → docs/privacy.html, in the Spartan page style.

The policy's markdown is the source of truth; the web page is generated,
never hand-edited. Supports what the policy uses: #/## headings, bold,
links, bullet lists, paragraphs. Run after every policy change:

    python3 Tools/build_privacy_page.py
"""
import html, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "PRIVACY_POLICY.md"
OUT = ROOT / "docs/privacy.html"

def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"(?<![\w\"=/])((?:https?://|mailto:)[^\s<)]+)", r'<a href="\1">\1</a>', text)
    text = re.sub(r"(?<![\w\"/@])([\w.+-]+@[\w-]+\.[\w.-]+)", r'<a href="mailto:\1">\1</a>', text)
    return text

def convert(md):
    out, para, items = [], [], []
    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>"); para.clear()
    def flush_list():
        if items:
            out.append("<ul>" + "".join("<li>" + inline(i) + "</li>" for i in items) + "</ul>"); items.clear()
    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush_para(); flush_list(); continue
        if line.startswith("# "):
            flush_para(); flush_list(); out.append("<h1>" + inline(line[2:]) + "</h1>"); continue
        if line.startswith("## "):
            flush_para(); flush_list(); out.append("<h2>" + inline(line[3:]) + "</h2>"); continue
        if line.startswith("### "):
            flush_para(); flush_list(); out.append("<h3>" + inline(line[4:]) + "</h3>"); continue
        if re.match(r"^\s*[-*] ", line):
            flush_para(); items.append(re.sub(r"^\s*[-*] ", "", line)); continue
        if items and line.startswith("  "):
            items[-1] += " " + line.strip(); continue
        flush_list(); para.append(line.strip())
    flush_para(); flush_list()
    return "\n".join(out)

body = convert(SRC.read_text(encoding="utf-8"))
page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title>Morphe Privacy Policy</title>
<meta name="description" content="What Morphe collects, where it lives, and the controls you have — export and delete are both in the app.">
<link rel="canonical" href="https://lucasdilley07-png.github.io/Morphe/privacy.html">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Morphe">
<meta property="og:title" content="Morphe Privacy Policy">
<meta property="og:description" content="What Morphe collects, where it lives, and the controls you have — export and delete are both in the app.">
<meta property="og:url" content="https://lucasdilley07-png.github.io/Morphe/privacy.html">
<meta property="og:image" content="https://lucasdilley07-png.github.io/Morphe/assets/og-card.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Morphe Privacy Policy">
<meta name="twitter:description" content="What Morphe collects, where it lives, and the controls you have — export and delete are both in the app.">
<meta name="twitter:image" content="https://lucasdilley07-png.github.io/Morphe/assets/og-card.png">
<meta name="theme-color" content="#121214">
<link rel="icon" href="assets/icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700;800&family=IBM+Plex+Mono:wght@500&display=swap">
<style>
:root {{ --bg:#FFFFFF; --bg-elevated:#F6F6F8; --fg:#16181F; --fg-2:rgba(22,24,31,0.66); --hair:rgba(22,24,31,0.12); --accent:#2957D9; --accent-ink:#2957D9; color-scheme: light; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#121214; --bg-elevated:#1A1A1C; --fg:#F2F3F7; --fg-2:rgba(242,243,247,0.7); --hair:rgba(242,243,247,0.12); --accent-ink:#7AA2FF; color-scheme: dark; }} }}
* {{ box-sizing: border-box; }}
body {{ margin:0; background:var(--bg); color:var(--fg); font-family:"Manrope",-apple-system,"Helvetica Neue",Arial,sans-serif; font-size:17px; line-height:1.6; -webkit-font-smoothing:antialiased; }}
.wrap {{ max-width:720px; margin:0 auto; padding-inline:20px; padding-block:40px 96px; }}
.brand {{ display:flex; align-items:center; gap:10px; text-decoration:none; color:inherit; margin-bottom:32px; }}
.brand img {{ width:22px; height:30px; }}
.brand span {{ font-family:"IBM Plex Mono",monospace; font-weight:500; letter-spacing:0.32em; font-size:14px; }}
h1 {{ font-size:clamp(2rem,1.4rem+2vw,2.6rem); letter-spacing:-0.02em; line-height:1.05; margin:0 0 8px; text-wrap:balance; }}
h2 {{ font-size:1.35rem; letter-spacing:-0.01em; margin:40px 0 8px; }}
h3 {{ font-size:1.1rem; margin:24px 0 6px; }}
p, li {{ color:var(--fg-2); max-width:65ch; }}
p strong, li strong {{ color:var(--fg); font-weight:700; }}
a {{ color:var(--accent-ink); }}
ul {{ padding-left:20px; }}
li {{ margin-bottom:6px; }}
.foot {{ margin-top:48px; padding-top:16px; border-top:1px solid var(--hair); font-size:13px; color:var(--fg-2); display:flex; gap:16px; flex-wrap:wrap; }}
</style>
</head>
<body>
<div class="wrap">
  <a class="brand" href="index.html" aria-label="Morphe home"><img src="assets/helmet.png" alt=""><span>MORPHE</span></a>
{body}
  <div class="foot"><a href="index.html">Morphe</a><a href="support.html">Support</a><span>TRAIN SMARTER</span></div>
</div>
</body>
</html>
"""
OUT.write_text(page, encoding="utf-8")
print("wrote", OUT)
