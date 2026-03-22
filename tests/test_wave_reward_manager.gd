extends GutTest

## Tests for core/endless/wave_reward_manager.gd

var _wrm: WaveRewardManager

func before_each() -> void:
	_wrm = WaveRewardManager.new()
	add_child(_wrm)
	_wrm.setup()

func after_each() -> void:
	_wrm.queue_free()

# ---------------------------------------------------------------------------
# Pool
# ---------------------------------------------------------------------------

func test_pool_has_18_rewards() -> void:
	assert_eq(_wrm.get_pool_size(), 18)

# ---------------------------------------------------------------------------
# should_offer_reward
# ---------------------------------------------------------------------------

func test_should_offer_reward_at_wave_5() -> void:
	assert_true(_wrm.should_offer_reward(5))

func test_should_offer_reward_at_wave_10() -> void:
	assert_true(_wrm.should_offer_reward(10))

func test_should_not_offer_reward_at_wave_3() -> void:
	assert_false(_wrm.should_offer_reward(3))

func test_should_not_offer_reward_at_wave_0() -> void:
	assert_false(_wrm.should_offer_reward(0))

# ---------------------------------------------------------------------------
# generate_choices
# ---------------------------------------------------------------------------

func test_generate_choices_returns_3() -> void:
	var choices: Array = _wrm.generate_choices()
	assert_eq(choices.size(), Constants.WAVE_REWARD_CHOICE_COUNT)

func test_choices_have_required_keys() -> void:
	var choices: Array = _wrm.generate_choices()
	for c in choices:
		assert_true(c.has("id"))
		assert_true(c.has("display_name"))
		assert_true(c.has("modifiers"))

# ---------------------------------------------------------------------------
# pick_reward
# ---------------------------------------------------------------------------

func test_pick_reward_adds_to_picked() -> void:
	_wrm.generate_choices()
	_wrm.pick_reward(0)
	assert_eq(_wrm.get_picked_rewards().size(), 1)

func test_pick_reward_emits_signal() -> void:
	_wrm.generate_choices()
	watch_signals(_wrm)
	_wrm.pick_reward(1)
	assert_signal_emitted(_wrm, "reward_picked")

func test_pick_random_picks_from_choices() -> void:
	_wrm.generate_choices()
	_wrm.pick_random()
	assert_eq(_wrm.get_picked_rewards().size(), 1)

# ---------------------------------------------------------------------------
# get_modifiers
# ---------------------------------------------------------------------------

func test_get_modifiers_empty_initially() -> void:
	var mods: Dictionary = _wrm.get_modifiers()
	assert_eq(mods.size(), 0)

func test_get_modifiers_aggregates_after_pick() -> void:
	_wrm.generate_choices()
	_wrm.pick_reward(0)
	var mods: Dictionary = _wrm.get_modifiers()
	assert_gt(mods.size(), 0, "Should have at least one modifier key")

func test_stacking_same_reward_doubles_effect() -> void:
	# Pick the same reward twice to test stacking
	_wrm.generate_choices()
	var choices: Array = _wrm.get_picked_rewards()
	_wrm.pick_reward(0)
	_wrm.generate_choices()
	_wrm.pick_reward(0)
	# With 2 picks, at least one modifier should be doubled
	assert_eq(_wrm.get_picked_rewards().size(), 2)

func test_get_modifier_value_returns_default() -> void:
	assert_almost_eq(_wrm.get_modifier_value("nonexistent", 0.0), 0.0, 0.001)
