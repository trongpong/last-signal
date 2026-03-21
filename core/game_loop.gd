class_name GameLoop
extends Node

## Orchestrates the wave system, adaptation, economy, and game-state transitions
## for a single level run.  Connect this to the scene tree alongside WaveManager
## and AdaptationManager instances.
##
## Typical lifecycle:
##   setup(game_manager, economy_manager, wave_manager, adaptation_manager)
##   start_level(level_id, difficulty, waves_array)
##   # Player builds towers …
##   send_wave()          ← can repeat, or called automatically on break timeout

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the player wins the level.
signal level_victory(level_id: String, stars: int, diamonds: int)

## Emitted when the player loses the level.
signal level_defeat(level_id: String)

# ---------------------------------------------------------------------------
# Private references
# ---------------------------------------------------------------------------

var _gm = null
var _em = null
var _wm: WaveManager = null
var _am: AdaptationManager = null

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _level_id: String = ""
var _difficulty: int = Enums.Difficulty.NORMAL
var _waves_since_adaptation_check: int = 0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Wires the four manager references and connects WaveManager signals.
## Call once before start_level.
func setup(
	gm,
	em,
	wm: WaveManager,
	am: AdaptationManager
) -> void:
	_gm = gm
	_em = em
	_wm = wm
	_am = am

	_wm.wave_complete.connect(_on_wave_complete)
	_wm.all_waves_complete.connect(_on_all_waves_complete)


## Initialises all managers and transitions to BUILDING state.
func start_level(level_id: String, difficulty: int, waves: Array) -> void:
	_level_id = level_id
	_difficulty = difficulty
	_waves_since_adaptation_check = 0

	var constants := Constants.new()
	var gold_mult: float = constants.DIFFICULTY_GOLD_MULT.get(difficulty, 1.0)
	constants.free()

	_em.reset_match_economy()
	_em.set_gold_modifier(gold_mult)

	_am.setup(difficulty, false)

	_wm.load_waves(waves)
	_gm.start_level(level_id, difficulty)


## Optionally grants early-send bonus then launches the next wave.
## Changes game state to WAVE_ACTIVE.
func send_wave() -> void:
	if not _wm.has_more_waves():
		return
	if _wm.is_wave_active:
		return

	var bonus: int = _wm.get_early_send_bonus()
	if bonus > 0:
		_em.add_gold(bonus)

	_am.start_new_wave_window()
	_wm.start_next_wave()
	_gm.change_state(Enums.GameState.WAVE_ACTIVE)


## Called by enemy death handlers. Adds gold and records damage for adaptation.
## gold_value: the gold this enemy was worth.
func on_enemy_killed(gold_value: int) -> void:
	_em.add_gold(gold_value)
	_wm.on_enemy_died()


## Called when an enemy exits the map. Loses a life.
func on_enemy_reached_exit() -> void:
	_gm.lose_life()
	_wm.on_enemy_reached_exit()


## Called when a tower deals damage — forwards to AdaptationManager.
func on_damage_dealt(damage_type: int, amount: float) -> void:
	_am.record_damage(damage_type, amount)

# ---------------------------------------------------------------------------
# Private signal handlers
# ---------------------------------------------------------------------------

func _on_wave_complete(wave_number: int) -> void:
	_waves_since_adaptation_check += 1
	if _waves_since_adaptation_check >= Constants.ADAPTATION_CHECK_INTERVAL:
		_am.check_adaptation()
		_waves_since_adaptation_check = 0

	_gm.change_state(Enums.GameState.WAVE_COMPLETE)


func _on_all_waves_complete() -> void:
	var stars: int = _gm.calculate_stars()
	var constants := Constants.new()
	var diamond_mult: float = constants.DIFFICULTY_DIAMOND_MULT.get(_difficulty, 1.0)
	constants.free()

	var base_diamonds: int = 50 + stars * 25
	var diamonds: int = int(float(base_diamonds) * diamond_mult)
	_em.add_diamonds(diamonds)

	_gm.complete_level()
	level_victory.emit(_level_id, stars, diamonds)
