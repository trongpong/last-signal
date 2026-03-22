class_name AdaptationManager
extends Node

## Tracks damage dealt by each tower type during a wave window and adjusts
## enemy resistances so that enemies gradually resist over-used damage types.
##
## Usage:
##   1. Call setup(difficulty, is_endless) at level start.
##   2. Call record_damage(damage_type, amount) from tower hit handlers.
##   3. Call check_adaptation() at the end of each adaptation interval (e.g. per-wave).
##   4. Call start_new_wave_window() at wave start to clear the damage log.
##   5. Query get_resistances() to apply to enemies.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever resistances are recalculated.
signal adaptation_changed(resistances: Dictionary)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Current resistance per DamageType key (int → float 0.0–max_resistance).
var _resistances: Dictionary = {}

## Accumulated damage per DamageType this wave window (int → float).
var _damage_log: Dictionary = {}

## The threshold fraction above which a type triggers adaptation.
var _threshold: float = 0.4

## The maximum resistance any type can reach.
var _max_resistance: float = Constants.ADAPTATION_MAX_RESISTANCE

## Decay rate multiplier (increased by Signal Leech wave reward).
var _decay_multiplier: float = 1.0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Configures the manager for the current run.
## Must be called before using the manager.
func setup(difficulty: int, is_endless: bool) -> void:
	var constants := Constants.new()
	_threshold = constants.DIFFICULTY_ADAPTATION_THRESHOLD.get(
		difficulty, Constants.ADAPTATION_ENDLESS_THRESHOLD
	)

	_max_resistance = (
		Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS
		if is_endless
		else Constants.ADAPTATION_MAX_RESISTANCE
	)

	_resistances.clear()
	_damage_log.clear()


## Records damage dealt by a specific damage type this window.
func record_damage(damage_type: int, amount: float) -> void:
	var current: float = _damage_log.get(damage_type, 0.0)
	_damage_log[damage_type] = current + amount


## Analyses the damage log and updates resistances:
##   - Types whose share exceeds _threshold gain ADAPTATION_RESISTANCE_INCREMENT (capped at max).
##   - All other tracked types decay by ADAPTATION_DECAY_RATE (floored at 0).
## Emits adaptation_changed with a copy of the current resistances.
func check_adaptation() -> void:
	var total_damage: float = 0.0
	for dmg in _damage_log.values():
		total_damage += dmg

	if total_damage <= 0.0:
		adaptation_changed.emit(get_resistances())
		return

	# Determine dominant types
	for dtype in _damage_log:
		var share: float = _damage_log[dtype] / total_damage
		var current_res: float = _resistances.get(dtype, 0.0)
		if share > _threshold:
			# Increase resistance, cap at max
			_resistances[dtype] = minf(
				current_res + Constants.ADAPTATION_RESISTANCE_INCREMENT,
				_max_resistance
			)
		else:
			# Decay resistance, floor at 0
			_resistances[dtype] = maxf(
				current_res - Constants.ADAPTATION_DECAY_RATE * _decay_multiplier,
				0.0
			)
			# Remove the entry entirely if it decayed to zero to keep dict clean
			if _resistances[dtype] == 0.0:
				_resistances.erase(dtype)

	adaptation_changed.emit(get_resistances())


## Clears the damage log for the next wave window.
## Does NOT reset accumulated resistances.
func start_new_wave_window() -> void:
	_damage_log.clear()


## Returns a copy of the current resistance dict (DamageType int → float).
func get_resistances() -> Dictionary:
	return _resistances.duplicate()


## Increases the adaptation threshold, making it harder for resistance to trigger.
## bonus: percentage points to add to the threshold (e.g. 0.04 = +4%).
func apply_threshold_bonus(bonus: float) -> void:
	_threshold = minf(_threshold + bonus, 0.95)

## Sets the decay rate multiplier (e.g. 2.0 = resistance decays twice as fast).
func set_decay_multiplier(mult: float) -> void:
	_decay_multiplier = maxf(mult, 1.0)

## Fully resets resistances and damage log (e.g. for a new level).
func reset() -> void:
	_resistances.clear()
	_damage_log.clear()
