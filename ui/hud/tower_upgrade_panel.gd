class_name TowerUpgradePanel
extends PanelContainer

## Panel shown when the player selects a placed tower.
## Displays current stats, tier, upgrade branch choices, targeting cycle, and sell.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal upgrade_requested(tower: Tower, choice: int)
signal sell_requested(tower: Tower)
signal targeting_changed(tower: Tower, mode: int)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _tower: Tower = null
var _sell_value: int = 0

## Ordered list of TargetingMode int values; length matches Enums.TargetingMode size.
const _TARGETING_MODES: Array = [
	Enums.TargetingMode.NEAREST,
	Enums.TargetingMode.STRONGEST,
	Enums.TargetingMode.WEAKEST,
	Enums.TargetingMode.FIRST,
	Enums.TargetingMode.LAST,
]

const _TARGETING_KEYS: Array = [
	"TARGETING_NEAREST",
	"TARGETING_STRONGEST",
	"TARGETING_WEAKEST",
	"TARGETING_FIRST",
	"TARGETING_LAST",
]

var _current_targeting_index: int = 3  # default FIRST

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _name_label: Label
var _stats_label: Label
var _tier_label: Label
var _targeting_btn: Button
var _upgrade_container: VBoxContainer
var _sell_btn: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	hide()


func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	_name_label = Label.new()
	vbox.add_child(_name_label)

	_tier_label = Label.new()
	vbox.add_child(_tier_label)

	_stats_label = Label.new()
	vbox.add_child(_stats_label)

	# Targeting button
	_targeting_btn = Button.new()
	_targeting_btn.text = tr("HUD_TARGETING") + ": " + tr("TARGETING_FIRST")
	_targeting_btn.pressed.connect(_cycle_targeting)
	vbox.add_child(_targeting_btn)

	# Upgrade choices container
	_upgrade_container = VBoxContainer.new()
	vbox.add_child(_upgrade_container)

	# Sell button
	_sell_btn = Button.new()
	_sell_btn.text = tr("HUD_SELL")
	_sell_btn.pressed.connect(_on_sell_pressed)
	vbox.add_child(_sell_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Display the panel populated with the given tower's data.
## sell_value: gold the player will receive on sell.
func show_for_tower(tower: Tower, sell_value: int) -> void:
	_tower = tower
	_sell_value = sell_value

	# Name
	var def: TowerDefinition = tower._definition
	var name_key := "TOWER_" + def.id.to_upper()
	_name_label.text = tr(name_key)

	# Tier
	_tier_label.text = tr("TIER").replace("{0}", str(tower.current_tier))

	# Stats
	_stats_label.text = "DMG: %.1f  RoF: %.2f  RNG: %.0f" % [
		tower.current_damage,
		tower.current_fire_rate,
		tower.current_range
	]

	# Targeting — sync button to current mode
	var mode_idx: int = _TARGETING_MODES.find(tower.targeting_mode)
	_current_targeting_index = mode_idx if mode_idx >= 0 else 3
	_update_targeting_label()

	# Sell button
	_sell_btn.text = tr("HUD_SELL") + " (%d)" % sell_value

	# Upgrade choices
	_populate_upgrade_choices(tower)

	show()


func hide_panel() -> void:
	_tower = null
	hide()

# ---------------------------------------------------------------------------
# Targeting cycle
# ---------------------------------------------------------------------------

func _cycle_targeting() -> void:
	if _tower == null:
		return
	_current_targeting_index = (_current_targeting_index + 1) % _TARGETING_MODES.size()
	_update_targeting_label()
	targeting_changed.emit(_tower, _TARGETING_MODES[_current_targeting_index])


func _update_targeting_label() -> void:
	var key: String = _TARGETING_KEYS[_current_targeting_index]
	_targeting_btn.text = tr("HUD_TARGETING") + ": " + tr(key)

# ---------------------------------------------------------------------------
# Upgrade choices
# ---------------------------------------------------------------------------

func _populate_upgrade_choices(tower: Tower) -> void:
	# Clear previous buttons
	for child in _upgrade_container.get_children():
		child.queue_free()

	var tier_tree: TierTree = tower.get_tier_tree()
	if tier_tree == null:
		return

	var options: Array = tier_tree.get_upgrade_options(tower.get_upgrade_path())
	if options.is_empty():
		var max_lbl := Label.new()
		max_lbl.text = tr("UI_COMPLETED")
		_upgrade_container.add_child(max_lbl)
		return

	for i in options.size():
		var branch: Dictionary = options[i]
		var btn := Button.new()
		var display: String = branch.get("display_name", "Upgrade %d" % i)
		var cost: int = branch.get("cost", 0) as int
		btn.text = "%s (%d)" % [display, cost]
		var slot := i  # capture
		btn.pressed.connect(func() -> void: _on_upgrade_pressed(slot))
		_upgrade_container.add_child(btn)

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_upgrade_pressed(choice: int) -> void:
	if _tower != null:
		upgrade_requested.emit(_tower, choice)


func _on_sell_pressed() -> void:
	if _tower != null:
		sell_requested.emit(_tower)
