extends GutTest

## Integration test: targeting + upgrade flow working together through Tower.
## Verifies that TowerTargeting, TierTree, and Tower interact correctly.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_basic_def() -> TowerDefinition:
	var d := TowerDefinition.new()
	d.id = "pulse_cannon"
	d.display_name = "Pulse Cannon"
	d.tower_type = Enums.TowerType.PULSE_CANNON
	d.damage_type = Enums.DamageType.PULSE
	d.base_damage = 25.0
	d.base_fire_rate = 1.0
	d.base_range = 200.0
	d.cost = 100
	d.shape_sides = 8
	d.shape_radius = 16.0
	d.color = Color.CYAN
	d.tier_branches = [
		{
			"name": "rapid",
			"display_name": "Rapid Fire",
			"damage_mult": 1.0,
			"fire_rate_mult": 1.5,
			"range_mult": 1.0,
			"cost": 75,
			"special": "",
			"branches": [
				{
					"name": "overcharge",
					"display_name": "Overcharge",
					"damage_mult": 1.5,
					"fire_rate_mult": 1.0,
					"range_mult": 1.2,
					"cost": 150,
					"special": "",
					"branches": []
				}
			]
		},
		{
			"name": "power",
			"display_name": "Power Shot",
			"damage_mult": 2.0,
			"fire_rate_mult": 0.8,
			"range_mult": 1.1,
			"cost": 100,
			"special": "",
			"branches": []
		}
	]
	return d

func _make_enemy_dict(pos: Vector2, hp: float, progress: float, alive: bool = true) -> Dictionary:
	return {"position": pos, "hp": hp, "progress": progress, "alive": alive}

# ---------------------------------------------------------------------------
# Scenario 1: Tower targets FIRST enemy with targeting component
# ---------------------------------------------------------------------------

func test_tower_targets_first_via_targeting_component() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)
	tower.set_targeting_mode(Enums.TargetingMode.FIRST)

	var enemies := [
		_make_enemy_dict(Vector2(100, 0), 80.0, 0.2),
		_make_enemy_dict(Vector2(120, 0), 60.0, 0.8),   # farthest along
		_make_enemy_dict(Vector2(80, 0), 100.0, 0.5)
	]

	var idx := tower._targeting.select_target(
		tower.global_position, tower.current_range, tower.targeting_mode, enemies
	)
	assert_eq(idx, 1)

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 2: Upgrade changes stats and tower can still target correctly
# ---------------------------------------------------------------------------

func test_upgrade_then_target_with_increased_range() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)
	tower.set_targeting_mode(Enums.TargetingMode.NEAREST)

	# Enemy just outside base range
	var enemies := [_make_enemy_dict(Vector2(220, 0), 50.0, 0.5)]

	# Before upgrade: range=200, enemy at 220 → out of range
	var idx_before := tower._targeting.select_target(
		tower.global_position, tower.current_range, tower.targeting_mode, enemies
	)
	assert_eq(idx_before, -1)

	# Apply tier-2 overcharge upgrade (chain: rapid→overcharge, range_mult=1.0 then 1.2)
	# After rapid: range still 200. After overcharge: 200*1.0*1.2 = 240 → in range
	tower.apply_upgrade(0)  # rapid
	tower.apply_upgrade(0)  # overcharge

	var idx_after := tower._targeting.select_target(
		tower.global_position, tower.current_range, tower.targeting_mode, enemies
	)
	assert_eq(idx_after, 0)

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 3: Full upgrade path cost matches investment
# ---------------------------------------------------------------------------

func test_investment_matches_upgrade_costs() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	assert_eq(tower.get_total_investment(), 100)

	tower.apply_upgrade(0)  # rapid costs 75
	assert_eq(tower.get_total_investment(), 175)

	tower.apply_upgrade(0)  # overcharge costs 150
	assert_eq(tower.get_total_investment(), 325)

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 4: Buff + upgrade compound correctly
# ---------------------------------------------------------------------------

func test_buff_and_upgrade_compound_damage() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	# Upgrade to power shot: damage_mult=2.0 → 50.0
	tower.apply_upgrade(1)
	assert_almost_eq(tower.current_damage, 50.0, 0.001)

	# Apply support buff: damage_mult=1.25
	tower.apply_buff(self, 1.25, 1.0)
	# Effective = 50.0 * 1.25 = 62.5
	assert_almost_eq(tower.get_effective_damage(), 62.5, 0.001)

	# Clear buff, effective should equal base upgraded stat
	tower.clear_buff()
	assert_almost_eq(tower.get_effective_damage(), 50.0, 0.001)

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 5: TowerPlacer sell value reflects upgrade investment
# ---------------------------------------------------------------------------

func test_sell_value_after_upgrades() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)
	tower.apply_upgrade(0)  # +75 gold
	tower.apply_upgrade(0)  # +150 gold → total=325, tier=2

	var placer := TowerPlacer.new()
	add_child(placer)

	# rate = 0.7 + 2*0.02 = 0.74 → floor(325 * 0.74) = floor(240.5) = 240
	var sell_val := placer.calculate_sell_value(tower.get_total_investment(), tower.current_tier)
	assert_eq(sell_val, 240)

	placer.queue_free()
	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 6: Targeting skips dead enemies
# ---------------------------------------------------------------------------

func test_targeting_skips_dead_and_picks_alive() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)
	tower.set_targeting_mode(Enums.TargetingMode.STRONGEST)

	var enemies := [
		_make_enemy_dict(Vector2(50, 0), 500.0, 0.1, false),   # strongest but dead
		_make_enemy_dict(Vector2(60, 0), 80.0, 0.4, true),
		_make_enemy_dict(Vector2(70, 0), 120.0, 0.6, true)
	]
	var idx := tower._targeting.select_target(
		tower.global_position, tower.current_range, tower.targeting_mode, enemies
	)
	assert_eq(idx, 2)  # strongest alive enemy

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 7: Cooldown mechanics in context
# ---------------------------------------------------------------------------

func test_cooldown_matches_upgraded_fire_rate() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	# Upgrade rapid: fire_rate x1.5 → 1.5
	tower.apply_upgrade(0)
	assert_true(tower.can_fire())

	tower.on_fired()
	# Cooldown = 1/1.5 ≈ 0.667
	assert_almost_eq(tower._fire_cooldown, 1.0 / 1.5, 0.001)
	assert_false(tower.can_fire())

	# Advance past cooldown
	tower._process(0.7)
	assert_true(tower.can_fire())

	tower.queue_free()
	def.free()

# ---------------------------------------------------------------------------
# Scenario 8: UpgradeManager with real economy
# ---------------------------------------------------------------------------

func test_upgrade_manager_deducts_gold() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	eco.add_gold(200)

	var manager := UpgradeManager.new()
	add_child(manager)

	var success := manager.try_upgrade(tower, 0, eco)  # rapid costs 75
	assert_true(success)
	assert_eq(eco.gold, 125)  # 200 - 75 = 125
	assert_eq(tower.current_tier, 1)

	manager.queue_free()
	eco.queue_free()
	tower.queue_free()
	def.free()

func test_upgrade_manager_fails_when_insufficient_gold() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	eco.add_gold(50)  # not enough for rapid (75)

	var manager := UpgradeManager.new()
	add_child(manager)

	var success := manager.try_upgrade(tower, 0, eco)
	assert_false(success)
	assert_eq(eco.gold, 50)  # unchanged
	assert_eq(tower.current_tier, 0)  # unchanged

	manager.queue_free()
	eco.queue_free()
	tower.queue_free()
	def.free()

func test_upgrade_manager_emits_signal_on_success() -> void:
	var def := _make_basic_def()
	var tower := Tower.new()
	add_child(tower)
	tower.initialize(def)

	var eco := load("res://core/economy/economy_manager.gd").new()
	add_child(eco)
	eco.add_gold(500)

	var manager := UpgradeManager.new()
	add_child(manager)
	watch_signals(manager)

	manager.try_upgrade(tower, 1, eco)  # power costs 100
	assert_signal_emitted(manager, "tower_upgraded")

	manager.queue_free()
	eco.queue_free()
	tower.queue_free()
	def.free()
