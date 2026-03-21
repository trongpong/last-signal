extends GutTest

## Tests for core/ability_system/hero.gd

var _hero: Hero

func before_each() -> void:
	_hero = Hero.new()
	add_child(_hero)

func after_each() -> void:
	_hero.queue_free()

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_summon_cooldown_constant() -> void:
	assert_almost_eq(Hero.SUMMON_COOLDOWN, 150.0, 0.001)

# ---------------------------------------------------------------------------
# Initial State (before initialize)
# ---------------------------------------------------------------------------

func test_not_active_before_initialize() -> void:
	assert_false(_hero.is_active())

# ---------------------------------------------------------------------------
# initialize
# ---------------------------------------------------------------------------

func test_active_after_initialize_with_positive_duration() -> void:
	_hero.initialize("pulse_hero", 20.0, Vector2.ZERO)
	assert_true(_hero.is_active())

func test_not_active_with_zero_duration() -> void:
	_hero.initialize("pulse_hero", 0.0, Vector2.ZERO)
	assert_false(_hero.is_active())

func test_position_set_on_initialize() -> void:
	_hero.initialize("pulse_hero", 10.0, Vector2(100.0, 200.0))
	assert_almost_eq(_hero.position.x, 100.0, 0.001)
	assert_almost_eq(_hero.position.y, 200.0, 0.001)

# ---------------------------------------------------------------------------
# apply_duration_bonus
# ---------------------------------------------------------------------------

func test_apply_duration_bonus_extends_remaining() -> void:
	_hero.initialize("pulse_hero", 20.0, Vector2.ZERO)
	_hero.apply_duration_bonus(5.0)
	# Tick 10 seconds — should still be active (remaining = 25 - 10 = 15)
	_hero._process(10.0)
	assert_true(_hero.is_active())

func test_apply_duration_bonus_zero_does_not_change_state() -> void:
	_hero.initialize("pulse_hero", 20.0, Vector2.ZERO)
	_hero.apply_duration_bonus(0.0)
	assert_true(_hero.is_active())

# ---------------------------------------------------------------------------
# _process: expiry
# ---------------------------------------------------------------------------

func test_expired_after_duration_ticks() -> void:
	_hero.initialize("pulse_hero", 5.0, Vector2.ZERO)
	_hero._process(5.1)
	assert_false(_hero.is_active())

func test_still_active_before_duration_expires() -> void:
	_hero.initialize("pulse_hero", 5.0, Vector2.ZERO)
	_hero._process(4.9)
	assert_true(_hero.is_active())

func test_process_does_nothing_when_inactive() -> void:
	# Never initialized (duration = 0)
	_hero._process(1.0)
	assert_false(_hero.is_active())

# ---------------------------------------------------------------------------
# expired signal
# ---------------------------------------------------------------------------

func test_expired_signal_emitted() -> void:
	_hero.initialize("pulse_hero", 1.0, Vector2.ZERO)
	watch_signals(_hero)
	_hero._process(1.5)
	assert_signal_emitted(_hero, "expired")

func test_expired_signal_passes_hero_reference() -> void:
	_hero.initialize("pulse_hero", 1.0, Vector2.ZERO)
	watch_signals(_hero)
	_hero._process(1.5)
	var args := get_signal_parameters(_hero, "expired")
	assert_eq(args[0], _hero)

func test_expired_signal_not_emitted_before_duration() -> void:
	_hero.initialize("pulse_hero", 10.0, Vector2.ZERO)
	watch_signals(_hero)
	_hero._process(5.0)
	assert_signal_not_emitted(_hero, "expired")

func test_expired_signal_only_emitted_once() -> void:
	_hero.initialize("pulse_hero", 1.0, Vector2.ZERO)
	watch_signals(_hero)
	_hero._process(1.5)
	_hero._process(1.0)  # Extra tick after expiry
	assert_signal_emit_count(_hero, "expired", 1)

# ---------------------------------------------------------------------------
# Multiple ticks
# ---------------------------------------------------------------------------

func test_partial_ticks_accumulate() -> void:
	_hero.initialize("pulse_hero", 3.0, Vector2.ZERO)
	_hero._process(1.0)
	_hero._process(1.0)
	assert_true(_hero.is_active())
	_hero._process(1.1)
	assert_false(_hero.is_active())
