class_name EnemyDefinition
extends Resource

## Data resource defining the stats and appearance of an enemy type.
## Create .tres instances in content/enemies/ for each enemy variant.

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: Enums.EnemyArchetype = Enums.EnemyArchetype.DRONE
@export var base_hp: float = 100.0
@export var speed: float = 150.0
@export var armor: float = 0.0
@export var shield: float = 0.0
@export var gold_value: int = 10
@export var diamond_chance: float = 0.0
@export var shape_sides: int = 4
@export var shape_radius: float = 12.0
@export var color: Color = Color.WHITE
@export var size_scale: float = 1.0
## Keys are Enums.DamageType (int), values are resistance fraction 0.0–1.0
@export var resistance_map: Dictionary = {}
@export var abilities: Array[String] = []
@export var is_boss: bool = false
@export var is_flying: bool = false
