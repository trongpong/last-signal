extends GutTest

## Integration smoke tests for the Plan 1 foundation.
## Tests full level flow, difficulty modifiers, and diamond doubler working together.
## Run in Godot editor with GUT addon installed.

var gm
var em
var sm

func before_each() -> void:
	gm = GameManager.new()
	add_child(gm)
	em = EconomyManager.new()
	add_child(em)
	sm = SaveManager.new()
	sm.save_path = "user://test_integration_temp.json"
	add_child(sm)

func after_each() -> void:
	if FileAccess.file_exists(sm.save_path):
		DirAccess.remove_absolute(sm.save_path)
	gm.queue_free()
	em.queue_free()
	sm.queue_free()

# ---------------------------------------------------------------------------
# Full level flow: Normal difficulty
# ---------------------------------------------------------------------------

func test_full_level_flow_normal() -> void:
	# Start level
	em.reset_match_economy()
	em.set_gold_modifier(1.0)
	gm.start_level("level_01", Enums.Difficulty.NORMAL)

	assert_eq(gm.current_state, Enums.GameState.BUILDING)
	assert_eq(gm.lives, 20)
	assert_eq(gm.current_difficulty, Enums.Difficulty.NORMAL)

	# Simulate entering wave
	gm.change_state(Enums.GameState.WAVE_ACTIVE)
	assert_eq(gm.current_state, Enums.GameState.WAVE_ACTIVE)

	# Earn gold during wave
	em.add_gold(150)
	assert_eq(em.gold, 150)

	# Wave completes
	gm.change_state(Enums.GameState.WAVE_COMPLETE)
	assert_eq(gm.current_state, Enums.GameState.WAVE_COMPLETE)

	# Complete level (all waves done)
	gm.complete_level()
	assert_eq(gm.current_state, Enums.GameState.VICTORY)

func test_full_level_flow_victory_emits_completed() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	watch_signals(gm)
	gm.complete_level()
	assert_signal_emitted(gm, "level_completed")

func test_full_level_flow_perfect_run_three_stars() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	# No lives lost
	gm.complete_level()
	assert_eq(gm.calculate_stars(), 3)

func test_full_level_flow_near_perfect_two_stars() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	for _i in range(3):
		gm.lose_life()
	gm.complete_level()
	assert_eq(gm.calculate_stars(), 2)

func test_full_level_flow_rough_run_one_star() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	for _i in range(8):
		gm.lose_life()
	gm.complete_level()
	assert_eq(gm.calculate_stars(), 1)

# ---------------------------------------------------------------------------
# Hard difficulty modifiers
# ---------------------------------------------------------------------------

func test_hard_difficulty_reduced_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.HARD)
	assert_eq(gm.lives, 10)

func test_hard_difficulty_gold_modifier() -> void:
	em.reset_match_economy()
	var constants := Constants.new()
	em.set_gold_modifier(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.HARD])
	constants.free()
	em.add_gold(100)
	assert_eq(em.gold, 85, "Hard difficulty should give 85 gold per 100 earned")

func test_nightmare_difficulty_gold_modifier() -> void:
	em.reset_match_economy()
	var constants := Constants.new()
	em.set_gold_modifier(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NIGHTMARE])
	constants.free()
	em.add_gold(100)
	assert_eq(em.gold, 70, "Nightmare difficulty should give 70 gold per 100 earned")

func test_nightmare_difficulty_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	assert_eq(gm.lives, 5)

func test_nightmare_defeat_at_zero_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	for _i in range(5):
		gm.lose_life()
	assert_eq(gm.current_state, Enums.GameState.DEFEAT)
	assert_eq(gm.lives, 0)

func test_hard_hp_multiplier() -> void:
	var constants := Constants.new()
	var hp_mult: float = constants.DIFFICULTY_HP_MULT[Enums.Difficulty.HARD]
	constants.free()
	# An enemy with base 100 HP should have 180 on Hard
	var base_hp := 100.0
	var expected_hp := base_hp * hp_mult
	assert_almost_eq(expected_hp, 180.0, 0.001)

func test_nightmare_hp_multiplier() -> void:
	var constants := Constants.new()
	var hp_mult: float = constants.DIFFICULTY_HP_MULT[Enums.Difficulty.NIGHTMARE]
	constants.free()
	var base_hp := 100.0
	var expected_hp := base_hp * hp_mult
	assert_almost_eq(expected_hp, 300.0, 0.001)

# ---------------------------------------------------------------------------
# Diamond doubler integration
# ---------------------------------------------------------------------------

func test_diamond_doubler_doubles_ad_reward() -> void:
	em.diamond_doubler = true
	em.add_diamonds(Constants.DIAMONDS_PER_AD)
	assert_eq(em.diamonds, Constants.DIAMONDS_PER_AD * 2,
		"Diamond doubler should double ad reward")

func test_diamond_doubler_doubles_level_reward() -> void:
	em.diamond_doubler = true
	var constants := Constants.new()
	var base_reward := int(10.0 * constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.HARD])
	constants.free()
	em.add_diamonds(base_reward)
	assert_eq(em.diamonds, base_reward * 2)

func test_diamond_doubler_tracks_doubled_total() -> void:
	em.diamond_doubler = true
	em.add_diamonds(50)
	em.add_diamonds(50)
	assert_eq(em.total_diamonds_earned, 200, "total_diamonds_earned should track doubled amounts")

func test_diamond_doubler_spend_does_not_affect_total() -> void:
	em.diamond_doubler = true
	em.add_diamonds(100)
	var earned_before := em.total_diamonds_earned
	em.spend_diamonds(100)
	assert_eq(em.total_diamonds_earned, earned_before,
		"Spending should not reduce total_diamonds_earned")

# ---------------------------------------------------------------------------
# Save/load integration
# ---------------------------------------------------------------------------

func test_save_and_load_preserves_level_completion() -> void:
	# Record a level completion
	sm.set_level_complete("level_01", 3, Enums.Difficulty.HARD)
	sm.save_game()

	# Load in a fresh SaveManager
	var sm2 := SaveManager.new()
	sm2.save_path = sm.save_path
	add_child(sm2)
	sm2.load_game()

	var record := sm2.get_level_record("level_01")
	assert_eq(record["best_stars"], 3)
	assert_eq(record["best_difficulty"], Enums.Difficulty.HARD)
	sm2.queue_free()

func test_save_and_load_preserves_diamonds() -> void:
	em.add_diamonds(500)
	sm.sync_economy(em)
	sm.save_game()

	var sm2 := SaveManager.new()
	sm2.save_path = sm.save_path
	add_child(sm2)
	sm2.load_game()

	var eco2 := EconomyManager.new()
	add_child(eco2)
	sm2.apply_economy(eco2)
	assert_eq(eco2.diamonds, 500)
	sm2.queue_free()
	eco2.queue_free()

func test_match_reset_preserves_diamonds_across_levels() -> void:
	# Earn diamonds on first level
	em.add_diamonds(100)
	var diamonds_after_level1 := em.diamonds

	# Start new match (resets gold, keeps diamonds)
	em.reset_match_economy()
	assert_eq(em.diamonds, diamonds_after_level1,
		"Diamonds should survive match reset between levels")

func test_full_nightmare_run_with_diamond_reward() -> void:
	# Full nightmare playthrough simulation
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	em.reset_match_economy()
	var constants := Constants.new()
	em.set_gold_modifier(constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NIGHTMARE])

	# Simulate earning gold during waves
	em.add_gold(200)
	assert_eq(em.gold, 140, "Nightmare gold: 200 * 0.7 = 140")

	# Complete with 2 lives lost
	gm.lose_life()
	gm.lose_life()
	gm.complete_level()

	assert_eq(gm.current_state, Enums.GameState.VICTORY)
	assert_eq(gm.calculate_stars(), 2)

	# Diamond reward is higher on nightmare
	var nightmare_mult: float = constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.NIGHTMARE]
	constants.free()
	var base_diamond_reward := 10
	var expected_diamonds := int(float(base_diamond_reward) * nightmare_mult)
	em.add_diamonds(expected_diamonds)
	assert_eq(em.diamonds, 25, "Nightmare diamond reward: 10 * 2.5 = 25")

# ---------------------------------------------------------------------------
# Pause integration
# ---------------------------------------------------------------------------

func test_pause_during_wave() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	gm.change_state(Enums.GameState.WAVE_ACTIVE)
	gm.toggle_pause()
	assert_eq(gm.current_state, Enums.GameState.PAUSED)
	gm.toggle_pause()
	assert_eq(gm.current_state, Enums.GameState.WAVE_ACTIVE,
		"Unpausing should restore WAVE_ACTIVE")

# ---------------------------------------------------------------------------
# Economy: early send bonus
# ---------------------------------------------------------------------------

func test_early_send_gold_bonus_amount() -> void:
	assert_eq(Constants.EARLY_SEND_GOLD_BONUS, 50)

func test_early_send_adds_correct_gold() -> void:
	em.reset_match_economy()
	em.set_gold_modifier(1.0)
	em.add_gold(Constants.EARLY_SEND_GOLD_BONUS)
	assert_eq(em.gold, 50)

func test_early_send_gold_with_hard_modifier() -> void:
	em.reset_match_economy()
	em.set_gold_modifier(0.85)
	em.add_gold(Constants.EARLY_SEND_GOLD_BONUS)
	assert_eq(em.gold, 42, "50 * 0.85 = 42 (int truncated)")
