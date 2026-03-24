class_name LevelFailed
extends Control

## Defeat screen shown when the player loses all lives.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal retry_pressed
signal quit_pressed

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _title_label: Label
var _message_label: Label
var _retry_button: Button
var _quit_button: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	# Keep interactive even when tree is paused during defeat state
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start hidden; will be shown via show_results()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		quit_pressed.emit()
		get_viewport().set_input_as_handled()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent reddish backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.15, 0.02, 0.02, 0.8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(300, 0)
	add_child(vbox)

	# Defeat title — red color
	_title_label = Label.new()
	_title_label.text = tr("UI_DEFEAT")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	vbox.add_child(_title_label)

	# Wave reached message
	_message_label = Label.new()
	_message_label.text = ""
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_message_label)

	# Retry — gold font (encourage retry)
	_retry_button = Button.new()
	_retry_button.text = tr("UI_RESTART")
	_retry_button.focus_mode = Control.FOCUS_ALL
	_retry_button.custom_minimum_size = Vector2(260, 56)
	_retry_button.add_theme_font_size_override("font_size", 20)
	_retry_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_retry_button.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		retry_pressed.emit()
	)
	vbox.add_child(_retry_button)

	# Quit to main menu — gray font
	_quit_button = Button.new()
	_quit_button.text = tr("UI_MAIN_MENU")
	_quit_button.focus_mode = Control.FOCUS_ALL
	_quit_button.custom_minimum_size = Vector2(260, 56)
	_quit_button.add_theme_font_size_override("font_size", 20)
	_quit_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_quit_button.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		quit_pressed.emit()
	)
	vbox.add_child(_quit_button)

	# Focus neighbors for arrow key navigation
	var buttons: Array[Button] = [_retry_button, _quit_button]
	for i in buttons.size():
		var prev_path := buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		var next_path := buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = prev_path
		buttons[i].focus_neighbor_bottom = next_path

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Populate the defeat screen and show it with a fade-in animation.
## wave_reached: the wave number the player reached before losing.
func show_results(wave_reached: int) -> void:
	_message_label.text = tr("UI_WAVE_REACHED") + ": " + str(wave_reached)
	# Fade-in animation
	modulate.a = 0.0
	show()
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	# Grab initial focus on the retry button
	_retry_button.grab_focus()
