class_name Constants

## Shared game-wide constants for Last Signal tower defense.
## All balance values and configuration constants live here.

# ---------------------------------------------------------------------------
# Difficulty Multipliers
# Dictionaries use var (not const) because enum keys require runtime resolution
# ---------------------------------------------------------------------------

## HP multiplier per difficulty
var DIFFICULTY_HP_MULT: Dictionary = {
	Enums.Difficulty.NORMAL: 1.0,
	Enums.Difficulty.HARD: 1.8,
	Enums.Difficulty.NIGHTMARE: 3.0
}

## Speed multiplier per difficulty
var DIFFICULTY_SPEED_MULT: Dictionary = {
	Enums.Difficulty.NORMAL: 1.0,
	Enums.Difficulty.HARD: 1.15,
	Enums.Difficulty.NIGHTMARE: 1.3
}

## Gold income modifier per difficulty (lower = less gold earned)
var DIFFICULTY_GOLD_MULT: Dictionary = {
	Enums.Difficulty.NORMAL: 1.0,
	Enums.Difficulty.HARD: 0.85,
	Enums.Difficulty.NIGHTMARE: 0.7
}

## Starting lives per difficulty
var DIFFICULTY_LIVES: Dictionary = {
	Enums.Difficulty.NORMAL: 20,
	Enums.Difficulty.HARD: 10,
	Enums.Difficulty.NIGHTMARE: 5
}

## Adaptation threshold per difficulty (fraction of wave that must be same type
## before resistance starts increasing)
var DIFFICULTY_ADAPTATION_THRESHOLD: Dictionary = {
	Enums.Difficulty.NORMAL: 0.4,
	Enums.Difficulty.HARD: 0.4,
	Enums.Difficulty.NIGHTMARE: 0.25
}

## Diamond reward multiplier per difficulty
var DIFFICULTY_DIAMOND_MULT: Dictionary = {
	Enums.Difficulty.NORMAL: 1.0,
	Enums.Difficulty.HARD: 1.5,
	Enums.Difficulty.NIGHTMARE: 2.5
}

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------

## Fraction of tower cost returned on sell (base, before upgrades)
const BASE_SELL_REFUND: float = 0.7

## Additional refund fraction per upgrade tier applied to the tower
const SELL_REFUND_PER_UPGRADE_TIER: float = 0.02

## Gold bonus for sending the next wave early
const EARLY_SEND_GOLD_BONUS: int = 50

## Gold bonus awarded when a wave is cleared
const WAVE_CLEAR_BONUS: int = 25

# ---------------------------------------------------------------------------
# Adaptation System
# ---------------------------------------------------------------------------

## How often (in seconds) the adaptation system checks and adjusts resistances
const ADAPTATION_CHECK_INTERVAL: int = 3

## Maximum resistance a tower type can accumulate (normal/hard)
const ADAPTATION_MAX_RESISTANCE: float = 0.6

## Maximum resistance in endless mode
const ADAPTATION_MAX_RESISTANCE_ENDLESS: float = 0.75

## Threshold (fraction of total enemies) at which a composition triggers adaptation
const ADAPTATION_ENDLESS_THRESHOLD: float = 0.3

## How much resistance increases per adaptation tick
const ADAPTATION_RESISTANCE_INCREMENT: float = 0.1

## How much resistance decays per adaptation tick when not triggered
const ADAPTATION_DECAY_RATE: float = 0.05

# ---------------------------------------------------------------------------
# Star Rating
# ---------------------------------------------------------------------------

## Fraction of starting lives that can be lost and still earn 2 stars
var STAR_2_MAX_LIVES_LOST_FRACTION: float = 0.25

## Fraction of starting lives that can be lost and still earn 3 stars (0 = perfect only)
var STAR_3_MAX_LIVES_LOST_FRACTION: float = 0.0

# ---------------------------------------------------------------------------
# Wave & Speed
# ---------------------------------------------------------------------------

## Default interval between enemy spawns in seconds
const DEFAULT_SPAWN_INTERVAL := 0.5

## Duration of the break between waves in seconds
const WAVE_BREAK_DURATION: float = 6.0

## Available game speed multiplier options
const SPEED_OPTIONS: Array = [1.0, 2.0, 3.0]

# ---------------------------------------------------------------------------
# Upgrade Costs
# ---------------------------------------------------------------------------

## Gold costs for each global upgrade tier (10 tiers)
const GLOBAL_UPGRADE_COSTS: Array = [50, 75, 110, 160, 230, 330, 470, 680, 980, 1400]

## Diamond costs for each skill node tier (10 tiers)
const SKILL_NODE_COSTS: Array = [80, 120, 180, 260, 380, 540, 760, 920, 1080, 1200]

# ---------------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------------

## Diamond cost to unlock an ability
const ABILITY_UNLOCK_COST: int = 200

## Diamond costs to upgrade an ability through 5 tiers
const ABILITY_UPGRADE_COSTS: Array = [100, 200, 300, 450, 600]

# ---------------------------------------------------------------------------
# Monetization
# ---------------------------------------------------------------------------

## Maximum ad views rewarded per day
const MAX_ADS_PER_DAY: int = 5

## Diamonds earned per ad view
const DIAMONDS_PER_AD: int = 10

# ---------------------------------------------------------------------------
# Hero Abilities
# ---------------------------------------------------------------------------

## Base cooldown for hero abilities in seconds
const HERO_BASE_COOLDOWN: float = 150.0

## Duration bonus added per upgrade tier for hero abilities
const HERO_DURATION_PER_UPGRADE_TIER: float = 1.0

# ---------------------------------------------------------------------------
# Mobile / Touch
# ---------------------------------------------------------------------------

## Minimum touch target size in pixels
const MIN_TOUCH_TARGET: float = 56.0

## Tower selection radius for touch input
const TOUCH_SELECT_RADIUS: float = 56.0

## Long press duration in seconds for showing info
const LONG_PRESS_DURATION: float = 0.5

# ---------------------------------------------------------------------------
# Enemy Abilities
# ---------------------------------------------------------------------------

## Healer: heal pulse cooldown in seconds
const HEALER_PULSE_COOLDOWN: float = 4.0
## Healer: pulse range in pixels
const HEALER_PULSE_RANGE: float = 80.0
## Healer: fraction of ally max HP healed per pulse
const HEALER_PULSE_FRACTION: float = 0.15

## Shielder: shield aura cooldown in seconds
const SHIELDER_AURA_COOLDOWN: float = 5.0
## Shielder: aura range in pixels
const SHIELDER_AURA_RANGE: float = 60.0
## Shielder: shield points granted per pulse
const SHIELDER_AURA_AMOUNT: float = 30.0
## Shielder: maximum shield an ally can have from auras
const SHIELDER_AURA_MAX: float = 100.0

## Scout: scatter signal range in pixels on death
const SCOUT_SCATTER_RANGE: float = 100.0
## Scout: speed multiplier applied to nearby allies on death
const SCOUT_SCATTER_SPEED_MULT: float = 1.2
## Scout: duration of scatter speed buff in seconds
const SCOUT_SCATTER_DURATION: float = 3.0

## Drone Swarm: minimum alive drones to trigger Overwhelm
const DRONE_OVERWHELM_THRESHOLD: int = 5
## Drone Swarm: speed multiplier when Overwhelm is active
const DRONE_OVERWHELM_SPEED_MULT: float = 1.1

## Tank: damage reduction fraction for the first tower type that hits
const TANK_FORTIFIED_REDUCTION: float = 0.25

# ---------------------------------------------------------------------------
# Tower Synergies
# ---------------------------------------------------------------------------

const SYNERGY_RANGE: float = 100.0
const SYNERGY_BARRAGE_FIRE_RATE_MULT: float = 1.15
const SYNERGY_EFFICIENCY_INCOME_MULT: float = 1.30
const SYNERGY_SHATTER_CHAIN_DAMAGE_MULT: float = 2.0
const SYNERGY_FROSTBITE_SPLASH_DAMAGE_MULT: float = 1.25
const SYNERGY_COLD_SNAP_SLOW_EXTEND: float = 0.5
const SYNERGY_FOCUS_FIRE_DAMAGE_MULT: float = 1.20
const SYNERGY_FOCUS_FIRE_DURATION: float = 2.0

# ---------------------------------------------------------------------------
# Elite Enemy Modifiers (Endless Mode)
# ---------------------------------------------------------------------------

const ELITE_START_WAVE: int = 15
const ELITE_REGEN_PULSE_INTERVAL: float = 2.0
const ELITE_REGEN_HP_FRACTION: float = 0.02
const ELITE_SPLIT_COUNT: int = 2
const ELITE_SPLIT_HP_FRACTION: float = 0.30
const ELITE_SPLIT_SPEED_MULT: float = 0.80
const ELITE_PHASE_INTERVAL: float = 3.0
const ELITE_PHASE_DURATION: float = 0.5
const ELITE_MAGNETIC_RANGE: float = 60.0
const ELITE_MAGNETIC_SPEED_MULT: float = 1.15
const ELITE_REFLECTIVE_PAUSE: float = 0.3
const ELITE_ENRAGED_INTERVAL: float = 3.0
const ELITE_ENRAGED_SPEED_INCREMENT: float = 0.05
const ELITE_ENRAGED_SPEED_CAP: float = 0.50
const ELITE_DOUBLE_MODIFIER_WAVE: int = 50
const ELITE_HP_SCALE: float = 1.5

# ---------------------------------------------------------------------------
# Roguelite Wave Rewards (Endless Mode)
# ---------------------------------------------------------------------------

const WAVE_REWARD_INTERVAL: int = 5
const WAVE_REWARD_CHOICE_COUNT: int = 3
const WAVE_REWARD_TIMER: float = 8.0

# ---------------------------------------------------------------------------
# Tower Mastery
# ---------------------------------------------------------------------------

const MASTERY_TIERS: Array = [
	{"name": "Bronze",  "kills": 500,    "damage_bonus": 0.00, "cost_discount": 0.00},
	{"name": "Silver",  "kills": 2000,   "damage_bonus": 0.03, "cost_discount": 0.00},
	{"name": "Gold",    "kills": 8000,   "damage_bonus": 0.03, "cost_discount": 0.00},
	{"name": "Diamond", "kills": 25000,  "damage_bonus": 0.03, "cost_discount": 0.00},
	{"name": "Master",  "kills": 100000, "damage_bonus": 0.03, "cost_discount": 0.05},
]

# ---------------------------------------------------------------------------
# Signal Decode Minigame
# ---------------------------------------------------------------------------

const SIGNAL_DECODE_GLYPHS: Array = ["◆", "◇", "○", "△", "□", "☆"]
const SIGNAL_DECODE_DISPLAY_TIME: float = 2.0
const SIGNAL_DECODE_INPUT_TIME: float = 4.0
const SIGNAL_DECODE_REWARD_GOLD: int = 20
const SIGNAL_DECODE_REWARD_DAMAGE_MULT: float = 0.05
const SIGNAL_DECODE_REWARD_COOLDOWN_SECS: float = 3.0
