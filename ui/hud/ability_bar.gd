class_name AbilityBar
extends VBoxContainer

## Vertical bar of ability activation buttons plus an optional hero summon button.
## Positioned bottom-left, above the tower bar for mobile thumb-zone ergonomics.
## Call setup() after loading the ability loadout, then update_cooldowns() each frame/tick.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ability_activated(slot: int)
signal hero_summoned

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _ability_buttons: Array[Button] = []
var _hero_btn: Button = null
var _ability_ids: Array[String] = []
var _cooldown_overlays: Array[ColorRect] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build the bar from a list of ability id strings.
## hero_available: show an extra hero summon button when true.
func setup(ability_ids: Array, hero_available: bool) -> void:
	_ability_ids.clear()

	# Clear existing children
	for child in get_children():
		child.queue_free()
	_ability_buttons.clear()
	_cooldown_overlays.clear()
	_hero_btn = null

	# Create one button per ability slot
	for i in ability_ids.size():
		var ab_id: String = ability_ids[i] as String
		_ability_ids.append(ab_id)

		var btn := Button.new()
		btn.text = _get_ability_label(ab_id)
		btn.custom_minimum_size = Vector2(64, 64)
		btn.clip_contents = true
		var slot := i  # capture loop variable
		btn.pressed.connect(func() -> void: _on_ability_pressed(slot))
		add_child(btn)
		_ability_buttons.append(btn)

		# Cooldown overlay — a semi-transparent dark rect that shrinks as cooldown expires
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.5)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = false
		btn.add_child(overlay)
		_cooldown_overlays.append(overlay)

	# Hero summon button
	if hero_available:
		_hero_btn = Button.new()
		_hero_btn.text = tr("ABILITY_HERO")
		_hero_btn.custom_minimum_size = Vector2(64, 64)
		_hero_btn.pressed.connect(_on_hero_pressed)
		add_child(_hero_btn)


## Refresh cooldown state for each ability button.
## abilities: Array of Ability nodes (from AbilityManager._abilities).
func update_cooldowns(abilities: Array) -> void:
	for i in _ability_buttons.size():
		var btn: Button = _ability_buttons[i]
		var overlay: ColorRect = _cooldown_overlays[i] if i < _cooldown_overlays.size() else null
		if i < abilities.size() and abilities[i] != null:
			var ab: Ability = abilities[i] as Ability
			btn.disabled = not ab.is_ready()
			# Append a rough cooldown indicator to the label
			if not ab.is_ready():
				var remaining: float = ab._cooldown_remaining
				btn.text = _get_ability_label(_ability_ids[i]) + "\n%.0fs" % remaining
				# Update cooldown overlay height
				if overlay != null:
					var progress: float = ab.get_cooldown_progress()
					overlay.visible = true
					overlay.position = Vector2.ZERO
					overlay.size = Vector2(btn.size.x, btn.size.y * (1.0 - progress))
			else:
				btn.text = _get_ability_label(_ability_ids[i])
				if overlay != null:
					overlay.visible = false
		else:
			btn.disabled = false
			if overlay != null:
				overlay.visible = false

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _get_ability_label(ab_id: String) -> String:
	var key: String = "ABILITY_" + ab_id.to_upper()
	return tr(key)


func _on_ability_pressed(slot: int) -> void:
	AudioManager.play_ui_click()
	ability_activated.emit(slot)


func _on_hero_pressed() -> void:
	AudioManager.play_ui_click()
	hero_summoned.emit()
