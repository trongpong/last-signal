# Map Variety & Zoom System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 path types (zigzag, spiral, branching, multi-entry), region-based map scaling with camera zoom/pan, 13 hand-crafted milestone levels, and procedural path generation.

**Architecture:** Extend existing Path2D/PathFollow2D system to support multiple paths per level. Add GameCamera (Camera2D wrapper) for zoom/pan on scaled maps. PathGenerator creates deterministic procedural paths. LevelRegistry drives map_scale and path_type per level.

**Tech Stack:** Godot 4.6, GDScript, Path2D, Camera2D

**Spec:** `docs/superpowers/specs/2026-03-22-map-variety-zoom-design.md`

---

### Task 1: SubWaveDefinition — Add `path_index` field

**Files:**
- Modify: `core/wave_system/sub_wave_definition.gd`
- Test: `tests/test_wave_manager.gd`

- [ ] **Step 1: Write failing test for path_index default**

In `tests/test_wave_manager.gd`, add:

```gdscript
func test_sub_wave_path_index_default() -> void:
	var sw := SubWaveDefinition.new("scout_basic", 5, 0.5, 0.0)
	assert_eq(sw.path_index, 0, "Default path_index should be 0")

func test_sub_wave_path_index_explicit() -> void:
	var sw := SubWaveDefinition.new("scout_basic", 5, 0.5, 0.0, 2)
	assert_eq(sw.path_index, 2, "Explicit path_index should be 2")
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `path_index` not defined on SubWaveDefinition

- [ ] **Step 3: Add path_index to SubWaveDefinition**

In `core/wave_system/sub_wave_definition.gd`, add field and update `_init`:

```gdscript
var path_index: int = 0

func _init(
	p_enemy_id: String = "",
	p_count: int = 1,
	p_spawn_interval: float = Constants.DEFAULT_SPAWN_INTERVAL,
	p_delay: float = 0.0,
	p_path_index: int = 0
) -> void:
	enemy_id = p_enemy_id
	count = p_count
	spawn_interval = p_spawn_interval
	delay = p_delay
	path_index = p_path_index
```

- [ ] **Step 4: Run tests to verify pass**

- [ ] **Step 5: Commit**

```
feat: add path_index to SubWaveDefinition for multi-path support
```

---

### Task 2: WaveManager — Propagate `path_index` through signal chain

**Files:**
- Modify: `core/wave_system/wave_manager.gd`
- Test: `tests/test_wave_manager.gd`

- [ ] **Step 1: Update WaveManager signal and spawn queue first (test written after)**

**Note:** The signal signature change must happen before writing the test, because Godot 4 crashes (not just fails) when connecting a lambda with mismatched parameter count to a signal.

- [ ] **Step 2: Update WaveManager signal and spawn queue**

In `core/wave_system/wave_manager.gd`:

1. Change signal (line ~21):
```gdscript
signal enemy_spawn_requested(enemy_id: String, path_index: int)
```

2. In `_build_spawn_queue()`, add `path_index` to each entry:
```gdscript
queue_entry["path_index"] = sw.path_index
```

3. In `_process()` where spawn emits (line ~181), change:
```gdscript
enemy_spawn_requested.emit(entry["enemy_id"], entry["path_index"])
```

- [ ] **Step 3: Update game.gd signal connection**

In `scenes/game.gd`, update `_on_enemy_spawn_requested` signature:
```gdscript
func _on_enemy_spawn_requested(enemy_id: String, path_index: int = 0) -> void:
```
(path_index unused for now — wired in Task 7)

- [ ] **Step 4: Write verification test**

```gdscript
func test_spawn_signal_includes_path_index() -> void:
	var wm := WaveManager.new()
	add_child(wm)
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	var sw := SubWaveDefinition.new("scout_basic", 1, 0.1, 0.0, 1)
	wd.sub_waves = [sw]
	wm.load_waves([wd])

	var received_path_index: int = -1
	wm.enemy_spawn_requested.connect(func(eid: String, pi: int) -> void:
		received_path_index = pi
	)
	wm.start_next_wave()
	for i in range(20):
		wm._process(0.1)
	assert_eq(received_path_index, 1, "Signal should include path_index from sub-wave")
	wm.queue_free()
```

- [ ] **Step 5: Run all tests to verify pass and no regressions**

Verify existing `test_spawn_uses_correct_enemy_id` still passes (args[0] unchanged).

- [ ] **Step 6: Commit**

```
feat: propagate path_index through WaveManager signal chain
```

---

### Task 3: LevelRegistry — Add `map_scale` and `path_type` fields

**Files:**
- Modify: `core/campaign/level_registry.gd`
- Test: `tests/test_constants.gd` (or new `tests/test_level_registry.gd`)

- [ ] **Step 1: Write failing test**

```gdscript
func test_level_registry_map_scale() -> void:
	var reg := LevelRegistry.new()
	reg.register_levels()
	var level_1_1: Dictionary = reg.get_level("1_1")
	assert_eq(level_1_1["map_scale"], 1.0, "Region 1 map_scale should be 1.0")
	var level_3_1: Dictionary = reg.get_level("3_1")
	assert_eq(level_3_1["map_scale"], 2.0, "Region 3 map_scale should be 2.0")
	var level_5_1: Dictionary = reg.get_level("5_1")
	assert_eq(level_5_1["map_scale"], 3.0, "Region 5 map_scale should be 3.0")

func test_level_registry_path_type() -> void:
	var reg := LevelRegistry.new()
	reg.register_levels()
	var level: Dictionary = reg.get_level("1_1")
	assert_true(level.has("path_type"), "Level should have path_type field")
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Add fields to register_levels()**

In `core/campaign/level_registry.gd`, inside the level_dict construction (line ~58-68), add:

```gdscript
"map_scale": 1.0 + float(region - 1) * 0.5,
"path_type": _get_path_type(level_id, region, map_mode),
```

Add helper method:
```gdscript
func _get_path_type(level_id: String, region: int, map_mode: int) -> String:
	# Hand-crafted milestone levels
	var milestones: Dictionary = {
		"1_5": "branching", "1_10": "spiral",
		"3_1": "spiral", "3_9": "multi_entry",
		"4_1": "branching", "4_9": "multi_entry",
		"5_8": "multi_entry",
	}
	if milestones.has(level_id):
		return milestones[level_id]
	# Grid maze levels ignore path_type
	if map_mode == Enums.MapMode.GRID_MAZE:
		return "grid_maze"
	# Procedural selection by region
	var types_by_region: Dictionary = {
		1: ["zigzag"],
		3: ["zigzag", "spiral", "branching"],
		4: ["zigzag", "spiral", "branching", "multi_entry"],
	}
	var available: Array = types_by_region.get(region, ["zigzag"])
	return available[level_id.hash() % available.size()]
```

- [ ] **Step 4: Run tests to verify pass**

- [ ] **Step 5: Commit**

```
feat: add map_scale and path_type to LevelRegistry
```

---

### Task 4: GameCamera — Camera2D wrapper with zoom/pan/clamp

**Files:**
- Create: `core/map/game_camera.gd`
- Test: `tests/test_game_camera.gd`

- [ ] **Step 1: Write failing test**

```gdscript
func test_game_camera_zoom_limits() -> void:
	var cam := GameCamera.new()
	add_child(cam)
	cam.setup(2.0, Vector2(2560, 1440))
	# Initial zoom should fit full map
	assert_almost_eq(cam.zoom.x, 0.5, 0.01, "Initial zoom should be 1/map_scale")
	# Zoom in should not exceed 1.0
	cam.zoom_by(10.0)
	assert_almost_eq(cam.zoom.x, 1.0, 0.01, "Max zoom should be 1.0")
	# Zoom out should not go below fit-all
	cam.zoom_by(-10.0)
	assert_almost_eq(cam.zoom.x, 0.5, 0.01, "Min zoom should be 1/map_scale")
	cam.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement GameCamera**

Create `core/map/game_camera.gd`:

```gdscript
class_name GameCamera
extends Camera2D

var _map_scale: float = 1.0
var _world_size: Vector2 = Vector2(1280, 720)
var _min_zoom: float = 1.0
var _max_zoom: float = 1.0
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO

func setup(map_scale: float, world_size: Vector2) -> void:
	_map_scale = map_scale
	_world_size = world_size
	_min_zoom = 1.0 / map_scale
	_max_zoom = 1.0
	zoom = Vector2(_min_zoom, _min_zoom)
	position = world_size * 0.5
	_clamp_position()

func zoom_by(amount: float) -> void:
	var new_zoom: float = clampf(zoom.x + amount * 0.1, _min_zoom, _max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_position()

func pan_by(delta: Vector2) -> void:
	position -= delta / zoom.x
	_clamp_position()

func _clamp_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = vp_size / (2.0 * zoom.x)
	position.x = clampf(position.x, half_view.x, _world_size.x - half_view.x)
	position.y = clampf(position.y, half_view.y, _world_size.y - half_view.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(-1.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			if mb.pressed:
				_pan_start = mb.position
	elif event is InputEventMouseMotion and _is_panning:
		var motion := event as InputEventMouseMotion
		pan_by(motion.relative)
	elif event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		zoom_by((mag.factor - 1.0) * 5.0)
```

- [ ] **Step 4: Run tests to verify pass**

- [ ] **Step 5: Commit**

```
feat: add GameCamera with zoom/pan/clamp support
```

---

### Task 5: PathGenerator — Procedural path generation

**Files:**
- Create: `core/map/path_generator.gd`
- Test: `tests/test_path_generator.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
func test_zigzag_generates_valid_path() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("zigzag", 1.0, 1, "1_4".hash())
	assert_true(result.has("paths"), "Result should have paths")
	assert_eq(result["paths"].size(), 1, "Zigzag should have 1 path")
	var path: Array = result["paths"][0]
	assert_true(path.size() >= 5, "Should have at least 5 waypoints")
	# First point should be off-screen left
	assert_true(path[0].x <= 0, "Start should be off-screen left")
	# Last point should be off-screen right
	assert_true(path[path.size() - 1].x >= 1280, "End should be off-screen right")

func test_branching_generates_two_paths() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("branching", 1.0, 5, "1_5".hash())
	assert_eq(result["paths"].size(), 2, "Branching should have 2 paths")

func test_multi_entry_generates_multiple_paths() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("multi_entry", 2.0, 1, "3_5".hash())
	assert_true(result["paths"].size() >= 2, "Multi-entry should have 2+ paths")

func test_deterministic_generation() -> void:
	var gen := PathGenerator.new()
	var r1: Dictionary = gen.generate("zigzag", 1.0, 1, 42)
	var r2: Dictionary = gen.generate("zigzag", 1.0, 1, 42)
	assert_eq(r1["paths"][0], r2["paths"][0], "Same seed should produce same path")

func test_spiral_has_loop_back() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("spiral", 1.0, 1, "1_10".hash())
	var path: Array = result["paths"][0]
	# At least one point where X decreases
	var has_loop: bool = false
	for i in range(1, path.size()):
		if path[i].x < path[i - 1].x:
			has_loop = true
			break
	assert_true(has_loop, "Spiral should have at least one X decrease (loop-back)")
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement PathGenerator**

Create `core/map/path_generator.gd`:

```gdscript
class_name PathGenerator
extends RefCounted

## Generates deterministic procedural path data for non-hand-crafted levels.
## Returns a Dictionary matching the level data format:
## { "type": String, "paths": Array[Array[Vector2]], "exit": Vector2 }

var _last_seed: int = 0

func generate(path_type: String, map_scale: float, level_number: int, path_seed: int) -> Dictionary:
	_last_seed = path_seed
	seed(path_seed)
	match path_type:
		"zigzag":
			return _gen_zigzag(map_scale, level_number)
		"spiral":
			return _gen_spiral(map_scale, level_number)
		"branching":
			return _gen_branching(map_scale, level_number)
		"multi_entry":
			return _gen_multi_entry(map_scale, level_number)
	return _gen_zigzag(map_scale, level_number)

func _playable_y_min(map_scale: float) -> float:
	return 57.0

func _playable_y_max(map_scale: float) -> float:
	return 720.0 * map_scale - 72.0

func _world_width(map_scale: float) -> float:
	return 1280.0 * map_scale

func _gen_zigzag(map_scale: float, level_number: int) -> Dictionary:
	var points: Array = []
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var count: int = clampi(5 + level_number / 3, 5, 8)
	points.append(Vector2(-33, randf_range(y_min + 50, y_max - 50)))
	for i in range(1, count - 1):
		var x: float = w * float(i) / float(count - 1)
		var y: float = randf_range(y_min + 30, y_max - 30)
		points.append(Vector2(x, y))
	points.append(Vector2(w + 33, randf_range(y_min + 50, y_max - 50)))
	return {"type": "zigzag", "paths": [points], "exit": points[points.size() - 1]}

func _gen_spiral(map_scale: float, level_number: int) -> Dictionary:
	var points: Array = []
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var y_mid: float = (y_min + y_max) * 0.5
	# Forward section
	points.append(Vector2(-33, y_mid + randf_range(-80, 80)))
	var loop_start_x: float = w * randf_range(0.25, 0.4)
	points.append(Vector2(loop_start_x, randf_range(y_min + 40, y_mid)))
	# Forward to loop peak
	var loop_peak_x: float = w * randf_range(0.45, 0.6)
	points.append(Vector2(loop_peak_x, randf_range(y_mid, y_max - 40)))
	# Loop back (X decreases)
	var loop_back_x: float = loop_start_x - w * randf_range(0.05, 0.15)
	points.append(Vector2(loop_back_x, randf_range(y_max - 100, y_max - 40)))
	# Second loop back
	points.append(Vector2(loop_back_x - w * 0.05, randf_range(y_mid, y_mid + 60)))
	# Resume forward
	var resume_x: float = w * randf_range(0.5, 0.65)
	points.append(Vector2(resume_x, randf_range(y_min + 40, y_mid)))
	# Continue to end
	for i in range(2):
		var x: float = resume_x + w * float(i + 1) * 0.15
		points.append(Vector2(x, randf_range(y_min + 40, y_max - 40)))
	points.append(Vector2(w + 33, y_mid + randf_range(-60, 60)))
	return {"type": "spiral", "paths": [points], "exit": points[points.size() - 1]}

func _gen_branching(map_scale: float, level_number: int) -> Dictionary:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var y_mid: float = (y_min + y_max) * 0.5
	# Shared start
	var start := Vector2(-33, y_mid + randf_range(-60, 60))
	var split_x: float = w * randf_range(0.2, 0.35)
	var split_pt := Vector2(split_x, y_mid + randf_range(-30, 30))
	# Shared end
	var merge_x: float = w * randf_range(0.7, 0.85)
	var merge_pt := Vector2(merge_x, y_mid + randf_range(-30, 30))
	var end_pt := Vector2(w + 33, y_mid + randf_range(-60, 60))
	# Upper path
	var upper_mid := Vector2(w * 0.5, randf_range(y_min + 40, y_mid - 40))
	var path_a: Array = [start, split_pt, upper_mid, merge_pt, end_pt]
	# Lower path
	var lower_mid := Vector2(w * 0.5, randf_range(y_mid + 40, y_max - 40))
	var path_b: Array = [start, split_pt, lower_mid, merge_pt, end_pt]
	return {"type": "branching", "paths": [path_a, path_b], "merge_point": merge_pt, "exit": end_pt}

func _gen_multi_entry(map_scale: float, level_number: int) -> Dictionary:
	var path_seed: int = _last_seed  # Stored from generate() call
	var w: float = _world_width(map_scale)
	var h: float = 720.0 * map_scale
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var exit_pt := Vector2(w + 33, (y_min + y_max) * 0.5)
	var converge_x: float = w * 0.8
	var paths: Array = []
	# Path from left (top band)
	var band_h: float = (y_max - y_min) / 3.0
	var p1: Array = [
		Vector2(-33, y_min + band_h * 0.5),
		Vector2(w * 0.3, y_min + randf_range(30, band_h - 30)),
		Vector2(w * 0.6, y_min + randf_range(30, band_h)),
		Vector2(converge_x, exit_pt.y),
		exit_pt,
	]
	paths.append(p1)
	# Path from left-bottom (bottom band)
	var p2: Array = [
		Vector2(-33, y_max - band_h * 0.5),
		Vector2(w * 0.25, y_max - randf_range(30, band_h - 30)),
		Vector2(w * 0.55, y_max - randf_range(30, band_h)),
		Vector2(converge_x, exit_pt.y),
		exit_pt,
	]
	paths.append(p2)
	# Optional 3rd path from top edge (middle band)
	if level_number > 3 or map_scale >= 2.0:
		var p3: Array = [
			Vector2(w * 0.3, -33),
			Vector2(w * 0.35, y_min + band_h),
			Vector2(w * 0.5, y_min + band_h + randf_range(20, band_h - 20)),
			Vector2(converge_x, exit_pt.y),
			exit_pt,
		]
		paths.append(p3)
	# Crossing avoidance: check segment intersections, retry with different seed if crossed
	if paths.size() >= 2 and _paths_intersect(paths):
		seed(path_seed + 1)
		return _gen_multi_entry(map_scale, level_number)
	return {"type": "multi_entry", "paths": paths, "exit": exit_pt}

func _paths_intersect(paths: Array) -> bool:
	for i in range(paths.size()):
		for j in range(i + 1, paths.size()):
			if _two_paths_cross(paths[i], paths[j]):
				return true
	return false

func _two_paths_cross(path_a: Array, path_b: Array) -> bool:
	for ai in range(path_a.size() - 1):
		for bi in range(path_b.size() - 1):
			if _segments_intersect(path_a[ai], path_a[ai + 1], path_b[bi], path_b[bi + 1]):
				return true
	return false

func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var cross: float = d1.x * d2.y - d1.y * d2.x
	if absf(cross) < 0.001:
		return false
	var d3: Vector2 = p3 - p1
	var t: float = (d3.x * d2.y - d3.y * d2.x) / cross
	var u: float = (d3.x * d1.y - d3.y * d1.x) / cross
	return t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0
```

- [ ] **Step 4: Run tests to verify pass**

- [ ] **Step 5: Commit**

```
feat: add PathGenerator for procedural path generation
```

---

### Task 6: Level Data — Hand-crafted milestone levels

**Files:**
- Modify: `content/levels/level_data.gd`

- [ ] **Step 1: Refactor path data to new format**

Change `get_path_points()` to `get_level_paths()` returning the new dictionary format. Keep `get_path_points()` as a backward-compat wrapper that returns the first path from the new format.

Add new static function:
```gdscript
static func get_level_paths(level_id: String) -> Dictionary:
	var id: String = level_id
	if id.begins_with("level_"):
		id = id.substr(6)
	if _LEVEL_PATHS.has(id):
		return _LEVEL_PATHS[id].duplicate(true)
	return {}
```

- [ ] **Step 2: Add path data for existing levels (1_1, 1_2, 1_3)**

Convert existing `_PATH_POINTS` entries to new format in a `_LEVEL_PATHS` dictionary:
```gdscript
const _LEVEL_PATHS: Dictionary = {
	"1_1": {
		"type": "zigzag",
		"paths": [[Vector2(-33, 360), Vector2(200, 200), Vector2(467, 400),
			Vector2(734, 133), Vector2(1000, 334), Vector2(1314, 360)]],
		"exit": Vector2(1314, 360),
	},
	# ... 1_2, 1_3 similarly
}
```

- [ ] **Step 3: Add path data for 1_5 (Crossroads — branching)**

```gdscript
"1_5": {
	"type": "branching",
	"paths": [
		[Vector2(-33, 360), Vector2(250, 360), Vector2(450, 180),
			Vector2(750, 180), Vector2(950, 360), Vector2(1314, 360)],
		[Vector2(-33, 360), Vector2(250, 360), Vector2(450, 540),
			Vector2(750, 540), Vector2(950, 360), Vector2(1314, 360)],
	],
	"merge_point": Vector2(950, 360),
	"exit": Vector2(1314, 360),
},
```

- [ ] **Step 4: Add path data for 1_10 (Perimeter Boss — spiral)**

```gdscript
"1_10": {
	"type": "spiral",
	"paths": [[Vector2(-33, 360), Vector2(200, 180), Vector2(500, 500),
		Vector2(400, 550), Vector2(350, 300), Vector2(600, 150),
		Vector2(850, 400), Vector2(1100, 250), Vector2(1314, 360)]],
	"exit": Vector2(1314, 360),
},
```

- [ ] **Step 5: Update `_sub()` helper to support path_index**

Add optional `p_path_index` parameter to the `_sub()` helper:
```gdscript
static func _sub(enemy_id: String, count: int, interval: float, delay: float, p_path_index: int = 0) -> SubWaveDefinition:
	return SubWaveDefinition.new(enemy_id, count, interval, delay, p_path_index)
```

- [ ] **Step 6: Add wave data for 1_5 and 1_10**

Add `_level_1_5()` and `_level_1_10()` functions with hand-crafted waves. Add them to the `get_waves()` match statement. For 1_5 (branching), sub-waves alternate `path_index` 0 and 1:
```gdscript
# Example: alternating sub-waves on path 0 and path 1
_sub("scout_basic", 5, 0.8, 0.0, 0),  # path 0 (upper)
_sub("drone_basic", 5, 0.8, 0.5, 1),  # path 1 (lower)
```

- [ ] **Step 7: Add remaining milestone levels (3_1, 3_9, 4_1, 4_9, 5_8)**

Add path data and wave data for each. Use the path type from the spec table. Scale coordinates by `map_scale`. For 4_9 and 5_8 (hybrid hand-crafted), manually author multiple paths combining styles.

Levels 2_1, 2_10, 5_1 are GRID_MAZE — they only need wave data (no path points). Add `_level_2_1()`, `_level_2_10()`, `_level_5_1()` wave functions.

- [ ] **Step 8: Update get_waves() match statement with all new levels**

```gdscript
match id:
	"1_1": return _level_1_1()
	"1_2": return _level_1_2()
	"1_3": return _level_1_3()
	"1_5": return _level_1_5()
	"1_10": return _level_1_10()
	"2_1": return _level_2_1()
	"2_10": return _level_2_10()
	"3_1": return _level_3_1()
	"3_9": return _level_3_9()
	"4_1": return _level_4_1()
	"4_9": return _level_4_9()
	"5_1": return _level_5_1()
	"5_8": return _level_5_8()
```

- [ ] **Step 9: Commit**

```
feat: add hand-crafted path and wave data for 10 milestone levels
```

---

### Task 7: game.gd — Multi-path setup and spawning

**Files:**
- Modify: `scenes/game.gd`

- [ ] **Step 1: Replace `_enemy_path: Path2D` with `_enemy_paths: Array[Path2D]`**

Change the variable declaration. Update `_setup_enemy_path()` to `_setup_enemy_paths()`.

- [ ] **Step 2: Implement `_setup_enemy_paths()`**

Load path data from `LevelData.get_level_paths()`. If empty, try `PathGenerator`. If still empty (grid maze), skip. For each path array, create a `Path2D` with `Curve2D`, draw glow line, path line, and markers. Use slightly different colors for secondary paths (e.g., orange glow for path 2, green for path 3).

```gdscript
var _enemy_paths: Array[Path2D] = []

func _setup_enemy_paths() -> void:
	var level_paths: Dictionary = LevelData.get_level_paths(_level_id)
	if level_paths.is_empty():
		# Try procedural generation
		var registry := LevelRegistry.new()
		registry.register_levels()
		var level_def: Dictionary = registry.get_level(_level_id.replace("level_", ""))
		if level_def.get("map_mode", 0) == Enums.MapMode.GRID_MAZE:
			return  # Grid maze handles paths dynamically
		var gen := PathGenerator.new()
		var path_type: String = level_def.get("path_type", "zigzag")
		var ms: float = level_def.get("map_scale", 1.0)
		level_paths = gen.generate(path_type, ms, level_def.get("level_number", 1), _level_id.hash())

	if level_paths.is_empty():
		return

	var path_colors: Array = [
		Color(0.2, 0.5, 0.9, 0.6),
		Color(0.9, 0.5, 0.2, 0.6),
		Color(0.2, 0.9, 0.3, 0.6),
	]
	for i in range(level_paths["paths"].size()):
		var points: Array = level_paths["paths"][i]
		var path2d := Path2D.new()
		var curve := Curve2D.new()
		for pt in points:
			curve.add_point(pt)
		path2d.curve = curve
		map.add_child(path2d)
		_enemy_paths.append(path2d)
		_draw_path_visual(points, path_colors[mini(i, path_colors.size() - 1)])
```

- [ ] **Step 3: Update `_on_enemy_spawn_requested` to use path_index**

```gdscript
func _on_enemy_spawn_requested(enemy_id: String, path_index: int = 0) -> void:
	# ... existing def loading code ...
	var path: Path2D = _enemy_paths[clampi(path_index, 0, _enemy_paths.size() - 1)]
	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_follow.progress = 0.0
	path.add_child(path_follow)
	# ... rest of enemy setup unchanged ...
```

- [ ] **Step 4: Call `_setup_enemy_paths()` from `start_level()` instead of `_ready()`**

Move path setup from `_ready()` to `start_level()` (after `_level_id` is set and level data is available). Remove the old `_setup_enemy_path()` call from `_ready()`. Cache a `LevelRegistry` instance as `_level_registry` member variable (set up in `_ready()`) to avoid repeated construction.

- [ ] **Step 5: Run game to verify paths render correctly for level 1_1**

- [ ] **Step 6: Commit**

```
feat: support multi-path enemy spawning in game scene
```

---

### Task 8: game.gd — Camera integration and coordinate conversion

**Files:**
- Modify: `scenes/game.gd`

- [ ] **Step 1: Add camera setup in `start_level()`**

After world bounds are known, create GameCamera if map_scale > 1.0:

```gdscript
var _game_camera: GameCamera = null

# In start_level(), after loading level_def:
var map_scale: float = level_def.get("map_scale", 1.0)
if map_scale > 1.0:
	_game_camera = GameCamera.new()
	_game_camera.name = "GameCamera"
	add_child(_game_camera)
	var world_size := Vector2(1280.0 * map_scale, 720.0 * map_scale)
	_game_camera.setup(map_scale, world_size)
```

- [ ] **Step 2: Add viewport-to-world coordinate conversion**

Add helper method:
```gdscript
func _viewport_to_world(viewport_pos: Vector2) -> Vector2:
	if _game_camera == null:
		return viewport_pos
	return get_canvas_transform().affine_inverse() * viewport_pos
```

- [ ] **Step 3: Update `_handle_tap()` to convert coordinates**

After HUD exclusion checks (which stay in viewport space), convert to world space:
```gdscript
func _handle_tap(viewport_pos: Vector2) -> void:
	var pos: Vector2 = _viewport_to_world(viewport_pos)
	# ... rest uses world-space pos for _find_tower_at, _try_place_tower, _is_position_occupied ...
```

**Important:** `_touch_start_pos` stays in viewport space (used for drag distance detection in `_input()`). Only convert to world space when passing to world-space functions (`_find_tower_at`, `_try_place_tower`).

- [ ] **Step 4: Update `_process()` long-press to convert coordinates**

Convert `_touch_start_pos` through `_viewport_to_world()` only when calling `_find_tower_at()`:
```gdscript
var world_pos: Vector2 = _viewport_to_world(_touch_start_pos)
var tower_at: Tower = _find_tower_at(world_pos)
```

- [ ] **Step 5: Scale background, grid overlay, and field border to world size**

Add `world_size` member variables to `_GridOverlay` and `_FieldBorder` inner classes. Set them before `queue_redraw()`:
```gdscript
class _GridOverlay extends Node2D:
	var world_size: Vector2 = Vector2(1280, 720)
	func _draw() -> void:
		var grid_size: float = 64.0
		var color := Color(0.1, 0.15, 0.25, 0.15)
		var top_y: float = 57.0
		var bottom_y: float = world_size.y - 72.0
		var x: float = 0.0
		while x <= world_size.x:
			draw_line(Vector2(x, top_y), Vector2(x, bottom_y), color, 1.0)
			x += grid_size
		var y: float = top_y
		while y <= bottom_y:
			draw_line(Vector2(0, y), Vector2(world_size.x, y), color, 1.0)
			y += grid_size
```

Set world_size when creating the overlays in `_setup_hud()` or `start_level()`:
```gdscript
grid.world_size = Vector2(1280.0 * map_scale, 720.0 * map_scale)
grid.queue_redraw()
```

- [ ] **Step 6: Run game on a region 1 level to verify no regressions (no camera, identity transform)**

- [ ] **Step 7: Commit**

```
feat: integrate GameCamera with zoom/pan and coordinate conversion
```

---

### Task 9: GridManager — Scale grid with map_scale

**Files:**
- Modify: `core/pathfinding/grid_manager.gd`
- Modify: `scenes/game.gd` (pass map_scale to grid setup)

- [ ] **Step 1: Add map_scale parameter to GridManager.initialize() — keep existing signature compatible**

Keep the existing `size` parameter and add `map_scale` as an optional parameter. Compute scaled size at the call site to avoid breaking existing callers:

```gdscript
func initialize(size: Vector2i = Vector2i(20, 12), cell_size: Vector2 = Vector2(64.0, 64.0)) -> void:
	_grid_size = size
	_cell_size = cell_size
```

No signature change needed — callers compute scaled size:
```gdscript
var scaled_size := Vector2i(int(20.0 * map_scale), int(12.0 * map_scale))
grid_manager.initialize(scaled_size)
```

- [ ] **Step 2: Update game.gd to pass scaled grid size when setting up grid maze levels**

Grep for all existing `GridManager.initialize()` callers and update them to pass the scaled size.

- [ ] **Step 3: Run tests to verify no regressions**

- [ ] **Step 4: Commit**

```
feat: scale grid maze dimensions with map_scale
```

---

### Task 10: Integration testing

**Files:**
- Test: `tests/test_integration_map_variety.gd`

- [ ] **Step 1: Write integration test — zigzag level loads paths**

```gdscript
func test_zigzag_level_creates_single_path() -> void:
	# Simulate loading level 1_1 paths
	var paths: Dictionary = LevelData.get_level_paths("1_1")
	assert_eq(paths["type"], "zigzag")
	assert_eq(paths["paths"].size(), 1)
```

- [ ] **Step 2: Write integration test — branching level loads 2 paths**

```gdscript
func test_branching_level_creates_two_paths() -> void:
	var paths: Dictionary = LevelData.get_level_paths("1_5")
	assert_eq(paths["type"], "branching")
	assert_eq(paths["paths"].size(), 2)
```

- [ ] **Step 3: Write integration test — procedural fallback works**

```gdscript
func test_procedural_fallback_for_unknown_level() -> void:
	var paths: Dictionary = LevelData.get_level_paths("1_7")
	assert_true(paths.is_empty(), "Non-milestone should have no hand-crafted data")
	# PathGenerator should fill in
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("zigzag", 1.0, 7, "1_7".hash())
	assert_true(result["paths"].size() > 0, "PathGenerator should produce paths")
```

- [ ] **Step 4: Write integration test — map_scale from registry**

```gdscript
func test_map_scale_matches_region() -> void:
	var reg := LevelRegistry.new()
	reg.register_levels()
	for region in range(1, 6):
		var level_id: String = "%d_1" % region
		var level: Dictionary = reg.get_level(level_id)
		var expected: float = 1.0 + float(region - 1) * 0.5
		assert_eq(level["map_scale"], expected, "Region %d should have scale %.1f" % [region, expected])
```

- [ ] **Step 5: Run all tests**

- [ ] **Step 6: Commit**

```
test: add integration tests for map variety system
```

---

### Task 11: Manual play-testing checkpoint

- [ ] **Step 1: Play level 1_1** — should be unchanged (zigzag, no zoom)
- [ ] **Step 2: Play level 1_5** — should show branching paths with 2 colored routes
- [ ] **Step 3: Play level 1_10** — should show spiral path with loop-back
- [ ] **Step 4: Play a level 1_4** (procedural) — should generate a zigzag path
- [ ] **Step 5: Play level 3_1** — should have zoom/pan (map_scale 2.0), spiral path
- [ ] **Step 6: Verify tower placement works correctly when zoomed in**
- [ ] **Step 7: Verify enemy spawning uses correct paths on branching levels**
- [ ] **Step 8: Report any issues found**
