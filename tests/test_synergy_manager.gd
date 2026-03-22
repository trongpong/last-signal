extends GutTest

## Tests for core/tower_system/synergy_manager.gd

var _sm: SynergyManager
var _towers_node: Node2D

func before_each() -> void:
	_sm = SynergyManager.new()
	add_child(_sm)
	_towers_node = Node2D.new()
	add_child(_towers_node)

func after_each() -> void:
	for child in _towers_node.get_children():
		child.queue_free()
	_towers_node.queue_free()
	_sm.queue_free()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_tower(tower_type: int, pos: Vector2) -> Tower:
	var def := TowerDefinition.new()
	def.tower_type = tower_type as Enums.TowerType
	def.display_name = "Test"
	def.base_damage = 10.0
	def.base_fire_rate = 1.0
	def.base_range = 100.0
	def.cost = 100
	def.damage_type = Enums.DamageType.PULSE
	var tower := Tower.new()
	_towers_node.add_child(tower)
	tower.initialize(def)
	tower.global_position = pos
	return tower

# ---------------------------------------------------------------------------
# Detection tests
# ---------------------------------------------------------------------------

func test_no_synergy_when_towers_far_apart() -> void:
	var t1 := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(200, 0))
	_sm.recalculate(_towers_node)
	assert_false(t1.has_synergy(), "Towers >100px apart should not have synergy")
	assert_false(t2.has_synergy())

func test_shatter_assigned_when_within_range() -> void:
	var t1 := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(50, 0))
	_sm.recalculate(_towers_node)
	assert_true(t1.has_synergy())
	assert_eq(t1.get_synergy_type(), Enums.SynergyType.SHATTER)
	assert_eq(t2.get_synergy_type(), Enums.SynergyType.SHATTER)

func test_barrage_assigned_when_within_range() -> void:
	var t1 := _make_tower(Enums.TowerType.PULSE_CANNON, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.MISSILE_POD, Vector2(80, 0))
	_sm.recalculate(_towers_node)
	assert_eq(t1.get_synergy_type(), Enums.SynergyType.BARRAGE)

func test_each_tower_limited_to_one_synergy() -> void:
	var cryo := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var arc := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(50, 0))
	var missile := _make_tower(Enums.TowerType.MISSILE_POD, Vector2(50, 50))
	_sm.recalculate(_towers_node)
	# Cryo should pair with Arc (SHATTER, priority 8) rather than Missile (FROSTBITE, priority 4)
	assert_eq(cryo.get_synergy_type(), Enums.SynergyType.SHATTER)
	# Missile should not have a synergy since Cryo is taken
	assert_false(missile.has_synergy())

func test_synergy_cleared_on_tower_removal() -> void:
	var t1 := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(50, 0))
	_sm.recalculate(_towers_node)
	assert_true(t1.has_synergy())
	t2.queue_free()
	_towers_node.remove_child(t2)
	_sm.recalculate(_towers_node)
	assert_false(t1.has_synergy())

# ---------------------------------------------------------------------------
# Discovery tests
# ---------------------------------------------------------------------------

func test_discovery_tracked() -> void:
	var t1 := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(50, 0))
	_sm.recalculate(_towers_node)
	assert_true(_sm.is_discovered(Enums.SynergyType.SHATTER))

func test_already_discovered_not_signaled_again() -> void:
	_sm.load_discovered([Enums.SynergyType.SHATTER])
	var t1 := _make_tower(Enums.TowerType.CRYO_ARRAY, Vector2(0, 0))
	var t2 := _make_tower(Enums.TowerType.ARC_EMITTER, Vector2(50, 0))
	watch_signals(_sm)
	_sm.recalculate(_towers_node)
	assert_signal_not_emitted(_sm, "synergy_activated")

func test_load_discovered_persists() -> void:
	_sm.load_discovered([Enums.SynergyType.BARRAGE, Enums.SynergyType.CONDUIT])
	assert_true(_sm.is_discovered(Enums.SynergyType.BARRAGE))
	assert_true(_sm.is_discovered(Enums.SynergyType.CONDUIT))
	assert_false(_sm.is_discovered(Enums.SynergyType.SHATTER))
