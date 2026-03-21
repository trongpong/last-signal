extends GutTest

## Tests for core/enemy_system/enemy_definition.gd

var def: EnemyDefinition

func before_each() -> void:
	def = EnemyDefinition.new()

func after_each() -> void:
	def.free()

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_default_id_is_empty() -> void:
	assert_eq(def.id, "")

func test_default_display_name_is_empty() -> void:
	assert_eq(def.display_name, "")

func test_default_archetype_is_drone() -> void:
	assert_eq(def.archetype, Enums.EnemyArchetype.DRONE)

func test_default_base_hp() -> void:
	assert_almost_eq(def.base_hp, 100.0, 0.001)

func test_default_speed() -> void:
	assert_almost_eq(def.speed, 150.0, 0.001)

func test_default_armor_is_zero() -> void:
	assert_almost_eq(def.armor, 0.0, 0.001)

func test_default_shield_is_zero() -> void:
	assert_almost_eq(def.shield, 0.0, 0.001)

func test_default_gold_value() -> void:
	assert_eq(def.gold_value, 10)

func test_default_diamond_chance_is_zero() -> void:
	assert_almost_eq(def.diamond_chance, 0.0, 0.001)

func test_default_shape_sides() -> void:
	assert_eq(def.shape_sides, 4)

func test_default_shape_radius() -> void:
	assert_almost_eq(def.shape_radius, 12.0, 0.001)

func test_default_color_is_white() -> void:
	assert_eq(def.color, Color.WHITE)

func test_default_size_scale_is_one() -> void:
	assert_almost_eq(def.size_scale, 1.0, 0.001)

func test_default_resistance_map_is_empty() -> void:
	assert_eq(def.resistance_map.size(), 0)

func test_default_abilities_is_empty() -> void:
	assert_eq(def.abilities.size(), 0)

func test_default_is_boss_false() -> void:
	assert_false(def.is_boss)

func test_default_is_flying_false() -> void:
	assert_false(def.is_flying)

# ---------------------------------------------------------------------------
# Assignment
# ---------------------------------------------------------------------------

func test_set_id() -> void:
	def.id = "scout"
	assert_eq(def.id, "scout")

func test_set_archetype_scout() -> void:
	def.archetype = Enums.EnemyArchetype.SCOUT
	assert_eq(def.archetype, Enums.EnemyArchetype.SCOUT)

func test_set_resistance_map() -> void:
	def.resistance_map[Enums.DamageType.CRYO] = 0.5
	assert_almost_eq(def.resistance_map[Enums.DamageType.CRYO] as float, 0.5, 0.001)

func test_set_is_flying() -> void:
	def.is_flying = true
	assert_true(def.is_flying)

func test_set_is_boss() -> void:
	def.is_boss = true
	assert_true(def.is_boss)

func test_abilities_array_append() -> void:
	def.abilities.append("regen")
	assert_eq(def.abilities.size(), 1)
	assert_eq(def.abilities[0], "regen")
