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
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	custom_minimum_size = Vector2(0, 72)
	add_theme_constant_override("separation", 4)

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


## Highlight the button for the given tower type, deselect all others.
func select_tower(tower_type: int) -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.set_selected(btn._tower_type == tower_type)


## Clear selection on all buttons.
func deselect_all() -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.set_selected(false)


## Update affordability highlight on all buttons.
func update_gold(gold: int) -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.update_affordability(gold)


## Apply a cost discount percentage to all tower buttons.
func apply_cost_discount(discount_percent: int) -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			var original: int = btn._cost
			var discounted: int = maxi(original - int(float(original) * float(discount_percent) / 100.0), 1)
			btn.set_display_cost(discounted)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_tower_selected(tower_type: int) -> void:
	tower_build_requested.emit(tower_type)
