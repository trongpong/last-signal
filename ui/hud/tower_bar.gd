class_name TowerBar
extends HBoxContainer

## Horizontal bar of TowerButtons shown during the build phase.
## Populated from TowerDefinition resources, filtered by unlocked set.

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

signal tower_build_requested(tower_type: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _buttons: Array[TowerButton] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build buttons for each definition whose id appears in unlocked.
## unlocked: Array of tower id strings (e.g. ["PULSE_CANNON", "ARC_EMITTER"]).
func populate(definitions: Array, unlocked: Array) -> void:
	# Clear existing buttons
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_buttons.clear()

	for def in definitions:
		if def == null:
			continue
		if not unlocked.has(def.id):
			continue
		var btn := TowerButton.new()
		btn.setup(def)
		btn.tower_selected.connect(_on_tower_selected)
		add_child(btn)
		_buttons.append(btn)


## Update affordability highlight on all buttons.
func update_gold(gold: int) -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.update_affordability(gold)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_tower_selected(tower_type: int) -> void:
	tower_build_requested.emit(tower_type)
