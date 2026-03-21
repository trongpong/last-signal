class_name LevelComplete
extends Control

## End-of-level screen showing star rating, diamonds earned, and action buttons.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal continue_pressed
signal restart_pressed

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _stars_label: Label
var _diamonds_label: Label

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	# Keep interactive even when tree is paused during victory state
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(300, 0)
	add_child(vbox)

	# Victory title
	var title := Label.new()
	title.text = tr("UI_VICTORY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Stars display
	_stars_label = Label.new()
	_stars_label.text = tr("UI_STARS") + ": -"
	_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stars_label)

	# Diamonds earned
	_diamonds_label = Label.new()
	_diamonds_label.text = tr("UI_DIAMONDS") + ": 0"
	_diamonds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_diamonds_label)

	# Continue (go to next level or back to map)
	var continue_btn := Button.new()
	continue_btn.text = tr("UI_CONTINUE")
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	vbox.add_child(continue_btn)

	# Restart
	var restart_btn := Button.new()
	restart_btn.text = tr("UI_RESTART")
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	vbox.add_child(restart_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Populate the results display.
## stars: 1–3
## diamonds: diamonds awarded for this run
func show_results(stars: int, diamonds: int) -> void:
	var star_str: String = "★".repeat(stars) + "☆".repeat(3 - stars)
	_stars_label.text = tr("UI_STARS") + ": " + star_str
	_diamonds_label.text = tr("UI_DIAMONDS") + ": +" + str(diamonds)
	show()
