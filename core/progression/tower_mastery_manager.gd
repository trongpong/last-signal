class_name TowerMasteryManager
extends Node

## Tracks per-tower-type lifetime kills and damage across matches.
## Mastery tiers unlock permanent damage bonuses and cost discounts.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal mastery_tier_reached(tower_type: int, tier_name: String)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _save_manager = null
var _match_kills: Dictionary = {}   # tower_type int -> int
var _match_damage: Dictionary = {}  # tower_type int -> float
var _lifetime_data: Dictionary = {} # tower_type str -> { "kills": int, "damage": float }

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(save_manager) -> void:
	_save_manager = save_manager
	_match_kills.clear()
	_match_damage.clear()
	_load_from_save()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func record_kill(tower_type: int) -> void:
	if tower_type < 0:
		return
	_match_kills[tower_type] = _match_kills.get(tower_type, 0) + 1

func record_damage(tower_type: int, amount: float) -> void:
	if tower_type < 0:
		return
	_match_damage[tower_type] = (_match_damage.get(tower_type, 0.0) as float) + amount

func get_mastery_tier(tower_type: int) -> int:
	var kills: int = _get_lifetime_kills(tower_type)
	var tier: int = -1
	for i in range(Constants.MASTERY_TIERS.size()):
		if kills >= (Constants.MASTERY_TIERS[i]["kills"] as int):
			tier = i
	return tier

func get_mastery_bonuses(tower_type: int) -> Dictionary:
	var tier: int = get_mastery_tier(tower_type)
	var damage_bonus: float = 0.0
	var cost_discount: float = 0.0
	for i in range(tier + 1):
		damage_bonus += Constants.MASTERY_TIERS[i]["damage_bonus"] as float
		cost_discount += Constants.MASTERY_TIERS[i]["cost_discount"] as float
	return {"damage_bonus": damage_bonus, "cost_discount": cost_discount}

func get_lifetime_kills(tower_type: int) -> int:
	return _get_lifetime_kills(tower_type)

func get_lifetime_damage(tower_type: int) -> float:
	var key: String = str(tower_type)
	var data: Dictionary = _lifetime_data.get(key, {})
	return (data.get("damage", 0.0) as float) + (_match_damage.get(tower_type, 0.0) as float)

## Commits match stats to lifetime data and saves.
func commit_match_stats() -> void:
	for tower_type in _match_kills:
		var key: String = str(tower_type)
		if not _lifetime_data.has(key):
			_lifetime_data[key] = {"kills": 0, "damage": 0.0}
		var old_tier: int = get_mastery_tier(tower_type)
		_lifetime_data[key]["kills"] = (_lifetime_data[key]["kills"] as int) + (_match_kills[tower_type] as int)
		_lifetime_data[key]["damage"] = (_lifetime_data[key]["damage"] as float) + (_match_damage.get(tower_type, 0.0) as float)
		var new_tier: int = get_mastery_tier(tower_type)
		if new_tier > old_tier and new_tier >= 0:
			var tier_name: String = Constants.MASTERY_TIERS[new_tier]["name"] as String
			mastery_tier_reached.emit(tower_type, tier_name)
	for tower_type in _match_damage:
		var key: String = str(tower_type)
		if not _lifetime_data.has(key):
			_lifetime_data[key] = {"kills": 0, "damage": 0.0}
		if not _match_kills.has(tower_type):
			_lifetime_data[key]["damage"] = (_lifetime_data[key]["damage"] as float) + (_match_damage[tower_type] as float)
	_match_kills.clear()
	_match_damage.clear()
	_save_to_save()

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _get_lifetime_kills(tower_type: int) -> int:
	var key: String = str(tower_type)
	var data: Dictionary = _lifetime_data.get(key, {})
	return (data.get("kills", 0) as int) + (_match_kills.get(tower_type, 0) as int)

func _load_from_save() -> void:
	if _save_manager == null:
		return
	_lifetime_data = _save_manager.data.get("tower_mastery", {}).duplicate(true)

func _save_to_save() -> void:
	if _save_manager == null:
		return
	_save_manager.data["tower_mastery"] = _lifetime_data.duplicate(true)
	_save_manager.save_game()
