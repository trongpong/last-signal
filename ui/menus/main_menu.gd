class_name MainMenu
extends Control

## Main menu screen with campaign, endless, tower lab, and settings buttons.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal play_campaign
signal play_endless
signal open_daily_challenge
signal open_tower_lab
signal open_diamond_shop
signal open_settings

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _endless_btn: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent dark background behind entire menu
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Title label with gold color and shadow
	var title := Label.new()
	title.text = "Last Signal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	var title_settings := LabelSettings.new()
	title_settings.font_size = 44
	title_settings.font_color = Color(0.9, 0.8, 0.2)
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	title_settings.shadow_offset = Vector2(2, 2)
	title_settings.shadow_size = 3
	title.label_settings = title_settings
	vbox.add_child(title)

	# Campaign button — gold tint
	var campaign_btn := Button.new()
	campaign_btn.text = tr("UI_PLAY_CAMPAIGN")
	campaign_btn.focus_mode = Control.FOCUS_ALL
	campaign_btn.custom_minimum_size = Vector2(280, 56)
	campaign_btn.add_theme_font_size_override("font_size", 20)
	campaign_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	campaign_btn.pressed.connect(func() -> void: play_campaign.emit())
	vbox.add_child(campaign_btn)

	# Endless mode button — orange tint
	_endless_btn = Button.new()
	_endless_btn.text = tr("UI_ENDLESS_MODE")
	_endless_btn.focus_mode = Control.FOCUS_ALL
	_endless_btn.custom_minimum_size = Vector2(280, 56)
	_endless_btn.add_theme_font_size_override("font_size", 20)
	_endless_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	_endless_btn.pressed.connect(func() -> void: play_endless.emit())
	_endless_btn.disabled = true  # locked until set_endless_unlocked(true)
	vbox.add_child(_endless_btn)

	# Daily challenge button — green tint
	var daily_btn := Button.new()
	daily_btn.text = tr("UI_DAILY_CHALLENGE")
	daily_btn.focus_mode = Control.FOCUS_ALL
	daily_btn.custom_minimum_size = Vector2(280, 56)
	daily_btn.add_theme_font_size_override("font_size", 20)
	daily_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	daily_btn.pressed.connect(func() -> void: open_daily_challenge.emit())
	vbox.add_child(daily_btn)

	# Tower lab button — cyan tint
	var lab_btn := Button.new()
	lab_btn.text = tr("UI_TOWER_LAB")
	lab_btn.focus_mode = Control.FOCUS_ALL
	lab_btn.custom_minimum_size = Vector2(280, 56)
	lab_btn.add_theme_font_size_override("font_size", 20)
	lab_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	lab_btn.pressed.connect(func() -> void: open_tower_lab.emit())
	vbox.add_child(lab_btn)

	# Diamond shop button — cyan tint
	var shop_btn := Button.new()
	shop_btn.text = tr("UI_DIAMOND_SHOP")
	shop_btn.focus_mode = Control.FOCUS_ALL
	shop_btn.custom_minimum_size = Vector2(280, 56)
	shop_btn.add_theme_font_size_override("font_size", 20)
	shop_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	shop_btn.pressed.connect(func() -> void: open_diamond_shop.emit())
	vbox.add_child(shop_btn)

	# Settings button — gray tint
	var settings_btn := Button.new()
	settings_btn.text = tr("UI_SETTINGS")
	settings_btn.focus_mode = Control.FOCUS_ALL
	settings_btn.custom_minimum_size = Vector2(280, 56)
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	settings_btn.pressed.connect(func() -> void: open_settings.emit())
	vbox.add_child(settings_btn)

	# Focus neighbors for arrow key navigation
	var buttons: Array[Button] = [campaign_btn, _endless_btn, lab_btn, shop_btn, settings_btn]
	for i in buttons.size():
		var prev_path := buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		var next_path := buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = prev_path
		buttons[i].focus_neighbor_bottom = next_path

	# Grab initial focus
	campaign_btn.grab_focus()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Unlock or lock the endless mode button.
func set_endless_unlocked(unlocked: bool) -> void:
	if _endless_btn != null:
		_endless_btn.disabled = not unlocked
