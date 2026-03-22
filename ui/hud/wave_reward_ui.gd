extends CanvasLayer

## 3-card reward selection overlay for roguelite endless mode.
## Shows during wave breaks every 5 waves. 8-second auto-pick timer.

signal card_chosen(index: int)
signal timer_expired

var _choices: Array = []
var _timer: float = Constants.WAVE_REWARD_TIMER
var _timer_bar: ColorRect = null
var _timer_bg: ColorRect = null
var _active: bool = true

func setup(choices: Array) -> void:
	_choices = choices
	_timer = Constants.WAVE_REWARD_TIMER
	_active = true
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer_bar != null and _timer_bg != null:
		var fraction: float = clampf(_timer / Constants.WAVE_REWARD_TIMER, 0.0, 1.0)
		_timer_bar.size.x = _timer_bg.size.x * fraction
	if _timer <= 0.0:
		_active = false
		timer_expired.emit()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	root.add_child(overlay)

	# Center container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300.0
	vbox.offset_right = 300.0
	vbox.offset_top = -200.0
	vbox.offset_bottom = 200.0
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SIGNAL INTERCEPTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a buff"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	# Timer bar
	_timer_bg = ColorRect.new()
	_timer_bg.custom_minimum_size = Vector2(500, 6)
	_timer_bg.color = Color(0.3, 0.3, 0.3, 0.8)
	vbox.add_child(_timer_bg)

	_timer_bar = ColorRect.new()
	_timer_bar.custom_minimum_size = Vector2(500, 6)
	_timer_bar.size = Vector2(500, 6)
	_timer_bar.color = Color(1.0, 0.85, 0.0, 0.9)
	_timer_bar.position = Vector2.ZERO
	_timer_bg.add_child(_timer_bar)

	# Card row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for i in range(_choices.size()):
		var card := _build_card(_choices[i], i)
		hbox.add_child(card)

func _build_card(reward: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 180)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.95)
	style.border_color = reward.get("icon_color", Color.WHITE) as Color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = reward.get("display_name", "???") as String
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", reward.get("icon_color", Color.WHITE) as Color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = reward.get("description", "") as String
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var btn := Button.new()
	btn.text = "Choose"
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void:
		if _active:
			_active = false
			card_chosen.emit(index)
	)
	vbox.add_child(btn)

	return panel
