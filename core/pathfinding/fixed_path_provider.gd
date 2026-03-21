class_name FixedPathProvider
extends PathProvider

## PathProvider implementation for fixed, pre-authored paths.
## Uses a PathFollow2D node to drive movement along a Godot Path2D.
## Call setup() with a PathFollow2D reference before use.

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _path_follow: PathFollow2D = null
var _reached_end: bool = false

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Assigns the PathFollow2D that this provider will advance.
## The PathFollow2D must already be a child of a Path2D.
func setup(path_follow: PathFollow2D) -> void:
	_path_follow = path_follow
	_reached_end = false

# ---------------------------------------------------------------------------
# PathProvider overrides
# ---------------------------------------------------------------------------

## Advances the PathFollow2D progress by speed * delta units.
func move(speed: float, delta: float) -> void:
	if _path_follow == null or _reached_end:
		return
	_path_follow.progress += speed * delta
	if _path_follow.progress_ratio >= 1.0:
		_reached_end = true

## Returns the current world-space position from PathFollow2D.
func get_current_position() -> Vector2:
	if _path_follow == null:
		return Vector2.ZERO
	return _path_follow.global_position

## Returns how far along the path the enemy is (0.0–1.0).
func get_progress_ratio() -> float:
	if _path_follow == null:
		return 0.0
	return _path_follow.progress_ratio

## Returns true when the PathFollow2D has reached ratio 1.0.
func has_reached_end() -> bool:
	return _reached_end
