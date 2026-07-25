"""Generate the full SETU launcher-icon asset set from one vector definition.

The mark: two identical ellipses counter-rotated about a shared centre and
drawn as thick rings, woven over-under at their crossings — an endless knot.
SETU means "bridge"; the knot has no loose end, which is the whole promise.

Outputs (all regenerated from scratch, no hand-editing):
  assets/icon/icon.png            1024  legacy + source of truth
  assets/icon/foreground.png      1024  adaptive foreground (mark only)
  res/mipmap-*/ic_launcher.png    48-192
  res/drawable-*/ic_launcher_foreground.png  108-432
  docs/store/icon-512-family-elder.png  512  Play Store listing
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont

CREAM = (245, 237, 223, 255)
TERRA = (200, 121, 47, 255)
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 8

# Geometry (fractions of the canvas edge).
TILT = 46
A_F, B_F, SW_F = 0.265, 0.150, 0.032        # in-tile, with wordmark
FA_F, FB_F, FSW_F = 0.235, 0.133, 0.028     # adaptive foreground, mark only


def _ring(S, a, b, sw, ang):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    c = S / 2
    ImageDraw.Draw(layer).ellipse([c - a, c - b, c + a, c + b],
                                  outline=TERRA, width=sw)
    return layer.rotate(ang, resample=Image.BICUBIC, center=(c, c))


def knot(S, a_f, b_f, sw_f, tilt=TILT):
    a, b, sw = S * a_f, S * b_f, max(1, int(S * sw_f))
    c, t = S / 2, math.radians(tilt)
    A, B = _ring(S, a, b, sw, tilt), _ring(S, a, b, sw, -tilt)

    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(A)
    out.alpha_composite(B)

    # B currently sits on top at all four crossings; bring A forward at the
    # two on the x-axis so the strands genuinely alternate over/under.
    xc = 1 / math.sqrt((math.cos(t) / a) ** 2 + (math.sin(t) / b) ** 2)
    patch = Image.new("L", (S, S), 0)
    pd = ImageDraw.Draw(patch)
    r = sw * 1.45
    for s in (-1, 1):
        pd.ellipse([c + s * xc - r, c - r, c + s * xc + r, c + r], fill=255)
    out.paste(A, (0, 0), Image.composite(A.getchannel("A"), patch, patch))
    return out


def icon(N):
    """Cream rounded tile + knot + letter-spaced SETU wordmark."""
    S = N * SS
    card = Image.new("RGBA", (S, S), CREAM)
    card.alpha_composite(knot(S, A_F, B_F, SW_F), (0, int(-S * 0.075)))

    d = ImageDraw.Draw(card)
    f = ImageFont.truetype(FONT_BOLD, int(S * 0.145))
    track = int(S * 0.024)
    widths = [d.textlength(ch, font=f) for ch in "SETU"]
    x = (S - (sum(widths) + track * 3)) / 2
    for ch, w in zip("SETU", widths):
        d.text((x, S * 0.635), ch, font=f, fill=TERRA)
        x += w + track

    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1],
                                           radius=int(S * 0.225), fill=255)
    card.putalpha(mask)
    return card.resize((N, N), Image.LANCZOS)


def foreground(N):
    """Adaptive foreground: mark only, inside the 66dp-of-108dp safe zone.

    The wordmark is deliberately omitted — launchers mask adaptive icons to
    circles/squircles and crop the outer third, which would clip text.
    """
    S = N * SS
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(knot(S, FA_F, FB_F, FSW_F))
    return layer.resize((N, N), Image.LANCZOS)


MIPMAP = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
DRAWABLE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

if __name__ == "__main__":
    root = sys.argv[1]
    app = f"{root}/apps/family_elder_app"
    res = f"{app}/android/app/src/main/res"

    icon(1024).save(f"{app}/assets/icon/icon.png")
    foreground(1024).save(f"{app}/assets/icon/foreground.png")

    for d, px in MIPMAP.items():
        icon(px).save(f"{res}/mipmap-{d}/ic_launcher.png")
    for d, px in DRAWABLE.items():
        os.makedirs(f"{res}/drawable-{d}", exist_ok=True)
        foreground(px).save(f"{res}/drawable-{d}/ic_launcher_foreground.png")

    icon(512).save(f"{root}/docs/store/icon-512-family-elder.png")
    print("generated all icon assets")
