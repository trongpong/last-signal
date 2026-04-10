class_name TowerLab
extends Control

## Meta-progression screen: skill trees per tower and global stat upgrades.
## Production-quality mobile layout with sidebar navigation and polished visuals.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal skill_unlock_requested(tower_type: int, node_index: int)
signal global_upgrade_requested(upgrade_id: String)
signal back_pressed

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const _TOWER_COLORS: Dictionary = {
	0: Color(0.0, 0.9, 1.0),    # Pulse Cannon - cyan
	1: Color(1.0, 0.9, 0.0),    # Arc Emitter - yellow
	2: Color(0.5, 0.8, 1.0),    # Cryo Array - ice blue
	3: Color(1.0, 0.4, 0.1),    # Missile Pod - orange
	4: Color(1.0, 1.0, 1.0),    # Beam Spire - white
	5: Color(0.2, 1.0, 0.3),    # Nano Hive - green
	6: Color(1.0, 0.85, 0.0),   # Harvester - gold
}

const _TOWER_KEYS: Array = [
	[0, "TOWER_PULSE_CANNON"],
	[1, "TOWER_ARC_EMITTER"],
	[2, "TOWER_CRYO_ARRAY"],
	[3, "TOWER_MISSILE_POD"],
	[4, "TOWER_BEAM_SPIRE"],
	[5, "TOWER_NANO_HIVE"],
	[6, "TOWER_HARVESTER"],
]

# ---------------------------------------------------------------------------
# References
# ---------------------------------------------------------------------------

var _progression_manager: ProgressionManager = null
var _economy_manager = null

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _tower_buttons: Array[Button] = []
var _skill_tree_panel: VBoxContainer
var _global_upgrades_panel: VBoxContainer
var _diamonds_label: Label
var _skill_detail_panel: PanelContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_cost: Label
var _selected_tower_type: int = -1
var _content_title: Label
var _tab_skills_btn: Button
var _tab_globals_btn: Button
var _tab_synergies_btn: Button
var _skill_scroll: ScrollContainer
var _global_scroll: ScrollContainer
var _synergy_scroll: ScrollContainer
var _synergy_panel: VBoxContainer
var _current_tab: int = 0  # 0 = skills, 1 = globals, 2 = synergies
var _bg: ColorRect

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_layout()
	AdManager.apply_banner_reserve(self, SaveManager)
	AdManager.banner_reserve_changed.connect(_on_banner_reserve_changed)
	AdManager.show_banner(SaveManager)


func _exit_tree() -> void:
	AdManager.hide_banner()
	if AdManager.banner_reserve_changed.is_connected(_on_banner_reserve_changed):
		AdManager.banner_reserve_changed.disconnect(_on_banner_reserve_changed)


func _on_banner_reserve_changed(_pixels: float) -> void:
	AdManager.apply_banner_reserve(self, SaveManager)
	AdManager.extend_bg_over_banner(_bg, SaveManager)


func _get_safe_margin() -> float:
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	var left: float = safe_area.position.x
	var right: float = maxf(screen_size.x - safe_area.end.x, 0.0)
	return clampf(maxf(left, right), 16.0, 48.0)


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Full dark background
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.02, 0.03, 0.06, 0.95)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	AdManager.extend_bg_over_banner(_bg, SaveManager)

	var safe: float = _get_safe_margin()
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = safe
	main_hbox.offset_right = -safe
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)

	# ---- LEFT SIDEBAR: tower list ----
	_build_sidebar(main_hbox)

	# Vertical divider
	var vsep := ColorRect.new()
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsep.color = Color(0.3, 0.3, 0.3, 0.3)
	vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_hbox.add_child(vsep)

	# ---- RIGHT: content area ----
	_build_content_area(main_hbox)


func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(200, 0)
	sidebar.add_theme_constant_override("separation", 0)
	parent.add_child(sidebar)

	# Sidebar background
	var sidebar_bg := ColorRect.new()
	sidebar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar_bg.color = Color(0.04, 0.05, 0.1, 0.9)
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.add_child(sidebar_bg)
	sidebar.move_child(sidebar_bg, 0)

	# Margin wrapper for sidebar content padding
	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 10)
	sidebar_margin.add_theme_constant_override("margin_right", 10)
	sidebar_margin.add_theme_constant_override("margin_top", 4)
	sidebar_margin.add_theme_constant_override("margin_bottom", 4)
	sidebar_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_margin.add_child(inner)

	# Header row matching content area height (44px)
	var header_row := HBoxContainer.new()
	header_row.custom_minimum_size = Vector2(0, 44)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(header_row)

	var title := Label.new()
	title.text = tr("UI_TOWER_LAB")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(title)

	# Diamond count (right side of header)
	_diamonds_label = Label.new()
	_diamonds_label.text = "◆ 0"
	_diamonds_label.add_theme_font_size_override("font_size", 14)
	_diamonds_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header_row.add_child(_diamonds_label)

	inner.add_child(HSeparator.new())

	# Section label
	var towers_lbl := Label.new()
	towers_lbl.text = tr("LAB_TOWERS")
	towers_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	towers_lbl.add_theme_font_size_override("font_size", 11)
	towers_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	inner.add_child(towers_lbl)

	# Tower buttons — card-style to match skill tree and global upgrade cards
	for pair in _TOWER_KEYS:
		var tower_type: int = pair[0] as int
		var key: String = pair[1] as String
		var color: Color = _TOWER_COLORS.get(tower_type, Color.WHITE)

		var btn := Button.new()
		btn.text = "  " + tr(key)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Default card-style background
		var default_style := StyleBoxFlat.new()
		default_style.bg_color = Color(0.06, 0.06, 0.1, 0.6)
		default_style.border_color = Color(0.2, 0.2, 0.3, 0.4)
		default_style.set_border_width_all(1)
		default_style.set_corner_radius_all(4)
		default_style.set_content_margin_all(8)
		default_style.content_margin_left = 12
		btn.add_theme_stylebox_override("normal", default_style)
		# Hover style
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1, 0.5)
		hover_style.border_color = Color(color.r, color.g, color.b, 0.3)
		hover_style.set_border_width_all(1)
		hover_style.set_corner_radius_all(4)
		hover_style.set_content_margin_all(8)
		hover_style.content_margin_left = 12
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		var tt := tower_type
		btn.pressed.connect(func() -> void:
			AudioManager.play_ui_click()
			_on_tower_selected(tt)
		)
		inner.add_child(btn)
		_tower_buttons.append(btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	inner.add_child(HSeparator.new())

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("UI_BACK")
	back_btn.custom_minimum_size = Vector2(0, 48)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		back_pressed.emit()
	)
	inner.add_child(back_btn)


func _build_content_area(parent: HBoxContainer) -> void:
	# Margin wrapper for content area padding
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	parent.add_child(content_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 4)
	content_margin.add_child(right_vbox)

	# Header with title + tab buttons
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 44)
	header.add_theme_constant_override("separation", 8)
	right_vbox.add_child(header)

	_content_title = Label.new()
	_content_title.text = tr("LAB_SELECT_TOWER")
	_content_title.add_theme_font_size_override("font_size", 22)
	_content_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	_content_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_content_title)

	# Tab buttons
	_tab_skills_btn = Button.new()
	_tab_skills_btn.text = tr("SKILL_TREE")
	_tab_skills_btn.custom_minimum_size = Vector2(100, 36)
	_tab_skills_btn.add_theme_font_size_override("font_size", 14)
	_tab_skills_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		_switch_tab(0)
	)
	header.add_child(_tab_skills_btn)

	_tab_globals_btn = Button.new()
	_tab_globals_btn.text = tr("GLOBAL_UPGRADES")
	_tab_globals_btn.custom_minimum_size = Vector2(120, 36)
	_tab_globals_btn.add_theme_font_size_override("font_size", 14)
	_tab_globals_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		_switch_tab(1)
	)
	header.add_child(_tab_globals_btn)

	_tab_synergies_btn = Button.new()
	_tab_synergies_btn.text = tr("UI_SYNERGIES")
	_tab_synergies_btn.custom_minimum_size = Vector2(100, 36)
	_tab_synergies_btn.add_theme_font_size_override("font_size", 14)
	_tab_synergies_btn.pressed.connect(func() -> void:
		AudioManager.play_ui_click()
		_switch_tab(2)
	)
	header.add_child(_tab_synergies_btn)

	right_vbox.add_child(HSeparator.new())

	# Skill tree scroll area
	_skill_scroll = ScrollContainer.new()
	_skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_skill_scroll)

	_skill_tree_panel = VBoxContainer.new()
	_skill_tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_tree_panel.add_theme_constant_override("separation", 6)
	_skill_scroll.add_child(_skill_tree_panel)

	# Global upgrades scroll area (hidden by default)
	_global_scroll = ScrollContainer.new()
	_global_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_global_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_global_scroll.visible = false
	right_vbox.add_child(_global_scroll)

	_global_upgrades_panel = VBoxContainer.new()
	_global_upgrades_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_global_upgrades_panel.add_theme_constant_override("separation", 6)
	_global_scroll.add_child(_global_upgrades_panel)

	# Synergies scroll area (hidden by default)
	_synergy_scroll = ScrollContainer.new()
	_synergy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_synergy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_scroll.visible = false
	right_vbox.add_child(_synergy_scroll)

	_synergy_panel = VBoxContainer.new()
	_synergy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_panel.add_theme_constant_override("separation", 8)
	_synergy_scroll.add_child(_synergy_panel)

	# Skill detail panel at bottom
	_skill_detail_panel = PanelContainer.new()
	_skill_detail_panel.custom_minimum_size = Vector2(0, 70)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.07, 0.12, 0.9)
	detail_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	detail_style.set_border_width_all(1)
	detail_style.set_content_margin_all(8)
	_skill_detail_panel.add_theme_stylebox_override("panel", detail_style)
	right_vbox.add_child(_skill_detail_panel)

	var detail_vbox := VBoxContainer.new()
	_skill_detail_panel.add_child(detail_vbox)

	_detail_title = Label.new()
	_detail_title.text = tr("LAB_HOVER_SKILL")
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_vbox.add_child(_detail_title)

	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	detail_vbox.add_child(_detail_desc)

	_detail_cost = Label.new()
	_detail_cost.text = ""
	_detail_cost.add_theme_font_size_override("font_size", 14)
	_detail_cost.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	detail_vbox.add_child(_detail_cost)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func setup(pm: ProgressionManager, em) -> void:
	_progression_manager = pm
	_economy_manager = em

	if em != null:
		em.diamonds_changed.connect(_on_diamonds_changed)
		if _diamonds_label != null:
			_diamonds_label.text = "◆ " + str(em.diamonds)

	_populate_global_upgrades()
	_switch_tab(0)
	# Auto-select first tower
	if _TOWER_KEYS.size() > 0:
		_on_tower_selected(_TOWER_KEYS[0][0] as int)


# ---------------------------------------------------------------------------
# Tab switching
# ---------------------------------------------------------------------------

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	_skill_scroll.visible = (tab == 0)
	_global_scroll.visible = (tab == 1)
	_synergy_scroll.visible = (tab == 2)
	_skill_detail_panel.visible = (tab == 0)

	# Style tab buttons
	_style_tab_inactive(_tab_skills_btn)
	_style_tab_inactive(_tab_globals_btn)
	_style_tab_inactive(_tab_synergies_btn)
	if tab == 0:
		_style_tab_active(_tab_skills_btn)
	elif tab == 1:
		_style_tab_active(_tab_globals_btn)
	elif tab == 2:
		_style_tab_active(_tab_synergies_btn)
		_populate_synergies()


func _style_tab_active(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	style.border_color = Color(0.9, 0.8, 0.2, 0.6)
	style.border_width_bottom = 2
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))


func _style_tab_inactive(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.5)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


# ---------------------------------------------------------------------------
# Tower sidebar selection
# ---------------------------------------------------------------------------

func _on_tower_selected(tower_type: int) -> void:
	_selected_tower_type = tower_type
	_show_skill_tree(tower_type)
	_switch_tab(0)

	# Update header
	for pair in _TOWER_KEYS:
		if pair[0] as int == tower_type:
			var color: Color = _TOWER_COLORS.get(tower_type, Color.WHITE)
			_content_title.text = tr(pair[1] as String)
			_content_title.add_theme_color_override("font_color", color)
			break

	# Style sidebar buttons — card-style with rounded corners
	for i in _tower_buttons.size():
		var tt: int = _TOWER_KEYS[i][0] as int
		var color: Color = _TOWER_COLORS.get(tt, Color.WHITE)
		if tt == tower_type:
			_tower_buttons[i].add_theme_color_override("font_color", Color.WHITE)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.7)
			style.border_color = Color(color.r, color.g, color.b, 0.6)
			style.set_border_width_all(1)
			style.border_width_left = 3
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			style.content_margin_left = 12
			_tower_buttons[i].add_theme_stylebox_override("normal", style)
			_tower_buttons[i].add_theme_stylebox_override("hover", style)
		else:
			_tower_buttons[i].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.06, 0.1, 0.6)
			style.border_color = Color(0.2, 0.2, 0.3, 0.4)
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			style.content_margin_left = 12
			_tower_buttons[i].add_theme_stylebox_override("normal", style)
			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1, 0.5)
			hover.border_color = Color(color.r, color.g, color.b, 0.3)
			hover.set_border_width_all(1)
			hover.set_corner_radius_all(4)
			hover.set_content_margin_all(8)
			hover.content_margin_left = 12
			_tower_buttons[i].add_theme_stylebox_override("hover", hover)


# ---------------------------------------------------------------------------
# Skill tree display
# ---------------------------------------------------------------------------

func _show_skill_tree(tower_type: int) -> void:
	for child in _skill_tree_panel.get_children():
		child.queue_free()

	_clear_skill_detail()

	if _progression_manager == null:
		return

	var tree: SkillTree = _progression_manager._get_skill_tree(tower_type)
	if tree == null:
		return

	var unlocked: Dictionary = _progression_manager._get_unlocked_nodes(tower_type)
	var color: Color = _TOWER_COLORS.get(tower_type, Color.WHITE)

	for node in tree.nodes:
		var sn: SkillNode = node as SkillNode
		var current_level: int = unlocked.get(sn.node_index, 0) as int
		var is_maxed: bool = current_level >= sn.max_level
		var has_levels: bool = current_level > 0

		# Card-style row
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.set_content_margin_all(8)
		card_style.set_corner_radius_all(4)
		if is_maxed:
			card_style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.7)
			card_style.border_color = Color(color.r, color.g, color.b, 0.6)
		elif has_levels:
			card_style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.6)
			card_style.border_color = Color(color.r, color.g, color.b, 0.4)
		else:
			card_style.bg_color = Color(0.06, 0.06, 0.1, 0.6)
			card_style.border_color = Color(0.2, 0.2, 0.3, 0.4)
		card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)
		_skill_tree_panel.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		# Node index badge
		var badge := Label.new()
		badge.text = str(sn.node_index + 1)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(28, 28)
		badge.add_theme_font_size_override("font_size", 14)
		if has_levels:
			badge.add_theme_color_override("font_color", color)
		else:
			badge.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		row.add_child(badge)

		# Skill name + bonuses + level
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vbox)

		# Name row with level indicator
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		info_vbox.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = sn.display_name
		name_lbl.add_theme_font_size_override("font_size", 16)
		if has_levels:
			name_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		name_row.add_child(name_lbl)

		var level_lbl := Label.new()
		level_lbl.text = tr("LAB_SKILL_LEVEL").replace("{0}", str(current_level)).replace("{1}", str(sn.max_level))
		level_lbl.add_theme_font_size_override("font_size", 12)
		if is_maxed:
			level_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		elif has_levels:
			level_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		else:
			level_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		name_row.add_child(level_lbl)

		# Bonus description with current → next or total at max
		var bonus_lbl := Label.new()
		bonus_lbl.add_theme_font_size_override("font_size", 12)
		if is_maxed:
			# Show total effect at max level
			var total_parts: PackedStringArray = PackedStringArray()
			if sn.damage_bonus != 0.0:
				total_parts.append(tr("STAT_DAMAGE") + " +%.1f" % (sn.damage_bonus * float(sn.max_level)))
			if sn.fire_rate_bonus != 0.0:
				total_parts.append(tr("STAT_FIRE_RATE") + " +%.2f" % (sn.fire_rate_bonus * float(sn.max_level)))
			if sn.range_bonus != 0.0:
				total_parts.append(tr("STAT_RANGE") + " +%.0f" % (sn.range_bonus * float(sn.max_level)))
			if sn.special != "":
				total_parts.append(tr("STAT_SPECIAL") + ": %s" % sn.special)
			bonus_lbl.text = "  ".join(total_parts) if total_parts.size() > 0 else tr("LAB_MAX_LEVEL")
			bonus_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			info_vbox.add_child(bonus_lbl)
		elif has_levels:
			# Show current total → next total
			var parts: PackedStringArray = PackedStringArray()
			if sn.damage_bonus != 0.0:
				parts.append(tr("STAT_DAMAGE_SHORT") + " +%.1f → +%.1f" % [sn.damage_bonus * float(current_level), sn.damage_bonus * float(current_level + 1)])
			if sn.fire_rate_bonus != 0.0:
				parts.append(tr("STAT_FIRE_RATE_SHORT") + " +%.2f → +%.2f" % [sn.fire_rate_bonus * float(current_level), sn.fire_rate_bonus * float(current_level + 1)])
			if sn.range_bonus != 0.0:
				parts.append(tr("STAT_RANGE") + " +%.0f → +%.0f" % [sn.range_bonus * float(current_level), sn.range_bonus * float(current_level + 1)])
			if sn.special != "":
				parts.append(tr("STAT_SPECIAL") + ": %s" % sn.special)
			bonus_lbl.text = "  ".join(parts) if parts.size() > 0 else ""
			bonus_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			if bonus_lbl.text != "":
				info_vbox.add_child(bonus_lbl)
		else:
			# Show per-level info for unstarted skills
			var parts: PackedStringArray = PackedStringArray()
			if sn.damage_bonus != 0.0:
				parts.append(tr("LAB_STAT_PER_LEVEL").replace("{stat}", tr("STAT_DAMAGE")).replace("{per}", "%.1f" % sn.damage_bonus).replace("{max}", "%.1f" % (sn.damage_bonus * float(sn.max_level))))
			if sn.fire_rate_bonus != 0.0:
				parts.append(tr("LAB_STAT_PER_LEVEL").replace("{stat}", tr("STAT_FIRE_RATE")).replace("{per}", "%.2f" % sn.fire_rate_bonus).replace("{max}", "%.2f" % (sn.fire_rate_bonus * float(sn.max_level))))
			if sn.range_bonus != 0.0:
				parts.append(tr("LAB_STAT_PER_LEVEL").replace("{stat}", tr("STAT_RANGE")).replace("{per}", "%.0f" % sn.range_bonus).replace("{max}", "%.0f" % (sn.range_bonus * float(sn.max_level))))
			if sn.special != "":
				parts.append(tr("STAT_SPECIAL") + ": %s" % sn.special)
			bonus_lbl.text = "  ".join(parts) if parts.size() > 0 else ""
			bonus_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			if bonus_lbl.text != "":
				info_vbox.add_child(bonus_lbl)

		# Action button
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 40)
		btn.add_theme_font_size_override("font_size", 14)
		if is_maxed:
			btn.text = tr("LAB_MAX")
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else:
			var next_cost: int = tree.get_node_cost(sn.node_index, unlocked)
			btn.text = "◆ %d" % next_cost
			btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			var idx: int = sn.node_index
			var tt: int = tower_type
			btn.pressed.connect(func() -> void:
				AudioManager.play_ui_click()
				_on_skill_unlock(tt, idx)
			)
		row.add_child(btn)

		# Hover for details
		var skill_ref := sn
		var cur_level_ref := current_level
		card.mouse_entered.connect(func() -> void: _show_skill_detail(skill_ref, cur_level_ref))
		card.mouse_exited.connect(func() -> void: _clear_skill_detail())


# ---------------------------------------------------------------------------
# Global upgrades display
# ---------------------------------------------------------------------------

func _populate_global_upgrades() -> void:
	for child in _global_upgrades_panel.get_children():
		child.queue_free()

	if _progression_manager == null:
		return

	for upgrade_id in ProgressionManager.GLOBAL_UPGRADES.keys():
		var tier: int = _progression_manager.get_global_upgrade_tier(upgrade_id)
		var is_maxed: bool = tier >= 10

		# Card
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.set_content_margin_all(8)
		card_style.set_corner_radius_all(4)
		if is_maxed:
			card_style.bg_color = Color(0.1, 0.12, 0.05, 0.6)
			card_style.border_color = Color(0.6, 0.5, 0.0, 0.4)
		else:
			card_style.bg_color = Color(0.06, 0.06, 0.1, 0.6)
			card_style.border_color = Color(0.2, 0.2, 0.3, 0.4)
		card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)
		_global_upgrades_panel.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		# Info
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vbox)

		# Upgrade name (translated)
		var display_name: String = tr("GLOBAL_" + upgrade_id.to_upper())
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color.WHITE if not is_maxed else Color(0.9, 0.8, 0.2))
		info_vbox.add_child(name_lbl)

		# Description and current value
		var per_tier: float = ProgressionManager.GLOBAL_UPGRADES[upgrade_id] as float
		var desc_text: String = _get_upgrade_description(upgrade_id, per_tier, tier)
		var desc_lbl := Label.new()
		desc_lbl.text = desc_text
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5) if tier > 0 else Color(0.4, 0.4, 0.5))
		info_vbox.add_child(desc_lbl)

		# Progress bar (tier X/10)
		var progress_row := HBoxContainer.new()
		progress_row.add_theme_constant_override("separation", 4)
		info_vbox.add_child(progress_row)

		var tier_lbl := Label.new()
		tier_lbl.text = tr("LAB_TIER").replace("{0}", str(tier)).replace("{1}", "10")
		tier_lbl.add_theme_font_size_override("font_size", 12)
		tier_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		progress_row.add_child(tier_lbl)

		# Visual progress dots
		var dots_lbl := Label.new()
		var filled: String = "●".repeat(tier)
		var empty: String = "○".repeat(10 - tier)
		dots_lbl.text = filled + empty
		dots_lbl.add_theme_font_size_override("font_size", 10)
		dots_lbl.clip_text = true
		dots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_maxed:
			dots_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else:
			dots_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		progress_row.add_child(dots_lbl)

		# Action button
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 40)
		btn.add_theme_font_size_override("font_size", 14)
		if is_maxed:
			btn.text = tr("LAB_MAX")
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else:
			var cost_idx: int = mini(tier, Constants.GLOBAL_UPGRADE_COSTS.size() - 1)
			var cost: int = Constants.GLOBAL_UPGRADE_COSTS[cost_idx] as int
			btn.text = "◆ %d" % cost
			btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
			var uid: String = upgrade_id
			btn.pressed.connect(func() -> void:
				AudioManager.play_ui_click()
				_on_global_upgrade(uid)
			)
		row.add_child(btn)


func _get_upgrade_description(upgrade_id: String, per_tier: float, current_tier: int) -> String:
	var current_val: float = per_tier * float(current_tier)
	var next_val: float = per_tier * float(current_tier + 1)
	var is_maxed: bool = current_tier >= 10
	match upgrade_id:
		"starting_gold":
			if is_maxed:
				return tr("LAB_UPGRADE_STARTING_GOLD_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_STARTING_GOLD").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"tower_cost_reduction":
			if is_maxed:
				return tr("LAB_UPGRADE_TOWER_COST_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_TOWER_COST").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"extra_lives":
			if is_maxed:
				return tr("LAB_UPGRADE_EXTRA_LIVES_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_EXTRA_LIVES").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"ability_cooldown":
			if is_maxed:
				return tr("LAB_UPGRADE_ABILITY_CD_MAX").replace("{0}", "%.1f" % current_val)
			return tr("LAB_UPGRADE_ABILITY_CD").replace("{0}", "%.1f" % current_val).replace("{1}", "%.1f" % next_val)
		"adaptation_slowdown":
			if is_maxed:
				return tr("LAB_UPGRADE_ADAPT_DELAY_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_ADAPT_DELAY").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"gold_per_kill":
			if is_maxed:
				return tr("LAB_UPGRADE_GOLD_KILL_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_GOLD_KILL").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"tower_sell_refund":
			if is_maxed:
				return tr("LAB_UPGRADE_SELL_REFUND_MAX").replace("{0}", str(int(current_val)))
			return tr("LAB_UPGRADE_SELL_REFUND").replace("{0}", str(int(current_val))).replace("{1}", str(int(next_val)))
		"hero_duration":
			if is_maxed:
				return tr("LAB_UPGRADE_HERO_DUR_MAX").replace("{0}", "%.1f" % current_val)
			return tr("LAB_UPGRADE_HERO_DUR").replace("{0}", "%.1f" % current_val).replace("{1}", "%.1f" % next_val)
	return tr("LAB_UPGRADE_PER_TIER").replace("{0}", "%.1f" % per_tier)


# ---------------------------------------------------------------------------
# Skill detail panel
# ---------------------------------------------------------------------------

func _show_skill_detail(sn: SkillNode, current_level: int) -> void:
	if _detail_title == null:
		return
	var is_maxed: bool = current_level >= sn.max_level
	_detail_title.text = "%s  (%s)" % [sn.display_name, tr("LAB_SKILL_LEVEL").replace("{0}", str(current_level)).replace("{1}", str(sn.max_level))]
	if is_maxed:
		_detail_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	elif current_level > 0:
		_detail_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		_detail_title.add_theme_color_override("font_color", Color.WHITE)

	var parts: PackedStringArray = PackedStringArray()
	if sn.damage_bonus != 0.0:
		parts.append(tr("LAB_STAT_PER_LVL").replace("{stat}", tr("STAT_DAMAGE")).replace("{0}", "%.1f" % sn.damage_bonus))
	if sn.fire_rate_bonus != 0.0:
		parts.append(tr("LAB_STAT_PER_LVL").replace("{stat}", tr("STAT_FIRE_RATE")).replace("{0}", "%.2f" % sn.fire_rate_bonus))
	if sn.range_bonus != 0.0:
		parts.append(tr("LAB_STAT_PER_LVL").replace("{stat}", tr("STAT_RANGE")).replace("{0}", "%.0f" % sn.range_bonus))
	if sn.special != "":
		parts.append(tr("STAT_SPECIAL") + ": %s" % sn.special)
	if sn.description != "":
		parts.append(sn.description)
	# Show current total bonuses if any levels invested
	if current_level > 0:
		var total_parts: PackedStringArray = PackedStringArray()
		if sn.damage_bonus != 0.0:
			total_parts.append(tr("STAT_DAMAGE") + " +%.1f" % (sn.damage_bonus * float(current_level)))
		if sn.fire_rate_bonus != 0.0:
			total_parts.append(tr("STAT_FIRE_RATE") + " +%.2f" % (sn.fire_rate_bonus * float(current_level)))
		if sn.range_bonus != 0.0:
			total_parts.append(tr("STAT_RANGE") + " +%.0f" % (sn.range_bonus * float(current_level)))
		if total_parts.size() > 0:
			parts.append(tr("LAB_CURRENT_TOTAL") + ": " + ", ".join(total_parts))
	_detail_desc.text = " | ".join(parts) if parts.size() > 0 else tr("LAB_NO_BONUSES")

	if is_maxed:
		_detail_cost.text = tr("LAB_MAX_LEVEL_REACHED")
		_detail_cost.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		# Show cost for next level
		var unlocked: Dictionary = {}
		if _progression_manager != null and _selected_tower_type >= 0:
			unlocked = _progression_manager._get_unlocked_nodes(_selected_tower_type)
		var tree: SkillTree = null
		if _progression_manager != null and _selected_tower_type >= 0:
			tree = _progression_manager._get_skill_tree(_selected_tower_type)
		var next_cost: int = 0
		if tree != null:
			next_cost = tree.get_node_cost(sn.node_index, unlocked)
		_detail_cost.text = tr("LAB_NEXT_COST").replace("{0}", str(next_cost))
		_detail_cost.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))


func _clear_skill_detail() -> void:
	if _detail_title != null:
		_detail_title.text = tr("LAB_HOVER_SKILL")
		_detail_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if _detail_desc != null:
		_detail_desc.text = ""
	if _detail_cost != null:
		_detail_cost.text = ""


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_skill_unlock(tower_type: int, node_index: int) -> void:
	if _progression_manager != null:
		_progression_manager.unlock_skill_node(tower_type, node_index)
	skill_unlock_requested.emit(tower_type, node_index)
	_show_skill_tree(tower_type)


func _on_global_upgrade(upgrade_id: String) -> void:
	if _progression_manager != null:
		_progression_manager.upgrade_global(upgrade_id)
	global_upgrade_requested.emit(upgrade_id)
	_populate_global_upgrades()


func _on_diamonds_changed(new_diamonds: int, _delta: int) -> void:
	if _diamonds_label != null:
		_diamonds_label.text = "◆ " + str(new_diamonds)


# ---------------------------------------------------------------------------
# Synergies tab
# ---------------------------------------------------------------------------

const _SYNERGY_DEFS: Array = [
	{"type": Enums.SynergyType.SHATTER, "name_key": "SYNERGY_SHATTER", "pair_key": "SYNERGY_SHATTER_PAIR", "effect_key": "SYNERGY_SHATTER_EFFECT"},
	{"type": Enums.SynergyType.BARRAGE, "name_key": "SYNERGY_BARRAGE", "pair_key": "SYNERGY_BARRAGE_PAIR", "effect_key": "SYNERGY_BARRAGE_EFFECT"},
	{"type": Enums.SynergyType.AMPLIFY, "name_key": "SYNERGY_AMPLIFY", "pair_key": "SYNERGY_AMPLIFY_PAIR", "effect_key": "SYNERGY_AMPLIFY_EFFECT"},
	{"type": Enums.SynergyType.FROSTBITE, "name_key": "SYNERGY_FROSTBITE", "pair_key": "SYNERGY_FROSTBITE_PAIR", "effect_key": "SYNERGY_FROSTBITE_EFFECT"},
	{"type": Enums.SynergyType.EFFICIENCY, "name_key": "SYNERGY_EFFICIENCY", "pair_key": "SYNERGY_EFFICIENCY_PAIR", "effect_key": "SYNERGY_EFFICIENCY_EFFECT"},
	{"type": Enums.SynergyType.COLD_SNAP, "name_key": "SYNERGY_COLD_SNAP", "pair_key": "SYNERGY_COLD_SNAP_PAIR", "effect_key": "SYNERGY_COLD_SNAP_EFFECT"},
	{"type": Enums.SynergyType.CONDUIT, "name_key": "SYNERGY_CONDUIT", "pair_key": "SYNERGY_CONDUIT_PAIR", "effect_key": "SYNERGY_CONDUIT_EFFECT"},
	{"type": Enums.SynergyType.FOCUS_FIRE, "name_key": "SYNERGY_FOCUS_FIRE", "pair_key": "SYNERGY_FOCUS_FIRE_PAIR", "effect_key": "SYNERGY_FOCUS_FIRE_EFFECT"},
]

func _populate_synergies() -> void:
	if _synergy_panel == null:
		return
	for child in _synergy_panel.get_children():
		child.queue_free()

	var discovered: Array = SaveManager.data.get("progression", {}).get("synergies_discovered", [])

	for syn in _SYNERGY_DEFS:
		var syn_name: String = tr(syn["name_key"] as String)
		var syn_type: int = syn["type"] as int
		var is_found: bool = discovered.has(syn_type)

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.07, 0.12, 0.9) if is_found else Color(0.04, 0.04, 0.06, 0.7)
		card_style.border_color = Color(0.9, 0.8, 0.2, 0.5) if is_found else Color(0.3, 0.3, 0.3, 0.3)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card_style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", card_style)
		_synergy_panel.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 16)
		if is_found:
			title.text = syn_name
			title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else:
			title.text = tr("UI_SYNERGY_UNDISCOVERED")
			title.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(title)

		var pair_lbl := Label.new()
		pair_lbl.add_theme_font_size_override("font_size", 13)
		if is_found:
			pair_lbl.text = tr(syn["pair_key"] as String)
			pair_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		else:
			pair_lbl.text = tr("LAB_SYNERGY_UNKNOWN")
			pair_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		vbox.add_child(pair_lbl)

		if is_found:
			var effect_lbl := Label.new()
			effect_lbl.text = tr(syn["effect_key"] as String)
			effect_lbl.add_theme_font_size_override("font_size", 12)
			effect_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(effect_lbl)
