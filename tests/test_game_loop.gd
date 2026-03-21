extends GutTest

## Tests for core/game_loop.gd

var gl: GameLoop
var gm
var em
var wm: WaveManager
var am: AdaptationManager


func before_each() -> void:
	gm = GameManager.new()
	em = EconomyManager.new()
	wm = WaveManager.new()
	am = AdaptationManager.new()
	gl = GameLoop.new()
	add_child(gm)
	add_child(em)
	add_child(wm)
	add_child(am)
	add_child(gl)
	gl.setup(gm, em, wm, am)


func after_each() -> void:
	gl.queue_free()
	am.queue_free()
	wm.queue_free()
	em.queue_free()
	gm.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_wave(wave_number: int, enemy_id: String, count: int) -> WaveDefinition:
	var wd := WaveDefinition.new()
	wd.wave_number = wave_number
	wd.sub_waves.append(SubWaveDefinition.new(enemy_id, count, 0.0, 0.0))
	return wd


func _make_waves(n: int) -> Array:
	var result: Array = []
	for i in n:
		result.append(_make_wave(i + 1, "drone", 1))
	return result


func _start_default_level() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(2))


# ---------------------------------------------------------------------------
# start_level
# ---------------------------------------------------------------------------

func test_start_level_sets_game_state_to_building() -> void:
	_start_default_level()
	assert_eq(gm.current_state, Enums.GameState.BUILDING)

func test_start_level_sets_correct_level_id() -> void:
	gl.start_level("level_99", Enums.Difficulty.NORMAL, _make_waves(1))
	assert_eq(gm.current_level_id, "level_99")

func test_start_level_applies_gold_modifier_normal() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	em.add_gold(100)
	assert_eq(em.gold, 100)  # modifier = 1.0

func test_start_level_applies_gold_modifier_hard() -> void:
	gl.start_level("level_01", Enums.Difficulty.HARD, _make_waves(1))
	em.add_gold(100)
	assert_eq(em.gold, 85)  # modifier = 0.85

func test_start_level_resets_economy() -> void:
	em.add_gold(999)
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	# After reset, gold should be 0 before any additions
	assert_eq(em.gold, 0)

# ---------------------------------------------------------------------------
# send_wave
# ---------------------------------------------------------------------------

func test_send_wave_activates_wave() -> void:
	_start_default_level()
	gl.send_wave()
	assert_true(wm.is_wave_active)

func test_send_wave_changes_state_to_wave_active() -> void:
	_start_default_level()
	gl.send_wave()
	assert_eq(gm.current_state, Enums.GameState.WAVE_ACTIVE)

func test_send_wave_no_op_when_active() -> void:
	_start_default_level()
	gl.send_wave()
	watch_signals(wm)
	gl.send_wave()
	assert_signal_not_emitted(wm, "wave_started")

func test_send_wave_no_op_when_no_more_waves() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, [])
	watch_signals(wm)
	gl.send_wave()
	assert_signal_not_emitted(wm, "wave_started")

func test_send_wave_grants_early_bonus_during_break() -> void:
	# Start level with 2 waves, complete wave 1 to enter break
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)  # spawn the single enemy
	gl.on_enemy_killed(0)  # triggers wave_complete → break starts
	# Now we are in break; send_wave should give bonus
	var gold_before: int = em.gold
	gl.send_wave()
	assert_gt(em.gold, gold_before, "Early send should add gold during break")

# ---------------------------------------------------------------------------
# on_enemy_killed
# ---------------------------------------------------------------------------

func test_on_enemy_killed_adds_gold() -> void:
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)
	gl.on_enemy_killed(25)
	assert_eq(em.gold, 25)

func test_on_enemy_killed_notifies_wave_manager() -> void:
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)
	watch_signals(wm)
	gl.on_enemy_killed(10)
	# Wave should complete (single enemy wave)
	assert_signal_emitted(wm, "wave_complete")

# ---------------------------------------------------------------------------
# on_enemy_reached_exit
# ---------------------------------------------------------------------------

func test_on_enemy_reached_exit_loses_life() -> void:
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)
	var lives_before: int = gm.lives
	gl.on_enemy_reached_exit()
	assert_eq(gm.lives, lives_before - 1)

func test_on_enemy_reached_exit_notifies_wave_manager() -> void:
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)
	watch_signals(wm)
	gl.on_enemy_reached_exit()
	assert_signal_emitted(wm, "wave_complete")

# ---------------------------------------------------------------------------
# on_wave_complete → adaptation check
# ---------------------------------------------------------------------------

func test_wave_complete_changes_state_to_wave_complete() -> void:
	_start_default_level()
	gl.send_wave()
	wm._process(0.5)
	gl.on_enemy_killed(0)
	assert_eq(gm.current_state, Enums.GameState.WAVE_COMPLETE)

func test_adaptation_checked_every_three_waves() -> void:
	# Create a 4-wave level
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(4))
	watch_signals(am)
	# Clear waves 1, 2, 3 — adaptation should fire at wave 3
	for _i in 3:
		gl.send_wave()
		wm._process(0.5)
		gl.on_enemy_killed(0)
		if wm.is_wave_active:
			# wave is still active in break — skip
			pass
		# Fast-forward any break
		wm._process(Constants.WAVE_BREAK_DURATION + 0.1)
	assert_signal_emitted(am, "adaptation_changed")

# ---------------------------------------------------------------------------
# on_all_waves_complete → victory
# ---------------------------------------------------------------------------

func test_all_waves_complete_triggers_victory_state() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	watch_signals(gl)
	gl.on_enemy_killed(0)
	assert_signal_emitted(gl, "level_victory")

func test_all_waves_complete_sets_game_state_victory() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	gl.on_enemy_killed(0)
	assert_eq(gm.current_state, Enums.GameState.VICTORY)

func test_all_waves_complete_adds_diamonds() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	gl.on_enemy_killed(0)
	# 3 stars (no lives lost), base = 50 + 3*25 = 125, mult = 1.0
	assert_eq(em.diamonds, 125)

func test_all_waves_complete_diamonds_scaled_by_difficulty() -> void:
	gl.start_level("level_01", Enums.Difficulty.NIGHTMARE, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	gl.on_enemy_killed(0)
	# 3 stars, base = 125, nightmare mult = 2.5
	assert_eq(em.diamonds, 312)  # int(125 * 2.5)

func test_victory_signal_carries_stars() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	watch_signals(gl)
	gl.on_enemy_killed(0)
	var args: Array = get_signal_parameters(gl, "level_victory")
	assert_eq(args[1], 3)  # stars — no lives lost

func test_victory_signal_carries_diamonds() -> void:
	gl.start_level("level_01", Enums.Difficulty.NORMAL, _make_waves(1))
	gl.send_wave()
	wm._process(0.5)
	watch_signals(gl)
	gl.on_enemy_killed(0)
	var args: Array = get_signal_parameters(gl, "level_victory")
	assert_eq(args[2], 125)

# ---------------------------------------------------------------------------
# on_damage_dealt
# ---------------------------------------------------------------------------

func test_on_damage_dealt_forwards_to_adaptation_manager() -> void:
	_start_default_level()
	gl.on_damage_dealt(Enums.DamageType.PULSE, 200.0)
	# Check adaptation records it by triggering check
	watch_signals(am)
	am.check_adaptation()
	assert_signal_emitted(am, "adaptation_changed")
	var args: Array = get_signal_parameters(am, "adaptation_changed")
	assert_gt(args[0].get(Enums.DamageType.PULSE, 0.0), 0.0)
