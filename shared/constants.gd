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
	Enums.Difficulty.HARD: 0.35,
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
const SKILL_NODE_COSTS: Array = [80, 100, 120, 200, 250, 350, 450, 600, 750, 1200]

# ---------------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------------

## Diamond cost to unlock an ability
const ABILITY_UNLOCK_COST: int = 200

## Diamond costs to upgrade an ability through 5 tiers
const ABILITY_UPGRADE_COSTS: Array = [100, 150, 250, 400, 600]

# ---------------------------------------------------------------------------
# Monetization
# ---------------------------------------------------------------------------

## Maximum ad views rewarded per day
const MAX_ADS_PER_DAY: int = 10

## Diamonds earned per ad view
const DIAMONDS_PER_AD: int = 100

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
