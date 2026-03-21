extends GutTest

## Tests for core/pathfinding/fixed_path_provider.gd
## Uses a real Path2D + PathFollow2D hierarchy created in the test scene tree.

var _path2d: Path2D
var _path_follow: PathFollow2D
var _provider: FixedPathProvider

func before_each() -> void:
	# Build a simple straight horizontal path 500 units long
	_path2d = Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(500.0, 0.0))
	_path2d.curve = curve
	add_child(_path2d)

	_path_follow = PathFollow2D.new()
	_path_follow.loop = false
	_path2d.add_child(_path_follow)

	_provider = FixedPathProvider.new()
	add_child(_provider)
	_provider.setup(_path_follow)

func after_each() -> void:
	_provider.queue_free()
	_path2d.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_progress_ratio_is_zero() -> void:
	assert_almost_eq(_provider.get_progress_ratio(), 0.0, 0.001)

func test_initial_has_not_reached_end() -> void:
	assert_false(_provider.has_reached_end())

func test_initial_position_is_path_start() -> void:
	var pos := _provider.get_current_position()
	# PathFollow2D at progress 0 is at the first point (world-space)
	assert_almost_eq(pos.x, _path_follow.global_position.x, 1.0)

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func test_move_advances_progress() -> void:
	_provider.move(100.0, 1.0)  # speed 100, delta 1 → progress += 100
	assert_gt(_provider.get_progress_ratio(), 0.0)

func test_move_by_full_length_reaches_end() -> void:
	# Path is 500 units; move 500 in one step
	_provider.move(500.0, 1.0)
	assert_true(_provider.has_reached_end())

func test_move_partial_does_not_reach_end() -> void:
	_provider.move(100.0, 1.0)  # Only 100/500
	assert_false(_provider.has_reached_end())

func test_move_stops_after_end() -> void:
	_provider.move(500.0, 1.0)
	var ratio_at_end := _provider.get_progress_ratio()
	_provider.move(500.0, 1.0)  # extra move should be ignored
	assert_almost_eq(_provider.get_progress_ratio(), ratio_at_end, 0.001)

func test_progress_ratio_increases_with_movement() -> void:
	_provider.move(100.0, 1.0)
	var r1 := _provider.get_progress_ratio()
	_provider.move(100.0, 1.0)
	var r2 := _provider.get_progress_ratio()
	assert_gt(r2, r1)

# ---------------------------------------------------------------------------
# No setup (null path follow)
# ---------------------------------------------------------------------------

func test_no_setup_position_is_zero() -> void:
	var p := FixedPathProvider.new()
	add_child(p)
	assert_eq(p.get_current_position(), Vector2.ZERO)
	p.queue_free()

func test_no_setup_progress_ratio_is_zero() -> void:
	var p := FixedPathProvider.new()
	add_child(p)
	assert_almost_eq(p.get_progress_ratio(), 0.0, 0.001)
	p.queue_free()

func test_no_setup_has_not_reached_end() -> void:
	var p := FixedPathProvider.new()
	add_child(p)
	assert_false(p.has_reached_end())
	p.queue_free()

func test_no_setup_move_does_not_crash() -> void:
	var p := FixedPathProvider.new()
	add_child(p)
	p.move(100.0, 1.0)  # should silently no-op
	p.queue_free()
