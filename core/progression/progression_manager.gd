class_name ProgressionManager
extends Node

## Manages all meta-progression state: skill trees, global upgrades, and hero unlocks.
## Reads/writes to SaveManager's progression section and spends diamonds via EconomyManager.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal skill_unlocked(tower_type: int, node_index: int)
signal global_upgraded(upgrade_id: String, new_tier: int)
signal hero_unlocked(tower_type: int)

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

var _economy_manager
var _save_manager

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------

## skill_trees[tower_type int] -> SkillTree
var _skill_trees: Dictionary = {}

## unlocked_nodes[tower_type int] -> Array[int]
var _unlocked_nodes: Dictionary = {}

## global_upgrade_tiers[upgrade_id String] -> int
var _global_upgrade_tiers: Dictionary = {}

## heroes_unlocked: Array of tower_type ints
var _heroes_unlocked: Array = []

# ---------------------------------------------------------------------------
# Global Upgrades Definition
# ---------------------------------------------------------------------------

## Maps upgrade_id to its value_per_tier (float).
const GLOBAL_UPGRADES: Dictionary = {
	"starting_gold": 25.0,
	"tower_cost_reduction": 1.0,
	"extra_lives": 1.0,
	"ability_cooldown": 2.0,
	"adaptation_slowdown": 2.0,
	"gold_per_kill": 3.0,
	"tower_sell_refund": 2.0,
	"hero_duration": 1.0
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Injects EconomyManager and SaveManager references, then loads saved state.
func setup(em, sm) -> void:
	_economy_manager = em
	_save_manager = sm
	_load_from_save()

# ---------------------------------------------------------------------------
# Skill Tree API
# ---------------------------------------------------------------------------

## Attempts to unlock a skill node for the given tower_type.
## Returns true on success; false if prereq not met, already unlocked, or insufficient diamonds.
func unlock_skill_node(tower_type: int, node_index: int) -> bool:
	var tree: SkillTree = _get_skill_tree(tower_type)
	if tree == null:
		return false

	var unlocked: Array = _get_unlocked_nodes(tower_type)
	if not tree.can_unlock_node(node_index, unlocked):
		return false

	var cost: int = tree.get_node_cost(node_index)
	if not _economy_manager.spend_diamonds(cost):
		return false

	unlocked.append(node_index)
	_unlocked_nodes[tower_type] = unlocked

	# Check if this node grants a hero unlock
	var node: SkillNode = tree.nodes[node_index]
	if node.is_hero_unlock and not _heroes_unlocked.has(tower_type):
		_heroes_unlocked.append(tower_type)
		hero_unlocked.emit(tower_type)

	_save_to_save()
	skill_unlocked.emit(tower_type, node_index)
	return true

## Returns the aggregated stat bonuses from all unlocked skill nodes for a tower type.
func get_skill_bonuses(tower_type: int) -> Dictionary:
	var tree: SkillTree = _get_skill_tree(tower_type)
	if tree == null:
		return {"damage": 0.0, "fire_rate": 0.0, "range": 0.0}
	var unlocked: Array = _get_unlocked_nodes(tower_type)
	return tree.get_stat_bonuses(unlocked)

## Returns true if the hero for this tower type has been unlocked.
func is_hero_unlocked(tower_type: int) -> bool:
	return _heroes_unlocked.has(tower_type)

# ---------------------------------------------------------------------------
# Global Upgrade API
# ---------------------------------------------------------------------------

## Attempts to purchase the next tier of the given global upgrade.
## Returns true on success.
func upgrade_global(upgrade_id: String) -> bool:
	if not GLOBAL_UPGRADES.has(upgrade_id):
		return false

	var current_tier: int = get_global_upgrade_tier(upgrade_id)
	if current_tier >= 10:
		return false

	var cost: int = Constants.GLOBAL_UPGRADE_COSTS[current_tier] as int
	if not _economy_manager.spend_diamonds(cost):
		return false

	_global_upgrade_tiers[upgrade_id] = current_tier + 1
	_save_to_save()
	global_upgraded.emit(upgrade_id, current_tier + 1)
	return true

## Returns the current tier for the given upgrade_id (0 = not purchased).
func get_global_upgrade_tier(upgrade_id: String) -> int:
	return _global_upgrade_tiers.get(upgrade_id, 0) as int

# ---------------------------------------------------------------------------
# Convenience Getters
# ---------------------------------------------------------------------------

## Returns the total bonus starting gold from the "starting_gold" upgrade.
func get_starting_gold_bonus() -> int:
	var tier: int = get_global_upgrade_tier("starting_gold")
	return int(GLOBAL_UPGRADES["starting_gold"] * float(tier))

## Returns the total extra lives from the "extra_lives" upgrade.
func get_extra_lives() -> int:
	var tier: int = get_global_upgrade_tier("extra_lives")
	return int(GLOBAL_UPGRADES["extra_lives"] * float(tier))

## Returns the tower cost discount percent from the "tower_cost_reduction" upgrade.
func get_tower_cost_discount() -> int:
	var tier: int = get_global_upgrade_tier("tower_cost_reduction")
	return int(GLOBAL_UPGRADES["tower_cost_reduction"] * float(tier))

## Returns the ability cooldown reduction in seconds from the "ability_cooldown" upgrade.
func get_ability_cooldown_reduction() -> float:
	var tier: int = get_global_upgrade_tier("ability_cooldown")
	return GLOBAL_UPGRADES["ability_cooldown"] * float(tier)

## Returns the sell refund bonus percent from the "tower_sell_refund" upgrade.
func get_sell_refund_bonus() -> int:
	var tier: int = get_global_upgrade_tier("tower_sell_refund")
	return int(GLOBAL_UPGRADES["tower_sell_refund"] * float(tier))

## Returns the hero duration bonus in seconds from the "hero_duration" upgrade.
func get_hero_duration_bonus() -> float:
	var tier: int = get_global_upgrade_tier("hero_duration")
	return GLOBAL_UPGRADES["hero_duration"] * float(tier)

## Returns the gold-per-kill bonus from the "gold_per_kill" upgrade.
func get_gold_per_kill_bonus() -> int:
	var tier: int = get_global_upgrade_tier("gold_per_kill")
	return int(GLOBAL_UPGRADES["gold_per_kill"] * float(tier))

# ---------------------------------------------------------------------------
# Internal: Skill Tree Construction
# ---------------------------------------------------------------------------

## Returns the SkillTree for tower_type, building a default 10-node tree if needed.
func _get_skill_tree(tower_type: int) -> SkillTree:
	if _skill_trees.has(tower_type):
		return _skill_trees[tower_type] as SkillTree

	var tree := SkillTree.new()
	tree.tower_type = tower_type as Enums.TowerType

	# Build 10 default nodes: chain 0→1→2→3→4, 5→6→7→8→9 (independent second branch)
	# Node 9 is the hero unlock
	var costs: Array = Constants.SKILL_NODE_COSTS
	for i in range(10):
		var node := SkillNode.new()
		node.id = "node_%d" % i
		node.display_name = "Skill %d" % i
		node.description = ""
		node.node_index = i
		node.cost = costs[i] as int
		if i == 0:
			node.prerequisite_index = -1
		elif i == 5:
			node.prerequisite_index = -1
		elif i < 5:
			node.prerequisite_index = i - 1
		else:
			node.prerequisite_index = i - 1
		node.damage_bonus = 2.0 if i < 5 else 0.0
		node.fire_rate_bonus = 0.0 if i < 5 else 0.05
		node.range_bonus = 0.0
		node.is_hero_unlock = (i == 9)
		tree.nodes.append(node)

	_skill_trees[tower_type] = tree
	return tree

## Returns the mutable unlocked node array for a tower type, initializing if needed.
func _get_unlocked_nodes(tower_type: int) -> Array:
	if not _unlocked_nodes.has(tower_type):
		_unlocked_nodes[tower_type] = []
	return _unlocked_nodes[tower_type]

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _load_from_save() -> void:
	if _save_manager == null:
		return
	var prog: Dictionary = _save_manager.data.get("progression", {})

	# Load global upgrade tiers
	var saved_upgrades: Dictionary = prog.get("global_upgrades", {})
	for key in saved_upgrades.keys():
		_global_upgrade_tiers[key] = saved_upgrades[key] as int

	# Load skill tree node unlocks (stored as dict: tower_type_str -> Array[int])
	var saved_trees: Dictionary = prog.get("skill_trees", {})
	for key in saved_trees.keys():
		var tower_type_int: int = int(key)
		_unlocked_nodes[tower_type_int] = saved_trees[key] as Array

	# Load hero unlocks
	var saved_heroes: Array = prog.get("heroes_unlocked", [])
	for h in saved_heroes:
		_heroes_unlocked.append(h as int)

func _save_to_save() -> void:
	if _save_manager == null:
		return
	var prog: Dictionary = _save_manager.data["progression"]

	# Save global upgrade tiers
	prog["global_upgrades"] = _global_upgrade_tiers.duplicate()

	# Save skill tree node unlocks
	var trees_dict: Dictionary = {}
	for tower_type in _unlocked_nodes.keys():
		trees_dict[str(tower_type)] = _unlocked_nodes[tower_type].duplicate()
	prog["skill_trees"] = trees_dict

	# Save hero unlocks
	prog["heroes_unlocked"] = _heroes_unlocked.duplicate()
