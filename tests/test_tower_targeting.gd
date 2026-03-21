extends GutTest

## Tests for core/tower_system/tower_targeting.gd

var _targeting: TowerTargeting
const RANGE: float = 300.0
const TOWER_POS: Vector2 = Vector2(0.0, 0.0)

func before_each() -> void:
	_targeting = TowerTargeting.new()
	add_child(_targeting)

func after_each() -> void:
	_targeting.queue_free()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_enemy(pos: Vector2, hp: float, progress: float, alive: bool = true) -> Dictionary:
	return {
		"position": pos,
		"hp": hp,
		"progress": progress,
		"alive": alive
	}

# ---------------------------------------------------------------------------
# Empty / no valid target
# ---------------------------------------------------------------------------

func test_empty_list_returns_minus_one() -> void:
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, [])
	assert_eq(result, -1)

func test_all_dead_returns_minus_one() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.2, false),
		_make_enemy(Vector2(60, 0), 80.0, 0.4, false)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, -1)

func test_out_of_range_returns_minus_one() -> void:
	var enemies := [
		_make_enemy(Vector2(500, 0), 100.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, -1)

func test_dead_enemy_skipped_even_if_in_range() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.5, false),
		_make_enemy(Vector2(100, 0), 80.0, 0.3, true)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, 1)

# ---------------------------------------------------------------------------
# NEAREST
# ---------------------------------------------------------------------------

func test_nearest_picks_closest() -> void:
	var enemies := [
		_make_enemy(Vector2(200, 0), 50.0, 0.5),
		_make_enemy(Vector2(100, 0), 80.0, 0.3),
		_make_enemy(Vector2(150, 0), 60.0, 0.4)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, 1)

func test_nearest_single_valid_enemy() -> void:
	var enemies := [_make_enemy(Vector2(50, 0), 100.0, 0.1)]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, 0)

# ---------------------------------------------------------------------------
# STRONGEST
# ---------------------------------------------------------------------------

func test_strongest_picks_highest_hp() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 30.0, 0.1),
		_make_enemy(Vector2(60, 0), 150.0, 0.3),
		_make_enemy(Vector2(70, 0), 80.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.STRONGEST, enemies)
	assert_eq(result, 1)

func test_strongest_skips_dead() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 200.0, 0.1, false),
		_make_enemy(Vector2(60, 0), 80.0, 0.3, true)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.STRONGEST, enemies)
	assert_eq(result, 1)

# ---------------------------------------------------------------------------
# WEAKEST
# ---------------------------------------------------------------------------

func test_weakest_picks_lowest_hp() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.1),
		_make_enemy(Vector2(60, 0), 20.0, 0.3),
		_make_enemy(Vector2(70, 0), 60.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.WEAKEST, enemies)
	assert_eq(result, 1)

func test_weakest_skips_out_of_range() -> void:
	var enemies := [
		_make_enemy(Vector2(5, 0), 10.0, 0.1),   # very weak but in range -> should win
		_make_enemy(Vector2(600, 0), 1.0, 0.9)    # weakest but out of range
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.WEAKEST, enemies)
	assert_eq(result, 0)

# ---------------------------------------------------------------------------
# FIRST
# ---------------------------------------------------------------------------

func test_first_picks_highest_progress() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.2),
		_make_enemy(Vector2(60, 0), 80.0, 0.9),
		_make_enemy(Vector2(70, 0), 60.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.FIRST, enemies)
	assert_eq(result, 1)

func test_first_with_tied_progress_returns_some_valid() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.5),
		_make_enemy(Vector2(60, 0), 80.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.FIRST, enemies)
	assert_true(result == 0 or result == 1)

# ---------------------------------------------------------------------------
# LAST
# ---------------------------------------------------------------------------

func test_last_picks_lowest_progress() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.8),
		_make_enemy(Vector2(60, 0), 80.0, 0.1),
		_make_enemy(Vector2(70, 0), 60.0, 0.5)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.LAST, enemies)
	assert_eq(result, 1)

func test_last_skips_dead_enemies() -> void:
	var enemies := [
		_make_enemy(Vector2(50, 0), 100.0, 0.0, false),  # progress=0 but dead
		_make_enemy(Vector2(60, 0), 80.0, 0.3, true),
		_make_enemy(Vector2(70, 0), 60.0, 0.7, true)
	]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.LAST, enemies)
	assert_eq(result, 1)

# ---------------------------------------------------------------------------
# Range boundary
# ---------------------------------------------------------------------------

func test_enemy_exactly_at_range_is_valid() -> void:
	var enemies := [_make_enemy(Vector2(RANGE, 0), 100.0, 0.5)]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, 0)

func test_enemy_just_outside_range_is_invalid() -> void:
	var enemies := [_make_enemy(Vector2(RANGE + 1.0, 0), 100.0, 0.5)]
	var result := _targeting.select_target(TOWER_POS, RANGE, Enums.TargetingMode.NEAREST, enemies)
	assert_eq(result, -1)
