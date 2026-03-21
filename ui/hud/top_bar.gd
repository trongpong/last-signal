class_name TopBar
extends HBoxContainer

## HUD top bar displaying lives, gold, wave info, speed toggle, and send-wave button.
## Connects to GameManager and WaveManager signals via HUD.bind_signals().

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal send_wave_pressed
signal speed_changed(speed: float)

# ---------------------------------------------------------------------------
# Node references (set in _ready or via assign_nodes)
# ---------------------------------------------------------------------------

var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _send_wave_btn: Button
var _speed_btn: Button

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _current_speed_index: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()

# ---------------------------------------------------------------------------
# Layout (procedural — assembles children programmatically)
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	# Lives section
	var lives_box := HBoxContainer.new()
	var lives_icon_lbl := Label.new()
	lives_icon_lbl.text = tr("HUD_LIVES") + ":"
	_lives_label = Label.new()
	_lives_label.text = "20"
	lives_box.add_child(lives_icon_lbl)
	lives_box.add_child(_lives_label)
	add_child(lives_box)

	# Separator
	add_child(_make_spacer())

	# Gold section
	var gold_box := HBoxContainer.new()
	var gold_icon_lbl := Label.new()
	gold_icon_lbl.text = tr("HUD_GOLD") + ":"
	_gold_label = Label.new()
	_gold_label.text = "0"
	gold_box.add_child(gold_icon_lbl)
	gold_box.add_child(_gold_label)
	add_child(gold_box)

	# Separator
	add_child(_make_spacer())

	# Wave section
	var wave_box := HBoxContainer.new()
	var wave_icon_lbl := Label.new()
	wave_icon_lbl.text = tr("HUD_WAVE") + ":"
	_wave_label = Label.new()
	_wave_label.text = "0 / 0"
	wave_box.add_child(wave_icon_lbl)
	wave_box.add_child(_wave_label)
	add_child(wave_box)

	# Separator
	add_child(_make_spacer())

	# Speed button
	_speed_btn = Button.new()
	_speed_btn.text = tr("HUD_SPEED") + " x1"
	_speed_btn.pressed.connect(_cycle_speed)
	add_child(_speed_btn)

	# Send wave button
	_send_wave_btn = Button.new()
	_send_wave_btn.text = tr("HUD_SEND_WAVE")
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)
	add_child(_send_wave_btn)


func _make_spacer() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(16, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Update the lives display.
func update_lives(lives: int) -> void:
	if _lives_label != null:
		_lives_label.text = str(lives)


## Update the gold display.
func update_gold(gold: int) -> void:
	if _gold_label != null:
		_gold_label.text = str(gold)


## Update the wave counter display.
func update_wave(current: int, total: int) -> void:
	if _wave_label != null:
		_wave_label.text = "%d / %d" % [current, total]


## Enable or disable the Send Wave button.
func set_send_enabled(enabled: bool) -> void:
	if _send_wave_btn != null:
		_send_wave_btn.disabled = not enabled

# ---------------------------------------------------------------------------
# Speed cycling
# ---------------------------------------------------------------------------

func _cycle_speed() -> void:
	_current_speed_index = (_current_speed_index + 1) % Constants.SPEED_OPTIONS.size()
	var new_speed: float = Constants.SPEED_OPTIONS[_current_speed_index] as float
	if _speed_btn != null:
		_speed_btn.text = tr("HUD_SPEED") + " x%s" % str(new_speed)
	speed_changed.emit(new_speed)


func _on_send_wave_pressed() -> void:
	send_wave_pressed.emit()
