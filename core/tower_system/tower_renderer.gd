class_name TowerRenderer
extends Node2D

## Renders a tower using geometric shapes.
## setup() must be called with a TowerDefinition before the node is visible.
## Draws: range indicator (when show_range=true), platform, main polygon shape,
## outline (brighter at higher tiers), and tier indicator dots.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const PLATFORM_SCALE: float = 1.35
const PLATFORM_DARK_FACTOR: float = 0.5
const RANGE_INDICATOR_ALPHA: float = 0.08
const RANGE_BORDER_ALPHA: float = 0.5
const RANGE_BORDER_WIDTH: float = 1.5
const OUTLINE_BASE_WIDTH: float = 1.5
const OUTLINE_TIER_WIDTH: float = 0.5
const TIE_DOT_RADIUS: float = 3.0
const TIER_DOT_SPACING: float = 9.0
const TIER_DOT_OFFSET_Y: float = 22.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _shape_sides: int = 8
var _shape_radius: float = 16.0
var _color: Color = Color.CYAN
var _current_tier: int = 0
var show_range: bool = false
var _range: float = 200.0

# Polygon point cache for mobile rendering performance
var _cached_shape_points: PackedVector2Array = PackedVector2Array()
var _cached_platform_points: PackedVector2Array = PackedVector2Array()
var _cache_dirty: bool = true

# Aura glow cache
var _cached_aura_points: PackedVector2Array = PackedVector2Array()

# Firing flash effect
var _flash_timer: float = 0.0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Configure renderer from a TowerDefinition.
func setup(definition: TowerDefinition) -> void:
	_shape_sides = definition.shape_sides
	_shape_radius = definition.shape_radius
	_color = definition.color
	_range = definition.base_range
	_current_tier = 0
	mark_dirty()

## Update the displayed tier (affects outline brightness and dot count).
func set_tier(tier: int) -> void:
	_current_tier = maxi(tier, 0)
	mark_dirty()

## Update the displayed range (used for range indicator circle).
func set_range(new_range: float) -> void:
	_range = maxf(new_range, 0.0)
	mark_dirty()

## Mark the polygon point cache as dirty and request a redraw.
func mark_dirty() -> void:
	_cache_dirty = true
	queue_redraw()

## Trigger a firing flash effect.
func flash() -> void:
	_flash_timer = 0.1
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
		queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Regenerate cached polygon points only when dirty
	if _cache_dirty:
		_cached_aura_points = _get_polygon_points(_shape_sides, _shape_radius * 1.8)
		_cached_platform_points = _get_polygon_points(_shape_sides, _shape_radius * PLATFORM_SCALE)
		_cached_shape_points = _get_polygon_points(_shape_sides, _shape_radius)
		_cache_dirty = false

	# 1. Range indicator (drawn first so it appears behind everything)
	if show_range:
		_draw_range_indicator()

	# 2. Aura glow behind tower
	var aura_color := Color(_color.r, _color.g, _color.b, 0.1)
	draw_colored_polygon(_cached_aura_points, aura_color)

	# 3. Platform (darker, larger base)
	var platform_color := Color(
		_color.r * PLATFORM_DARK_FACTOR,
		_color.g * PLATFORM_DARK_FACTOR,
		_color.b * PLATFORM_DARK_FACTOR,
		1.0
	)
	draw_colored_polygon(_cached_platform_points, platform_color)

	# 4. Main shape
	draw_colored_polygon(_cached_shape_points, _color)

	# 5. Outline — brighter at higher tiers
	var outline_brightness: float = minf(0.8 + float(_current_tier) * 0.1, 1.0)
	var outline_color := Color(outline_brightness, outline_brightness, outline_brightness, 0.85)
	var outline_width: float = OUTLINE_BASE_WIDTH + float(_current_tier) * OUTLINE_TIER_WIDTH
	_draw_polygon_outline(_cached_shape_points, outline_color, outline_width)

	# 6. Tier indicator dots (one dot per tier, centered below the tower)
	if _current_tier > 0:
		_draw_tier_dots()

	# 7. Firing flash effect
	if _flash_timer > 0.0:
		var flash_alpha: float = _flash_timer / 0.1
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 1.0, 1.0, flash_alpha))

## Draw a filled circle for range with a thin border.
func _draw_range_indicator() -> void:
	draw_circle(Vector2.ZERO, _range, Color(_color.r, _color.g, _color.b, RANGE_INDICATOR_ALPHA))
	# Draw border as a polygon approximation
	var border_points := _get_polygon_points(16, _range)
	_draw_polygon_outline(border_points, Color(_color.r, _color.g, _color.b, RANGE_BORDER_ALPHA), RANGE_BORDER_WIDTH)

func _draw_tier_dots() -> void:
	var total_width: float = float(_current_tier - 1) * TIER_DOT_SPACING
	var start_x: float = -total_width / 2.0
	for i in range(_current_tier):
		var dot_x: float = start_x + float(i) * TIER_DOT_SPACING
		var dot_pos := Vector2(dot_x, TIER_DOT_OFFSET_Y)
		draw_circle(dot_pos, TIE_DOT_RADIUS, Color.WHITE)
		draw_circle(dot_pos, TIE_DOT_RADIUS, Color(0.0, 0.0, 0.0, 0.4), false, 1.0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns polygon points for a regular n-sided polygon.
func _get_polygon_points(sides: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n: int = maxi(sides, 3)
	for i in range(n):
		var angle: float = (TAU * float(i) / float(n)) - PI / 2.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _draw_polygon_outline(points: PackedVector2Array, outline_color: Color, width: float) -> void:
	var n: int = points.size()
	for i in range(n):
		draw_line(points[i], points[(i + 1) % n], outline_color, width)
