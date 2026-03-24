class_name PauseMenu
extends Control

## In-game pause overlay shown when the player pauses.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal settings_requested

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _wave_label: Label
var _gold_label: Label
var _kills_label: Label
var _quit_confirm_panel: PanelContainer

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	# Pause menus must remain interactive while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Start hidden; will be shown via show_animated()
	hide()


## Show with a fade-in animation.
func show_animated() -> void:
	# Make sure quit confirmation is hidden when the menu opens
	_quit_confirm_panel.hide()
	modulate.a = 0.0
	show()
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _quit_confirm_panel.visible:
			_quit_confirm_panel.hide()
		else:
			resume_pressed.emit()
		get_viewport().set_input_as_handled()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent dark backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(280, 0)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Pause title — gold color
	var title := Label.new()
	title.text = tr("UI_PAUSE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	vbox.add_child(title)

	# -----------------------------------------------------------------------
	# Stats section
	# -----------------------------------------------------------------------
	var stats_header := Label.new()
	stats_header.text = tr("HUD_LEVEL_STATS")
	stats_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_header.add_theme_font_size_override("font_size", 16)
	stats_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(stats_header)

	var stats_panel := PanelContainer.new()
	vbox.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_panel.add_child(stats_vbox)

	_wave_label = Label.new()
	_wave_label.text = tr("UI_WAVE") + ": -"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 16)
	_wave_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	stats_vbox.add_child(_wave_label)

	_gold_label = Label.new()
	_gold_label.text = tr("UI_GOLD_EARNED") + ": 0"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	stats_vbox.add_child(_gold_label)

	_kills_label = Label.new()
	_kills_label.text = tr("UI_ENEMIES_KILLED") + ": 0"
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kills_label.add_theme_font_size_override("font_size", 16)
	_kills_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	stats_vbox.add_child(_kills_label)

	# -----------------------------------------------------------------------
	# Buttons
	# -----------------------------------------------------------------------

	# Resume
	var resume_btn := Button.new()
	resume_btn.text = tr("UI_RESUME")
	resume_btn.focus_mode = Control.FOCUS_ALL
	resume_btn.custom_minimum_size = Vector2(260, 56)
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	resume_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	vbox.add_child(resume_btn)

	# Settings
	var settings_btn := Button.new()
	settings_btn.text = tr("UI_SETTINGS")
	settings_btn.focus_mode = Control.FOCUS_ALL
	settings_btn.custom_minimum_size = Vector2(260, 56)
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	settings_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
	settings_btn.pressed.connect(func() -> void: settings_requested.emit())
	vbox.add_child(settings_btn)

	# Restart
	var restart_btn := Button.new()
	restart_btn.text = tr("UI_RESTART")
	restart_btn.focus_mode = Control.FOCUS_ALL
	restart_btn.custom_minimum_size = Vector2(260, 56)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	restart_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.4))
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	vbox.add_child(restart_btn)

	# Quit to main menu (shows confirmation first)
	var quit_btn := Button.new()
	quit_btn.text = tr("UI_QUIT_LEVEL")
	quit_btn.focus_mode = Control.FOCUS_ALL
	quit_btn.custom_minimum_size = Vector2(260, 56)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	quit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	quit_btn.pressed.connect(func() -> void: _quit_confirm_panel.show(); _quit_confirm_panel.get_node("VBox/ConfirmBtn").grab_focus())
	vbox.add_child(quit_btn)

	# -----------------------------------------------------------------------
	# Quit confirmation panel
	# -----------------------------------------------------------------------
	_quit_confirm_panel = PanelContainer.new()
	_quit_confirm_panel.hide()
	vbox.add_child(_quit_confirm_panel)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.name = "VBox"
	_quit_confirm_panel.add_child(confirm_vbox)

	var confirm_label := Label.new()
	confirm_label.text = tr("UI_CONFIRM_QUIT")
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_vbox.add_child(confirm_label)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmBtn"
	confirm_btn.text = tr("UI_YES")
	confirm_btn.focus_mode = Control.FOCUS_ALL
	confirm_btn.custom_minimum_size = Vector2(260, 56)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.pressed.connect(func() -> void: quit_pressed.emit())
	confirm_vbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = tr("UI_NO")
	cancel_btn.focus_mode = Control.FOCUS_ALL
	cancel_btn.custom_minimum_size = Vector2(260, 56)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.pressed.connect(func() -> void: _quit_confirm_panel.hide(); quit_btn.grab_focus())
	confirm_vbox.add_child(cancel_btn)

	# Focus neighbors for arrow key navigation (main buttons)
	var buttons: Array[Button] = [resume_btn, settings_btn, restart_btn, quit_btn]
	for i in buttons.size():
		var prev_path := buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		var next_path := buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = prev_path
		buttons[i].focus_neighbor_bottom = next_path

	# Focus neighbors for confirmation buttons
	confirm_btn.focus_neighbor_bottom = cancel_btn.get_path()
	cancel_btn.focus_neighbor_top = confirm_btn.get_path()
	confirm_btn.focus_neighbor_top = cancel_btn.get_path()
	cancel_btn.focus_neighbor_bottom = confirm_btn.get_path()

	# Grab initial focus
	resume_btn.grab_focus()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Update the stats display in the pause menu.
func update_stats(wave: int, gold: int, kills: int) -> void:
	_wave_label.text = tr("UI_WAVE") + ": " + str(wave)
	_gold_label.text = tr("UI_GOLD_EARNED") + ": " + str(gold)
	_kills_label.text = tr("UI_ENEMIES_KILLED") + ": " + str(kills)
