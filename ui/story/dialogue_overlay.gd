class_name DialogueOverlay
extends CanvasLayer

## Fullscreen dialogue overlay that displays story text one line at a time.
## Call show_dialogue(keys) with an array of translation keys to start.
## Emits dialogue_finished when all lines have been acknowledged.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal dialogue_finished

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _keys: Array = []
var _index: int = 0
var _text_label: Label
var _advance_btn: Button
var _backdrop: ColorRect

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	hide()


func _build_layout() -> void:
	layer = 100  # render above everything else

	# Semi-transparent backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.1, 0.85)
	add_child(_backdrop)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.custom_minimum_size = Vector2(800, 0)
	vbox.offset_top = -200.0
	add_child(vbox)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_text_label)

	_advance_btn = Button.new()
	_advance_btn.text = tr("UI_CONTINUE")
	_advance_btn.pressed.connect(_next)
	vbox.add_child(_advance_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start showing dialogue from the provided array of translation keys.
## Each call resets to the beginning of the sequence.
func show_dialogue(dialogue_keys: Array) -> void:
	_keys = dialogue_keys.duplicate()
	_index = 0
	if _keys.is_empty():
		dialogue_finished.emit()
		return
	_display_current()
	show()

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Show the text for the current index.
func _display_current() -> void:
	if _index < _keys.size():
		_text_label.text = tr(_keys[_index] as String)

## Advance to the next line, or finish if all lines have been shown.
func _next() -> void:
	_index += 1
	if _index >= _keys.size():
		hide()
		dialogue_finished.emit()
	else:
		_display_current()
