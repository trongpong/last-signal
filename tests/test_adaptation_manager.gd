extends GutTest

## Tests for core/adaptation/adaptation_manager.gd

var am: AdaptationManager

func before_each() -> void:
	am = AdaptationManager.new()
	add_child(am)
	am.setup(Enums.Difficulty.NORMAL, false)


func after_each() -> void:
	am.queue_free()


# ---------------------------------------------------------------------------
# Initial state after setup
# ---------------------------------------------------------------------------

func test_initial_resistances_empty() -> void:
	assert_eq(am.get_resistances().size(), 0)

func test_get_resistances_returns_copy() -> void:
	var r1: Dictionary = am.get_resistances()
	r1[Enums.DamageType.PULSE] = 0.9
	assert_eq(am.get_resistances().size(), 0, "Modifying returned dict should not affect internal state")

# ---------------------------------------------------------------------------
# record_damage
# ---------------------------------------------------------------------------

func test_record_damage_accumulates() -> void:
	am.record_damage(Enums.DamageType.PULSE, 100.0)
	am.record_damage(Enums.DamageType.PULSE, 50.0)
	am.check_adaptation()
	# 150 / 150 = 100% share → should gain resistance
	var res: Dictionary = am.get_resistances()
	assert_gt(res.get(Enums.DamageType.PULSE, 0.0), 0.0)

# ---------------------------------------------------------------------------
# check_adaptation — dominant type gains resistance
# ---------------------------------------------------------------------------

func test_dominant_type_gains_resistance() -> void:
	# NORMAL threshold is 0.4; PULSE = 100%, so it exceeds threshold
	am.record_damage(Enums.DamageType.PULSE, 1000.0)
	am.check_adaptation()
	var res: Dictionary = am.get_resistances()
	assert_almost_eq(
		res.get(Enums.DamageType.PULSE, 0.0),
		Constants.ADAPTATION_RESISTANCE_INCREMENT,
		0.0001
	)

func test_multiple_checks_stack_resistance() -> void:
	for i in 3:
		am.record_damage(Enums.DamageType.BEAM, 1000.0)
		am.check_adaptation()
		am.start_new_wave_window()
	var expected: float = Constants.ADAPTATION_RESISTANCE_INCREMENT * 3
	var res: Dictionary = am.get_resistances()
	assert_almost_eq(res.get(Enums.DamageType.BEAM, 0.0), expected, 0.0001)

func test_resistance_capped_at_max() -> void:
	# Force many ticks to saturate
	var ticks_needed: int = int(
		ceil(Constants.ADAPTATION_MAX_RESISTANCE / Constants.ADAPTATION_RESISTANCE_INCREMENT)
	) + 5
	for _i in ticks_needed:
		am.record_damage(Enums.DamageType.CRYO, 1000.0)
		am.check_adaptation()
		am.start_new_wave_window()
	var res: Dictionary = am.get_resistances()
	assert_almost_eq(
		res.get(Enums.DamageType.CRYO, 0.0),
		Constants.ADAPTATION_MAX_RESISTANCE,
		0.0001
	)

# ---------------------------------------------------------------------------
# check_adaptation — non-dominant type decays
# ---------------------------------------------------------------------------

func test_non_dominant_type_decays() -> void:
	# First, build up resistance for PULSE
	for _i in 3:
		am.record_damage(Enums.DamageType.PULSE, 1000.0)
		am.check_adaptation()
		am.start_new_wave_window()
	# Now use mostly ARC so PULSE share is below threshold
	am.record_damage(Enums.DamageType.ARC, 1000.0)
	am.record_damage(Enums.DamageType.PULSE, 10.0)  # < 40% share
	var before: float = am.get_resistances().get(Enums.DamageType.PULSE, 0.0)
	am.check_adaptation()
	var after: float = am.get_resistances().get(Enums.DamageType.PULSE, 0.0)
	assert_lt(after, before)

func test_resistance_decays_to_zero_and_is_removed() -> void:
	# Build one tick of resistance
	am.record_damage(Enums.DamageType.MISSILE, 1000.0)
	am.check_adaptation()
	am.start_new_wave_window()
	# Now use a different type exclusively to trigger decay
	for _i in 20:
		am.record_damage(Enums.DamageType.NANO, 1000.0)
		am.check_adaptation()
		am.start_new_wave_window()
	var res: Dictionary = am.get_resistances()
	assert_false(res.has(Enums.DamageType.MISSILE), "Decayed-to-zero type should be absent")

# ---------------------------------------------------------------------------
# check_adaptation — no damage recorded
# ---------------------------------------------------------------------------

func test_check_with_no_damage_emits_signal() -> void:
	watch_signals(am)
	am.check_adaptation()
	assert_signal_emitted(am, "adaptation_changed")

func test_check_with_no_damage_does_not_change_resistances() -> void:
	am.get_resistances()  # baseline empty
	am.check_adaptation()
	assert_eq(am.get_resistances().size(), 0)

# ---------------------------------------------------------------------------
# start_new_wave_window
# ---------------------------------------------------------------------------

func test_start_new_wave_window_clears_damage_log() -> void:
	am.record_damage(Enums.DamageType.PULSE, 500.0)
	am.start_new_wave_window()
	# If log was cleared, check_adaptation with new log shouldn't pick up old damage
	am.record_damage(Enums.DamageType.ARC, 100.0)
	am.check_adaptation()
	var res: Dictionary = am.get_resistances()
	# ARC is 100% of fresh log — should gain resistance
	assert_gt(res.get(Enums.DamageType.ARC, 0.0), 0.0)
	# PULSE from before the window clear should NOT have gained resistance
	assert_false(res.has(Enums.DamageType.PULSE))

func test_start_new_wave_window_does_not_reset_resistances() -> void:
	am.record_damage(Enums.DamageType.BEAM, 1000.0)
	am.check_adaptation()
	var before: float = am.get_resistances().get(Enums.DamageType.BEAM, 0.0)
	am.start_new_wave_window()
	var after: float = am.get_resistances().get(Enums.DamageType.BEAM, 0.0)
	assert_almost_eq(after, before, 0.0001)

# ---------------------------------------------------------------------------
# reset
# ---------------------------------------------------------------------------

func test_reset_clears_resistances() -> void:
	am.record_damage(Enums.DamageType.PULSE, 1000.0)
	am.check_adaptation()
	am.reset()
	assert_eq(am.get_resistances().size(), 0)

func test_reset_clears_damage_log() -> void:
	am.record_damage(Enums.DamageType.CRYO, 500.0)
	am.reset()
	am.check_adaptation()
	assert_eq(am.get_resistances().size(), 0)

# ---------------------------------------------------------------------------
# Endless mode — higher max resistance
# ---------------------------------------------------------------------------

func test_endless_mode_higher_cap() -> void:
	var endless_am := AdaptationManager.new()
	add_child(endless_am)
	endless_am.setup(Enums.Difficulty.NIGHTMARE, true)
	var ticks_needed: int = int(
		ceil(Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS / Constants.ADAPTATION_RESISTANCE_INCREMENT)
	) + 10
	for _i in ticks_needed:
		endless_am.record_damage(Enums.DamageType.HARVEST, 1000.0)
		endless_am.check_adaptation()
		endless_am.start_new_wave_window()
	var res: Dictionary = endless_am.get_resistances()
	assert_almost_eq(
		res.get(Enums.DamageType.HARVEST, 0.0),
		Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS,
		0.0001
	)
	endless_am.queue_free()

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func test_check_adaptation_emits_adaptation_changed() -> void:
	am.record_damage(Enums.DamageType.PULSE, 1000.0)
	watch_signals(am)
	am.check_adaptation()
	assert_signal_emitted(am, "adaptation_changed")

func test_adaptation_changed_passes_resistance_dict() -> void:
	am.record_damage(Enums.DamageType.ARC, 1000.0)
	watch_signals(am)
	am.check_adaptation()
	var args: Array = get_signal_parameters(am, "adaptation_changed")
	assert_true(args[0] is Dictionary)
