extends GutTest

## Tests for core/save/save_manager.gd
## Run in Godot editor with GUT addon installed.

var sm

func before_each() -> void:
	sm = load("res://core/save/save_manager.gd").new()
	# Use a temp path so tests don't pollute real saves
	sm.save_path = "user://test_save_temp.json"
	add_child(sm)

func after_each() -> void:
	# Clean up test save file
	if FileAccess.file_exists(sm.save_path):
		DirAccess.remove_absolute(sm.save_path)
	sm.queue_free()

# ---------------------------------------------------------------------------
# Default save structure
# ---------------------------------------------------------------------------

func test_default_save_has_profile() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("profile"))

func test_default_save_has_campaign() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("campaign"))

func test_default_save_has_economy() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("economy"))

func test_default_save_has_progression() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("progression"))

func test_default_save_has_endless() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("endless"))

func test_default_save_has_stats() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("stats"))

func test_default_save_has_monetization() -> void:
	var data := sm.get_default_save_data()
	assert_true(data.has("monetization"))

func test_default_towers_unlocked_has_four_starters() -> void:
	var data := sm.get_default_save_data()
	var towers: Array = data["progression"]["towers_unlocked"]
	assert_eq(towers.size(), 4, "Should start with 4 unlocked towers")

func test_default_starters_are_correct() -> void:
	var data := sm.get_default_save_data()
	var towers: Array = data["progression"]["towers_unlocked"]
	assert_true(towers.has("PULSE_CANNON"))
	assert_true(towers.has("ARC_EMITTER"))
	assert_true(towers.has("CRYO_ARRAY"))
	assert_true(towers.has("MISSILE_POD"))

func test_default_diamonds_zero() -> void:
	var data := sm.get_default_save_data()
	assert_eq(data["economy"]["diamonds"], 0)

func test_default_diamond_doubler_false() -> void:
	var data := sm.get_default_save_data()
	assert_false(data["economy"]["diamond_doubler"])

func test_default_language_english() -> void:
	var data := sm.get_default_save_data()
	assert_eq(data["profile"]["language"], "en")

# ---------------------------------------------------------------------------
# Save and load round-trip
# ---------------------------------------------------------------------------

func test_save_creates_file() -> void:
	sm.save_game()
	assert_true(FileAccess.file_exists(sm.save_path))

func test_save_emits_signal() -> void:
	watch_signals(sm)
	sm.save_game()
	assert_signal_emitted(sm, "game_saved")

func test_load_emits_signal() -> void:
	sm.save_game()
	watch_signals(sm)
	sm.load_game()
	assert_signal_emitted(sm, "game_loaded")

func test_load_returns_false_when_no_file() -> void:
	var result := sm.load_game()
	assert_false(result)

func test_load_returns_true_when_file_exists() -> void:
	sm.save_game()
	var result := sm.load_game()
	assert_true(result)

func test_round_trip_preserves_language() -> void:
	sm.data["profile"]["language"] = "fr"
	sm.save_game()
	var sm2 := load("res://core/save/save_manager.gd").new()
	sm2.save_path = sm.save_path
	add_child(sm2)
	sm2.load_game()
	assert_eq(sm2._data["profile"]["language"], "fr")
	sm2.queue_free()

# ---------------------------------------------------------------------------
# Deep merge (forward compatibility)
# ---------------------------------------------------------------------------

func test_deep_merge_adds_missing_keys() -> void:
	var dst := {"a": 1, "b": {"c": 2, "d": 3}}
	var src := {"a": 99, "b": {"c": 50}}
	var result := sm._deep_merge(dst, src)
	assert_eq(result["a"], 99, "src value should override dst")
	assert_eq(result["b"]["c"], 50, "nested src value should override")
	assert_eq(result["b"]["d"], 3, "key only in dst should be preserved")

func test_deep_merge_nested_new_key_from_src() -> void:
	var dst := {"a": {}}
	var src := {"a": {"new_key": 42}}
	var result := sm._deep_merge(dst, src)
	assert_eq(result["a"]["new_key"], 42)

# ---------------------------------------------------------------------------
# Level completion
# ---------------------------------------------------------------------------

func test_set_level_complete_records_entry() -> void:
	sm.set_level_complete("level_01", 3, Enums.Difficulty.NORMAL)
	var record := sm.get_level_record("level_01")
	assert_false(record.is_empty())

func test_set_level_complete_stores_stars() -> void:
	sm.set_level_complete("level_01", 2, Enums.Difficulty.NORMAL)
	var record := sm.get_level_record("level_01")
	assert_eq(record["best_stars"], 2)

func test_set_level_complete_keeps_best_stars() -> void:
	sm.set_level_complete("level_01", 1, Enums.Difficulty.NORMAL)
	sm.set_level_complete("level_01", 3, Enums.Difficulty.NORMAL)
	sm.set_level_complete("level_01", 2, Enums.Difficulty.NORMAL)
	var record := sm.get_level_record("level_01")
	assert_eq(record["best_stars"], 3, "Should keep highest stars achieved")

func test_set_level_complete_keeps_best_difficulty() -> void:
	sm.set_level_complete("level_01", 1, Enums.Difficulty.NORMAL)
	sm.set_level_complete("level_01", 1, Enums.Difficulty.NIGHTMARE)
	var record := sm.get_level_record("level_01")
	assert_eq(record["best_difficulty"], Enums.Difficulty.NIGHTMARE,
		"Should keep highest difficulty achieved")

func test_get_level_record_returns_empty_for_unknown() -> void:
	var record := sm.get_level_record("nonexistent_level")
	assert_true(record.is_empty())

func test_completed_flag_set() -> void:
	sm.set_level_complete("level_01", 2, Enums.Difficulty.HARD)
	var record := sm.get_level_record("level_01")
	assert_true(record["completed"])

# ---------------------------------------------------------------------------
# Economy sync
# ---------------------------------------------------------------------------

func test_sync_economy_stores_diamonds() -> void:
	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	eco.add_diamonds(500)
	sm.sync_economy(eco)
	assert_eq(sm.data["economy"]["diamonds"], 500)
	eco.queue_free()

func test_apply_economy_sets_diamonds() -> void:
	sm.data["economy"]["diamonds"] = 250
	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	sm.apply_economy(eco)
	assert_eq(eco.diamonds, 250)
	eco.queue_free()

func test_apply_economy_sets_diamond_doubler() -> void:
	sm.data["economy"]["diamond_doubler"] = true
	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	sm.apply_economy(eco)
	assert_true(eco.diamond_doubler)
	eco.queue_free()
