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

# Typewriter effect
var _chars_per_second: float = 30.0
var _typewriter_active: bool = false
var _char_progress: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	hide()


func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_char_progress += _chars_per_second * delta
	var count := int(_char_progress)
	_text_label.visible_characters = count
	if count >= _text_label.text.length():
		_typewriter_active = false
		_text_label.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _typewriter_active:
		if event is InputEventMouseButton and event.pressed:
			_skip_typewriter()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_skip_typewriter()
			get_viewport().set_input_as_handled()


func _build_layout() -> void:
	layer = 100  # render above everything else

	# Semi-transparent backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.06, 0.9)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_text_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_text_label)

	_advance_btn = Button.new()
	_advance_btn.text = tr("UI_CONTINUE")
	_advance_btn.custom_minimum_size = Vector2(0, 56)
	_advance_btn.add_theme_font_size_override("font_size", 20)
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

## Show the text for the current index with typewriter effect.
func _display_current() -> void:
	if _index < _keys.size():
		_text_label.text = tr(_keys[_index] as String)
		_text_label.visible_characters = 0
		_char_progress = 0.0
		_typewriter_active = true


## Skip typewriter animation and show full text immediately.
func _skip_typewriter() -> void:
	_typewriter_active = false
	_text_label.visible_characters = -1


## Advance to the next line, or finish if all lines have been shown.
func _next() -> void:
	AudioManager.play_ui_click()
	_index += 1
	if _index >= _keys.size():
		hide()
		dialogue_finished.emit()
	else:
		_display_current()
