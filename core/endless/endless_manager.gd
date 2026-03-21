class_name EndlessManager
extends Node

## Manages an endless-mode run: wave generation, milestone rewards,
## and per-difficulty high-score tracking.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal milestone_reached(wave: int, diamonds: int)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Wave-number → diamond reward at that milestone.
const MILESTONES: Dictionary = {
	10:  50,
	25:  100,
	50:  200,
	75:  300,
	100: 500,
}

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _wave_generator: WaveGenerator = null
var _current_wave: int = 0
var _difficulty: int = Enums.Difficulty.NORMAL

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_wave_generator = WaveGenerator.new()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Begin a new endless run at the given difficulty.
## Resets the wave counter.
func start(difficulty: int) -> void:
	_difficulty = difficulty
	_current_wave = 0

## Generate and return the WaveDefinition for the next wave.
## Increments the internal wave counter.
func generate_next_wave() -> WaveDefinition:
	_current_wave += 1
	return _wave_generator.generate_wave(_current_wave, _difficulty)

## Returns true if the current wave is a milestone.
func is_milestone(wave: int) -> bool:
	return MILESTONES.has(wave)

## Returns the diamond reward for a milestone wave, or 0 if not a milestone.
func get_milestone_diamonds(wave: int) -> int:
	return MILESTONES.get(wave, 0) as int

## Records the current wave as the player's high score for the active difficulty.
## Emits milestone_reached if the current wave is a milestone.
func record_high_score(save_manager: SaveManager) -> void:
	if save_manager == null:
		push_warning("EndlessManager.record_high_score: no SaveManager provided")
		return

	var key: String = _difficulty_key(_difficulty)
	var high_scores: Dictionary = save_manager.data["endless"]["high_scores"]
	var previous: int = high_scores.get(key, 0) as int
	if _current_wave > previous:
		high_scores[key] = _current_wave
		save_manager.save_game()

	# Emit milestone signal if applicable
	if is_milestone(_current_wave):
		var diamonds: int = get_milestone_diamonds(_current_wave)
		milestone_reached.emit(_current_wave, diamonds)

## Returns the recorded high score for the given difficulty.
func get_high_score(difficulty: int, save_manager: SaveManager) -> int:
	if save_manager == null:
		return 0
	var key: String = _difficulty_key(difficulty)
	return save_manager.data["endless"]["high_scores"].get(key, 0) as int

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _difficulty_key(difficulty: int) -> String:
	match difficulty:
		Enums.Difficulty.HARD:
			return "hard"
		Enums.Difficulty.NIGHTMARE:
			return "nightmare"
		_:
			return "normal"
