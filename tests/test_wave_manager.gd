extends GutTest

## Tests for core/wave_system/wave_manager.gd

var wm: WaveManager

func before_each() -> void:
	wm = WaveManager.new()
	add_child(wm)


func after_each() -> void:
	wm.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_wave(wave_number: int, enemy_id: String, count: int, is_boss: bool = false) -> WaveDefinition:
	var wd := WaveDefinition.new()
	wd.wave_number = wave_number
	wd.is_boss_wave = is_boss
	wd.sub_waves.append(SubWaveDefinition.new(enemy_id, count, 0.0, 0.0))
	return wd


func _make_two_wave_list() -> Array:
	return [
		_make_wave(1, "scout", 2),
		_make_wave(2, "tank", 3),
	]


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_wave_index_is_minus_one() -> void:
	assert_eq(wm.current_wave_index, -1)

func test_initial_total_waves_is_zero() -> void:
	assert_eq(wm.total_waves, 0)

func test_initial_is_wave_active_false() -> void:
	assert_false(wm.is_wave_active)

# ---------------------------------------------------------------------------
# load_waves
# ---------------------------------------------------------------------------

func test_load_waves_sets_total_waves() -> void:
	wm.load_waves(_make_two_wave_list())
	assert_eq(wm.total_waves, 2)

func test_load_waves_resets_index() -> void:
	wm.load_waves(_make_two_wave_list())
	assert_eq(wm.current_wave_index, -1)

func test_load_waves_resets_active_flag() -> void:
	wm.load_waves(_make_two_wave_list())
	assert_false(wm.is_wave_active)

# ---------------------------------------------------------------------------
# has_more_waves
# ---------------------------------------------------------------------------

func test_has_more_waves_true_after_load() -> void:
	wm.load_waves(_make_two_wave_list())
	assert_true(wm.has_more_waves())

func test_has_more_waves_false_empty() -> void:
	wm.load_waves([])
	assert_false(wm.has_more_waves())

# ---------------------------------------------------------------------------
# start_next_wave
# ---------------------------------------------------------------------------

func test_start_next_wave_sets_active() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	assert_true(wm.is_wave_active)

func test_start_next_wave_increments_index() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	assert_eq(wm.current_wave_index, 0)

func test_start_next_wave_emits_wave_started() -> void:
	wm.load_waves(_make_two_wave_list())
	watch_signals(wm)
	wm.start_next_wave()
	assert_signal_emitted(wm, "wave_started")

func test_start_next_wave_signal_has_correct_wave_number() -> void:
	wm.load_waves(_make_two_wave_list())
	watch_signals(wm)
	wm.start_next_wave()
	var args: Array = get_signal_parameters(wm, "wave_started")
	assert_eq(args[0], 1)  # wave_number

func test_start_next_wave_signal_has_total_waves() -> void:
	wm.load_waves(_make_two_wave_list())
	watch_signals(wm)
	wm.start_next_wave()
	var args: Array = get_signal_parameters(wm, "wave_started")
	assert_eq(args[1], 2)  # total_waves

func test_start_next_wave_no_op_when_active() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	watch_signals(wm)
	wm.start_next_wave()  # should be ignored
	assert_signal_not_emitted(wm, "wave_started")

func test_start_next_wave_no_op_when_no_more_waves() -> void:
	wm.load_waves([_make_wave(1, "drone", 1)])
	wm.start_next_wave()
	# Simulate clearing the only wave
	wm.on_enemy_died()
	# Now no more waves
	watch_signals(wm)
	wm.start_next_wave()
	assert_signal_not_emitted(wm, "wave_started")

# ---------------------------------------------------------------------------
# Spawn queue / enemy_spawn_requested
# ---------------------------------------------------------------------------

func test_enemy_spawn_requested_emitted_for_zero_delay() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 1, 0.0, 0.0))
	wm.load_waves([wd])
	watch_signals(wm)
	wm.start_next_wave()
	# Advance time enough to trigger spawn
	wm._process(0.1)
	assert_signal_emitted(wm, "enemy_spawn_requested")

func test_spawn_uses_correct_enemy_id() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("scout_basic", 1, 0.0, 0.0))
	wm.load_waves([wd])
	watch_signals(wm)
	wm.start_next_wave()
	wm._process(0.1)
	var args: Array = get_signal_parameters(wm, "enemy_spawn_requested")
	assert_eq(args[0], "scout_basic")

# ---------------------------------------------------------------------------
# Wave clear / wave_complete
# ---------------------------------------------------------------------------

func test_wave_complete_emitted_after_all_enemies_die() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 2, 0.0, 0.0))
	wm.load_waves([wd])
	wm.start_next_wave()
	wm._process(0.5)  # spawn both
	watch_signals(wm)
	wm.on_enemy_died()
	wm.on_enemy_died()
	assert_signal_emitted(wm, "wave_complete")

func test_wave_complete_not_emitted_until_all_dead() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 2, 0.0, 0.0))
	wm.load_waves([wd])
	wm.start_next_wave()
	wm._process(0.5)
	watch_signals(wm)
	wm.on_enemy_died()
	assert_signal_not_emitted(wm, "wave_complete")

func test_is_wave_active_false_after_clear() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 1, 0.0, 0.0))
	wm.load_waves([wd])
	wm.start_next_wave()
	wm._process(0.5)
	wm.on_enemy_died()
	assert_false(wm.is_wave_active)

# ---------------------------------------------------------------------------
# all_waves_complete
# ---------------------------------------------------------------------------

func test_all_waves_complete_emitted_after_last_wave() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 1, 0.0, 0.0))
	wm.load_waves([wd])
	wm.start_next_wave()
	wm._process(0.5)
	watch_signals(wm)
	wm.on_enemy_died()
	assert_signal_emitted(wm, "all_waves_complete")

func test_break_started_emitted_between_waves() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	wm._process(0.5)
	watch_signals(wm)
	wm.on_enemy_died()
	wm.on_enemy_died()
	assert_signal_emitted(wm, "break_started")

# ---------------------------------------------------------------------------
# Break + auto-start
# ---------------------------------------------------------------------------

func test_break_timer_emits_send_request() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	wm._process(0.5)
	wm.on_enemy_died()
	wm.on_enemy_died()
	# Fast-forward through the break — should emit break_skip_requested
	watch_signals(wm)
	wm._process(Constants.WAVE_BREAK_DURATION + 0.1)
	assert_signal_emitted(wm, "break_skip_requested")

# ---------------------------------------------------------------------------
# on_enemy_reached_exit
# ---------------------------------------------------------------------------

func test_on_enemy_reached_exit_counts_toward_clear() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	wd.sub_waves.append(SubWaveDefinition.new("drone", 1, 0.0, 0.0))
	wm.load_waves([wd])
	wm.start_next_wave()
	wm._process(0.5)
	watch_signals(wm)
	wm.on_enemy_reached_exit()
	assert_signal_emitted(wm, "wave_complete")

# ---------------------------------------------------------------------------
# Early send bonus
# ---------------------------------------------------------------------------

func test_get_early_send_bonus_zero_outside_break() -> void:
	wm.load_waves(_make_two_wave_list())
	assert_eq(wm.get_early_send_bonus(), 0)

func test_get_early_send_bonus_positive_during_break() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	wm._process(0.5)
	wm.on_enemy_died()
	wm.on_enemy_died()
	# We are now in a break
	var bonus: int = wm.get_early_send_bonus()
	assert_gt(bonus, 0)

func test_get_early_send_bonus_max_at_break_start() -> void:
	wm.load_waves(_make_two_wave_list())
	wm.start_next_wave()
	wm._process(0.5)
	wm.on_enemy_died()
	wm.on_enemy_died()
	# Immediately after break starts bonus should be ~max
	var bonus: int = wm.get_early_send_bonus()
	assert_almost_eq(float(bonus), float(Constants.EARLY_SEND_GOLD_BONUS), 5.0)

# ---------------------------------------------------------------------------
# SubWaveDefinition path_index
# ---------------------------------------------------------------------------

func test_sub_wave_path_index_default() -> void:
	var sw := SubWaveDefinition.new("scout_basic", 5, 0.5, 0.0)
	assert_eq(sw.path_index, 0, "Default path_index should be 0")

func test_sub_wave_path_index_explicit() -> void:
	var sw := SubWaveDefinition.new("scout_basic", 5, 0.5, 0.0, 2)
	assert_eq(sw.path_index, 2, "Explicit path_index should be 2")

# ---------------------------------------------------------------------------
# path_index propagation through signal
# ---------------------------------------------------------------------------

func test_spawn_signal_includes_path_index() -> void:
	var wm := WaveManager.new()
	add_child(wm)
	var wd := WaveDefinition.new()
	wd.wave_number = 1
	var sw := SubWaveDefinition.new("scout_basic", 1, 0.1, 0.0, 1)
	wd.sub_waves = [sw]
	wm.load_waves([wd])

	watch_signals(wm)
	wm.start_next_wave()
	for i in range(20):
		wm._process(0.1)
	assert_signal_emitted(wm, "enemy_spawn_requested")
	var args = get_signal_parameters(wm, "enemy_spawn_requested")
	assert_eq(args[1], 1, "Signal should include path_index from sub-wave")
	wm.queue_free()
