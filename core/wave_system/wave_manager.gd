class_name WaveManager
extends Node

## Manages wave sequencing, enemy spawning, break timers, and wave-clear detection.
## Drives the spawn loop via _process. Connect signals to wire up game logic.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a wave becomes active.
signal wave_started(wave_number: int, total_waves: int)

## Emitted when all enemies in a wave have died or exited.
signal wave_complete(wave_number: int)

## Emitted after the final wave clears.
signal all_waves_complete

## Emitted when the spawner wants to create an enemy instance.
signal enemy_spawn_requested(enemy_id: String)

## Emitted at the start of a break period between waves.
signal break_started(duration: float)

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Current wave index into _waves (-1 before any wave starts).
var current_wave_index: int = -1

## Total number of waves loaded.
var total_waves: int = 0

## Whether a wave is currently running.
var is_wave_active: bool = false

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## The loaded wave definitions.
var _waves: Array = []

## Flat spawn queue: array of Dictionaries {enemy_id, delay_remaining}
## Built from the active WaveDefinition's sub_waves.
var _spawn_queue: Array = []

## Accumulated time since last spawn attempt.
var _spawn_timer: float = 0.0

## Enemies still alive (spawned but not dead/exited) in current wave.
var _enemies_alive: int = 0

## Enemies yet to be spawned in current wave.
var _enemies_to_spawn: int = 0

## Whether we are in a break between waves.
var _in_break: bool = false

## Remaining break time in seconds.
var _break_timer: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _in_break:
		_break_timer -= delta
		if _break_timer <= 0.0:
			_in_break = false
			if has_more_waves():
				start_next_wave()
	elif is_wave_active:
		_process_spawn_queue(delta)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Loads wave definitions and resets manager state.
func load_waves(waves: Array) -> void:
	_waves = waves
	total_waves = waves.size()
	current_wave_index = -1
	is_wave_active = false
	_in_break = false
	_break_timer = 0.0
	_spawn_queue.clear()
	_enemies_alive = 0
	_enemies_to_spawn = 0


## Starts the next wave in sequence. Does nothing if already active or no more waves.
func start_next_wave() -> void:
	if is_wave_active:
		return
	if not has_more_waves():
		return

	current_wave_index += 1
	var wave: WaveDefinition = _waves[current_wave_index]

	_build_spawn_queue(wave)
	_enemies_alive = wave.get_total_enemy_count()
	_enemies_to_spawn = _enemies_alive
	_spawn_timer = 0.0

	is_wave_active = true
	wave_started.emit(wave.wave_number, total_waves)


## Returns true if there are still waves left to play.
func has_more_waves() -> bool:
	return current_wave_index + 1 < total_waves


## Returns the gold bonus for sending the next wave early.
## Scales linearly with remaining break time.
func get_early_send_bonus() -> int:
	if not _in_break or _break_timer <= 0.0:
		return 0
	var fraction: float = _break_timer / Constants.WAVE_BREAK_DURATION
	return int(Constants.EARLY_SEND_GOLD_BONUS * fraction)


## Called by the game when an enemy dies in the field.
func on_enemy_died() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_check_wave_clear()


## Called by the game when an enemy reaches the exit (counts against lives but still clears).
func on_enemy_reached_exit() -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_check_wave_clear()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds a flat spawn queue from the sub-waves of the given WaveDefinition.
## Each entry: { enemy_id: String, delay_remaining: float }
func _build_spawn_queue(wave: WaveDefinition) -> void:
	_spawn_queue.clear()
	for sw: SubWaveDefinition in wave.sub_waves:
		var accumulated_delay: float = sw.delay
		for i in sw.count:
			_spawn_queue.append({
				"enemy_id": sw.enemy_id,
				"delay_remaining": accumulated_delay,
			})
			accumulated_delay += sw.spawn_interval


## Advances the spawn queue by delta, emitting enemy_spawn_requested for ready entries.
func _process_spawn_queue(delta: float) -> void:
	if _spawn_queue.is_empty():
		return

	_spawn_timer += delta

	# Process from front of queue — entries are ordered by delay.
	while not _spawn_queue.is_empty():
		var entry: Dictionary = _spawn_queue[0]
		if _spawn_timer >= entry["delay_remaining"]:
			_spawn_queue.pop_front()
			_enemies_to_spawn -= 1
			enemy_spawn_requested.emit(entry["enemy_id"])
		else:
			break


## Checks whether all enemies have been resolved (spawned + dead/exited).
func _check_wave_clear() -> void:
	if not is_wave_active:
		return
	# Wave clears when spawn queue is empty and no enemies remain alive.
	if _spawn_queue.is_empty() and _enemies_to_spawn <= 0 and _enemies_alive <= 0:
		_on_wave_enemies_cleared()


## Called when all enemies in the wave are gone.
func _on_wave_enemies_cleared() -> void:
	var finished_wave: WaveDefinition = _waves[current_wave_index]
	is_wave_active = false
	wave_complete.emit(finished_wave.wave_number)

	if has_more_waves():
		_in_break = true
		_break_timer = Constants.WAVE_BREAK_DURATION
		break_started.emit(Constants.WAVE_BREAK_DURATION)
	else:
		all_waves_complete.emit()
