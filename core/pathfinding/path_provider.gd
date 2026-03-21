class_name PathProvider
extends Node

## Abstract base class for enemy path-following providers.
## Subclasses implement the movement strategy (fixed path, grid maze, etc.).
## Call move() each frame from Enemy._process().

## Advances along the path by speed * delta world-units.
## Must be overridden by subclass.
func move(speed: float, delta: float) -> void:
	push_error("PathProvider.move() is abstract — override in subclass")

## Returns the current world-space position along the path.
## Must be overridden by subclass.
func get_current_position() -> Vector2:
	push_error("PathProvider.get_current_position() is abstract — override in subclass")
	return Vector2.ZERO

## Returns a 0.0–1.0 fraction representing how far along the path the enemy is.
## Must be overridden by subclass.
func get_progress_ratio() -> float:
	push_error("PathProvider.get_progress_ratio() is abstract — override in subclass")
	return 0.0

## Returns true when the enemy has reached or passed the end of the path.
## Must be overridden by subclass.
func has_reached_end() -> bool:
	push_error("PathProvider.has_reached_end() is abstract — override in subclass")
	return false
