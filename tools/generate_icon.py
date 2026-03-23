"""Generate the Last Signal project icon.

Design: A geometric beacon/spire (amber/gold) broadcasting cyan signal arcs
upward against a deep navy background. Matches the game's procedural geometric
art style and directly evokes the game name "Last Signal".

Output: icon.png (1024x1024) in project root.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

# Render at 2x for anti-aliasing, downscale at end
R = 2048
OUT = 1024
S = R / OUT

def sc(v):
    return int(v * S)

def scp(pts):
    return [(int(x * S), int(y * S)) for x, y in pts]

# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
canvas = Image.new('RGBA', (R, R), (7, 11, 20, 255))

# ---------------------------------------------------------------------------
# Background: subtle radial glow from upper-center
# ---------------------------------------------------------------------------
bg_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
gd = ImageDraw.Draw(bg_glow)
cx, cy = R // 2, sc(370)
max_r = sc(340)
for radius in range(max_r, 0, -4):
    t = 1 - radius / max_r
    opacity = int(55 * t * t)
    ry = int(radius * 0.8)
    gd.ellipse([cx - radius, cy - ry, cx + radius, cy + ry],
               fill=(14, 28, 52, opacity))
canvas = Image.alpha_composite(canvas, bg_glow)

# ---------------------------------------------------------------------------
# Subtle hex grid texture (faint sci-fi background)
# ---------------------------------------------------------------------------
hex_layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
hd = ImageDraw.Draw(hex_layer)

hex_r = sc(42)
hex_w = hex_r * 2
hex_h = int(hex_r * math.sqrt(3))

for row in range(-1, 14):
    for col in range(-1, 14):
        hx = int(col * hex_w * 0.75 + R * 0.08)
        hy = int(row * hex_h + (col % 2) * hex_h * 0.5 + R * 0.05)
        pts = []
        for i in range(6):
            angle = math.radians(60 * i + 30)
            px = hx + int(hex_r * math.cos(angle))
            py = hy + int(hex_r * math.sin(angle))
            pts.append((px, py))
        hd.polygon(pts, outline=(0, 160, 210, 10))

canvas = Image.alpha_composite(canvas, hex_layer)

# ---------------------------------------------------------------------------
# Signal arcs: 3 concentric arcs emanating upward from beacon
# Arc center at (512, 410) in design space
# 140-degree arcs centered on north (200 to 340 in PIL angles)
# ---------------------------------------------------------------------------
acx, acy = sc(512), sc(410)

arcs = [
    # (radius, stroke_width, sharp_opacity, glow_opacity)
    (sc(275), sc(7),  70,  20),   # outer
    (sc(190), sc(9),  145, 40),   # middle
    (sc(108), sc(11), 235, 65),   # inner
]

# Glow layer (blurred arcs behind)
arc_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ag = ImageDraw.Draw(arc_glow)
for radius, width, _, glow_op in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ag.arc(bbox, 200, 340, fill=(0, 190, 245, glow_op), width=width + sc(16))
arc_glow = arc_glow.filter(ImageFilter.GaussianBlur(radius=sc(10)))
canvas = Image.alpha_composite(canvas, arc_glow)

# Sharp arc layer
arc_sharp = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ash = ImageDraw.Draw(arc_sharp)
for radius, width, sharp_op, _ in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ash.arc(bbox, 200, 340, fill=(0, 212, 255, sharp_op), width=width)
canvas = Image.alpha_composite(canvas, arc_sharp)

# ---------------------------------------------------------------------------
# Beacon glow (warm radial glow at antenna tip)
# ---------------------------------------------------------------------------
bx, by = sc(512), sc(355)

beacon_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
bg_d = ImageDraw.Draw(beacon_glow)
glow_r = sc(65)
for r in range(glow_r, 0, -1):
    t = 1 - r / glow_r
    opacity = int(100 * t * t * t)
    rv = 255
    gv = int(200 + 55 * t)
    bv = int(60 + 195 * t)
    bg_d.ellipse([bx - r, by - r, bx + r, by + r], fill=(rv, gv, bv, opacity))
canvas = Image.alpha_composite(canvas, beacon_glow)

# ---------------------------------------------------------------------------
# Antenna mast + cross arm
# ---------------------------------------------------------------------------
ant = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ad = ImageDraw.Draw(ant)

# Mast
ad.line([(sc(512), sc(355)), (sc(512), sc(440))],
        fill=(255, 190, 60, 255), width=sc(7))
# Cross arm
ad.line([(sc(486), sc(394)), (sc(538), sc(394))],
        fill=(255, 190, 60, 200), width=sc(5))
# Small dish circle
r_dish = sc(10)
ad.ellipse([sc(512) - r_dish, sc(415) - r_dish,
            sc(512) + r_dish, sc(415) + r_dish],
           outline=(255, 170, 40, 130), width=sc(3))

canvas = Image.alpha_composite(canvas, ant)

# ---------------------------------------------------------------------------
# Tower / spire body — segmented sci-fi structure
# ---------------------------------------------------------------------------
tower = Image.new('RGBA', (R, R), (0, 0, 0, 0))
td = ImageDraw.Draw(tower)

# Tower is built from 4 segments, each a trapezoid getting wider toward base.
# This gives a technological, tiered appearance.
#
#     /\        tip (y 440-485)
#    /  \
#   |    |      upper (y 485-575)
#   |    |
#  |      |     middle (y 575-680)
#  |      |
# |        |    lower (y 680-790)
# |________|

segments = [
    # (y_top, half_width_top, y_bot, half_width_bot, fill_color)
    (440, 14,  490, 36,  (245, 180, 45)),   # tip - brightest
    (490, 38,  580, 50,  (225, 155, 30)),   # upper
    (580, 52,  680, 60,  (205, 130, 18)),   # middle
    (680, 62,  790, 66,  (180, 108, 10)),   # lower - darkest
]

# Tower glow (subtle amber aura behind tower body)
tower_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
tg_draw = ImageDraw.Draw(tower_glow)
for gr in range(sc(40), 0, -1):
    t = 1 - gr / sc(40)
    tg_draw.rounded_rectangle(
        [sc(512 - 66 - 40 + gr), sc(440 - 10 + gr),
         sc(512 + 66 + 40 - gr), sc(790 + 10 - gr)],
        radius=sc(10), fill=(255, 160, 30, int(12 * t)))
tower_glow = tower_glow.filter(ImageFilter.GaussianBlur(radius=sc(12)))
canvas = Image.alpha_composite(canvas, tower_glow)

# Draw segments as flat trapezoids
for y_top, hw_top, y_bot, hw_bot, color in segments:
    seg = scp([
        (512 - hw_top, y_top), (512 + hw_top, y_top),
        (512 + hw_bot, y_bot), (512 - hw_bot, y_bot),
    ])
    td.polygon(seg, fill=(*color, 255))

# Separator lines between segments (bright amber accents)
for y_top, hw_top, _, _, _ in segments[1:]:
    td.line(scp([(512 - hw_top - 3, y_top), (512 + hw_top + 3, y_top)]),
            fill=(255, 220, 120, 160), width=sc(2))

# Left edge rim light
for y_top, hw_top, y_bot, hw_bot, _ in segments:
    td.line(scp([(512 - hw_top, y_top), (512 - hw_bot, y_bot)]),
            fill=(255, 210, 100, 70), width=sc(2))

# Right edge darker outline
for y_top, hw_top, y_bot, hw_bot, _ in segments:
    td.line(scp([(512 + hw_top, y_top), (512 + hw_bot, y_bot)]),
            fill=(140, 80, 0, 50), width=sc(2))

canvas = Image.alpha_composite(canvas, tower)

# ---------------------------------------------------------------------------
# Beacon light (bright white dot at antenna tip)
# ---------------------------------------------------------------------------
light = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ld = ImageDraw.Draw(light)

# Outer warm ring
r1 = sc(15)
ld.ellipse([bx - r1, by - r1, bx + r1, by + r1],
           fill=(255, 240, 200, 240))
# Inner bright white
r2 = sc(9)
ld.ellipse([bx - r2, by - r2, bx + r2, by + r2],
           fill=(255, 255, 255, 255))

canvas = Image.alpha_composite(canvas, light)

# ---------------------------------------------------------------------------
# Base platform
# ---------------------------------------------------------------------------
base = Image.new('RGBA', (R, R), (0, 0, 0, 0))
bd = ImageDraw.Draw(base)

# Upper platform
bd.rounded_rectangle(
    [sc(460), sc(790), sc(564), sc(800)],
    radius=sc(5), fill=(22, 36, 54, 210))
# Lower wider platform
bd.rounded_rectangle(
    [sc(442), sc(800), sc(582), sc(810)],
    radius=sc(4), fill=(14, 26, 40, 190))

canvas = Image.alpha_composite(canvas, base)

# ---------------------------------------------------------------------------
# Subtle border glow on the rounded rect edge
# ---------------------------------------------------------------------------
border = Image.new('RGBA', (R, R), (0, 0, 0, 0))
brd = ImageDraw.Draw(border)
brd.rounded_rectangle([0, 0, R - 1, R - 1], radius=sc(200),
                       outline=(0, 170, 220, 22), width=sc(3))
canvas = Image.alpha_composite(canvas, border)

# ---------------------------------------------------------------------------
# Apply rounded rect mask (clip to icon shape)
# ---------------------------------------------------------------------------
mask = Image.new('L', (R, R), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, R - 1, R - 1], radius=sc(200), fill=255)

final = Image.new('RGBA', (R, R), (0, 0, 0, 0))
final.paste(canvas, mask=mask)

# ---------------------------------------------------------------------------
# Downscale with Lanczos for smooth anti-aliasing
# ---------------------------------------------------------------------------
result = final.resize((OUT, OUT), Image.LANCZOS)

# Save
out_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'icon.png')
result.save(out_path, 'PNG')
print(f"Icon saved to {out_path} ({OUT}x{OUT})")
