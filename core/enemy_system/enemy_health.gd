class_name EnemyHealth
extends Node

## Manages HP, shield, armor, and resistance for a single enemy instance.
## Attach as a child of Enemy. Call initialize() before use.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever HP or shield values change. hp and max_hp are current values.
signal health_changed(hp: float, max_hp: float, shield: float)

## Emitted when HP reaches zero (after all damage is applied).
signal died()

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var _max_hp: float = 100.0
var _hp: float = 100.0
var _armor: float = 0.0
var _shield: float = 0.0
var _resistance_map: Dictionary = {}
var _dead: bool = false

# Tank Fortified mechanic
var _is_fortified: bool = false
var _fortified_type: int = -1
var _fortified_reduction: float = Constants.TANK_FORTIFIED_REDUCTION

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Sets up the health component from base stats.
## resistance_map: Dictionary[Enums.DamageType, float] — resistance fractions 0.0–1.0.
func initialize(hp: float, armor: float, shield: float, resistance_map: Dictionary = {}) -> void:
	_max_hp = maxf(hp, 1.0)
	_hp = _max_hp
	_armor = maxf(armor, 0.0)
	_shield = maxf(shield, 0.0)
	_resistance_map = resistance_map.duplicate()
	_dead = false
	health_changed.emit(_hp, _max_hp, _shield)

## Applies damage of the given type. Returns actual damage dealt to HP.
## Order: resistance reduction → armor reduction (diminishing returns) → shield absorption → HP.
## If ignore_armor is true, skip the armor reduction step.
func take_damage(amount: float, damage_type: Enums.DamageType, ignore_armor: bool = false) -> float:
	if _dead:
		return 0.0

	# 1. Resistance
	var resistance: float = _resistance_map.get(damage_type, 0.0) as float
	var reduced: float = amount * (1.0 - clampf(resistance, 0.0, 1.0))

	# 1b. Tank Fortified — 25% reduction from first tower type that hits
	if _is_fortified:
		if _fortified_type == -1:
			_fortified_type = damage_type as int
		if damage_type as int == _fortified_type:
			reduced *= (1.0 - _fortified_reduction)

	# 2. Armor (diminishing-returns percentage reduction)
	var after_armor: float = reduced
	if not ignore_armor:
		var armor_reduction: float = _armor / (_armor + 100.0)
		after_armor = reduced * (1.0 - armor_reduction)

	# 3. Shield absorbs first
	var hp_damage: float = after_armor
	if _shield > 0.0:
		var shield_absorbed: float = minf(_shield, after_armor)
		_shield -= shield_absorbed
		hp_damage = after_armor - shield_absorbed

	# 4. Apply to HP
	_hp = maxf(_hp - hp_damage, 0.0)
	health_changed.emit(_hp, _max_hp, _shield)

	if _hp <= 0.0 and not _dead:
		_dead = true
		died.emit()

	return hp_damage

## Heals the enemy by amount, capped at max HP. Does not revive a dead enemy.
func heal(amount: float) -> void:
	if _dead:
		return
	_hp = minf(_hp + maxf(amount, 0.0), _max_hp)
	health_changed.emit(_hp, _max_hp, _shield)

## Adds shield points on top of the current shield.
func add_shield(amount: float) -> void:
	_shield += maxf(amount, 0.0)
	health_changed.emit(_hp, _max_hp, _shield)

## Returns true if the enemy has HP remaining.
func is_alive() -> bool:
	return not _dead

## Returns current HP as a fraction of max HP (0.0–1.0).
func get_hp_percentage() -> float:
	if _max_hp <= 0.0:
		return 0.0
	return _hp / _max_hp

## Read-only accessors
func get_hp() -> float:
	return _hp

func get_max_hp() -> float:
	return _max_hp

func get_shield() -> float:
	return _shield

## Sets HP to a fraction of max HP and emits health_changed.
func set_hp_fraction(fraction: float) -> void:
	_hp = _max_hp * clampf(fraction, 0.0, 1.0)
	health_changed.emit(_hp, _max_hp, _shield)

## Returns a copy of the current resistance map.
func get_resistance_map() -> Dictionary:
	return _resistance_map.duplicate()

## Adds an adaptation resistance bonus for a damage type, capped at cap.
func apply_resistance_bonus(dtype: int, amount: float, cap: float = 0.75) -> void:
	var existing: float = _resistance_map.get(dtype, 0.0)
	_resistance_map[dtype] = minf(existing + amount, cap)

## Scales max HP by multiplier, preserving the current HP fraction.
func scale_max_hp(multiplier: float) -> void:
	var frac: float = _hp / maxf(_max_hp, 1.0)
	_max_hp *= multiplier
	_hp = _max_hp * frac
	health_changed.emit(_hp, _max_hp, _shield)

## Enables the Tank Fortified mechanic (25% reduction from first damage type).
func enable_fortified() -> void:
	_is_fortified = true
	_fortified_type = -1

## Returns the damage type the Tank is fortified against, or -1 if unset.
func get_fortified_type() -> int:
	return _fortified_type
