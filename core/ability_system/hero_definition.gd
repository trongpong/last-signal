class_name HeroDefinition
extends Resource

## Static data resource describing a hero unit that can be summoned in battle.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

@export var id: String = ""
@export var display_name: String = ""

## The tower type this hero is associated with.
@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON

# ---------------------------------------------------------------------------
# Summon Parameters
# ---------------------------------------------------------------------------

@export var base_duration: float = 20.0

# ---------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------

## Number of sides for the polygon used to render this hero.
@export var shape_sides: int = 8

## Radius of the hero's rendered polygon in pixels.
@export var shape_radius: float = 24.0

@export var color: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Combat Stats
# ---------------------------------------------------------------------------

@export var damage: float = 50.0
@export var attack_speed: float = 1.0
@export var movement_speed: float = 80.0

# ---------------------------------------------------------------------------
# Special Ability
# ---------------------------------------------------------------------------

## String key for any special passive or active effect (e.g. "chain_lightning").
@export var special_ability: String = ""
