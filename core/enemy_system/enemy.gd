class_name Enemy
extends Node2D

## Base enemy node. Attach a PathProvider child before calling initialize().
## initialize() must be called with an EnemyDefinition and Difficulty before
## adding the enemy to the scene tree (or immediately after).

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the enemy's HP reaches zero.
signal enemy_died(enemy: Enemy)

## Emitted when the enemy successfully traverses the path to the exit.
signal enemy_reached_exit(enemy: Enemy)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var _definition: EnemyDefinition = null
var _health: EnemyHealth = null
var _renderer: EnemyRenderer = null
var _path_provider: PathProvider = null

var _effective_speed: float = 150.0
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _initialized: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Fully initialises the enemy from a definition and difficulty.
## Creates EnemyHealth and EnemyRenderer as children.
## path_provider must already be added as a child (or set via set_path_provider).
func initialize(def: EnemyDefinition, difficulty: int) -> void:
	_definition = def

	var constants := Constants.new()
	var hp_mult: float = constants.DIFFICULTY_HP_MULT.get(difficulty, 1.0) as float
	var spd_mult: float = constants.DIFFICULTY_SPEED_MULT.get(difficulty, 1.0) as float
	constants.free()

	# Health component
	_health = EnemyHealth.new()
	_health.name = "EnemyHealth"
	add_child(_health)
	_health.initialize(
		def.base_hp * hp_mult,
		def.armor,
		def.shield,
		def.resistance_map
	)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)

	# Renderer component
	_renderer = EnemyRenderer.new()
	_renderer.name = "EnemyRenderer"
	add_child(_renderer)
	_renderer.setup(def)

	# Speed (affected by difficulty)
	_effective_speed = def.speed * spd_mult

	_initialized = true

## Assign the path provider. Must be set before _process runs.
func set_path_provider(provider: PathProvider) -> void:
	_path_provider = provider

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _initialized or _path_provider == null:
		return
	if not _health.is_alive():
		return

	# Advance along path
	var current_speed := _effective_speed * _slow_factor
	_path_provider.move(current_speed, delta)

	# Sync visual position with path
	global_position = _path_provider.get_current_position()

	# Slow timer countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_factor = 1.0

	# Check exit
	if _path_provider.has_reached_end():
		on_reached_exit()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Applies a movement slow effect. factor is 0.0–1.0 (1.0 = no slow, 0.5 = half speed).
## The effect lasts for duration seconds; a new slow only applies if stronger.
func apply_slow(factor: float, duration: float) -> void:
	var clamped: float = clampf(factor, 0.0, 1.0)
	if clamped < _slow_factor:
		_slow_factor = clamped
		_slow_timer = maxf(duration, _slow_timer)

## Returns the gold value of this enemy (from its definition).
func get_gold_value() -> int:
	if _definition == null:
		return 0
	return _definition.gold_value

## Returns true if the enemy is still alive.
func is_alive() -> bool:
	if _health == null:
		return false
	return _health.is_alive()

## Returns 0.0–1.0 HP fraction.
func get_hp_percentage() -> float:
	if _health == null:
		return 0.0
	return _health.get_hp_percentage()

## Returns current path progress ratio (0.0–1.0).
func get_progress_ratio() -> float:
	if _path_provider == null:
		return 0.0
	return _path_provider.get_progress_ratio()

## Called when the enemy reaches the exit. Emits signal and queues removal.
func on_reached_exit() -> void:
	enemy_reached_exit.emit(self)
	set_process(false)
	queue_free()

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_health_changed(hp: float, max_hp: float, shield: float) -> void:
	if _renderer != null:
		_renderer.update_health(hp, max_hp, shield)

func _on_died() -> void:
	set_process(false)
	enemy_died.emit(self)
	queue_free()
