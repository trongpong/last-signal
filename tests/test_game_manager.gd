extends GutTest

## Tests for core/game_manager.gd
## Run in Godot editor with GUT addon installed.

var gm

func before_each() -> void:
	gm = load("res://core/game_manager.gd").new()
	add_child(gm)

func after_each() -> void:
	gm.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_is_menu() -> void:
	assert_eq(gm.current_state, Enums.GameState.MENU)

func test_initial_difficulty_is_normal() -> void:
	assert_eq(gm.current_difficulty, Enums.Difficulty.NORMAL)

func test_initial_game_speed_is_one() -> void:
	assert_almost_eq(gm.game_speed, 1.0, 0.001)

# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func test_change_state_emits_signal() -> void:
	watch_signals(gm)
	gm.change_state(Enums.GameState.BUILDING)
	assert_signal_emitted(gm, "state_changed")

func test_change_state_updates_current_state() -> void:
	gm.change_state(Enums.GameState.BUILDING)
	assert_eq(gm.current_state, Enums.GameState.BUILDING)

func test_change_state_no_op_same_state() -> void:
	watch_signals(gm)
	gm.change_state(Enums.GameState.MENU)
	assert_signal_not_emitted(gm, "state_changed")

# ---------------------------------------------------------------------------
# Difficulty
# ---------------------------------------------------------------------------

func test_set_difficulty_emits_signal() -> void:
	watch_signals(gm)
	gm.set_difficulty(Enums.Difficulty.HARD)
	assert_signal_emitted(gm, "difficulty_changed")

func test_set_difficulty_updates_current() -> void:
	gm.set_difficulty(Enums.Difficulty.NIGHTMARE)
	assert_eq(gm.current_difficulty, Enums.Difficulty.NIGHTMARE)

# ---------------------------------------------------------------------------
# Level start
# ---------------------------------------------------------------------------

func test_start_level_transitions_to_building() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	assert_eq(gm.current_state, Enums.GameState.BUILDING)

func test_start_level_sets_level_id() -> void:
	gm.start_level("level_02", Enums.Difficulty.HARD)
	assert_eq(gm.current_level_id, "level_02")

func test_start_level_normal_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	assert_eq(gm.lives, 20)

func test_start_level_hard_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.HARD)
	assert_eq(gm.lives, 10)

func test_start_level_nightmare_lives() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	assert_eq(gm.lives, 5)

func test_start_level_resets_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	gm.lose_life()
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	assert_eq(gm.lives_lost, 0)

func test_start_level_emits_level_started() -> void:
	watch_signals(gm)
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	assert_signal_emitted(gm, "level_started")

# ---------------------------------------------------------------------------
# Lose life
# ---------------------------------------------------------------------------

func test_lose_life_decrements() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	gm.lose_life()
	assert_eq(gm.lives, 19)

func test_lose_life_increments_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	gm.lose_life()
	gm.lose_life()
	assert_eq(gm.lives_lost, 2)

func test_lose_life_emits_signal() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	watch_signals(gm)
	gm.lose_life()
	assert_signal_emitted(gm, "lives_changed")

func test_lose_all_lives_triggers_defeat() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	# Nightmare has 5 lives
	for _i in range(5):
		gm.lose_life()
	assert_eq(gm.current_state, Enums.GameState.DEFEAT)

func test_lose_all_lives_emits_level_failed() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	watch_signals(gm)
	for _i in range(5):
		gm.lose_life()
	assert_signal_emitted(gm, "level_failed")

func test_lose_life_clamped_at_zero() -> void:
	gm.start_level("level_01", Enums.Difficulty.NIGHTMARE)
	for _i in range(10):
		gm.lose_life()
	assert_eq(gm.lives, 0, "Lives should not go below 0")

# ---------------------------------------------------------------------------
# Star calculation
# ---------------------------------------------------------------------------

func test_three_stars_no_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	assert_eq(gm.calculate_stars(), 3)

func test_two_stars_within_five_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	for _i in range(3):
		gm.lose_life()
	assert_eq(gm.calculate_stars(), 2)

func test_two_stars_exactly_five_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	for _i in range(5):
		gm.lose_life()
	assert_eq(gm.calculate_stars(), 2)

func test_one_star_more_than_five_lives_lost() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	for _i in range(6):
		gm.lose_life()
	assert_eq(gm.calculate_stars(), 1)

# ---------------------------------------------------------------------------
# Complete level
# ---------------------------------------------------------------------------

func test_complete_level_transitions_to_victory() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	gm.complete_level()
	assert_eq(gm.current_state, Enums.GameState.VICTORY)

func test_complete_level_emits_level_completed() -> void:
	gm.start_level("level_01", Enums.Difficulty.NORMAL)
	watch_signals(gm)
	gm.complete_level()
	assert_signal_emitted(gm, "level_completed")

# ---------------------------------------------------------------------------
# Game speed
# ---------------------------------------------------------------------------

func test_set_valid_speed() -> void:
	gm.set_game_speed(2.0)
	assert_almost_eq(gm.game_speed, 2.0, 0.001)

func test_set_speed_emits_signal() -> void:
	watch_signals(gm)
	gm.set_game_speed(2.0)
	assert_signal_emitted(gm, "game_speed_changed")

func test_set_invalid_speed_ignored() -> void:
	gm.set_game_speed(1.0)
	gm.set_game_speed(1.5)  # not in SPEED_OPTIONS
	assert_almost_eq(gm.game_speed, 1.0, 0.001, "Invalid speed should not change game_speed")

# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

func test_toggle_pause_from_building() -> void:
	gm.change_state(Enums.GameState.BUILDING)
	gm.toggle_pause()
	assert_eq(gm.current_state, Enums.GameState.PAUSED)

func test_toggle_pause_restores_state() -> void:
	gm.change_state(Enums.GameState.WAVE_ACTIVE)
	gm.toggle_pause()
	gm.toggle_pause()
	assert_eq(gm.current_state, Enums.GameState.WAVE_ACTIVE)
