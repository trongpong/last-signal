"""Generate the Last Signal Play Store feature graphic (1024x500).

Layout: beacon tower on the left, signal arcs expanding right,
"LAST SIGNAL" title in amber/gold, tagline in cyan.
Dark navy background with hex grid texture.

Output: feature_graphic.png (1024x500) in project root.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os
import random

W, H = 2048, 1000  # 2x for AA
OUT_W, OUT_H = 1024, 500
S = W / OUT_W

def sc(v):
    return int(v * S)

def scp(pts):
    return [(int(x * S), int(y * S)) for x, y in pts]

# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
canvas = Image.new('RGBA', (W, H), (6, 10, 18, 255))

# ---------------------------------------------------------------------------
# Background radial glow (centered left of middle, where tower is)
# ---------------------------------------------------------------------------
bg_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(bg_glow)
gcx, gcy = sc(300), sc(220)
max_r = sc(380)
for radius in range(max_r, 0, -4):
    t = 1 - radius / max_r
    opacity = int(50 * t * t)
    ry = int(radius * 0.7)
    gd.ellipse([gcx - radius, gcy - ry, gcx + radius, gcy + ry],
               fill=(12, 25, 48, opacity))
canvas = Image.alpha_composite(canvas, bg_glow)

# ---------------------------------------------------------------------------
# Stars
# ---------------------------------------------------------------------------
star_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
random.seed(99)
for _ in range(40):
    sx = random.randint(sc(20), W - sc(20))
    sy = random.randint(sc(20), H - sc(20))
    sr = random.choice([sc(1), sc(1), sc(2)])
    sa = random.randint(15, 50)
    sd.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
               fill=(180, 210, 240, sa))
canvas = Image.alpha_composite(canvas, star_layer)

# ---------------------------------------------------------------------------
# Hex grid (fading from center)
# ---------------------------------------------------------------------------
hex_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
hd = ImageDraw.Draw(hex_layer)
hex_r = sc(36)
hex_w = hex_r * 2
hex_h = int(hex_r * math.sqrt(3))

for row in range(-1, 10):
    for col in range(-1, 18):
        hx = int(col * hex_w * 0.75 + W * 0.04)
        hy = int(row * hex_h + (col % 2) * hex_h * 0.5 + H * 0.03)
        dist = math.sqrt((hx - W * 0.35) ** 2 + (hy - H * 0.5) ** 2)
        alpha = max(0, int(12 * (1 - dist / (W * 0.5))))
        if alpha < 2:
            continue
        pts = []
        for i in range(6):
            angle = math.radians(60 * i + 30)
            px = hx + int(hex_r * math.cos(angle))
            py = hy + int(hex_r * math.sin(angle))
            pts.append((px, py))
        hd.polygon(pts, outline=(0, 150, 200, alpha))

canvas = Image.alpha_composite(canvas, hex_layer)

# ---------------------------------------------------------------------------
# Signal arcs (centered on tower tip, expanding rightward)
# Arc center at (300, 195) design coords
# Wider arcs than icon — 160 degree sweep biased right
# ---------------------------------------------------------------------------
acx, acy = sc(300), sc(200)

arcs = [
    (sc(100), sc(5), 240, 70),
    (sc(175), sc(4), 150, 45),
    (sc(255), sc(3), 80, 25),
    (sc(340), sc(3), 40, 12),
]

# Arc glow
arc_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ag = ImageDraw.Draw(arc_glow)
for radius, width, _, glow_op in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ag.arc(bbox, 190, 350, fill=(0, 180, 240, glow_op), width=width + sc(18))
arc_glow = arc_glow.filter(ImageFilter.GaussianBlur(radius=sc(10)))
canvas = Image.alpha_composite(canvas, arc_glow)

# Sharp arcs
arc_sharp = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ash = ImageDraw.Draw(arc_sharp)
for radius, width, sharp_op, _ in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ash.arc(bbox, 195, 345, fill=(0, 212, 255, sharp_op), width=width)
canvas = Image.alpha_composite(canvas, arc_sharp)

# Arc endpoint dots
arc_dots = Image.new('RGBA', (W, H), (0, 0, 0, 0))
acd = ImageDraw.Draw(arc_dots)
for radius, _, sharp_op, _ in arcs:
    for angle_deg in [195, 345]:
        angle = math.radians(angle_deg)
        dx = acx + int(radius * math.cos(angle))
        dy = acy + int(radius * math.sin(angle))
        dr = sc(3)
        acd.ellipse([dx - dr, dy - dr, dx + dr, dy + dr],
                    fill=(0, 212, 255, min(sharp_op, 200)))
canvas = Image.alpha_composite(canvas, arc_dots)

# ---------------------------------------------------------------------------
# Beacon glow + light rays
# ---------------------------------------------------------------------------
bx, by = sc(300), sc(170)

# Light rays
rays = Image.new('RGBA', (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(rays)
for angle_offset in [-20, -10, 0, 10, 20]:
    angle = math.radians(270 + angle_offset)
    ex = bx + int(sc(75) * math.cos(angle))
    ey = by + int(sc(75) * math.sin(angle))
    rd.line([(bx, by), (ex, ey)], fill=(255, 230, 150, 16), width=sc(3))
rays = rays.filter(ImageFilter.GaussianBlur(radius=sc(4)))
canvas = Image.alpha_composite(canvas, rays)

# Radial glow
beacon_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bg_d = ImageDraw.Draw(beacon_glow)
glow_r = sc(60)
for r in range(glow_r, 0, -1):
    t = 1 - r / glow_r
    opacity = int(100 * t * t * t)
    bg_d.ellipse([bx - r, by - r, bx + r, by + r],
                 fill=(255, int(200 + 55 * t), int(50 + 205 * t), opacity))
canvas = Image.alpha_composite(canvas, beacon_glow)

# ---------------------------------------------------------------------------
# Antenna
# ---------------------------------------------------------------------------
ant = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ad = ImageDraw.Draw(ant)
ad.line([(sc(300), sc(170)), (sc(300), sc(225))],
        fill=(255, 190, 60, 255), width=sc(6))
ad.line([(sc(284), sc(196)), (sc(316), sc(196))],
        fill=(255, 190, 60, 200), width=sc(4))
r_dish = sc(8)
ad.ellipse([sc(300) - r_dish, sc(212) - r_dish,
            sc(300) + r_dish, sc(212) + r_dish],
           outline=(255, 175, 45, 140), width=sc(2))
canvas = Image.alpha_composite(canvas, ant)

# ---------------------------------------------------------------------------
# Tower body (smaller, positioned left)
# ---------------------------------------------------------------------------
tower = Image.new('RGBA', (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(tower)

segments = [
    (225, 10, 260, 26, (245, 180, 45)),
    (260, 28, 325, 38, (225, 155, 30)),
    (325, 40, 395, 46, (205, 130, 18)),
    (395, 48, 465, 50, (180, 108, 10)),
]

# Tower glow
tower_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
tg = ImageDraw.Draw(tower_glow)
for gr in range(sc(35), 0, -1):
    t = 1 - gr / sc(35)
    tg.rounded_rectangle(
        [sc(300 - 55 - 35) + gr, sc(220) + gr,
         sc(300 + 55 + 35) - gr, sc(470) - gr],
        radius=sc(8), fill=(255, 150, 25, int(12 * t)))
tower_glow = tower_glow.filter(ImageFilter.GaussianBlur(radius=sc(10)))
canvas = Image.alpha_composite(canvas, tower_glow)

for y_top, hw_top, y_bot, hw_bot, color in segments:
    seg = scp([
        (300 - hw_top, y_top), (300 + hw_top, y_top),
        (300 + hw_bot, y_bot), (300 - hw_bot, y_bot),
    ])
    td.polygon(seg, fill=(*color, 255))

for y_top, hw_top, _, _, _ in segments[1:]:
    td.line(scp([(300 - hw_top - 3, y_top), (300 + hw_top + 3, y_top)]),
            fill=(255, 225, 130, 170), width=sc(2))

for y_top, hw_top, y_bot, hw_bot, _ in segments:
    td.line(scp([(300 - hw_top, y_top), (300 - hw_bot, y_bot)]),
            fill=(255, 215, 110, 70), width=sc(2))
    td.line(scp([(300 + hw_top, y_top), (300 + hw_bot, y_bot)]),
            fill=(130, 75, 0, 50), width=sc(2))

canvas = Image.alpha_composite(canvas, tower)

# Beacon light
light = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(light)
r1 = sc(12)
ld.ellipse([bx - r1, by - r1, bx + r1, by + r1], fill=(255, 240, 200, 245))
r2 = sc(7)
ld.ellipse([bx - r2, by - r2, bx + r2, by + r2], fill=(255, 255, 255, 255))
canvas = Image.alpha_composite(canvas, light)

# Base
base = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(base)
bd.rounded_rectangle([sc(258), sc(465), sc(342), sc(473)], radius=sc(3),
                      fill=(25, 40, 60, 210))
bd.rounded_rectangle([sc(248), sc(473), sc(352), sc(479)], radius=sc(3),
                      fill=(16, 28, 44, 190))
canvas = Image.alpha_composite(canvas, base)

# ---------------------------------------------------------------------------
# Title text: "LAST SIGNAL"
# ---------------------------------------------------------------------------
text_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
txt = ImageDraw.Draw(text_layer)

# Title
try:
    title_font = ImageFont.truetype("arialbd.ttf", sc(52))
except OSError:
    title_font = ImageFont.truetype("arial.ttf", sc(52))

title = "LAST SIGNAL"
title_x, title_y = sc(480), sc(148)

# Title shadow
txt.text((title_x + sc(2), title_y + sc(2)), title,
         font=title_font, fill=(0, 0, 0, 120))
# Title text (amber/gold)
txt.text((title_x, title_y), title,
         font=title_font, fill=(255, 200, 60, 255))

canvas = Image.alpha_composite(canvas, text_layer)

# ---------------------------------------------------------------------------
# Tagline: "THEY ADAPT. WILL YOU?"
# ---------------------------------------------------------------------------
tag_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
tag_draw = ImageDraw.Draw(tag_layer)

try:
    tag_font = ImageFont.truetype("arial.ttf", sc(22))
except OSError:
    tag_font = ImageFont.load_default()

tagline = "THEY ADAPT. WILL YOU?"
tag_x, tag_y = sc(483), sc(218)

tag_draw.text((tag_x, tag_y), tagline,
              font=tag_font, fill=(0, 200, 240, 220))

canvas = Image.alpha_composite(canvas, tag_layer)

# ---------------------------------------------------------------------------
# Subtitle bullets (key features)
# ---------------------------------------------------------------------------
sub_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sub_draw = ImageDraw.Draw(sub_layer)

try:
    sub_font = ImageFont.truetype("arial.ttf", sc(14))
except OSError:
    sub_font = ImageFont.load_default()

features = [
    "Adaptive enemy resistance",
    "7 towers with branching upgrades",
    "8 synergy combos to discover",
    "46-level campaign + endless mode",
    "Daily challenges",
]

feat_x = sc(485)
feat_y = sc(280)
line_h = sc(24)

for i, feat in enumerate(features):
    y = feat_y + i * line_h
    # Bullet dot
    dot_r = sc(3)
    sub_draw.ellipse([feat_x - sc(2), y + sc(5), feat_x + dot_r, y + sc(5) + dot_r],
                     fill=(0, 200, 240, 140))
    # Text
    sub_draw.text((feat_x + sc(12), y), feat,
                  font=sub_font, fill=(180, 200, 220, 200))

canvas = Image.alpha_composite(canvas, sub_layer)

# ---------------------------------------------------------------------------
# Vignette
# ---------------------------------------------------------------------------
vignette = Image.new('RGBA', (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(vignette)
vcx, vcy = W // 2, H // 2
vig_max = int(min(W, H) * 0.7)
for r in range(max(W, H), vig_max, -2):
    t = (r - vig_max) / (max(W, H) - vig_max)
    opacity = int(60 * t * t)
    vd.ellipse([vcx - r, vcy - r, vcx + r, vcy + r],
               fill=(0, 0, 0, opacity))
canvas = Image.alpha_composite(canvas, vignette)

# ---------------------------------------------------------------------------
# Subtle border
# ---------------------------------------------------------------------------
border = Image.new('RGBA', (W, H), (0, 0, 0, 0))
brd = ImageDraw.Draw(border)
brd.rectangle([0, 0, W - 1, H - 1], outline=(0, 160, 210, 18), width=sc(2))
canvas = Image.alpha_composite(canvas, border)

# ---------------------------------------------------------------------------
# Downscale
# ---------------------------------------------------------------------------
result = canvas.resize((OUT_W, OUT_H), Image.LANCZOS)

out_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'feature_graphic.png')
result.save(out_path, 'PNG')
print(f"Feature graphic saved to {out_path} ({OUT_W}x{OUT_H})")
