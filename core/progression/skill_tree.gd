class_name SkillTree
extends Resource

## Represents the full skill tree for one tower type.
## Each skill node can be leveled up to its max_level with diamonds.
## unlocked_levels is a Dictionary: { skill_index: current_level }.

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var nodes: Array[SkillNode] = []

# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

## Returns true if the skill at node_index can be upgraded one more level.
## Checks: valid index and current level < max_level.
func can_unlock_node(node_index: int, unlocked_levels: Dictionary) -> bool:
	if node_index < 0 or node_index >= nodes.size():
		return false
	var node: SkillNode = nodes[node_index]
	var current_level: int = unlocked_levels.get(node_index, 0) as int
	if current_level >= node.max_level:
		return false
	return true

## Returns the diamond cost for the next level of node at node_index, or 0 if invalid.
## Cost scales by current level using Constants.SKILL_NODE_COSTS.
func get_node_cost(node_index: int, unlocked_levels: Dictionary = {}) -> int:
	if node_index < 0 or node_index >= nodes.size():
		return 0
	var current_level: int = unlocked_levels.get(node_index, 0) as int
	var costs: Array = Constants.SKILL_NODE_COSTS
	if costs.is_empty():
		return 0
	var cost_idx: int = mini(current_level, costs.size() - 1)
	return costs[cost_idx] as int

## Returns the total cost to max out every node in this tree.
func get_total_cost() -> int:
	var total: int = 0
	var costs: Array = Constants.SKILL_NODE_COSTS
	if costs.is_empty():
		return 0
	for node in nodes:
		for lvl in range(node.max_level):
			var cost_idx: int = mini(lvl, costs.size() - 1)
			total += costs[cost_idx] as int
	return total

## Returns a list of node indices that can currently be upgraded.
func get_unlockable_nodes(unlocked_levels: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for i in range(nodes.size()):
		if can_unlock_node(i, unlocked_levels):
			result.append(i)
	return result

## Returns a dict with summed stat bonuses from all skill levels.
## Each node's per-level bonuses are multiplied by current level.
## Keys: damage, fire_rate, range, specials
func get_stat_bonuses(unlocked_levels: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {"damage": 0.0, "fire_rate": 0.0, "range": 0.0, "specials": []}
	for idx in unlocked_levels.keys():
		var skill_idx: int = idx as int
		if skill_idx < 0 or skill_idx >= nodes.size():
			continue
		var node: SkillNode = nodes[skill_idx]
		var level: int = unlocked_levels[idx] as int
		bonuses["damage"] = (bonuses["damage"] as float) + node.damage_bonus * float(level)
		bonuses["fire_rate"] = (bonuses["fire_rate"] as float) + node.fire_rate_bonus * float(level)
		bonuses["range"] = (bonuses["range"] as float) + node.range_bonus * float(level)
		if node.special != "" and level > 0:
			bonuses["specials"].append({"special": node.special, "level": level})
	return bonuses
