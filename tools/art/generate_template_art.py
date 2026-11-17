#!/usr/bin/env python3
"""Generates DragonLands' original `template_` artwork under assets/graphics/.

All art is created from scratch here (no external images):
  * terrain + fog textures: tileable fractal noise painted with numpy/PIL;
  * sprites: hand-written SVG shapes rendered by headless Chromium (render_svg.js).

Shared style: light from the upper left, warm dark outline (INK), soft painted
gradients, a light paper grain. Sprites have transparent backgrounds; their
ground contact point is the bottom-centre region described in README.md.

Run from anywhere:  python3 tools/art/generate_template_art.py
Requires: numpy, Pillow, node + playwright (Chromium).
"""
import json
import math
import random
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "graphics"
HERE = Path(__file__).resolve().parent
INK = "#2a2118"


# ----------------------------------------------------------------------------- helpers
def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def tile_noise(size, cells, rng):
    """Smooth value noise that tiles seamlessly over `size` pixels."""
    grid = rng.random((cells, cells)).astype(np.float32)
    xs = np.arange(size) * cells / size
    i0 = np.floor(xs).astype(int)
    t = xs - i0
    t = t * t * (3 - 2 * t)
    i1 = (i0 + 1) % cells
    rows = grid[:, i0] * (1 - t) + grid[:, i1] * t
    return rows[i0, :] * (1 - t)[:, None] + rows[i1, :] * t[:, None]


def fbm(size, rng, octaves=((4, 0.5), (8, 0.25), (16, 0.14), (32, 0.07), (64, 0.04))):
    n = sum(w * tile_noise(size, c, rng) for c, w in octaves)
    return (n - n.min()) / (n.max() - n.min())


def ramp(n, colors):
    """Maps noise 0..1 through evenly spaced colour stops."""
    stops = [hex_rgb(c) for c in colors]
    seg = len(stops) - 1
    x = np.clip(n, 0, 1) * seg
    i = np.minimum(np.floor(x).astype(int), seg - 1)
    t = (x - i)[..., None]
    a = np.stack(stops)[i]
    b = np.stack(stops)[i + 1]
    return a * (1 - t) + b * t


def to_image(rgb):
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def wrapped(draw_fn, size):
    """Calls draw_fn(dx, dy) for the 9 tile offsets so marks wrap seamlessly."""
    for dx in (-size, 0, size):
        for dy in (-size, 0, size):
            draw_fn(dx, dy)


def scatter(img, rng, count, painter):
    size = img.size[0]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x, y = rng.random() * size, rng.random() * size
        wrapped(lambda dx, dy: painter(d, x + dx, y + dy), size)
    return Image.alpha_composite(img, layer)


def save(img, rel):
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print("wrote", path.relative_to(ROOT))


# ----------------------------------------------------------------------------- terrain
def terrain_grass(rng):
    s = 256
    n1, n2 = fbm(s, rng), fbm(s, rng, ((16, 0.5), (32, 0.3), (64, 0.2)))
    rgb = ramp(n1, ["#4c7c35", "#5f8f3e", "#72a145", "#7fab4c"]) * (0.92 + 0.16 * n2[..., None])
    img = to_image(rgb)
    pal = [(62, 104, 44, 120), (126, 168, 76, 110), (148, 186, 92, 90), (84, 128, 52, 120)]

    def blade(d, x, y):
        a = math.radians(-90 + rng.uniform(-28, 28))
        ln = rng.uniform(3, 7)
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=pal[rng.randrange(4)], width=1)

    img = scatter(img, rng, 1500, blade)
    flowers = [(236, 214, 110, 230), (243, 240, 226, 230), (190, 166, 222, 220)]

    def flower(d, x, y):
        c = flowers[rng.randrange(3)]
        d.ellipse([x - 1.3, y - 1.3, x + 1.3, y + 1.3], fill=c)

    return scatter(img, rng, 22, flower)


def terrain_forest_floor(rng):
    s = 256
    n1, n2 = fbm(s, rng), fbm(s, rng, ((16, 0.5), (32, 0.3), (64, 0.2)))
    rgb = ramp(n1, ["#2f4426", "#3c5329", "#4a5e2f", "#55633a"]) * (0.9 + 0.2 * n2[..., None])
    img = to_image(rgb)
    leaves = [(110, 82, 46, 170), (138, 108, 54, 160), (78, 118, 50, 150), (60, 74, 36, 170)]

    def leaf(d, x, y):
        r = rng.uniform(1.2, 2.6)
        d.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=leaves[rng.randrange(4)])

    img = scatter(img, rng, 900, leaf)

    def twig(d, x, y):
        a = rng.uniform(0, math.pi)
        ln = rng.uniform(5, 11)
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=(70, 52, 32, 160), width=1)

    return scatter(img, rng, 45, twig)


def terrain_road(rng):
    s = 256
    n1, n2 = fbm(s, rng), fbm(s, rng, ((24, 0.5), (48, 0.3), (96, 0.2)))
    rgb = ramp(n1, ["#8c6d47", "#a07f55", "#b3926a", "#bc9c72"]) * (0.9 + 0.18 * n2[..., None])
    img = to_image(rgb)

    def pebble(d, x, y):
        r = rng.uniform(1.2, 3.2)
        g = rng.randrange(120, 180)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=(g, g - 10, g - 28, 200), outline=(90, 70, 48, 150))
        d.point((x - r * 0.3, y - r * 0.3), fill=(230, 220, 200, 200))

    img = scatter(img, rng, 120, pebble)

    def grit(d, x, y):
        d.point((x, y), fill=(92, 70, 46, 150))

    return scatter(img, rng, 1400, grit)


def terrain_water(rng):
    s = 256
    n1 = fbm(s, rng)
    rgb = ramp(n1, ["#255d74", "#2f6d86", "#3a7f97", "#4791a6"])
    img = to_image(rgb)
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(70):
        x, y = rng.random() * s, rng.random() * s
        ln, amp = rng.uniform(10, 26), rng.uniform(0.8, 2.0)
        col = (150, 210, 222, rng.randrange(60, 130))

        def ripple(dx, dy):
            pts = [(x + dx + t, y + dy + math.sin(t / ln * math.pi) * -amp) for t in np.linspace(0, ln, 8)]
            d.line(pts, fill=col, width=1)

        wrapped(ripple, s)
    return Image.alpha_composite(img, layer)


def terrain_rock(rng):
    s = 256
    n1, n2 = fbm(s, rng), fbm(s, rng, ((16, 0.5), (32, 0.3), (64, 0.2)))
    rgb = ramp(n1, ["#6f695d", "#857e6e", "#9a917e", "#aaa08b"]) * (0.9 + 0.2 * n2[..., None])
    img = to_image(rgb)
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(26):
        x, y = rng.random() * s, rng.random() * s
        pts = [(x, y)]
        a = rng.uniform(0, math.tau)
        for _ in range(rng.randrange(4, 9)):
            a += rng.uniform(-0.8, 0.8)
            x += math.cos(a) * rng.uniform(3, 8)
            y += math.sin(a) * rng.uniform(3, 8)
            pts.append((x, y))
        wrapped(lambda dx, dy: d.line([(p[0] + dx, p[1] + dy) for p in pts], fill=(70, 64, 54, 150), width=1), s)
    img = Image.alpha_composite(img, layer)

    def stone(d, x, y):
        r = rng.uniform(2, 5)
        g = rng.randrange(140, 190)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=(g, g - 6, g - 18, 220), outline=(80, 74, 62, 180))
        d.ellipse([x - r * 0.5, y - r * 0.55, x, y - r * 0.1], fill=(225, 220, 205, 150))

    img = scatter(img, rng, 70, stone)

    def lichen(d, x, y):
        r = rng.uniform(1, 2.5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(150, 164, 84, 110))

    return scatter(img, rng, 60, lichen)


def fog_clouds(rng):
    s = 256
    n = fbm(s, rng, ((4, 0.45), (8, 0.25), (16, 0.15), (32, 0.1), (64, 0.05)))
    w = fbm(s, rng, ((8, 0.5), (16, 0.3), (32, 0.2)))
    rgb = ramp(n ** 1.2, ["#121822", "#1b2330", "#2a3445", "#3d4a5f", "#56637a"])
    rgb = rgb + (np.clip(w - 0.6, 0, 1) * 90)[..., None]
    return to_image(rgb)


# ----------------------------------------------------------------------------- svg sprites
def svg(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs><filter id="blur" x="-50%" y="-50%" width="200%" height="200%">'
            f'<feGaussianBlur stdDeviation="3"/></filter>{defs}</defs>{body}</svg>')


def shadow(cx, cy, rx, ry, a=0.35):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="rgb(22,28,12)" opacity="{a}" filter="url(#blur)"/>'


def circles(cs, fill, grow=0.0, dx=0.0, dy=0.0, scale=1.0, opacity=1.0):
    return "".join(f'<circle cx="{x + dx:.1f}" cy="{y + dy:.1f}" r="{r * scale + grow:.1f}" fill="{fill}" opacity="{opacity}"/>'
                   for x, y, r in cs)


def canopy(cs, uid, base, mid, light, speck, dark):
    """Clustered-circle foliage with a merged outline and clipped highlights."""
    out = circles(cs, INK, grow=2.6)
    out += circles(cs, base)
    out += f'<clipPath id="clip{uid}">{circles(cs, "#000")}</clipPath><g clip-path="url(#clip{uid})">'
    out += circles(cs, dark, dx=5, dy=7, scale=0.9, opacity=0.55)
    out += circles(cs, mid, dx=-3, dy=-4, scale=0.82)
    out += circles(cs, light, dx=-8, dy=-10, scale=0.45, opacity=0.85)
    r = random.Random(uid)
    xs = [c[0] for c in cs]
    ys = [c[1] for c in cs]
    for _ in range(26):
        x = r.uniform(min(xs) - 10, max(xs))
        y = r.uniform(min(ys) - 14, max(ys) - 4)
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r.uniform(1.5, 3):.1f}" fill="{speck}" opacity="0.75"/>'
    return out + "</g>"


def tree_oak():
    w, h = 112, 128
    r = random.Random(11)
    cs = [(56, 56, 27)]
    for i in range(8):
        a = i / 8 * math.tau + r.uniform(-0.2, 0.2)
        cs.append((56 + math.cos(a) * r.uniform(18, 24), 58 + math.sin(a) * r.uniform(14, 19), r.uniform(17, 22)))
    body = shadow(62, 114, 36, 10)
    body += f'<path d="M48,117 C51,104 52,92 52,76 L61,76 C61,92 62,104 66,117 Z" fill="#6b4a2e" stroke="{INK}" stroke-width="2.4"/>'
    body += '<path d="M54,112 C55,100 55,90 55,80" stroke="#8a6440" stroke-width="2" fill="none"/>'
    body += canopy(cs, 1, "#3d6b2e", "#558a3a", "#82b450", "#a7d06c", "#24451f")
    return w, h, svg(w, h, body)


def tree_pine():
    w, h = 80, 136
    body = shadow(44, 125, 24, 8)
    body += f'<rect x="36" y="104" width="9" height="22" rx="2" fill="#5e4129" stroke="{INK}" stroke-width="2.2"/>'
    tiers = [(112, 34, 40), (92, 28, 38), (72, 22, 34), (52, 15, 32)]
    for yb, hw, ht in tiers:
        apex = (40, yb - ht)
        pts = [apex, (40 + hw, yb), (40 + hw * 0.5, yb - 4), (40, yb + 1), (40 - hw * 0.5, yb - 4), (40 - hw, yb)]
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        lit = [apex, (40, yb + 1), (40 - hw * 0.5, yb - 4), (40 - hw, yb)]
        lp = " ".join(f"{x:.1f},{y:.1f}" for x, y in lit)
        body += f'<polygon points="{p}" fill="#2b5733" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
        body += f'<polygon points="{lp}" fill="#3f7a46" opacity="0.9"/>'
        body += f'<polyline points="{40 - hw * 0.7:.1f},{yb - 5} {40 - hw * 0.2:.1f},{yb - ht * 0.55:.1f}" stroke="#6ea866" stroke-width="2" opacity="0.7" fill="none"/>'
    return w, h, svg(w, h, body)


def bush():
    w, h = 56, 44
    cs = [(20, 26, 11), (32, 22, 12), (40, 29, 9), (14, 31, 8), (28, 31, 10)]
    body = shadow(30, 37, 22, 6)
    body += canopy(cs, 2, "#3f6f30", "#5a913d", "#86b955", "#a8d16e", "#26461f")
    for x, y in [(22, 24), (34, 27), (17, 31)]:
        body += f'<circle cx="{x}" cy="{y}" r="1.8" fill="#c8463a" stroke="{INK}" stroke-width="0.6"/>'
    return w, h, svg(w, h, body)


def rocks():
    w, h = 72, 56
    body = shadow(38, 48, 30, 7)
    stones = [
        ([(10, 46), (14, 30), (26, 22), (38, 28), (40, 46)], "#8d8677", "#b3ab98"),
        ([(34, 47), (38, 34), (50, 28), (62, 36), (64, 47)], "#7d7769", "#a69e8b"),
        ([(24, 50), (26, 42), (34, 38), (44, 42), (46, 50)], "#958e7e", "#bfb7a3"),
    ]
    for pts, fill, light in stones:
        p = " ".join(f"{x},{y}" for x, y in pts)
        top = " ".join(f"{x},{y}" for x, y in pts[1:4]) + f" {pts[3][0] - 4},{pts[3][1] + 6} {pts[1][0] + 4},{pts[1][1] + 6}"
        body += f'<polygon points="{p}" fill="{fill}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>'
        body += f'<polygon points="{top}" fill="{light}" opacity="0.85"/>'
    body += '<circle cx="20" cy="40" r="3" fill="#7d9a4a" opacity="0.8"/><circle cx="56" cy="42" r="2.5" fill="#7d9a4a" opacity="0.8"/>'
    return w, h, svg(w, h, body)


def mountain(variant):
    if variant == "a":
        w, h = 192, 176
        sil = [(6, 162), (36, 120), (58, 98), (76, 68), (96, 26), (112, 46), (124, 60), (142, 92), (160, 118), (186, 162)]
        lit = [(6, 162), (36, 120), (58, 98), (76, 68), (96, 26), (101, 66), (92, 104), (100, 136), (96, 162)]
        snow = [(82, 56), (96, 26), (112, 46), (118, 56), (110, 54), (104, 62), (98, 54), (90, 62)]
        snow_lit = [(82, 56), (96, 26), (99, 50), (90, 62)]
        ridges = [[(96, 26), (101, 66), (92, 104), (100, 136)], [(58, 98), (70, 112), (66, 140)], [(142, 92), (130, 118), (136, 150)]]
    else:
        w, h = 160, 150
        sil = [(6, 138), (28, 104), (44, 74), (58, 40), (72, 58), (84, 48), (100, 30), (116, 62), (132, 92), (154, 138)]
        lit = [(6, 138), (28, 104), (44, 74), (58, 40), (64, 76), (78, 64), (84, 48), (100, 30), (98, 76), (86, 110), (90, 138)]
        snow = [(90, 44), (100, 30), (110, 48), (104, 46), (98, 54), (94, 48)]
        snow_lit = [(90, 44), (100, 30), (99, 46), (94, 48)]
        ridges = [[(100, 30), (98, 76), (86, 110), (90, 138)], [(58, 40), (64, 76), (54, 110)]]
    p = lambda pts: " ".join(f"{x},{y}" for x, y in pts)
    base_y = sil[0][1]
    body = shadow(w * 0.54, base_y - 2, w * 0.46, 13, 0.4)
    defs = (f'<linearGradient id="lit{variant}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b3aa96"/>'
            f'<stop offset="1" stop-color="#8b8270"/></linearGradient>'
            f'<linearGradient id="shade{variant}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a7262"/>'
            f'<stop offset="1" stop-color="#5a5347"/></linearGradient>')
    body += f'<polygon points="{p(sil)}" fill="url(#shade{variant})" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    body += f'<polygon points="{p(lit)}" fill="url(#lit{variant})"/>'
    for ridge in ridges:
        body += f'<polyline points="{p(ridge)}" fill="none" stroke="#4a443a" stroke-width="2" stroke-linecap="round" opacity="0.7"/>'
    r = random.Random(variant)
    body += f'<clipPath id="sil{variant}"><polygon points="{p(sil)}"/></clipPath><g clip-path="url(#sil{variant})">'
    for _ in range(14):
        x = r.uniform(w * 0.2, w * 0.8)
        y = r.uniform(h * 0.45, base_y - 12)
        body += f'<path d="M{x:.0f},{y:.0f} l{r.uniform(5, 10):.0f},{r.uniform(-4, 4):.0f}" stroke="#4f483d" stroke-width="1.6" opacity="0.55"/>'
    body += "</g>"
    body += f'<polygon points="{p(snow)}" fill="#cfd8df" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
    body += f'<polygon points="{p(snow_lit)}" fill="#f4f6f4"/>'
    for i in range(6):
        x = sil[0][0] + 22 + i * (w - 56) / 5 + r.uniform(-8, 8)
        y = base_y - r.uniform(1, 6)
        s = r.uniform(0.8, 1.2)
        body += (f'<path d="M{x - 7 * s:.1f},{y:.1f} l{3 * s:.1f},{-9 * s:.1f} l{2 * s:.1f},{7 * s:.1f} l{3 * s:.1f},{-11 * s:.1f} '
                 f'l{2 * s:.1f},{11 * s:.1f} l{3 * s:.1f},{-7 * s:.1f} l{2 * s:.1f},{9 * s:.1f} Z" fill="#5f8f3e" '
                 f'stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>')
    return w, h, svg(w, h, body, defs)


def bridge():
    w, h = 112, 80
    defs = ('<linearGradient id="deck" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b9ae96"/>'
            '<stop offset="1" stop-color="#9c917b"/></linearGradient>')
    body = '<rect x="8" y="30" width="96" height="34" rx="6" fill="rgb(15,30,40)" opacity="0.35" filter="url(#blur)"/>'
    body += f'<rect x="4" y="22" width="104" height="36" rx="5" fill="url(#deck)" stroke="{INK}" stroke-width="2.4"/>'
    for i in range(1, 13):
        x = 4 + i * 8
        body += f'<line x1="{x}" y1="24" x2="{x}" y2="56" stroke="#857a65" stroke-width="1.2" opacity="0.7"/>'
    body += '<rect x="6" y="36" width="100" height="8" fill="#a78a62" opacity="0.45"/>'
    for y, fill in ((16, "#a39985"), (54, "#8f8571")):
        body += f'<rect x="2" y="{y}" width="108" height="10" rx="4" fill="{fill}" stroke="{INK}" stroke-width="2.2"/>'
        for i in range(1, 9):
            body += f'<line x1="{2 + i * 12}" y1="{y + 1}" x2="{2 + i * 12}" y2="{y + 9}" stroke="#6f6656" stroke-width="1.3"/>'
        body += f'<rect x="4" y="{y + 1}" width="104" height="3" rx="1.5" fill="#d5ccb6" opacity="0.6"/>'
    return w, h, svg(w, h, body, defs)


def camp():
    w, h = 128, 112
    defs = ('<radialGradient id="glow"><stop offset="0" stop-color="#ffd27a" stop-opacity="0.75"/>'
            '<stop offset="1" stop-color="#ff8a3a" stop-opacity="0"/></radialGradient>')
    body = shadow(62, 98, 54, 11)
    body += '<ellipse cx="64" cy="94" rx="56" ry="15" fill="#8f7550" opacity="0.55"/>'
    # tent
    body += f'<polygon points="14,92 44,34 90,40 108,88" fill="#b8975e" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
    body += f'<polygon points="14,92 44,34 60,94" fill="#ddc48f" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
    body += f'<polygon points="30,93 44,62 52,94" fill="#3b2c1f" stroke="{INK}" stroke-width="1.8"/>'
    body += '<line x1="44" y1="34" x2="90" y2="40" stroke="#f1e2ba" stroke-width="2" opacity="0.8"/>'
    body += f'<line x1="44" y1="34" x2="40" y2="20" stroke="{INK}" stroke-width="2.4"/>'
    body += f'<polygon points="40,20 54,24 41,28" fill="#c0452f" stroke="{INK}" stroke-width="1.4"/>'
    # bedroll and pack
    body += f'<rect x="62" y="88" width="26" height="9" rx="4.5" fill="#6f8d5a" stroke="{INK}" stroke-width="1.8"/>'
    # campfire
    body += '<circle cx="104" cy="94" r="22" fill="url(#glow)"/>'
    for a in range(0, 360, 45):
        x = 104 + math.cos(math.radians(a)) * 10
        y = 97 + math.sin(math.radians(a)) * 5
        body += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="3.6" ry="2.6" fill="#8d877b" stroke="{INK}" stroke-width="1.2"/>'
    body += f'<line x1="96" y1="99" x2="112" y2="93" stroke="#5e3f25" stroke-width="3.5" stroke-linecap="round"/>'
    body += f'<line x1="96" y1="93" x2="112" y2="99" stroke="#6e4a2c" stroke-width="3.5" stroke-linecap="round"/>'
    body += f'<path d="M98,95 C97,86 103,84 101,76 C107,82 110,86 110,95 Z" fill="#ff8a2a" stroke="{INK}" stroke-width="1.4"/>'
    body += '<path d="M101,95 C101,89 104,88 104,83 C107,87 108,90 107,95 Z" fill="#ffd45e"/>'
    return w, h, svg(w, h, body, defs)


def watchtower():
    w, h = 112, 176
    defs = ('<linearGradient id="stone" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#bcb4a2"/>'
            '<stop offset="0.45" stop-color="#9d9483"/><stop offset="1" stop-color="#6c6559"/></linearGradient>')
    body = shadow(64, 160, 44, 11, 0.4)
    outline = "30,160 32,62 38,50 46,56 52,40 60,48 68,32 74,46 82,54 84,160"
    body += f'<polygon points="{outline}" fill="url(#stone)" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>'
    body += '<path d="M33,62 Q57,72 83,58" fill="none" stroke="#5d564b" stroke-width="2"/>'
    r = random.Random(5)
    for row, y in enumerate(range(70, 158, 11)):
        body += f'<path d="M32,{y} Q57,{y + 6} 84,{y}" fill="none" stroke="#6d6658" stroke-width="1.3" opacity="0.7"/>'
        for x in range(36 + (row % 2) * 7, 82, 14):
            body += f'<line x1="{x}" y1="{y + 2}" x2="{x}" y2="{y + 10}" stroke="#6d6658" stroke-width="1.1" opacity="0.6"/>'
    body += f'<rect x="54" y="84" width="7" height="18" rx="3" fill="#2a2420" stroke="{INK}" stroke-width="1.4"/>'
    body += f'<path d="M48,160 L48,140 Q56,130 64,140 L64,160 Z" fill="#4a3424" stroke="{INK}" stroke-width="2"/>'
    for cx, cy, rr in [(34, 120, 7), (36, 108, 6), (33, 132, 8), (40, 98, 5), (38, 140, 6)]:
        body += f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#4f7d36" stroke="{INK}" stroke-width="1.2"/>'
        body += f'<circle cx="{cx - 2}" cy="{cy - 2}" r="{rr * 0.5:.1f}" fill="#79a94e"/>'
    for cx, cy, rr in [(90, 156, 6), (98, 159, 4), (82, 160, 4), (22, 158, 4)]:
        body += f'<ellipse cx="{cx}" cy="{cy}" rx="{rr}" ry="{rr * 0.7:.1f}" fill="#948b7a" stroke="{INK}" stroke-width="1.4"/>'
    return w, h, svg(w, h, body, defs)


def lodge():
    w, h = 144, 120
    body = shadow(74, 106, 62, 11, 0.4)
    # chimney smoke
    for i, (x, y, rr) in enumerate([(104, 14, 6), (110, 7, 7), (118, 3, 6)]):
        body += f'<circle cx="{x}" cy="{y}" r="{rr}" fill="#d6d6d0" opacity="{0.55 - i * 0.12:.2f}"/>'
    # walls
    body += f'<rect x="24" y="64" width="96" height="42" fill="#8a5f3a" stroke="{INK}" stroke-width="2.6"/>'
    for i, y in enumerate(range(68, 104, 7)):
        body += f'<rect x="25" y="{y}" width="94" height="5" rx="2.5" fill="{"#a5744a" if i % 2 else "#966843"}"/>'
    body += f'<rect x="62" y="76" width="18" height="30" rx="2" fill="#4b3222" stroke="{INK}" stroke-width="2"/>'
    body += '<circle cx="76" cy="92" r="1.6" fill="#d9b25a"/>'
    body += f'<rect x="34" y="78" width="16" height="13" fill="#f2c96b" stroke="{INK}" stroke-width="2"/>'
    body += f'<line x1="42" y1="78" x2="42" y2="91" stroke="{INK}" stroke-width="1.5"/>'
    body += f'<rect x="94" y="78" width="16" height="13" fill="#e9bc5c" stroke="{INK}" stroke-width="2"/>'
    # roof
    body += f'<rect x="98" y="18" width="13" height="26" fill="#7f786c" stroke="{INK}" stroke-width="2.2"/>'
    body += f'<polygon points="12,70 34,26 110,26 132,70" fill="#6a5a3c" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>'
    for i, y in enumerate(range(33, 70, 8)):
        inset = (70 - y) * 0.5
        body += f'<line x1="{12 + inset:.0f}" y1="{y}" x2="{132 - inset:.0f}" y2="{y}" stroke="#4e4229" stroke-width="1.6"/>'
    body += '<polygon points="34,26 72,26 56,70 12,70" fill="#7f6c47" opacity="0.6"/>'
    for cx, cy, rr in [(40, 40, 7), (52, 34, 6), (86, 50, 8), (100, 60, 6), (30, 58, 6), (116, 64, 5)]:
        body += f'<ellipse cx="{cx}" cy="{cy}" rx="{rr}" ry="{rr * 0.6:.1f}" fill="#6f9a45" opacity="0.85"/>'
    # woodpile and chopping block
    for i, (x, y) in enumerate([(124, 100), (132, 100), (128, 93), (136, 93), (132, 86)]):
        body += f'<circle cx="{x}" cy="{y}" r="4.4" fill="#c8a06a" stroke="{INK}" stroke-width="1.5"/><circle cx="{x}" cy="{y}" r="1.6" fill="#8a6440"/>'
    body += f'<ellipse cx="12" cy="104" rx="8" ry="4" fill="#a37b4c" stroke="{INK}" stroke-width="1.6"/>'
    body += f'<rect x="4" y="104" width="16" height="6" fill="#7b5634" stroke="{INK}" stroke-width="1.6"/>'
    body += f'<line x1="10" y1="104" x2="20" y2="90" stroke="#6b4a2e" stroke-width="2.4"/>'
    body += f'<polygon points="17,92 24,87 24,95" fill="#9aa3a8" stroke="{INK}" stroke-width="1.2"/>'
    return w, h, svg(w, h, body)


def standing_stones():
    w, h = 160, 112
    body = '<ellipse cx="80" cy="74" rx="74" ry="32" fill="#8fbe5e" opacity="0.35"/>'
    body += '<ellipse cx="80" cy="74" rx="40" ry="15" fill="#b3a477" opacity="0.4"/>'
    body += f'<ellipse cx="80" cy="74" rx="14" ry="6" fill="#9b9586" stroke="{INK}" stroke-width="1.8"/>'
    stones = []
    for i in range(7):
        a = i / 7 * math.tau + 0.4
        x = 80 + math.cos(a) * 60
        y = 72 + math.sin(a) * 26
        stones.append((y, x, i))
    stones.sort()
    for y, x, i in stones:
        depth = (y - 46) / 52  # 0 = back, 1 = front
        hgt = 26 + depth * 14 + (8 if i == 2 else 0)
        wid = 11 + depth * 5
        body += shadow(x + 6, y + 1, wid, 4, 0.3)
        body += (f'<path d="M{x - wid / 2:.1f},{y:.1f} L{x - wid / 2 + 1:.1f},{y - hgt + 6:.1f} Q{x:.1f},{y - hgt - 4:.1f} '
                 f'{x + wid / 2 - 1:.1f},{y - hgt + 6:.1f} L{x + wid / 2:.1f},{y:.1f} Z" fill="#8f8c80" stroke="{INK}" stroke-width="2.2"/>')
        body += (f'<path d="M{x - wid / 2 + 2:.1f},{y - 2:.1f} L{x - wid / 2 + 3:.1f},{y - hgt + 7:.1f} Q{x - 1:.1f},{y - hgt - 1:.1f} '
                 f'{x:.1f},{y - hgt + 4:.1f} L{x:.1f},{y - 2:.1f} Z" fill="#b4b1a3"/>')
        body += f'<ellipse cx="{x + 1:.1f}" cy="{y - hgt * 0.35:.1f}" rx="{wid * 0.35:.1f}" ry="{hgt * 0.12:.1f}" fill="#6f9440" opacity="0.8"/>'
        if i == 2:
            body += (f'<path d="M{x - 2:.1f},{y - hgt * 0.7:.1f} l3,4 l-3,4 l3,4" stroke="#7fe0d0" stroke-width="1.8" '
                     f'fill="none" opacity="0.9"/>')
    return w, h, svg(w, h, body)


def dragon_nest():
    w, h = 144, 104
    defs = ('<radialGradient id="ember"><stop offset="0" stop-color="#ffb347" stop-opacity="0.9"/>'
            '<stop offset="0.6" stop-color="#e2582a" stop-opacity="0.45"/><stop offset="1" stop-color="#7a2a12" stop-opacity="0"/></radialGradient>'
            '<radialGradient id="egg" cx="0.35" cy="0.3"><stop offset="0" stop-color="#fff4dc"/>'
            '<stop offset="0.7" stop-color="#e9c48c"/><stop offset="1" stop-color="#c98a4c"/></radialGradient>')
    body = shadow(74, 92, 64, 12, 0.45)
    body += f'<polygon points="6,90 14,70 34,60 60,56 92,56 118,62 136,74 140,90 110,98 40,98" fill="#3c3634" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
    body += '<polygon points="14,72 34,62 60,58 54,70 30,76" fill="#5b524c"/>'
    body += '<polygon points="118,64 134,74 124,80" fill="#57504a"/>'
    body += '<path d="M24,88 l10,-6 l8,4" stroke="#ff7a3a" stroke-width="1.6" fill="none" opacity="0.7"/>'
    body += '<path d="M112,90 l8,-5 l6,3" stroke="#ff7a3a" stroke-width="1.6" fill="none" opacity="0.6"/>'
    body += f'<ellipse cx="72" cy="66" rx="48" ry="21" fill="#4a3322" stroke="{INK}" stroke-width="2.4"/>'
    r = random.Random(9)
    for i in range(46):
        a = r.uniform(0, math.tau)
        x = 72 + math.cos(a) * r.uniform(34, 46)
        y = 66 + math.sin(a) * r.uniform(13, 19)
        ln = r.uniform(8, 16)
        t = a + math.pi / 2 + r.uniform(-0.4, 0.4)
        col = r.choice(["#2a1d14", "#5b3d26", "#6e4a2c", "#3a281b"])
        body += f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{x + math.cos(t) * ln:.1f}" y2="{y + math.sin(t) * ln * 0.45:.1f}" stroke="{col}" stroke-width="2.4" stroke-linecap="round"/>'
    body += '<ellipse cx="72" cy="64" rx="32" ry="12" fill="#22170f"/>'
    body += '<ellipse cx="72" cy="62" rx="38" ry="18" fill="url(#ember)"/>'
    for cx, cy, rr in [(30, 60, 6), (112, 70, 5), (44, 80, 5), (100, 50, 4)]:
        body += f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#5f8a3a" stroke="{INK}" stroke-width="1.2"/>'
    for ex, ey, rot in [(60, 58, -12), (76, 52, 4), (88, 62, 14)]:
        body += (f'<g transform="rotate({rot} {ex} {ey})"><ellipse cx="{ex}" cy="{ey}" rx="9" ry="12" fill="url(#egg)" '
                 f'stroke="{INK}" stroke-width="2"/>')
        for _ in range(6):
            body += f'<circle cx="{ex + r.uniform(-5, 5):.1f}" cy="{ey + r.uniform(-7, 7):.1f}" r="{r.uniform(0.8, 1.6):.1f}" fill="#8a3b22"/>'
        body += "</g>"
    for _ in range(8):
        body += f'<circle cx="{r.uniform(46, 100):.1f}" cy="{r.uniform(48, 74):.1f}" r="1.2" fill="#ffd27a"/>'
    return w, h, svg(w, h, body, defs)


def adventurer():
    w, h = 56, 80
    defs = ('<linearGradient id="cloak" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3f8a76"/>'
            '<stop offset="0.6" stop-color="#2f6b5e"/><stop offset="1" stop-color="#22514a"/></linearGradient>'
            '<radialGradient id="lamp"><stop offset="0" stop-color="#fff2b0"/><stop offset="1" stop-color="#ffb84a" stop-opacity="0"/></radialGradient>')
    body = f'<ellipse cx="22" cy="74" rx="5" ry="3.4" fill="#3a2a1c" stroke="{INK}" stroke-width="1.6"/>'
    body += f'<ellipse cx="33" cy="74" rx="5" ry="3.4" fill="#3a2a1c" stroke="{INK}" stroke-width="1.6"/>'
    body += f'<rect x="19" y="60" width="6" height="13" fill="#6b5236" stroke="{INK}" stroke-width="1.4"/>'
    body += f'<rect x="30" y="60" width="6" height="13" fill="#5d462e" stroke="{INK}" stroke-width="1.4"/>'
    body += f'<path d="M17,30 Q12,48 10,66 Q28,71 46,66 Q43,48 39,30 Z" fill="url(#cloak)" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    body += '<path d="M18,36 Q15,50 14,62" stroke="#5fae95" stroke-width="2" fill="none" opacity="0.7"/>'
    body += f'<path d="M20,32 L38,52" stroke="#6b4a2e" stroke-width="3"/>'
    body += f'<rect x="33" y="48" width="10" height="9" rx="2" fill="#8a6440" stroke="{INK}" stroke-width="1.5"/>'
    body += f'<path d="M18,30 Q28,36 39,30 L37,26 Q28,30 20,26 Z" fill="#c0452f" stroke="{INK}" stroke-width="1.6"/>'
    body += f'<circle cx="28" cy="18" r="11" fill="#2f6b5e" stroke="{INK}" stroke-width="2.4"/>'
    body += '<path d="M19,14 Q22,7 30,8" stroke="#4f9c84" stroke-width="2.4" fill="none"/>'
    body += f'<ellipse cx="30" cy="21" rx="6.5" ry="6" fill="#2a2018"/>'
    body += f'<ellipse cx="31" cy="23" rx="4.6" ry="3.8" fill="#e6b48a"/>'
    body += f'<line x1="46" y1="10" x2="47" y2="74" stroke="#6b4a2e" stroke-width="3" stroke-linecap="round"/>'
    body += f'<line x1="46" y1="10" x2="47" y2="74" stroke="{INK}" stroke-width="0.8" opacity="0.6"/>'
    body += '<circle cx="46" cy="9" r="9" fill="url(#lamp)"/>'
    body += f'<circle cx="46" cy="9" r="3.2" fill="#ffe28a" stroke="{INK}" stroke-width="1.2"/>'
    body += f'<ellipse cx="44" cy="40" rx="4" ry="3.5" fill="#e6b48a" stroke="{INK}" stroke-width="1.3"/>'
    return w, h, svg(w, h, body, defs)


def dragon_ember():
    w, h = 128, 104
    defs = ('<linearGradient id="wingE" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f08a45"/>'
            '<stop offset="1" stop-color="#b8442a"/></linearGradient>'
            '<linearGradient id="bodyE" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e86a34"/>'
            '<stop offset="1" stop-color="#b8402a"/></linearGradient>')
    # back wing (darker), drawn first
    body = f'<path d="M58,52 L34,8 Q30,22 22,26 Q24,36 14,42 Q24,50 20,58 Q38,54 52,62 Z" fill="#9a3420" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    # tail
    body += f'<path d="M44,64 Q24,70 14,82 Q8,92 18,94 Q14,86 26,80 Q38,74 52,72 Z" fill="url(#bodyE)" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    body += f'<path d="M18,94 Q6,96 4,88 Q10,90 12,84 Q14,90 18,94 Z" fill="#ffcf5a" stroke="{INK}" stroke-width="1.6"/>'
    # body
    body += f'<path d="M40,64 Q50,50 72,52 Q90,54 96,48 L100,58 Q90,72 70,74 Q52,76 40,64 Z" fill="url(#bodyE)" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
    body += '<path d="M48,68 Q62,74 80,68 Q90,64 96,58" stroke="#f6c060" stroke-width="5" fill="none" stroke-linecap="round"/>'
    for i in range(6):
        x = 50 + i * 8
        body += f'<polygon points="{x},{54 - (i % 2)} {x + 4},{46 - (i % 2) * 2} {x + 7},{54}" fill="#7a2614" stroke="{INK}" stroke-width="1.2"/>'
    # legs tucked
    body += f'<path d="M60,72 q-2,8 -8,9" stroke="{INK}" stroke-width="5" stroke-linecap="round" fill="none"/>'
    body += f'<path d="M60,72 q-2,8 -8,9" stroke="#c4502c" stroke-width="3" stroke-linecap="round" fill="none"/>'
    body += f'<path d="M82,70 q0,8 -6,10" stroke="{INK}" stroke-width="5" stroke-linecap="round" fill="none"/>'
    body += f'<path d="M82,70 q0,8 -6,10" stroke="#c4502c" stroke-width="3" stroke-linecap="round" fill="none"/>'
    # neck + head
    body += f'<path d="M90,52 Q98,40 108,38 Q120,38 124,46 Q118,48 116,52 Q108,54 100,60 Z" fill="url(#bodyE)" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    body += f'<path d="M106,38 Q100,28 92,26 Q100,34 102,40 Z" fill="#3a2418" stroke="{INK}" stroke-width="1.4"/>'
    body += f'<path d="M112,38 Q110,26 104,22 Q110,32 109,39 Z" fill="#3a2418" stroke="{INK}" stroke-width="1.4"/>'
    body += f'<ellipse cx="113" cy="43" rx="3" ry="2.2" fill="#ffe27a" stroke="{INK}" stroke-width="1"/>'
    body += '<circle cx="122" cy="45" r="1" fill="#2a1d14"/>'
    body += '<circle cx="126" cy="41" r="2" fill="#bfb8b0" opacity="0.6"/><circle cx="127" cy="36" r="2.6" fill="#bfb8b0" opacity="0.4"/>'
    # front wing (lit)
    body += (f'<path d="M66,54 L98,4 Q100,18 108,22 Q104,30 112,36 Q100,38 98,46 Q88,46 78,58 Z" fill="url(#wingE)" '
             f'stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>')
    for tx, ty in [(108, 22), (112, 36), (98, 46)]:
        body += f'<line x1="70" y1="54" x2="{tx}" y2="{ty}" stroke="#8e2f1c" stroke-width="1.6" opacity="0.8"/>'
    body += '<path d="M70,50 L96,10" stroke="#ffc07a" stroke-width="2" opacity="0.8"/>'
    return w, h, svg(w, h, body, defs)


def dragon_moss():
    w, h = 96, 72
    defs = ('<linearGradient id="bodyM" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6faa52"/>'
            '<stop offset="1" stop-color="#4c8540"/></linearGradient>')
    # far legs
    body = f'<rect x="30" y="50" width="9" height="14" rx="4" fill="#3d6c35" stroke="{INK}" stroke-width="2"/>'
    body += f'<rect x="62" y="50" width="9" height="14" rx="4" fill="#3d6c35" stroke="{INK}" stroke-width="2"/>'
    # tail
    body += f'<path d="M24,44 Q10,44 6,36 Q4,30 10,32 Q14,38 26,38 Z" fill="url(#bodyM)" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>'
    body += f'<path d="M8,33 Q0,26 4,20 Q10,26 10,32 Z" fill="#8fd16a" stroke="{INK}" stroke-width="1.6"/>'
    # body
    body += f'<path d="M20,42 Q22,24 46,24 Q70,22 78,34 Q80,52 60,56 L34,56 Q20,54 20,42 Z" fill="url(#bodyM)" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
    body += '<path d="M28,52 Q48,58 70,50" stroke="#c4d888" stroke-width="5" fill="none" stroke-linecap="round"/>'
    for cx, cy, rr in [(38, 36, 4), (50, 32, 3.2), (60, 40, 3.6), (44, 46, 2.6), (68, 34, 2.4)]:
        body += f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="#3f8a7f" opacity="0.75"/>'
    # fern fronds along back
    for i, (x, y, a) in enumerate([(30, 30, -40), (40, 25, -25), (51, 23, -10), (62, 25, 5), (71, 29, 20)]):
        body += (f'<g transform="rotate({a} {x} {y})"><path d="M{x},{y} Q{x - 6},{y - 9} {x},{y - 18} Q{x + 6},{y - 9} {x},{y} Z" '
                 f'fill="#8fd16a" stroke="{INK}" stroke-width="1.6"/><line x1="{x}" y1="{y}" x2="{x}" y2="{y - 16}" stroke="#4f8a3a" stroke-width="1.2"/></g>')
    # near legs
    body += f'<rect x="24" y="50" width="11" height="16" rx="5" fill="#4f8a44" stroke="{INK}" stroke-width="2.2"/>'
    body += f'<rect x="56" y="50" width="11" height="16" rx="5" fill="#4f8a44" stroke="{INK}" stroke-width="2.2"/>'
    for x in (26, 30, 58, 62):
        body += f'<circle cx="{x + 1}" cy="66" r="1.6" fill="#e9e2c8"/>'
    # head
    body += f'<path d="M70,36 Q72,22 84,22 Q94,24 94,34 Q94,42 84,44 Q76,46 70,42 Z" fill="url(#bodyM)" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>'
    body += f'<path d="M78,23 Q74,14 70,12 M76,17 L71,18" stroke="#7a5634" stroke-width="2.4" stroke-linecap="round" fill="none"/>'
    body += f'<path d="M86,22 Q88,12 94,10 M89,15 L94,16" stroke="#7a5634" stroke-width="2.4" stroke-linecap="round" fill="none"/>'
    body += '<ellipse cx="71" cy="12" rx="3" ry="1.8" fill="#8fd16a"/><ellipse cx="94" cy="10" rx="3" ry="1.8" fill="#8fd16a"/>'
    body += f'<circle cx="86" cy="31" r="3.4" fill="#f0b24a" stroke="{INK}" stroke-width="1.2"/><circle cx="87" cy="31" r="1.5" fill="#2a1d14"/>'
    body += '<circle cx="85.5" cy="30" r="0.7" fill="#fff"/>'
    body += '<path d="M86,40 Q90,41 93,38" stroke="#2a1d14" stroke-width="1.2" fill="none"/>'
    return w, h, svg(w, h, body, defs)


SPRITES = {
    "decor/tree_oak": tree_oak,
    "decor/tree_pine": tree_pine,
    "decor/bush": bush,
    "decor/rocks": rocks,
    "decor/mountain_a": lambda: mountain("a"),
    "decor/mountain_b": lambda: mountain("b"),
    "decor/bridge": bridge,
    "landmarks/camp": camp,
    "landmarks/watchtower": watchtower,
    "landmarks/lodge": lodge,
    "landmarks/standing_stones": standing_stones,
    "landmarks/dragon_nest": dragon_nest,
    "actors/adventurer": adventurer,
    "dragons/ember": dragon_ember,
    "dragons/moss": dragon_moss,
}

TEXTURES = {
    "terrain/grass": terrain_grass,
    "terrain/forest_floor": terrain_forest_floor,
    "terrain/road": terrain_road,
    "terrain/water": terrain_water,
    "terrain/rock": terrain_rock,
    "fog/clouds": fog_clouds,
}


def template_path(logical):
    folder, name = logical.split("/")
    return f"{folder}/template_{name}.png"


def add_grain(path, seed):
    """Light paper grain on opaque pixels, shared by every sprite for a coherent finish."""
    img = Image.open(path).convert("RGBA")
    a = np.asarray(img).astype(np.float32)
    rng = np.random.default_rng(seed)
    grain = rng.normal(0, 1, a.shape[:2]).astype(np.float32)
    a[..., :3] *= (1 + 0.035 * grain)[..., None]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").save(path)


def main():
    for i, (logical, fn) in enumerate(TEXTURES.items()):
        save(fn(_PyRng(100 + i)), template_path(logical))
    with tempfile.TemporaryDirectory() as tmp:
        jobs = []
        for logical, fn in SPRITES.items():
            w, h, text = fn()
            svg_path = Path(tmp) / (logical.replace("/", "_") + ".svg")
            svg_path.write_text(text)
            png = Path(tmp) / (logical.replace("/", "_") + ".png")
            jobs.append({"svg": str(svg_path), "png": str(png), "width": w, "height": h, "scale": 2, "logical": logical})
        jobs_file = Path(tmp) / "jobs.json"
        jobs_file.write_text(json.dumps(jobs))
        subprocess.run(["node", str(HERE / "render_svg.js"), str(jobs_file)], check=True, cwd=HERE)
        for i, job in enumerate(jobs):
            big = Image.open(job["png"]).convert("RGBA")
            small = big.resize((job["width"], job["height"]), Image.LANCZOS)
            dest = OUT / template_path(job["logical"])
            dest.parent.mkdir(parents=True, exist_ok=True)
            small.save(dest)
            add_grain(dest, 500 + i)
            print("wrote", dest.relative_to(ROOT))


class _PyRng:
    """Adapter giving numpy-style random() arrays and python-style helpers from one seed."""

    def __init__(self, seed):
        self._np = np.random.default_rng(seed)
        self._py = random.Random(seed)

    def random(self, shape=None):
        return self._np.random(shape) if shape is not None else self._py.random()

    def uniform(self, a, b):
        return self._py.uniform(a, b)

    def randrange(self, *args):
        return self._py.randrange(*args)


if __name__ == "__main__":
    main()
