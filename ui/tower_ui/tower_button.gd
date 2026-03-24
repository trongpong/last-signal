class_name TowerButton
extends Button

## A button representing a single tower type in the build bar.
## Displays tower name and cost; dims when the player cannot afford it.

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

signal tower_selected(tower_type: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _tower_type: int = -1
var _cost: int = 0
var _selected: bool = false:
	set = set_selected
var _default_stylebox: StyleBox = null
var _cost_label: Label = null

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Populate this button from a TowerDefinition resource.
func setup(def: TowerDefinition) -> void:
	_tower_type = def.tower_type as int
	_cost = def.cost
	# Clear default text — we use a VBox with separate labels instead
	text = ""
	# Touch-friendly minimum size
	custom_minimum_size = Vector2(90, 64)
	# Card-style default background
	var default_sb := StyleBoxFlat.new()
	default_sb.bg_color = Color(0.06, 0.06, 0.1, 0.8)
	default_sb.border_color = Color(0.2, 0.3, 0.4, 0.5)
	default_sb.set_border_width_all(1)
	default_sb.set_corner_radius_all(4)
	default_sb.set_content_margin_all(6)
	add_theme_stylebox_override("normal", default_sb)
	_default_stylebox = default_sb
	# Hover style
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.1, 0.1, 0.18, 0.9)
	hover_sb.border_color = Color(0.4, 0.5, 0.6, 0.6)
	hover_sb.set_border_width_all(1)
	hover_sb.set_corner_radius_all(4)
	hover_sb.set_content_margin_all(6)
	add_theme_stylebox_override("hover", hover_sb)
	# VBox layout: tower name on top, cost below
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6.0
	vbox.offset_right = -6.0
	vbox.offset_top = 6.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	# Tower name
	var name_key: String = "TOWER_" + def.id.to_upper()
	var name_lbl := Label.new()
	name_lbl.text = tr(name_key)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	# Cost
	_cost_label = Label.new()
	_cost_label.text = str(def.cost)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_cost_label)
	pressed.connect(_on_pressed)


## Update the displayed cost (e.g. after applying global discount).
func set_display_cost(display_cost: int) -> void:
	_cost = display_cost
	if _cost_label != null:
		_cost_label.text = str(display_cost)


## Grey out the button when the player cannot afford this tower.
func update_affordability(gold: int) -> void:
	var can_afford := gold >= _cost
	disabled = not can_afford
	modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5, 1.0)


## Set the selected state, toggling a gold border highlight.
func set_selected(val: bool) -> void:
	_selected = val
	if _selected:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		sb.border_color = Color(1.0, 0.85, 0.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(4)
		add_theme_stylebox_override("normal", sb)
	else:
		if _default_stylebox:
			add_theme_stylebox_override("normal", _default_stylebox)
		else:
			remove_theme_stylebox_override("normal")

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	AudioManager.play_ui_click()
	# Touch feedback: brief scale tween
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	tower_selected.emit(_tower_type)
