class_name TopBar
extends HBoxContainer

## HUD top bar displaying lives, gold, wave info, and speed toggle.
## Connects to GameManager and WaveManager signals via HUD.bind_signals().

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal speed_changed(speed: float)

# ---------------------------------------------------------------------------
# Node references (set in _ready or via assign_nodes)
# ---------------------------------------------------------------------------

var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _speed_btn: Button

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _current_speed_index: int = 0
var _available_speeds: Array = [1.0]
var _previous_gold: int = -1
var _previous_lives: int = -1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()

# ---------------------------------------------------------------------------
# Layout (procedural — assembles children programmatically)
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	custom_minimum_size = Vector2(0, 56)

	# Left padding spacer so labels aren't flush against the screen edge
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(10, 0)
	add_child(left_pad)

	# Lives section
	var lives_box := HBoxContainer.new()
	var lives_icon_lbl := Label.new()
	lives_icon_lbl.text = tr("HUD_LIVES") + ":"
	lives_icon_lbl.add_theme_font_size_override("font_size", 16)
	_lives_label = Label.new()
	_lives_label.text = "20"
	_lives_label.add_theme_font_size_override("font_size", 20)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lives_box.add_child(lives_icon_lbl)
	lives_box.add_child(_lives_label)
	add_child(lives_box)

	# Separator
	add_child(_make_separator())

	# Gold section
	var gold_box := HBoxContainer.new()
	var gold_icon_lbl := Label.new()
	gold_icon_lbl.text = tr("HUD_GOLD") + ":"
	gold_icon_lbl.add_theme_font_size_override("font_size", 16)
	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	gold_box.add_child(gold_icon_lbl)
	gold_box.add_child(_gold_label)
	add_child(gold_box)

	# Separator
	add_child(_make_separator())

	# Wave section
	var wave_box := HBoxContainer.new()
	var wave_icon_lbl := Label.new()
	wave_icon_lbl.text = tr("HUD_WAVE") + ":"
	wave_icon_lbl.add_theme_font_size_override("font_size", 16)
	_wave_label = Label.new()
	_wave_label.text = "0 / 0"
	_wave_label.add_theme_font_size_override("font_size", 20)
	_wave_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	wave_box.add_child(wave_icon_lbl)
	wave_box.add_child(_wave_label)
	add_child(wave_box)

	# Separator
	add_child(_make_separator())

	# Speed button
	_speed_btn = Button.new()
	_speed_btn.text = tr("HUD_SPEED") + " x1"
	_speed_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_speed_btn.pressed.connect(_cycle_speed)
	add_child(_speed_btn)

	# Right padding spacer
	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(10, 0)
	add_child(right_pad)


func _make_separator() -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(16, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var sep_lbl := Label.new()
	sep_lbl.text = "|"
	sep_lbl.add_theme_font_size_override("font_size", 18)
	sep_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
	box.add_child(sep_lbl)
	return box

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Update the lives display.
func update_lives(lives: int) -> void:
	if _lives_label == null:
		return
	if _previous_lives >= 0 and lives < _previous_lives:
		_flash_lives_lost()
	_previous_lives = lives
	_lives_label.text = str(lives)


## Update the gold display.
func update_gold(gold: int) -> void:
	if _gold_label == null:
		return
	if _previous_gold >= 0:
		var diff: int = gold - _previous_gold
		if diff != 0:
			_show_gold_change(diff)
	_previous_gold = gold
	_gold_label.text = str(gold)


## Update the wave counter display.
func update_wave(current: int, total: int) -> void:
	if _wave_label != null:
		_wave_label.text = "%d / %d" % [current, total]



# ---------------------------------------------------------------------------
# Visual feedback
# ---------------------------------------------------------------------------

## Show a floating "+X" / "-X" label near the gold display that drifts up and fades out.
func _show_gold_change(amount: int) -> void:
	var lbl := Label.new()
	if amount > 0:
		lbl.text = "+" + str(amount)
		lbl.modulate = Color.GREEN
	else:
		lbl.text = str(amount)
		lbl.modulate = Color.RED

	# Add as sibling so it renders in the same coordinate space.
	_gold_label.get_parent().add_child(lbl)
	lbl.position = _gold_label.position + Vector2(0, -4)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 30, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)


## Flash the lives label red and give it a brief horizontal shake.
func _flash_lives_lost() -> void:
	var tw := create_tween()
	_lives_label.modulate = Color.RED
	tw.tween_property(_lives_label, "modulate", Color.WHITE, 0.3)
	# Small shake
	var orig_x: float = _lives_label.position.x
	var shake_tw := create_tween()
	shake_tw.tween_property(_lives_label, "position:x", orig_x + 3.0, 0.05)
	shake_tw.tween_property(_lives_label, "position:x", orig_x - 3.0, 0.05)
	shake_tw.tween_property(_lives_label, "position:x", orig_x, 0.05)

# ---------------------------------------------------------------------------
# Speed cycling
# ---------------------------------------------------------------------------

## Set which speed options are available based on unlocks.
func set_available_speeds(has_x2: bool, has_x3: bool) -> void:
	_available_speeds = [1.0]
	if has_x2:
		_available_speeds.append(2.0)
	if has_x3:
		_available_speeds.append(3.0)
	_current_speed_index = 0
	if _speed_btn != null:
		_speed_btn.text = tr("HUD_SPEED") + " x1"

func _cycle_speed() -> void:
	_current_speed_index = (_current_speed_index + 1) % _available_speeds.size()
	var new_speed: float = _available_speeds[_current_speed_index] as float
	if _speed_btn != null:
		_speed_btn.text = tr("HUD_SPEED") + " x%s" % str(new_speed)
	speed_changed.emit(new_speed)


