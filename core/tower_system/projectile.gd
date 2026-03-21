class_name Projectile
extends Node2D

## A simple projectile that travels toward a target position.
## Emits hit_target when it reaches the target or gets close enough.
## Expires automatically after exceeding MAX_TRAVEL_DISTANCE.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const HIT_THRESHOLD: float = 10.0
const MAX_TRAVEL_DISTANCE: float = 2000.0
const DRAW_RADIUS: float = 3.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the projectile reaches the target.
## position: world position of the hit
## damage: damage amount
## damage_type: Enums.DamageType
## splash_radius: radius of splash damage (0 = single target)
signal hit_target(position: Vector2, damage: float, damage_type: int, splash_radius: float)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _target_pos: Vector2 = Vector2.ZERO
var _speed: float = 400.0
var _damage: float = 0.0
var _damage_type: int = Enums.DamageType.PULSE
var _splash_radius: float = 0.0
var _travel_distance: float = 0.0
var _initialized: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Set up the projectile before adding to scene.
## target_pos: world position to fly toward
## speed: pixels per second
## damage: damage dealt on hit
## damage_type: Enums.DamageType
## splash_radius: 0 for single target, >0 for area damage
func initialize(target_pos: Vector2, speed: float, damage: float, damage_type: int, splash_radius: float = 0.0) -> void:
	_target_pos = target_pos
	_speed = maxf(speed, 1.0)
	_damage = damage
	_damage_type = damage_type
	_splash_radius = maxf(splash_radius, 0.0)
	_travel_distance = 0.0
	_initialized = true

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _initialized:
		return

	var to_target: Vector2 = _target_pos - global_position
	var dist_remaining: float = to_target.length()

	# Move this frame
	var step: float = _speed * delta

	if dist_remaining <= HIT_THRESHOLD or step >= dist_remaining:
		# Arrived at target
		global_position = _target_pos
		_on_hit()
		return

	# Move toward target
	var direction: Vector2 = to_target / dist_remaining
	global_position += direction * step
	_travel_distance += step

	# Expire if traveled too far
	if _travel_distance >= MAX_TRAVEL_DISTANCE:
		queue_free()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	draw_circle(Vector2.ZERO, DRAW_RADIUS, Color.WHITE)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_hit() -> void:
	hit_target.emit(global_position, _damage, _damage_type, _splash_radius)
	queue_free()
