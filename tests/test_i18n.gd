extends GutTest

## Tests for content/translations/ui.csv
## Verifies all required translation keys exist.
## Run in Godot editor with GUT addon installed.

## Load and parse the CSV directly since TranslationServer requires editor import.
var _keys: Array = []

func before_all() -> void:
	var file := FileAccess.open("res://content/translations/ui.csv", FileAccess.READ)
	if file == null:
		push_error("test_i18n: cannot open translations CSV")
		return
	# Skip header row
	file.get_line()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",", false, 1)
		if parts.size() >= 1:
			_keys.append(parts[0])
	file.close()

func _has_key(key: String) -> bool:
	return _keys.has(key)

# ---------------------------------------------------------------------------
# Required UI keys
# ---------------------------------------------------------------------------

func test_main_menu_keys() -> void:
	assert_true(_has_key("UI_PLAY_CAMPAIGN"))
	assert_true(_has_key("UI_ENDLESS_MODE"))
	assert_true(_has_key("UI_TOWER_LAB"))
	assert_true(_has_key("UI_SETTINGS"))
	assert_true(_has_key("UI_MAIN_MENU"))
	assert_true(_has_key("UI_DIAMOND_SHOP"))

func test_common_ui_keys() -> void:
	assert_true(_has_key("UI_BACK"))
	assert_true(_has_key("UI_CONFIRM"))
	assert_true(_has_key("UI_CANCEL"))
	assert_true(_has_key("UI_PAUSE"))
	assert_true(_has_key("UI_RESUME"))
	assert_true(_has_key("UI_RESTART"))
	assert_true(_has_key("UI_QUIT_LEVEL"))

# ---------------------------------------------------------------------------
# Tower names
# ---------------------------------------------------------------------------

func test_tower_name_pulse_cannon() -> void:
	assert_true(_has_key("TOWER_PULSE_CANNON"))

func test_tower_name_arc_emitter() -> void:
	assert_true(_has_key("TOWER_ARC_EMITTER"))

func test_tower_name_cryo_array() -> void:
	assert_true(_has_key("TOWER_CRYO_ARRAY"))

func test_tower_name_missile_pod() -> void:
	assert_true(_has_key("TOWER_MISSILE_POD"))

func test_tower_name_beam_spire() -> void:
	assert_true(_has_key("TOWER_BEAM_SPIRE"))

func test_tower_name_nano_hive() -> void:
	assert_true(_has_key("TOWER_NANO_HIVE"))

func test_tower_name_harvester() -> void:
	assert_true(_has_key("TOWER_HARVESTER"))

func test_all_tower_types_have_translation() -> void:
	assert_eq(Enums.TowerType.size(), 7, "7 tower types defined")
	var tower_keys := ["TOWER_PULSE_CANNON", "TOWER_ARC_EMITTER", "TOWER_CRYO_ARRAY",
		"TOWER_MISSILE_POD", "TOWER_BEAM_SPIRE", "TOWER_NANO_HIVE", "TOWER_HARVESTER"]
	for key in tower_keys:
		assert_true(_has_key(key), "Missing translation: %s" % key)

# ---------------------------------------------------------------------------
# Difficulty names
# ---------------------------------------------------------------------------

func test_difficulty_names() -> void:
	assert_true(_has_key("DIFFICULTY_NORMAL"))
	assert_true(_has_key("DIFFICULTY_HARD"))
	assert_true(_has_key("DIFFICULTY_NIGHTMARE"))

# ---------------------------------------------------------------------------
# HUD keys
# ---------------------------------------------------------------------------

func test_hud_keys() -> void:
	assert_true(_has_key("HUD_WAVE_COMPLETE"))
	assert_true(_has_key("HUD_BUILDING_PHASE"))
	assert_true(_has_key("HUD_PREPARE"))
	assert_true(_has_key("HUD_INCOMING"))

# ---------------------------------------------------------------------------
# Enemy names
# ---------------------------------------------------------------------------

func test_enemy_names() -> void:
	assert_true(_has_key("ENEMY_SCOUT"))
	assert_true(_has_key("ENEMY_DRONE"))
	assert_true(_has_key("ENEMY_TANK"))
	assert_true(_has_key("ENEMY_FLYER"))
	assert_true(_has_key("ENEMY_SHIELDER"))
	assert_true(_has_key("ENEMY_HEALER"))

func test_all_enemy_archetypes_have_translation() -> void:
	assert_eq(Enums.EnemyArchetype.size(), 6, "6 enemy archetypes defined")
	var enemy_keys := ["ENEMY_SCOUT", "ENEMY_DRONE", "ENEMY_TANK",
		"ENEMY_FLYER", "ENEMY_SHIELDER", "ENEMY_HEALER"]
	for key in enemy_keys:
		assert_true(_has_key(key), "Missing translation: %s" % key)

# ---------------------------------------------------------------------------
# Star rating
# ---------------------------------------------------------------------------

func test_star_rating_keys() -> void:
	assert_true(_has_key("STAR_RATING_1"))
	assert_true(_has_key("STAR_RATING_2"))
	assert_true(_has_key("STAR_RATING_3"))

# ---------------------------------------------------------------------------
# Ability names
# ---------------------------------------------------------------------------

func test_ability_names() -> void:
	assert_true(_has_key("ABILITY_ORBITAL_STRIKE"))
	assert_true(_has_key("ABILITY_EMP_BURST"))
	assert_true(_has_key("ABILITY_REPAIR_WAVE"))
	assert_true(_has_key("ABILITY_SHIELD_MATRIX"))
	assert_true(_has_key("ABILITY_OVERCLOCK"))
	assert_true(_has_key("ABILITY_SCRAP_SALVAGE"))

func test_all_ability_types_have_translation() -> void:
	assert_eq(Enums.AbilityType.size(), 6, "6 ability types defined")
	var ability_keys := ["ABILITY_ORBITAL_STRIKE", "ABILITY_EMP_BURST", "ABILITY_REPAIR_WAVE",
		"ABILITY_SHIELD_MATRIX", "ABILITY_OVERCLOCK", "ABILITY_SCRAP_SALVAGE"]
	for key in ability_keys:
		assert_true(_has_key(key), "Missing translation: %s" % key)

# ---------------------------------------------------------------------------
# Translation count sanity
# ---------------------------------------------------------------------------

func test_minimum_key_count() -> void:
	assert_gt(_keys.size(), 50, "Should have at least 50 translation keys")

func test_no_duplicate_keys() -> void:
	var seen := {}
	var has_dupe := false
	for key in _keys:
		if seen.has(key):
			has_dupe = true
			push_warning("Duplicate translation key: %s" % key)
		seen[key] = true
	assert_false(has_dupe, "No duplicate translation keys should exist")
