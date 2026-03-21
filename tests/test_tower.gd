extends GutTest

## Tests for core/tower_system/tower.gd

var _tower: Tower
var _def: TowerDefinition

func _make_def(damage: float = 25.0, fire_rate: float = 1.0, range_val: float = 200.0, cost: int = 100) -> TowerDefinition:
	var d := TowerDefinition.new()
	d.id = "test_tower"
	d.display_name = "Test Tower"
	d.tower_type = Enums.TowerType.PULSE_CANNON
	d.damage_type = Enums.DamageType.PULSE
	d.base_damage = damage
	d.base_fire_rate = fire_rate
	d.base_range = range_val
	d.cost = cost
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
					"name": "rapid2",
					"display_name": "Rapid Fire II",
					"damage_mult": 1.2,
					"fire_rate_mult": 1.2,
					"range_mult": 1.0,
					"cost": 125,
					"special": "",
					"branches": []
				}
			]
		},
		{
			"name": "power",
			"display_name": "Power Shot",
			"damage_mult": 2.0,
			"fire_rate_mult": 0.7,
			"range_mult": 1.1,
			"cost": 100,
			"special": "",
			"branches": []
		}
	]
	return d

func before_each() -> void:
	_def = _make_def()
	_tower = Tower.new()
	add_child(_tower)
	_tower.initialize(_def)

func after_each() -> void:
	if is_instance_valid(_tower):
		_tower.queue_free()
	_def.free()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func test_initialized_flag_set() -> void:
	assert_true(_tower._initialized)

func test_base_damage_set() -> void:
	assert_almost_eq(_tower.current_damage, 25.0, 0.001)

func test_base_fire_rate_set() -> void:
	assert_almost_eq(_tower.current_fire_rate, 1.0, 0.001)

func test_base_range_set() -> void:
	assert_almost_eq(_tower.current_range, 200.0, 0.001)

func test_current_tier_zero() -> void:
	assert_eq(_tower.current_tier, 0)

func test_upgrade_path_empty() -> void:
	assert_eq(_tower.get_upgrade_path().size(), 0)

func test_targeting_component_created() -> void:
	assert_not_null(_tower._targeting)

func test_renderer_component_created() -> void:
	assert_not_null(_tower._renderer)

func test_tier_tree_created() -> void:
	assert_not_null(_tower._tier_tree)

# ---------------------------------------------------------------------------
# Firing
# ---------------------------------------------------------------------------

func test_can_fire_when_cooldown_zero() -> void:
	assert_true(_tower.can_fire())

func test_on_fired_sets_cooldown() -> void:
	_tower.on_fired()
	assert_gt(_tower._fire_cooldown, 0.0)

func test_cannot_fire_during_cooldown() -> void:
	_tower.on_fired()
	assert_false(_tower.can_fire())

func test_cooldown_decreases_over_time() -> void:
	_tower.on_fired()
	var initial: float = _tower._fire_cooldown
	_tower._process(0.1)
	assert_lt(_tower._fire_cooldown, initial)

func test_can_fire_again_after_cooldown_expires() -> void:
	_tower.on_fired()
	# Fire rate = 1.0 → cooldown = 1.0s; advance 1.1s
	_tower._process(1.1)
	assert_true(_tower.can_fire())

func test_cooldown_is_one_over_fire_rate() -> void:
	# fire_rate = 1.0 → cooldown = 1.0
	_tower.on_fired()
	assert_almost_eq(_tower._fire_cooldown, 1.0, 0.001)

func test_zero_fire_rate_cannot_fire() -> void:
	_tower.current_fire_rate = 0.0
	assert_false(_tower.can_fire())

# ---------------------------------------------------------------------------
# Effective stats
# ---------------------------------------------------------------------------

func test_effective_damage_no_buff_equals_base() -> void:
	assert_almost_eq(_tower.get_effective_damage(), 25.0, 0.001)

func test_effective_fire_rate_no_buff_equals_base() -> void:
	assert_almost_eq(_tower.get_effective_fire_rate(), 1.0, 0.001)

func test_buff_increases_effective_damage() -> void:
	_tower.apply_buff(1.5, 1.0)
	assert_almost_eq(_tower.get_effective_damage(), 37.5, 0.001)

func test_buff_increases_effective_fire_rate() -> void:
	_tower.apply_buff(1.0, 2.0)
	assert_almost_eq(_tower.get_effective_fire_rate(), 2.0, 0.001)

func test_clear_buff_resets_to_one() -> void:
	_tower.apply_buff(1.5, 2.0)
	_tower.clear_buff()
	assert_almost_eq(_tower.get_effective_damage(), 25.0, 0.001)
	assert_almost_eq(_tower.get_effective_fire_rate(), 1.0, 0.001)

# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

func test_apply_upgrade_increments_tier() -> void:
	_tower.apply_upgrade(0)
	assert_eq(_tower.current_tier, 1)

func test_apply_upgrade_recalculates_stats() -> void:
	_tower.apply_upgrade(0)  # rapid: fire_rate_mult=1.5
	assert_almost_eq(_tower.current_fire_rate, 1.5, 0.001)

func test_apply_upgrade_power_doubles_damage() -> void:
	_tower.apply_upgrade(1)  # power: damage_mult=2.0
	assert_almost_eq(_tower.current_damage, 50.0, 0.001)

func test_apply_upgrade_invalid_choice_ignored() -> void:
	_tower.apply_upgrade(99)
	assert_eq(_tower.current_tier, 0)

func test_two_upgrades_compound() -> void:
	_tower.apply_upgrade(0)   # rapid: fire_rate x1.5
	_tower.apply_upgrade(0)   # rapid2: damage x1.2, fire_rate x1.2
	# damage: 25 * 1.0 * 1.2 = 30, fire_rate: 1.0 * 1.5 * 1.2 = 1.8
	assert_almost_eq(_tower.current_damage, 30.0, 0.001)
	assert_almost_eq(_tower.current_fire_rate, 1.8, 0.001)

func test_upgrade_path_recorded() -> void:
	_tower.apply_upgrade(1)
	assert_eq(_tower.get_upgrade_path().size(), 1)
	assert_eq(_tower.get_upgrade_path()[0], 1)

func test_upgrade_path_returns_copy() -> void:
	_tower.apply_upgrade(0)
	var path := _tower.get_upgrade_path()
	path.append(99)
	assert_eq(_tower.get_upgrade_path().size(), 1)

# ---------------------------------------------------------------------------
# Investment
# ---------------------------------------------------------------------------

func test_total_investment_equals_cost_before_upgrades() -> void:
	assert_eq(_tower.get_total_investment(), 100)

func test_total_investment_includes_upgrade_cost() -> void:
	_tower.apply_upgrade(0)  # cost=75
	assert_eq(_tower.get_total_investment(), 175)

func test_total_investment_accumulates_multiple_upgrades() -> void:
	_tower.apply_upgrade(0)  # cost=75
	_tower.apply_upgrade(0)  # cost=125
	assert_eq(_tower.get_total_investment(), 300)

# ---------------------------------------------------------------------------
# Targeting mode
# ---------------------------------------------------------------------------

func test_set_targeting_mode() -> void:
	_tower.set_targeting_mode(Enums.TargetingMode.NEAREST)
	assert_eq(_tower.targeting_mode, Enums.TargetingMode.NEAREST)

# ---------------------------------------------------------------------------
# Sell signal
# ---------------------------------------------------------------------------

func test_sell_emits_signal() -> void:
	watch_signals(_tower)
	_tower.sell()
	assert_signal_emitted(_tower, "sold")
