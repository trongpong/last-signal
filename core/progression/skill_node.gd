class_name SkillNode
extends Resource

## A single node in a tower's skill tree.
## Represents one unlockable upgrade purchased with diamonds.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Sequential index in the skill tree's nodes array.
@export var node_index: int = 0

## Diamond cost to unlock this node.
@export var cost: int = 80

## Index of the prerequisite node (-1 means no prerequisite).
@export var prerequisite_index: int = -1

## If true, unlocking this node also unlocks the hero for this tower type.
@export var is_hero_unlock: bool = false

# ---------------------------------------------------------------------------
# Stat Bonuses
# ---------------------------------------------------------------------------

## Flat damage bonus granted when this node is unlocked.
@export var damage_bonus: float = 0.0

## Flat fire rate bonus granted when this node is unlocked.
@export var fire_rate_bonus: float = 0.0

## Flat range bonus granted when this node is unlocked.
@export var range_bonus: float = 0.0

## String key for a special effect (e.g. "pierce", "chain", "slow").
@export var special: String = ""
