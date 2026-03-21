extends GutTest

## Tests for core/endless/endless_manager.gd

var em: EndlessManager
var sm: SaveManager

func before_each() -> void:
	sm = SaveManager.new()
	sm.save_path = "user://test_endless_temp.json"
	add_child(sm)

	em = EndlessManager.new()
	add_child(em)
	em.start(Enums.Difficulty.NORMAL)

func after_each() -> void:
	if FileAccess.file_exists(sm.save_path):
		DirAccess.remove_absolute(sm.save_path)
	em.queue_free()
	sm.queue_free()

# ---------------------------------------------------------------------------
# Milestones
# ---------------------------------------------------------------------------

func test_wave_10_is_milestone() -> void:
	assert_true(em.is_milestone(10))

func test_wave_25_is_milestone() -> void:
	assert_true(em.is_milestone(25))

func test_wave_50_is_milestone() -> void:
	assert_true(em.is_milestone(50))

func test_wave_75_is_milestone() -> void:
	assert_true(em.is_milestone(75))

func test_wave_100_is_milestone() -> void:
	assert_true(em.is_milestone(100))

func test_wave_11_not_milestone() -> void:
	assert_false(em.is_milestone(11))

func test_milestone_diamonds_wave_10() -> void:
	assert_eq(em.get_milestone_diamonds(10), 50)

func test_milestone_diamonds_wave_100() -> void:
	assert_eq(em.get_milestone_diamonds(100), 500)

func test_non_milestone_gives_zero_diamonds() -> void:
	assert_eq(em.get_milestone_diamonds(7), 0)

# ---------------------------------------------------------------------------
# Wave generation
# ---------------------------------------------------------------------------

func test_generate_next_wave_returns_wave_definition() -> void:
	var wd: WaveDefinition = em.generate_next_wave()
	assert_not_null(wd)

func test_generate_next_wave_increments_wave_number() -> void:
	var wd1 := em.generate_next_wave()
	var wd2 := em.generate_next_wave()
	assert_eq(wd2.wave_number, wd1.wave_number + 1)

func test_generate_wave_has_sub_waves() -> void:
	var wd := em.generate_next_wave()
	assert_gt(wd.sub_waves.size(), 0)

func test_wave_10_is_boss_wave() -> void:
	var wd: WaveDefinition = null
	for _i in 10:
		wd = em.generate_next_wave()
	assert_not_null(wd)
	assert_true(wd.is_boss_wave)

# ---------------------------------------------------------------------------
# High scores
# ---------------------------------------------------------------------------

func test_initial_high_score_is_zero() -> void:
	assert_eq(em.get_high_score(Enums.Difficulty.NORMAL, sm), 0)

func test_record_high_score_stores_wave() -> void:
	em.generate_next_wave()  # wave 1
	em.generate_next_wave()  # wave 2
	em.record_high_score(sm)
	assert_eq(em.get_high_score(Enums.Difficulty.NORMAL, sm), 2)

func test_high_score_not_overwritten_by_lower() -> void:
	# Simulate a run reaching wave 5
	for _i in 5:
		em.generate_next_wave()
	em.record_high_score(sm)

	# Restart and only reach wave 2
	em.start(Enums.Difficulty.NORMAL)
	for _i in 2:
		em.generate_next_wave()
	em.record_high_score(sm)

	assert_eq(em.get_high_score(Enums.Difficulty.NORMAL, sm), 5)

func test_high_scores_separate_per_difficulty() -> void:
	for _i in 3:
		em.generate_next_wave()
	em.record_high_score(sm)

	em.start(Enums.Difficulty.HARD)
	for _i in 7:
		em.generate_next_wave()
	em.record_high_score(sm)

	assert_eq(em.get_high_score(Enums.Difficulty.NORMAL, sm), 3)
	assert_eq(em.get_high_score(Enums.Difficulty.HARD, sm), 7)

# ---------------------------------------------------------------------------
# Milestone signal
# ---------------------------------------------------------------------------

func test_milestone_signal_emitted_at_wave_10() -> void:
	watch_signals(em)
	for _i in 10:
		em.generate_next_wave()
	em.record_high_score(sm)
	assert_signal_emitted(em, "milestone_reached")
