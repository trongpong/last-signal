extends GutTest

## Tests for core/campaign/level_registry.gd

var registry: LevelRegistry

func before_each() -> void:
	registry = LevelRegistry.new()
	registry.register_levels()

# ---------------------------------------------------------------------------
# Total counts
# ---------------------------------------------------------------------------

func test_total_level_count() -> void:
	# 10+10+9+9+8 = 46
	assert_eq(registry.get_total_level_count(), 46)

func test_region_count() -> void:
	assert_eq(registry.get_region_count(), 5)

# ---------------------------------------------------------------------------
# Region level counts
# ---------------------------------------------------------------------------

func test_region_1_has_ten_levels() -> void:
	assert_eq(registry.get_levels_for_region(1).size(), 10)

func test_region_2_has_ten_levels() -> void:
	assert_eq(registry.get_levels_for_region(2).size(), 10)

func test_region_3_has_nine_levels() -> void:
	assert_eq(registry.get_levels_for_region(3).size(), 9)

func test_region_4_has_nine_levels() -> void:
	assert_eq(registry.get_levels_for_region(4).size(), 9)

func test_region_5_has_eight_levels() -> void:
	assert_eq(registry.get_levels_for_region(5).size(), 8)

# ---------------------------------------------------------------------------
# Level dict contents
# ---------------------------------------------------------------------------

func test_first_level_id() -> void:
	var lvl := registry.get_level("1_1")
	assert_eq(lvl["id"], "1_1")

func test_first_level_region() -> void:
	var lvl := registry.get_level("1_1")
	assert_eq(lvl["region"], 1)

func test_first_level_not_boss() -> void:
	var lvl := registry.get_level("1_1")
	assert_false(lvl["is_boss_level"])

func test_region1_last_level_is_boss() -> void:
	var lvl := registry.get_level("1_10")
	assert_true(lvl["is_boss_level"])

func test_region5_last_level_has_final_boss() -> void:
	var lvl := registry.get_level("5_8")
	assert_true(lvl["has_final_boss"])

func test_non_final_level_has_no_final_boss() -> void:
	var lvl := registry.get_level("1_10")
	assert_false(lvl["has_final_boss"])

func test_region1_wave_count() -> void:
	var lvl := registry.get_level("1_1")
	assert_eq(lvl["wave_count"], 15)

func test_region5_wave_count() -> void:
	var lvl := registry.get_level("5_1")
	assert_eq(lvl["wave_count"], 28)

func test_region1_map_mode_fixed_path() -> void:
	var lvl := registry.get_level("1_1")
	assert_eq(lvl["map_mode"], Enums.MapMode.FIXED_PATH)

func test_region2_map_mode_grid_maze() -> void:
	var lvl := registry.get_level("2_1")
	assert_eq(lvl["map_mode"], Enums.MapMode.GRID_MAZE)

# ---------------------------------------------------------------------------
# Tower unlocks
# ---------------------------------------------------------------------------

func test_region2_unlocks_beam_spire() -> void:
	assert_eq(registry.get_tower_unlock_for_region(2), "beam_spire")

func test_region3_unlocks_nano_hive() -> void:
	assert_eq(registry.get_tower_unlock_for_region(3), "nano_hive")

func test_region4_unlocks_harvester() -> void:
	assert_eq(registry.get_tower_unlock_for_region(4), "harvester")

func test_region5_no_tower_unlock() -> void:
	assert_eq(registry.get_tower_unlock_for_region(5), "")

func test_region1_no_tower_unlock() -> void:
	assert_eq(registry.get_tower_unlock_for_region(1), "")

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_get_level_unknown_returns_empty() -> void:
	assert_true(registry.get_level("99_99").is_empty())

func test_get_levels_for_unknown_region() -> void:
	assert_eq(registry.get_levels_for_region(99).size(), 0)

# ---------------------------------------------------------------------------
# map_scale and path_type (map variety system)
# ---------------------------------------------------------------------------

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
