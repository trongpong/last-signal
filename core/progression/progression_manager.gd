class_name ProgressionManager
extends Node

## Manages all meta-progression state: skill trees, global upgrades, and hero unlocks.
## Reads/writes to SaveManager's progression section and spends diamonds via EconomyManager.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal skill_unlocked(tower_type: int, node_index: int, new_level: int)
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

## unlocked_nodes[tower_type int] -> Dictionary { skill_index: current_level }
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

## Attempts to upgrade a skill node for the given tower_type by one level.
## Returns true on success; false if already at max level or insufficient diamonds.
func unlock_skill_node(tower_type: int, node_index: int) -> bool:
	var tree: SkillTree = _get_skill_tree(tower_type)
	if tree == null:
		return false

	var unlocked: Dictionary = _get_unlocked_nodes(tower_type)
	if not tree.can_unlock_node(node_index, unlocked):
		return false

	var cost: int = tree.get_node_cost(node_index, unlocked)
	if not _economy_manager.spend_diamonds(cost):
		return false

	var current_level: int = unlocked.get(node_index, 0) as int
	var new_level: int = current_level + 1
	unlocked[node_index] = new_level
	_unlocked_nodes[tower_type] = unlocked

	# Check if this node grants a hero unlock
	var node: SkillNode = tree.nodes[node_index]
	if node.is_hero_unlock and not _heroes_unlocked.has(tower_type):
		_heroes_unlocked.append(tower_type)
		hero_unlocked.emit(tower_type)

	_save_to_save()
	skill_unlocked.emit(tower_type, node_index, new_level)
	return true

## Returns the aggregated stat bonuses from all unlocked skill nodes for a tower type.
## Bonuses are multiplied by each skill's current level.
func get_skill_bonuses(tower_type: int) -> Dictionary:
	var tree: SkillTree = _get_skill_tree(tower_type)
	if tree == null:
		return {"damage": 0.0, "fire_rate": 0.0, "range": 0.0, "specials": []}
	var unlocked: Dictionary = _get_unlocked_nodes(tower_type)
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
	if current_tier >= Constants.GLOBAL_UPGRADE_COSTS.size():
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

## Returns the SkillTree for tower_type, building 5 thematic skill nodes if needed.
## Each skill is upgradeable to level 5. Bonuses represent per-level gains.
func _get_skill_tree(tower_type: int) -> SkillTree:
	if _skill_trees.has(tower_type):
		return _skill_trees[tower_type] as SkillTree

	var tree := SkillTree.new()
	tree.tower_type = tower_type as Enums.TowerType

	# skill_defs: Array of [id, display_name, description, damage, fire_rate, range, special]
	# Each entry represents per-level bonuses for a skill upgradeable to level 5.
	var skill_defs: Array = []
	match tower_type:
		Enums.TowerType.PULSE_CANNON:
			skill_defs = [
				["focused_beam", "Focused Beam", "Increases damage per level.", 3.0, 0.0, 0.0, ""],
				["rapid_cycling", "Rapid Cycling", "Increases fire rate per level.", 0.0, 0.05, 0.0, ""],
				["extended_barrel", "Extended Barrel", "Increases range per level.", 0.0, 0.0, 15.0, ""],
				["piercing_rounds", "Piercing Rounds", "Shots pierce through enemies at level 3 and above.", 0.0, 0.0, 0.0, "pierce"],
				["overcharge_protocol", "Overcharge Protocol", "Increases both damage and fire rate per level.", 5.0, 0.03, 0.0, ""],
			]
		Enums.TowerType.ARC_EMITTER:
			skill_defs = [
				["chain_lightning", "Chain Lightning", "Adds one chain target per level. Also increases damage.", 2.0, 0.0, 0.0, "chain_count+1"],
				["voltage_surge", "Voltage Surge", "Increases damage per level.", 4.0, 0.0, 0.0, ""],
				["conductor_range", "Conductor Range", "Increases range per level.", 0.0, 0.0, 12.0, ""],
				["static_field", "Static Field", "Expands splash area per level.", 0.0, 0.0, 0.0, "splash+10"],
				["tesla_mastery", "Tesla Mastery", "Increases both damage and range per level.", 6.0, 0.0, 10.0, ""],
			]
		Enums.TowerType.CRYO_ARRAY:
			skill_defs = [
				["deep_freeze", "Deep Freeze", "Increases slow power per level.", 0.0, 0.0, 0.0, "slow_power+0.05"],
				["frost_spread", "Frost Spread", "Increases range per level.", 0.0, 0.0, 12.0, ""],
				["cryo_burst", "Cryo Burst", "Increases fire rate per level.", 0.0, 0.06, 0.0, ""],
				["permafrost", "Permafrost", "Chance to fully freeze enemies at level 3 and above.", 0.0, 0.0, 0.0, "freeze_chance"],
				["absolute_zero", "Absolute Zero", "Increases both range and fire rate per level.", 0.0, 0.04, 15.0, ""],
			]
		Enums.TowerType.MISSILE_POD:
			skill_defs = [
				["warhead_yield", "Warhead Yield", "Increases damage per level.", 8.0, 0.0, 0.0, ""],
				["blast_radius", "Blast Radius", "Expands splash area per level.", 0.0, 0.0, 0.0, "splash+15"],
				["rapid_reload", "Rapid Reload", "Increases fire rate per level.", 0.0, 0.04, 0.0, ""],
				["cluster_munitions", "Cluster Munitions", "Fires multiple shots at level 3 and above.", 0.0, 0.0, 0.0, "multi_shot"],
				["devastation", "Devastation", "Increases damage and splash area per level.", 10.0, 0.0, 0.0, "splash+10"],
			]
		Enums.TowerType.BEAM_SPIRE:
			skill_defs = [
				["precision_optics", "Precision Optics", "Increases range per level.", 0.0, 0.0, 20.0, ""],
				["power_amplifier", "Power Amplifier", "Increases damage per level.", 5.0, 0.0, 0.0, ""],
				["quick_calibration", "Quick Calibration", "Increases fire rate per level.", 0.0, 0.03, 0.0, ""],
				["armor_penetration", "Armor Penetration", "Shots ignore armor at level 2 and above.", 0.0, 0.0, 0.0, "armor_pierce"],
				["death_ray", "Death Ray", "Increases both damage and range per level.", 8.0, 0.0, 15.0, ""],
			]
		Enums.TowerType.NANO_HIVE:
			skill_defs = [
				["swarm_density", "Swarm Density", "Increases fire rate per level.", 0.0, 0.06, 0.0, ""],
				["repair_nanites", "Repair Nanites", "Heals nearby towers at level 2 and above.", 0.0, 0.0, 0.0, "heal_nearby"],
				["signal_boost", "Signal Boost", "Increases range per level.", 0.0, 0.0, 15.0, ""],
				["buff_amplifier", "Buff Amplifier", "Increases buff power per level.", 0.0, 0.0, 0.0, "buff_power+0.1"],
				["hive_mind", "Hive Mind", "Increases both fire rate and range per level.", 0.0, 0.05, 12.0, ""],
			]
		Enums.TowerType.HARVESTER:
			skill_defs = [
				["efficient_mining", "Efficient Mining", "Increases gold bonus per level.", 0.0, 0.0, 0.0, "gold_bonus+5"],
				["processing_speed", "Processing Speed", "Increases fire rate per level.", 0.0, 0.05, 0.0, ""],
				["detection_range", "Detection Range", "Increases range per level.", 0.0, 0.0, 12.0, ""],
				["rare_materials", "Rare Materials", "Chance to find diamonds at level 3 and above.", 0.0, 0.0, 0.0, "diamond_chance"],
				["extraction_mastery", "Extraction Mastery", "Increases fire rate and gold bonus per level.", 0.0, 0.04, 0.0, "gold_bonus+8"],
			]
		_:
			# Fallback: balanced generic skills
			skill_defs = [
				["skill_0", "Power Up", "Increases damage per level.", 3.0, 0.0, 0.0, ""],
				["skill_1", "Quick Shot", "Increases fire rate per level.", 0.0, 0.04, 0.0, ""],
				["skill_2", "Far Sight", "Increases range per level.", 0.0, 0.0, 12.0, ""],
				["skill_3", "Special Training", "Unlocks a special ability.", 0.0, 0.0, 0.0, ""],
				["skill_4", "Mastery", "Increases all stats per level.", 3.0, 0.03, 10.0, ""],
			]

	for i in range(skill_defs.size()):
		var def: Array = skill_defs[i]
		var node := SkillNode.new()
		node.id = def[0] as String
		node.display_name = def[1] as String
		node.description = def[2] as String
		node.node_index = i
		node.cost = 0  # Cost is determined dynamically by level via SkillTree.get_node_cost()
		node.prerequisite_index = -1  # All 5 skills are independently upgradeable
		node.damage_bonus = def[3] as float
		node.fire_rate_bonus = def[4] as float
		node.range_bonus = def[5] as float
		node.special = def[6] as String
		node.max_level = 5
		node.is_hero_unlock = false
		tree.nodes.append(node)

	_skill_trees[tower_type] = tree
	return tree

## Returns the mutable unlocked levels dictionary for a tower type, initializing if needed.
## Returns Dictionary: { skill_index: current_level }
func _get_unlocked_nodes(tower_type: int) -> Dictionary:
	if not _unlocked_nodes.has(tower_type):
		_unlocked_nodes[tower_type] = {}
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

	# Load skill tree node levels (stored as dict: tower_type_str -> { skill_index_str: level })
	var saved_trees: Dictionary = prog.get("skill_trees", {})
	for key in saved_trees.keys():
		var tower_type_int: int = int(key)
		var saved_levels = saved_trees[key]
		if saved_levels is Dictionary:
			var levels: Dictionary = {}
			for skill_key in saved_levels.keys():
				levels[int(skill_key)] = saved_levels[skill_key] as int
			_unlocked_nodes[tower_type_int] = levels
		else:
			# Legacy save format (Array of unlocked indices) - migrate to level 1
			var levels: Dictionary = {}
			for idx in saved_levels:
				levels[idx as int] = 1
			_unlocked_nodes[tower_type_int] = levels

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

	# Save skill tree node levels
	var trees_dict: Dictionary = {}
	for tower_type in _unlocked_nodes.keys():
		var levels: Dictionary = _unlocked_nodes[tower_type] as Dictionary
		var save_levels: Dictionary = {}
		for skill_idx in levels.keys():
			save_levels[str(skill_idx)] = levels[skill_idx]
		trees_dict[str(tower_type)] = save_levels
	prog["skill_trees"] = trees_dict

	# Save hero unlocks
	prog["heroes_unlocked"] = _heroes_unlocked.duplicate()

	_save_manager.save_game()
