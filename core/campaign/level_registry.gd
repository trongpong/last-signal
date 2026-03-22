class_name LevelRegistry
extends RefCounted

## Registry of all campaign levels, organised by region.
## Call register_levels() once after construction to populate.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Maps region number → tower_id unlocked upon completing that region's boss.
## Empty string means no additional tower unlocked.
const REGION_TOWER_UNLOCKS: Dictionary = {
	2: "beam_spire",
	3: "nano_hive",
	4: "harvester",
	5: "",
}

# ---------------------------------------------------------------------------
# Private storage
# ---------------------------------------------------------------------------

var _levels: Dictionary = {}       # level_id → level dict
var _regions: Dictionary = {}      # region_number → Array[level_id]

# ---------------------------------------------------------------------------
# Population
# ---------------------------------------------------------------------------

## Creates all 46 campaign levels across 5 regions.
func register_levels() -> void:
	_levels = {}
	_regions = {}

	var region_defs: Array = [
		# [region, region_name, level_count, map_mode, wave_count]
		[1, "Outer Perimeter",  10, Enums.MapMode.FIXED_PATH, 15],
		[2, "Uplink Corridor",  10, Enums.MapMode.GRID_MAZE,  18],
		[3, "Resonance Fields", 9,  Enums.MapMode.FIXED_PATH, 22],
		[4, "Core Approach",    9,  Enums.MapMode.FIXED_PATH, 25],
		[5, "Signal Heart",     8,  Enums.MapMode.GRID_MAZE,  28],
	]

	for region_def in region_defs:
		var region: int = region_def[0] as int
		var region_name: String = region_def[1] as String
		var level_count: int = region_def[2] as int
		var map_mode: int = region_def[3] as int
		var wave_count: int = region_def[4] as int

		var ids: Array = []
		for n in range(1, level_count + 1):
			var level_id: String = "%d_%d" % [region, n]
			var is_boss: bool = (n == level_count)
			var has_final: bool = (region == 5 and is_boss)

			var level_dict: Dictionary = {
				"id": level_id,
				"region": region,
				"region_name": region_name,
				"display_name": "%s %d" % [region_name, n],
				"level_number": n,
				"map_mode": map_mode,
				"wave_count": wave_count,
				"is_boss_level": is_boss,
				"has_final_boss": has_final,
				"map_scale": 1.0 + float(region - 1) * 0.5,
				"path_type": _get_path_type(level_id, region, map_mode),
			}
			_levels[level_id] = level_dict
			ids.append(level_id)

		_regions[region] = ids

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Total number of regions.
func get_region_count() -> int:
	return _regions.size()

## Array of level dicts for a given region number (1-based).
func get_levels_for_region(region: int) -> Array:
	if not _regions.has(region):
		return []
	var result: Array = []
	for id in _regions[region]:
		result.append(_levels[id].duplicate(true))
	return result

## Returns a copy of the level dict for the given id, or empty dict.
func get_level(level_id: String) -> Dictionary:
	if _levels.has(level_id):
		return _levels[level_id].duplicate(true)
	return {}

## Total number of registered levels across all regions.
func get_total_level_count() -> int:
	return _levels.size()

## Returns the tower_id unlocked by completing a region, or "" if none.
func get_tower_unlock_for_region(region: int) -> String:
	return REGION_TOWER_UNLOCKS.get(region, "") as String

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Determines the path_type for a level based on milestone overrides, map_mode,
## and procedural selection by region.
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
