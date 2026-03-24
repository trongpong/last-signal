class_name TowerUpgradePanel
extends PanelContainer

## Panel shown when the player selects a placed tower.
## Displays current stats, tier, upgrade branch choices, targeting cycle, and sell.
## Uses card-based unified styling consistent with Tower Lab.

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

var _current_targeting_index: int = 3

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _name_label: Label
var _tier_label: Label
var _stats_container: VBoxContainer
var _targeting_btn: Button
var _upgrade_container: VBoxContainer
var _sell_btn: Button

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Panel background styling
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.04, 0.08, 0.95)
	panel_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.border_color = Color(0.8, 0.7, 0.2, 0.5)
	panel_style.set_content_margin_all(12)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)
	_build_layout()
	hide()


func _build_layout() -> void:
	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(outer_vbox)

	# ---- HEADER: tower name + tier (fixed, outside scroll) ----
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)

	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 16)
	_tier_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(_tier_label)

	outer_vbox.add_child(HSeparator.new())

	# ---- SCROLLABLE BODY: stats + upgrades + actions ----
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	outer_vbox.add_child(scroll)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body)

	# Left column: stats
	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 2)
	_stats_container.custom_minimum_size = Vector2(180, 0)
	body.add_child(_stats_container)

	# Vertical divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(1, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	div.color = Color(0.3, 0.3, 0.3, 0.3)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(div)

	# Center column: upgrades
	_upgrade_container = VBoxContainer.new()
	_upgrade_container.add_theme_constant_override("separation", 6)
	_upgrade_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_upgrade_container)

	# Vertical divider
	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(1, 0)
	div2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	div2.color = Color(0.3, 0.3, 0.3, 0.3)
	div2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(div2)

	# Right column: targeting + sell
	var actions_vbox := VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 6)
	actions_vbox.custom_minimum_size = Vector2(150, 0)
	body.add_child(actions_vbox)

	_targeting_btn = Button.new()
	_targeting_btn.custom_minimum_size = Vector2(0, 40)
	_targeting_btn.add_theme_font_size_override("font_size", 14)
	_targeting_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_targeting_btn.pressed.connect(_cycle_targeting)
	actions_vbox.add_child(_targeting_btn)

	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(0, 40)
	_sell_btn.add_theme_font_size_override("font_size", 14)
	_sell_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_sell_btn.pressed.connect(_on_sell_pressed)
	actions_vbox.add_child(_sell_btn)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_for_tower(tower: Tower, sell_value: int) -> void:
	_tower = tower
	_sell_value = sell_value

	var def: TowerDefinition = tower.get_definition()
	var name_key := "TOWER_" + def.id.to_upper()
	_name_label.text = tr(name_key)

	_tier_label.text = tr("TIER").replace("{0}", str(tower.current_tier))

	# Stats
	for child in _stats_container.get_children():
		child.queue_free()
	_add_stat_row(tr("HUD_STAT_DAMAGE"), "%.1f" % tower.current_damage, Color(1.0, 0.5, 0.2))
	_add_stat_row(tr("HUD_STAT_FIRE_RATE"), "%.2f/s" % tower.current_fire_rate, Color(0.4, 0.8, 1.0))
	_add_stat_row(tr("HUD_STAT_RANGE"), "%.0f" % tower.current_range, Color(0.3, 0.9, 0.3))

	# Targeting
	var mode_idx: int = _TARGETING_MODES.find(tower.targeting_mode)
	_current_targeting_index = mode_idx if mode_idx >= 0 else 3
	_update_targeting_label()

	# Sell
	_sell_btn.text = tr("SELL_VALUE").replace("{0}", str(sell_value))

	# Upgrades
	_populate_upgrade_choices(tower)

	# Animate
	AudioManager.play_ui_panel_open()
	show()
	var final_offset_top: float = offset_top
	offset_top = 0.0
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "offset_top", final_offset_top, 0.2)


func hide_panel() -> void:
	AudioManager.play_ui_panel_close()
	_tower = null
	hide()

# ---------------------------------------------------------------------------
# Targeting cycle
# ---------------------------------------------------------------------------

func _cycle_targeting() -> void:
	if _tower == null:
		return
	AudioManager.play_ui_click()
	_current_targeting_index = (_current_targeting_index + 1) % _TARGETING_MODES.size()
	var new_mode: int = _TARGETING_MODES[_current_targeting_index]
	_update_targeting_label()
	_tower.set_targeting_mode(new_mode)
	targeting_changed.emit(_tower, new_mode)


func _update_targeting_label() -> void:
	var key: String = _TARGETING_KEYS[_current_targeting_index]
	_targeting_btn.text = tr("HUD_TARGETING") + ": " + tr(key)

# ---------------------------------------------------------------------------
# Upgrade choices
# ---------------------------------------------------------------------------

func _populate_upgrade_choices(tower: Tower) -> void:
	for child in _upgrade_container.get_children():
		child.queue_free()

	var tier_tree: TierTree = tower.get_tier_tree()
	if tier_tree == null:
		return

	var options: Array = tier_tree.get_upgrade_options(tower.get_upgrade_path())
	if options.is_empty():
		var max_lbl := Label.new()
		max_lbl.text = tr("HUD_FULLY_UPGRADED")
		max_lbl.add_theme_font_size_override("font_size", 14)
		max_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		_upgrade_container.add_child(max_lbl)
		return

	var header := Label.new()
	header.text = tr("HUD_UPGRADES")
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_upgrade_container.add_child(header)

	var cur_dmg: float = tower.current_damage
	var cur_rof: float = tower.current_fire_rate
	var cur_rng: float = tower.current_range

	for i in options.size():
		var branch: Dictionary = options[i]
		var display: String = branch.get("display_name", "Upgrade %d" % (i + 1))
		var cost: int = branch.get("cost", 0) as int

		# Card for this upgrade option
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.06, 0.1, 0.7)
		card_style.border_color = Color(0.2, 0.3, 0.4, 0.5)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(3)
		card_style.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		_upgrade_container.add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 2)
		card.add_child(card_vbox)

		# Upgrade name + cost button
		var top_row := HBoxContainer.new()
		card_vbox.add_child(top_row)

		var name_lbl := Label.new()
		name_lbl.text = display
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)

		var btn := Button.new()
		btn.text = tr("UI_COST_GOLD").replace("{0}", str(cost))
		btn.custom_minimum_size = Vector2(80, 32)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		var slot := i
		btn.pressed.connect(func() -> void:
			AudioManager.play_ui_click()
			_on_upgrade_pressed(slot)
		)
		top_row.add_child(btn)

		# Stat preview — multiply only the base+tier portion, then re-add bonuses
		# Tower stat formula: (base × tier_mults + skill) × (1 + mastery)
		# To preview, extract base×tier, apply new mult, reconstruct
		var dmg_mult: float = branch.get("damage_mult", 1.0) as float
		var rof_mult: float = branch.get("fire_rate_mult", 1.0) as float
		var rng_mult: float = branch.get("range_mult", 1.0) as float
		var mastery_f: float = 1.0 + tower.get_mastery_damage_bonus()
		var skill_dmg: float = tower.get_skill_damage_bonus()
		var skill_rof: float = tower.get_skill_fire_rate_bonus()
		var skill_rng: float = tower.get_skill_range_bonus()
		var base_tier_dmg: float = cur_dmg / maxf(mastery_f, 0.01) - skill_dmg
		var base_tier_rof: float = cur_rof - skill_rof
		var base_tier_rng: float = cur_rng - skill_rng
		var preview_parts: PackedStringArray = PackedStringArray()
		if not is_equal_approx(dmg_mult, 1.0):
			var new_dmg: float = (base_tier_dmg * dmg_mult + skill_dmg) * mastery_f
			preview_parts.append(tr("HUD_STAT_DAMAGE") + ": %.1f → %.1f" % [cur_dmg, new_dmg])
		if not is_equal_approx(rof_mult, 1.0):
			var new_rof: float = base_tier_rof * rof_mult + skill_rof
			preview_parts.append(tr("HUD_STAT_FIRE_RATE") + ": %.2f → %.2f" % [cur_rof, new_rof])
		if not is_equal_approx(rng_mult, 1.0):
			var new_rng: float = base_tier_rng * rng_mult + skill_rng
			preview_parts.append(tr("HUD_STAT_RANGE") + ": %.0f → %.0f" % [cur_rng, new_rng])

		if preview_parts.size() > 0:
			var preview_lbl := Label.new()
			preview_lbl.text = "  ".join(preview_parts)
			preview_lbl.add_theme_font_size_override("font_size", 12)
			preview_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			card_vbox.add_child(preview_lbl)

# ---------------------------------------------------------------------------
# Stat display helpers
# ---------------------------------------------------------------------------

func _add_stat_row(label: String, value: String, color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_stats_container.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lbl.custom_minimum_size = Vector2(75, 0)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_upgrade_pressed(choice: int) -> void:
	if _tower != null:
		upgrade_requested.emit(_tower, choice)


func _on_sell_pressed() -> void:
	if _tower != null:
		AudioManager.play_ui_click()
		sell_requested.emit(_tower)
