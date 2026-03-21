class_name MainMenu
extends Control

## Main menu screen with campaign, endless, tower lab, and settings buttons.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal play_campaign
signal play_endless
signal open_tower_lab
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

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(300, 0)
	add_child(vbox)

	# Title label
	var title := Label.new()
	title.text = "Last Signal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Campaign button
	var campaign_btn := Button.new()
	campaign_btn.text = tr("UI_PLAY_CAMPAIGN")
	campaign_btn.pressed.connect(func() -> void: play_campaign.emit())
	vbox.add_child(campaign_btn)

	# Endless mode button
	_endless_btn = Button.new()
	_endless_btn.text = tr("UI_ENDLESS_MODE")
	_endless_btn.pressed.connect(func() -> void: play_endless.emit())
	_endless_btn.disabled = true  # locked until set_endless_unlocked(true)
	vbox.add_child(_endless_btn)

	# Tower lab button
	var lab_btn := Button.new()
	lab_btn.text = tr("UI_TOWER_LAB")
	lab_btn.pressed.connect(func() -> void: open_tower_lab.emit())
	vbox.add_child(lab_btn)

	# Settings button
	var settings_btn := Button.new()
	settings_btn.text = tr("UI_SETTINGS")
	settings_btn.pressed.connect(func() -> void: open_settings.emit())
	vbox.add_child(settings_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Unlock or lock the endless mode button.
func set_endless_unlocked(unlocked: bool) -> void:
	if _endless_btn != null:
		_endless_btn.disabled = not unlocked
