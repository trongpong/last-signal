extends GutTest

## Tests for shared/constants.gd
## Run in Godot editor with GUT addon installed.

var constants: Constants

func before_each() -> void:
	constants = Constants.new()

func after_each() -> void:

# ---------------------------------------------------------------------------
# Difficulty multiplier tests
# ---------------------------------------------------------------------------

func test_hp_multipliers() -> void:
	assert_eq(constants.DIFFICULTY_HP_MULT[Enums.Difficulty.NORMAL], 1.0)
	assert_eq(constants.DIFFICULTY_HP_MULT[Enums.Difficulty.HARD], 1.8)
	assert_eq(constants.DIFFICULTY_HP_MULT[Enums.Difficulty.NIGHTMARE], 3.0)

func test_speed_multipliers() -> void:
	assert_eq(constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.NORMAL], 1.0)
	assert_almost_eq(constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.HARD], 1.15, 0.001)
	assert_almost_eq(constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.NIGHTMARE], 1.3, 0.001)

func test_gold_multipliers() -> void:
	assert_eq(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NORMAL], 1.0)
	assert_almost_eq(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.HARD], 0.85, 0.001)
	assert_almost_eq(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NIGHTMARE], 0.7, 0.001)

func test_starting_lives() -> void:
	assert_eq(constants.DIFFICULTY_LIVES[Enums.Difficulty.NORMAL], 20)
	assert_eq(constants.DIFFICULTY_LIVES[Enums.Difficulty.HARD], 10)
	assert_eq(constants.DIFFICULTY_LIVES[Enums.Difficulty.NIGHTMARE], 5)

func test_adaptation_thresholds() -> void:
	assert_almost_eq(constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.NORMAL], 0.4, 0.001)
	assert_almost_eq(constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.HARD], 0.35, 0.001)
	assert_almost_eq(constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.NIGHTMARE], 0.25, 0.001)

func test_diamond_reward_multipliers() -> void:
	assert_eq(constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.NORMAL], 1.0)
	assert_almost_eq(constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.HARD], 1.5, 0.001)
	assert_almost_eq(constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.NIGHTMARE], 2.5, 0.001)

# ---------------------------------------------------------------------------
# Economy tests
# ---------------------------------------------------------------------------

func test_base_sell_refund() -> void:
	assert_almost_eq(Constants.BASE_SELL_REFUND, 0.7, 0.001)

func test_sell_refund_per_tier() -> void:
	assert_almost_eq(Constants.SELL_REFUND_PER_UPGRADE_TIER, 0.02, 0.001)

func test_early_send_gold_bonus() -> void:
	assert_eq(Constants.EARLY_SEND_GOLD_BONUS, 50)

# ---------------------------------------------------------------------------
# Adaptation tests
# ---------------------------------------------------------------------------

func test_adaptation_check_interval() -> void:
	assert_eq(Constants.ADAPTATION_CHECK_INTERVAL, 3)

func test_max_resistance() -> void:
	assert_almost_eq(Constants.ADAPTATION_MAX_RESISTANCE, 0.6, 0.001)

func test_max_resistance_endless() -> void:
	assert_almost_eq(Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS, 0.75, 0.001)

func test_endless_threshold() -> void:
	assert_almost_eq(Constants.ADAPTATION_ENDLESS_THRESHOLD, 0.3, 0.001)

func test_resistance_increment() -> void:
	assert_almost_eq(Constants.ADAPTATION_RESISTANCE_INCREMENT, 0.1, 0.001)

func test_decay_rate() -> void:
	assert_almost_eq(Constants.ADAPTATION_DECAY_RATE, 0.05, 0.001)

# ---------------------------------------------------------------------------
# Star rating tests
# ---------------------------------------------------------------------------

func test_star_two_fraction_threshold() -> void:
	assert_almost_eq(Constants.new().STAR_2_MAX_LIVES_LOST_FRACTION, 0.25, 0.001)

func test_star_three_fraction_threshold() -> void:
	assert_almost_eq(Constants.new().STAR_3_MAX_LIVES_LOST_FRACTION, 0.0, 0.001)

# ---------------------------------------------------------------------------
# Wave & speed tests
# ---------------------------------------------------------------------------

func test_wave_break_duration() -> void:
	assert_almost_eq(Constants.WAVE_BREAK_DURATION, 6.0, 0.001)

func test_speed_options() -> void:
	assert_eq(Constants.SPEED_OPTIONS.size(), 3)
	assert_almost_eq(Constants.SPEED_OPTIONS[0], 1.0, 0.001)
	assert_almost_eq(Constants.SPEED_OPTIONS[1], 2.0, 0.001)
	assert_almost_eq(Constants.SPEED_OPTIONS[2], 3.0, 0.001)

# ---------------------------------------------------------------------------
# Upgrade cost tests
# ---------------------------------------------------------------------------

func test_global_upgrade_costs_count() -> void:
	assert_eq(Constants.GLOBAL_UPGRADE_COSTS.size(), 10, "Should have 10 upgrade tiers")

func test_global_upgrade_costs_ascending() -> void:
	for i in range(1, Constants.GLOBAL_UPGRADE_COSTS.size()):
		assert_gt(Constants.GLOBAL_UPGRADE_COSTS[i], Constants.GLOBAL_UPGRADE_COSTS[i - 1],
			"Each tier should cost more than the previous")

func test_skill_node_costs_count() -> void:
	assert_eq(Constants.SKILL_NODE_COSTS.size(), 10)

func test_ability_unlock_cost() -> void:
	assert_eq(Constants.ABILITY_UNLOCK_COST, 200)

func test_ability_upgrade_costs_count() -> void:
	assert_eq(Constants.ABILITY_UPGRADE_COSTS.size(), 5)

# ---------------------------------------------------------------------------
# Monetization tests
# ---------------------------------------------------------------------------

func test_max_ads_per_day() -> void:
	assert_eq(Constants.MAX_ADS_PER_DAY, 10)

func test_diamonds_per_ad() -> void:
	assert_eq(Constants.DIAMONDS_PER_AD, 10)

# ---------------------------------------------------------------------------
# Hero tests
# ---------------------------------------------------------------------------

func test_hero_base_cooldown() -> void:
	assert_almost_eq(Constants.HERO_BASE_COOLDOWN, 150.0, 0.001)

func test_hero_duration_per_upgrade() -> void:
	assert_almost_eq(Constants.HERO_DURATION_PER_UPGRADE_TIER, 1.0, 0.001)
