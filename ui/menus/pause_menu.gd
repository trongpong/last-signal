class_name PauseMenu
extends Control

## In-game pause overlay shown when the player pauses.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal resume_pressed
signal restart_pressed
signal quit_pressed

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	# Pause menus must remain interactive while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(240, 0)
	add_child(vbox)

	# Pause title
	var title := Label.new()
	title.text = tr("UI_PAUSE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Resume
	var resume_btn := Button.new()
	resume_btn.text = tr("UI_RESUME")
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	vbox.add_child(resume_btn)

	# Restart
	var restart_btn := Button.new()
	restart_btn.text = tr("UI_RESTART")
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	vbox.add_child(restart_btn)

	# Quit to main menu
	var quit_btn := Button.new()
	quit_btn.text = tr("UI_QUIT_LEVEL")
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	vbox.add_child(quit_btn)
