extends GutTest

## Tests for core/ability_system/ability_manager.gd

var _manager: AbilityManager

func before_each() -> void:
	_manager = AbilityManager.new()
	add_child(_manager)

func after_each() -> void:
	_manager.queue_free()

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_max_slots_is_three() -> void:
	assert_eq(AbilityManager.MAX_SLOTS, 3)

func test_ability_cooldowns_contains_orbital_strike() -> void:
	assert_true(AbilityManager.ABILITY_COOLDOWNS.has("orbital_strike"))

func test_orbital_strike_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["orbital_strike"], 60.0)

func test_emp_burst_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["emp_burst"], 45.0)

func test_repair_wave_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["repair_wave"], 40.0)

func test_shield_matrix_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["shield_matrix"], 50.0)

func test_overclock_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["overclock"], 30.0)

func test_scrap_salvage_cooldown() -> void:
	assert_eq(AbilityManager.ABILITY_COOLDOWNS["scrap_salvage"], 35.0)

# ---------------------------------------------------------------------------
# set_loadout / get_loadout
# ---------------------------------------------------------------------------

func test_empty_loadout_initially() -> void:
	assert_eq(_manager.get_loadout().size(), 0)

func test_set_loadout_stores_ids() -> void:
	_manager.set_loadout(["orbital_strike", "emp_burst"])
	var loadout := _manager.get_loadout()
	assert_eq(loadout[0], "orbital_strike")
	assert_eq(loadout[1], "emp_burst")

func test_set_loadout_caps_at_max_slots() -> void:
	_manager.set_loadout(["orbital_strike", "emp_burst", "repair_wave", "shield_matrix"])
	assert_eq(_manager.get_loadout().size(), 3)

func test_set_loadout_creates_ability_children() -> void:
	_manager.set_loadout(["orbital_strike", "emp_burst"])
	# Two ability children should exist
	assert_not_null(_manager.get_ability(0))
	assert_not_null(_manager.get_ability(1))

func test_get_ability_invalid_slot_returns_null() -> void:
	_manager.set_loadout(["orbital_strike"])
	assert_null(_manager.get_ability(5))

func test_set_loadout_replaces_previous_loadout() -> void:
	_manager.set_loadout(["orbital_strike", "emp_burst", "repair_wave"])
	_manager.set_loadout(["overclock"])
	assert_eq(_manager.get_loadout().size(), 1)
	assert_eq(_manager.get_loadout()[0], "overclock")

func test_empty_loadout_clears_abilities() -> void:
	_manager.set_loadout(["orbital_strike"])
	_manager.set_loadout([])
	assert_eq(_manager.get_loadout().size(), 0)

# ---------------------------------------------------------------------------
# activate_ability
# ---------------------------------------------------------------------------

func test_activate_ability_returns_true_when_ready() -> void:
	_manager.set_loadout(["orbital_strike"])
	var result := _manager.activate_ability(0)
	assert_true(result)

func test_activate_ability_invalid_slot_returns_false() -> void:
	_manager.set_loadout(["orbital_strike"])
	var result := _manager.activate_ability(5)
	assert_false(result)

func test_activate_ability_emits_signal() -> void:
	_manager.set_loadout(["orbital_strike"])
	watch_signals(_manager)
	_manager.activate_ability(0, "target")
	assert_signal_emitted(_manager, "ability_activated")

func test_activate_ability_signal_contains_id_and_slot() -> void:
	_manager.set_loadout(["emp_burst"])
	watch_signals(_manager)
	_manager.activate_ability(0, null)
	var args := get_signal_parameters(_manager, "ability_activated")
	assert_eq(args[0], "emp_burst")
	assert_eq(args[1], 0)

func test_activate_ability_second_time_fails_while_on_cooldown() -> void:
	_manager.set_loadout(["orbital_strike"])
	_manager.activate_ability(0)
	var result := _manager.activate_ability(0)
	assert_false(result)

func test_activate_ability_no_loadout_returns_false() -> void:
	var result := _manager.activate_ability(0)
	assert_false(result)

# ---------------------------------------------------------------------------
# set_cooldown_reduction
# ---------------------------------------------------------------------------

func test_set_cooldown_reduction_applies_to_abilities() -> void:
	_manager.set_loadout(["orbital_strike"])
	_manager.set_cooldown_reduction(0.5)
	var ab: Ability = _manager.get_ability(0)
	assert_almost_eq(ab.cooldown_reduction, 0.5, 0.001)

func test_set_cooldown_reduction_before_loadout_applies_on_set() -> void:
	_manager.set_cooldown_reduction(0.3)
	_manager.set_loadout(["repair_wave"])
	var ab: Ability = _manager.get_ability(0)
	assert_almost_eq(ab.cooldown_reduction, 0.3, 0.001)

# ---------------------------------------------------------------------------
# Three slots independent
# ---------------------------------------------------------------------------

func test_three_slots_are_independent() -> void:
	_manager.set_loadout(["orbital_strike", "emp_burst", "repair_wave"])
	_manager.activate_ability(0)
	# Slot 0 is on cooldown; slot 1 should still be ready
	var ab1: Ability = _manager.get_ability(1)
	assert_true(ab1.is_ready())
