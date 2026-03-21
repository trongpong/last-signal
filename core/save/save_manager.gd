class_name SaveManager
extends Node

## Singleton managing persistent game data via JSON save files.
## Includes backup rotation, forward-compatible deep merge, and level completion tracking.
## Registered as an autoload in project.godot.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal game_saved(path: String)
signal game_loaded(path: String)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

const MAX_BACKUPS: int = 3
var save_path: String = "user://last_signal_save.json"

# ---------------------------------------------------------------------------
# In-memory save data
# ---------------------------------------------------------------------------

var _data: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = get_default_save_data()

# ---------------------------------------------------------------------------
# Default Save Structure
# ---------------------------------------------------------------------------

## Returns a fresh save file structure with all expected keys.
## Used for new saves and deep-merged with loaded data for forward compatibility.
func get_default_save_data() -> Dictionary:
	return {
		"version": 1,
		"profile": {
			"language": "en",
			"settings": {
				"music_volume": 1.0,
				"sfx_volume": 1.0,
				"show_damage_numbers": true,
				"show_range_on_hover": true
			}
		},
		"campaign": {
			"current_region": "region_01",
			"levels_completed": {},
			"endless_unlocked": false
		},
		"economy": {
			"diamonds": 0,
			"diamond_doubler": false,
			"total_diamonds_earned": 0
		},
		"progression": {
			"towers_unlocked": [
				"PULSE_CANNON",
				"ARC_EMITTER",
				"CRYO_ARRAY",
				"MISSILE_POD"
			],
			"skill_trees": {},
			"global_upgrades": {},
			"abilities_unlocked": [],
			"abilities_upgrade_levels": {},
			"heroes_unlocked": []
		},
		"endless": {
			"high_scores": {}
		},
		"stats": {
			"total_waves_survived": 0,
			"total_enemies_killed": 0,
			"total_gold_earned": 0,
			"total_play_time_seconds": 0
		},
		"monetization": {
			"ads_watched_today": 0,
			"ads_last_reset_date": "",
			"no_ads_purchased": false
		}
	}

# ---------------------------------------------------------------------------
# Data Accessors
# ---------------------------------------------------------------------------

## Returns a copy of the current in-memory save data.
func get_data() -> Dictionary:
	return _data.duplicate(true)

## Direct access to a top-level section for reading.
func get_section(section: String) -> Dictionary:
	if _data.has(section):
		return _data[section].duplicate(true)
	return {}

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

## Saves current _data to disk with backup rotation.
func save_game() -> void:
	_rotate_backups()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing: %s" % save_path)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	game_saved.emit(save_path)

## Rotates existing backup files (max MAX_BACKUPS).
func _rotate_backups() -> void:
	# Shift backup_2 -> backup_3, backup_1 -> backup_2, current -> backup_1
	var base := save_path.get_basename()
	var ext := save_path.get_extension()

	# Remove oldest backup if it exists
	var oldest := "%s_backup_%d.%s" % [base, MAX_BACKUPS, ext]
	if FileAccess.file_exists(oldest):
		DirAccess.remove_absolute(oldest)

	# Shift existing backups up
	for i in range(MAX_BACKUPS - 1, 0, -1):
		var src := "%s_backup_%d.%s" % [base, i, ext]
		var dst := "%s_backup_%d.%s" % [base, i + 1, ext]
		if FileAccess.file_exists(src):
			DirAccess.rename_absolute(src, dst)

	# Copy current save to backup_1
	if FileAccess.file_exists(save_path):
		var src_file := FileAccess.open(save_path, FileAccess.READ)
		if src_file != null:
			var content := src_file.get_as_text()
			src_file.close()
			var backup_1 := "%s_backup_1.%s" % [base, ext]
			var dst_file := FileAccess.open(backup_1, FileAccess.WRITE)
			if dst_file != null:
				dst_file.store_string(content)
				dst_file.close()

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

## Loads save data from disk. Deep-merges with defaults for forward compatibility.
## Returns true on success, false on failure (fresh default data is used).
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		_data = get_default_save_data()
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file for reading: %s" % save_path)
		_data = get_default_save_data()
		return false

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("SaveManager: JSON parse error in save file: %s" % json.get_error_message())
		_data = get_default_save_data()
		return false

	var loaded: Dictionary = json.get_data()
	_data = _deep_merge(get_default_save_data(), loaded)
	game_loaded.emit(save_path)
	return true

## Deep-merges src into dst (dst is the defaults, src is the loaded data).
## Keys in src override dst; keys in dst missing from src are preserved.
func _deep_merge(dst: Dictionary, src: Dictionary) -> Dictionary:
	var result := dst.duplicate(true)
	for key in src.keys():
		if result.has(key) and result[key] is Dictionary and src[key] is Dictionary:
			result[key] = _deep_merge(result[key], src[key])
		else:
			result[key] = src[key]
	return result

# ---------------------------------------------------------------------------
# Level Completion
# ---------------------------------------------------------------------------

## Records level completion, keeping the best stars and best difficulty seen.
## difficulty is an Enums.Difficulty int.
func set_level_complete(level_id: String, stars: int, difficulty: int) -> void:
	var levels: Dictionary = _data["campaign"]["levels_completed"]
	if not levels.has(level_id):
		levels[level_id] = {
			"best_stars": stars,
			"best_difficulty": difficulty,
			"completed": true
		}
	else:
		var existing: Dictionary = levels[level_id]
		if stars > existing.get("best_stars", 0):
			existing["best_stars"] = stars
		if difficulty > existing.get("best_difficulty", 0):
			existing["best_difficulty"] = difficulty
		existing["completed"] = true

## Returns the completion record for a level, or empty dict if not completed.
func get_level_record(level_id: String) -> Dictionary:
	var levels: Dictionary = _data["campaign"]["levels_completed"]
	return levels.get(level_id, {}).duplicate(true)

# ---------------------------------------------------------------------------
# Convenience setters (sync from runtime managers)
# ---------------------------------------------------------------------------

## Syncs diamond economy data from EconomyManager into save data.
func sync_economy(economy_manager: EconomyManager) -> void:
	_data["economy"]["diamonds"] = economy_manager.diamonds
	_data["economy"]["diamond_doubler"] = economy_manager.diamond_doubler
	_data["economy"]["total_diamonds_earned"] = economy_manager.total_diamonds_earned

## Applies saved economy data into an EconomyManager instance.
func apply_economy(economy_manager: EconomyManager) -> void:
	var eco: Dictionary = _data.get("economy", {})
	economy_manager.diamonds = eco.get("diamonds", 0)
	economy_manager.diamond_doubler = eco.get("diamond_doubler", false)
	economy_manager.total_diamonds_earned = eco.get("total_diamonds_earned", 0)
