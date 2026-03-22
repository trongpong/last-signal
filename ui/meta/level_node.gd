class_name LevelNode
extends Button

## A clickable node on the campaign map representing one level.
## Shows stars earned and a lock icon when the level is not yet available.

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

signal level_selected(level_id: String)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _level_id: String = ""

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Configure the node's display.
## id:           level identifier string (e.g. "region_01_01")
## display_name: human-readable level name
## stars:        0–3 stars earned so far
## locked:       when true, disable the button and show a lock indicator
func setup(id: String, display_name: String, stars: int, locked: bool) -> void:
	_level_id = id

	if locked:
		text = display_name
		disabled = true
		tooltip_text = tr("UI_LOCKED")
		# Dim locked style
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.02, 0.02)
		style.border_color = Color(0.4, 0.1, 0.1, 0.5)
		style.set_border_width_all(1)
		style.set_content_margin_all(4)
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("disabled", style)
		add_theme_color_override("font_disabled_color", Color(0.35, 0.25, 0.25))
	else:
		var star_str: String = "★".repeat(stars) + "☆".repeat(3 - stars)
		text = display_name + "\n" + star_str
		disabled = false
		tooltip_text = display_name

		if stars > 0:
			# Completed: gold tint
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.12, 0.0)
			style.border_color = Color(0.8, 0.7, 0.0, 0.5)
			style.set_border_width_all(1)
			style.set_content_margin_all(4)
			add_theme_stylebox_override("normal", style)
			add_theme_stylebox_override("hover", style)
			add_theme_stylebox_override("pressed", style)
			add_theme_stylebox_override("focus", style)
			# Gold star text color
			add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))
		else:
			# Unlocked but unplayed: blue tint
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.05, 0.15)
			style.border_color = Color(0.3, 0.5, 0.8, 0.5)
			style.set_border_width_all(1)
			style.set_content_margin_all(4)
			add_theme_stylebox_override("normal", style)
			add_theme_stylebox_override("hover", style)
			add_theme_stylebox_override("pressed", style)
			add_theme_stylebox_override("focus", style)
			# Empty stars in gray
			add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
			add_theme_color_override("font_hover_color", Color(0.5, 0.6, 0.8))

	pressed.connect(_on_pressed)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	level_selected.emit(_level_id)
