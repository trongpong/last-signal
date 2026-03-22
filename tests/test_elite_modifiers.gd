extends GutTest

## Tests for elite enemy modifiers (Phase 3).

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

func _make_enemy(hp: float = 100.0, speed: float = 100.0) -> Enemy:
	var def := EnemyDefinition.new()
	def.id = "test_elite"
	def.archetype = Enums.EnemyArchetype.DRONE
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

# ---------------------------------------------------------------------------
# Basic state
# ---------------------------------------------------------------------------

func test_not_elite_by_default() -> void:
	var e := _make_enemy()
	assert_false(e.is_elite())

func test_apply_elite_modifier_sets_elite() -> void:
	var e := _make_enemy()
	e.apply_elite_modifier(Enums.EliteModifier.REGENERATING)
	assert_true(e.is_elite())
	assert_true(e.has_elite_modifier(Enums.EliteModifier.REGENERATING))

func test_multiple_modifiers() -> void:
	var e := _make_enemy()
	e.apply_elite_modifier(Enums.EliteModifier.REGENERATING)
	e.apply_elite_modifier(Enums.EliteModifier.ENRAGED)
	assert_true(e.has_elite_modifier(Enums.EliteModifier.REGENERATING))
	assert_true(e.has_elite_modifier(Enums.EliteModifier.ENRAGED))

func test_elite_hp_scaled_up() -> void:
	var e := _make_enemy(100.0)
	var health: EnemyHealth = e.get_node_or_null("EnemyHealth")
	var hp_before: float = health.get_max_hp()
	e.apply_elite_modifier(Enums.EliteModifier.MAGNETIC)
	assert_gt(health.get_max_hp(), hp_before, "Elite should have higher max HP")

# ---------------------------------------------------------------------------
# Regenerating
# ---------------------------------------------------------------------------

func test_regenerating_heals_over_time() -> void:
	var e := _make_enemy(200.0)
	e.apply_elite_modifier(Enums.EliteModifier.REGENERATING)
	var health: EnemyHealth = e.get_node_or_null("EnemyHealth")
	health.take_damage(100.0, Enums.DamageType.PULSE)
	var hp_before: float = health.get_hp()
	for i in range(150):
		e._process(0.02)
	assert_gt(health.get_hp(), hp_before, "Regenerating elite should heal over time")

# ---------------------------------------------------------------------------
# Phasing
# ---------------------------------------------------------------------------

func test_phasing_toggles_untargetable() -> void:
	var e := _make_enemy()
	e.apply_elite_modifier(Enums.EliteModifier.PHASING)
	assert_false(e.is_phasing(), "Should not start phased")
	# Advance past the phase interval (3s)
	for i in range(200):
		e._process(0.02)
	assert_true(e.is_phasing(), "Should be phased after 3s interval")

# ---------------------------------------------------------------------------
# Enraged
# ---------------------------------------------------------------------------

func test_enraged_speed_increases() -> void:
	var e := _make_enemy(200.0, 100.0)
	e.apply_elite_modifier(Enums.EliteModifier.ENRAGED)
	var speed_before: float = e._effective_speed
	# Process past multiple enrage intervals (3s each)
	for i in range(500):
		e._process(0.02)
	assert_gt(e._effective_speed, speed_before, "Enraged elite should get faster over time")

func test_enraged_speed_caps() -> void:
	var e := _make_enemy(200.0, 100.0)
	e.apply_elite_modifier(Enums.EliteModifier.ENRAGED)
	# Process for long time (100s) to ensure cap
	for i in range(5000):
		e._process(0.02)
	var base_speed: float = 100.0
	var max_speed: float = base_speed * (1.0 + Constants.ELITE_ENRAGED_SPEED_CAP)
	assert_almost_eq(e._effective_speed, max_speed, 1.0, "Speed should cap at +50%")

# ---------------------------------------------------------------------------
# Splitting
# ---------------------------------------------------------------------------

func test_splitting_emits_signal() -> void:
	var e := _make_enemy(100.0)
	e.apply_elite_modifier(Enums.EliteModifier.SPLITTING)
	watch_signals(e)
	var health: EnemyHealth = e.get_node_or_null("EnemyHealth")
	health.take_damage(9999.0, Enums.DamageType.PULSE)
	assert_signal_emitted(e, "elite_split_requested")

# ---------------------------------------------------------------------------
# Magnetic
# ---------------------------------------------------------------------------

func test_magnetic_buffs_nearby_allies() -> void:
	var mag := _make_enemy()
	mag.apply_elite_modifier(Enums.EliteModifier.MAGNETIC)
	var ally := _make_enemy()
	ally.global_position = Vector2(30, 0)
	mag._process(0.016)
	assert_gt(ally._speed_buff_factor, 1.0, "Nearby ally should be speed-buffed by Magnetic")

func test_magnetic_does_not_buff_distant() -> void:
	var mag := _make_enemy()
	mag.apply_elite_modifier(Enums.EliteModifier.MAGNETIC)
	var ally := _make_enemy()
	ally.global_position = Vector2(200, 0)
	mag._process(0.016)
	assert_almost_eq(ally._speed_buff_factor, 1.0, 0.001, "Distant ally should not be buffed")
