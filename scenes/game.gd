extends Node2D

## Root script for the main game scene.
## Coordinates the GameManager and EconomyManager singletons
## to start a level and drive the core game loop.

# ---------------------------------------------------------------------------
# Child node references (set up in game.tscn)
# ---------------------------------------------------------------------------

@onready var map: Node2D = $Map
@onready var towers: Node2D = $Towers
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var ui: CanvasLayer = $UI

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect to manager signals so the scene can react to state changes
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)
	GameManager.lives_changed.connect(_on_lives_changed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Starts a level by ID on the given difficulty.
## Resets match economy with the appropriate gold modifier, then tells
## GameManager to begin.
func start_level(level_id: String, difficulty: int = Enums.Difficulty.NORMAL) -> void:
	# Reset match economy and apply difficulty gold modifier
	EconomyManager.reset_match_economy()
	var gold_modifier: float = Constants.DIFFICULTY_GOLD_MULT.get(difficulty, 1.0)
	EconomyManager.set_gold_modifier(gold_modifier)

	# Delegate level start to GameManager
	GameManager.start_level(level_id, difficulty)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_state_changed(new_state: int, _old_state: int) -> void:
	match new_state:
		Enums.GameState.BUILDING:
			_enter_building_phase()
		Enums.GameState.WAVE_ACTIVE:
			_enter_wave_phase()
		Enums.GameState.WAVE_COMPLETE:
			_enter_wave_complete()
		Enums.GameState.VICTORY:
			_enter_victory()
		Enums.GameState.DEFEAT:
			_enter_defeat()
		Enums.GameState.PAUSED:
			_enter_paused()

func _on_level_completed(_level_id: String, stars: int) -> void:
	print("Level completed with %d stars!" % stars)

func _on_level_failed(_level_id: String) -> void:
	print("Level failed.")

func _on_lives_changed(new_lives: int, _lives_lost: int) -> void:
	print("Lives remaining: %d" % new_lives)

# ---------------------------------------------------------------------------
# Phase transitions (stubs for future implementation)
# ---------------------------------------------------------------------------

func _enter_building_phase() -> void:
	pass  # Future: show build UI, enable tower placement

func _enter_wave_phase() -> void:
	pass  # Future: start spawning enemies

func _enter_wave_complete() -> void:
	pass  # Future: show wave complete summary

func _enter_victory() -> void:
	pass  # Future: show victory screen

func _enter_defeat() -> void:
	pass  # Future: show defeat screen

func _enter_paused() -> void:
	pass  # Future: show pause menu
