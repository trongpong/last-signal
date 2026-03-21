class_name TowerLab
extends Control

## Meta-progression screen: skill trees per tower and global stat upgrades.
## Requires ProgressionManager and EconomyManager references via setup().

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal skill_unlock_requested(tower_type: int, node_index: int)
signal global_upgrade_requested(upgrade_id: String)
signal back_pressed

# ---------------------------------------------------------------------------
# References
# ---------------------------------------------------------------------------

var _progression_manager: ProgressionManager = null
var _economy_manager = null

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _tower_list: VBoxContainer
var _skill_tree_panel: VBoxContainer
var _global_upgrades_panel: VBoxContainer
var _diamonds_label: Label
var _selected_tower_type: int = -1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	# Left panel: tower list
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var towers_title := Label.new()
	towers_title.text = tr("UI_TOWER_LAB")
	left_vbox.add_child(towers_title)

	_tower_list = VBoxContainer.new()
	left_vbox.add_child(_tower_list)

	# Centre panel: skill tree for selected tower
	var centre_panel := PanelContainer.new()
	centre_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(centre_panel)

	var centre_vbox := VBoxContainer.new()
	centre_panel.add_child(centre_vbox)

	var skill_title := Label.new()
	skill_title.text = tr("SKILL_TREE")
	centre_vbox.add_child(skill_title)

	_skill_tree_panel = VBoxContainer.new()
	centre_vbox.add_child(_skill_tree_panel)

	# Right panel: global upgrades
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)

	var global_title := Label.new()
	global_title.text = tr("GLOBAL_UPGRADES")
	right_vbox.add_child(global_title)

	_diamonds_label = Label.new()
	_diamonds_label.text = tr("UI_DIAMONDS") + ": 0"
	right_vbox.add_child(_diamonds_label)

	_global_upgrades_panel = VBoxContainer.new()
	right_vbox.add_child(_global_upgrades_panel)

	# Back button at the bottom
	var footer := HBoxContainer.new()
	# Re-parent footer outside hbox — add to self
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	right_vbox.add_child(back_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Inject managers and populate all panels.
func setup(pm: ProgressionManager, em) -> void:
	_progression_manager = pm
	_economy_manager = em

	if em != null:
		em.diamonds_changed.connect(_on_diamonds_changed)
		_diamonds_label.text = tr("UI_DIAMONDS") + ": " + str(em.diamonds)

	_populate_tower_list()
	_populate_global_upgrades()

# ---------------------------------------------------------------------------
# Internal: tower list
# ---------------------------------------------------------------------------

func _populate_tower_list() -> void:
	for child in _tower_list.get_children():
		child.queue_free()

	# Show all tower types; label comes from translation key
	var tower_types: Array = [
		[Enums.TowerType.PULSE_CANNON,  "TOWER_PULSE_CANNON"],
		[Enums.TowerType.ARC_EMITTER,   "TOWER_ARC_EMITTER"],
		[Enums.TowerType.CRYO_ARRAY,    "TOWER_CRYO_ARRAY"],
		[Enums.TowerType.MISSILE_POD,   "TOWER_MISSILE_POD"],
		[Enums.TowerType.BEAM_SPIRE,    "TOWER_BEAM_SPIRE"],
		[Enums.TowerType.NANO_HIVE,     "TOWER_NANO_HIVE"],
		[Enums.TowerType.HARVESTER,     "TOWER_HARVESTER"],
	]
	for pair in tower_types:
		var tower_type: int = pair[0] as int
		var key: String = pair[1] as String
		var btn := Button.new()
		btn.text = tr(key)
		var tt := tower_type  # capture
		btn.pressed.connect(func() -> void: _on_tower_selected(tt))
		_tower_list.add_child(btn)

# ---------------------------------------------------------------------------
# Internal: skill tree
# ---------------------------------------------------------------------------

func _show_skill_tree(tower_type: int) -> void:
	for child in _skill_tree_panel.get_children():
		child.queue_free()

	if _progression_manager == null:
		return

	var tree: SkillTree = _progression_manager._get_skill_tree(tower_type)
	if tree == null:
		return

	var unlocked: Array = _progression_manager._get_unlocked_nodes(tower_type)

	for node in tree.nodes:
		var sn: SkillNode = node as SkillNode
		var row := HBoxContainer.new()
		_skill_tree_panel.add_child(row)

		var lbl := Label.new()
		lbl.text = sn.display_name
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = str(sn.cost)
		row.add_child(cost_lbl)

		var btn := Button.new()
		if unlocked.has(sn.node_index):
			btn.text = tr("UI_COMPLETED")
			btn.disabled = true
		else:
			btn.text = tr("UI_UNLOCK")
			var idx: int = sn.node_index
			btn.pressed.connect(func() -> void: _on_skill_unlock(tower_type, idx))

		if sn.is_hero_unlock:
			btn.text += " (Hero)"

		row.add_child(btn)

# ---------------------------------------------------------------------------
# Internal: global upgrades
# ---------------------------------------------------------------------------

func _populate_global_upgrades() -> void:
	for child in _global_upgrades_panel.get_children():
		child.queue_free()

	if _progression_manager == null:
		return

	for upgrade_id in ProgressionManager.GLOBAL_UPGRADES.keys():
		var row := HBoxContainer.new()
		_global_upgrades_panel.add_child(row)

		var tier: int = _progression_manager.get_global_upgrade_tier(upgrade_id)
		var lbl := Label.new()
		lbl.text = upgrade_id + " (T%d)" % tier
		lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(lbl)

		var cost_idx: int = mini(tier, Constants.GLOBAL_UPGRADE_COSTS.size() - 1)
		var cost: int = Constants.GLOBAL_UPGRADE_COSTS[cost_idx] as int

		var btn := Button.new()
		if tier >= 10:
			btn.text = tr("UI_COMPLETED")
			btn.disabled = true
		else:
			btn.text = tr("UI_UPGRADE") + " (%d♦)" % cost
			var uid: String = upgrade_id  # capture
			btn.pressed.connect(func() -> void: _on_global_upgrade(uid))
		row.add_child(btn)

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_tower_selected(tower_type: int) -> void:
	_selected_tower_type = tower_type
	_show_skill_tree(tower_type)


func _on_skill_unlock(tower_type: int, node_index: int) -> void:
	skill_unlock_requested.emit(tower_type, node_index)
	# Refresh tree view
	_show_skill_tree(tower_type)


func _on_global_upgrade(upgrade_id: String) -> void:
	global_upgrade_requested.emit(upgrade_id)
	# Refresh panel
	_populate_global_upgrades()


func _on_diamonds_changed(new_diamonds: int, _delta: int) -> void:
	_diamonds_label.text = tr("UI_DIAMONDS") + ": " + str(new_diamonds)
