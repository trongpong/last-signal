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

	# Dark backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(300, 0)
	add_child(vbox)

	# Victory title — gold color
	var title := Label.new()
	title.text = tr("UI_VICTORY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(title)

	# Stars display — larger font for star symbols
	_stars_label = Label.new()
	_stars_label.text = tr("UI_STARS") + ": -"
	_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_stars_label)

	# Diamonds earned — cyan color with diamond symbol
	_diamonds_label = Label.new()
	_diamonds_label.text = tr("UI_DIAMONDS") + ": 0"
	_diamonds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diamonds_label.add_theme_font_size_override("font_size", 18)
	_diamonds_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(_diamonds_label)

	# Continue (go to next level or back to map) — gold font (primary action)
	var continue_btn := Button.new()
	continue_btn.text = tr("UI_CONTINUE")
	continue_btn.custom_minimum_size = Vector2(260, 56)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	vbox.add_child(continue_btn)

	# Restart — gray font (secondary action)
	var restart_btn := Button.new()
	restart_btn.text = tr("UI_RESTART")
	restart_btn.custom_minimum_size = Vector2(260, 56)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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
	# Color stars gold (earned stars dominate the visual)
	_stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_diamonds_label.text = "◆ " + tr("UI_DIAMONDS") + ": +" + str(diamonds)
	# Fade-in animation
	modulate.a = 0.0
	show()
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
