class_name FlyerPathProvider
extends PathProvider

## PathProvider for flying enemies. Linearly interpolates between
## start_pos and exit_pos, ignoring the ground path.

var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO
var _total_distance: float = 0.0
var _distance_traveled: float = 0.0
var _reached_end: bool = false

## Initializes the provider with world-space start and end positions.
func setup(start_pos: Vector2, end_pos: Vector2) -> void:
	_start = start_pos
	_end = end_pos
	_current_pos = start_pos
	_total_distance = start_pos.distance_to(end_pos)
	_distance_traveled = 0.0
	_reached_end = false

func move(speed: float, delta: float) -> void:
	if _reached_end or _total_distance <= 0.0:
		return
	_distance_traveled += speed * delta
	if _distance_traveled >= _total_distance:
		_distance_traveled = _total_distance
		_current_pos = _end
		_reached_end = true
	else:
		_current_pos = _start.lerp(_end, _distance_traveled / _total_distance)

func get_current_position() -> Vector2:
	return _current_pos

func get_progress_ratio() -> float:
	if _total_distance <= 0.0:
		return 0.0
	return clampf(_distance_traveled / _total_distance, 0.0, 1.0)

func has_reached_end() -> bool:
	return _reached_end
