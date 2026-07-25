"""Generate the full SETU launcher-icon asset set from one vector definition.

The mark: two lobes side by side (an infinity) with a third loop woven
diagonally through them, drawn as thick terracotta rings on warm cream.
SETU means "bridge" — the knot ties two sides together with no loose end.

Outputs (all regenerated from scratch, no hand-editing):
  assets/icon/icon.png                        1024  legacy + source of truth
  assets/icon/foreground.png                  1024  adaptive foreground
  res/mipmap-*/ic_launcher.png                48-192
  res/drawable-*/ic_launcher_foreground.png   108-432
  docs/store/icon-512-family-elder.png        512   Play Store listing

Run:  python3 tools/build_app_icon.py .
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

CREAM = (245, 237, 223, 255)
TERRA = (200, 121, 47, 255)
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 8  # supersample factor

# Knot geometry, as fractions of the canvas edge.
DX, A, B, SW = 0.115, 0.185, 0.155, 0.030      # the two lobes
DA, DB, DTILT = 0.255, 0.115, -38              # the diagonal loop


def _ring(S, cx, cy, a, b, sw, ang):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - a, cy - b, cx + a, cy + b],
                                  outline=TERRA, width=sw)
    return layer.rotate(ang, resample=Image.BICUBIC, center=(cx, cy))


def knot(S, scale=1.0):
    """Two lobes + a diagonal loop, woven over-under at their crossings."""
    c = S / 2
    dx, a, b = S * DX * scale, S * A * scale, S * B * scale
    sw = max(1, int(S * SW * scale))
    left = _ring(S, c - dx, c, a, b, sw, 0)
    diag = _ring(S, c, c, S * DA * scale, S * DB * scale, sw, DTILT)
    right = _ring(S, c + dx, c, a, b, sw, 0)

    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for layer in (left, diag, right):
        out.alpha_composite(layer)

    # Bring earlier layers back to the front at chosen crossings so the
    # strands genuinely alternate over/under instead of simply stacking.
    def bring_forward(layer, pts):
        mask = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(mask)
        r = sw * 1.5
        for px, py in pts:
            md.ellipse([px - r, py - r, px + r, py + r], fill=255)
        out.paste(layer, (0, 0),
                  Image.composite(layer.getchannel("A"), mask, mask))

    bring_forward(diag, [(c - dx - a * 0.55, c + b * 0.30),
                         (c + dx + a * 0.55, c - b * 0.30)])
    bring_forward(left, [(c, c - b * 0.75), (c, c + b * 0.75)])
    return out


def icon(N):
    """Cream rounded tile + knot + letter-spaced SETU wordmark."""
    S = N * SS
    card = Image.new("RGBA", (S, S), CREAM)
    card.alpha_composite(knot(S), (0, int(-S * 0.075)))

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
    """Adaptive foreground: the knot only, inside the 66-of-108dp safe zone.

    The wordmark is deliberately omitted — launchers mask adaptive icons to
    circles/squircles and crop the outer third, which would clip text.
    """
    S = N * SS
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(knot(S, scale=0.88))
    return layer.resize((N, N), Image.LANCZOS)


MIPMAP = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
DRAWABLE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
            "xxxhdpi": 432}

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
