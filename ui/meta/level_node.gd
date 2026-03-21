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
		text = tr("UI_LOCKED") + "\n" + display_name
		disabled = true
		tooltip_text = tr("UI_LOCKED")
	else:
		var star_str: String = "★".repeat(stars) + "☆".repeat(3 - stars)
		text = display_name + "\n" + star_str
		disabled = false
		tooltip_text = display_name

	pressed.connect(_on_pressed)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	level_selected.emit(_level_id)
