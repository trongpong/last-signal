class_name Projectile
extends Node2D

## A simple projectile that travels toward a target position.
## Emits hit_target when it reaches the target or gets close enough.
## Expires automatically after exceeding MAX_TRAVEL_DISTANCE.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const HIT_THRESHOLD: float = 3.0
const MAX_TRAVEL_DISTANCE: float = 2000.0
const DRAW_RADIUS: float = 5.0
const GLOW_RADIUS: float = 10.0
const TRAIL_LENGTH: int = 5

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
var _trail: Array[Vector2] = []

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
	visible = true
	set_process(true)

## Reset all state to defaults for pool reuse.
func reset() -> void:
	_target_pos = Vector2.ZERO
	_speed = 400.0
	_damage = 0.0
	_damage_type = Enums.DamageType.PULSE
	_splash_radius = 0.0
	_travel_distance = 0.0
	_initialized = false
	_trail.clear()
	damage_type = -1
	global_position = Vector2.ZERO
	visible = false

## Release the projectile back to the pool (hide and stop processing).
func release() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _initialized:
		return

	# Record trail position before movement
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.remove_at(0)

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
	queue_redraw()

	# Expire if traveled too far
	if _travel_distance >= MAX_TRAVEL_DISTANCE:
		queue_free()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

## Color map for projectile visuals based on DamageType.
const _DAMAGE_TYPE_COLORS: Dictionary = {
	Enums.DamageType.PULSE: Color.CYAN,
	Enums.DamageType.ARC: Color.YELLOW,
	Enums.DamageType.CRYO: Color(0.5, 0.8, 1.0),
	Enums.DamageType.MISSILE: Color.ORANGE_RED,
	Enums.DamageType.BEAM: Color.WHITE,
	Enums.DamageType.NANO: Color.GREEN,
	Enums.DamageType.HARVEST: Color.GOLD,
}

## Exposed damage type for external queries and draw coloring.
## When set to a valid DamageType, overrides the internal _damage_type for drawing.
var damage_type: int = -1

func _draw() -> void:
	var dt: int = damage_type if damage_type >= 0 else _damage_type
	var col: Color = _DAMAGE_TYPE_COLORS.get(dt, Color.WHITE)

	# Trail — fading circles at previous positions
	var trail_count: int = _trail.size()
	for i in range(trail_count):
		var t: float = float(i) / float(trail_count)  # 0.0 (oldest) to ~1.0 (newest)
		var trail_alpha: float = t * 0.3
		var trail_radius: float = DRAW_RADIUS * (0.3 + t * 0.5)
		var trail_pos: Vector2 = _trail[i] - global_position  # convert to local
		draw_circle(trail_pos, trail_radius, Color(col.r, col.g, col.b, trail_alpha))

	# Glow
	var glow_color := Color(col.r, col.g, col.b, 0.3)
	draw_circle(Vector2.ZERO, GLOW_RADIUS, glow_color)

	# Main projectile
	draw_circle(Vector2.ZERO, DRAW_RADIUS, col)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_hit() -> void:
	hit_target.emit(global_position, _damage, _damage_type, _splash_radius)
	queue_free()
