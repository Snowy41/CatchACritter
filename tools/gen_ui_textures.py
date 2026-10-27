"""Generates the project's own UI textures (white on transparent, tinted in Roblox via ImageColor3).

Usage:  python tools/gen_ui_textures.py <out_dir> [name ...]
Names: sunburst, paws, glow, sparkle, ribbon (default: all). Needs Pillow.
Upload the PNGs to Roblox and put the asset ids into src/shared/Textures.luau.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def alpha_image(mask: Image.Image) -> Image.Image:
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def radial(size: int, power: float) -> Image.Image:
    g = Image.new("L", (size, size), 0)
    px = g.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c + 0.5, y - c + 0.5) / c
            px[x, y] = int(255 * max(0.0, 1 - r) ** power)
    return g


def sunburst() -> Image.Image:
    s, n = 1024, 18
    c = s / 2
    rays = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(rays)
    for i in range(n):
        a0 = i / n * 2 * math.pi
        a1 = a0 + math.pi / n * 0.9
        d.polygon([(c, c), (c + math.cos(a0) * s, c + math.sin(a0) * s), (c + math.cos(a1) * s, c + math.sin(a1) * s)], fill=255)
    rays = rays.filter(ImageFilter.GaussianBlur(3))
    fall = radial(s, 1.4)
    alpha = Image.composite(fall, Image.new("L", (s, s), 0), rays)
    alpha = ImageChops.lighter(alpha, fall.point(lambda v: int(v * 0.35)))
    return alpha_image(alpha)


def paws() -> Image.Image:
    ss, t = 4, 512
    m = Image.new("L", (t * ss, t * ss), 0)
    d = ImageDraw.Draw(m)

    def paw(cx, cy, s, rot):
        a = math.radians(rot)

        def rp(x, y):
            return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))

        def ell(x, y, rx, ry):
            d.polygon([rp(x + rx * math.cos(k / 24 * 2 * math.pi), y + ry * math.sin(k / 24 * 2 * math.pi)) for k in range(24)], fill=255)

        ell(0, s * 0.28, s * 0.42, s * 0.34)
        for x, y in [(-0.52, -0.18), (-0.2, -0.48), (0.2, -0.48), (0.52, -0.18)]:
            ell(x * s, y * s, s * 0.15, s * 0.2)

    for x, y, r in [(128, 128, -20), (384, 384, 20), (384, 128, 15), (128, 384, -15)]:
        paw(x * ss, y * ss, 60 * ss, r)
    return alpha_image(m.resize((t, t), Image.LANCZOS))


def glow() -> Image.Image:
    return alpha_image(radial(256, 2))


def sparkle() -> Image.Image:
    ss = 4
    s = 256 * ss
    c = s / 2
    sp = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(sp)
    for a in [0, 90]:
        for k in range(2):
            length = s * 0.48 if k == 0 else s * 0.3
            ang = math.radians(a + (0 if k == 0 else 45))
            w = s * 0.07 if k == 0 else s * 0.045
            pts = []
            for rr, off in [(length, 0), (w, 90), (length, 180), (w, 270)]:
                th = ang + math.radians(off)
                pts.append((c + rr * math.cos(th), c + rr * math.sin(th)))
            d.polygon(pts, fill=255 if k == 0 else 200)
    sp = sp.filter(ImageFilter.GaussianBlur(ss * 1.2)).resize((256, 256), Image.LANCZOS)
    sp = ImageChops.lighter(sp, radial(256, 2).point(lambda v: int(v * 0.8)))
    return alpha_image(sp)


def ribbon() -> Image.Image:
    """Notched banner, 512x128, 9-slice centre Rect(48, 24, 464, 104). The dark outline is made by
    dilating the shape's mask, so every corner (including the notch's inner point) is closed."""
    ss = 2
    w, h = 512 * ss, 128 * ss
    ow = 7 * ss  # outline width
    m = ow + 2 * ss  # keep the dilated outline inside the canvas
    n = 40 * ss  # notch depth
    body = [(m, m), (w - m, m), (w - m - n, h / 2), (w - m, h - m), (m, h - m), (m + n, h / 2)]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(body, fill=255)
    grown = mask.filter(ImageFilter.MaxFilter(2 * ow + 1))
    outline = ImageChops.subtract(grown, mask)

    # white body, light top highlight, soft lower shade (grey multiplies with ImageColor3)
    fill = Image.new("L", (w, h), 255)
    shade = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shade).rectangle([0, h * 0.6, w, h], fill=45)
    fill = ImageChops.subtract(fill, shade)
    rgb = Image.merge("RGB", [fill, fill, fill])
    ink = Image.new("RGB", (w, h), (20, 14, 36))
    rgb = Image.composite(ink, rgb, outline)
    img = rgb.convert("RGBA")
    img.putalpha(grown)
    return img.resize((512, 128), Image.LANCZOS)


def reticle() -> Image.Image:
    """Targeting reticle: ring with four inward ticks and a soft inner glow, 512x512."""
    ss, s = 2, 512 * 2
    c = s / 2
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    r_out, r_in = s * 0.44, s * 0.38
    d.ellipse([c - r_out, c - r_out, c + r_out, c + r_out], fill=255)
    d.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], fill=0)
    for a in range(4):
        th = math.radians(45 + a * 90)
        tip = (c + math.cos(th) * s * 0.27, c + math.sin(th) * s * 0.27)
        b1 = (c + math.cos(th - 0.09) * s * 0.47, c + math.sin(th - 0.09) * s * 0.47)
        b2 = (c + math.cos(th + 0.09) * s * 0.47, c + math.sin(th + 0.09) * s * 0.47)
        d.polygon([tip, b1, b2], fill=255)
    for a in range(4):  # cut four gaps into the ring
        th = math.radians(a * 90)
        d.polygon([(c, c), (c + math.cos(th - 0.12) * s, c + math.sin(th - 0.12) * s), (c + math.cos(th + 0.12) * s, c + math.sin(th + 0.12) * s)], fill=0)
    glow_l = radial(s, 3).point(lambda v: int(v * 0.25))
    m = ImageChops.lighter(m, glow_l)
    return alpha_image(m.resize((512, 512), Image.LANCZOS))


def ring() -> Image.Image:
    """Thin soft ring (shockwaves, ripples, capture bubble rim), 512x512."""
    s = 512
    c = s / 2
    g = Image.new("L", (s, s), 0)
    px = g.load()
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - c + 0.5, y - c + 0.5) / c
            px[x, y] = int(255 * max(0.0, 1 - abs(r - 0.88) / 0.08) ** 1.5)
    return alpha_image(g)


def heart() -> Image.Image:
    """Chunky heart for particles (white, tint via ParticleEmitter.Color), 256x256."""
    ss, s = 4, 256 * 4
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    pts = []
    for k in range(200):
        t = k / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((s / 2 + x * s / 38, s / 2 - y * s / 38 - s * 0.03))
    d.polygon(pts, fill=255)
    return alpha_image(m.resize((256, 256), Image.LANCZOS))


GENERATORS = {"heart": heart, "sunburst": sunburst, "paws": paws, "glow": glow, "sparkle": sparkle, "ribbon": ribbon, "reticle": reticle, "ring": ring}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    names = sys.argv[2:] or list(GENERATORS)
    os.makedirs(out, exist_ok=True)
    for name in names:
        GENERATORS[name]().save(os.path.join(out, f"tex_{name}.png"))
        print("wrote", f"tex_{name}.png")
