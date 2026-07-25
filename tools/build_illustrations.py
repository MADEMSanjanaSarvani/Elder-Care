"""Original SETU illustrations — flat, warm, drawn from primitives.

Deliberately illustration rather than photography: a stock photo of a
stranger sitting under "Priya is safe" would read as a picture of the
user's own parent, which it isn't. Illustrations carry the warmth without
making a claim. Everything here is generated, so it is licence-free and
regenerable.

Rendered at 4x and downsampled for clean edges. Transparent background so
each drops onto any surface.
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

SS = 4

# Warm SETU palette.
TERRA = (200, 121, 47)
TERRA_S = (232, 178, 124)
LAV = (98, 84, 155)
LAV_S = (183, 175, 214)
SAGE = (78, 143, 112)
SAGE_S = (166, 202, 182)
PEACH = (240, 138, 60)
CREAM = (245, 237, 223)
INK = (58, 50, 44)


def canvas(w, h):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def blob(d, cx, cy, r, color, alpha=255, squash=1.0):
    d.ellipse([cx - r, cy - r * squash, cx + r, cy + r * squash],
              fill=color + (alpha,))


def rrect(d, x0, y0, x1, y1, rad, color, alpha=255):
    d.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=color + (alpha,))


def arc(d, box, start, end, color, width, alpha=255):
    d.arc(box, start, end, fill=color + (alpha,), width=width)


def person(d, cx, base, scale, body, hair, *, cane=False):
    """A simple flat figure: round head, rounded-rect body, tapered arms."""
    s = scale
    head_r = 25 * s
    head_cy = base - 150 * s
    body_top = head_cy + head_r + 10 * s
    # torso
    rrect(d, cx - 33 * s, body_top, cx + 33 * s, base, 28 * s, body)
    # arms, hanging naturally along the torso
    for sgn in (-1, 1):
        d.line([(cx + sgn * 30 * s, body_top + 18 * s),
                (cx + sgn * 44 * s, body_top + 72 * s)],
               fill=body + (255,), width=int(14 * s))
        blob(d, cx + sgn * 44 * s, body_top + 74 * s, 8 * s, (243, 214, 189))
    # neck, head, hair
    rrect(d, cx - 8 * s, head_cy + head_r - 6 * s, cx + 8 * s,
          body_top + 4 * s, 6 * s, (243, 214, 189))
    blob(d, cx, head_cy, head_r, (243, 214, 189))
    d.pieslice([cx - head_r, head_cy - head_r,
                cx + head_r, head_cy + head_r * 0.45], 180, 360,
               fill=hair + (255,))
    if cane:
        d.line([(cx + 54 * s, body_top + 70 * s), (cx + 60 * s, base)],
               fill=INK + (130,), width=int(5 * s))


# --------------------------------------------------------------------------


def hero_family(w=340, h=240):
    """Two generations side by side under a warm sun — onboarding / login."""
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.5, H * 0.64, W * 0.46, TERRA_S, 55, squash=0.74)
    blob(d, W * 0.87, H * 0.15, W * 0.10, PEACH, 95)           # sun, clear of heads
    blob(d, W * 0.10, H * 0.60, W * 0.06, SAGE_S, 120)          # soft foliage
    blob(d, W * 0.93, H * 0.66, W * 0.05, SAGE_S, 120)
    base = H * 0.84
    person(d, W * 0.39, base, SS * 0.95, LAV_S, LAV)            # younger
    person(d, W * 0.61, base, SS * 0.86, TERRA_S, (156, 150, 145), cane=True)
    # ground
    d.line([(W * 0.08, base), (W * 0.92, base)],
           fill=TERRA + (70,), width=int(3 * SS))
    return im.resize((w, h), Image.LANCZOS)


def empty_notifications(w=200, h=160):
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.5, H * 0.56, W * 0.34, LAV_S, 70)
    cx, cy = W * 0.5, H * 0.5
    # bell
    d.pieslice([cx - 46 * SS, cy - 52 * SS, cx + 46 * SS, cy + 44 * SS],
               180, 360, fill=LAV + (255,))
    rrect(d, cx - 46 * SS, cy + 12 * SS, cx + 46 * SS, cy + 26 * SS,
          7 * SS, LAV)
    blob(d, cx, cy + 38 * SS, 11 * SS, LAV)
    blob(d, cx, cy - 56 * SS, 9 * SS, LAV)
    for sgn in (-1, 1):
        arc(d, [cx + sgn * 62 * SS - 22 * SS, cy - 40 * SS,
                cx + sgn * 62 * SS + 22 * SS, cy + 12 * SS],
            -55 if sgn > 0 else 125, 55 if sgn > 0 else 235,
            LAV_S, int(6 * SS))
    return im.resize((w, h), Image.LANCZOS)


def empty_timeline(w=200, h=160):
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.5, H * 0.62, W * 0.36, PEACH, 55)
    cx, cy = W * 0.5, H * 0.60
    d.pieslice([cx - 52 * SS, cy - 52 * SS, cx + 52 * SS, cy + 52 * SS],
               180, 360, fill=PEACH + (235,))                  # rising sun
    for i in range(7):                                          # rays
        a = math.radians(200 + i * 23)
        r0, r1 = 66 * SS, 86 * SS
        d.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
                (cx + r1 * math.cos(a), cy + r1 * math.sin(a))],
               fill=PEACH + (170,), width=int(5 * SS))
    d.line([(W * 0.12, cy), (W * 0.88, cy)],
           fill=TERRA + (120,), width=int(5 * SS))
    return im.resize((w, h), Image.LANCZOS)


def empty_memories(w=200, h=160):
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.5, H * 0.55, W * 0.36, TERRA_S, 65)
    # two tilted photo frames
    for dx, dy, rot, col in ((-0.10, 0.03, -9, LAV_S), (0.08, -0.02, 8, CREAM)):
        f = Image.new("RGBA", (int(96 * SS), int(96 * SS)), (0, 0, 0, 0))
        fd = ImageDraw.Draw(f)
        fd.rounded_rectangle([0, 0, 96 * SS, 96 * SS], radius=10 * SS,
                             fill=col + (255,), outline=TERRA + (120,),
                             width=int(3 * SS))
        fd.pieslice([18 * SS, 26 * SS, 78 * SS, 86 * SS], 180, 360,
                    fill=SAGE_S + (255,))
        fd.ellipse([60 * SS, 16 * SS, 78 * SS, 34 * SS], fill=PEACH + (255,))
        f = f.rotate(rot, resample=Image.BICUBIC, expand=True)
        im.alpha_composite(f, (int(W * (0.5 + dx) - f.width / 2),
                               int(H * (0.5 + dy) - f.height / 2)))
    return im.resize((w, h), Image.LANCZOS)


def empty_care(w=200, h=160):
    """A heart cradled by two hands — used where care/caregivers are empty."""
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.5, H * 0.56, W * 0.34, SAGE_S, 75)
    cx, cy = W * 0.5, H * 0.46
    r = 27 * SS
    blob(d, cx - r * 0.62, cy, r, TERRA)
    blob(d, cx + r * 0.62, cy, r, TERRA)
    d.polygon([(cx - r * 1.6, cy + r * 0.25), (cx + r * 1.6, cy + r * 0.25),
               (cx, cy + r * 2.15)], fill=TERRA + (255,))
    # a single cradling bowl beneath the heart, with two thumbs
    arc(d, [cx - 72 * SS, cy + 6 * SS, cx + 72 * SS, cy + 108 * SS],
        15, 165, SAGE, int(11 * SS))
    for sgn in (-1, 1):
        blob(d, cx + sgn * 69 * SS, cy + 52 * SS, 10 * SS, SAGE)
    return im.resize((w, h), Image.LANCZOS)


def login_backdrop(w=360, h=200):
    """A soft warm band for the top of the login / auth screens."""
    im, d = canvas(w, h)
    W, H = w * SS, h * SS
    blob(d, W * 0.18, H * 0.30, W * 0.24, TERRA_S, 170)
    blob(d, W * 0.70, H * 0.20, W * 0.19, LAV_S, 150)
    blob(d, W * 0.48, H * 0.74, W * 0.26, PEACH, 110)
    blob(d, W * 0.88, H * 0.62, W * 0.13, SAGE_S, 160)
    blob(d, W * 0.32, H * 0.60, W * 0.10, LAV_S, 110)
    # Blur into a single soft wash — hard-edged circles read as flat shapes
    # behind a login form; a diffuse gradient reads as light.
    im = im.filter(ImageFilter.GaussianBlur(radius=26 * SS / 4))
    return im.resize((w, h), Image.LANCZOS)


SET = {
    "hero_family": hero_family,
    "empty_notifications": empty_notifications,
    "empty_timeline": empty_timeline,
    "empty_memories": empty_memories,
    "empty_care": empty_care,
    "login_backdrop": login_backdrop,
}

if __name__ == "__main__":
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    for name, fn in SET.items():
        img = fn()
        img.save(f"{dest}/{name}.png")
        # 2x for high-density screens
        fn(**{k: v * 2 for k, v in
              zip(fn.__defaults__ and ("w", "h") or (), fn.__defaults__ or ())}
           ).save(f"{dest}/{name}@2x.png") if fn.__defaults__ else None
    print("illustrations:", ", ".join(SET))
