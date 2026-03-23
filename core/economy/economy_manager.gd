extends Node

## Singleton managing gold (match currency) and diamonds (premium currency).
## Registered as an autoload in project.godot.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal gold_changed(new_gold: int, delta: int)
signal diamonds_changed(new_diamonds: int, delta: int)

# ---------------------------------------------------------------------------
# Gold
# ---------------------------------------------------------------------------

var gold: int = 0

## Multiplier applied to all gold gains. Set per difficulty at match start.
var _gold_modifier: float = 1.0

# ---------------------------------------------------------------------------
# Diamonds
# ---------------------------------------------------------------------------

var diamonds: int = 0

## When true, all diamond gains are doubled (purchased upgrade)
var diamond_doubler: bool = false

## Cumulative diamonds ever earned; never decremented by spending
var total_diamonds_earned: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# Gold API
# ---------------------------------------------------------------------------

## Adds gold, applying _gold_modifier. Emits gold_changed.
func add_gold(amount: int) -> void:
	var actual: int = int(float(amount) * _gold_modifier)
	gold += actual
	gold_changed.emit(gold, actual)

## Attempts to spend gold. Returns true on success, false if insufficient.
func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	gold_changed.emit(gold, -amount)
	return true

## Returns true if current gold >= amount.
func can_afford(amount: int) -> bool:
	return gold >= amount

## Returns the current gold income modifier.
func get_gold_modifier() -> float:
	return _gold_modifier

## Sets the gold income modifier (e.g. 0.85 for hard difficulty).
func set_gold_modifier(modifier: float) -> void:
	_gold_modifier = modifier

# ---------------------------------------------------------------------------
# Diamond API
# ---------------------------------------------------------------------------

## Adds diamonds. If diamond_doubler is active, doubles the amount.
## Tracks total_diamonds_earned. Emits diamonds_changed.
func add_diamonds(amount: int) -> void:
	var actual: int = amount * 2 if diamond_doubler else amount
	diamonds += actual
	total_diamonds_earned += actual
	diamonds_changed.emit(diamonds, actual)

## Attempts to spend diamonds. Returns true on success, false if insufficient.
func spend_diamonds(amount: int) -> bool:
	if not can_afford_diamonds(amount):
		return false
	diamonds -= amount
	diamonds_changed.emit(diamonds, -amount)
	return true

## Returns true if current diamonds >= amount.
func can_afford_diamonds(amount: int) -> bool:
	return diamonds >= amount

# ---------------------------------------------------------------------------
# Match Lifecycle
# ---------------------------------------------------------------------------

## Resets gold and modifier for a new match. Preserves diamonds and total earned.
func reset_match_economy() -> void:
	var old_gold := gold
	gold = 0
	_gold_modifier = 1.0
	if old_gold != 0:
		gold_changed.emit(gold, -old_gold)
