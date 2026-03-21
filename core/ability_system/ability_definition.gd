class_name AbilityDefinition
extends Resource

## Static data resource describing a single activatable ability.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Enum value from Enums.AbilityType.
@export var ability_type: Enums.AbilityType = Enums.AbilityType.ORBITAL_STRIKE

# ---------------------------------------------------------------------------
# Timing
# ---------------------------------------------------------------------------

@export var base_cooldown: float = 60.0
@export var base_duration: float = 5.0

# ---------------------------------------------------------------------------
# Effect
# ---------------------------------------------------------------------------

@export var base_value: float = 100.0

## If true, the ability targets a world-space position.
@export var targets_position: bool = false

## If true, the ability targets a specific tower node.
@export var targets_tower: bool = false
