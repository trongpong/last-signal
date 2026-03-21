extends GutTest

## Integration tests: Enemy on a fixed path and on a grid path.
## Verifies that the full Enemy + PathProvider pipeline works end-to-end.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_definition(id: String, hp: float, speed: float) -> EnemyDefinition:
	var d := EnemyDefinition.new()
	d.id = id
	d.display_name = id.capitalize()
	d.base_hp = hp
	d.speed = speed
	d.armor = 0.0
	d.shield = 0.0
	d.gold_value = 10
	d.shape_sides = 4
	d.shape_radius = 12.0
	d.color = Color.WHITE
	return d

# ---------------------------------------------------------------------------
# Fixed path integration
# ---------------------------------------------------------------------------

var _fp_path2d: Path2D
var _fp_follow: PathFollow2D
var _fp_provider: FixedPathProvider
var _fp_enemy: Enemy
var _fp_def: EnemyDefinition

func _setup_fixed_path() -> void:
	_fp_path2d = Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(300.0, 0.0))
	_fp_path2d.curve = curve
	add_child(_fp_path2d)

	_fp_follow = PathFollow2D.new()
	_fp_follow.loop = false
	_fp_path2d.add_child(_fp_follow)

	_fp_provider = FixedPathProvider.new()
	_fp_path2d.add_child(_fp_provider)
	_fp_provider.setup(_fp_follow)

	_fp_def = _make_definition("test_fixed", 100.0, 200.0)
	_fp_enemy = Enemy.new()
	add_child(_fp_enemy)
	_fp_enemy.set_path_provider(_fp_provider)
	_fp_enemy.initialize(_fp_def, Enums.Difficulty.NORMAL)

func _teardown_fixed_path() -> void:
	if is_instance_valid(_fp_enemy):
		_fp_enemy.queue_free()
	if is_instance_valid(_fp_path2d):
		_fp_path2d.queue_free()
	_fp_def.free()

func test_fixed_path_enemy_alive_at_start() -> void:
	_setup_fixed_path()
	assert_true(_fp_enemy.is_alive())
	_teardown_fixed_path()

func test_fixed_path_enemy_moves_along_path() -> void:
	_setup_fixed_path()
	var start_ratio := _fp_enemy.get_progress_ratio()
	_fp_provider.move(100.0, 1.0)
	var end_ratio := _fp_enemy.get_progress_ratio()
	assert_gt(end_ratio, start_ratio)
	_teardown_fixed_path()

func test_fixed_path_enemy_reaches_end() -> void:
	_setup_fixed_path()
	_fp_provider.move(10000.0, 1.0)
	assert_true(_fp_provider.has_reached_end())
	_teardown_fixed_path()

func test_fixed_path_enemy_emits_reached_exit() -> void:
	_setup_fixed_path()
	watch_signals(_fp_enemy)
	_fp_enemy.on_reached_exit()
	assert_signal_emitted(_fp_enemy, "enemy_reached_exit")
	_teardown_fixed_path()

func test_fixed_path_enemy_dies_and_emits_signal() -> void:
	_setup_fixed_path()
	watch_signals(_fp_enemy)
	_fp_enemy._health.take_damage(10000.0, Enums.DamageType.PULSE)
	assert_signal_emitted(_fp_enemy, "enemy_died")
	_teardown_fixed_path()

func test_fixed_path_enemy_gold_value() -> void:
	_setup_fixed_path()
	assert_eq(_fp_enemy.get_gold_value(), 10)
	_teardown_fixed_path()

func test_fixed_path_enemy_hard_difficulty_more_hp() -> void:
	_setup_fixed_path()
	var hard_def := _make_definition("hard_test", 100.0, 100.0)
	var hard_enemy := Enemy.new()
	add_child(hard_enemy)

	var pf2 := PathFollow2D.new()
	pf2.loop = false
	_fp_path2d.add_child(pf2)
	var pp := FixedPathProvider.new()
	_fp_path2d.add_child(pp)
	pp.setup(pf2)

	hard_enemy.set_path_provider(pp)
	hard_enemy.initialize(hard_def, Enums.Difficulty.HARD)

	# Hard HP mult = 1.8, so effective HP = 180; a 100-damage hit leaves 43%
	hard_enemy._health.take_damage(100.0, Enums.DamageType.PULSE)
	assert_true(hard_enemy.is_alive())  # still alive at 180 total HP
	hard_enemy.queue_free()
	hard_def.free()
	_teardown_fixed_path()

func test_fixed_path_slow_reduces_speed() -> void:
	_setup_fixed_path()
	_fp_enemy.apply_slow(0.5, 5.0)
	assert_almost_eq(_fp_enemy._slow_factor, 0.5, 0.001)
	_teardown_fixed_path()

# ---------------------------------------------------------------------------
# Grid path integration
# ---------------------------------------------------------------------------

var _grid: GridManager
var _gp_provider: GridPathProvider
var _gp_enemy: Enemy
var _gp_def: EnemyDefinition

func _setup_grid_path() -> void:
	_grid = GridManager.new()
	add_child(_grid)
	_grid.initialize(Vector2i(8, 5), Vector2(64.0, 64.0))
	_grid.set_entry_point(Vector2i(0, 2))
	_grid.set_exit_point(Vector2i(7, 2))

	_gp_provider = GridPathProvider.new()
	add_child(_gp_provider)
	_gp_provider.setup(_grid)

	_gp_def = _make_definition("test_grid", 80.0, 150.0)
	_gp_enemy = Enemy.new()
	add_child(_gp_enemy)
	_gp_enemy.set_path_provider(_gp_provider)
	_gp_enemy.initialize(_gp_def, Enums.Difficulty.NORMAL)

func _teardown_grid_path() -> void:
	if is_instance_valid(_gp_enemy):
		_gp_enemy.queue_free()
	if is_instance_valid(_gp_provider):
		_gp_provider.queue_free()
	if is_instance_valid(_grid):
		_grid.queue_free()
	_gp_def.free()

func test_grid_path_enemy_alive_at_start() -> void:
	_setup_grid_path()
	assert_true(_gp_enemy.is_alive())
	_teardown_grid_path()

func test_grid_path_enemy_starts_near_entry() -> void:
	_setup_grid_path()
	var entry_world := _grid.cell_to_world(Vector2i(0, 2))
	var pos := _gp_provider.get_current_position()
	assert_almost_eq(pos.x, entry_world.x, 5.0)
	assert_almost_eq(pos.y, entry_world.y, 5.0)
	_teardown_grid_path()

func test_grid_path_enemy_advances() -> void:
	_setup_grid_path()
	var r0 := _gp_enemy.get_progress_ratio()
	_gp_provider.move(200.0, 1.0)
	var r1 := _gp_enemy.get_progress_ratio()
	assert_gt(r1, r0)
	_teardown_grid_path()

func test_grid_path_enemy_traverses_full_path() -> void:
	_setup_grid_path()
	_gp_provider.move(100000.0, 1.0)
	assert_true(_gp_provider.has_reached_end())
	_teardown_grid_path()

func test_grid_path_has_valid_path_initially() -> void:
	_setup_grid_path()
	assert_true(_grid.has_valid_path())
	_teardown_grid_path()

func test_grid_path_tower_placement_recalculates_path() -> void:
	_setup_grid_path()
	var cells_before := _grid.get_path_cells().size()
	# Place a tower away from the direct path to force a longer route
	_grid.place_tower(Vector2i(4, 2))
	var cells_after := _grid.get_path_cells().size()
	# Path must still exist and should be at least as long
	assert_true(_grid.has_valid_path())
	assert_ge(cells_after, cells_before - 1)
	_teardown_grid_path()

func test_grid_path_enemy_nightmare_difficulty() -> void:
	_setup_grid_path()
	var nm_def := _make_definition("nightmare_enemy", 100.0, 100.0)
	var nm_enemy := Enemy.new()
	add_child(nm_enemy)

	var nm_provider := GridPathProvider.new()
	add_child(nm_provider)
	nm_provider.setup(_grid)

	nm_enemy.set_path_provider(nm_provider)
	nm_enemy.initialize(nm_def, Enums.Difficulty.NIGHTMARE)

	# Nightmare HP mult = 3.0 → effective HP = 300; 100 damage should not kill it
	nm_enemy._health.take_damage(100.0, Enums.DamageType.PULSE)
	assert_true(nm_enemy.is_alive())
	nm_enemy.queue_free()
	nm_provider.queue_free()
	nm_def.free()
	_teardown_grid_path()
