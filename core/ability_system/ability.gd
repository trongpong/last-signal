class_name Ability
extends Node

## Runtime instance of a single ability slot.
## Tracks cooldown, emits signals when activated or ready.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal activated(ability_id: String, target: Variant)
signal cooldown_complete(ability_id: String)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _ability_id: String = ""
var _base_cooldown: float = 60.0
var _cooldown_remaining: float = 0.0
var _was_on_cooldown: bool = false

## Fractional reduction applied to the base cooldown on activation (0.0–1.0).
var cooldown_reduction: float = 0.0

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Sets the ability id and base cooldown. Call before use.
func initialize(id: String, cooldown: float) -> void:
	_ability_id = id
	_base_cooldown = cooldown
	_cooldown_remaining = 0.0
	_was_on_cooldown = false

# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

## Returns true if the ability is off cooldown and ready to use.
func is_ready() -> bool:
	return _cooldown_remaining <= 0.0

## Returns a 0.0–1.0 value representing cooldown progress (1.0 = fully charged).
func get_cooldown_progress() -> float:
	if _base_cooldown <= 0.0:
		return 1.0
	var effective_cd: float = _base_cooldown * (1.0 - clampf(cooldown_reduction, 0.0, 1.0))
	if effective_cd <= 0.0:
		return 1.0
	return clampf(1.0 - (_cooldown_remaining / effective_cd), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

## Activates the ability if ready. Applies cooldown_reduction to cooldown.
## Emits activated signal. Returns true on success, false if still on cooldown.
func activate(target: Variant = null) -> bool:
	if not is_ready():
		return false
	var effective_cd: float = _base_cooldown * (1.0 - clampf(cooldown_reduction, 0.0, 1.0))
	_cooldown_remaining = maxf(effective_cd, 0.0)
	_was_on_cooldown = _cooldown_remaining > 0.0
	activated.emit(_ability_id, target)
	return true

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			if _was_on_cooldown:
				_was_on_cooldown = false
				cooldown_complete.emit(_ability_id)
