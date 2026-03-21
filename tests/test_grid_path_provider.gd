extends GutTest

## Tests for core/pathfinding/grid_path_provider.gd

var _grid: GridManager
var _provider: GridPathProvider

func before_each() -> void:
	_grid = GridManager.new()
	add_child(_grid)
	_grid.initialize(Vector2i(10, 6), Vector2(64.0, 64.0))
	_grid.set_entry_point(Vector2i(0, 2))
	_grid.set_exit_point(Vector2i(9, 2))

	_provider = GridPathProvider.new()
	add_child(_provider)
	_provider.setup(_grid)

func after_each() -> void:
	_provider.queue_free()
	_grid.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_position_near_entry() -> void:
	var entry_world := _grid.cell_to_world(Vector2i(0, 2))
	var pos := _provider.get_current_position()
	# Should start at (or near) entry world position
	assert_almost_eq(pos.x, entry_world.x, 1.0)
	assert_almost_eq(pos.y, entry_world.y, 1.0)

func test_initial_has_not_reached_end() -> void:
	assert_false(_provider.has_reached_end())

func test_initial_progress_ratio_is_zero() -> void:
	assert_almost_eq(_provider.get_progress_ratio(), 0.0, 0.01)

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func test_move_advances_position() -> void:
	var start_pos := _provider.get_current_position()
	_provider.move(200.0, 1.0)
	var end_pos := _provider.get_current_position()
	# Position should have moved
	assert_gt(start_pos.distance_to(end_pos), 0.0)

func test_move_increases_progress_ratio() -> void:
	_provider.move(100.0, 1.0)
	assert_gt(_provider.get_progress_ratio(), 0.0)

func test_full_traverse_reaches_end() -> void:
	# Path is 9 cells × 64 units = 576 units; move in one large step
	_provider.move(10000.0, 1.0)
	assert_true(_provider.has_reached_end())

func test_partial_move_does_not_reach_end() -> void:
	_provider.move(30.0, 1.0)
	assert_false(_provider.has_reached_end())

func test_move_ignored_after_end() -> void:
	_provider.move(10000.0, 1.0)
	var pos_at_end := _provider.get_current_position()
	_provider.move(10000.0, 1.0)
	assert_eq(_provider.get_current_position(), pos_at_end)

# ---------------------------------------------------------------------------
# Path update (rerouting)
# ---------------------------------------------------------------------------

func test_path_update_does_not_crash() -> void:
	_provider.move(100.0, 1.0)
	# Place a tower off the current path and verify reroute happens
	_grid.place_tower(Vector2i(5, 0))
	# Provider should still be alive and not crashed
	assert_false(_provider.has_reached_end())

func test_progress_ratio_clamped_to_one() -> void:
	_provider.move(100000.0, 1.0)
	assert_almost_eq(_provider.get_progress_ratio(), 1.0, 0.001)
