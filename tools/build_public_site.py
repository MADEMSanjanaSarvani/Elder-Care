"""Build the public SETU site: privacy policy, terms, and a support page.

Google Play requires a publicly reachable Privacy Policy URL, and a support
contact, before it will accept a listing. This renders the canonical
markdown in docs/legal/ into standalone, styled HTML in docs/public-site/,
so the published pages and the in-app copies never drift apart.

IMPORTANT — do NOT point GitHub Pages at the whole docs/ folder: it also
holds the business plans, feasibility model and credentials checklist, and
Pages would publish all of it. Publish docs/public-site/ only. See
docs/store/PLAY-STORE-SUBMISSION.md for the one-command way to do that.

Run:  python3 tools/build_public_site.py .
"""
import datetime
import os
import re
import sys

import markdown

# Values substituted into the [BRACKETED] placeholders in the markdown.
# SETU is pre-incorporation, so the data fiduciary under the DPDP Act is the
# founder personally. Swap COMPANY once a private limited company exists.
COMPANY = "Sanjana Sarvani Madem, sole proprietor, trading as SETU"
ADDRESS = "Visakhapatnam, Andhra Pradesh, India"
CONTACT = "sanjanasarvani2111@gmail.com"
NAME = "SETU"

CSS = """
:root{--paper:#FAF9F6;--raised:#fff;--ink:#3A322C;--muted:#7A6E64;
--accent:#C8792F;--border:#E6E3DF}
@media(prefers-color-scheme:dark){:root{--paper:#191614;--raised:#221E1B;
--ink:#F2EDE7;--muted:#A79C92;--border:#332D28}}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);
font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:760px;margin:0 auto;padding:32px 20px 96px}
header{display:flex;align-items:center;gap:12px;padding:22px 0;
border-bottom:1px solid var(--border);margin-bottom:32px}
header .mark{width:40px;height:40px;flex:none}
header b{font-size:19px;letter-spacing:.5px}
header .tag{color:var(--muted);font-size:14px;margin-left:auto}
h1{font-size:30px;line-height:1.2;margin:.4em 0}
h2{font-size:21px;margin-top:1.9em;border-top:1px solid var(--border);
padding-top:1.1em}
h3{font-size:17px;margin-top:1.5em}
a{color:var(--accent)}
blockquote{margin:1.4em 0;padding:14px 18px;background:var(--raised);
border-left:3px solid var(--accent);border-radius:0 12px 12px 0;
color:var(--muted)}
table{width:100%;border-collapse:collapse;margin:1.2em 0;font-size:14.5px}
th,td{text-align:left;padding:9px 10px;border-bottom:1px solid var(--border)}
th{color:var(--muted);font-weight:700}
code{background:var(--raised);padding:2px 6px;border-radius:5px;font-size:14px}
.scroll{overflow-x:auto}
nav.links{display:flex;gap:10px;flex-wrap:wrap;margin:28px 0}
nav.links a{display:inline-block;padding:9px 16px;background:var(--raised);
border:1px solid var(--border);border-radius:999px;text-decoration:none;
font-weight:600;font-size:14.5px}
footer{margin-top:60px;padding-top:20px;border-top:1px solid var(--border);
color:var(--muted);font-size:13.5px}
"""

MARK = ('<svg class="mark" viewBox="0 0 1024 1024" '
        'xmlns="http://www.w3.org/2000/svg">'
        '<rect width="1024" height="1024" rx="230" fill="#F5EDDF"/>'
        '<g fill="none" stroke="#C8792F" stroke-linecap="round">'
        '<path d="M 284 572 A 228 210 0 0 1 740 572" stroke-width="36"/>'
        '<path d="M 354 572 A 158 145 0 0 1 670 572" stroke-width="32" '
        'opacity=".8"/>'
        '<path d="M 420 572 A 92 85 0 0 1 604 572" stroke-width="27" '
        'opacity=".62"/></g>'
        '<path d="M 512 706 C 417 495 545 447 512 532 '
        'C 579 447 707 495 512 706 Z" fill="#C8792F"/></svg>')


def page(title, body, *, active=""):
    def lk(href, label):
        cur = ' style="border-color:var(--accent)"' if label == active else ""
        return f'<a href="{href}"{cur}>{label}</a>'

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · SETU</title><style>{CSS}</style></head><body>
<div class="wrap">
<header>{MARK}<b>SETU</b>
<span class="tag">Your parents' safety net.</span></header>
<nav class="links">{lk('index.html', 'Home')}{lk('privacy.html', 'Privacy')}
{lk('terms.html', 'Terms')}{lk('support.html', 'Support')}</nav>
{body}
<footer>SETU — a trusted elder-care ecosystem for families.<br>
Contact: <a href="mailto:{CONTACT}">{CONTACT}</a></footer>
</div></body></html>"""


def render_md(path):
    src = open(path).read()
    today = datetime.date.today().strftime("%d %B %Y")
    src = (src.replace("[COMPANY LEGAL NAME]", COMPANY)
              .replace("[COMPANY ADDRESS]", ADDRESS)
              .replace("[DATE]", today)
              .replace("[NAME]", NAME))
    # Drop the internal "fill this in before publishing" notes — they are
    # instructions to us, not content for the public page.
    src = re.sub(r"^> \*\*Fill in before publishing\*\*.*?(?=\n\n)", "",
                 src, flags=re.S | re.M)
    html = markdown.markdown(src, extensions=["tables", "toc", "sane_lists"])
    return html.replace("<table>", '<div class="scroll"><table>') \
               .replace("</table>", "</table></div>")


INDEX = """<h1>SETU</h1>
<p>SETU is a trusted elder-care ecosystem for families — daily check-ins,
medicine reminders, verified caregivers, doctor consultations and emergency
SOS, so adult children living away can know their parents are alright.</p>
<p>These pages carry the documents Google Play and India's Digital Personal
Data Protection Act require us to publish.</p>
<h2>Documents</h2>
<ul>
<li><a href="privacy.html">Privacy Policy</a> — what we collect, why, who can
see it, and how to have it deleted.</li>
<li><a href="terms.html">Terms of Service</a> — the agreement covering use of
the app and the care it coordinates.</li>
<li><a href="support.html">Support</a> — how to reach a human.</li>
</ul>"""

SUPPORT = f"""<h1>Support</h1>
<p>Something not working, a question about a visit, or a request about your
data — write to us and a person will reply.</p>
<h2>Contact</h2>
<p><a href="mailto:{CONTACT}">{CONTACT}</a><br>
We aim to reply within two working days.</p>
<h2>Your data</h2>
<p>Under the DPDP Act you may ask for a copy of your data, ask us to correct
it, or ask us to delete it. Email the address above with the subject
<code>Data request</code> and tell us which you want. You can also start both
from inside the app: <b>Profile → Settings &amp; privacy</b>.</p>
<h2>Emergencies</h2>
<p><b>SETU is not an emergency service.</b> If someone is in immediate danger,
call <b>112</b> (India's emergency number) or your local hospital first. The
app's SOS alerts your family circle and our team — it does not replace an
ambulance.</p>"""

if __name__ == "__main__":
    root = sys.argv[1]
    out = f"{root}/docs/public-site"
    os.makedirs(out, exist_ok=True)

    pages = {
        "index.html": page("Home", INDEX, active="Home"),
        "privacy.html": page(
            "Privacy Policy",
            render_md(f"{root}/docs/legal/PRIVACY-POLICY.md"),
            active="Privacy"),
        "terms.html": page(
            "Terms of Service",
            render_md(f"{root}/docs/legal/TERMS-OF-SERVICE.md"),
            active="Terms"),
        "support.html": page("Support", SUPPORT, active="Support"),
    }
    for name, html in pages.items():
        open(f"{out}/{name}", "w").write(html)
    # Stops GitHub Pages running the files through Jekyll.
    open(f"{out}/.nojekyll", "w").write("")
    print("built:", ", ".join(pages))
