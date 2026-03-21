class_name MusicSystem
extends Node

## Adaptive music system for Last Signal.
## Manages multiple MusicLayers that fade in/out based on game state and region.

const REGION_KEYS: Dictionary = {
	1: "C",
	2: "D",
	3: "F#",
	4: "A",
	5: "E"
}

var current_key: String = "C"
var intensity: float = 0.0

var _layer_base: MusicLayer
var _layer_intensity: MusicLayer
var _layer_combat: MusicLayer
var _layer_boss: MusicLayer

var _current_state: Enums.GameState = Enums.GameState.MENU
var _boss_active: bool = false


func _ready() -> void:
	_layer_base = _make_layer("base", "Music")
	_layer_intensity = _make_layer("intensity", "Music")
	_layer_combat = _make_layer("combat", "Music")
	_layer_boss = _make_layer("boss", "Music")


func _make_layer(layer_name: String, bus: String) -> MusicLayer:
	var layer := MusicLayer.new()
	layer.name = layer_name
	layer.bus = bus
	layer.autoplay = false
	add_child(layer)
	return layer


## Switch the musical key for the current region.
func set_region(region: int) -> void:
	if REGION_KEYS.has(region):
		current_key = REGION_KEYS[region]


## Update music layer mix based on the current game state.
func set_game_state(state: Enums.GameState) -> void:
	_current_state = state
	_apply_state()


## Enable or disable the boss music layer.
func set_boss_active(active: bool) -> void:
	_boss_active = active
	_apply_state()


## Set intensity [0..1] — controls the intensity layer volume.
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _current_state == Enums.GameState.WAVE_ACTIVE and not _boss_active:
		_layer_intensity.fade_in(intensity)


## Return a list of currently active (non-silent) layer names.
func get_active_layers() -> Array[String]:
	var result: Array[String] = []
	if _layer_base.target_volume > 0.0:
		result.append("base")
	if _layer_intensity.target_volume > 0.0:
		result.append("intensity")
	if _layer_combat.target_volume > 0.0:
		result.append("combat")
	if _layer_boss.target_volume > 0.0:
		result.append("boss")
	return result


func _apply_state() -> void:
	match _current_state:
		Enums.GameState.MENU:
			_layer_base.fade_out()
			_layer_intensity.fade_out()
			_layer_combat.fade_out()
			_layer_boss.fade_out()

		Enums.GameState.BUILDING:
			_layer_base.fade_in(1.0)
			_layer_intensity.fade_out()
			_layer_combat.fade_out()
			_layer_boss.fade_out()

		Enums.GameState.WAVE_ACTIVE:
			_layer_base.fade_in(1.0)
			if _boss_active:
				_layer_intensity.fade_out()
				_layer_combat.fade_out()
				_layer_boss.fade_in(1.0)
			else:
				_layer_intensity.fade_in(intensity)
				_layer_combat.fade_in(1.0)
				_layer_boss.fade_out()

		Enums.GameState.VICTORY, Enums.GameState.DEFEAT:
			_layer_base.fade_in(0.4)
			_layer_intensity.fade_out()
			_layer_combat.fade_out()
			_layer_boss.fade_out()

		Enums.GameState.WAVE_COMPLETE:
			_layer_base.fade_in(1.0)
			_layer_intensity.fade_out()
			_layer_combat.fade_out()
			_layer_boss.fade_out()

		Enums.GameState.PAUSED:
			# Maintain current state, no changes
			pass
