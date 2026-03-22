# Mobile Optimization Design

**Date:** 2026-03-22
**Target:** Android + iOS, phones primarily, landscape only

## 1. Viewport & Display

- Base viewport: 1280x720 (down from 1920x1080)
- Stretch mode: `canvas_items`, aspect: `expand`
- Orientation: landscape locked
- All path points and game coordinates scaled from 1920x1080 → 1280x720 (0.667x factor)
- DPI awareness via content_scale_factor

## 2. Touch Input

Replace all mouse-specific input with touch-compatible handling:

- `InputEventScreenTouch` + `InputEventMouseButton` (dual support for editor testing)
- Tap = select/place tower, press buttons
- Tap empty area = deselect (replaces right-click)
- Long press (0.5s) on tower = show tooltip/info (replaces hover)
- Tower click detection radius: 32px → 56px
- Touch feedback: brief scale pulse (1.0 → 1.1 → 1.0 over 0.1s) on interactive elements
- Remove all MOUSE_BUTTON_RIGHT handling, replace with tap-away-to-deselect

## 3. UI Sizing

All touch targets minimum 56x56px:

| Component | Old Size | New Size |
|-----------|----------|----------|
| Top bar height | 48px | 56px |
| Tower bar height | 64px | 72px |
| Tower buttons | unspecified | 64x64px |
| Ability buttons | 80x48px | 64x64px |
| Upgrade panel width | 200px | 260px |
| Send wave button | default | 72x56px |
| Speed button | default | 56x56px |
| Targeting button | default | 56x40px |
| Sell button | default | full-width, 48px tall |
| Menu buttons | default | 280x56px |
| Settings sliders | HSlider default | 40px track height |

Font sizes via theme override:
- Body text: 18px minimum
- Headers/titles: 24px
- HUD labels (gold, lives, wave): 20px
- Button text: 18px

## 4. HUD Layout (Thumb-Zone Optimized)

```
+--[Lives] [Gold] [Wave X/Y] ----[Speed]--+   <- top bar (info, minimal interaction)
|                                          |
|              GAME FIELD                  |
|                                          |
|  [Ability1]                              |
|  [Ability2]                  [Send Wave] |   <- bottom-right, large
|  [Ability3]                              |
+--[Tower1][Tower2][Tower3]...[Tower7]-----+   <- bottom bar (thumb zone)
```

- Tower bar: pinned bottom, horizontal scroll if needed
- Ability bar: bottom-left, vertical stack
- Send wave: bottom-right, large button
- Speed: top-right
- Upgrade panel: slides up from bottom (not from right)
- Top bar: info display only (lives, gold, wave count)

## 5. Rendering Performance

### Tower Renderer
- Range indicator polygon: 48 segments → 16 segments
- Cache polygon points in `_cached_points: PackedVector2Array`
- Only regenerate on tier change, not every frame
- Skip range indicator draw when not selected/hovered

### Enemy Renderer
- Flying enemies: `queue_redraw()` every 3rd frame via frame counter
- Cache health bar rects (only recalculate on health change)

### Projectile Pooling
- Pool of 50 pre-allocated projectiles
- `acquire()` / `release()` instead of `new()` / `queue_free()`
- Reset state on acquire

### General
- Reduce max simultaneous enemies visible (cull off-screen)
- Batch draw calls where possible via CanvasItem groups

## 6. Project Configuration

### project.godot changes
```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1  # landscape

[input_devices]
pointing/emulate_touch_from_mouse=true
pointing/emulate_mouse_from_touch=true
```

### Game coordinate scaling
All hardcoded coordinates in game.gd, level_data.gd path points, and build spots must be scaled by 0.667x (1280/1920) or made viewport-relative.

## 7. Files to Modify

| File | Changes |
|------|---------|
| project.godot | viewport, orientation, touch emulation |
| scenes/game.gd | touch input, coordinate scaling, deselect logic |
| ui/hud/hud.gd | layout restructure, sizes |
| ui/hud/top_bar.gd | height, font sizes |
| ui/hud/tower_bar.gd | height, button sizes, horizontal scroll |
| ui/hud/ability_bar.gd | reposition bottom-left, vertical, button sizes |
| ui/hud/tower_upgrade_panel.gd | slide from bottom, wider |
| ui/hud/tooltip.gd | long-press trigger, larger text |
| ui/tower_ui/tower_button.gd | 64x64 minimum, touch feedback |
| ui/menus/main_menu.gd | button sizes, font |
| ui/menus/pause_menu.gd | button sizes, font |
| ui/menus/settings_menu.gd | slider height, button sizes |
| ui/menus/level_complete.gd | button sizes |
| ui/menus/level_failed.gd | button sizes |
| ui/meta/campaign_map.gd | touch targets, font |
| ui/meta/diamond_shop.gd | button sizes |
| ui/meta/tower_lab.gd | touch targets |
| ui/story/dialogue_overlay.gd | text size, tap to advance |
| core/tower_system/tower_renderer.gd | polygon caching, segment reduction |
| core/enemy_system/enemy_renderer.gd | frame-skip redraw |
| core/tower_system/projectile.gd | object pooling |
| content/levels/level_data.gd | scale path coordinates |
| shared/constants.gd | mobile touch constants |
