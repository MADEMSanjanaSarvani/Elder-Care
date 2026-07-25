"""Turn raw phone screenshots into Play Store listing images.

Google Play wants 2-8 phone screenshots, min 320px on the short side and
max 3840px on the long side. Raw captures satisfy that but sell nothing —
a listing converts on the caption, not the pixels. This drops each capture
onto a warm SETU-branded panel with a headline above it.

Usage:
    # 1. Screenshot the app on your phone, copy the PNGs to a folder
    # 2. python3 tools/frame_screenshots.py <in-folder> <out-folder>
    #
    # Files are processed in sorted filename order and paired with the
    # captions below, so name them 01-dashboard.png, 02-timeline.png, …

Captions describe what a family member gets, not what the screen is called
— "Know they're alright, without calling five times a day" outsells
"Dashboard". Edit CAPTIONS to match the screens you actually captured.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

CREAM = (250, 249, 246)
INK = (58, 50, 44)
TERRA = (200, 121, 47)
MUTED = (122, 110, 100)

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# Headline + subline per screenshot, in filename order.
CAPTIONS = [
    ("Know they're alright", "Their whole day, at a glance"),
    ("Never a missed dose", "Medicine reminders that actually get taken"),
    ("Verified caregivers", "Background-checked, rated, tracked to the door"),
    ("A doctor, from home", "Video consultations without the waiting room"),
    ("One tap in an emergency", "SOS alerts your family circle instantly"),
    ("Warm moments, shared", "AI turns each day into something to keep"),
    ("You decide who sees what", "Consent is a setting, not fine print"),
    ("Care plans that fit", "Simple monthly pricing, cancel anytime"),
]

OUT_W, OUT_H = 1242, 2208     # a safe, widely-accepted phone listing size


def _fit(text, font, draw, max_w):
    """Shrink until the line fits, then return the font actually used."""
    size = font.size
    path = font.path
    while size > 20:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def frame(shot_path, headline, subline):
    canvas = Image.new("RGB", (OUT_W, OUT_H), CREAM)
    d = ImageDraw.Draw(canvas)
    pad = 72

    h_font = _fit(headline, ImageFont.truetype(BOLD, 92), d, OUT_W - pad * 2)
    s_font = _fit(subline, ImageFont.truetype(REG, 46), d, OUT_W - pad * 2)

    y = 118
    d.text((OUT_W / 2, y), headline, font=h_font, fill=INK, anchor="ma")
    y += h_font.size + 26
    d.text((OUT_W / 2, y), subline, font=s_font, fill=MUTED, anchor="ma")
    y += s_font.size + 54

    # a short accent rule, then the device shot
    d.rounded_rectangle([OUT_W / 2 - 46, y, OUT_W / 2 + 46, y + 7],
                        radius=4, fill=TERRA)
    y += 52

    shot = Image.open(shot_path).convert("RGB")
    avail_h = OUT_H - y - pad
    avail_w = OUT_W - pad * 2
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)),
                       Image.LANCZOS)

    # rounded corners on the capture so it reads as a device, not a crop
    r = int(shot.width * 0.055)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height],
                                           radius=r, fill=255)
    x = int((OUT_W - shot.width) / 2)
    canvas.paste(shot, (x, int(y)), mask)
    return canvas


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    shots = sorted(f for f in os.listdir(src)
                   if f.lower().endswith((".png", ".jpg", ".jpeg")))
    if not shots:
        sys.exit(f"No images found in {src}")
    for i, name in enumerate(shots[:8]):
        head, sub = CAPTIONS[i % len(CAPTIONS)]
        out = os.path.join(dst, f"play-{i + 1:02d}.png")
        frame(os.path.join(src, name), head, sub).save(out)
        print(f"{name}  ->  {out}   “{head}”")
    print(f"\n{min(len(shots), 8)} listing images ready in {dst}")
