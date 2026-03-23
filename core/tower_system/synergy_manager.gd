class_name SynergyManager
extends Node

## Detects and manages tower synergy combos based on proximity.
## Each tower can participate in at most one synergy at a time.
## Higher-priority synergies win when a tower qualifies for multiple.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal synergy_activated(tower_a: Tower, tower_b: Tower, synergy_type: int, synergy_name: String)

# ---------------------------------------------------------------------------
# Synergy Pair Definitions (sorted by priority, highest first)
# ---------------------------------------------------------------------------

var SYNERGY_PAIRS: Array = [
	{"type_a": Enums.TowerType.CRYO_ARRAY,    "type_b": Enums.TowerType.ARC_EMITTER,  "synergy": Enums.SynergyType.SHATTER,    "name": "Shatter",    "priority": 8},
	{"type_a": Enums.TowerType.MISSILE_POD,    "type_b": Enums.TowerType.BEAM_SPIRE,   "synergy": Enums.SynergyType.FOCUS_FIRE,  "name": "Focus Fire", "priority": 7},
	{"type_a": Enums.TowerType.ARC_EMITTER,    "type_b": Enums.TowerType.BEAM_SPIRE,   "synergy": Enums.SynergyType.CONDUIT,     "name": "Conduit",    "priority": 6},
	{"type_a": Enums.TowerType.NANO_HIVE,      "type_b": Enums.TowerType.BEAM_SPIRE,   "synergy": Enums.SynergyType.AMPLIFY,     "name": "Amplify",    "priority": 5},
	{"type_a": Enums.TowerType.CRYO_ARRAY,     "type_b": Enums.TowerType.MISSILE_POD,  "synergy": Enums.SynergyType.FROSTBITE,   "name": "Frostbite",  "priority": 4},
	{"type_a": Enums.TowerType.PULSE_CANNON,   "type_b": Enums.TowerType.CRYO_ARRAY,   "synergy": Enums.SynergyType.COLD_SNAP,   "name": "Cold Snap",  "priority": 3},
	{"type_a": Enums.TowerType.PULSE_CANNON,   "type_b": Enums.TowerType.MISSILE_POD,  "synergy": Enums.SynergyType.BARRAGE,     "name": "Barrage",    "priority": 2},
	{"type_a": Enums.TowerType.HARVESTER,       "type_b": Enums.TowerType.NANO_HIVE,    "synergy": Enums.SynergyType.EFFICIENCY,  "name": "Efficiency", "priority": 1},
]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Set of discovered synergy type ints
var _discovered: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Recalculate all synergies for towers under the given parent node.
## Clears existing synergies, then greedily assigns in priority order.
func recalculate(towers_node: Node2D) -> void:
	var tower_list: Array = []
	for child in towers_node.get_children():
		if child is Tower:
			(child as Tower).clear_synergy()
			tower_list.append(child as Tower)

	var assigned: Dictionary = {}  # tower instance_id -> true

	for pair_def in SYNERGY_PAIRS:
		var type_a: int = pair_def["type_a"]
		var type_b: int = pair_def["type_b"]
		var synergy: int = pair_def["synergy"]
		var sname: String = pair_def["name"]

		# Find all unassigned towers of each type
		var towers_a: Array = []
		var towers_b: Array = []
		for t in tower_list:
			if assigned.has(t.get_instance_id()):
				continue
			var tt: int = _get_tower_type(t)
			if tt == type_a:
				towers_a.append(t)
			elif tt == type_b:
				towers_b.append(t)

		# Try to pair closest qualifying towers
		for ta in towers_a:
			if assigned.has(ta.get_instance_id()):
				continue
			var best_b: Tower = null
			var best_dist: float = Constants.SYNERGY_RANGE
			for tb in towers_b:
				if assigned.has(tb.get_instance_id()):
					continue
				var dist: float = ta.global_position.distance_to(tb.global_position)
				if dist <= best_dist:
					best_dist = dist
					best_b = tb
			if best_b != null:
				_assign_synergy(ta, best_b, synergy, sname, assigned)

## Returns whether the given synergy type has been discovered this session.
func is_discovered(synergy_type: int) -> bool:
	return _discovered.has(synergy_type)

## Returns all discovered synergy type ints.
func get_all_discovered() -> Array:
	return _discovered.keys()

## Loads previously discovered synergies from save data.
func load_discovered(discovered_array: Array) -> void:
	for s in discovered_array:
		_discovered[s as int] = true

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _get_tower_type(tower: Tower) -> int:
	if not tower.is_initialized():
		return -1
	return tower.get_tower_type()

func _assign_synergy(ta: Tower, tb: Tower, synergy: int, sname: String, assigned: Dictionary) -> void:
	ta.set_synergy(synergy, tb.get_instance_id())
	tb.set_synergy(synergy, ta.get_instance_id())
	assigned[ta.get_instance_id()] = true
	assigned[tb.get_instance_id()] = true

	if not _discovered.has(synergy):
		_discovered[synergy] = true
		synergy_activated.emit(ta, tb, synergy, sname)
