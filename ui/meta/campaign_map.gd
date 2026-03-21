class_name CampaignMap
extends Control

## Campaign map screen showing a scrollable grid/list of level nodes
## plus a difficulty selector and a back button.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal level_chosen(level_id: String, difficulty: int)
signal back_pressed

# ---------------------------------------------------------------------------
# Difficulty options — must match Enums.Difficulty order
# ---------------------------------------------------------------------------

const _DIFFICULTY_KEYS: Array = [
	"DIFFICULTY_NORMAL",
	"DIFFICULTY_HARD",
	"DIFFICULTY_NIGHTMARE",
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _levels_container: GridContainer
var _difficulty_option: OptionButton
var _selected_level_id: String = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = tr("UI_LEVEL_SELECT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Difficulty row
	var diff_row := HBoxContainer.new()
	vbox.add_child(diff_row)

	var diff_lbl := Label.new()
	diff_lbl.text = tr("UI_REGION") + ": "
	diff_row.add_child(diff_lbl)

	_difficulty_option = OptionButton.new()
	for key in _DIFFICULTY_KEYS:
		_difficulty_option.add_item(tr(key))
	_difficulty_option.selected = 0
	diff_row.add_child(_difficulty_option)

	# Scrollable level grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_levels_container = GridContainer.new()
	_levels_container.columns = 4
	scroll.add_child(_levels_container)

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	vbox.add_child(back_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Populate level nodes.
## levels: Array of Dictionaries { "id": String, "display_name": String }
## save_data: SaveManager.data["campaign"] dictionary
func populate(levels: Array, save_data: Dictionary) -> void:
	for child in _levels_container.get_children():
		child.queue_free()

	var completed: Dictionary = save_data.get("levels_completed", {})

	var prev_completed: bool = true  # first level is always unlocked
	for level_def in levels:
		var id: String = level_def.get("id", "") as String
		var display: String = level_def.get("display_name", id) as String
		var record: Dictionary = completed.get(id, {}) as Dictionary
		var stars: int = record.get("best_stars", 0) as int
		var locked: bool = not prev_completed

		var node := LevelNode.new()
		node.setup(id, display, stars, locked)
		node.level_selected.connect(_on_level_selected)
		_levels_container.add_child(node)

		prev_completed = record.get("completed", false) as bool

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_level_selected(level_id: String) -> void:
	_selected_level_id = level_id
	var difficulty: int = _difficulty_option.selected  # matches Enums.Difficulty order
	level_chosen.emit(level_id, difficulty)
