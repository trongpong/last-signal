"""Generate Android adaptive launcher icons for Last Signal.

Produces:
  - icons/main_192.png           (192x192 legacy icon)
  - icons/adaptive_foreground.png (432x432 foreground layer — beacon on transparent)
  - icons/adaptive_background.png (432x432 background layer — navy + stars)

Adaptive icons use a 108dp safe zone inside a 432x432 canvas (66/432 inset on each side).
The foreground content must fit within the inner 300x300 area to avoid clipping.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
ICONS_DIR = os.path.join(PROJECT_ROOT, "icons")
os.makedirs(ICONS_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# 1. Legacy icon: resize source to 192x192
# ---------------------------------------------------------------------------
src = Image.open(os.path.join(PROJECT_ROOT, "icon.png")).convert("RGBA")
legacy = src.resize((192, 192), Image.LANCZOS)
legacy_path = os.path.join(ICONS_DIR, "main_192.png")
legacy.save(legacy_path, "PNG")
print(f"Legacy icon: {legacy_path}")

# ---------------------------------------------------------------------------
# 2. Adaptive background: navy with subtle stars/hex (432x432)
# ---------------------------------------------------------------------------
BG = 432
R = BG * 3  # render at 3x

bg_canvas = Image.new("RGBA", (R, R), (6, 10, 18, 255))

# Radial glow
glow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
cx, cy = R // 2, R // 2
max_r = int(R * 0.45)
for radius in range(max_r, 0, -3):
    t = 1 - radius / max_r
    opacity = int(50 * t * t)
    gd.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
               fill=(12, 25, 48, opacity))
bg_canvas = Image.alpha_composite(bg_canvas, glow)

# Stars
star_layer = Image.new("RGBA", (R, R), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
random.seed(42)
for _ in range(40):
    sx = random.randint(20, R - 20)
    sy = random.randint(20, R - 20)
    sr = random.choice([2, 2, 3])
    sa = random.randint(15, 55)
    sd.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
               fill=(180, 210, 240, sa))
bg_canvas = Image.alpha_composite(bg_canvas, star_layer)

# Hex grid
hex_layer = Image.new("RGBA", (R, R), (0, 0, 0, 0))
hd = ImageDraw.Draw(hex_layer)
hex_r = int(R * 0.035)
hex_w = hex_r * 2
hex_h = int(hex_r * math.sqrt(3))
for row in range(-1, 12):
    for col in range(-1, 12):
        hx = int(col * hex_w * 0.75 + R * 0.06)
        hy = int(row * hex_h + (col % 2) * hex_h * 0.5 + R * 0.03)
        dist = math.sqrt((hx - R // 2) ** 2 + (hy - R // 2) ** 2)
        alpha = max(0, int(12 * (1 - dist / (R * 0.55))))
        if alpha < 2:
            continue
        pts = []
        for i in range(6):
            angle = math.radians(60 * i + 30)
            px = hx + int(hex_r * math.cos(angle))
            py = hy + int(hex_r * math.sin(angle))
            pts.append((px, py))
        hd.polygon(pts, outline=(0, 150, 200, alpha))
bg_canvas = Image.alpha_composite(bg_canvas, hex_layer)

bg_result = bg_canvas.resize((BG, BG), Image.LANCZOS)
bg_path = os.path.join(ICONS_DIR, "adaptive_background.png")
bg_result.save(bg_path, "PNG")
print(f"Adaptive background: {bg_path}")

# ---------------------------------------------------------------------------
# 3. Adaptive foreground: beacon/tower on transparent (432x432)
# ---------------------------------------------------------------------------
FG = 432
R = FG * 3
S = R / 1024  # scale factor from original 1024-design coords


def sc(v):
    return int(v * S)


def scp(pts):
    return [(int(x * S), int(y * S)) for x, y in pts]


fg_canvas = Image.new("RGBA", (R, R), (0, 0, 0, 0))

# Signal arcs
acx, acy = sc(512), sc(410)
arcs = [
    (sc(275), sc(6), 75, 22),
    (sc(190), sc(8), 150, 45),
    (sc(108), sc(10), 240, 70),
]

arc_glow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
ag = ImageDraw.Draw(arc_glow)
for radius, width, _, glow_op in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ag.arc(bbox, 195, 345, fill=(0, 180, 240, glow_op), width=width + sc(22))
arc_glow = arc_glow.filter(ImageFilter.GaussianBlur(radius=sc(12)))
fg_canvas = Image.alpha_composite(fg_canvas, arc_glow)

arc_sharp = Image.new("RGBA", (R, R), (0, 0, 0, 0))
ash = ImageDraw.Draw(arc_sharp)
for radius, width, sharp_op, _ in arcs:
    bbox = [acx - radius, acy - radius, acx + radius, acy + radius]
    ash.arc(bbox, 200, 340, fill=(0, 212, 255, sharp_op), width=width)
fg_canvas = Image.alpha_composite(fg_canvas, arc_sharp)

# Arc endpoint dots
arc_dots = Image.new("RGBA", (R, R), (0, 0, 0, 0))
acd = ImageDraw.Draw(arc_dots)
for radius, _, sharp_op, _ in arcs:
    for angle_deg in [200, 340]:
        angle = math.radians(angle_deg)
        dx = acx + int(radius * math.cos(angle))
        dy = acy + int(radius * math.sin(angle))
        dr = sc(4)
        acd.ellipse([dx - dr, dy - dr, dx + dr, dy + dr],
                    fill=(0, 212, 255, sharp_op))
fg_canvas = Image.alpha_composite(fg_canvas, arc_dots)

# Beacon glow
bx, by = sc(512), sc(355)
beacon_glow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
bg_d = ImageDraw.Draw(beacon_glow)
glow_r = sc(80)
for r in range(glow_r, 0, -1):
    t = 1 - r / glow_r
    opacity = int(110 * t * t * t)
    rv, gv, bv = 255, int(200 + 55 * t), int(50 + 205 * t)
    bg_d.ellipse([bx - r, by - r, bx + r, by + r], fill=(rv, gv, bv, opacity))
fg_canvas = Image.alpha_composite(fg_canvas, beacon_glow)

# Antenna
ant = Image.new("RGBA", (R, R), (0, 0, 0, 0))
ad = ImageDraw.Draw(ant)
ad.line([(sc(512), sc(355)), (sc(512), sc(440))], fill=(255, 190, 60, 255), width=sc(8))
ad.line([(sc(484), sc(392)), (sc(540), sc(392))], fill=(255, 190, 60, 210), width=sc(5))
r_dish = sc(11)
ad.ellipse([sc(512) - r_dish, sc(416) - r_dish, sc(512) + r_dish, sc(416) + r_dish],
           outline=(255, 175, 45, 150), width=sc(3))
fg_canvas = Image.alpha_composite(fg_canvas, ant)

# Tower body
tower = Image.new("RGBA", (R, R), (0, 0, 0, 0))
td = ImageDraw.Draw(tower)
segments = [
    (440, 14, 490, 36, (245, 180, 45)),
    (490, 38, 575, 50, (225, 155, 30)),
    (575, 52, 675, 60, (205, 130, 18)),
    (675, 62, 785, 66, (180, 108, 10)),
]
for y_top, hw_top, y_bot, hw_bot, color in segments:
    seg = scp([(512 - hw_top, y_top), (512 + hw_top, y_top),
               (512 + hw_bot, y_bot), (512 - hw_bot, y_bot)])
    td.polygon(seg, fill=(*color, 255))
for y_top, hw_top, _, _, _ in segments[1:]:
    td.line(scp([(512 - hw_top - 4, y_top), (512 + hw_top + 4, y_top)]),
            fill=(255, 225, 130, 180), width=sc(2))
fg_canvas = Image.alpha_composite(fg_canvas, tower)

# Beacon light
light = Image.new("RGBA", (R, R), (0, 0, 0, 0))
ld = ImageDraw.Draw(light)
r1 = sc(16)
ld.ellipse([bx - r1, by - r1, bx + r1, by + r1], fill=(255, 240, 200, 245))
r2 = sc(10)
ld.ellipse([bx - r2, by - r2, bx + r2, by + r2], fill=(255, 255, 255, 255))
fg_canvas = Image.alpha_composite(fg_canvas, light)

# Base platform
base = Image.new("RGBA", (R, R), (0, 0, 0, 0))
bd = ImageDraw.Draw(base)
bd.rounded_rectangle([sc(455), sc(785), sc(569), sc(797)], radius=sc(4), fill=(25, 40, 60, 220))
bd.rounded_rectangle([sc(438), sc(797), sc(586), sc(808)], radius=sc(4), fill=(16, 28, 44, 200))
fg_canvas = Image.alpha_composite(fg_canvas, base)

fg_result = fg_canvas.resize((FG, FG), Image.LANCZOS)
fg_path = os.path.join(ICONS_DIR, "adaptive_foreground.png")
fg_result.save(fg_path, "PNG")
print(f"Adaptive foreground: {fg_path}")

print("Done! Configure in export_presets.cfg:")
print(f'  launcher_icons/main_192x192="res://icons/main_192.png"')
print(f'  launcher_icons/adaptive_foreground_432x432="res://icons/adaptive_foreground.png"')
print(f'  launcher_icons/adaptive_background_432x432="res://icons/adaptive_background.png"')
