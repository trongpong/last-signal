# Map Variety & Zoom System Design

**Date:** 2026-03-22
**Status:** Approved

## Overview

Expand the map system from 3 identical left-to-right zigzag paths to 4 distinct path types, region-based map scaling with camera zoom/pan, 13 hand-crafted milestone levels, and procedural path generation for the rest.

## Goals

- Every level feels visually distinct, not repetitive
- Map complexity scales with campaign progression
- 4 path types create different strategic challenges
- Zoom/pan introduced gradually (region 2+), not on tutorial levels

## Path Types

### 1. Zigzag (existing)
Single path, left-to-right with varying vertical turns. One `Path2D` node.

### 2. Spiral / Loop
Single path that loops back on itself, creating choke points where towers can hit enemies multiple times. One `Path2D` with waypoints that decrease in X before resuming forward.

### 3. Branching / Split
Path splits into 2 routes then merges back. Forces the player to cover both lanes. Two `Path2D` nodes sharing the same start and end points. Enemies are assigned to a branch via `path_index` on their sub-wave.

### 4. Multi-Entry
Enemies spawn from different edges (left, top, bottom), all converging on a single exit. Multiple `Path2D` nodes with different start points. Each sub-wave specifies which entry path it uses via `path_index`.

## Map Scale

Map scale determines world size. Camera zoom is enabled for scales > 1.0.

For levels with `map_mode = GRID_MAZE` (regions 2 and 5), the grid scales proportionally: `_grid_size = Vector2i(int(20 * map_scale), int(12 * map_scale))` while `_cell_size` stays at `Vector2(64.0, 64.0)`. This keeps cell size consistent while expanding the grid to cover the larger world.

| Region | Map Scale | World Size | Map Mode | Zoom |
|--------|-----------|------------|----------|------|
| 1 | 1.0 | 1280x720 | FIXED_PATH | Static (no zoom) |
| 2 | 1.5 | 1920x1080 | GRID_MAZE | Enabled |
| 3 | 2.0 | 2560x1440 | FIXED_PATH | Enabled |
| 4 | 2.5 | 3200x1800 | FIXED_PATH | Enabled |
| 5 | 3.0 | 3840x2160 | GRID_MAZE | Enabled |

Formula: `map_scale = 1.0 + (region - 1) * 0.5`

## Camera System

### When `map_scale = 1.0`
No camera changes. Behavior identical to current game. No zoom controls shown.

### When `map_scale > 1.0`
A `Camera2D` node is added to the game scene via `GameCamera` wrapper.

- **Initial zoom**: fits the full map in the viewport — `Vector2(1.0 / map_scale, 1.0 / map_scale)`
- **Zoom range**: from fit-all (`1.0 / map_scale`) to 1:1 pixel view (`Vector2(1.0, 1.0)`)
- **Zoom input**: scroll wheel (desktop), `InputEventMagnifyGesture` (mobile)
- **Pan input**: click-drag (desktop), touch-drag (mobile) when zoomed in
- **Clamping**: camera cannot pan past world bounds
- **HUD**: unaffected — `CanvasLayer` stays anchored to screen
- **Grid overlay & field border**: drawn in world-space, scale with world bounds

### Input Handling & Coordinate Spaces

Two coordinate spaces are in play:
1. **Viewport space**: raw `InputEvent.position` — used for HUD exclusion checks (top 56px, bottom 72px)
2. **World space**: viewport position transformed through camera — used for tower placement, tower selection, damage popups

**Conversion order in `_input()` / `_handle_tap()`:**
1. Check HUD exclusion zones in viewport space (unchanged)
2. Convert to world space: `var world_pos: Vector2 = get_canvas_transform().affine_inverse() * viewport_pos`
3. Pass `world_pos` to `_find_tower_at()`, `_try_place_tower()`, `_is_position_occupied()`, `_show_damage_popup()`

When `map_scale = 1.0` and no camera exists, the canvas transform is identity, so the conversion is a no-op.

Per CLAUDE.md: use `get_viewport().get_mouse_position()` for raw viewport position, never `get_global_mouse_position()`.

## Level Data Model

Path data stored in `level_data.gd` for hand-crafted levels:

```gdscript
{
    "type": "zigzag",          # "zigzag", "spiral", "branching", "multi_entry"
    "paths": [
        [Vector2(...), ...],   # Primary path (always present)
        [Vector2(...), ...],   # Secondary path (branching/multi-entry only)
    ],
    "merge_point": Vector2,    # Where branches rejoin (branching type only)
    "exit": Vector2,           # Exit point
}
```

### SubWaveDefinition Change

Add `path_index: int = 0` as a field on `SubWaveDefinition`. Add `p_path_index: int = 0` as an optional fifth parameter to `_init()`, setting `path_index = p_path_index`. Existing 4-argument call sites are unaffected due to the default value.

### WaveManager Signal Chain

The `enemy_spawn_requested` signal must change to propagate `path_index`:

1. Signal: `signal enemy_spawn_requested(enemy_id: String, path_index: int)`
2. `_build_spawn_queue()`: each spawn entry stores `path_index` from its `SubWaveDefinition`
3. Emit: `enemy_spawn_requested.emit(entry["enemy_id"], entry["path_index"])`
4. `game.gd._on_enemy_spawn_requested(enemy_id: String, path_index: int)`: uses `path_index` to pick from `_enemy_paths` array

### Enemy Spawning

Game scene maintains `_enemy_paths: Array[Path2D]`. When spawning:
```gdscript
var path: Path2D = _enemy_paths[clampi(path_index, 0, _enemy_paths.size() - 1)]
```

### Multi-Path Visual Feedback

`_setup_enemy_path()` becomes `_setup_enemy_paths()` and loops over all paths in the level data. Each path gets its own glow line, path line, and directional markers drawn in the same style as today. Secondary paths use slightly different colors for visual distinction.

## Map Mode & Path Type Interaction

For levels with `map_mode = GRID_MAZE` (regions 2 and 5), the `path_type` field is ignored. The grid A* system determines paths at runtime based on tower placement. `PathGenerator` is not used for grid maze levels.

For levels with `map_mode = FIXED_PATH`, `path_type` determines which path style is used (hand-crafted or procedurally generated).

## LevelRegistry Changes

Two new fields per level definition:
- `map_scale: float` — derived from region: `1.0 + (region - 1) * 0.5`
- `path_type: String` — explicit for hand-crafted, rule-based for procedural. Ignored when `map_mode = GRID_MAZE`.

## Hand-Crafted Milestone Levels

13 total (3 existing + 10 new):

| Level | Name | Path Type | Role | Map Scale |
|-------|------|-----------|------|-----------|
| 1_1 | First Contact | Zigzag | Tutorial (exists) | 1.0 |
| 1_2 | Outer Gate | Zigzag | Intro drone_fast (exists) | 1.0 |
| 1_3 | Relay Defense | Zigzag | Intro armored (exists) | 1.0 |
| 1_5 | Crossroads | Branching | First split path | 1.0 |
| 1_10 | Perimeter Boss | Spiral | Region 1 boss | 1.0 |
| 2_1 | Corridor Entry | Grid maze | Region 2 intro | 1.5 |
| 2_10 | Uplink Boss | Grid maze | Region 2 boss | 1.5 |
| 3_1 | Field Approach | Spiral | Region 3 intro | 2.0 |
| 3_9 | Resonance Boss | Multi-entry | Region 3 boss | 2.0 |
| 4_1 | Core Breach | Branching | Region 4 intro | 2.5 |
| 4_9 | Core Boss | Multi-entry (hand-crafted) | Region 4 boss | 2.5 |
| 5_1 | Heart Entry | Grid maze | Region 5 intro | 3.0 |
| 5_8 | Final Signal | Multi-entry (hand-crafted) | Final boss | 3.0 |

**Hybrid path types** (4_9, 5_8): These are hand-crafted levels where path data is manually authored with multiple paths that combine characteristics (e.g., one entry spirals while another branches). The `path_type` field is informational only for these levels — the actual path geometry is defined explicitly in `level_data.gd`, not generated by `PathGenerator`.

All other levels use WaveGenerator with procedurally generated paths (FIXED_PATH) or grid A* (GRID_MAZE).

## Procedural Path Generation

New `PathGenerator` class. Deterministic: same `level_id` always produces the same path via `seed(level_id.hash())`.

### Input
- `map_scale: float`
- `path_type: String`
- `level_number: int`
- `seed: int` (from level_id hash)

### Generation Rules

**Zigzag**: 5-8 waypoints. X advances evenly across `1280 * map_scale`. Y randomized within playable area. More waypoints at higher regions.

**Spiral**: 8-12 waypoints. Includes a loop-back section where X decreases for 2-3 points before resuming forward. Creates choke points.

**Branching**: Generates a zigzag path, picks a midpoint to split. Offsets secondary path ±150-200px vertically (scaled by map_scale). Both converge at ~75% through.

**Multi-entry**: Generates 2-3 independent paths from different edges (left, top, bottom). All converge on exit (right edge). Crossing avoidance: each entry path is assigned a vertical band (e.g., top third, middle third, bottom third). Paths stay within their band until the convergence zone at ~80% X, where they merge toward the exit. If paths still intersect (checked by segment intersection test), regenerate with `seed + 1`.

### Playable Area Bounds
- Vertical: `57px` to `(720 * map_scale) - 72px`
- Horizontal: `-33px` to `(1280 * map_scale) + 33px`

## Procedural Path Type Selection

For non-hand-crafted FIXED_PATH levels, path type is selected by region:

| Region | Available Path Types |
|--------|---------------------|
| 1 | Zigzag only |
| 3 | Zigzag, Spiral, Branching |
| 4 | All 4 types |

Regions 2 and 5 use GRID_MAZE and don't need procedural path type selection.

Selection is deterministic based on `level_id.hash() % available_types.size()`.

## game.gd `start_level` Flow

1. Look up `map_scale`, `path_type`, and `map_mode` from LevelRegistry
2. Set world bounds: `Vector2(1280 * map_scale, 720 * map_scale)`
3. Create `GameCamera` if `map_scale > 1.0` — set zoom limits, enable pan/pinch
4. Load paths: hand-crafted from `level_data.gd`, or generate via `PathGenerator` (FIXED_PATH only)
5. Create `Path2D` node(s) — one per path in the level. Draw glow, path line, and markers for each.
6. Scale grid overlay, field border, and background to world bounds
7. For GRID_MAZE: scale `GridManager._grid_size` proportionally with `map_scale`
8. Convert input coordinates from viewport to world space after HUD exclusion checks

## Files Changed

### New Files
- `core/map/path_generator.gd` — procedural path generation
- `core/map/game_camera.gd` — Camera2D wrapper with zoom/pan/clamp logic

### Modified Files
- `content/levels/level_data.gd` — new path data format, 10 new hand-crafted levels
- `core/campaign/level_registry.gd` — `map_scale` and `path_type` fields
- `core/wave_system/sub_wave_definition.gd` — `path_index` field (optional 5th param in `_init`)
- `core/wave_system/wave_manager.gd` — `enemy_spawn_requested` signal adds `path_index`, spawn queue propagates it
- `core/pathfinding/grid_manager.gd` — scale `_grid_size` by `map_scale`
- `scenes/game.gd` — camera setup, multi-path spawning, world-space input handling, multi-path visual drawing
- `scenes/game.tscn` — camera node (optional, can be created in code)

## Out of Scope

- Map editor tool
- Decorative map elements (rocks, buildings)
- Minimap widget (can be added later if needed)
