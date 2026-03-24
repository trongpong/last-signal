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
var _skill_specials: Dictionary = {}  # "special_name" -> level
var _tier_specials: Dictionary = {}  # "special_string" -> count (from tier upgrade branches)

# Cooldown: seconds remaining before the tower can fire again
var _fire_cooldown: float = 0.0

# Buff state (applied by support towers)
# Dictionary keyed by source Node, value is { "damage_mult": float, "fire_rate_mult": float }
var _buff_sources: Dictionary = {}
var _buff_damage_mult: float = 1.0
var _buff_fire_rate_mult: float = 1.0

# Synergy state (managed by SynergyManager)
var _synergy_type: int = -1
var _synergy_partner_id: int = -1

# Last target tracking (for Focus Fire synergy)
var _last_target_id: int = -1

# Mastery bonuses (from TowerMasteryManager)
var _mastery_damage_bonus: float = 0.0
var _mastery_cost_discount: float = 0.0
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

## Adds extra seconds to the fire cooldown (e.g. reflective elite).
func add_fire_cooldown(seconds: float) -> void:
	_fire_cooldown += seconds

## Returns the TowerTargeting component.
func get_targeting() -> TowerTargeting:
	return _targeting

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
	_skill_specials.clear()
	for entry in bonuses.get("specials", []):
		var special: String = entry.get("special", "") as String
		var level: int = entry.get("level", 0) as int
		if special != "":
			_skill_specials[special] = level
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

## Returns the TowerDefinition resource, or null.
func get_definition() -> TowerDefinition:
	return _definition

func get_tower_type() -> Enums.TowerType:
	if _definition == null:
		return Enums.TowerType.PULSE_CANNON
	return _definition.tower_type

## Returns true if initialize() has been called successfully.
func is_initialized() -> bool:
	return _initialized

## Returns true if this tower is an income-generating tower (e.g. Harvester).
func is_income_tower() -> bool:
	return _definition != null and _definition.is_income

## Returns true if this tower is a support tower that buffs nearby towers.
func is_support_tower() -> bool:
	return _definition != null and _definition.is_support

## Returns the projectile speed from the definition (default 400 if uninitialized).
func get_projectile_speed() -> float:
	if _definition == null:
		return 400.0
	return _definition.projectile_speed

## Returns the damage type from the definition (default PULSE if uninitialized).
func get_damage_type() -> int:
	if _definition == null:
		return Enums.DamageType.PULSE
	return _definition.damage_type

## Proxy for TowerTargeting.select_target — avoids external access to _targeting.
func select_target(tower_pos: Vector2, attack_range: float, mode: int, enemy_data: Array) -> int:
	if _targeting == null:
		return -1
	return _targeting.select_target(tower_pos, attack_range, mode, enemy_data)

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
# Synergy
# ---------------------------------------------------------------------------

func set_synergy(synergy_type: int, partner_id: int) -> void:
	_synergy_type = synergy_type
	_synergy_partner_id = partner_id

func clear_synergy() -> void:
	_synergy_type = -1
	_synergy_partner_id = -1

func get_synergy_type() -> int:
	return _synergy_type

func has_synergy() -> bool:
	return _synergy_type >= 0

func get_synergy_partner_id() -> int:
	return _synergy_partner_id

func set_last_target_id(id: int) -> void:
	_last_target_id = id

func get_last_target_id() -> int:
	return _last_target_id

# ---------------------------------------------------------------------------
# Mastery
# ---------------------------------------------------------------------------

func apply_mastery_bonuses(bonuses: Dictionary) -> void:
	_mastery_damage_bonus = bonuses.get("damage_bonus", 0.0) as float
	_mastery_cost_discount = bonuses.get("cost_discount", 0.0) as float
	_recalculate_stats()

func get_mastery_cost_discount() -> float:
	return _mastery_cost_discount

func get_mastery_damage_bonus() -> float:
	return _mastery_damage_bonus

func get_skill_damage_bonus() -> float:
	return _skill_damage_bonus

func get_skill_fire_rate_bonus() -> float:
	return _skill_fire_rate_bonus

func get_skill_range_bonus() -> float:
	return _skill_range_bonus

# ---------------------------------------------------------------------------
# Sell
# ---------------------------------------------------------------------------

## Emit the sold signal and free this node.
func sell() -> void:
	sold.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Effective stats (base + tier upgrade specials + skill specials)
# ---------------------------------------------------------------------------

## Returns effective splash radius including tier upgrade and skill bonuses.
func get_effective_splash() -> float:
	if _definition == null:
		return 0.0
	var base: float = _definition.splash_radius
	for key in _tier_specials:
		if key.begins_with("splash+"):
			base += float(key.substr(7)) * float(_tier_specials[key])
		elif key.begins_with("splash="):
			base = maxf(base, float(key.substr(7)))
	for key in _skill_specials:
		if key.begins_with("splash+"):
			base += float(key.substr(7)) * float(_skill_specials[key])
	return base

## Returns effective chain count including tier upgrade and skill bonuses.
func get_effective_chain_count() -> int:
	if _definition == null:
		return 0
	var base: int = _definition.chain_count
	for key in _tier_specials:
		if key.begins_with("chain_count+"):
			base += int(key.substr(12)) * _tier_specials[key]
	for key in _skill_specials:
		if key.begins_with("chain_count+"):
			base += int(key.substr(12)) * _skill_specials[key]
	return base

## Returns the chain range including tier upgrade bonuses.
func get_effective_chain_range() -> float:
	if _definition == null:
		return 0.0
	var base: float = _definition.chain_range
	for key in _tier_specials:
		if key.begins_with("chain_range+"):
			base += float(key.substr(12)) * float(_tier_specials[key])
	return base

## Returns effective slow factor including tier upgrade and skill bonuses (lower = stronger).
func get_effective_slow_factor() -> float:
	if _definition == null:
		return 1.0
	var base: float = _definition.slow_factor
	for key in _tier_specials:
		if key.begins_with("slow_factor-"):
			base -= float(key.substr(12)) * float(_tier_specials[key])
	for key in _skill_specials:
		if key.begins_with("slow_power+"):
			base -= float(key.substr(11)) * float(_skill_specials[key])
	return clampf(base, 0.05, 1.0)

## Returns the slow duration including tier upgrade bonuses.
func get_effective_slow_duration() -> float:
	if _definition == null:
		return 0.0
	var base: float = _definition.slow_duration
	for key in _tier_specials:
		if key.begins_with("slow_duration+"):
			base += float(key.substr(14)) * float(_tier_specials[key])
	return base

## Returns effective income per wave including tier upgrade and skill bonuses.
func get_effective_income() -> int:
	if _definition == null:
		return 0
	var base: int = _definition.income_per_wave
	for key in _tier_specials:
		if key.begins_with("income+"):
			base += int(key.substr(7)) * _tier_specials[key]
	for key in _skill_specials:
		if key.begins_with("gold_bonus+"):
			base += int(key.substr(11)) * _skill_specials[key]
	return base

## Returns effective buff range including skill range bonus.
func get_effective_buff_range() -> float:
	if _definition == null:
		return 0.0
	return _definition.buff_range + _skill_range_bonus

## Returns effective buff damage multiplier including tier upgrade and skill bonuses.
func get_effective_buff_damage_mult() -> float:
	if _definition == null:
		return 1.0
	var base: float = _definition.buff_damage_mult
	for key in _tier_specials:
		if key.begins_with("buff_damage_mult+"):
			base += float(key.substr(17)) * float(_tier_specials[key])
	for key in _skill_specials:
		if key.begins_with("buff_power+"):
			base += float(key.substr(11)) * float(_skill_specials[key])
	return base

## Returns the buff fire rate multiplier including tier upgrade bonuses.
func get_effective_buff_fire_rate_mult() -> float:
	if _definition == null:
		return 1.0
	var base: float = _definition.buff_fire_rate_mult
	for key in _tier_specials:
		if key.begins_with("buff_fire_rate_mult+"):
			base += float(key.substr(20)) * float(_tier_specials[key])
	return base

## Returns true if this tower has the named special active (from skill tree or tier upgrades).
func has_special(special_name: String) -> bool:
	return _skill_specials.has(special_name) or _tier_specials.has(special_name)

## Returns the level of the named skill special, or 0 if not present.
## For tier specials, returns the count (how many times that special was chosen).
func get_special_level(special_name: String) -> int:
	var level: int = _skill_specials.get(special_name, 0) as int
	level += _tier_specials.get(special_name, 0) as int
	return level

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

	# Collect tier upgrade specials
	_tier_specials.clear()
	for special in _tier_tree.collect_specials(_upgrade_path):
		_tier_specials[special] = (_tier_specials.get(special, 0) as int) + 1

	current_damage = (upgraded.get("damage", _definition.base_damage) as float) + _skill_damage_bonus
	current_damage *= (1.0 + _mastery_damage_bonus)
	current_fire_rate = (upgraded.get("fire_rate", _definition.base_fire_rate) as float) + _skill_fire_rate_bonus
	current_fire_rate = clampf(current_fire_rate, 0.1, MAX_FIRE_RATE)
	current_range = (upgraded.get("range", _definition.base_range) as float) + _skill_range_bonus
