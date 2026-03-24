class_name TierTree
extends RefCounted

## Manages a tower's branching upgrade tree.
## branches: Array[Dictionary] — the top-level branch choices.
## chosen_path: Array[int] — list of branch indices chosen so far.
##
## Each branch dictionary has these keys:
##   name: String
##   display_name: String
##   damage_mult: float
##   fire_rate_mult: float
##   range_mult: float
##   cost: int
##   special: String
##   branches: Array  (sub-branches at the next tier)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var branches: Array = []

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func setup(branch_list: Array) -> void:
	branches = branch_list

# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

## Returns the Array of branch options available after following chosen_path.
## If chosen_path is empty, returns the top-level branches.
## Returns [] when the path has reached a leaf node.
func get_upgrade_options(chosen_path: Array) -> Array:
	var current_branches: Array = branches
	for choice in chosen_path:
		var idx: int = choice as int
		if idx < 0 or idx >= current_branches.size():
			return []
		var branch: Dictionary = current_branches[idx]
		current_branches = branch.get("branches", []) as Array
	return current_branches

## Returns the current tier depth (length of chosen_path).
func get_current_tier(chosen_path: Array) -> int:
	return chosen_path.size()

## Returns the gold cost to reach the NEXT upgrade from chosen_path by taking choice.
## Returns 0 if the choice is invalid.
func get_next_upgrade_cost(chosen_path: Array, choice: int) -> int:
	var options: Array = get_upgrade_options(chosen_path)
	if choice < 0 or choice >= options.size():
		return 0
	return (options[choice] as Dictionary).get("cost", 0) as int

## Returns the total gold cost of all upgrades along chosen_path.
func get_total_cost(chosen_path: Array) -> int:
	var total: int = 0
	var current_branches: Array = branches
	for choice in chosen_path:
		var idx: int = choice as int
		if idx < 0 or idx >= current_branches.size():
			break
		var branch: Dictionary = current_branches[idx]
		total += branch.get("cost", 0) as int
		current_branches = branch.get("branches", []) as Array
	return total

## Applies all upgrades along chosen_path to base_stats and returns the result.
## base_stats must contain: damage, fire_rate, range (all floats).
## Returns a new Dictionary with the scaled values.
func apply_upgrades(base_stats: Dictionary, chosen_path: Array) -> Dictionary:
	var result: Dictionary = {
		"damage": base_stats.get("damage", 0.0) as float,
		"fire_rate": base_stats.get("fire_rate", 0.0) as float,
		"range": base_stats.get("range", 0.0) as float
	}

	var current_branches: Array = branches
	for choice in chosen_path:
		var idx: int = choice as int
		if idx < 0 or idx >= current_branches.size():
			break
		var branch: Dictionary = current_branches[idx]
		result["damage"] = (result["damage"] as float) * (branch.get("damage_mult", 1.0) as float)
		result["fire_rate"] = (result["fire_rate"] as float) * (branch.get("fire_rate_mult", 1.0) as float)
		result["range"] = (result["range"] as float) * (branch.get("range_mult", 1.0) as float)
		current_branches = branch.get("branches", []) as Array

	return result

## Collects all non-empty special strings along chosen_path.
## Returns an Array of Strings (may contain duplicates if the same special appears at multiple tiers).
func collect_specials(chosen_path: Array) -> Array:
	var specials: Array = []
	var current_branches: Array = branches
	for choice in chosen_path:
		var idx: int = choice as int
		if idx < 0 or idx >= current_branches.size():
			break
		var branch: Dictionary = current_branches[idx]
		var special: String = branch.get("special", "") as String
		if special != "":
			specials.append(special)
		current_branches = branch.get("branches", []) as Array
	return specials
