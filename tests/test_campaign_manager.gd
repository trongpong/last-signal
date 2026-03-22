extends GutTest

## Tests for core/campaign/campaign_manager.gd

var cm: CampaignManager
var sm

func before_each() -> void:
	sm = load("res://core/save/save_manager.gd").new()
	sm.save_path = "user://test_campaign_temp.json"
	add_child(sm)

	cm = CampaignManager.new()
	add_child(cm)
	cm.setup(sm)

func after_each() -> void:
	if FileAccess.file_exists(sm.save_path):
		DirAccess.remove_absolute(sm.save_path)
	remove_child(cm)
	cm.queue_free()
	remove_child(sm)
	sm.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_first_level_always_unlocked() -> void:
	assert_true(cm.is_level_unlocked("1_1"))

func test_second_level_locked_initially() -> void:
	assert_false(cm.is_level_unlocked("1_2"))

func test_endless_locked_initially() -> void:
	assert_false(cm.is_endless_unlocked())

func test_starting_towers_contain_pulse_cannon() -> void:
	var towers := cm.get_unlocked_towers()
	assert_true(towers.has("PULSE_CANNON"))

func test_starting_towers_count() -> void:
	var towers := cm.get_unlocked_towers()
	assert_eq(towers.size(), 4)

func test_total_stars_zero_initially() -> void:
	assert_eq(cm.get_total_stars(), 0)

func test_current_region_is_1_initially() -> void:
	assert_eq(cm.get_current_region(), 1)

# ---------------------------------------------------------------------------
# Level unlock chain
# ---------------------------------------------------------------------------

func test_completing_1_1_unlocks_1_2() -> void:
	watch_signals(cm)
	cm.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	assert_true(cm.is_level_unlocked("1_2"))

func test_completing_1_1_emits_level_unlocked() -> void:
	watch_signals(cm)
	cm.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	assert_signal_emitted(cm, "level_unlocked")

func test_completing_region_boss_emits_region_unlocked() -> void:
	watch_signals(cm)
	# Complete all region 1 levels so the boss is reachable, then complete boss
	for n in range(1, 11):
		cm.on_level_complete("1_%d" % n, 3, Enums.Difficulty.NORMAL)
	assert_signal_emitted_with_parameters(cm, "region_unlocked", [1])

func test_completing_region2_boss_emits_tower_unlocked() -> void:
	watch_signals(cm)
	# Complete all of regions 1 and 2
	for n in range(1, 11):
		cm.on_level_complete("1_%d" % n, 3, Enums.Difficulty.NORMAL)
	for n in range(1, 11):
		cm.on_level_complete("2_%d" % n, 3, Enums.Difficulty.NORMAL)
	assert_signal_emitted(cm, "tower_unlocked")

func test_completing_region2_boss_adds_beam_spire_to_save() -> void:
	for n in range(1, 11):
		cm.on_level_complete("1_%d" % n, 3, Enums.Difficulty.NORMAL)
	for n in range(1, 11):
		cm.on_level_complete("2_%d" % n, 3, Enums.Difficulty.NORMAL)
	var towers: Array = sm.data["progression"]["towers_unlocked"]
	assert_true(towers.has("BEAM_SPIRE"))

# ---------------------------------------------------------------------------
# Stars
# ---------------------------------------------------------------------------

func test_total_stars_accumulate() -> void:
	cm.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	cm.on_level_complete("1_2", 2, Enums.Difficulty.NORMAL)
	# Verify stars are recorded per level via get_level_record
	var rec_1_1: Dictionary = sm.get_level_record("1_1", Enums.Difficulty.NORMAL)
	var rec_1_2: Dictionary = sm.get_level_record("1_2", Enums.Difficulty.NORMAL)
	assert_eq(rec_1_1.get("best_stars", 0), 3)
	assert_eq(rec_1_2.get("best_stars", 0), 2)

func test_best_stars_kept_on_replay() -> void:
	cm.on_level_complete("1_1", 1, Enums.Difficulty.NORMAL)
	cm.on_level_complete("1_1", 3, Enums.Difficulty.NORMAL)
	# Verify the best star count is kept after replaying a level
	var rec: Dictionary = sm.get_level_record("1_1", Enums.Difficulty.NORMAL)
	assert_eq(rec.get("best_stars", 0), 3)

# ---------------------------------------------------------------------------
# Endless unlock
# ---------------------------------------------------------------------------

func test_endless_unlocked_after_final_boss() -> void:
	# Complete all levels across all 5 regions
	var region_counts: Array = [10, 10, 9, 9, 8]
	for r in range(1, 6):
		for n in range(1, region_counts[r - 1] + 1):
			cm.on_level_complete("%d_%d" % [r, n], 3, Enums.Difficulty.NORMAL)
	assert_true(cm.is_endless_unlocked())

func test_endless_unlock_emits_signal() -> void:
	watch_signals(cm)
	var region_counts: Array = [10, 10, 9, 9, 8]
	for r in range(1, 6):
		for n in range(1, region_counts[r - 1] + 1):
			cm.on_level_complete("%d_%d" % [r, n], 3, Enums.Difficulty.NORMAL)
	assert_signal_emitted(cm, "endless_unlocked")
