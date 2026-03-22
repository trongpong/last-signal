extends GutTest

## Tests for enemy archetype abilities (Phase 2).

var _enemies: Array = []

func after_each() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()
	_enemies.clear()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_enemy(archetype: int, hp: float = 100.0, speed: float = 100.0) -> Enemy:
	var def := EnemyDefinition.new()
	def.id = "test_%d" % archetype
	def.archetype = archetype as Enums.EnemyArchetype
	def.base_hp = hp
	def.speed = speed
	def.armor = 0.0
	def.shield = 0.0
	def.gold_value = 10
	def.shape_sides = 4
	def.shape_radius = 8.0
	def.color = Color.WHITE
	def.size_scale = 1.0
	def.resistance_map = {}
	def.is_flying = false

	var provider := FlyerPathProvider.new()
	provider.setup(Vector2.ZERO, Vector2(1000, 0))

	var enemy := Enemy.new()
	enemy.add_child(provider)
	enemy.set_path_provider(provider)
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.initialize(def, Enums.Difficulty.NORMAL)
	enemy.global_position = Vector2.ZERO
	_enemies.append(enemy)
	return enemy

func _damage_enemy(enemy: Enemy, amount: float, dtype: int = Enums.DamageType.PULSE) -> void:
	var health: EnemyHealth = enemy.get_node_or_null("EnemyHealth")
	if health != null:
		health.take_damage(amount, dtype as Enums.DamageType)

# ---------------------------------------------------------------------------
# Healer
# ---------------------------------------------------------------------------

func test_healer_heals_nearby_allies() -> void:
	var healer := _make_enemy(Enums.EnemyArchetype.HEALER)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(50, 0)
	# Damage ally
	_damage_enemy(ally, 50.0)
	var hp_before: float = ally.get_hp_percentage()
	# Advance healer past its cooldown
	for i in range(250):
		healer._process(0.02)
	var hp_after: float = ally.get_hp_percentage()
	assert_gt(hp_after, hp_before, "Healer should have healed the nearby ally")
	pass

func test_healer_does_not_heal_distant_allies() -> void:
	var healer := _make_enemy(Enums.EnemyArchetype.HEALER)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(200, 0)
	_damage_enemy(ally, 50.0)
	var hp_before: float = ally.get_hp_percentage()
	for i in range(250):
		healer._process(0.02)
	var hp_after: float = ally.get_hp_percentage()
	assert_eq(hp_after, hp_before, "Healer should not heal distant allies")
	pass

func test_healer_does_not_heal_self() -> void:
	var healer := _make_enemy(Enums.EnemyArchetype.HEALER)
	_damage_enemy(healer, 30.0)
	var hp_before: float = healer.get_hp_percentage()
	for i in range(250):
		healer._process(0.02)
	var hp_after: float = healer.get_hp_percentage()
	assert_eq(hp_after, hp_before, "Healer should not heal itself")
	pass

# ---------------------------------------------------------------------------
# Shielder
# ---------------------------------------------------------------------------

func test_shielder_grants_shield_to_nearby() -> void:
	var shielder := _make_enemy(Enums.EnemyArchetype.SHIELDER)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(30, 0)
	var health: EnemyHealth = ally.get_node_or_null("EnemyHealth")
	var shield_before: float = health.get_shield()
	for i in range(300):
		shielder._process(0.02)
	var shield_after: float = health.get_shield()
	assert_gt(shield_after, shield_before, "Shielder should grant shield to nearby ally")
	pass

func test_shielder_caps_shield_at_max() -> void:
	var shielder := _make_enemy(Enums.EnemyArchetype.SHIELDER)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(30, 0)
	var health: EnemyHealth = ally.get_node_or_null("EnemyHealth")
	health.add_shield(90.0)
	for i in range(300):
		shielder._process(0.02)
	assert_almost_eq(health.get_shield(), Constants.SHIELDER_AURA_MAX, 0.01,
		"Shield should be capped at SHIELDER_AURA_MAX")
	pass

# ---------------------------------------------------------------------------
# Scout Scatter
# ---------------------------------------------------------------------------

func test_scout_scatter_on_death_buffs_allies() -> void:
	var scout := _make_enemy(Enums.EnemyArchetype.SCOUT)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(50, 0)
	# Kill scout
	_damage_enemy(scout, 9999.0)
	assert_gt(ally._speed_buff_factor, 1.0, "Nearby ally should have speed buff after scout death")
	pass

func test_scout_scatter_does_not_buff_distant() -> void:
	var scout := _make_enemy(Enums.EnemyArchetype.SCOUT)
	var ally := _make_enemy(Enums.EnemyArchetype.DRONE)
	ally.global_position = Vector2(200, 0)
	_damage_enemy(scout, 9999.0)
	assert_almost_eq(ally._speed_buff_factor, 1.0, 0.001,
		"Distant ally should not be affected by scout scatter")
	pass

# ---------------------------------------------------------------------------
# Drone Swarm Overwhelm
# ---------------------------------------------------------------------------

func test_drone_overwhelm_activates_at_five() -> void:
	var drones: Array = []
	for i in range(5):
		var d := _make_enemy(Enums.EnemyArchetype.DRONE)
		d.global_position = Vector2(i * 10, 0)
		drones.append(d)
	# Process one frame
	drones[0]._process(0.016)
	assert_gt(drones[1]._speed_buff_factor, 1.0, "Drones should have speed buff when 5+ alive")
	pass

func test_drone_overwhelm_inactive_below_five() -> void:
	var drones: Array = []
	for i in range(4):
		var d := _make_enemy(Enums.EnemyArchetype.DRONE)
		d.global_position = Vector2(i * 10, 0)
		drones.append(d)
	drones[0]._process(0.016)
	assert_almost_eq(drones[1]._speed_buff_factor, 1.0, 0.001,
		"Drones should not have speed buff with fewer than 5")
	pass

# ---------------------------------------------------------------------------
# Tank Fortified
# ---------------------------------------------------------------------------

func test_tank_fortified_sets_type_on_first_hit() -> void:
	var tank := _make_enemy(Enums.EnemyArchetype.TANK, 500.0)
	var health: EnemyHealth = tank.get_node_or_null("EnemyHealth")
	assert_eq(health.get_fortified_type(), -1, "Fortified type should be unset initially")
	health.take_damage(10.0, Enums.DamageType.CRYO)
	assert_eq(health.get_fortified_type(), Enums.DamageType.CRYO, "First hit should lock fortified type")
	pass

func test_tank_fortified_reduces_matching_damage() -> void:
	var tank := _make_enemy(Enums.EnemyArchetype.TANK, 500.0)
	var health: EnemyHealth = tank.get_node_or_null("EnemyHealth")
	# First hit locks type to PULSE
	health.take_damage(100.0, Enums.DamageType.PULSE)
	var hp_after_first: float = health.get_hp()
	# Second hit should be reduced by 25%
	health.take_damage(100.0, Enums.DamageType.PULSE)
	var hp_after_second: float = health.get_hp()
	var damage_dealt: float = hp_after_first - hp_after_second
	assert_lt(damage_dealt, 100.0, "Matching damage type should be reduced by fortified")
	pass

func test_tank_fortified_does_not_reduce_other_types() -> void:
	var tank := _make_enemy(Enums.EnemyArchetype.TANK, 500.0)
	var health: EnemyHealth = tank.get_node_or_null("EnemyHealth")
	# Lock type to PULSE
	health.take_damage(10.0, Enums.DamageType.PULSE)
	var hp_before: float = health.get_hp()
	# Hit with different type
	health.take_damage(100.0, Enums.DamageType.CRYO)
	var damage_dealt: float = hp_before - health.get_hp()
	assert_almost_eq(damage_dealt, 100.0, 0.01, "Non-matching type should deal full damage")
	pass
