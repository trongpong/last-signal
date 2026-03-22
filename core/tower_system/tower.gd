class_name Tower
extends Node2D

## Base tower node. Call initialize(def) after adding to scene tree.
## Manages combat stats, upgrade path, cooldown, and buff state.
## Creates TierTree, TowerTargeting, and TowerRenderer as children.

const MAX_FIRE_RATE: float = 10.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted each time the tower fires a projectile.
signal fired(tower: Tower, target_pos: Vector2)

## Emitted when the tower is sold.
signal sold(tower: Tower)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var _definition: TowerDefinition = null
var _tier_tree: TierTree = null
var _targeting: TowerTargeting = null
var _renderer: TowerRenderer = null

var current_damage: float = 0.0
var current_fire_rate: float = 0.0
var current_range: float = 0.0
var current_tier: int = 0
var targeting_mode: int = Enums.TargetingMode.FIRST

var _upgrade_path: Array = []
var _base_cost: int = 0
var _upgrade_cost_total: int = 0

# Skill tree bonuses from ProgressionManager
var _skill_damage_bonus: float = 0.0
var _skill_fire_rate_bonus: float = 0.0
var _skill_range_bonus: float = 0.0

# Cooldown: seconds remaining before the tower can fire again
var _fire_cooldown: float = 0.0

# Buff state (applied by support towers)
# Dictionary keyed by source Node, value is { "damage_mult": float, "fire_rate_mult": float }
var _buff_sources: Dictionary = {}
var _buff_damage_mult: float = 1.0
var _buff_fire_rate_mult: float = 1.0

var _initialized: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Fully initialises the tower from a TowerDefinition.
## Creates and attaches TierTree, TowerTargeting, TowerRenderer children.
func initialize(def: TowerDefinition) -> void:
	_definition = def
	_base_cost = def.cost
	_upgrade_cost_total = 0

	# Set default targeting mode from definition (first available, or FIRST)
	if def.targeting_modes.size() > 0:
		targeting_mode = def.targeting_modes[0] as int
	else:
		targeting_mode = Enums.TargetingMode.FIRST

	# Build tier tree
	_tier_tree = TierTree.new()
	_tier_tree.setup(def.tier_branches)

	# Targeting component
	_targeting = TowerTargeting.new()
	_targeting.name = "TowerTargeting"
	add_child(_targeting)

	# Renderer component
	_renderer = TowerRenderer.new()
	_renderer.name = "TowerRenderer"
	add_child(_renderer)
	_renderer.setup(def)

	# Calculate base stats
	_recalculate_stats()

	_initialized = true

# ---------------------------------------------------------------------------
# Process (cooldown tracking only; actual firing is driven externally)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _initialized:
		return
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

# ---------------------------------------------------------------------------
# Firing
# ---------------------------------------------------------------------------

## Returns true if the cooldown has expired and the tower can fire.
func can_fire() -> bool:
	return _initialized and _fire_cooldown <= 0.0 and current_fire_rate > 0.0

## Call after the tower fires to reset the cooldown.
func on_fired() -> void:
	if current_fire_rate > 0.0:
		_fire_cooldown = 1.0 / current_fire_rate
	else:
		_fire_cooldown = 999.0

## Applies skill tree bonuses from ProgressionManager.
## bonuses: Dictionary with keys "damage", "fire_rate", "range", "specials"
func apply_skill_bonuses(bonuses: Dictionary) -> void:
	_skill_damage_bonus = bonuses.get("damage", 0.0) as float
	_skill_fire_rate_bonus = bonuses.get("fire_rate", 0.0) as float
	_skill_range_bonus = bonuses.get("range", 0.0) as float
	_recalculate_stats()

## Returns damage including any active buff multiplier.
func get_effective_damage() -> float:
	return current_damage * _buff_damage_mult

## Returns fire rate including any active buff multiplier.
func get_effective_fire_rate() -> float:
	return current_fire_rate * _buff_fire_rate_mult

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

## Apply the next upgrade by choosing a branch index.
## Updates stats and notifies the renderer.
func apply_upgrade(choice: int) -> void:
	var options: Array = _tier_tree.get_upgrade_options(_upgrade_path)
	if choice < 0 or choice >= options.size():
		return

	var branch: Dictionary = options[choice]
	_upgrade_cost_total += branch.get("cost", 0) as int
	_upgrade_path.append(choice)
	current_tier = _upgrade_path.size()

	_recalculate_stats()

	if _renderer != null:
		_renderer.set_tier(current_tier)
		_renderer.set_range(current_range)

# ---------------------------------------------------------------------------
# Targeting mode
# ---------------------------------------------------------------------------

func set_targeting_mode(mode: int) -> void:
	targeting_mode = mode

# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------

func get_tier_tree() -> TierTree:
	return _tier_tree

## Returns a copy of the current upgrade path.
func get_upgrade_path() -> Array:
	return _upgrade_path.duplicate()

## Returns the total gold invested (base cost + all upgrade costs).
func get_total_investment() -> int:
	return _base_cost + _upgrade_cost_total

# ---------------------------------------------------------------------------
# Buff support
# ---------------------------------------------------------------------------

## Apply a buff from a support tower.
## source: the node applying the buff (used as dictionary key for stacking)
## damage_mult: damage multiplier (1.0 = no change)
## fire_rate_mult: fire rate multiplier (1.0 = no change)
func apply_buff(source: Node, damage_mult: float, fire_rate_mult: float) -> void:
	_buff_sources[source] = {
		"damage_mult": maxf(damage_mult, 0.0),
		"fire_rate_mult": maxf(fire_rate_mult, 0.0),
	}
	_recalculate_buff_multipliers()

## Remove a buff from a specific source.
func remove_buff(source: Node) -> void:
	_buff_sources.erase(source)
	_recalculate_buff_multipliers()

## Remove all active buffs (reset multipliers to 1.0).
func clear_buff() -> void:
	_buff_sources.clear()
	_buff_damage_mult = 1.0
	_buff_fire_rate_mult = 1.0

## Recalculate effective buff multipliers by taking the max from all sources.
func _recalculate_buff_multipliers() -> void:
	var max_damage_mult: float = 1.0
	var max_fire_rate_mult: float = 1.0
	for source in _buff_sources:
		var buff: Dictionary = _buff_sources[source]
		max_damage_mult = maxf(max_damage_mult, buff.get("damage_mult", 1.0))
		max_fire_rate_mult = maxf(max_fire_rate_mult, buff.get("fire_rate_mult", 1.0))
	_buff_damage_mult = minf(max_damage_mult, 3.0)
	_buff_fire_rate_mult = minf(max_fire_rate_mult, 3.0)

# ---------------------------------------------------------------------------
# Sell
# ---------------------------------------------------------------------------

## Emit the sold signal and free this node.
func sell() -> void:
	sold.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _recalculate_stats() -> void:
	if _definition == null or _tier_tree == null:
		return

	var base: Dictionary = {
		"damage": _definition.base_damage,
		"fire_rate": _definition.base_fire_rate,
		"range": _definition.base_range
	}
	var upgraded: Dictionary = _tier_tree.apply_upgrades(base, _upgrade_path)

	current_damage = (upgraded.get("damage", _definition.base_damage) as float) + _skill_damage_bonus
	current_fire_rate = (upgraded.get("fire_rate", _definition.base_fire_rate) as float) + _skill_fire_rate_bonus
	current_fire_rate = minf(current_fire_rate, MAX_FIRE_RATE)
	current_range = (upgraded.get("range", _definition.base_range) as float) + _skill_range_bonus
