class_name Hero
extends Node2D

## Runtime hero unit that persists on the field for a limited duration.
## Draws itself as a glowing octagon. Emits expired when the timer runs out.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal expired(hero: Hero)
signal attacked(target: Node2D, damage: float)

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

## Reference to the HeroDefinition resource providing combat stats.
var hero_definition: HeroDefinition = null

# Combat state
var _attack_timer: float = 0.0
var _target: Node2D = null

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
		return

	# --- Combat ---
	if hero_definition == null:
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var enemy: Node2D = _find_nearest_enemy()
		if enemy != null:
			var dmg: float = hero_definition.damage
			attacked.emit(enemy, dmg)
			_target = enemy
			# Reset timer based on attack_speed (attacks per second)
			var aspd: float = maxf(hero_definition.attack_speed, 0.01)
			_attack_timer = 1.0 / aspd
		else:
			_target = null
			# Retry next frame
			_attack_timer = 0.0

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

# ---------------------------------------------------------------------------
# Combat helpers
# ---------------------------------------------------------------------------

## Searches for the nearest valid enemy within the hero's attack range.
## Checks the "enemies" group first; falls back to scanning sibling containers
## for nodes named "Enemies" or "enemies".
func _find_nearest_enemy() -> Node2D:
	var range_sq: float = _get_attack_range_sq()
	var best: Node2D = null
	var best_dist_sq: float = range_sq

	# Try the "enemies" scene-tree group first
	var candidates: Array = get_tree().get_nodes_in_group("enemies") if is_inside_tree() else []

	# Fallback: scan parent for an enemy container node
	if candidates.is_empty() and is_inside_tree() and get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling.name.to_lower() == "enemies" or sibling.name.to_lower() == "enemycontainer":
				candidates = sibling.get_children()
				break

	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		var dist_sq: float = global_position.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate

	return best


## Returns the squared attack range for distance checks.
## Defaults to 200 px when no hero_definition is set.
func _get_attack_range_sq() -> float:
	var base_range: float = 200.0
	return base_range * base_range
