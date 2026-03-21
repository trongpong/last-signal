class_name AbilityBar
extends HBoxContainer

## Horizontal bar of ability activation buttons plus an optional hero summon button.
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
	_hero_btn = null

	# Create one button per ability slot
	for i in ability_ids.size():
		var ab_id: String = ability_ids[i] as String
		_ability_ids.append(ab_id)

		var btn := Button.new()
		btn.text = _get_ability_label(ab_id)
		btn.custom_minimum_size = Vector2(80, 48)
		var slot := i  # capture loop variable
		btn.pressed.connect(func() -> void: _on_ability_pressed(slot))
		add_child(btn)
		_ability_buttons.append(btn)

	# Hero summon button
	if hero_available:
		_hero_btn = Button.new()
		_hero_btn.text = tr("HUD_SEND_WAVE")  # repurpose label until a dedicated key exists
		_hero_btn.custom_minimum_size = Vector2(80, 48)
		_hero_btn.pressed.connect(_on_hero_pressed)
		add_child(_hero_btn)


## Refresh cooldown state for each ability button.
## abilities: Array of Ability nodes (from AbilityManager._abilities).
func update_cooldowns(abilities: Array) -> void:
	for i in _ability_buttons.size():
		var btn: Button = _ability_buttons[i]
		if i < abilities.size() and abilities[i] != null:
			var ab: Ability = abilities[i] as Ability
			btn.disabled = not ab.is_ready()
			# Append a rough cooldown indicator to the label
			if not ab.is_ready():
				var remaining: float = ab._cooldown_remaining
				btn.text = _get_ability_label(_ability_ids[i]) + "\n%.0fs" % remaining
			else:
				btn.text = _get_ability_label(_ability_ids[i])
		else:
			btn.disabled = false

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _get_ability_label(ab_id: String) -> String:
	var key: String = "ABILITY_" + ab_id.to_upper()
	return tr(key)


func _on_ability_pressed(slot: int) -> void:
	ability_activated.emit(slot)


func _on_hero_pressed() -> void:
	hero_summoned.emit()
