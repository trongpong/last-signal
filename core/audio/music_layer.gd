class_name MusicLayer
extends AudioStreamPlayer

## A single adaptive music layer that supports smooth volume fading.
## Layers automatically stop when silent and resume when given a target volume.

const FADE_SPEED := 2.0  # dB or linear units per second

var target_volume: float = 0.0  # linear [0..1]
var _current_volume: float = 0.0  # linear [0..1]


func _ready() -> void:
	volume_db = -80.0
	_current_volume = 0.0
	target_volume = 0.0
	finished.connect(_on_finished)


## Restart playback when stream ends (replaces native LOOP_FORWARD to avoid Android crash).
func _on_finished() -> void:
	if target_volume > 0.0001 and stream != null:
		play()


func _process(delta: float) -> void:
	if is_equal_approx(_current_volume, target_volume):
		return

	_current_volume = move_toward(_current_volume, target_volume, FADE_SPEED * delta)

	if _current_volume <= 0.0001:
		_current_volume = 0.0
		volume_db = -80.0
		if playing:
			stop()
		return

	volume_db = linear_to_db(_current_volume)

	if not playing and _current_volume > 0.0001 and stream != null:
		play()


## Begin fading this layer in to the given linear volume [0..1].
func fade_in(vol: float = 1.0) -> void:
	target_volume = clampf(vol, 0.0, 1.0)
	if not playing and stream != null:
		play()


## Begin fading this layer out to silence.
func fade_out() -> void:
	target_volume = 0.0
