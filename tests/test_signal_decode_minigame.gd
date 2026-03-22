extends GutTest

## Tests for ui/hud/signal_decode_minigame.gd

var _minigame

func before_each() -> void:
	_minigame = load("res://ui/hud/signal_decode_minigame.gd").new()
	add_child(_minigame)

func after_each() -> void:
	if is_instance_valid(_minigame):
		_minigame.queue_free()

# ---------------------------------------------------------------------------
# Sequence length
# ---------------------------------------------------------------------------

func test_sequence_length_waves_1_to_10() -> void:
	_minigame.setup(5)
	assert_eq(_minigame._sequence.size(), 4)

func test_sequence_length_waves_11_to_25() -> void:
	_minigame.setup(15)
	assert_eq(_minigame._sequence.size(), 5)

func test_sequence_length_waves_26_plus() -> void:
	_minigame.setup(30)
	assert_eq(_minigame._sequence.size(), 6)

func test_sequence_length_wave_10_is_4() -> void:
	_minigame.setup(10)
	assert_eq(_minigame._sequence.size(), 4)

func test_sequence_length_wave_25_is_5() -> void:
	_minigame.setup(25)
	assert_eq(_minigame._sequence.size(), 5)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func test_correct_input_emits_succeeded() -> void:
	_minigame.setup(5)
	# Advance past SHOWING phase
	_minigame._start_input_phase()
	watch_signals(_minigame)
	# Tap correct sequence
	for glyph_idx in _minigame._sequence:
		_minigame._on_glyph_pressed(glyph_idx)
	assert_signal_emitted(_minigame, "decode_succeeded")

func test_wrong_input_does_not_emit_succeeded() -> void:
	_minigame.setup(5)
	_minigame._start_input_phase()
	watch_signals(_minigame)
	# Tap wrong glyph (find one not in sequence)
	var wrong: int = 0
	if _minigame._sequence.size() > 0 and _minigame._sequence[0] == 0:
		wrong = 1
	_minigame._on_glyph_pressed(wrong if wrong != _minigame._sequence[0] else wrong + 1)
	assert_signal_not_emitted(_minigame, "decode_succeeded")

func test_skip_emits_finished() -> void:
	_minigame.setup(5)
	watch_signals(_minigame)
	_minigame.skip()
	assert_signal_emitted(_minigame, "decode_finished")

# ---------------------------------------------------------------------------
# Camera shake
# ---------------------------------------------------------------------------

func test_camera_shake_sets_timer() -> void:
	var cam := GameCamera.new()
	add_child(cam)
	cam.setup(1.0, Vector2(1280, 720))
	cam.shake(5.0, 0.3)
	assert_gt(cam._shake_timer, 0.0)
	cam.queue_free()

func test_camera_shake_resets_after_duration() -> void:
	var cam := GameCamera.new()
	add_child(cam)
	cam.setup(1.0, Vector2(1280, 720))
	cam.shake(5.0, 0.1)
	for i in range(10):
		cam._process(0.02)
	assert_almost_eq(cam._shake_timer, 0.0, 0.001)
	assert_eq(cam.offset, Vector2.ZERO)
	cam.queue_free()
