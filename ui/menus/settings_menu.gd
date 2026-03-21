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
	["id", "Bahasa Indonesia"],
	["zh", "中文"],
	["ja", "日本語"],
	["ko", "한국어"],
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _music_slider: HSlider
var _sfx_slider: HSlider
var _language_option: OptionButton
var _damage_numbers_check: CheckButton
var _range_on_hover_check: CheckButton

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	_load_settings()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(360, 0)
	add_child(vbox)

	# Music volume
	var music_lbl := Label.new()
	music_lbl.text = tr("SETTINGS_MUSIC_VOLUME")
	vbox.add_child(music_lbl)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.value = 1.0
	_music_slider.value_changed.connect(_on_music_changed)
	vbox.add_child(_music_slider)

	# SFX volume
	var sfx_lbl := Label.new()
	sfx_lbl.text = tr("SETTINGS_SFX_VOLUME")
	vbox.add_child(sfx_lbl)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.value = 1.0
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	vbox.add_child(_sfx_slider)

	# Language dropdown
	var lang_lbl := Label.new()
	lang_lbl.text = tr("SETTINGS_LANGUAGE")
	vbox.add_child(lang_lbl)

	_language_option = OptionButton.new()
	for pair in _LANGUAGES:
		_language_option.add_item(pair[1] as String)
	_language_option.item_selected.connect(_on_language_selected)
	vbox.add_child(_language_option)

	# Damage numbers toggle
	var dmg_lbl := Label.new()
	dmg_lbl.text = tr("SETTINGS_DAMAGE_NUMBERS")
	vbox.add_child(dmg_lbl)

	_damage_numbers_check = CheckButton.new()
	_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	vbox.add_child(_damage_numbers_check)

	# Range on hover toggle
	var range_lbl := Label.new()
	range_lbl.text = tr("SETTINGS_RANGE_ON_HOVER")
	vbox.add_child(range_lbl)

	_range_on_hover_check = CheckButton.new()
	_range_on_hover_check.toggled.connect(_on_range_on_hover_toggled)
	vbox.add_child(_range_on_hover_check)

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

# ---------------------------------------------------------------------------
# Settings persistence
# ---------------------------------------------------------------------------

## Read settings from SaveManager and populate the UI.
func _load_settings() -> void:
	if not Engine.has_singleton("SaveManager"):
		return
	var sm = Engine.get_singleton("SaveManager")
	if sm == null:
		return
	var settings: Dictionary = sm.data.get("profile", {}).get("settings", {})
	var language: String = sm.data.get("profile", {}).get("language", "en")

	_music_slider.set_value_no_signal(settings.get("music_vol", 1.0) as float)
	_sfx_slider.set_value_no_signal(settings.get("sfx_vol", 1.0) as float)
	_damage_numbers_check.set_pressed_no_signal(settings.get("show_damage_numbers", true) as bool)
	_range_on_hover_check.set_pressed_no_signal(settings.get("show_range_on_hover", true) as bool)

	# Select the matching language entry
	for i in _LANGUAGES.size():
		if (_LANGUAGES[i] as Array)[0] == language:
			_language_option.select(i)
			break


## Write current UI values back to SaveManager and persist.
func _save_settings() -> void:
	if not Engine.has_singleton("SaveManager"):
		return
	var sm = Engine.get_singleton("SaveManager")
	if sm == null:
		return
	var settings: Dictionary = sm.data["profile"]["settings"]
	settings["music_vol"] = _music_slider.value
	settings["sfx_vol"] = _sfx_slider.value
	settings["show_damage_numbers"] = _damage_numbers_check.button_pressed
	settings["show_range_on_hover"] = _range_on_hover_check.button_pressed
	sm.save_game()

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_music_changed(_value: float) -> void:
	_save_settings()


func _on_sfx_changed(_value: float) -> void:
	_save_settings()


func _on_damage_numbers_toggled(_on: bool) -> void:
	_save_settings()


func _on_range_on_hover_toggled(_on: bool) -> void:
	_save_settings()


func _on_language_selected(index: int) -> void:
	var locale: String = (_LANGUAGES[index] as Array)[0] as String
	TranslationServer.set_locale(locale)

	if Engine.has_singleton("SaveManager"):
		var sm = Engine.get_singleton("SaveManager")
		if sm != null:
			sm.data["profile"]["language"] = locale
			sm.save_game()


func _on_back_pressed() -> void:
	back_pressed.emit()
