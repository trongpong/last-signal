extends GutTest

## Tests for core/economy/economy_manager.gd
## Run in Godot editor with GUT addon installed.

var em: EconomyManager

func before_each() -> void:
	em = EconomyManager.new()
	add_child(em)

func after_each() -> void:
	em.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_gold_is_zero() -> void:
	assert_eq(em.gold, 0)

func test_initial_diamonds_is_zero() -> void:
	assert_eq(em.diamonds, 0)

func test_initial_total_diamonds_earned_is_zero() -> void:
	assert_eq(em.total_diamonds_earned, 0)

func test_initial_diamond_doubler_is_false() -> void:
	assert_false(em.diamond_doubler)

# ---------------------------------------------------------------------------
# Gold: add_gold
# ---------------------------------------------------------------------------

func test_add_gold_increases_gold() -> void:
	em.add_gold(100)
	assert_eq(em.gold, 100)

func test_add_gold_emits_signal() -> void:
	watch_signals(em)
	em.add_gold(50)
	assert_signal_emitted(em, "gold_changed")

func test_add_gold_applies_modifier() -> void:
	em.set_gold_modifier(0.85)
	em.add_gold(100)
	# 100 * 0.85 = 85 (int truncation)
	assert_eq(em.gold, 85)

func test_add_gold_modifier_nightmare() -> void:
	em.set_gold_modifier(0.7)
	em.add_gold(100)
	assert_eq(em.gold, 70)

# ---------------------------------------------------------------------------
# Gold: spend_gold
# ---------------------------------------------------------------------------

func test_spend_gold_succeeds_when_sufficient() -> void:
	em.add_gold(100)
	var result := em.spend_gold(50)
	assert_true(result)
	assert_eq(em.gold, 50)

func test_spend_gold_fails_when_insufficient() -> void:
	em.add_gold(30)
	var result := em.spend_gold(50)
	assert_false(result)
	assert_eq(em.gold, 30, "Gold should be unchanged on failed spend")

func test_spend_gold_emits_signal_on_success() -> void:
	em.add_gold(100)
	watch_signals(em)
	em.spend_gold(50)
	assert_signal_emitted(em, "gold_changed")

func test_spend_gold_no_signal_on_failure() -> void:
	watch_signals(em)
	em.spend_gold(50)
	assert_signal_not_emitted(em, "gold_changed")

# ---------------------------------------------------------------------------
# Gold: can_afford
# ---------------------------------------------------------------------------

func test_can_afford_true_when_exact() -> void:
	em.add_gold(50)
	assert_true(em.can_afford(50))

func test_can_afford_false_when_short() -> void:
	em.add_gold(49)
	assert_false(em.can_afford(50))

# ---------------------------------------------------------------------------
# Diamonds: add_diamonds (no doubler)
# ---------------------------------------------------------------------------

func test_add_diamonds_increases_diamonds() -> void:
	em.add_diamonds(100)
	assert_eq(em.diamonds, 100)

func test_add_diamonds_tracks_total_earned() -> void:
	em.add_diamonds(100)
	em.add_diamonds(50)
	assert_eq(em.total_diamonds_earned, 150)

func test_add_diamonds_emits_signal() -> void:
	watch_signals(em)
	em.add_diamonds(10)
	assert_signal_emitted(em, "diamonds_changed")

# ---------------------------------------------------------------------------
# Diamonds: diamond_doubler
# ---------------------------------------------------------------------------

func test_diamond_doubler_doubles_add() -> void:
	em.diamond_doubler = true
	em.add_diamonds(50)
	assert_eq(em.diamonds, 100)

func test_diamond_doubler_doubles_total_earned() -> void:
	em.diamond_doubler = true
	em.add_diamonds(50)
	assert_eq(em.total_diamonds_earned, 100)

func test_diamond_doubler_off_no_double() -> void:
	em.diamond_doubler = false
	em.add_diamonds(50)
	assert_eq(em.diamonds, 50)

# ---------------------------------------------------------------------------
# Diamonds: spend_diamonds
# ---------------------------------------------------------------------------

func test_spend_diamonds_succeeds_when_sufficient() -> void:
	em.add_diamonds(200)
	var result := em.spend_diamonds(100)
	assert_true(result)
	assert_eq(em.diamonds, 100)

func test_spend_diamonds_fails_when_insufficient() -> void:
	em.add_diamonds(50)
	var result := em.spend_diamonds(100)
	assert_false(result)
	assert_eq(em.diamonds, 50)

func test_spend_diamonds_does_not_affect_total_earned() -> void:
	em.add_diamonds(200)
	em.spend_diamonds(100)
	assert_eq(em.total_diamonds_earned, 200, "total_diamonds_earned should not decrease when spending")

# ---------------------------------------------------------------------------
# Match lifecycle: reset_match_economy
# ---------------------------------------------------------------------------

func test_reset_clears_gold() -> void:
	em.add_gold(500)
	em.reset_match_economy()
	assert_eq(em.gold, 0)

func test_reset_resets_modifier() -> void:
	em.set_gold_modifier(0.7)
	em.reset_match_economy()
	em.add_gold(100)
	assert_eq(em.gold, 100, "After reset, modifier should be 1.0 so gold adds at full value")

func test_reset_preserves_diamonds() -> void:
	em.add_diamonds(500)
	em.reset_match_economy()
	assert_eq(em.diamonds, 500)

func test_reset_preserves_total_diamonds_earned() -> void:
	em.add_diamonds(300)
	em.reset_match_economy()
	assert_eq(em.total_diamonds_earned, 300)

func test_reset_emits_gold_changed_when_gold_nonzero() -> void:
	em.add_gold(100)
	watch_signals(em)
	em.reset_match_economy()
	assert_signal_emitted(em, "gold_changed")
