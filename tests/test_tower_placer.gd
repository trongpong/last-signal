extends GutTest

## Tests for core/tower_system/tower_placer.gd

var _placer: TowerPlacer

func before_each() -> void:
	_placer = TowerPlacer.new()
	add_child(_placer)

func after_each() -> void:
	_placer.queue_free()

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_snap_distance_is_40() -> void:
	assert_almost_eq(TowerPlacer.SNAP_DISTANCE, 40.0, 0.001)

func test_invalid_spot_is_minus_one_minus_one() -> void:
	assert_eq(TowerPlacer.INVALID_SPOT, Vector2(-1.0, -1.0))

# ---------------------------------------------------------------------------
# set_build_spots
# ---------------------------------------------------------------------------

func test_set_build_spots_clears_previous() -> void:
	_placer.set_build_spots([Vector2(100, 100)])
	_placer.set_build_spots([Vector2(200, 200), Vector2(300, 300)])
	assert_eq(_placer._spots.size(), 2)

func test_set_build_spots_initializes_unoccupied() -> void:
	_placer.set_build_spots([Vector2(100, 100), Vector2(200, 200)])
	assert_false(_placer.is_occupied(Vector2(100, 100)))
	assert_false(_placer.is_occupied(Vector2(200, 200)))

# ---------------------------------------------------------------------------
# get_nearest_build_spot
# ---------------------------------------------------------------------------

func test_returns_nearest_spot_within_range() -> void:
	_placer.set_build_spots([Vector2(100, 0), Vector2(200, 0)])
	var result := _placer.get_nearest_build_spot(Vector2(95, 0))
	assert_eq(result, Vector2(100, 0))

func test_returns_invalid_when_no_spots() -> void:
	_placer.set_build_spots([])
	var result := _placer.get_nearest_build_spot(Vector2(0, 0))
	assert_eq(result, TowerPlacer.INVALID_SPOT)

func test_returns_invalid_when_all_out_of_range() -> void:
	_placer.set_build_spots([Vector2(500, 0)])
	var result := _placer.get_nearest_build_spot(Vector2(0, 0))
	assert_eq(result, TowerPlacer.INVALID_SPOT)

func test_returns_invalid_when_nearest_occupied() -> void:
	_placer.set_build_spots([Vector2(100, 0)])
	_placer.mark_occupied(Vector2(100, 0))
	var result := _placer.get_nearest_build_spot(Vector2(100, 0))
	assert_eq(result, TowerPlacer.INVALID_SPOT)

func test_returns_second_spot_when_nearest_occupied() -> void:
	_placer.set_build_spots([Vector2(100, 0), Vector2(120, 0)])
	_placer.mark_occupied(Vector2(100, 0))
	var result := _placer.get_nearest_build_spot(Vector2(105, 0))
	assert_eq(result, Vector2(120, 0))

func test_spot_exactly_at_snap_distance_is_valid() -> void:
	_placer.set_build_spots([Vector2(40, 0)])
	var result := _placer.get_nearest_build_spot(Vector2(0, 0))
	assert_eq(result, Vector2(40, 0))

func test_spot_just_outside_snap_distance_is_invalid() -> void:
	_placer.set_build_spots([Vector2(41, 0)])
	var result := _placer.get_nearest_build_spot(Vector2(0, 0))
	assert_eq(result, TowerPlacer.INVALID_SPOT)

# ---------------------------------------------------------------------------
# Occupancy
# ---------------------------------------------------------------------------

func test_mark_occupied_sets_occupied() -> void:
	_placer.set_build_spots([Vector2(100, 0)])
	_placer.mark_occupied(Vector2(100, 0))
	assert_true(_placer.is_occupied(Vector2(100, 0)))

func test_mark_free_clears_occupied() -> void:
	_placer.set_build_spots([Vector2(100, 0)])
	_placer.mark_occupied(Vector2(100, 0))
	_placer.mark_free(Vector2(100, 0))
	assert_false(_placer.is_occupied(Vector2(100, 0)))

func test_is_occupied_false_for_unknown_spot() -> void:
	assert_false(_placer.is_occupied(Vector2(999, 999)))

func test_mark_occupied_unknown_spot_does_not_crash() -> void:
	_placer.mark_occupied(Vector2(999, 999))
	assert_true(true)  # no crash

# ---------------------------------------------------------------------------
# calculate_sell_value
# ---------------------------------------------------------------------------

func test_sell_value_base_no_upgrades() -> void:
	# BASE_SELL_REFUND = 0.7, tier 0 → 0.7 * 100 = 70
	var result := _placer.calculate_sell_value(100, 0)
	assert_eq(result, 70)

func test_sell_value_tier1_upgrade() -> void:
	# 0.7 + 1 * 0.02 = 0.72 → 0.72 * 100 = 72
	var result := _placer.calculate_sell_value(100, 1)
	assert_eq(result, 72)

func test_sell_value_tier2_upgrade() -> void:
	# 0.7 + 2 * 0.02 = 0.74 → 0.74 * 100 = 74
	var result := _placer.calculate_sell_value(100, 2)
	assert_eq(result, 74)

func test_sell_value_with_upgrade_investment() -> void:
	# Total invest = 250, tier 2 → rate = 0.74 → 185
	var result := _placer.calculate_sell_value(250, 2)
	assert_eq(result, 185)

func test_sell_value_is_floored() -> void:
	# 0.7 * 3 = 2.1 → floor → 2
	var result := _placer.calculate_sell_value(3, 0)
	assert_eq(result, 2)

func test_sell_value_zero_investment_returns_zero() -> void:
	var result := _placer.calculate_sell_value(0, 0)
	assert_eq(result, 0)
