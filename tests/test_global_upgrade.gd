extends GutTest

## Tests for core/progression/global_upgrade.gd

var _upgrade: GlobalUpgrade

func before_each() -> void:
	_upgrade = GlobalUpgrade.new()
	_upgrade.id = "starting_gold"
	_upgrade.display_name = "Starting Gold"
	_upgrade.description = "Increases starting gold each match."
	_upgrade.value_per_tier = 25.0
	_upgrade.max_tier = 10

# ---------------------------------------------------------------------------
# get_cost_for_tier
# ---------------------------------------------------------------------------

func test_cost_tier_0_is_first_entry() -> void:
	# GLOBAL_UPGRADE_COSTS[0] = 50
	assert_eq(_upgrade.get_cost_for_tier(0), 50)

func test_cost_tier_1() -> void:
	# GLOBAL_UPGRADE_COSTS[1] = 75
	assert_eq(_upgrade.get_cost_for_tier(1), 75)

func test_cost_tier_9_is_last_entry() -> void:
	# GLOBAL_UPGRADE_COSTS[9] = 1400
	assert_eq(_upgrade.get_cost_for_tier(9), 1400)

func test_cost_at_max_tier_returns_zero() -> void:
	assert_eq(_upgrade.get_cost_for_tier(10), 0)

func test_cost_negative_tier_returns_zero() -> void:
	assert_eq(_upgrade.get_cost_for_tier(-1), 0)

# ---------------------------------------------------------------------------
# get_value_at_tier
# ---------------------------------------------------------------------------

func test_value_at_tier_0_is_zero() -> void:
	assert_almost_eq(_upgrade.get_value_at_tier(0), 0.0, 0.001)

func test_value_at_tier_1() -> void:
	assert_almost_eq(_upgrade.get_value_at_tier(1), 25.0, 0.001)

func test_value_at_tier_5() -> void:
	assert_almost_eq(_upgrade.get_value_at_tier(5), 125.0, 0.001)

func test_value_at_tier_10() -> void:
	assert_almost_eq(_upgrade.get_value_at_tier(10), 250.0, 0.001)

func test_value_scales_with_value_per_tier() -> void:
	_upgrade.value_per_tier = 2.0
	assert_almost_eq(_upgrade.get_value_at_tier(3), 6.0, 0.001)

# ---------------------------------------------------------------------------
# is_maxed
# ---------------------------------------------------------------------------

func test_not_maxed_at_tier_0() -> void:
	assert_false(_upgrade.is_maxed(0))

func test_not_maxed_at_tier_9() -> void:
	assert_false(_upgrade.is_maxed(9))

func test_maxed_at_tier_10() -> void:
	assert_true(_upgrade.is_maxed(10))

func test_maxed_above_max_tier() -> void:
	assert_true(_upgrade.is_maxed(11))

func test_custom_max_tier() -> void:
	_upgrade.max_tier = 5
	assert_false(_upgrade.is_maxed(4))
	assert_true(_upgrade.is_maxed(5))

# ---------------------------------------------------------------------------
# get_total_cost_to_max
# ---------------------------------------------------------------------------

func test_total_cost_to_max_sums_all_tiers() -> void:
	# 50+75+110+160+230+330+470+680+980+1400 = 4485
	assert_eq(_upgrade.get_total_cost_to_max(), 4485)

func test_total_cost_with_max_tier_1() -> void:
	_upgrade.max_tier = 1
	# Only tier 0: cost = 50
	assert_eq(_upgrade.get_total_cost_to_max(), 50)

func test_total_cost_with_max_tier_3() -> void:
	_upgrade.max_tier = 3
	# 50 + 75 + 110 = 235
	assert_eq(_upgrade.get_total_cost_to_max(), 235)

func test_total_cost_with_max_tier_0() -> void:
	_upgrade.max_tier = 0
	assert_eq(_upgrade.get_total_cost_to_max(), 0)
