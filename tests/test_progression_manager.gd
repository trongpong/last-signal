extends GutTest

## Tests for core/progression/progression_manager.gd

var _pm: ProgressionManager
var _em
var _sm

func before_each() -> void:
	_em = load("res://core/economy/economy_manager.gd").new()
	add_child(_em)

	_sm = load("res://core/save/save_manager.gd").new()
	_sm.save_path = "user://test_progression_temp.json"
	add_child(_sm)

	_pm = ProgressionManager.new()
	add_child(_pm)
	_pm.setup(_em, _sm)

func after_each() -> void:
	_pm.queue_free()
	_em.queue_free()
	if FileAccess.file_exists(_sm.save_path):
		DirAccess.remove_absolute(_sm.save_path)
	_sm.queue_free()

# ---------------------------------------------------------------------------
# Global Upgrade: get_global_upgrade_tier
# ---------------------------------------------------------------------------

func test_initial_upgrade_tier_is_zero() -> void:
	assert_eq(_pm.get_global_upgrade_tier("starting_gold"), 0)

func test_unknown_upgrade_tier_is_zero() -> void:
	assert_eq(_pm.get_global_upgrade_tier("nonexistent"), 0)

# ---------------------------------------------------------------------------
# Global Upgrade: upgrade_global
# ---------------------------------------------------------------------------

func test_upgrade_global_fails_without_diamonds() -> void:
	var result := _pm.upgrade_global("starting_gold")
	assert_false(result)

func test_upgrade_global_succeeds_with_diamonds() -> void:
	_em.add_diamonds(500)
	var result := _pm.upgrade_global("starting_gold")
	assert_true(result)

func test_upgrade_global_increments_tier() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("starting_gold")
	assert_eq(_pm.get_global_upgrade_tier("starting_gold"), 1)

func test_upgrade_global_spends_correct_cost() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("starting_gold")
	# GLOBAL_UPGRADE_COSTS[0] = 50
	assert_eq(_em.diamonds, 450)

func test_upgrade_global_emits_signal() -> void:
	_em.add_diamonds(500)
	watch_signals(_pm)
	_pm.upgrade_global("starting_gold")
	assert_signal_emitted(_pm, "global_upgraded")

func test_upgrade_global_fails_at_max_tier() -> void:
	_em.add_diamonds(99999)
	for _i in range(10):
		_pm.upgrade_global("starting_gold")
	var result := _pm.upgrade_global("starting_gold")
	assert_false(result)

func test_upgrade_global_unknown_id_returns_false() -> void:
	_em.add_diamonds(500)
	var result := _pm.upgrade_global("nonexistent_upgrade")
	assert_false(result)

# ---------------------------------------------------------------------------
# Global Upgrade Getters
# ---------------------------------------------------------------------------

func test_starting_gold_bonus_at_tier_0_is_zero() -> void:
	assert_eq(_pm.get_starting_gold_bonus(), 0)

func test_starting_gold_bonus_at_tier_1() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("starting_gold")
	assert_eq(_pm.get_starting_gold_bonus(), 25)

func test_extra_lives_at_tier_0_is_zero() -> void:
	assert_eq(_pm.get_extra_lives(), 0)

func test_tower_cost_discount_at_tier_0_is_zero() -> void:
	assert_eq(_pm.get_tower_cost_discount(), 0)

func test_ability_cooldown_reduction_at_tier_0_is_zero() -> void:
	assert_almost_eq(_pm.get_ability_cooldown_reduction(), 0.0, 0.001)

func test_sell_refund_bonus_at_tier_0_is_zero() -> void:
	assert_eq(_pm.get_sell_refund_bonus(), 0)

func test_hero_duration_bonus_at_tier_0_is_zero() -> void:
	assert_almost_eq(_pm.get_hero_duration_bonus(), 0.0, 0.001)

func test_gold_per_kill_bonus_at_tier_0_is_zero() -> void:
	assert_eq(_pm.get_gold_per_kill_bonus(), 0)

func test_hero_duration_bonus_after_upgrade() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("hero_duration")
	assert_almost_eq(_pm.get_hero_duration_bonus(), 1.0, 0.001)

func test_ability_cooldown_reduction_after_two_upgrades() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("ability_cooldown")
	_pm.upgrade_global("ability_cooldown")
	assert_almost_eq(_pm.get_ability_cooldown_reduction(), 4.0, 0.001)

# ---------------------------------------------------------------------------
# Skill Node Unlock
# ---------------------------------------------------------------------------

func test_unlock_skill_node_fails_without_diamonds() -> void:
	var result := _pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	assert_false(result)

func test_unlock_skill_node_succeeds_with_diamonds() -> void:
	_em.add_diamonds(500)
	var result := _pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	assert_true(result)

func test_unlock_skill_node_emits_signal() -> void:
	_em.add_diamonds(500)
	watch_signals(_pm)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	assert_signal_emitted(_pm, "skill_unlocked")

func test_unlock_skill_node_spends_diamonds() -> void:
	_em.add_diamonds(500)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	# SKILL_NODE_COSTS[0] = 80
	assert_eq(_em.diamonds, 420)

func test_unlock_skill_node_can_level_up_multiple_times() -> void:
	_em.add_diamonds(5000)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	var result := _pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	assert_true(result)

func test_unlock_skill_node_fails_at_max_level() -> void:
	_em.add_diamonds(99999)
	# Max level is 5
	for _i in range(5):
		_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	var result := _pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	assert_false(result)

func test_unlock_skill_nodes_are_independent() -> void:
	_em.add_diamonds(5000)
	# All 5 skills can be leveled independently (no prerequisites)
	var result := _pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 1)
	assert_true(result)

# ---------------------------------------------------------------------------
# get_skill_bonuses
# ---------------------------------------------------------------------------

func test_skill_bonuses_no_unlocks_returns_zeros() -> void:
	var bonuses := _pm.get_skill_bonuses(Enums.TowerType.PULSE_CANNON)
	assert_almost_eq(bonuses["damage"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["range"] as float, 0.0, 0.001)

func test_skill_bonuses_after_unlocking_first_node() -> void:
	_em.add_diamonds(5000)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	var bonuses := _pm.get_skill_bonuses(Enums.TowerType.PULSE_CANNON)
	# Focused Beam grants 3.0 damage per level, at level 1 = 3.0
	assert_almost_eq(bonuses["damage"] as float, 3.0, 0.001)

# ---------------------------------------------------------------------------
# Hero Unlock
# ---------------------------------------------------------------------------

func test_hero_not_unlocked_initially() -> void:
	assert_false(_pm.is_hero_unlocked(Enums.TowerType.PULSE_CANNON))

func test_skill_bonuses_scale_with_level() -> void:
	_em.add_diamonds(99999)
	# Focused Beam grants 3.0 damage per level
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	var bonuses := _pm.get_skill_bonuses(Enums.TowerType.PULSE_CANNON)
	# Level 3 x 3.0 = 9.0 damage
	assert_almost_eq(bonuses["damage"] as float, 9.0, 0.001)

func test_multiple_skills_combine_bonuses() -> void:
	_em.add_diamonds(99999)
	# Focused Beam (node 0): 3.0 damage per level
	# Overcharge Protocol (node 4): 5.0 damage + 0.03 fire rate per level
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 4)
	var bonuses := _pm.get_skill_bonuses(Enums.TowerType.PULSE_CANNON)
	# 3.0 + 5.0 = 8.0 damage total
	assert_almost_eq(bonuses["damage"] as float, 8.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.03, 0.001)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_save_and_reload_preserves_upgrade_tier() -> void:
	_em.add_diamonds(500)
	_pm.upgrade_global("starting_gold")

	var pm2 := ProgressionManager.new()
	add_child(pm2)
	pm2.setup(_em, _sm)
	assert_eq(pm2.get_global_upgrade_tier("starting_gold"), 1)
	pm2.queue_free()

func test_save_and_reload_preserves_skill_levels() -> void:
	_em.add_diamonds(5000)
	_pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)

	var pm2 := ProgressionManager.new()
	add_child(pm2)
	pm2.setup(_em, _sm)
	var bonuses := pm2.get_skill_bonuses(Enums.TowerType.PULSE_CANNON)
	# Focused Beam at level 1 = 3.0 damage
	assert_almost_eq(bonuses["damage"] as float, 3.0, 0.001)
	pm2.queue_free()
