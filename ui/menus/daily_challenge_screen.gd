extends Control

## Daily Challenge selection screen. Shows today's challenge and lets the player start it.

signal play_pressed
signal back_pressed

var _challenge: Dictionary = {}

func setup(challenge: Dictionary) -> void:
	_challenge = challenge
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	add_child(bg)

	# Center content
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200.0
	vbox.offset_right = 200.0
	vbox.offset_top = -180.0
	vbox.offset_bottom = 180.0
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = tr("DAILY_CHALLENGE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	vbox.add_child(title)

	# Challenge type
	var type_label := Label.new()
	type_label.text = _challenge.get("type_name", "Challenge") as String
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(type_label)

	# Description
	var desc := Label.new()
	desc.text = _challenge.get("description", "") as String
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	# Streak
	var streak: int = _challenge.get("streak", 0) as int
	if streak > 0:
		var streak_label := Label.new()
		streak_label.text = "Streak: %d days (+%d bonus diamonds)" % [streak, mini(streak, 7) * 10]
		streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		streak_label.add_theme_font_size_override("font_size", 13)
		streak_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		vbox.add_child(streak_label)

	# Reward info
	var reward_label := Label.new()
	reward_label.text = "Reward: 50 diamonds (100 for 3 stars)"
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(reward_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Play / Completed button
	var play_btn := Button.new()
	if _challenge.get("completed", false):
		play_btn.text = tr("DAILY_COMPLETED")
		play_btn.disabled = true
	else:
		play_btn.text = tr("DAILY_PLAY")
		play_btn.pressed.connect(func() -> void: play_pressed.emit())
	play_btn.custom_minimum_size = Vector2(200, 48)
	play_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(play_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	vbox.add_child(back_btn)
