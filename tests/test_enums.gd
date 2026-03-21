extends GutTest

## Tests for shared/enums.gd
## Run in Godot editor with GUT addon installed.

func test_difficulty_values() -> void:
	assert_eq(Enums.Difficulty.NORMAL, 0, "NORMAL should be 0")
	assert_eq(Enums.Difficulty.HARD, 1, "HARD should be 1")
	assert_eq(Enums.Difficulty.NIGHTMARE, 2, "NIGHTMARE should be 2")

func test_difficulty_count() -> void:
	assert_eq(Enums.Difficulty.size(), 3, "Difficulty should have 3 values")

func test_map_mode_values() -> void:
	assert_eq(Enums.MapMode.FIXED_PATH, 0)
	assert_eq(Enums.MapMode.GRID_MAZE, 1)

func test_tower_type_count() -> void:
	assert_eq(Enums.TowerType.size(), 7, "TowerType should have 7 values")

func test_tower_types_exist() -> void:
	assert_true(Enums.TowerType.has("PULSE_CANNON"))
	assert_true(Enums.TowerType.has("ARC_EMITTER"))
	assert_true(Enums.TowerType.has("CRYO_ARRAY"))
	assert_true(Enums.TowerType.has("MISSILE_POD"))
	assert_true(Enums.TowerType.has("BEAM_SPIRE"))
	assert_true(Enums.TowerType.has("NANO_HIVE"))
	assert_true(Enums.TowerType.has("HARVESTER"))

func test_enemy_archetype_count() -> void:
	assert_eq(Enums.EnemyArchetype.size(), 6, "EnemyArchetype should have 6 values")

func test_enemy_archetypes_exist() -> void:
	assert_true(Enums.EnemyArchetype.has("SCOUT"))
	assert_true(Enums.EnemyArchetype.has("DRONE"))
	assert_true(Enums.EnemyArchetype.has("TANK"))
	assert_true(Enums.EnemyArchetype.has("FLYER"))
	assert_true(Enums.EnemyArchetype.has("SHIELDER"))
	assert_true(Enums.EnemyArchetype.has("HEALER"))

func test_targeting_mode_count() -> void:
	assert_eq(Enums.TargetingMode.size(), 5)

func test_game_state_values() -> void:
	assert_true(Enums.GameState.has("MENU"))
	assert_true(Enums.GameState.has("BUILDING"))
	assert_true(Enums.GameState.has("WAVE_ACTIVE"))
	assert_true(Enums.GameState.has("WAVE_COMPLETE"))
	assert_true(Enums.GameState.has("VICTORY"))
	assert_true(Enums.GameState.has("DEFEAT"))
	assert_true(Enums.GameState.has("PAUSED"))

func test_damage_type_count() -> void:
	assert_eq(Enums.DamageType.size(), 7, "DamageType should have 7 values")

func test_damage_types_match_tower_types() -> void:
	# Each tower type maps to a damage type
	assert_eq(Enums.DamageType.size(), Enums.TowerType.size(),
		"DamageType count should match TowerType count")

func test_ability_type_count() -> void:
	assert_eq(Enums.AbilityType.size(), 6, "AbilityType should have 6 values")

func test_ability_types_exist() -> void:
	assert_true(Enums.AbilityType.has("ORBITAL_STRIKE"))
	assert_true(Enums.AbilityType.has("EMP_BURST"))
	assert_true(Enums.AbilityType.has("REPAIR_WAVE"))
	assert_true(Enums.AbilityType.has("SHIELD_MATRIX"))
	assert_true(Enums.AbilityType.has("OVERCLOCK"))
	assert_true(Enums.AbilityType.has("SCRAP_SALVAGE"))
