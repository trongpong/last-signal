class_name TowerButton
extends Button

## A button representing a single tower type in the build bar.
## Displays tower name and cost; dims when the player cannot afford it.

# ---------------------------------------------------------------------------
# Signal
# ---------------------------------------------------------------------------

signal tower_selected(tower_type: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _tower_type: int = -1
var _cost: int = 0

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Populate this button from a TowerDefinition resource.
func setup(def: TowerDefinition) -> void:
	_tower_type = def.tower_type as int
	_cost = def.cost
	# Use tr() to look up the localised tower name; fall back to the id.
	var name_key: String = "TOWER_" + def.id.to_upper()
	text = "%s\n%d" % [tr(name_key), def.cost]
	pressed.connect(_on_pressed)


## Grey out the button when the player cannot afford this tower.
func update_affordability(gold: int) -> void:
	disabled = gold < _cost

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	tower_selected.emit(_tower_type)
