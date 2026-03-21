extends GutTest

## Tests for core/tower_system/tower_definition.gd

var _def: TowerDefinition

func before_each() -> void:
	_def = TowerDefinition.new()

func after_each() -> void:
	_def.free()

# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

func test_default_id_is_empty() -> void:
	assert_eq(_def.id, "")

func test_default_display_name_is_empty() -> void:
	assert_eq(_def.display_name, "")

func test_default_tower_type_is_pulse_cannon() -> void:
	assert_eq(_def.tower_type, Enums.TowerType.PULSE_CANNON)

func test_default_damage_type_is_pulse() -> void:
	assert_eq(_def.damage_type, Enums.DamageType.PULSE)

func test_default_base_damage() -> void:
	assert_almost_eq(_def.base_damage, 25.0, 0.001)

func test_default_base_fire_rate() -> void:
	assert_almost_eq(_def.base_fire_rate, 1.0, 0.001)

func test_default_base_range() -> void:
	assert_almost_eq(_def.base_range, 200.0, 0.001)

func test_default_cost() -> void:
	assert_eq(_def.cost, 100)

func test_default_shape_sides() -> void:
	assert_eq(_def.shape_sides, 8)

func test_default_shape_radius() -> void:
	assert_almost_eq(_def.shape_radius, 16.0, 0.001)

func test_default_color_is_cyan() -> void:
	assert_eq(_def.color, Color.CYAN)

func test_default_targeting_modes_empty() -> void:
	assert_eq(_def.targeting_modes.size(), 0)

func test_default_is_support_false() -> void:
	assert_false(_def.is_support)

func test_default_is_income_false() -> void:
	assert_false(_def.is_income)

func test_default_projectile_speed() -> void:
	assert_almost_eq(_def.projectile_speed, 400.0, 0.001)

func test_default_splash_radius_zero() -> void:
	assert_almost_eq(_def.splash_radius, 0.0, 0.001)

func test_default_slow_factor_one() -> void:
	assert_almost_eq(_def.slow_factor, 1.0, 0.001)

func test_default_slow_duration_zero() -> void:
	assert_almost_eq(_def.slow_duration, 0.0, 0.001)

func test_default_chain_count_zero() -> void:
	assert_eq(_def.chain_count, 0)

func test_default_chain_range_zero() -> void:
	assert_almost_eq(_def.chain_range, 0.0, 0.001)

func test_default_buff_range_zero() -> void:
	assert_almost_eq(_def.buff_range, 0.0, 0.001)

func test_default_buff_damage_mult_one() -> void:
	assert_almost_eq(_def.buff_damage_mult, 1.0, 0.001)

func test_default_buff_fire_rate_mult_one() -> void:
	assert_almost_eq(_def.buff_fire_rate_mult, 1.0, 0.001)

func test_default_income_per_wave_zero() -> void:
	assert_eq(_def.income_per_wave, 0)

func test_default_skill_tree_id_empty() -> void:
	assert_eq(_def.skill_tree_id, "")

func test_default_tier_branches_empty() -> void:
	assert_eq(_def.tier_branches.size(), 0)

# ---------------------------------------------------------------------------
# Assignment
# ---------------------------------------------------------------------------

func test_set_id() -> void:
	_def.id = "pulse_cannon"
	assert_eq(_def.id, "pulse_cannon")

func test_set_tower_type() -> void:
	_def.tower_type = Enums.TowerType.ARC_EMITTER
	assert_eq(_def.tower_type, Enums.TowerType.ARC_EMITTER)

func test_set_damage_type() -> void:
	_def.damage_type = Enums.DamageType.CRYO
	assert_eq(_def.damage_type, Enums.DamageType.CRYO)

func test_set_is_support() -> void:
	_def.is_support = true
	assert_true(_def.is_support)

func test_set_is_income() -> void:
	_def.is_income = true
	assert_true(_def.is_income)

func test_set_splash_radius() -> void:
	_def.splash_radius = 60.0
	assert_almost_eq(_def.splash_radius, 60.0, 0.001)

func test_set_slow_factor() -> void:
	_def.slow_factor = 0.5
	assert_almost_eq(_def.slow_factor, 0.5, 0.001)

func test_set_slow_duration() -> void:
	_def.slow_duration = 2.0
	assert_almost_eq(_def.slow_duration, 2.0, 0.001)

func test_set_chain_count() -> void:
	_def.chain_count = 3
	assert_eq(_def.chain_count, 3)

func test_set_chain_range() -> void:
	_def.chain_range = 120.0
	assert_almost_eq(_def.chain_range, 120.0, 0.001)

func test_set_buff_range() -> void:
	_def.buff_range = 150.0
	assert_almost_eq(_def.buff_range, 150.0, 0.001)

func test_set_income_per_wave() -> void:
	_def.income_per_wave = 50
	assert_eq(_def.income_per_wave, 50)

func test_set_targeting_modes() -> void:
	_def.targeting_modes = [Enums.TargetingMode.NEAREST, Enums.TargetingMode.FIRST]
	assert_eq(_def.targeting_modes.size(), 2)

func test_tier_branches_can_hold_dicts() -> void:
	var branch: Dictionary = {
		"name": "rapid",
		"display_name": "Rapid Fire",
		"damage_mult": 1.0,
		"fire_rate_mult": 1.5,
		"range_mult": 1.0,
		"cost": 75,
		"special": "",
		"branches": []
	}
	_def.tier_branches.append(branch)
	assert_eq(_def.tier_branches.size(), 1)
	assert_eq(_def.tier_branches[0]["name"], "rapid")
	assert_almost_eq(_def.tier_branches[0]["fire_rate_mult"] as float, 1.5, 0.001)
