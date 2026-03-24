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

