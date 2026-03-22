extends Node

## Singleton that manages the global game state, difficulty, lives, and level flow.
## Registered as an autoload in project.godot.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal state_changed(new_state: int, old_state: int)
signal lives_changed(new_lives: int, lives_lost: int)
signal difficulty_changed(new_difficulty: int)
signal game_speed_changed(new_speed: float)
signal level_started(level_id: String, difficulty: int)
signal level_completed(level_id: String, stars: int)
signal level_failed(level_id: String)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var current_state: int = Enums.GameState.MENU
var current_difficulty: int = Enums.Difficulty.NORMAL
var current_level_id: String = ""
var lives: int = 20
var lives_lost: int = 0
var game_speed: float = 1.0

## Tracks the state before pausing so we can restore it on unpause
var _state_before_pause: int = Enums.GameState.MENU

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------------------------------------------------------------------------
# State Management
# ---------------------------------------------------------------------------

## Transitions the game to a new state, emitting state_changed signal.
func change_state(new_state: int) -> void:
	var old_state: int = current_state
	if old_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state, old_state)

# ---------------------------------------------------------------------------
# Difficulty
# ---------------------------------------------------------------------------

## Sets the difficulty and emits difficulty_changed.
func set_difficulty(difficulty: int) -> void:
	current_difficulty = difficulty
	difficulty_changed.emit(difficulty)

# ---------------------------------------------------------------------------
# Level Flow
# ---------------------------------------------------------------------------

## Starts a level with the given ID and difficulty.
## Resets lives based on difficulty constants, transitions to BUILDING state.
func start_level(level_id: String, difficulty: int) -> void:
	current_level_id = level_id
	set_difficulty(difficulty)

	var constants := Constants.new()
	lives = constants.DIFFICULTY_LIVES.get(difficulty, 20)

	lives_lost = 0
	lives_changed.emit(lives, lives_lost)
	change_state(Enums.GameState.BUILDING)
	level_started.emit(level_id, difficulty)

## Called when the last wave is cleared successfully.
## Calculates stars, transitions to VICTORY, emits level_completed.
func complete_level() -> void:
	var stars := calculate_stars()
	change_state(Enums.GameState.VICTORY)
	level_completed.emit(current_level_id, stars)

## Called when lives reach zero.
func _trigger_defeat() -> void:
	change_state(Enums.GameState.DEFEAT)
	level_failed.emit(current_level_id)

# ---------------------------------------------------------------------------
# Lives
# ---------------------------------------------------------------------------

## Decrements lives by 1. Triggers defeat if lives reach 0.
func lose_life() -> void:
	if current_state == Enums.GameState.DEFEAT:
		return
	lives = max(0, lives - 1)
	lives_lost += 1
	lives_changed.emit(lives, lives_lost)
	if lives <= 0:
		_trigger_defeat()

# ---------------------------------------------------------------------------
# Star Rating
# ---------------------------------------------------------------------------

## Returns 1, 2, or 3 stars based on lives lost during the level.
## Thresholds scale with starting lives so that harder difficulties (fewer lives)
## use proportional limits instead of fixed numbers.
func calculate_stars() -> int:
	var constants := Constants.new()
	var starting_lives: int = constants.DIFFICULTY_LIVES.get(current_difficulty, 20)
	var max_lost_for_3: int = int(float(starting_lives) * constants.STAR_3_MAX_LIVES_LOST_FRACTION)
	var max_lost_for_2: int = maxi(int(float(starting_lives) * constants.STAR_2_MAX_LIVES_LOST_FRACTION), 1)
	if lives_lost <= max_lost_for_3:
		return 3
	elif lives_lost <= max_lost_for_2:
		return 2
	return 1

# ---------------------------------------------------------------------------
# Game Speed
# ---------------------------------------------------------------------------

## Sets the game speed and updates Engine.time_scale. Emits game_speed_changed.
func set_game_speed(speed: float) -> void:
	if speed not in Constants.SPEED_OPTIONS:
		push_warning("GameManager.set_game_speed: invalid speed %f, ignoring" % speed)
		return
	game_speed = speed
	Engine.time_scale = speed
	game_speed_changed.emit(speed)

# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

## Toggles pause. Saves/restores pre-pause state.
func toggle_pause() -> void:
	if current_state == Enums.GameState.PAUSED:
		get_tree().paused = false
		change_state(_state_before_pause)
	else:
		_state_before_pause = current_state
		change_state(Enums.GameState.PAUSED)
		get_tree().paused = true
