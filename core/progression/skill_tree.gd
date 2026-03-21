class_name SkillTree
extends Resource

## Represents the full skill tree for one tower type.
## Nodes are unlocked with diamonds; each may require a prerequisite node.

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var nodes: Array[SkillNode] = []

# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

## Returns true if node_index can be unlocked given the current unlocked_array.
## Checks: valid index, not already unlocked, and prerequisite satisfied.
func can_unlock_node(node_index: int, unlocked_array: Array) -> bool:
	if node_index < 0 or node_index >= nodes.size():
		return false
	if unlocked_array.has(node_index):
		return false
	var node: SkillNode = nodes[node_index]
	if node.prerequisite_index != -1 and not unlocked_array.has(node.prerequisite_index):
		return false
	return true

## Returns the diamond cost for the node at node_index, or 0 if invalid.
func get_node_cost(node_index: int) -> int:
	if node_index < 0 or node_index >= nodes.size():
		return 0
	return nodes[node_index].cost

## Returns the total cost to unlock every node in this tree.
func get_total_cost() -> int:
	var total: int = 0
	for node in nodes:
		total += node.cost
	return total

## Returns a list of node indices that can currently be unlocked.
func get_unlockable_nodes(unlocked_array: Array) -> Array[int]:
	var result: Array[int] = []
	for i in range(nodes.size()):
		if can_unlock_node(i, unlocked_array):
			result.append(i)
	return result

## Returns a dict with summed stat bonuses from all unlocked nodes.
## Keys: damage, fire_rate, range
func get_stat_bonuses(unlocked_array: Array) -> Dictionary:
	var bonuses: Dictionary = {"damage": 0.0, "fire_rate": 0.0, "range": 0.0}
	for idx in unlocked_array:
		if idx < 0 or idx >= nodes.size():
			continue
		var node: SkillNode = nodes[idx]
		bonuses["damage"] = (bonuses["damage"] as float) + node.damage_bonus
		bonuses["fire_rate"] = (bonuses["fire_rate"] as float) + node.fire_rate_bonus
		bonuses["range"] = (bonuses["range"] as float) + node.range_bonus
	return bonuses
