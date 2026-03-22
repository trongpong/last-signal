extends GutTest

## Tests for core/enemy_system/enemy_health.gd

var eh: EnemyHealth

func before_each() -> void:
	eh = EnemyHealth.new()
	add_child(eh)
	eh.initialize(100.0, 0.0, 0.0)

func after_each() -> void:
	eh.queue_free()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func test_initialize_sets_hp() -> void:
	assert_almost_eq(eh.get_hp(), 100.0, 0.001)

func test_initialize_sets_max_hp() -> void:
	assert_almost_eq(eh.get_max_hp(), 100.0, 0.001)

func test_initialize_sets_shield() -> void:
	assert_almost_eq(eh.get_shield(), 0.0, 0.001)

func test_initialize_emits_health_changed() -> void:
	var eh2 := EnemyHealth.new()
	add_child(eh2)
	watch_signals(eh2)
	eh2.initialize(50.0, 0.0, 0.0)
	assert_signal_emitted(eh2, "health_changed")
	eh2.queue_free()

func test_initialize_hp_minimum_one() -> void:
	eh.initialize(0.0, 0.0, 0.0)
	assert_almost_eq(eh.get_max_hp(), 1.0, 0.001)

func test_initialize_with_shield() -> void:
	eh.initialize(100.0, 0.0, 30.0)
	assert_almost_eq(eh.get_shield(), 30.0, 0.001)

func test_initialize_is_alive() -> void:
	assert_true(eh.is_alive())

# ---------------------------------------------------------------------------
# HP percentage
# ---------------------------------------------------------------------------

func test_full_hp_percentage_is_one() -> void:
	assert_almost_eq(eh.get_hp_percentage(), 1.0, 0.001)

func test_hp_percentage_after_damage() -> void:
	eh.take_damage(25.0, Enums.DamageType.PULSE)
	assert_almost_eq(eh.get_hp_percentage(), 0.75, 0.001)

# ---------------------------------------------------------------------------
# Basic damage
# ---------------------------------------------------------------------------

func test_take_damage_reduces_hp() -> void:
	eh.take_damage(30.0, Enums.DamageType.PULSE)
	assert_almost_eq(eh.get_hp(), 70.0, 0.001)

func test_take_damage_emits_health_changed() -> void:
	watch_signals(eh)
	eh.take_damage(10.0, Enums.DamageType.PULSE)
	assert_signal_emitted(eh, "health_changed")

func test_take_damage_to_zero_emits_died() -> void:
	watch_signals(eh)
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	assert_signal_emitted(eh, "died")

func test_take_damage_to_zero_sets_not_alive() -> void:
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	assert_false(eh.is_alive())

func test_hp_does_not_go_below_zero() -> void:
	eh.take_damage(200.0, Enums.DamageType.PULSE)
	assert_almost_eq(eh.get_hp(), 0.0, 0.001)

func test_died_emitted_only_once() -> void:
	watch_signals(eh)
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	assert_signal_emit_count(eh, "died", 1)

# ---------------------------------------------------------------------------
# Armor
# ---------------------------------------------------------------------------

func test_armor_reduces_damage() -> void:
	eh.initialize(100.0, 10.0, 0.0)
	eh.take_damage(30.0, Enums.DamageType.PULSE)
	# Diminishing-returns armor: reduction = 10/(10+100) ≈ 0.0909
	# after_armor = 30 * (1 - 0.0909) ≈ 27.2727, HP = 100 - 27.2727 ≈ 72.7273
	assert_almost_eq(eh.get_hp(), 72.727, 0.01)

func test_armor_diminishing_returns_on_small_damage() -> void:
	eh.initialize(100.0, 50.0, 0.0)
	eh.take_damage(5.0, Enums.DamageType.PULSE)
	# Diminishing-returns armor: reduction = 50/(50+100) = 0.3333
	# after_armor = 5 * (1 - 0.3333) ≈ 3.3333, HP = 100 - 3.3333 ≈ 96.6667
	assert_almost_eq(eh.get_hp(), 96.667, 0.01)

# ---------------------------------------------------------------------------
# Shield
# ---------------------------------------------------------------------------

func test_shield_absorbs_damage_before_hp() -> void:
	eh.initialize(100.0, 0.0, 20.0)
	eh.take_damage(15.0, Enums.DamageType.PULSE)
	# Shield absorbs all 15 damage
	assert_almost_eq(eh.get_hp(), 100.0, 0.001)
	assert_almost_eq(eh.get_shield(), 5.0, 0.001)

func test_shield_overflow_damages_hp() -> void:
	eh.initialize(100.0, 0.0, 10.0)
	eh.take_damage(25.0, Enums.DamageType.PULSE)
	# Shield absorbs 10, remaining 15 hits HP
	assert_almost_eq(eh.get_hp(), 85.0, 0.001)
	assert_almost_eq(eh.get_shield(), 0.0, 0.001)

func test_add_shield() -> void:
	eh.add_shield(50.0)
	assert_almost_eq(eh.get_shield(), 50.0, 0.001)

func test_add_shield_emits_health_changed() -> void:
	watch_signals(eh)
	eh.add_shield(10.0)
	assert_signal_emitted(eh, "health_changed")

# ---------------------------------------------------------------------------
# Resistance
# ---------------------------------------------------------------------------

func test_resistance_reduces_damage() -> void:
	var rmap: Dictionary = {}
	rmap[Enums.DamageType.CRYO] = 0.5
	eh.initialize(100.0, 0.0, 0.0, rmap)
	eh.take_damage(40.0, Enums.DamageType.CRYO)
	# 40 * 0.5 = 20 damage, minimum armor check: 20 > 0 armor → 20 hp damage
	assert_almost_eq(eh.get_hp(), 80.0, 0.001)

func test_full_resistance_negates_all_damage() -> void:
	var rmap: Dictionary = {}
	rmap[Enums.DamageType.CRYO] = 1.0
	eh.initialize(100.0, 0.0, 0.0, rmap)
	eh.take_damage(50.0, Enums.DamageType.CRYO)
	# 50 * (1 - 1.0) = 0, no minimum-damage clamp → 0 damage
	assert_almost_eq(eh.get_hp(), 100.0, 0.001)

func test_no_resistance_for_other_type() -> void:
	var rmap: Dictionary = {}
	rmap[Enums.DamageType.CRYO] = 0.5
	eh.initialize(100.0, 0.0, 0.0, rmap)
	eh.take_damage(40.0, Enums.DamageType.PULSE)
	# PULSE has no resistance → full 40 damage
	assert_almost_eq(eh.get_hp(), 60.0, 0.001)

# ---------------------------------------------------------------------------
# Heal
# ---------------------------------------------------------------------------

func test_heal_increases_hp() -> void:
	eh.take_damage(30.0, Enums.DamageType.PULSE)
	eh.heal(10.0)
	assert_almost_eq(eh.get_hp(), 80.0, 0.001)

func test_heal_capped_at_max_hp() -> void:
	eh.take_damage(10.0, Enums.DamageType.PULSE)
	eh.heal(200.0)
	assert_almost_eq(eh.get_hp(), 100.0, 0.001)

func test_heal_emits_health_changed() -> void:
	eh.take_damage(20.0, Enums.DamageType.PULSE)
	watch_signals(eh)
	eh.heal(5.0)
	assert_signal_emitted(eh, "health_changed")

func test_heal_does_nothing_when_dead() -> void:
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	eh.heal(100.0)
	assert_almost_eq(eh.get_hp(), 0.0, 0.001)

# ---------------------------------------------------------------------------
# Dead state
# ---------------------------------------------------------------------------

func test_take_damage_does_nothing_when_dead() -> void:
	eh.take_damage(100.0, Enums.DamageType.PULSE)
	watch_signals(eh)
	eh.take_damage(50.0, Enums.DamageType.PULSE)
	assert_signal_not_emitted(eh, "health_changed")
