class_name GridPathProvider
extends PathProvider

## PathProvider implementation for GRID_MAZE map mode.
## Follows a list of world-space waypoints supplied by GridManager.
## Listens for path_updated to reroute while the enemy is in motion.

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _grid: GridManager = null
var _waypoints: Array = []     # Array[Vector2]
var _waypoint_index: int = 0
var _current_pos: Vector2 = Vector2.ZERO
var _reached_end: bool = false
var _total_path_length: float = 0.0
var _distance_traveled: float = 0.0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Connects to GridManager and initialises position from the current path.
func setup(grid: GridManager) -> void:
	_grid = grid
	_grid.path_updated.connect(_on_path_updated)
	_refresh_waypoints(_grid.get_path_world())

## Internal: rebuild waypoint list and find nearest point when path changes.
func _refresh_waypoints(new_waypoints: Array) -> void:
	if new_waypoints.is_empty():
		_waypoints = []
		_reached_end = false
		return

	var was_empty: bool = _waypoints.is_empty()
	_waypoints = new_waypoints.duplicate()
	_total_path_length = _compute_path_length(_waypoints)

	if was_empty:
		_current_pos = _waypoints[0]
		_waypoint_index = 0
		_reached_end = false
		_distance_traveled = 0.0
	else:
		# Snap to the nearest waypoint not yet behind us
		_waypoint_index = _find_nearest_waypoint(_current_pos)
		_reached_end = false

# ---------------------------------------------------------------------------
# PathProvider overrides
# ---------------------------------------------------------------------------

## Advances along waypoints by speed * delta units per frame.
func move(speed: float, delta: float) -> void:
	if _reached_end or _waypoints.is_empty():
		return

	var remaining: float = speed * delta
	_distance_traveled += remaining

	while remaining > 0.0 and _waypoint_index < _waypoints.size():
		var target: Vector2 = _waypoints[_waypoint_index]
		var to_target: float = _current_pos.distance_to(target)

		if to_target <= remaining:
			remaining -= to_target
			_current_pos = target
			_waypoint_index += 1
			if _waypoint_index >= _waypoints.size():
				_reached_end = true
				return
		else:
			_current_pos = _current_pos.move_toward(target, remaining)
			remaining = 0.0

## Returns the current world-space position.
func get_current_position() -> Vector2:
	return _current_pos

## Returns 0.0–1.0 progress ratio based on distance traveled vs total path length.
func get_progress_ratio() -> float:
	if _total_path_length <= 0.0:
		return 0.0
	return clampf(_distance_traveled / _total_path_length, 0.0, 1.0)

## Returns true when all waypoints have been passed.
func has_reached_end() -> bool:
	return _reached_end

# ---------------------------------------------------------------------------
# Signal handler
# ---------------------------------------------------------------------------

func _on_path_updated(new_path_cells: Array) -> void:
	if _grid == null:
		return
	_refresh_waypoints(_grid.get_path_world())

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _compute_path_length(waypoints: Array) -> float:
	var length: float = 0.0
	for i in range(waypoints.size() - 1):
		length += (waypoints[i] as Vector2).distance_to(waypoints[i + 1] as Vector2)
	return length

## Returns the index of the waypoint closest to pos (for rerouting).
func _find_nearest_waypoint(pos: Vector2) -> int:
	var best_idx: int = _waypoint_index
	var best_dist: float = INF
	for i in range(_waypoint_index, _waypoints.size()):
		var d: float = pos.distance_to(_waypoints[i] as Vector2)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx
