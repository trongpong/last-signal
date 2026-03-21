class_name TowerDefinition
extends Resource

## Data resource defining the stats and appearance of a tower type.
## Create .tres instances in content/towers/ for each tower variant.
## tier_branches defines the upgrade tree: each branch is a dictionary with
## name, display_name, damage_mult, fire_rate_mult, range_mult, cost, special,
## and nested branches for further tiers.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

@export var id: String = ""
@export var display_name: String = ""
@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var damage_type: Enums.DamageType = Enums.DamageType.PULSE

# ---------------------------------------------------------------------------
# Base Combat Stats
# ---------------------------------------------------------------------------

@export var base_damage: float = 25.0
@export var base_fire_rate: float = 1.0
@export var base_range: float = 200.0

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------

@export var cost: int = 100

# ---------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------

@export var shape_sides: int = 8
@export var shape_radius: float = 16.0
@export var color: Color = Color.CYAN

# ---------------------------------------------------------------------------
# Targeting
# ---------------------------------------------------------------------------

## Targeting modes available to this tower type
@export var targeting_modes: Array[int] = []

# ---------------------------------------------------------------------------
# Role Flags
# ---------------------------------------------------------------------------

@export var is_support: bool = false
@export var is_income: bool = false

# ---------------------------------------------------------------------------
# Projectile
# ---------------------------------------------------------------------------

@export var projectile_speed: float = 400.0

# ---------------------------------------------------------------------------
# Special Effects
# ---------------------------------------------------------------------------

## Radius of splash damage on impact (0 = single target)
@export var splash_radius: float = 0.0

## Movement speed multiplier applied on hit (1.0 = no slow, 0.5 = half speed)
@export var slow_factor: float = 1.0

## Duration in seconds of the slow effect
@export var slow_duration: float = 0.0

## Number of chain-lightning targets (0 = no chain)
@export var chain_count: int = 0

## Maximum range for each chain hop
@export var chain_range: float = 0.0

# ---------------------------------------------------------------------------
# Support Effects (Nano Hive)
# ---------------------------------------------------------------------------

## Radius within which this tower buffs allied towers
@export var buff_range: float = 0.0

## Damage multiplier applied to buffed towers (1.0 = no buff)
@export var buff_damage_mult: float = 1.0

## Fire rate multiplier applied to buffed towers (1.0 = no buff)
@export var buff_fire_rate_mult: float = 1.0

# ---------------------------------------------------------------------------
# Income (Harvester)
# ---------------------------------------------------------------------------

## Gold earned per wave by this tower
@export var income_per_wave: int = 0

# ---------------------------------------------------------------------------
# Skill Tree Reference
# ---------------------------------------------------------------------------

@export var skill_tree_id: String = ""

# ---------------------------------------------------------------------------
# Upgrade Tier Branches
# ---------------------------------------------------------------------------

## Tier upgrade branches. Each element is a Dictionary:
## {
##   "name": String,           -- internal branch identifier
##   "display_name": String,   -- human-readable label
##   "damage_mult": float,     -- cumulative damage multiplier
##   "fire_rate_mult": float,  -- cumulative fire rate multiplier
##   "range_mult": float,      -- cumulative range multiplier
##   "cost": int,              -- gold cost to take this branch
##   "special": String,        -- optional special effect key
##   "branches": Array         -- nested sub-branches (same structure)
## }
@export var tier_branches: Array[Dictionary] = []
