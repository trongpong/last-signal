class_name CampaignManager
extends Node

## Manages campaign progression: level unlocks, region clears, tower unlocks,
## and the transition to endless mode.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal level_unlocked(level_id: String)
signal region_unlocked(region: int)
signal tower_unlocked(tower_id: String)
signal endless_unlocked

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Tower IDs available from the very start of the campaign (uppercase-normalised).
const STARTING_TOWERS: Array = [
	"PULSE_CANNON",
	"ARC_EMITTER",
	"CRYO_ARRAY",
	"MISSILE_POD",
]

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _save_manager = null
var _registry: LevelRegistry = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Inject a SaveManager and build the level registry.
## Call once before any other method.
func setup(sm) -> void:
	_save_manager = sm
	_registry = LevelRegistry.new()
	_registry.register_levels()

# ---------------------------------------------------------------------------
# Registry accessors
# ---------------------------------------------------------------------------

## Returns the total number of regions.
func get_region_count() -> int:
	if _registry == null:
		return 0
	return _registry.get_region_count()

## Returns the level definition dictionary for the given level_id, or empty dict.
func get_level(level_id: String) -> Dictionary:
	if _registry == null:
		return {}
	return _registry.get_level(level_id)

## Returns all level definitions across all regions.
func get_all_levels() -> Array:
	if _registry == null:
		return []
	var result: Array = []
	for region in range(1, _registry.get_region_count() + 1):
		result.append_array(_registry.get_levels_for_region(region))
	return result

# ---------------------------------------------------------------------------
# Level unlock queries
# ---------------------------------------------------------------------------

## Returns true if the player may attempt this level.
## The very first level of region 1 is always available.
## All others require the immediately-preceding level to be completed.
func is_level_unlocked(level_id: String) -> bool:
	if level_id == "1_1":
		return true
	if _registry == null:
		return false

	var level_def: Dictionary = _registry.get_level(level_id)
	if level_def.is_empty():
		return false

	var prev_id: String = _get_previous_level_id(level_def)
	if prev_id.is_empty():
		return false

	return _is_completed(prev_id)

# ---------------------------------------------------------------------------
# Level completion
# ---------------------------------------------------------------------------

## Called when a level finishes successfully.
## Records the result, checks for new unlocks, and emits the appropriate signals.
func on_level_complete(level_id: String, stars: int, difficulty: int) -> void:
	if _save_manager == null:
		push_warning("CampaignManager.on_level_complete: no SaveManager")
		return
	if _registry == null:
		push_warning("CampaignManager.on_level_complete: no LevelRegistry")
		return

	_save_manager.set_level_complete(level_id, stars, difficulty)

	var level_def: Dictionary = _registry.get_level(level_id)
	if level_def.is_empty():
		return

	# Check if the next level in sequence just became unlocked
	var next_id: String = _get_next_level_id(level_def)
	if not next_id.is_empty():
		level_unlocked.emit(next_id)

	# If this is a boss level (last in region), check tower unlock and region signal
	if level_def.get("is_boss_level", false):
		var region: int = level_def["region"] as int
		region_unlocked.emit(region)

		var tower_id: String = _registry.get_tower_unlock_for_region(region)
		if not tower_id.is_empty():
			# Normalise to uppercase — LevelRegistry returns lowercase IDs
			var tower_id_upper: String = tower_id.to_upper()
			# Record tower unlock in save data
			var towers: Array = _save_manager.data["progression"]["towers_unlocked"]
			if not towers.has(tower_id_upper):
				towers.append(tower_id_upper)
			tower_unlocked.emit(tower_id_upper)

	# If the final level is beaten, unlock endless mode
	if level_def.get("has_final_boss", false):
		_save_manager.data["campaign"]["endless_unlocked"] = true
		endless_unlocked.emit()

	_save_manager.save_game()

# ---------------------------------------------------------------------------
# Endless
# ---------------------------------------------------------------------------

## Returns true if the player has unlocked endless mode.
func is_endless_unlocked() -> bool:
	if _save_manager == null:
		return false
	return _save_manager.data["campaign"].get("endless_unlocked", false) as bool

# ---------------------------------------------------------------------------
# Current region
# ---------------------------------------------------------------------------

## Returns the region number of the most-recently-reached incomplete level,
## or 1 if no levels have been started yet.
func get_current_region() -> int:
	if _save_manager == null or _registry == null:
		return 1
	for region in range(1, _registry.get_region_count() + 1):
		var levels: Array = _registry.get_levels_for_region(region)
		for level_def in levels:
			var lid: String = level_def["id"] as String
			if not _is_completed(lid):
				return level_def["region"] as int
	return _registry.get_region_count()

# ---------------------------------------------------------------------------
# Unlocked towers
# ---------------------------------------------------------------------------

## Returns the Array of tower ID strings currently unlocked (upper-case keys).
func get_unlocked_towers() -> Array:
	if _save_manager == null:
		return STARTING_TOWERS.duplicate()
	return _save_manager.data["progression"]["towers_unlocked"].duplicate()

# ---------------------------------------------------------------------------
# Stars
# ---------------------------------------------------------------------------

## Returns the cumulative best-star count across all completed levels.
## Handles the per-difficulty save format where each record is a dict of dicts
## keyed by difficulty: { "0": { "best_stars": 3, "completed": true }, ... }
func get_total_stars() -> int:
	if _save_manager == null:
		return 0
	var completed: Dictionary = _save_manager.data["campaign"]["levels_completed"]
	var total: int = 0
	for record in completed.values():
		if record is Dictionary:
			# Legacy flat format: {"completed": true, "best_stars": 3}
			if record.has("best_stars"):
				total += record.get("best_stars", 0) as int
				continue
			var best: int = 0
			for diff_record in record.values():
				if diff_record is Dictionary:
					best = maxi(best, diff_record.get("best_stars", 0) as int)
			total += best
	return total

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns true if the given level_id has been completed on any difficulty.
func _is_completed(level_id: String) -> bool:
	if _save_manager == null:
		return false
	var record: Dictionary = _save_manager.get_level_record(level_id)
	return record.get("completed", false) as bool


## Returns the level_id of the level immediately before level_def in sequence.
## Returns "" if this is the first level overall.
func _get_previous_level_id(level_def: Dictionary) -> String:
	if _registry == null:
		return ""
	var region: int = level_def["region"] as int
	var number: int = level_def["level_number"] as int

	if number > 1:
		return "%d_%d" % [region, number - 1]

	# First level of this region — predecessor is the last level of the previous region
	if region == 1:
		return ""

	var prev_region_levels: Array = _registry.get_levels_for_region(region - 1)
	if prev_region_levels.is_empty():
		return ""
	var last: Dictionary = prev_region_levels[prev_region_levels.size() - 1] as Dictionary
	return last["id"] as String


## Returns the level_id of the level immediately after level_def in sequence.
## Returns "" if this is the final level overall.
func _get_next_level_id(level_def: Dictionary) -> String:
	if _registry == null:
		return ""
	var region: int = level_def["region"] as int
	var number: int = level_def["level_number"] as int
	var region_levels: Array = _registry.get_levels_for_region(region)

	if number < region_levels.size():
		return "%d_%d" % [region, number + 1]

	# Last level of this region — successor is the first level of the next region
	if region >= _registry.get_region_count():
		return ""

	var next_region_levels: Array = _registry.get_levels_for_region(region + 1)
	if next_region_levels.is_empty():
		return ""
	return (next_region_levels[0] as Dictionary)["id"] as String
