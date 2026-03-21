extends GutTest

## Tests for core/enemy_system/enemy.gd

var _enemy: Enemy
var _def: EnemyDefinition

# Helper: build a minimal path with PathFollow2D so the enemy can move
var _path2d: Path2D
var _path_follow: PathFollow2D
var _path_provider: FixedPathProvider

func before_each() -> void:
	# Build a straight 500-unit horizontal path
	_path2d = Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(500.0, 0.0))
	_path2d.curve = curve
	add_child(_path2d)

	_path_follow = PathFollow2D.new()
	_path_follow.loop = false
	_path2d.add_child(_path_follow)

	_path_provider = FixedPathProvider.new()
	_path2d.add_child(_path_provider)
	_path_provider.setup(_path_follow)

	# Build a definition
	_def = EnemyDefinition.new()
	_def.id = "test_drone"
	_def.base_hp = 100.0
	_def.speed = 150.0
	_def.armor = 5.0
	_def.shield = 0.0
	_def.gold_value = 10
	_def.archetype = Enums.EnemyArchetype.DRONE
	_def.shape_sides = 6
	_def.shape_radius = 12.0
	_def.color = Color.WHITE

	# Build enemy
	_enemy = Enemy.new()
	add_child(_enemy)
	_enemy.set_path_provider(_path_provider)
	_enemy.initialize(_def, Enums.Difficulty.NORMAL)

func after_each() -> void:
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	if is_instance_valid(_path2d):
		_path2d.queue_free()
	_def.free()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func test_enemy_is_alive_after_init() -> void:
	assert_true(_enemy.is_alive())

func test_enemy_hp_percentage_full_after_init() -> void:
	assert_almost_eq(_enemy.get_hp_percentage(), 1.0, 0.001)

func test_enemy_gold_value_from_def() -> void:
	assert_eq(_enemy.get_gold_value(), 10)

func test_enemy_progress_ratio_zero_at_start() -> void:
	assert_almost_eq(_enemy.get_progress_ratio(), 0.0, 0.01)

# ---------------------------------------------------------------------------
# Difficulty HP scaling
# ---------------------------------------------------------------------------

func test_normal_difficulty_hp_unchanged() -> void:
	# Normal mult = 1.0, so hp = 100
	assert_almost_eq(_enemy.get_hp_percentage(), 1.0, 0.001)

func test_hard_difficulty_scales_hp() -> void:
	var hard_enemy := Enemy.new()
	add_child(hard_enemy)
	var pf2 := PathFollow2D.new()
	pf2.loop = false
	_path2d.add_child(pf2)
	var pp := FixedPathProvider.new()
	_path2d.add_child(pp)
	pp.setup(pf2)

	var d := EnemyDefinition.new()
	d.base_hp = 100.0
	d.speed = 100.0
	d.armor = 0.0
	d.shield = 0.0
	d.color = Color.WHITE
	hard_enemy.set_path_provider(pp)
	hard_enemy.initialize(d, Enums.Difficulty.HARD)
	# Hard mult = 1.8 → effective HP = 180; HP% should still be 1.0 (full)
	assert_almost_eq(hard_enemy.get_hp_percentage(), 1.0, 0.001)
	# Verify it takes more damage to kill (180 - 50 = 130 remaining)
	hard_enemy._health.take_damage(50.0, Enums.DamageType.PULSE)
	# 130/180 ≈ 0.722
	assert_gt(hard_enemy.get_hp_percentage(), 0.7)
	hard_enemy.queue_free()
	d.free()

# ---------------------------------------------------------------------------
# Damage and death
# ---------------------------------------------------------------------------

func test_enemy_takes_damage() -> void:
	_enemy._health.take_damage(30.0, Enums.DamageType.PULSE)
	assert_lt(_enemy.get_hp_percentage(), 1.0)

func test_enemy_dies_on_zero_hp() -> void:
	watch_signals(_enemy)
	_enemy._health.take_damage(10000.0, Enums.DamageType.PULSE)
	assert_signal_emitted(_enemy, "enemy_died")

func test_enemy_no_longer_alive_after_death() -> void:
	_enemy._health.take_damage(10000.0, Enums.DamageType.PULSE)
	assert_false(_enemy.is_alive())

# ---------------------------------------------------------------------------
# Slow effect
# ---------------------------------------------------------------------------

func test_apply_slow_reduces_factor() -> void:
	_enemy.apply_slow(0.5, 2.0)
	assert_almost_eq(_enemy._slow_factor, 0.5, 0.001)

func test_apply_slow_stronger_overwrites() -> void:
	_enemy.apply_slow(0.5, 2.0)
	_enemy.apply_slow(0.25, 3.0)
	assert_almost_eq(_enemy._slow_factor, 0.25, 0.001)

func test_apply_slow_weaker_does_not_overwrite() -> void:
	_enemy.apply_slow(0.3, 2.0)
	_enemy.apply_slow(0.8, 3.0)
	assert_almost_eq(_enemy._slow_factor, 0.3, 0.001)

func test_slow_timer_set() -> void:
	_enemy.apply_slow(0.5, 3.0)
	assert_almost_eq(_enemy._slow_timer, 3.0, 0.001)

# ---------------------------------------------------------------------------
# Reached exit
# ---------------------------------------------------------------------------

func test_on_reached_exit_emits_signal() -> void:
	watch_signals(_enemy)
	_enemy.on_reached_exit()
	assert_signal_emitted(_enemy, "enemy_reached_exit")

# ---------------------------------------------------------------------------
# Gold value
# ---------------------------------------------------------------------------

func test_gold_value_zero_without_definition() -> void:
	var bare := Enemy.new()
	add_child(bare)
	assert_eq(bare.get_gold_value(), 0)
	bare.queue_free()
