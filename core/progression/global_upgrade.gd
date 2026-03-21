class_name GlobalUpgrade
extends Resource

## Represents a single persistent global upgrade purchased with diamonds.
## Upgrades have up to 10 tiers and grant a flat bonus per tier.

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Bonus value added per tier (e.g. 25 for starting gold means +25 gold per tier).
@export var value_per_tier: float = 1.0

## Maximum number of tiers for this upgrade (default 10).
@export var max_tier: int = 10

# ---------------------------------------------------------------------------
# Cost API
# ---------------------------------------------------------------------------

## Returns the diamond cost to upgrade from (tier) to (tier + 1).
## tier is 0-indexed: cost to buy tier 1 = GLOBAL_UPGRADE_COSTS[0].
## Returns 0 if tier >= max_tier or out of range.
func get_cost_for_tier(tier: int) -> int:
	if tier < 0 or tier >= max_tier:
		return 0
	if tier >= Constants.GLOBAL_UPGRADE_COSTS.size():
		return 0
	return Constants.GLOBAL_UPGRADE_COSTS[tier] as int

# ---------------------------------------------------------------------------
# Value API
# ---------------------------------------------------------------------------

## Returns the cumulative value at the given tier.
func get_value_at_tier(tier: int) -> float:
	return value_per_tier * float(tier)

# ---------------------------------------------------------------------------
# Tier State
# ---------------------------------------------------------------------------

## Returns true if current_tier has reached max_tier.
func is_maxed(current_tier: int) -> bool:
	return current_tier >= max_tier

## Returns the total diamond cost to upgrade from tier 0 to max_tier.
func get_total_cost_to_max() -> int:
	var total: int = 0
	for t in range(max_tier):
		total += get_cost_for_tier(t)
	return total
