extends GutTest

## Tests for core/pathfinding/flyer_path_provider.gd

var _provider: FlyerPathProvider

func before_each() -> void:
	_provider = FlyerPathProvider.new()
	add_child(_provider)

func after_each() -> void:
	_provider.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_progress_ratio_is_zero() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	assert_almost_eq(_provider.get_progress_ratio(), 0.0, 0.001)

func test_initial_has_not_reached_end() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	assert_false(_provider.has_reached_end())

func test_initial_position_is_start() -> void:
	_provider.setup(Vector2(10, 20), Vector2(200, 300))
	assert_eq(_provider.get_current_position(), Vector2(10, 20))

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func test_move_advances_progress() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(50.0, 1.0)
	assert_almost_eq(_provider.get_progress_ratio(), 0.5, 0.01)

func test_move_full_distance_reaches_end() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(100.0, 1.0)
	assert_true(_provider.has_reached_end())

func test_move_overshoot_clamps_at_end() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(200.0, 1.0)
	assert_true(_provider.has_reached_end())
	assert_almost_eq(_provider.get_progress_ratio(), 1.0, 0.001)
	assert_eq(_provider.get_current_position(), Vector2(100, 0))

func test_move_partial_does_not_reach_end() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(30.0, 1.0)
	assert_false(_provider.has_reached_end())

func test_position_at_midpoint() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(50.0, 1.0)
	var pos := _provider.get_current_position()
	assert_almost_eq(pos.x, 50.0, 0.5)
	assert_almost_eq(pos.y, 0.0, 0.5)

func test_move_stops_after_end() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 0))
	_provider.move(100.0, 1.0)
	_provider.move(50.0, 1.0)
	assert_eq(_provider.get_current_position(), Vector2(100, 0))

func test_diagonal_path() -> void:
	_provider.setup(Vector2.ZERO, Vector2(100, 100))
	_provider.move(1000.0, 1.0)
	assert_true(_provider.has_reached_end())
	assert_eq(_provider.get_current_position(), Vector2(100, 100))

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_zero_distance_path() -> void:
	_provider.setup(Vector2(50, 50), Vector2(50, 50))
	_provider.move(100.0, 1.0)
	assert_eq(_provider.get_current_position(), Vector2(50, 50))
