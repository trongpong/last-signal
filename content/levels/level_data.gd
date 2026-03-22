class_name LevelData

## Static helper that returns hand-crafted wave sequences and path data for
## specific levels.
##
## Levels covered:
##   1_1  – "First Contact"      (5 waves, tutorial pacing)
##   1_2  – "Outer Gate"         (8 waves, introduces drone_fast)
##   1_3  – "Relay Defense"      (10 waves, first armoured enemy)
##   1_5  – "Crossroads"         (7 waves, branching paths)
##   1_10 – "Perimeter Boss"     (10 waves, spiral path, boss finale)
##   2_1  – "Grid Gauntlet"      (8 waves, grid maze — no path data)
##   2_10 – "Grid Siege"         (10 waves, grid maze — no path data)
##   3_1  – "Spiral Approach"    (8 waves, spiral, scale 2.0)
##   3_9  – "Triple Entry"       (10 waves, multi-entry, scale 2.0)
##   4_1  – "Branching Assault"  (8 waves, branching, scale 2.5)
##   4_9  – "Convergence Point"  (10 waves, multi-entry, scale 2.5)
##   5_1  – "Maze of Shadows"    (8 waves, grid maze — no path data)
##   5_8  – "Final Approach"     (12 waves, multi-entry, scale 3.0)
##
## All other levels fall back to WaveGenerator (procedural).

# ---------------------------------------------------------------------------
# Path Points (legacy single-path format)
# ---------------------------------------------------------------------------

## Per-level enemy path waypoints keyed by normalised level id (e.g. "1_1").
const _PATH_POINTS: Dictionary = {
	"1_1": [
		Vector2(-33, 360), Vector2(200, 200), Vector2(467, 400),
		Vector2(734, 133), Vector2(1000, 334), Vector2(1314, 360),
	],
	"1_2": [
		Vector2(-33, 200), Vector2(267, 334), Vector2(534, 133),
		Vector2(800, 400), Vector2(1067, 200), Vector2(1314, 267),
	],
	"1_3": [
		Vector2(-33, 467), Vector2(200, 267), Vector2(400, 467),
		Vector2(600, 200), Vector2(800, 400), Vector2(1000, 200),
		Vector2(1314, 334),
	],
}

## Default path used when a level has no hand-crafted path data.
const _DEFAULT_PATH_POINTS: Array = [
	Vector2(-33, 360), Vector2(200, 200), Vector2(467, 400),
	Vector2(734, 133), Vector2(1000, 334), Vector2(1314, 360),
]

# ---------------------------------------------------------------------------
# Path Data (new multi-path format with type metadata)
# ---------------------------------------------------------------------------

## Per-level path data in the new dictionary format.
## Each entry has: "type" (String), "paths" (Array of Arrays of Vector2),
## "exit" (Vector2), and optionally "merge_point" (Vector2).
const _LEVEL_PATHS: Dictionary = {
	# Region 1 — map_scale 1.0, X: -33..1314, Y: 0..720
	"1_1": {
		"type": "zigzag",
		"paths": [[Vector2(-33, 360), Vector2(200, 200), Vector2(467, 400),
			Vector2(734, 133), Vector2(1000, 334), Vector2(1314, 360)]],
		"exit": Vector2(1314, 360),
	},
	"1_2": {
		"type": "zigzag",
		"paths": [[Vector2(-33, 200), Vector2(267, 334), Vector2(534, 133),
			Vector2(800, 400), Vector2(1067, 200), Vector2(1314, 267)]],
		"exit": Vector2(1314, 267),
	},
	"1_3": {
		"type": "zigzag",
		"paths": [[Vector2(-33, 467), Vector2(200, 267), Vector2(400, 467),
			Vector2(600, 200), Vector2(800, 400), Vector2(1000, 200), Vector2(1314, 334)]],
		"exit": Vector2(1314, 334),
	},
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
	"1_10": {
		"type": "spiral",
		"paths": [[Vector2(-33, 360), Vector2(200, 180), Vector2(500, 500),
			Vector2(400, 550), Vector2(350, 300), Vector2(600, 150),
			Vector2(850, 400), Vector2(1100, 250), Vector2(1314, 360)]],
		"exit": Vector2(1314, 360),
	},
	# Region 3 — map_scale 2.0, X: -33..2593, Y: 57..1368
	"3_1": {
		"type": "spiral",
		"paths": [[Vector2(-33, 720), Vector2(400, 360), Vector2(1000, 1000),
			Vector2(800, 1100), Vector2(700, 600), Vector2(1200, 300),
			Vector2(1700, 800), Vector2(2200, 500), Vector2(2593, 720)]],
		"exit": Vector2(2593, 720),
	},
	"3_9": {
		"type": "multi_entry",
		"paths": [
			[Vector2(-33, 360), Vector2(400, 500), Vector2(900, 600),
				Vector2(1400, 500), Vector2(1900, 600), Vector2(2593, 720)],
			[Vector2(-33, 720), Vector2(500, 800), Vector2(1000, 700),
				Vector2(1500, 900), Vector2(2000, 700), Vector2(2593, 720)],
			[Vector2(-33, 1080), Vector2(400, 1000), Vector2(900, 1100),
				Vector2(1400, 900), Vector2(1900, 1000), Vector2(2593, 720)],
		],
		"exit": Vector2(2593, 720),
	},
	# Region 4 — map_scale 2.5, X: -33..3233, Y: 57..1743
	"4_1": {
		"type": "branching",
		"paths": [
			[Vector2(-33, 900), Vector2(500, 900), Vector2(900, 400),
				Vector2(1600, 400), Vector2(2200, 900), Vector2(3233, 900)],
			[Vector2(-33, 900), Vector2(500, 900), Vector2(900, 1400),
				Vector2(1600, 1400), Vector2(2200, 900), Vector2(3233, 900)],
		],
		"merge_point": Vector2(2200, 900),
		"exit": Vector2(3233, 900),
	},
	"4_9": {
		"type": "multi_entry",
		"paths": [
			[Vector2(-33, 450), Vector2(600, 350), Vector2(1200, 600),
				Vector2(1800, 400), Vector2(2400, 700), Vector2(3233, 900)],
			[Vector2(-33, 900), Vector2(600, 800), Vector2(1200, 1000),
				Vector2(1800, 900), Vector2(2400, 1000), Vector2(3233, 900)],
			[Vector2(-33, 1350), Vector2(600, 1400), Vector2(1200, 1200),
				Vector2(1800, 1350), Vector2(2400, 1100), Vector2(3233, 900)],
		],
		"exit": Vector2(3233, 900),
	},
	# Region 5 — map_scale 3.0, X: -33..3873, Y: 57..2103
	"5_8": {
		"type": "multi_entry",
		"paths": [
			[Vector2(-33, 540), Vector2(700, 400), Vector2(1400, 700),
				Vector2(2100, 500), Vector2(2800, 800), Vector2(3873, 1080)],
			[Vector2(-33, 1080), Vector2(700, 900), Vector2(1400, 1100),
				Vector2(2100, 1000), Vector2(2800, 1200), Vector2(3873, 1080)],
			[Vector2(-33, 1620), Vector2(700, 1500), Vector2(1400, 1700),
				Vector2(2100, 1400), Vector2(2800, 1500), Vector2(3873, 1080)],
		],
		"exit": Vector2(3873, 1080),
	},
}

# ---------------------------------------------------------------------------
# Path API
# ---------------------------------------------------------------------------

## Returns path data in the new dictionary format for the given level id.
## Accepts both "1_1" and "level_1_1" formats.
## Returns an empty Dictionary if no hand-crafted path data exists.
static func get_level_paths(level_id: String) -> Dictionary:
	var id: String = level_id
	if id.begins_with("level_"):
		id = id.substr(6)
	if _LEVEL_PATHS.has(id):
		return _LEVEL_PATHS[id].duplicate(true)
	return {}

## Returns the enemy path waypoints for the given level id (legacy format).
## Accepts both "1_1" and "level_1_1" formats.
## Falls back to the first path from the new format, then to _PATH_POINTS,
## then to the default path.
static func get_path_points(level_id: String) -> Array:
	var id: String = level_id
	if id.begins_with("level_"):
		id = id.substr(6)
	# Try new format first — return the first path
	if _LEVEL_PATHS.has(id):
		var paths: Array = _LEVEL_PATHS[id]["paths"]
		if paths.size() > 0:
			return paths[0].duplicate()
	# Fall back to legacy single-path data
	if _PATH_POINTS.has(id):
		return _PATH_POINTS[id].duplicate()
	return _DEFAULT_PATH_POINTS.duplicate()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns an Array of WaveDefinitions for the given level id.
## Returns an empty Array if no hand-crafted data exists for that id.
## Accepts both "1_1" and "level_1_1" formats.
static func get_waves(level_id: String) -> Array:
	# Strip optional "level_" prefix so both formats work
	var id: String = level_id
	if id.begins_with("level_"):
		id = id.substr(6)
	match id:
		"1_1":
			return _level_1_1()
		"1_2":
			return _level_1_2()
		"1_3":
			return _level_1_3()
		"1_5":
			return _level_1_5()
		"1_10":
			return _level_1_10()
		"2_1":
			return _level_2_1()
		"2_10":
			return _level_2_10()
		"3_1":
			return _level_3_1()
		"3_9":
			return _level_3_9()
		"4_1":
			return _level_4_1()
		"4_9":
			return _level_4_9()
		"5_1":
			return _level_5_1()
		"5_8":
			return _level_5_8()
	return []

# ---------------------------------------------------------------------------
# Level 1-1: First Contact
## 5 gentle waves — only scout and drone.
# ---------------------------------------------------------------------------

static func _level_1_1() -> Array:
	var waves: Array = []

	# Wave 1 — 6 scouts
	waves.append(_make_wave(1, false, [
		_sub("scout", 6, 0.6, 0.0),
	]))
	# Wave 2 — 6 scouts + 3 drones
	waves.append(_make_wave(2, false, [
		_sub("scout", 6, 0.6, 0.0),
		_sub("drone", 3, 0.8, 4.0),
	]))
	# Wave 3 — 8 scouts
	waves.append(_make_wave(3, false, [
		_sub("scout", 8, 0.5, 0.0),
	]))
	# Wave 4 — 5 drones + 5 scouts
	waves.append(_make_wave(4, false, [
		_sub("drone", 5, 0.7, 0.0),
		_sub("scout", 5, 0.5, 4.5),
	]))
	# Wave 5 — mini-boss wave: 4 drones + 10 scouts
	waves.append(_make_wave(5, true, [
		_sub("drone", 4, 1.0, 0.0),
		_sub("scout", 10, 0.4, 5.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-2: Outer Gate
## 8 waves — introduces fast scouts on wave 4.
# ---------------------------------------------------------------------------

static func _level_1_2() -> Array:
	var waves: Array = []

	waves.append(_make_wave(1, false, [
		_sub("scout", 8, 0.5, 0.0),
	]))
	waves.append(_make_wave(2, false, [
		_sub("scout", 8, 0.5, 0.0),
		_sub("drone", 4, 0.7, 5.0),
	]))
	waves.append(_make_wave(3, false, [
		_sub("drone", 8, 0.6, 0.0),
		_sub("scout", 6, 0.5, 6.0),
	]))
	# Wave 4 — first fast-scout appearance (scout used as fast enemy)
	waves.append(_make_wave(4, false, [
		_sub("scout", 6, 0.5, 0.0),
		_sub("scout", 4, 0.4, 4.0),
	]))
	waves.append(_make_wave(5, false, [
		_sub("drone", 8, 0.5, 0.0),
		_sub("scout", 4, 0.35, 5.5),
	]))
	waves.append(_make_wave(6, false, [
		_sub("scout", 10, 0.45, 0.0),
		_sub("scout", 6, 0.35, 6.0),
	]))
	waves.append(_make_wave(7, false, [
		_sub("drone", 10, 0.5, 0.0),
		_sub("scout", 8, 0.35, 6.5),
	]))
	# Wave 8 — boss: mass swarm
	waves.append(_make_wave(8, true, [
		_sub("scout", 6, 0.3, 0.0),
		_sub("scout", 12, 0.4, 3.0),
		_sub("drone", 8, 0.5, 8.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-3: Relay Defense
## 10 waves — introduces tank on wave 6.
# ---------------------------------------------------------------------------

static func _level_1_3() -> Array:
	var waves: Array = []

	waves.append(_make_wave(1, false, [
		_sub("scout", 10, 0.5, 0.0),
	]))
	waves.append(_make_wave(2, false, [
		_sub("drone", 8, 0.55, 0.0),
		_sub("scout", 6, 0.45, 5.0),
	]))
	waves.append(_make_wave(3, false, [
		_sub("scout", 6, 0.35, 0.0),
		_sub("drone", 6, 0.5, 4.0),
	]))
	waves.append(_make_wave(4, false, [
		_sub("scout", 12, 0.45, 0.0),
		_sub("scout", 6, 0.35, 6.5),
	]))
	waves.append(_make_wave(5, false, [
		_sub("drone", 10, 0.5, 0.0),
		_sub("scout", 8, 0.35, 6.0),
	]))
	# Wave 6 — tank debut
	waves.append(_make_wave(6, false, [
		_sub("tank", 2, 1.5, 0.0),
		_sub("scout", 12, 0.4, 4.0),
	]))
	waves.append(_make_wave(7, false, [
		_sub("tank", 3, 1.5, 0.0),
		_sub("scout", 8, 0.35, 5.5),
	]))
	waves.append(_make_wave(8, false, [
		_sub("drone", 12, 0.45, 0.0),
		_sub("tank", 3, 1.5, 7.0),
		_sub("scout", 6, 0.35, 12.0),
	]))
	waves.append(_make_wave(9, false, [
		_sub("scout", 14, 0.4, 0.0),
		_sub("scout", 10, 0.3, 7.0),
		_sub("tank", 4, 1.5, 12.0),
	]))
	# Wave 10 — boss: tanks + escorts
	waves.append(_make_wave(10, true, [
		_sub("tank", 4, 2.0, 0.0),
		_sub("scout", 10, 0.3, 10.0),
		_sub("scout", 16, 0.35, 16.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-5: Crossroads
## 7 waves — branching paths, enemies split between two routes.
# ---------------------------------------------------------------------------

static func _level_1_5() -> Array:
	var waves: Array = []

	# Wave 1 — scouts on both paths
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 4, 0.8, 0.0, 0),
		_sub("scout_basic", 4, 0.8, 0.5, 1),
	]))
	# Wave 2 — drones on path 0, scouts on path 1
	waves.append(_make_wave(2, false, [
		_sub("drone_basic", 5, 0.7, 0.0, 0),
		_sub("scout_basic", 6, 0.6, 1.0, 1),
	]))
	# Wave 3 — fast drones on path 1, scouts on path 0
	waves.append(_make_wave(3, false, [
		_sub("scout_basic", 8, 0.5, 0.0, 0),
		_sub("drone_fast", 4, 0.6, 2.0, 1),
	]))
	# Wave 4 — mixed pressure on both paths
	waves.append(_make_wave(4, false, [
		_sub("drone_basic", 6, 0.6, 0.0, 0),
		_sub("drone_basic", 6, 0.6, 0.5, 1),
		_sub("scout_basic", 4, 0.5, 5.0, 0),
	]))
	# Wave 5 — armored scouts on path 0, swarm on path 1
	waves.append(_make_wave(5, false, [
		_sub("scout_armored", 3, 1.0, 0.0, 0),
		_sub("drone_swarm", 8, 0.4, 1.0, 1),
	]))
	# Wave 6 — heavy pressure both paths
	waves.append(_make_wave(6, false, [
		_sub("drone_fast", 6, 0.5, 0.0, 0),
		_sub("scout_armored", 4, 0.8, 0.0, 1),
		_sub("scout_basic", 8, 0.4, 4.0, 0),
	]))
	# Wave 7 — boss: tank on path 0, flyers on path 1
	waves.append(_make_wave(7, true, [
		_sub("tank_heavy", 2, 2.0, 0.0, 0),
		_sub("flyer_light", 6, 0.6, 1.0, 1),
		_sub("scout_basic", 10, 0.35, 5.0, 0),
		_sub("drone_basic", 8, 0.5, 5.0, 1),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-10: Perimeter Boss
## 10 waves — spiral path, escalating difficulty, boss finale.
# ---------------------------------------------------------------------------

static func _level_1_10() -> Array:
	var waves: Array = []

	# Wave 1 — scout warm-up
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 8, 0.6, 0.0),
	]))
	# Wave 2 — drones join
	waves.append(_make_wave(2, false, [
		_sub("scout_basic", 6, 0.5, 0.0),
		_sub("drone_basic", 5, 0.7, 4.0),
	]))
	# Wave 3 — fast drones
	waves.append(_make_wave(3, false, [
		_sub("drone_fast", 6, 0.5, 0.0),
		_sub("scout_basic", 8, 0.45, 4.0),
	]))
	# Wave 4 — armored scouts + drones
	waves.append(_make_wave(4, false, [
		_sub("scout_armored", 4, 0.8, 0.0),
		_sub("drone_basic", 8, 0.5, 4.0),
	]))
	# Wave 5 — swarm wave
	waves.append(_make_wave(5, false, [
		_sub("drone_swarm", 12, 0.3, 0.0),
		_sub("scout_basic", 6, 0.5, 5.0),
	]))
	# Wave 6 — flyers debut
	waves.append(_make_wave(6, false, [
		_sub("flyer_light", 5, 0.7, 0.0),
		_sub("scout_armored", 4, 0.8, 4.5),
		_sub("drone_basic", 6, 0.5, 7.0),
	]))
	# Wave 7 — tank + escorts
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 2, 2.0, 0.0),
		_sub("scout_basic", 10, 0.4, 5.0),
		_sub("drone_fast", 4, 0.5, 9.0),
	]))
	# Wave 8 — multi-threat
	waves.append(_make_wave(8, false, [
		_sub("flyer_light", 6, 0.6, 0.0),
		_sub("tank_heavy", 3, 1.5, 4.0),
		_sub("scout_armored", 6, 0.6, 8.0),
	]))
	# Wave 9 — pre-boss crescendo
	waves.append(_make_wave(9, false, [
		_sub("drone_swarm", 10, 0.3, 0.0),
		_sub("tank_heavy", 3, 1.5, 4.0),
		_sub("flyer_light", 6, 0.5, 8.0),
		_sub("scout_basic", 12, 0.35, 12.0),
	]))
	# Wave 10 — boss: tank_boss + heavy escort
	waves.append(_make_wave(10, true, [
		_sub("tank_boss", 1, 1.0, 0.0),
		_sub("tank_heavy", 3, 2.0, 3.0),
		_sub("flyer_light", 8, 0.5, 8.0),
		_sub("scout_basic", 14, 0.3, 12.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 2-1: Grid Gauntlet (GRID_MAZE — wave data only)
## 8 waves — introduces grid maze gameplay.
# ---------------------------------------------------------------------------

static func _level_2_1() -> Array:
	var waves: Array = []

	# Wave 1 — basic intro
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 8, 0.6, 0.0),
	]))
	# Wave 2 — drones
	waves.append(_make_wave(2, false, [
		_sub("drone_basic", 6, 0.6, 0.0),
		_sub("scout_basic", 6, 0.5, 4.0),
	]))
	# Wave 3 — fast enemies test maze pathing
	waves.append(_make_wave(3, false, [
		_sub("drone_fast", 6, 0.5, 0.0),
		_sub("scout_basic", 8, 0.45, 4.0),
	]))
	# Wave 4 — armored units
	waves.append(_make_wave(4, false, [
		_sub("scout_armored", 4, 0.8, 0.0),
		_sub("drone_basic", 8, 0.5, 4.0),
	]))
	# Wave 5 — swarm
	waves.append(_make_wave(5, false, [
		_sub("drone_swarm", 10, 0.35, 0.0),
		_sub("scout_basic", 6, 0.5, 5.0),
	]))
	# Wave 6 — mixed
	waves.append(_make_wave(6, false, [
		_sub("flyer_light", 4, 0.7, 0.0),
		_sub("scout_armored", 5, 0.7, 3.5),
		_sub("drone_basic", 6, 0.5, 7.0),
	]))
	# Wave 7 — heavy pressure
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 2, 2.0, 0.0),
		_sub("drone_fast", 6, 0.5, 4.0),
		_sub("scout_basic", 10, 0.4, 7.0),
	]))
	# Wave 8 — boss: tank + flyers
	waves.append(_make_wave(8, true, [
		_sub("tank_heavy", 3, 1.5, 0.0),
		_sub("flyer_light", 6, 0.6, 5.0),
		_sub("scout_basic", 12, 0.35, 9.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 2-10: Grid Siege (GRID_MAZE — wave data only)
## 10 waves — grid maze boss level.
# ---------------------------------------------------------------------------

static func _level_2_10() -> Array:
	var waves: Array = []

	# Wave 1
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 10, 0.5, 0.0),
	]))
	# Wave 2
	waves.append(_make_wave(2, false, [
		_sub("drone_basic", 8, 0.55, 0.0),
		_sub("scout_basic", 6, 0.45, 5.0),
	]))
	# Wave 3
	waves.append(_make_wave(3, false, [
		_sub("drone_fast", 8, 0.45, 0.0),
		_sub("scout_armored", 4, 0.8, 4.5),
	]))
	# Wave 4
	waves.append(_make_wave(4, false, [
		_sub("scout_armored", 6, 0.7, 0.0),
		_sub("drone_swarm", 10, 0.3, 5.0),
	]))
	# Wave 5
	waves.append(_make_wave(5, false, [
		_sub("flyer_light", 6, 0.6, 0.0),
		_sub("drone_basic", 10, 0.45, 4.0),
	]))
	# Wave 6 — healer debut
	waves.append(_make_wave(6, false, [
		_sub("tank_heavy", 3, 1.5, 0.0),
		_sub("healer_support", 2, 2.0, 2.0),
		_sub("scout_basic", 8, 0.4, 6.0),
	]))
	# Wave 7
	waves.append(_make_wave(7, false, [
		_sub("flyer_heavy", 3, 1.2, 0.0),
		_sub("drone_fast", 8, 0.4, 4.5),
		_sub("scout_armored", 6, 0.6, 8.0),
	]))
	# Wave 8
	waves.append(_make_wave(8, false, [
		_sub("tank_heavy", 4, 1.5, 0.0),
		_sub("healer_support", 3, 1.5, 3.0),
		_sub("flyer_light", 6, 0.5, 7.0),
	]))
	# Wave 9 — pre-boss
	waves.append(_make_wave(9, false, [
		_sub("drone_swarm", 14, 0.25, 0.0),
		_sub("flyer_heavy", 4, 1.0, 5.0),
		_sub("tank_heavy", 3, 1.5, 9.0),
	]))
	# Wave 10 — boss
	waves.append(_make_wave(10, true, [
		_sub("tank_boss", 1, 1.0, 0.0),
		_sub("shielder_elite", 2, 2.0, 2.0),
		_sub("healer_support", 3, 1.5, 5.0),
		_sub("flyer_light", 8, 0.5, 8.0),
		_sub("scout_basic", 12, 0.3, 12.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 3-1: Spiral Approach (spiral, map_scale 2.0)
## 8 waves — larger map, spiral path.
# ---------------------------------------------------------------------------

static func _level_3_1() -> Array:
	var waves: Array = []

	# Wave 1
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 10, 0.55, 0.0),
		_sub("drone_basic", 4, 0.7, 6.0),
	]))
	# Wave 2
	waves.append(_make_wave(2, false, [
		_sub("drone_fast", 6, 0.5, 0.0),
		_sub("scout_armored", 4, 0.8, 4.0),
	]))
	# Wave 3
	waves.append(_make_wave(3, false, [
		_sub("scout_armored", 6, 0.7, 0.0),
		_sub("drone_swarm", 8, 0.35, 5.0),
	]))
	# Wave 4
	waves.append(_make_wave(4, false, [
		_sub("flyer_light", 5, 0.6, 0.0),
		_sub("drone_basic", 8, 0.5, 4.0),
		_sub("scout_basic", 6, 0.45, 8.0),
	]))
	# Wave 5
	waves.append(_make_wave(5, false, [
		_sub("tank_heavy", 3, 1.5, 0.0),
		_sub("healer_support", 2, 2.0, 2.0),
		_sub("scout_armored", 6, 0.6, 6.0),
	]))
	# Wave 6
	waves.append(_make_wave(6, false, [
		_sub("flyer_heavy", 3, 1.0, 0.0),
		_sub("drone_fast", 8, 0.4, 4.0),
		_sub("drone_swarm", 8, 0.3, 8.0),
	]))
	# Wave 7
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 4, 1.5, 0.0),
		_sub("flyer_light", 6, 0.5, 7.0),
		_sub("scout_basic", 10, 0.4, 10.0),
	]))
	# Wave 8 — boss
	waves.append(_make_wave(8, true, [
		_sub("tank_boss", 1, 1.0, 0.0),
		_sub("tank_heavy", 3, 1.5, 3.0),
		_sub("healer_support", 2, 2.0, 6.0),
		_sub("flyer_light", 8, 0.5, 8.0),
		_sub("scout_armored", 8, 0.5, 12.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 3-9: Triple Entry (multi-entry, map_scale 2.0)
## 10 waves — three entry paths, enemies attack from all directions.
# ---------------------------------------------------------------------------

static func _level_3_9() -> Array:
	var waves: Array = []

	# Wave 1 — scouts on all three paths
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 4, 0.7, 0.0, 0),
		_sub("scout_basic", 4, 0.7, 0.3, 1),
		_sub("scout_basic", 4, 0.7, 0.6, 2),
	]))
	# Wave 2 — drones on path 0, scouts on paths 1-2
	waves.append(_make_wave(2, false, [
		_sub("drone_basic", 6, 0.6, 0.0, 0),
		_sub("scout_basic", 6, 0.5, 1.0, 1),
		_sub("scout_armored", 3, 0.9, 2.0, 2),
	]))
	# Wave 3 — fast drones on path 1
	waves.append(_make_wave(3, false, [
		_sub("scout_basic", 8, 0.5, 0.0, 0),
		_sub("drone_fast", 6, 0.5, 0.0, 1),
		_sub("drone_basic", 6, 0.6, 3.0, 2),
	]))
	# Wave 4 — swarm on path 2
	waves.append(_make_wave(4, false, [
		_sub("scout_armored", 5, 0.7, 0.0, 0),
		_sub("drone_basic", 8, 0.5, 2.0, 1),
		_sub("drone_swarm", 10, 0.3, 1.0, 2),
	]))
	# Wave 5 — flyers and tanks
	waves.append(_make_wave(5, false, [
		_sub("flyer_light", 4, 0.7, 0.0, 0),
		_sub("tank_heavy", 2, 2.0, 0.0, 1),
		_sub("scout_basic", 8, 0.4, 4.0, 2),
	]))
	# Wave 6 — healers support tanks
	waves.append(_make_wave(6, false, [
		_sub("tank_heavy", 3, 1.5, 0.0, 0),
		_sub("healer_support", 2, 2.0, 1.0, 0),
		_sub("drone_fast", 6, 0.5, 3.0, 1),
		_sub("scout_armored", 6, 0.6, 3.0, 2),
	]))
	# Wave 7
	waves.append(_make_wave(7, false, [
		_sub("flyer_heavy", 3, 1.0, 0.0, 0),
		_sub("drone_swarm", 10, 0.3, 2.0, 1),
		_sub("tank_heavy", 2, 2.0, 2.0, 2),
		_sub("scout_basic", 8, 0.4, 7.0, 0),
	]))
	# Wave 8
	waves.append(_make_wave(8, false, [
		_sub("shielder_elite", 2, 2.0, 0.0, 0),
		_sub("tank_heavy", 3, 1.5, 0.0, 1),
		_sub("flyer_light", 6, 0.5, 3.0, 2),
		_sub("drone_fast", 8, 0.4, 6.0, 0),
	]))
	# Wave 9 — pre-boss
	waves.append(_make_wave(9, false, [
		_sub("tank_heavy", 4, 1.5, 0.0, 0),
		_sub("flyer_heavy", 4, 1.0, 0.0, 1),
		_sub("healer_support", 3, 1.5, 3.0, 2),
		_sub("scout_armored", 8, 0.5, 7.0, 0),
		_sub("drone_swarm", 10, 0.3, 7.0, 1),
	]))
	# Wave 10 — boss on path 1, elites on paths 0 and 2
	waves.append(_make_wave(10, true, [
		_sub("shielder_elite", 3, 1.5, 0.0, 0),
		_sub("tank_boss", 1, 1.0, 0.0, 1),
		_sub("flyer_heavy", 3, 1.2, 0.0, 2),
		_sub("healer_support", 3, 1.5, 4.0, 1),
		_sub("scout_basic", 10, 0.35, 8.0, 0),
		_sub("drone_fast", 8, 0.4, 8.0, 2),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 4-1: Branching Assault (branching, map_scale 2.5)
## 8 waves — two diverging paths, heavier enemies.
# ---------------------------------------------------------------------------

static func _level_4_1() -> Array:
	var waves: Array = []

	# Wave 1 — scouts split both paths
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 6, 0.6, 0.0, 0),
		_sub("scout_basic", 6, 0.6, 0.5, 1),
	]))
	# Wave 2 — armored on path 0, drones on path 1
	waves.append(_make_wave(2, false, [
		_sub("scout_armored", 5, 0.7, 0.0, 0),
		_sub("drone_fast", 6, 0.5, 0.0, 1),
		_sub("drone_basic", 4, 0.6, 4.0, 0),
	]))
	# Wave 3 — swarm and tanks
	waves.append(_make_wave(3, false, [
		_sub("drone_swarm", 10, 0.3, 0.0, 0),
		_sub("tank_heavy", 2, 2.0, 0.0, 1),
		_sub("scout_basic", 6, 0.5, 4.0, 1),
	]))
	# Wave 4 — flyers and healers
	waves.append(_make_wave(4, false, [
		_sub("flyer_light", 5, 0.6, 0.0, 0),
		_sub("healer_support", 2, 2.0, 0.0, 1),
		_sub("tank_heavy", 3, 1.5, 3.0, 1),
	]))
	# Wave 5 — heavy flyers
	waves.append(_make_wave(5, false, [
		_sub("flyer_heavy", 3, 1.0, 0.0, 0),
		_sub("scout_armored", 6, 0.6, 2.0, 1),
		_sub("drone_fast", 8, 0.4, 5.0, 0),
	]))
	# Wave 6 — shielders
	waves.append(_make_wave(6, false, [
		_sub("shielder_elite", 2, 2.0, 0.0, 0),
		_sub("tank_heavy", 3, 1.5, 0.0, 1),
		_sub("healer_support", 2, 2.0, 3.0, 0),
		_sub("drone_swarm", 10, 0.3, 6.0, 1),
	]))
	# Wave 7 — pre-boss
	waves.append(_make_wave(7, false, [
		_sub("flyer_heavy", 4, 1.0, 0.0, 0),
		_sub("tank_heavy", 4, 1.5, 0.0, 1),
		_sub("healer_support", 3, 1.5, 5.0, 0),
		_sub("scout_armored", 8, 0.5, 7.0, 1),
	]))
	# Wave 8 — boss on path 0, heavy escort on path 1
	waves.append(_make_wave(8, true, [
		_sub("tank_boss", 1, 1.0, 0.0, 0),
		_sub("shielder_elite", 3, 1.5, 0.0, 1),
		_sub("healer_support", 3, 1.5, 3.0, 0),
		_sub("flyer_heavy", 4, 1.0, 5.0, 1),
		_sub("scout_basic", 12, 0.3, 9.0, 0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 4-9: Convergence Point (multi-entry, map_scale 2.5)
## 10 waves — three entry paths, tough late-game enemies.
# ---------------------------------------------------------------------------

static func _level_4_9() -> Array:
	var waves: Array = []

	# Wave 1 — scouts from all entries
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 5, 0.6, 0.0, 0),
		_sub("scout_basic", 5, 0.6, 0.3, 1),
		_sub("scout_basic", 5, 0.6, 0.6, 2),
	]))
	# Wave 2 — armored and fast
	waves.append(_make_wave(2, false, [
		_sub("scout_armored", 4, 0.7, 0.0, 0),
		_sub("drone_fast", 6, 0.5, 0.0, 1),
		_sub("drone_basic", 8, 0.5, 2.0, 2),
	]))
	# Wave 3 — tanks and swarm
	waves.append(_make_wave(3, false, [
		_sub("tank_heavy", 2, 2.0, 0.0, 0),
		_sub("drone_swarm", 12, 0.25, 0.0, 1),
		_sub("scout_armored", 6, 0.6, 3.0, 2),
	]))
	# Wave 4 — flyers and healers
	waves.append(_make_wave(4, false, [
		_sub("flyer_light", 6, 0.6, 0.0, 0),
		_sub("healer_support", 3, 1.5, 0.0, 1),
		_sub("tank_heavy", 3, 1.5, 2.0, 2),
	]))
	# Wave 5 — heavy flyers and shielders
	waves.append(_make_wave(5, false, [
		_sub("flyer_heavy", 4, 1.0, 0.0, 0),
		_sub("shielder_elite", 2, 2.0, 0.0, 1),
		_sub("drone_fast", 8, 0.4, 3.0, 2),
	]))
	# Wave 6 — combined arms
	waves.append(_make_wave(6, false, [
		_sub("tank_heavy", 4, 1.5, 0.0, 0),
		_sub("healer_support", 3, 1.5, 1.0, 0),
		_sub("flyer_heavy", 3, 1.0, 0.0, 1),
		_sub("drone_swarm", 10, 0.3, 4.0, 2),
	]))
	# Wave 7 — shielders + escorts
	waves.append(_make_wave(7, false, [
		_sub("shielder_elite", 3, 1.5, 0.0, 0),
		_sub("flyer_light", 6, 0.5, 2.0, 1),
		_sub("tank_heavy", 3, 1.5, 2.0, 2),
		_sub("scout_armored", 8, 0.5, 7.0, 1),
	]))
	# Wave 8 — massive pressure
	waves.append(_make_wave(8, false, [
		_sub("tank_heavy", 4, 1.5, 0.0, 0),
		_sub("flyer_heavy", 4, 1.0, 0.0, 1),
		_sub("shielder_elite", 3, 1.5, 0.0, 2),
		_sub("healer_support", 3, 1.5, 5.0, 0),
	]))
	# Wave 9 — pre-boss crescendo
	waves.append(_make_wave(9, false, [
		_sub("flyer_heavy", 5, 0.8, 0.0, 0),
		_sub("tank_heavy", 5, 1.2, 0.0, 1),
		_sub("drone_swarm", 14, 0.25, 3.0, 2),
		_sub("healer_support", 4, 1.2, 6.0, 0),
		_sub("shielder_elite", 3, 1.5, 8.0, 1),
	]))
	# Wave 10 — boss on path 1, elites on all paths
	waves.append(_make_wave(10, true, [
		_sub("shielder_elite", 3, 1.5, 0.0, 0),
		_sub("tank_boss", 1, 1.0, 0.0, 1),
		_sub("flyer_heavy", 4, 1.0, 0.0, 2),
		_sub("healer_support", 4, 1.2, 3.0, 1),
		_sub("tank_heavy", 4, 1.5, 6.0, 0),
		_sub("scout_armored", 10, 0.4, 9.0, 2),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 5-1: Maze of Shadows (GRID_MAZE — wave data only)
## 8 waves — hardest grid maze, late-game enemies.
# ---------------------------------------------------------------------------

static func _level_5_1() -> Array:
	var waves: Array = []

	# Wave 1 — armored scouts
	waves.append(_make_wave(1, false, [
		_sub("scout_armored", 8, 0.6, 0.0),
		_sub("drone_fast", 4, 0.5, 5.0),
	]))
	# Wave 2 — flyers and tanks
	waves.append(_make_wave(2, false, [
		_sub("flyer_light", 6, 0.6, 0.0),
		_sub("tank_heavy", 3, 1.5, 3.0),
	]))
	# Wave 3 — shielders and healers
	waves.append(_make_wave(3, false, [
		_sub("shielder_elite", 3, 1.5, 0.0),
		_sub("healer_support", 2, 2.0, 1.0),
		_sub("scout_armored", 6, 0.6, 5.0),
	]))
	# Wave 4 — heavy flyers + swarm
	waves.append(_make_wave(4, false, [
		_sub("flyer_heavy", 4, 1.0, 0.0),
		_sub("drone_swarm", 12, 0.25, 4.0),
	]))
	# Wave 5 — tanks with healer support
	waves.append(_make_wave(5, false, [
		_sub("tank_heavy", 5, 1.2, 0.0),
		_sub("healer_support", 3, 1.5, 2.0),
		_sub("drone_fast", 8, 0.4, 7.0),
	]))
	# Wave 6 — elite combo
	waves.append(_make_wave(6, false, [
		_sub("shielder_elite", 4, 1.2, 0.0),
		_sub("flyer_heavy", 4, 1.0, 3.0),
		_sub("healer_support", 3, 1.5, 6.0),
	]))
	# Wave 7 — pre-boss
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 5, 1.2, 0.0),
		_sub("shielder_elite", 3, 1.5, 3.0),
		_sub("flyer_heavy", 5, 0.8, 6.0),
		_sub("healer_support", 4, 1.2, 9.0),
	]))
	# Wave 8 — boss: everything at once
	waves.append(_make_wave(8, true, [
		_sub("tank_boss", 1, 1.0, 0.0),
		_sub("shielder_elite", 4, 1.2, 2.0),
		_sub("healer_support", 4, 1.2, 4.0),
		_sub("flyer_heavy", 5, 0.8, 7.0),
		_sub("scout_armored", 10, 0.4, 10.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 5-8: Final Approach (multi-entry, map_scale 3.0)
## 12 waves — endgame gauntlet, three entry paths, brutal difficulty.
# ---------------------------------------------------------------------------

static func _level_5_8() -> Array:
	var waves: Array = []

	# Wave 1 — scouts from all entries
	waves.append(_make_wave(1, false, [
		_sub("scout_armored", 5, 0.6, 0.0, 0),
		_sub("scout_armored", 5, 0.6, 0.3, 1),
		_sub("scout_armored", 5, 0.6, 0.6, 2),
	]))
	# Wave 2 — fast drones and tanks
	waves.append(_make_wave(2, false, [
		_sub("drone_fast", 8, 0.4, 0.0, 0),
		_sub("tank_heavy", 3, 1.5, 0.0, 1),
		_sub("drone_swarm", 10, 0.3, 2.0, 2),
	]))
	# Wave 3 — flyers and shielders
	waves.append(_make_wave(3, false, [
		_sub("flyer_heavy", 4, 1.0, 0.0, 0),
		_sub("shielder_elite", 3, 1.5, 0.0, 1),
		_sub("healer_support", 3, 1.5, 2.0, 2),
	]))
	# Wave 4 — heavy combined assault
	waves.append(_make_wave(4, false, [
		_sub("tank_heavy", 4, 1.2, 0.0, 0),
		_sub("flyer_light", 8, 0.5, 0.0, 1),
		_sub("scout_armored", 8, 0.5, 3.0, 2),
		_sub("healer_support", 2, 2.0, 5.0, 0),
	]))
	# Wave 5 — swarm rush
	waves.append(_make_wave(5, false, [
		_sub("drone_swarm", 14, 0.2, 0.0, 0),
		_sub("drone_swarm", 14, 0.2, 0.5, 1),
		_sub("drone_fast", 8, 0.4, 3.5, 2),
	]))
	# Wave 6 — elite escort
	waves.append(_make_wave(6, false, [
		_sub("shielder_elite", 4, 1.2, 0.0, 0),
		_sub("tank_heavy", 4, 1.2, 0.0, 1),
		_sub("healer_support", 4, 1.2, 2.0, 2),
		_sub("flyer_heavy", 4, 1.0, 5.0, 0),
	]))
	# Wave 7 — multi-tank
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 5, 1.2, 0.0, 0),
		_sub("tank_heavy", 5, 1.2, 0.5, 1),
		_sub("healer_support", 4, 1.2, 3.0, 2),
		_sub("scout_armored", 10, 0.4, 7.0, 0),
	]))
	# Wave 8 — flyer onslaught
	waves.append(_make_wave(8, false, [
		_sub("flyer_heavy", 6, 0.8, 0.0, 0),
		_sub("flyer_heavy", 6, 0.8, 0.0, 1),
		_sub("shielder_elite", 4, 1.2, 4.0, 2),
		_sub("healer_support", 3, 1.5, 7.0, 1),
	]))
	# Wave 9 — shielder wall
	waves.append(_make_wave(9, false, [
		_sub("shielder_elite", 5, 1.0, 0.0, 0),
		_sub("tank_heavy", 5, 1.2, 0.0, 1),
		_sub("flyer_heavy", 5, 0.8, 3.0, 2),
		_sub("healer_support", 4, 1.2, 5.0, 0),
	]))
	# Wave 10 — pre-boss storm
	waves.append(_make_wave(10, false, [
		_sub("tank_heavy", 6, 1.0, 0.0, 0),
		_sub("flyer_heavy", 6, 0.8, 0.0, 1),
		_sub("shielder_elite", 5, 1.0, 0.0, 2),
		_sub("healer_support", 4, 1.2, 5.0, 0),
		_sub("drone_swarm", 14, 0.2, 8.0, 1),
	]))
	# Wave 11 — mini-boss: dual tanks
	waves.append(_make_wave(11, false, [
		_sub("tank_boss", 1, 1.0, 0.0, 0),
		_sub("shielder_elite", 4, 1.2, 1.0, 1),
		_sub("healer_support", 4, 1.2, 2.0, 2),
		_sub("flyer_heavy", 6, 0.8, 5.0, 0),
		_sub("tank_heavy", 5, 1.2, 8.0, 1),
	]))
	# Wave 12 — final boss: all paths under siege
	waves.append(_make_wave(12, true, [
		_sub("tank_boss", 1, 1.0, 0.0, 0),
		_sub("tank_boss", 1, 1.0, 2.0, 1),
		_sub("shielder_elite", 4, 1.2, 3.0, 2),
		_sub("healer_support", 5, 1.0, 5.0, 0),
		_sub("flyer_heavy", 6, 0.8, 7.0, 1),
		_sub("scout_armored", 12, 0.35, 10.0, 2),
	]))

	return waves

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_wave(number: int, is_boss: bool, sub_waves: Array) -> WaveDefinition:
	var wd := WaveDefinition.new()
	wd.wave_number = number
	wd.is_boss_wave = is_boss
	wd.sub_waves = sub_waves
	return wd


static func _sub(enemy_id: String, count: int, interval: float, delay: float, p_path_index: int = 0) -> SubWaveDefinition:
	return SubWaveDefinition.new(enemy_id, count, interval, delay, p_path_index)
