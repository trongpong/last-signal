extends GutTest

## Full-game integration tests covering the campaign level flow and endless mode.

# ---------------------------------------------------------------------------
# Shared setup / teardown
# ---------------------------------------------------------------------------

var save_manager
var economy_manager
var campaign_manager: CampaignManager
var endless_manager: EndlessManager

func before_each() -> void:
	save_manager = SaveManager.new()
	save_manager.save_path = "user://test_integration_full_temp.json"
	add_child(save_manager)

	economy_manager = EconomyManager.new()
	add_child(economy_manager)

	campaign_manager = CampaignManager.new()
	add_child(campaign_manager)
	campaign_manager.setup(save_manager)

	endless_manager = EndlessManager.new()
	add_child(endless_manager)

func after_each() -> void:
	if FileAccess.file_exists(save_manager.save_path):
		DirAccess.remove_absolute(save_manager.save_path)
	endless_manager.queue_free()
	campaign_manager.queue_free()
	economy_manager.queue_free()
	save_manager.queue_free()

# ===========================================================================
# test_complete_level_flow
# ===========================================================================

## Simulate starting a level, "killing" all enemies (economy grants), completing
## the level, earning diamonds, saving, and verifying persistence.

func test_complete_level_flow_level_1_1_is_unlocked() -> void:
	assert_true(campaign_manager.is_level_unlocked("1_1"))

func test_complete_level_flow_completes_and_saves() -> void:
	# Complete level 1_1 with 3 stars on NORMAL
	campaign_manager.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)

	var record := save_manager.get_level_record("1_1")
	assert_false(record.is_empty(), "Record should exist after completion")
	assert_eq(record["best_stars"], 3)
	assert_true(record["completed"])

func test_complete_level_flow_unlocks_next() -> void:
	campaign_manager.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	assert_true(campaign_manager.is_level_unlocked("1_2"))

func test_complete_level_flow_earn_diamonds() -> void:
	# Simulate the diamond award logic from main.gd
	var constants := Constants.new()
	var mult: float = constants.DIFFICULTY_DIAMOND_MULT.get(Enums.Difficulty.NORMAL, 1.0) as float
	constants.free()
	var stars: int = 3
	var diamonds: int = int(float(stars * 10) * mult)
	economy_manager.add_diamonds(diamonds)

	assert_eq(economy_manager.diamonds, diamonds)
	assert_gt(diamonds, 0)

func test_complete_level_flow_sync_and_save() -> void:
	economy_manager.add_diamonds(30)
	save_manager.sync_economy(economy_manager)
	save_manager.save_game()

	# Load into a fresh save manager and verify
	var sm2 := SaveManager.new()
	sm2.save_path = save_manager.save_path
	add_child(sm2)
	var ok := sm2.load_game()
	assert_true(ok)
	assert_eq(sm2.data["economy"]["diamonds"], 30)
	sm2.queue_free()

func test_complete_level_flow_total_stars_accumulate() -> void:
	campaign_manager.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	campaign_manager.on_level_complete("1_2", 2, Enums.Difficulty.NORMAL)
	assert_eq(campaign_manager.get_total_stars(), 5)

func test_complete_level_flow_region_boss_awards_tower() -> void:
	# Complete all of region 1
	for n in range(1, 11):
		campaign_manager.on_level_complete("1_%d" % n, 3, Enums.Difficulty.NORMAL)
	# Complete all of region 2 to trigger beam_spire unlock
	for n in range(1, 11):
		campaign_manager.on_level_complete("2_%d" % n, 3, Enums.Difficulty.NORMAL)

	var towers: Array = save_manager.data["progression"]["towers_unlocked"]
	assert_true(towers.has("BEAM_SPIRE"), "BEAM_SPIRE should be unlocked after region 2 boss")

func test_complete_level_flow_difficulty_multiplier_hard() -> void:
	var constants := Constants.new()
	var mult: float = constants.DIFFICULTY_DIAMOND_MULT.get(Enums.Difficulty.HARD, 1.5) as float
	constants.free()
	var diamonds_hard: int = int(float(3 * 10) * mult)
	# Hard should give more diamonds than normal (1.5x)
	assert_gt(diamonds_hard, 30)

# ===========================================================================
# test_endless_mode_flow
# ===========================================================================

## Generate 25 waves, verify they scale, and record a high score.

func test_endless_mode_flow_generates_25_waves() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	var waves: Array = []
	for _i in 25:
		waves.append(endless_manager.generate_next_wave())
	assert_eq(waves.size(), 25)

func test_endless_mode_flow_wave_numbers_sequential() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	for i in 25:
		var wd: WaveDefinition = endless_manager.generate_next_wave()
		assert_eq(wd.wave_number, i + 1)

func test_endless_mode_flow_wave_10_is_boss() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	var wd: WaveDefinition = null
	for _i in 10:
		wd = endless_manager.generate_next_wave()
	assert_not_null(wd)
	assert_true(wd.is_boss_wave)

func test_endless_mode_flow_wave_20_is_boss() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	var wd: WaveDefinition = null
	for _i in 20:
		wd = endless_manager.generate_next_wave()
	assert_true(wd.is_boss_wave)

func test_endless_mode_flow_enemy_count_scales() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	var wd1: WaveDefinition = endless_manager.generate_next_wave()  # wave 1
	var wd_last: WaveDefinition = null
	# Fast-forward to wave 25 (need to regenerate since we consumed wave 1)
	endless_manager.start(Enums.Difficulty.NORMAL)
	for _i in 25:
		wd_last = endless_manager.generate_next_wave()
	assert_gt(
		wd_last.get_total_enemy_count(),
		wd1.get_total_enemy_count(),
		"Later waves should have more enemies"
	)

func test_endless_mode_flow_hard_has_more_enemies_than_normal() -> void:
	# Compare wave 5 enemy counts across difficulties
	endless_manager.start(Enums.Difficulty.NORMAL)
	var wd_normal: WaveDefinition = null
	for _i in 5:
		wd_normal = endless_manager.generate_next_wave()

	endless_manager.start(Enums.Difficulty.HARD)
	var wd_hard: WaveDefinition = null
	for _i in 5:
		wd_hard = endless_manager.generate_next_wave()

	assert_gte(
		wd_hard.get_total_enemy_count(),
		wd_normal.get_total_enemy_count(),
		"HARD should have >= enemies than NORMAL on same wave"
	)

func test_endless_mode_flow_record_high_score() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	for _i in 25:
		endless_manager.generate_next_wave()
	endless_manager.record_high_score(save_manager)
	assert_eq(endless_manager.get_high_score(Enums.Difficulty.NORMAL, save_manager), 25)

func test_endless_mode_flow_milestone_25_reached() -> void:
	watch_signals(endless_manager)
	endless_manager.start(Enums.Difficulty.NORMAL)
	for _i in 25:
		endless_manager.generate_next_wave()
	endless_manager.record_high_score(save_manager)
	assert_signal_emitted(endless_manager, "milestone_reached")

func test_endless_mode_flow_wave_25_milestone_gives_100_diamonds() -> void:
	assert_eq(endless_manager.get_milestone_diamonds(25), 100)

func test_endless_mode_flow_high_score_persisted_across_save_load() -> void:
	endless_manager.start(Enums.Difficulty.NORMAL)
	for _i in 25:
		endless_manager.generate_next_wave()
	endless_manager.record_high_score(save_manager)
	save_manager.save_game()

	var sm2 := SaveManager.new()
	sm2.save_path = save_manager.save_path
	add_child(sm2)
	sm2.load_game()
	assert_eq(sm2.data["endless"]["high_scores"].get("normal", 0), 25)
	sm2.queue_free()

# ===========================================================================
# Level content integration
# ===========================================================================

func test_level_data_1_1_has_5_waves() -> void:
	var waves := LevelData.get_waves("1_1")
	assert_eq(waves.size(), 5)

func test_level_data_1_2_has_8_waves() -> void:
	var waves := LevelData.get_waves("1_2")
	assert_eq(waves.size(), 8)

func test_level_data_1_3_has_10_waves() -> void:
	var waves := LevelData.get_waves("1_3")
	assert_eq(waves.size(), 10)

func test_level_data_1_1_last_wave_is_boss() -> void:
	var waves := LevelData.get_waves("1_1")
	var last: WaveDefinition = waves[waves.size() - 1] as WaveDefinition
	assert_true(last.is_boss_wave)

func test_level_data_1_3_wave_6_has_tank_heavy() -> void:
	var waves := LevelData.get_waves("1_3")
	var wave6: WaveDefinition = waves[5] as WaveDefinition
	var has_tank := false
	for sw in wave6.sub_waves:
		if (sw as SubWaveDefinition).enemy_id == "tank_heavy":
			has_tank = true
			break
	assert_true(has_tank, "Wave 6 of 1_3 should introduce tank_heavy")

func test_level_data_unknown_returns_empty() -> void:
	assert_eq(LevelData.get_waves("99_99").size(), 0)
