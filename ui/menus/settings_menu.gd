class_name SettingsMenu
extends Control

## Settings screen: audio sliders, language selector, toggle options, back button.
## Reads from SaveManager on open, writes back on every change.

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

signal back_pressed

# ---------------------------------------------------------------------------
# Supported languages: [locale_code, display_name]
# ---------------------------------------------------------------------------

const _LANGUAGES: Array = [
	["en", "English"],
	["vi", "Tiếng Việt"],
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _music_slider: HSlider
var _sfx_slider: HSlider
var _language_option: OptionButton
var _damage_numbers_check: CheckButton
var _range_on_hover_check: CheckButton
var _fullscreen_check: CheckButton
var _colorblind_check: CheckButton

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	_load_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _get_safe_margin() -> float:
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	var left: float = safe_area.position.x
	var right: float = maxf(screen_size.x - safe_area.end.x, 0.0)
	return clampf(maxf(left, right), 16.0, 48.0)


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: float = _get_safe_margin()

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Fixed header with title and back button
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.anchor_bottom = 0.0
	header.offset_top = 8.0
	header.offset_bottom = 52.0
	header.offset_left = safe
	header.offset_right = -safe
	header.add_theme_constant_override("separation", 12)
	add_child(header)

	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.focus_mode = Control.FOCUS_ALL
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var title := Label.new()
	title.text = tr("UI_SETTINGS")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	header.add_child(title)

	# Spacer to balance the back button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	header.add_child(spacer)

	# Scrollable content area below the header
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 56.0
	scroll.offset_left = safe
	scroll.offset_right = -safe
	add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(scroll_margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll_margin.add_child(vbox)

	# --- Audio section ---
	var audio_header := Label.new()
	audio_header.text = tr("SETTINGS_AUDIO")
	audio_header.add_theme_font_size_override("font_size", 16)
	audio_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(audio_header)

	# Music volume
	var music_lbl := Label.new()
	music_lbl.text = tr("SETTINGS_MUSIC_VOLUME")
	music_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(music_lbl)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.value = 1.0
	_music_slider.focus_mode = Control.FOCUS_ALL
	_music_slider.custom_minimum_size.y = 48
	_music_slider.value_changed.connect(_on_music_changed)
	vbox.add_child(_music_slider)

	# SFX volume
	var sfx_lbl := Label.new()
	sfx_lbl.text = tr("SETTINGS_SFX_VOLUME")
	sfx_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sfx_lbl)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.value = 1.0
	_sfx_slider.focus_mode = Control.FOCUS_ALL
	_sfx_slider.custom_minimum_size.y = 48
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	vbox.add_child(_sfx_slider)

	vbox.add_child(HSeparator.new())

	# --- Gameplay section ---
	var gameplay_header := Label.new()
	gameplay_header.text = tr("SETTINGS_GAMEPLAY")
	gameplay_header.add_theme_font_size_override("font_size", 16)
	gameplay_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(gameplay_header)

	# Damage numbers toggle
	var dmg_lbl := Label.new()
	dmg_lbl.text = tr("SETTINGS_DAMAGE_NUMBERS")
	dmg_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(dmg_lbl)

	_damage_numbers_check = CheckButton.new()
	_damage_numbers_check.focus_mode = Control.FOCUS_ALL
	_damage_numbers_check.custom_minimum_size.y = 48
	_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	vbox.add_child(_damage_numbers_check)

	# Range on hover toggle
	var range_lbl := Label.new()
	range_lbl.text = tr("SETTINGS_RANGE_ON_HOVER")
	range_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(range_lbl)

	_range_on_hover_check = CheckButton.new()
	_range_on_hover_check.focus_mode = Control.FOCUS_ALL
	_range_on_hover_check.custom_minimum_size.y = 48
	_range_on_hover_check.toggled.connect(_on_range_on_hover_toggled)
	vbox.add_child(_range_on_hover_check)

	vbox.add_child(HSeparator.new())

	# --- Display section ---
	var display_header := Label.new()
	display_header.text = tr("SETTINGS_DISPLAY")
	display_header.add_theme_font_size_override("font_size", 16)
	display_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(display_header)

	# Fullscreen toggle
	var fs_lbl := Label.new()
	fs_lbl.text = tr("SETTINGS_FULLSCREEN")
	fs_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(fs_lbl)

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.focus_mode = Control.FOCUS_ALL
	_fullscreen_check.custom_minimum_size.y = 48
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(_fullscreen_check)

	# Colorblind mode toggle
	var cb_lbl := Label.new()
	cb_lbl.text = tr("SETTINGS_COLORBLIND")
	cb_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(cb_lbl)

	_colorblind_check = CheckButton.new()
	_colorblind_check.focus_mode = Control.FOCUS_ALL
	_colorblind_check.custom_minimum_size.y = 48
	_colorblind_check.toggled.connect(_on_colorblind_toggled)
	vbox.add_child(_colorblind_check)

	vbox.add_child(HSeparator.new())

	# --- Language section ---
	var lang_header := Label.new()
	lang_header.text = tr("SETTINGS_LANGUAGE_SECTION")
	lang_header.add_theme_font_size_override("font_size", 16)
	lang_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(lang_header)

	var lang_lbl := Label.new()
	lang_lbl.text = tr("SETTINGS_LANGUAGE")
	lang_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lang_lbl)

	_language_option = OptionButton.new()
	_language_option.focus_mode = Control.FOCUS_ALL
	_language_option.custom_minimum_size.y = 48
	for pair in _LANGUAGES:
		_language_option.add_item(pair[1] as String)
	_language_option.item_selected.connect(_on_language_selected)
	vbox.add_child(_language_option)

	# Focus neighbors for arrow key navigation
	var controls: Array[Control] = [
		_music_slider, _sfx_slider,
		_damage_numbers_check, _range_on_hover_check,
		_fullscreen_check, _colorblind_check, _language_option
	]
	for i in controls.size():
		var prev_path := controls[(i - 1 + controls.size()) % controls.size()].get_path()
		var next_path := controls[(i + 1) % controls.size()].get_path()
		controls[i].focus_neighbor_top = prev_path
		controls[i].focus_neighbor_bottom = next_path

	# Grab initial focus
	_music_slider.grab_focus()

# ---------------------------------------------------------------------------
# Settings persistence
# ---------------------------------------------------------------------------

## Read settings from SaveManager and populate the UI.
func _load_settings() -> void:
	var settings: Dictionary = SaveManager.data.get("profile", {}).get("settings", {})
	var language: String = SaveManager.data.get("profile", {}).get("language", "en")

	_music_slider.set_value_no_signal(settings.get("music_vol", 1.0) as float)
	_sfx_slider.set_value_no_signal(settings.get("sfx_vol", 1.0) as float)
	_damage_numbers_check.set_pressed_no_signal(settings.get("show_damage_numbers", true) as bool)
	_range_on_hover_check.set_pressed_no_signal(settings.get("show_range_on_hover", true) as bool)
	_colorblind_check.set_pressed_no_signal(settings.get("colorblind_mode", false) as bool)

	# Select the matching language entry
	for i in _LANGUAGES.size():
		if (_LANGUAGES[i] as Array)[0] == language:
			_language_option.select(i)
			break


## Write current UI values back to SaveManager and persist.
func _save_settings() -> void:
	var settings: Dictionary = SaveManager.data["profile"]["settings"]
	settings["music_vol"] = _music_slider.value
	settings["sfx_vol"] = _sfx_slider.value
	settings["show_damage_numbers"] = _damage_numbers_check.button_pressed
	settings["show_range_on_hover"] = _range_on_hover_check.button_pressed
	settings["colorblind_mode"] = _colorblind_check.button_pressed
	SaveManager.save_game()

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_save_settings()


func _on_damage_numbers_toggled(_on: bool) -> void:
	_save_settings()


func _on_range_on_hover_toggled(_on: bool) -> void:
	_save_settings()


func _on_fullscreen_toggled(toggled: bool) -> void:
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_colorblind_toggled(_on: bool) -> void:
	_save_settings()


func _on_language_selected(index: int) -> void:
	var locale: String = (_LANGUAGES[index] as Array)[0] as String
	TranslationServer.set_locale(locale)

	SaveManager.data["profile"]["language"] = locale
	SaveManager.save_game()


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	back_pressed.emit()
