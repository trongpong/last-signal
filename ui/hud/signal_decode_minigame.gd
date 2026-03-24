extends Control

## Between-wave minigame: a glyph sequence flashes, player taps them back.
## Success gives a random bonus. Fail or skip = nothing happens.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal decode_succeeded(reward_type: int, reward_value: float)
signal decode_finished

# ---------------------------------------------------------------------------
# Reward types
# ---------------------------------------------------------------------------

enum RewardType { GOLD, DAMAGE_BUFF, COOLDOWN_REDUCTION }

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

enum Phase { SHOWING, INPUT, RESULT }

var _phase: int = Phase.SHOWING
var _sequence: Array = []
var _input_index: int = 0
var _timer: float = 0.0
var _display_index: int = 0
var _display_interval: float = 0.0
var _succeeded: bool = false

# UI refs
var _glyph_buttons: Array = []
var _sequence_labels: Array = []
var _timer_bar: ColorRect = null
var _timer_bg: ColorRect = null
var _status_label: Label = null
var _prompt_label: Label = null

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(wave_number: int) -> void:
	var seq_length: int = _get_sequence_length(wave_number)
	_sequence.clear()
	for i in range(seq_length):
		_sequence.append(randi() % Constants.SIGNAL_DECODE_GLYPHS.size())
	_phase = Phase.SHOWING
	_display_index = 0
	_display_interval = Constants.SIGNAL_DECODE_DISPLAY_TIME / float(seq_length)
	_timer = 0.0
	_input_index = 0
	_succeeded = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func skip() -> void:
	decode_finished.emit()

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.SHOWING:
			var idx: int = int(_timer / _display_interval)
			if idx != _display_index and idx < _sequence.size():
				_display_index = idx
				_highlight_sequence_label(idx)
			if _timer >= Constants.SIGNAL_DECODE_DISPLAY_TIME:
				_start_input_phase()
		Phase.INPUT:
			var elapsed: float = _timer
			if _timer_bar != null and _timer_bg != null:
				var fraction: float = clampf(1.0 - elapsed / Constants.SIGNAL_DECODE_INPUT_TIME, 0.0, 1.0)
				_timer_bar.size.x = _timer_bg.size.x * fraction
			if elapsed >= Constants.SIGNAL_DECODE_INPUT_TIME:
				_finish(false)
		Phase.RESULT:
			if _timer >= 0.5:
				decode_finished.emit()
				set_process(false)

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Position: bottom-center, above tower bar
	anchor_left = 0.25
	anchor_right = 0.75
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -210.0
	offset_bottom = -80.0

	# Background panel
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.08, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Prompt
	_prompt_label = Label.new()
	_prompt_label.text = tr("SIGNAL_DECODE_PROMPT")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_prompt_label)

	# Sequence display row
	var seq_hbox := HBoxContainer.new()
	seq_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	seq_hbox.add_theme_constant_override("separation", 8)
	seq_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(seq_hbox)
	for i in range(_sequence.size()):
		var lbl := Label.new()
		lbl.text = Constants.SIGNAL_DECODE_GLYPHS[_sequence[i]]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		lbl.custom_minimum_size = Vector2(28, 28)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seq_hbox.add_child(lbl)
		_sequence_labels.append(lbl)

	# Timer bar
	_timer_bg = ColorRect.new()
	_timer_bg.custom_minimum_size = Vector2(0, 4)
	_timer_bg.color = Color(0.3, 0.3, 0.3, 0.6)
	_timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_timer_bg)
	_timer_bar = ColorRect.new()
	_timer_bar.custom_minimum_size = Vector2(0, 4)
	_timer_bar.color = Color(1.0, 0.85, 0.0, 0.8)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bg.add_child(_timer_bar)

	# Glyph buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_hbox)
	for i in range(Constants.SIGNAL_DECODE_GLYPHS.size()):
		var btn := Button.new()
		btn.text = Constants.SIGNAL_DECODE_GLYPHS[i]
		btn.custom_minimum_size = Vector2(44, 44)
		btn.add_theme_font_size_override("font_size", 20)
		btn.disabled = true  # Disabled during SHOWING phase
		btn.pressed.connect(_on_glyph_pressed.bind(i))
		btn_hbox.add_child(btn)
		_glyph_buttons.append(btn)

	# Status label (hidden initially)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.visible = false
	vbox.add_child(_status_label)

# ---------------------------------------------------------------------------
# Phase transitions
# ---------------------------------------------------------------------------

func _highlight_sequence_label(idx: int) -> void:
	if idx < _sequence_labels.size():
		_sequence_labels[idx].add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))

func _start_input_phase() -> void:
	_phase = Phase.INPUT
	_timer = 0.0
	_input_index = 0
	# Hide sequence, enable buttons
	for lbl in _sequence_labels:
		lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	for btn in _glyph_buttons:
		btn.disabled = false
	if _prompt_label != null:
		_prompt_label.text = tr("SIGNAL_DECODE_INPUT_PROMPT")

func _on_glyph_pressed(glyph_index: int) -> void:
	if _phase != Phase.INPUT:
		return
	if glyph_index == _sequence[_input_index]:
		# Correct — highlight this position
		if _input_index < _sequence_labels.size():
			_sequence_labels[_input_index].add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		_input_index += 1
		if _input_index >= _sequence.size():
			_finish(true)
	else:
		# Wrong
		_finish(false)

func _finish(success: bool) -> void:
	_succeeded = success
	_phase = Phase.RESULT
	_timer = 0.0
	for btn in _glyph_buttons:
		btn.disabled = true
	if _status_label != null:
		_status_label.visible = true
		if success:
			_status_label.text = tr("SIGNAL_DECODE_SUCCESS")
			_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			_emit_reward()
		else:
			_status_label.text = tr("SIGNAL_DECODE_FAIL")
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

func _emit_reward() -> void:
	var roll: float = randf()
	if roll < 0.33:
		decode_succeeded.emit(RewardType.GOLD, float(Constants.SIGNAL_DECODE_REWARD_GOLD))
	elif roll < 0.66:
		decode_succeeded.emit(RewardType.DAMAGE_BUFF, Constants.SIGNAL_DECODE_REWARD_DAMAGE_MULT)
	else:
		decode_succeeded.emit(RewardType.COOLDOWN_REDUCTION, Constants.SIGNAL_DECODE_REWARD_COOLDOWN_SECS)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_sequence_length(wave_number: int) -> int:
	if wave_number <= 10:
		return 4
	elif wave_number <= 25:
		return 5
	return 6
