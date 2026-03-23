"""Generate the Last Signal project icon.

Design: A geometric beacon/spire (amber/gold) broadcasting cyan signal arcs
upward against a deep navy background. Matches the game's procedural geometric
art style and directly evokes the game name "Last Signal".

Output: icon.png (1024x1024) in project root.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

# Render at 3x for crisp anti-aliasing, downscale at end
R = 3072
OUT = 1024
S = R / OUT

def sc(v):
    return int(v * S)

def scp(pts):
    return [(int(x * S), int(y * S)) for x, y in pts]

# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
canvas = Image.new('RGBA', (R, R), (6, 10, 18, 255))

# ---------------------------------------------------------------------------
# Background: radial glow from upper-center
# ---------------------------------------------------------------------------
bg_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
gd = ImageDraw.Draw(bg_glow)
cx, cy = R // 2, sc(370)
max_r = sc(360)
for radius in range(max_r, 0, -3):
    t = 1 - radius / max_r
    opacity = int(60 * t * t)
    ry = int(radius * 0.8)
    gd.ellipse([cx - radius, cy - ry, cx + radius, cy + ry],
               fill=(12, 25, 48, opacity))
canvas = Image.alpha_composite(canvas, bg_glow)

# ---------------------------------------------------------------------------
# Stars / distant particles
# ---------------------------------------------------------------------------
star_layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
random.seed(42)  # deterministic
for _ in range(60):
    sx = random.randint(sc(40), sc(984))
    sy = random.randint(sc(40), sc(984))
    sr = random.choice([sc(1), sc(1), sc(2)])
    sa = random.randint(15, 55)
    sd.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
               fill=(180, 210, 240, sa))
canvas = Image.alpha_composite(canvas, star_layer)

# ---------------------------------------------------------------------------
# Hex grid texture (faint sci-fi background)
# ---------------------------------------------------------------------------
hex_layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
hd = ImageDraw.Draw(hex_layer)

hex_r = sc(44)
hex_w = hex_r * 2
hex_h = int(hex_r * math.sqrt(3))

for row in range(-1, 15):
    for col in range(-1, 15):
        hx = int(col * hex_w * 0.75 + R * 0.06)
        hy = int(row * hex_h + (col % 2) * hex_h * 0.5 + R * 0.03)
        # Fade hex opacity based on distance from center
        dist = math.sqrt((hx - R // 2) ** 2 + (hy - sc(500)) ** 2)
        alpha = max(0, int(14 * (1 - dist / (R * 0.6))))
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
# Signal arcs: 3 concentric arcs emanating upward from beacon
# Arc center at (512, 410), 140-degree arcs centered on north
# ---------------------------------------------------------------------------
acx, acy = sc(512), sc(410)

arcs = [
    # (radius, stroke_width, sharp_opacity, glow_opacity)
    (sc(275), sc(6),  75,  22),   # outer
    (sc(190), sc(8),  150, 45),   # middle
    (sc(108), sc(10), 240, 70),   # inner
]

# Wide soft glow behind arcs
arc_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ag = ImageDraw.Draw(arc_glow)
for radius, width, _, glow_op in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ag.arc(bbox, 195, 345, fill=(0, 180, 240, glow_op), width=width + sc(22))
arc_glow = arc_glow.filter(ImageFilter.GaussianBlur(radius=sc(12)))
canvas = Image.alpha_composite(canvas, arc_glow)

# Sharp arcs
arc_sharp = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ash = ImageDraw.Draw(arc_sharp)
for radius, width, sharp_op, _ in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ash.arc(bbox, 200, 340, fill=(0, 212, 255, sharp_op), width=width)
canvas = Image.alpha_composite(canvas, arc_sharp)

# Arc endpoint dots (small bright dots at each arc tip)
arc_dots = Image.new('RGBA', (R, R), (0, 0, 0, 0))
acd = ImageDraw.Draw(arc_dots)
for radius, _, sharp_op, _ in arcs:
    for angle_deg in [200, 340]:
        angle = math.radians(angle_deg)
        dx = acx + int(radius * math.cos(angle))
        dy = acy + int(radius * math.sin(angle))
        dr = sc(4)
        acd.ellipse([dx - dr, dy - dr, dx + dr, dy + dr],
                    fill=(0, 212, 255, sharp_op))
canvas = Image.alpha_composite(canvas, arc_dots)

# ---------------------------------------------------------------------------
# Beacon glow — larger, with subtle upward rays
# ---------------------------------------------------------------------------
bx, by = sc(512), sc(355)

# Upward light rays (subtle vertical streaks from beacon)
rays = Image.new('RGBA', (R, R), (0, 0, 0, 0))
rd = ImageDraw.Draw(rays)
for angle_offset in [-18, -8, 0, 8, 18]:
    angle = math.radians(270 + angle_offset)
    ex = bx + int(sc(90) * math.cos(angle))
    ey = by + int(sc(90) * math.sin(angle))
    rd.line([(bx, by), (ex, ey)], fill=(255, 230, 150, 18), width=sc(3))
rays = rays.filter(ImageFilter.GaussianBlur(radius=sc(5)))
canvas = Image.alpha_composite(canvas, rays)

# Main radial glow
beacon_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
bg_d = ImageDraw.Draw(beacon_glow)
glow_r = sc(80)
for r in range(glow_r, 0, -1):
    t = 1 - r / glow_r
    opacity = int(110 * t * t * t)
    rv = 255
    gv = int(200 + 55 * t)
    bv = int(50 + 205 * t)
    bg_d.ellipse([bx - r, by - r, bx + r, by + r], fill=(rv, gv, bv, opacity))
canvas = Image.alpha_composite(canvas, beacon_glow)

# ---------------------------------------------------------------------------
# Antenna mast + cross arm
# ---------------------------------------------------------------------------
ant = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ad = ImageDraw.Draw(ant)

# Mast (slightly thicker)
ad.line([(sc(512), sc(355)), (sc(512), sc(440))],
        fill=(255, 190, 60, 255), width=sc(8))
# Cross arm
ad.line([(sc(484), sc(392)), (sc(540), sc(392))],
        fill=(255, 190, 60, 210), width=sc(5))
# Small dish circle
r_dish = sc(11)
ad.ellipse([sc(512) - r_dish, sc(416) - r_dish,
            sc(512) + r_dish, sc(416) + r_dish],
           outline=(255, 175, 45, 150), width=sc(3))

canvas = Image.alpha_composite(canvas, ant)

# ---------------------------------------------------------------------------
# Tower / spire body — segmented sci-fi structure
# ---------------------------------------------------------------------------
tower = Image.new('RGBA', (R, R), (0, 0, 0, 0))
td = ImageDraw.Draw(tower)

segments = [
    # (y_top, half_width_top, y_bot, half_width_bot, fill_color)
    (440, 14,  490, 36,  (245, 180, 45)),   # tip - brightest
    (490, 38,  575, 50,  (225, 155, 30)),   # upper
    (575, 52,  675, 60,  (205, 130, 18)),   # middle
    (675, 62,  785, 66,  (180, 108, 10)),   # lower - darkest
]

# Tower glow (amber aura behind body)
tower_glow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
tg_draw = ImageDraw.Draw(tower_glow)
for gr in range(sc(45), 0, -1):
    t = 1 - gr / sc(45)
    tg_draw.rounded_rectangle(
        [sc(512 - 70 - 45) + gr, sc(435) + gr,
         sc(512 + 70 + 45) - gr, sc(795) - gr],
        radius=sc(10), fill=(255, 150, 25, int(14 * t)))
tower_glow = tower_glow.filter(ImageFilter.GaussianBlur(radius=sc(14)))
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
    td.line(scp([(512 - hw_top - 4, y_top), (512 + hw_top + 4, y_top)]),
            fill=(255, 225, 130, 180), width=sc(2))

# Center status indicator on each segment (small horizontal dash)
for y_top, hw_top, y_bot, hw_bot, color in segments[1:]:  # skip tip
    mid_y = (y_top + y_bot) // 2
    dash_hw = 8
    td.line(scp([(512 - dash_hw, mid_y), (512 + dash_hw, mid_y)]),
            fill=(255, 230, 140, 50), width=sc(2))

# Left edge rim light
for y_top, hw_top, y_bot, hw_bot, _ in segments:
    td.line(scp([(512 - hw_top, y_top), (512 - hw_bot, y_bot)]),
            fill=(255, 215, 110, 80), width=sc(2))

# Right edge darker outline
for y_top, hw_top, y_bot, hw_bot, _ in segments:
    td.line(scp([(512 + hw_top, y_top), (512 + hw_bot, y_bot)]),
            fill=(130, 75, 0, 55), width=sc(2))

# Top and bottom outlines
y_t, hw_t = segments[0][0], segments[0][1]
td.line(scp([(512 - hw_t, y_t), (512 + hw_t, y_t)]),
        fill=(255, 220, 100, 90), width=sc(2))
y_b, _, _, hw_b, _ = segments[-1]
td.line(scp([(512 - segments[-1][3], segments[-1][2]),
             (512 + segments[-1][3], segments[-1][2])]),
        fill=(130, 75, 0, 55), width=sc(2))

canvas = Image.alpha_composite(canvas, tower)

# ---------------------------------------------------------------------------
# Beacon light (bright white dot at antenna tip)
# ---------------------------------------------------------------------------
light = Image.new('RGBA', (R, R), (0, 0, 0, 0))
ld = ImageDraw.Draw(light)

# Outer warm ring
r1 = sc(16)
ld.ellipse([bx - r1, by - r1, bx + r1, by + r1],
           fill=(255, 240, 200, 245))
# Inner bright white
r2 = sc(10)
ld.ellipse([bx - r2, by - r2, bx + r2, by + r2],
           fill=(255, 255, 255, 255))

canvas = Image.alpha_composite(canvas, light)

# ---------------------------------------------------------------------------
# Base platform (wider, more defined)
# ---------------------------------------------------------------------------
base = Image.new('RGBA', (R, R), (0, 0, 0, 0))
bd = ImageDraw.Draw(base)

# Upper platform
bd.rounded_rectangle(
    [sc(455), sc(785), sc(569), sc(797)],
    radius=sc(4), fill=(25, 40, 60, 220))
# Bright edge line on top of platform
bd.line(scp([(458, 785), (566, 785)]),
        fill=(60, 90, 120, 120), width=sc(2))
# Lower wider platform
bd.rounded_rectangle(
    [sc(438), sc(797), sc(586), sc(808)],
    radius=sc(4), fill=(16, 28, 44, 200))
# Ground shadow
ground_shadow = Image.new('RGBA', (R, R), (0, 0, 0, 0))
gs_draw = ImageDraw.Draw(ground_shadow)
gs_draw.ellipse([sc(440), sc(805), sc(584), sc(825)],
                fill=(0, 0, 0, 40))
ground_shadow = ground_shadow.filter(ImageFilter.GaussianBlur(radius=sc(6)))
canvas = Image.alpha_composite(canvas, ground_shadow)

canvas = Image.alpha_composite(canvas, base)

# ---------------------------------------------------------------------------
# Vignette (darken edges for depth)
# ---------------------------------------------------------------------------
vignette = Image.new('RGBA', (R, R), (0, 0, 0, 0))
vd = ImageDraw.Draw(vignette)
vig_cx, vig_cy = R // 2, R // 2
vig_max = int(R * 0.72)
for r in range(R, vig_max, -2):
    t = (r - vig_max) / (R - vig_max)
    opacity = int(50 * t * t)
    vd.ellipse([vig_cx - r, vig_cy - r, vig_cx + r, vig_cy + r],
               fill=(0, 0, 0, opacity))
canvas = Image.alpha_composite(canvas, vignette)

# ---------------------------------------------------------------------------
# Border glow (subtle cyan edge)
# ---------------------------------------------------------------------------
border = Image.new('RGBA', (R, R), (0, 0, 0, 0))
brd = ImageDraw.Draw(border)
brd.rounded_rectangle([sc(2), sc(2), R - sc(2), R - sc(2)], radius=sc(200),
                       outline=(0, 160, 210, 25), width=sc(3))
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
