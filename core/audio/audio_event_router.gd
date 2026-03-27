extends Node
## Routes game events to AudioManager play calls.
## Computes escalation factor and handles rate limiting.

const MAX_HITS_PER_SECOND := 6
const MAX_GOLD_EARNS_PER_SECOND := 3
const ENDLESS_ESCALATION_CAP := 30.0

var _escalation := 0.0
var _suppress_economy_audio := false
var _prev_lives_lost: int = 0
var _is_endless_mode := false

var _hit_timestamps: Array[float] = []
var _gold_earn_timestamps: Array[float] = []


func get_escalation() -> float:
	return _escalation


func suppress_economy_audio(suppressed: bool) -> void:
	_suppress_economy_audio = suppressed


func setup(wave_manager: Node, endless_mode: bool = false) -> void:
	_is_endless_mode = endless_mode
	_prev_lives_lost = 0
	# Disconnect stale autoload signals from previous game sessions
	# (WaveManager is freed between sessions so its connections auto-disconnect,
	# but autoload signals persist since AudioEventRouter lives on AudioManager)
	_disconnect_if_connected(GameManager, "lives_changed", _on_lives_changed)
	_disconnect_if_connected(GameManager, "level_completed", _on_level_completed)
	_disconnect_if_connected(GameManager, "level_failed", _on_level_failed)
	_disconnect_if_connected(EconomyManager, "gold_changed", _on_gold_changed)
	_disconnect_if_connected(EconomyManager, "diamonds_changed", _on_diamonds_changed)
	# Connect signals
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_complete.connect(_on_wave_complete)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	EconomyManager.diamonds_changed.connect(_on_diamonds_changed)


func _update_escalation(wave_number: int, total_waves: int) -> void:
	if _is_endless_mode:
		_escalation = clampf(float(wave_number) / ENDLESS_ESCALATION_CAP, 0.0, 1.0)
	else:
		_escalation = clampf(float(wave_number) / maxf(float(total_waves), 1.0), 0.0, 1.0)


func can_play_hit() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	_hit_timestamps = _hit_timestamps.filter(func(t: float) -> bool: return now - t < 1.0)
	if _hit_timestamps.size() >= MAX_HITS_PER_SECOND:
		return false
	_hit_timestamps.append(now)
	return true


func _can_play_gold_earn() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	_gold_earn_timestamps = _gold_earn_timestamps.filter(func(t: float) -> bool: return now - t < 1.0)
	if _gold_earn_timestamps.size() >= MAX_GOLD_EARNS_PER_SECOND:
		return false
	_gold_earn_timestamps.append(now)
	return true


func _on_wave_started(wave_number: int, total_waves: int) -> void:
	_update_escalation(wave_number, total_waves)
	AudioManager.play_wave_start(_escalation)
	AudioManager.set_music_intensity(_escalation)


func _on_wave_complete(wave_number: int) -> void:
	AudioManager.play_wave_complete(_escalation)


func _on_lives_changed(_new_lives: int, lives_lost: int) -> void:
	if lives_lost > _prev_lives_lost:
		AudioManager.play_lives_lost(_escalation)
	_prev_lives_lost = lives_lost


func _on_level_completed(_level_id: String, _stars: int) -> void:
	AudioManager.play_victory(_escalation)


func _on_level_failed(_level_id: String) -> void:
	AudioManager.play_defeat(_escalation)


func _on_gold_changed(_new_gold: int, delta: int) -> void:
	if _suppress_economy_audio:
		return
	if delta > 0:
		if _can_play_gold_earn():
			AudioManager.play_gold_earn()
	elif delta < 0:
		AudioManager.play_gold_spend()


func _on_diamonds_changed(_new_diamonds: int, delta: int) -> void:
	if _suppress_economy_audio:
		return
	if delta > 0:
		AudioManager.play_diamond_earn()


func _disconnect_if_connected(source: Object, signal_name: String, callable: Callable) -> void:
	if source.is_connected(signal_name, callable):
		source.disconnect(signal_name, callable)
