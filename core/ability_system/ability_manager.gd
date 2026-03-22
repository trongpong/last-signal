class_name AbilityManager
extends Node

## Manages up to 3 ability slots for the player.
## Creates Ability child nodes for each slot; handles activation routing.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ability_activated(ability_id: String, slot: int, target: Variant)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAX_SLOTS: int = 3

## Base cooldowns (seconds) for each ability type by string id.
const ABILITY_COOLDOWNS: Dictionary = {
	"orbital_strike": 60.0,
	"emp_burst": 45.0,
	"repair_wave": 40.0,
	"shield_matrix": 50.0,
	"overclock": 30.0,
	"scrap_salvage": 35.0
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Ordered list of ability IDs in each slot (up to MAX_SLOTS).
var _loadout: Array[String] = []

## Ability child nodes indexed by slot.
var _abilities: Array[Ability] = []

var _cooldown_reduction: float = 0.0

# ---------------------------------------------------------------------------
# Loadout Management
# ---------------------------------------------------------------------------

## Sets the ability loadout from an array of ability ID strings.
## Creates Ability children; removes previous ones. Caps at MAX_SLOTS.
func set_loadout(ability_ids: Array) -> void:
	# Remove existing ability children
	for ab in _abilities:
		if ab != null and is_instance_valid(ab):
			ab.queue_free()
	_abilities.clear()
	_loadout.clear()

	var count: int = mini(ability_ids.size(), MAX_SLOTS)
	for i in range(count):
		var ab_id: String = ability_ids[i] as String
		_loadout.append(ab_id)

		var ab := Ability.new()
		ab.name = "Ability_%d" % i
		add_child(ab)
		var cd: float = ABILITY_COOLDOWNS.get(ab_id, 60.0) as float
		ab.initialize(ab_id, cd)
		ab.cooldown_reduction = _cooldown_reduction
		_abilities.append(ab)

## Returns a copy of the current loadout (array of ability ID strings).
func get_loadout() -> Array[String]:
	return _loadout.duplicate()

## Reduces the cooldown of all abilities by the given amount.
func reduce_all_cooldowns(seconds: float) -> void:
	for ab in _abilities:
		if ab != null:
			ab.reduce_cooldown(seconds)

# ---------------------------------------------------------------------------
# Ability Access
# ---------------------------------------------------------------------------

## Returns the Ability node at the given slot index, or null if invalid.
func get_ability(slot: int) -> Ability:
	if slot < 0 or slot >= _abilities.size():
		return null
	return _abilities[slot]

# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

## Activates the ability in the given slot with the provided target.
## Returns true on success, false if slot invalid or ability on cooldown.
func activate_ability(slot: int, target: Variant = null) -> bool:
	var ab: Ability = get_ability(slot)
	if ab == null:
		return false
	if not ab.activate(target):
		return false
	var ab_id: String = _loadout[slot] if slot < _loadout.size() else ""
	ability_activated.emit(ab_id, slot, target)
	return true

# ---------------------------------------------------------------------------
# Cooldown Reduction
# ---------------------------------------------------------------------------

## Sets the fractional cooldown reduction applied to all ability slots.
func set_cooldown_reduction(reduction: float) -> void:
	_cooldown_reduction = reduction
	for ab in _abilities:
		if ab != null and is_instance_valid(ab):
			ab.cooldown_reduction = reduction
