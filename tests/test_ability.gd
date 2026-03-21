extends GutTest

## Tests for core/ability_system/ability.gd

var _ability: Ability

func before_each() -> void:
	_ability = Ability.new()
	add_child(_ability)
	_ability.initialize("orbital_strike", 60.0)

func after_each() -> void:
	_ability.queue_free()

# ---------------------------------------------------------------------------
# Initial State
# ---------------------------------------------------------------------------

func test_is_ready_initially() -> void:
	assert_true(_ability.is_ready())

func test_cooldown_progress_is_one_initially() -> void:
	assert_almost_eq(_ability.get_cooldown_progress(), 1.0, 0.001)

# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

func test_activate_returns_true_when_ready() -> void:
	var result := _ability.activate()
	assert_true(result)

func test_activate_returns_false_when_on_cooldown() -> void:
	_ability.activate()
	var result := _ability.activate()
	assert_false(result)

func test_activate_emits_signal() -> void:
	watch_signals(_ability)
	_ability.activate()
	assert_signal_emitted(_ability, "activated")

func test_activate_signal_contains_ability_id() -> void:
	watch_signals(_ability)
	_ability.activate("target_pos")
	var args := get_signal_parameters(_ability, "activated")
	assert_eq(args[0], "orbital_strike")

func test_activate_signal_contains_target() -> void:
	watch_signals(_ability)
	_ability.activate("my_target")
	var args := get_signal_parameters(_ability, "activated")
	assert_eq(args[1], "my_target")

func test_not_ready_after_activation() -> void:
	_ability.activate()
	assert_false(_ability.is_ready())

# ---------------------------------------------------------------------------
# Cooldown Progress
# ---------------------------------------------------------------------------

func test_cooldown_progress_drops_after_activation() -> void:
	_ability.activate()
	assert_true(_ability.get_cooldown_progress() < 1.0)

func test_cooldown_progress_is_zero_right_after_activation() -> void:
	# Just activated, no delta processed → progress near 0
	_ability.activate()
	assert_almost_eq(_ability.get_cooldown_progress(), 0.0, 0.01)

# ---------------------------------------------------------------------------
# Cooldown Reduction
# ---------------------------------------------------------------------------

func test_zero_cooldown_reduction_uses_full_cooldown() -> void:
	_ability.cooldown_reduction = 0.0
	_ability.activate()
	assert_false(_ability.is_ready())

func test_full_cooldown_reduction_activates_instantly() -> void:
	_ability.cooldown_reduction = 1.0
	_ability.activate()
	# With 100% reduction, effective cooldown = 0, should remain ready
	assert_true(_ability.is_ready())

func test_cooldown_progress_at_max_reduction() -> void:
	_ability.cooldown_reduction = 1.0
	_ability.activate()
	assert_almost_eq(_ability.get_cooldown_progress(), 1.0, 0.001)

# ---------------------------------------------------------------------------
# Process (simulated ticks)
# ---------------------------------------------------------------------------

func test_process_reduces_cooldown_remaining() -> void:
	_ability.activate()
	# Simulate a large delta to drain cooldown
	_ability._process(60.0)
	assert_true(_ability.is_ready())

func test_cooldown_complete_signal_emitted() -> void:
	_ability.activate()
	watch_signals(_ability)
	_ability._process(60.0)
	assert_signal_emitted(_ability, "cooldown_complete")

func test_cooldown_complete_signal_contains_id() -> void:
	_ability.activate()
	watch_signals(_ability)
	_ability._process(60.0)
	var args := get_signal_parameters(_ability, "cooldown_complete")
	assert_eq(args[0], "orbital_strike")

func test_cooldown_complete_not_emitted_before_expiry() -> void:
	_ability.activate()
	watch_signals(_ability)
	_ability._process(1.0)
	assert_signal_not_emitted(_ability, "cooldown_complete")

func test_is_ready_after_cooldown_expires() -> void:
	_ability.activate()
	_ability._process(61.0)
	assert_true(_ability.is_ready())

# ---------------------------------------------------------------------------
# Zero base_cooldown edge case
# ---------------------------------------------------------------------------

func test_zero_base_cooldown_progress_is_one() -> void:
	_ability.initialize("test", 0.0)
	assert_almost_eq(_ability.get_cooldown_progress(), 1.0, 0.001)
