class_name MusicSystem
extends Node

## Adaptive music system for Last Signal.
## Manages multiple MusicLayers that fade in/out based on game state and region.

const SAMPLE_RATE: int = 44100
const LOOP_DURATION: float = 8.0

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
	_assign_layer_streams()


## Generate procedural audio streams and assign them to each music layer.
func _assign_layer_streams() -> void:
	# base: warm ambient drone — A1 + E2 sine, very low cutoff
	_layer_base.stream = _make_drone_stream(55.0, 82.5, "sine", 220.0)
	# intensity: mid-range tension — A2 + D3 sine
	_layer_intensity.stream = _make_drone_stream(110.0, 146.8, "sine", 400.0)
	# combat: brighter energy — A3 + A4 square
	_layer_combat.stream = _make_drone_stream(220.0, 440.0, "square", 600.0)
	# boss: deep ominous sub-bass — A0 + A1 saw
	_layer_boss.stream = _make_drone_stream(27.5, 55.0, "saw", 100.0)


## Generate an 8-second looped AudioStreamWAV drone from two frequencies.
func _make_drone_stream(freq_a: float, freq_b: float, wave: String, cutoff: float) -> AudioStreamWAV:
	var layer_a: PackedFloat32Array
	var layer_b: PackedFloat32Array
	match wave:
		"sine":
			layer_a = SynthEngine.generate_sine(freq_a, LOOP_DURATION, SAMPLE_RATE)
			layer_b = SynthEngine.generate_sine(freq_b, LOOP_DURATION, SAMPLE_RATE)
		"square":
			layer_a = SynthEngine.generate_square(freq_a, LOOP_DURATION, SAMPLE_RATE)
			layer_b = SynthEngine.generate_square(freq_b, LOOP_DURATION, SAMPLE_RATE)
		_:  # saw
			layer_a = SynthEngine.generate_saw(freq_a, LOOP_DURATION, SAMPLE_RATE)
			layer_b = SynthEngine.generate_saw(freq_b, LOOP_DURATION, SAMPLE_RATE)
	var mixed := SynthEngine.mix(layer_a, layer_b, 0.6, 0.4)
	mixed = SynthEngine.apply_filter_lowpass(mixed, cutoff, SAMPLE_RATE)
	mixed = SynthEngine.apply_adsr(mixed, 0.5, 0.2, 0.8, 0.5, SAMPLE_RATE)
	var stream := SynthEngine.samples_to_stream(mixed, SAMPLE_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = mixed.size()
	return stream


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
