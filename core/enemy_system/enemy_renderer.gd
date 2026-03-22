class_name EnemyRenderer
extends Node2D

## Renders an enemy as a polygon using geometric shapes.
## setup() must be called with an EnemyDefinition before the node is visible.
## Supports health bar, resistance outline, and rotation for flyers.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const HEALTH_BAR_WIDTH: float = 32.0
const HEALTH_BAR_HEIGHT: float = 5.0
const HEALTH_BAR_OFFSET_Y: float = -20.0
const SHIELD_BAR_OFFSET_Y: float = -26.0
const RESISTANCE_OUTLINE_WIDTH: float = 2.0
const FLYER_ROTATION_SPEED: float = 1.5  # radians per second

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _shape_sides: int = 4
var _shape_radius: float = 12.0
var _color: Color = Color.WHITE
var _size_scale: float = 1.0
var _is_flying: bool = false
var _resistance_map: Dictionary = {}

var _hp_fraction: float = 1.0
var _shield_fraction: float = 0.0   # shield / max_hp, for bar proportions
var _show_health_bar: bool = false
var _rotation_angle: float = 0.0
var _frame_counter: int = 0
var _hit_flash: float = 0.0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Configure renderer from an EnemyDefinition.
func setup(definition: EnemyDefinition) -> void:
	_shape_sides = definition.shape_sides
	_shape_radius = definition.shape_radius
	_color = definition.color
	_size_scale = definition.size_scale
	_is_flying = definition.is_flying
	_resistance_map = definition.resistance_map.duplicate()
	queue_redraw()

## Trigger a brief white hit flash on the enemy body.
func flash_hit() -> void:
	_hit_flash = 0.1
	queue_redraw()

## Update health display. Call from EnemyHealth.health_changed signal.
func update_health(hp: float, max_hp: float, shield: float) -> void:
	_hp_fraction = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_shield_fraction = clampf(shield / maxf(max_hp, 1.0), 0.0, 1.0)
	_show_health_bar = _hp_fraction < 1.0 or _shield_fraction > 0.0
	queue_redraw()

## Called by Enemy when resistance_map is updated (adaptation system).
func set_resistance_map(resistance_map: Dictionary) -> void:
	_resistance_map = resistance_map.duplicate()
	queue_redraw()

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _is_flying:
		_rotation_angle = fmod(_rotation_angle + FLYER_ROTATION_SPEED * delta, TAU)
		_frame_counter += 1
		if _frame_counter % 3 == 0:
			queue_redraw()

	if _hit_flash > 0.0:
		_hit_flash -= delta
		queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var points: PackedVector2Array = _get_polygon_points(_shape_sides, _shape_radius * _size_scale)

	# Ground shadow
	draw_circle(Vector2(2, 4), _shape_radius * _size_scale * 1.2, Color(0.0, 0.0, 0.0, 0.3))

	# Resistance outline (drawn behind body)
	if not _resistance_map.is_empty():
		_draw_resistance_outline(points)

	# Body polygon
	draw_colored_polygon(points, _color)

	# Outline (light outline to stand out against dark backgrounds)
	_draw_polygon_outline(points, Color(1.0, 1.0, 1.0, 0.3), 1.0)

	# Hit flash overlay
	if _hit_flash > 0.0:
		draw_colored_polygon(points, Color(1.0, 1.0, 1.0, _hit_flash * 3.0))

	# Health bar (only when damaged)
	if _show_health_bar:
		_draw_health_bar()

## Returns polygon points for an n-sided regular polygon, rotated by _rotation_angle.
func _get_polygon_points(sides: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n: int = maxi(sides, 3)
	for i in range(n):
		var angle: float = _rotation_angle + (TAU * i / float(n)) - PI / 2.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _draw_polygon_outline(points: PackedVector2Array, outline_color: Color, width: float) -> void:
	var n: int = points.size()
	for i in range(n):
		draw_line(points[i], points[(i + 1) % n], outline_color, width)

func _draw_resistance_outline(points: PackedVector2Array) -> void:
	# Pick the dominant resistance color: brightest resistance type gets an outline
	var max_resist: float = 0.0
	var outline_color := Color(1.0, 1.0, 0.0, 0.8)  # default yellow glow
	for dtype in _resistance_map:
		var val: float = _resistance_map[dtype] as float
		if val > max_resist:
			max_resist = val
			outline_color = _resistance_color_for_type(dtype as Enums.DamageType, val)

	# Scale the outline by resistance magnitude
	if max_resist > 0.0:
		var scale_factor: float = 1.0 + max_resist * 0.3
		var scaled := PackedVector2Array()
		for p in points:
			scaled.append(p * scale_factor)
		_draw_polygon_outline(scaled, outline_color, RESISTANCE_OUTLINE_WIDTH)

func _draw_health_bar() -> void:
	var bar_x: float = -HEALTH_BAR_WIDTH / 2.0
	var bg_rect := Rect2(bar_x, HEALTH_BAR_OFFSET_Y, HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)

	# Background
	draw_rect(bg_rect, Color(0.15, 0.15, 0.15, 0.85))

	# HP fill
	var hp_w: float = HEALTH_BAR_WIDTH * _hp_fraction
	if hp_w > 0.0:
		var hp_color: Color = _hp_color(_hp_fraction)
		draw_rect(Rect2(bar_x, HEALTH_BAR_OFFSET_Y, hp_w, HEALTH_BAR_HEIGHT), hp_color)

	# Shield bar (shown above HP bar)
	if _shield_fraction > 0.0:
		var shield_w: float = minf(HEALTH_BAR_WIDTH * _shield_fraction, HEALTH_BAR_WIDTH)
		draw_rect(
			Rect2(bar_x, SHIELD_BAR_OFFSET_Y, shield_w, HEALTH_BAR_HEIGHT - 1.0),
			Color(0.3, 0.6, 1.0, 0.9)
		)

	# Border
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.6), false, 1.0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _hp_color(fraction: float) -> Color:
	if fraction > 0.6:
		return Color(0.2, 0.85, 0.2)
	elif fraction > 0.3:
		return Color(0.9, 0.75, 0.1)
	return Color(0.9, 0.15, 0.15)

func _resistance_color_for_type(dtype: Enums.DamageType, strength: float) -> Color:
	var alpha: float = 0.5 + strength * 0.5
	match dtype:
		Enums.DamageType.PULSE:
			return Color(1.0, 1.0, 0.0, alpha)
		Enums.DamageType.ARC:
			return Color(0.3, 0.6, 1.0, alpha)
		Enums.DamageType.CRYO:
			return Color(0.5, 0.9, 1.0, alpha)
		Enums.DamageType.MISSILE:
			return Color(1.0, 0.4, 0.0, alpha)
		Enums.DamageType.BEAM:
			return Color(1.0, 0.0, 0.8, alpha)
		Enums.DamageType.NANO:
			return Color(0.0, 1.0, 0.5, alpha)
		Enums.DamageType.HARVEST:
			return Color(0.8, 0.5, 0.1, alpha)
	return Color(1.0, 1.0, 1.0, alpha)
