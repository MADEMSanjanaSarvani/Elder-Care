"""Generate the full SETU launcher-icon asset set.

The mark: three sheltering arcs curving over a heart — someone is watching
over them. That is the promise SETU sells ("your parents' safety net"), so
the icon says protection rather than spelling out the name.

Drawn as real SVG and rasterised with rsvg-convert, because stroke joins
and curve quality matter at 48px and a raster-primitive drawing library
cannot hold a uniform stroke around a curve.

Requires: librsvg2-bin  (apt-get install -y librsvg2-bin)

Outputs:
  assets/icon/icon.png                        1024  legacy + source of truth
  assets/icon/foreground.png                  1024  adaptive foreground
  res/mipmap-*/ic_launcher.png                48-192
  res/drawable-*/ic_launcher_foreground.png   108-432
  docs/store/icon-512-family-elder.png        512   Play Store listing

Run:  python3 tools/build_app_icon.py .
"""
import os
import subprocess
import sys
import tempfile

CREAM = "#F5EDDF"
TERRA = "#C8792F"

# Arc radii (outermost first) and their relative weight/opacity falloff, as
# fractions of a 1024px canvas.
ARCS = ((228, 1.00, 1.00), (158, 0.88, 0.80), (92, 0.76, 0.62))


def svg(size=1024, *, wordmark=True, scale=1.0, tile=True):
    c = size / 2
    s = size / 1024.0 * scale
    # With the wordmark the mark lifts to make room; without it, it sits a
    # touch low so the arcs+heart read as centred inside a round mask.
    cy = c - (size * 0.085 if wordmark else -size * 0.012)
    sw = 36 * s

    body = []
    if tile:
        body.append(f'<rect width="{size}" height="{size}" '
                    f'rx="{size * 0.225:.1f}" fill="{CREAM}"/>')
    for rr, wf, op in ARCS:
        r = rr * s
        body.append(
            f'<path d="M {c - r:.1f} {cy + 60 * s:.1f} '
            f'A {r:.1f} {r * 0.92:.1f} 0 0 1 {c + r:.1f} {cy + 60 * s:.1f}" '
            f'fill="none" stroke="{TERRA}" stroke-width="{sw * wf:.1f}" '
            f'stroke-linecap="round" opacity="{op:.2f}"/>')

    hx, hy, hr = c, cy + 132 * s, 56 * s
    body.append(
        f'<path d="M {hx:.1f} {hy + hr * 1.10:.1f} '
        f'C {hx - hr * 1.70:.1f} {hy - hr * 0.30:.1f} '
        f'{hx - hr * 0.55:.1f} {hy - hr * 1.30:.1f} {hx:.1f} {hy - hr * 0.35:.1f} '
        f'C {hx + hr * 0.55:.1f} {hy - hr * 1.30:.1f} '
        f'{hx + hr * 1.70:.1f} {hy - hr * 0.30:.1f} '
        f'{hx:.1f} {hy + hr * 1.10:.1f} Z" fill="{TERRA}"/>')

    if wordmark:
        body.append(
            f'<text x="{c:.1f}" y="{size * 0.80:.1f}" text-anchor="middle" '
            f'font-family="DejaVu Sans" font-weight="bold" '
            f'font-size="{size * 0.15:.1f}" '
            f'letter-spacing="{size * 0.028:.1f}" fill="{TERRA}" '
            f'dx="{size * 0.014:.1f}">SETU</text>')

    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" '
            f'height="{size}" viewBox="0 0 {size} {size}">'
            + "".join(body) + '</svg>')


def render(markup, px, out):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(markup)
        tmp = f.name
    try:
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px),
                        tmp, "-o", out], check=True)
    finally:
        os.unlink(tmp)


MIPMAP = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
DRAWABLE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
            "xxxhdpi": 432}

if __name__ == "__main__":
    root = sys.argv[1]
    app = f"{root}/apps/family_elder_app"
    res = f"{app}/android/app/src/main/res"

    tile = svg(1024)
    # Adaptive foreground: mark only, shrunk into the 66-of-108dp safe zone.
    # No wordmark — launchers crop the outer third to fit round/squircle masks
    # and would clip the text.
    fore = svg(1024, wordmark=False, scale=0.74, tile=False)

    render(tile, 1024, f"{app}/assets/icon/icon.png")
    render(fore, 1024, f"{app}/assets/icon/foreground.png")
    for d, px in MIPMAP.items():
        render(tile, px, f"{res}/mipmap-{d}/ic_launcher.png")
    for d, px in DRAWABLE.items():
        os.makedirs(f"{res}/drawable-{d}", exist_ok=True)
        render(fore, px, f"{res}/drawable-{d}/ic_launcher_foreground.png")
    render(tile, 512, f"{root}/docs/store/icon-512-family-elder.png")
    print("generated all icon assets")
