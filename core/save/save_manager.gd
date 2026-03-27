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

var data: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	data = get_default_save_data()

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
				"music_vol": 1.0,
				"sfx_vol": 1.0,
				"ui_vol": 1.0,
				"speed_pref": 1.0,
				"graphics": "medium",
				"show_damage_numbers": true,
				"show_range_on_hover": true,
				"colorblind_mode": false
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
			"heroes_unlocked": [],
			"synergies_discovered": []
		},
		"tower_mastery": {},
		"daily_challenges": {
			"last_completed_date": "",
			"streak": 0,
			"history": {}
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
		},
		"unlocks": {
			"speed_x2": false,
			"speed_x3": false
		}
	}

# ---------------------------------------------------------------------------
# Data Accessors
# ---------------------------------------------------------------------------

## Returns a copy of the current in-memory save data.
func get_data() -> Dictionary:
	return data.duplicate(true)

## Direct access to a top-level section for reading.
func get_section(section: String) -> Dictionary:
	if data.has(section):
		return data[section].duplicate(true)
	return {}

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

## Saves current data to disk with backup rotation.
func save_game() -> void:
	_rotate_backups()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing: %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
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
		data = get_default_save_data()
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file for reading: %s" % save_path)
		data = get_default_save_data()
		return false

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("SaveManager: JSON parse error in save file: %s" % json.get_error_message())
		data = get_default_save_data()
		return false

	var loaded: Dictionary = json.get_data()
	data = _deep_merge(get_default_save_data(), loaded)
	data = _validate_save_data(data)
	game_loaded.emit(save_path)
	return true

## Validates and sanitises loaded save data so downstream code can assume
## correct types and reasonable values.  Returns the cleaned dictionary.
func _validate_save_data(d: Dictionary) -> Dictionary:
	var defaults: Dictionary = get_default_save_data()

	# --- ensure key sections exist and are the right type ---
	for section in ["economy", "progression", "campaign"]:
		if not d.has(section) or not (d[section] is Dictionary):
			d[section] = defaults[section].duplicate(true)

	# Also ensure profile.settings exists when "settings" section lives there
	if d.has("profile"):
		if not (d["profile"] is Dictionary):
			d["profile"] = defaults["profile"].duplicate(true)
		elif not d["profile"].has("settings") or not (d["profile"]["settings"] is Dictionary):
			d["profile"]["settings"] = defaults["profile"]["settings"].duplicate(true)

	# --- economy value validation ---
	var eco: Dictionary = d["economy"]

	# diamonds must be int, not string or float
	if not (eco.get("diamonds") is int):
		var raw = eco.get("diamonds", 0)
		if raw is String and raw.is_valid_int():
			eco["diamonds"] = int(raw)
		elif raw is float:
			eco["diamonds"] = int(raw)
		else:
			eco["diamonds"] = 0

	# gold must be int (some save schemas include gold)
	if eco.has("gold"):
		if not (eco["gold"] is int):
			var raw = eco["gold"]
			if raw is String and raw.is_valid_int():
				eco["gold"] = int(raw)
			elif raw is float:
				eco["gold"] = int(raw)
			else:
				eco["gold"] = 0

	# clamp to >= 0
	eco["diamonds"] = maxi(eco["diamonds"] as int, 0)
	if eco.has("gold"):
		eco["gold"] = maxi(eco["gold"] as int, 0)

	return d

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
## Records completion per difficulty. Save structure:
## levels_completed[level_id][str(difficulty)] = { best_stars, completed }
func set_level_complete(level_id: String, stars: int, difficulty: int) -> void:
	var levels: Dictionary = data["campaign"]["levels_completed"]
	if not levels.has(level_id):
		levels[level_id] = {}
	var level_data: Dictionary = levels[level_id]
	var diff_key: String = str(difficulty)
	if not level_data.has(diff_key):
		level_data[diff_key] = {"best_stars": stars, "completed": true}
	else:
		var existing: Dictionary = level_data[diff_key]
		if stars > existing.get("best_stars", 0):
			existing["best_stars"] = stars
		existing["completed"] = true

## Returns the completion record for a level at a specific difficulty.
## Returns empty dict if not completed at that difficulty.
func get_level_record(level_id: String, difficulty: int = -1) -> Dictionary:
	var levels: Dictionary = data["campaign"]["levels_completed"]
	if not levels.has(level_id):
		return {}
	var level_data: Dictionary = levels[level_id]
	# If difficulty specified, return that difficulty's record
	if difficulty >= 0:
		var diff_key: String = str(difficulty)
		return (level_data.get(diff_key, {}) as Dictionary).duplicate(true)
	# If no difficulty specified, return best across all difficulties (backward compat)
	# Handle old flat format: level_data = { "completed": true, "best_stars": 3 }
	if level_data.has("completed"):
		return level_data.duplicate(true)
	# New per-difficulty format: level_data = { "0": {...}, "1": {...} }
	var best: Dictionary = {}
	for diff_key in level_data.keys():
		var val = level_data[diff_key]
		if not (val is Dictionary):
			continue
		var record: Dictionary = val as Dictionary
		if record.get("completed", false):
			if best.is_empty() or (record.get("best_stars", 0) as int) > (best.get("best_stars", 0) as int):
				best = record.duplicate(true)
	if not best.is_empty():
		best["completed"] = true
	return best

# ---------------------------------------------------------------------------
# Convenience setters (sync from runtime managers)
# ---------------------------------------------------------------------------

## Syncs diamond economy data from EconomyManager into save data.
func sync_economy(economy_manager) -> void:
	data["economy"]["diamonds"] = economy_manager.diamonds
	data["economy"]["diamond_doubler"] = economy_manager.diamond_doubler
	data["economy"]["total_diamonds_earned"] = economy_manager.total_diamonds_earned

## Applies saved economy data into an EconomyManager instance.
func apply_economy(economy_manager) -> void:
	var eco: Dictionary = data.get("economy", {})
	economy_manager.diamonds = eco.get("diamonds", 0)
	economy_manager.diamond_doubler = eco.get("diamond_doubler", false)
	economy_manager.total_diamonds_earned = eco.get("total_diamonds_earned", 0)

# ---------------------------------------------------------------------------
# Data Reset
# ---------------------------------------------------------------------------

## Resets campaign, progression, endless, daily challenges, and tower mastery
## to defaults. Preserves economy, stats, settings, monetization, and unlocks.
func reset_progress() -> void:
	var defaults := get_default_save_data()
	data["campaign"] = defaults["campaign"].duplicate(true)
	data["progression"] = defaults["progression"].duplicate(true)
	data["endless"] = defaults["endless"].duplicate(true)
	data["daily_challenges"] = defaults["daily_challenges"].duplicate(true)
	data["tower_mastery"] = defaults["tower_mastery"].duplicate(true)
	save_game()

## Resets stats to defaults. Preserves all other data.
func reset_stats() -> void:
	var defaults := get_default_save_data()
	data["stats"] = defaults["stats"].duplicate(true)
	save_game()

## Full factory reset — replaces all data with defaults.
func reset_all() -> void:
	data = get_default_save_data()
	save_game()
