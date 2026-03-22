class_name UpgradeManager
extends Node

## Handles the purchase and application of tower upgrades.
## Checks the player's gold, deducts cost, then calls tower.apply_upgrade().

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after a successful upgrade.
signal tower_upgraded(tower: Tower, new_tier: int)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Attempt to purchase the next upgrade for tower via the given branch choice.
## economy must be an EconomyManager (or compatible object with spend_gold()).
## Returns true if the upgrade was purchased successfully, false otherwise.
func try_upgrade(tower: Tower, choice: int, economy) -> bool:
	if tower == null or economy == null:
		return false

	var tier_tree: TierTree = tower.get_tier_tree()
	if tier_tree == null:
		return false

	var current_path: Array = tower.get_upgrade_path()
	var cost: int = tier_tree.get_next_upgrade_cost(current_path, choice)

	# No valid upgrade at this choice
	if tier_tree.get_upgrade_options(current_path).size() == 0:
		return false

	if cost > 0:
		if not economy.spend_gold(cost):
			return false

	tower.apply_upgrade(choice)
	tower_upgraded.emit(tower, tower.current_tier)
	return true
