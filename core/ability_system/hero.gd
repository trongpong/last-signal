class_name Hero
extends Node2D

## Runtime hero unit that persists on the field for a limited duration.
## Draws itself as a glowing octagon. Emits expired when the timer runs out.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal expired(hero: Hero)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SUMMON_COOLDOWN: float = 150.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _hero_id: String = ""
var _duration_remaining: float = 0.0
var _total_duration: float = 0.0
var _active: bool = false

# Visual parameters (can be set before adding to scene)
var _color: Color = Color(0.4, 0.8, 1.0, 1.0)
var _shape_sides: int = 8
var _shape_radius: float = 24.0

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Sets up the hero with its id, duration, and world-space spawn position.
func initialize(id: String, duration: float, spawn_pos: Vector2) -> void:
	_hero_id = id
	_total_duration = duration
	_duration_remaining = duration
	_active = duration > 0.0
	position = spawn_pos
	queue_redraw()

## Adds extra duration to the hero (e.g. from progression upgrades).
func apply_duration_bonus(bonus: float) -> void:
	_duration_remaining += bonus
	_total_duration += bonus

# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

## Returns true if the hero is currently active on the field.
func is_active() -> bool:
	return _active

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _active:
		return

	_duration_remaining -= delta
	queue_redraw()

	if _duration_remaining <= 0.0:
		_duration_remaining = 0.0
		_active = false
		expired.emit(self)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not _active:
		return

	var sides: int = maxi(_shape_sides, 3)
	var radius: float = _shape_radius

	# Glow circle (semi-transparent, larger than the polygon)
	var glow_color := Color(_color.r, _color.g, _color.b, 0.25)
	draw_circle(Vector2.ZERO, radius * 1.5, glow_color)

	# Polygon outline
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var angle: float = (TAU / float(sides)) * float(i) - (PI / 2.0)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	# Fill
	var fill_color := Color(_color.r, _color.g, _color.b, 0.6)
	draw_colored_polygon(points, fill_color)

	# Outline
	for i in range(sides):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % sides]
		draw_line(a, b, _color, 2.0)

	# Duration bar above hero
	if _total_duration > 0.0:
		var bar_width: float = radius * 2.0
		var bar_height: float = 4.0
		var bar_y: float = -(radius + 10.0)
		var fraction: float = clampf(_duration_remaining / _total_duration, 0.0, 1.0)
		# Background
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
		# Fill
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * fraction, bar_height), _color)
