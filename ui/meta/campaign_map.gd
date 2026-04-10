class_name CampaignMap
extends Control

## Campaign map screen with region tabs and per-region level grids.
## Each region is a chapter shown when its tab is selected.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal level_chosen(level_id: String, difficulty: int)
signal back_pressed

# ---------------------------------------------------------------------------
# Difficulty options — must match Enums.Difficulty order
# ---------------------------------------------------------------------------

const _DIFFICULTY_KEYS: Array = [
	"DIFFICULTY_NORMAL",
	"DIFFICULTY_HARD",
	"DIFFICULTY_NIGHTMARE",
]

const _DIFFICULTY_COLORS: Array = [
	Color(0.3, 0.8, 0.3),   # Normal: green
	Color(1.0, 0.6, 0.1),   # Hard: orange
	Color(1.0, 0.2, 0.2),   # Nightmare: red
]

# ---------------------------------------------------------------------------
# Region colors for tab/header styling
# ---------------------------------------------------------------------------

const _REGION_COLORS: Array = [
	Color(0.3, 0.7, 0.4),   # Region 1: green
	Color(0.3, 0.5, 0.9),   # Region 2: blue
	Color(0.7, 0.4, 0.8),   # Region 3: purple
	Color(0.9, 0.5, 0.2),   # Region 4: orange
	Color(0.9, 0.2, 0.2),   # Region 5: red
]

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------

var _difficulty_option: OptionButton
var _region_tabs: VBoxContainer
var _region_panels: Array[Control] = []
var _region_buttons: Array[Button] = []
var _current_region: int = 0
var _level_container: Control
var _region_title_label: Label
var _region_progress_label: Label
var _save_data: Dictionary = {}
var _all_levels: Array = []
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

	# Dark background
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

	# ---- LEFT SIDEBAR: region list + difficulty ----
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(220, 0)
	sidebar.add_theme_constant_override("separation", 0)
	main_hbox.add_child(sidebar)

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
	inner.add_theme_constant_override("separation", 4)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_margin.add_child(inner)

	# Title in sidebar
	var title := Label.new()
	title.text = tr("UI_LEVEL_SELECT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	title.custom_minimum_size = Vector2(0, 40)
	inner.add_child(title)

	# Separator
	var sep1 := HSeparator.new()
	inner.add_child(sep1)

	# Region buttons (vertical list)
	var region_label := Label.new()
	region_label.text = tr("UI_REGIONS")
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.add_theme_font_size_override("font_size", 12)
	region_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	inner.add_child(region_label)

	_region_tabs = VBoxContainer.new()
	_region_tabs.add_theme_constant_override("separation", 2)
	inner.add_child(_region_tabs)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	# Separator
	var sep2 := HSeparator.new()
	inner.add_child(sep2)

	# Difficulty selector
	var diff_label := Label.new()
	diff_label.text = tr("UI_DIFFICULTY")
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 12)
	diff_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	inner.add_child(diff_label)

	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size = Vector2(0, 44)
	_difficulty_option.add_theme_font_size_override("font_size", 16)
	for key in _DIFFICULTY_KEYS:
		_difficulty_option.add_item(tr(key))
	_difficulty_option.selected = 0
	_difficulty_option.item_selected.connect(_on_difficulty_changed)
	inner.add_child(_difficulty_option)

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

	# Vertical separator line
	var vsep := ColorRect.new()
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsep.color = Color(0.3, 0.3, 0.3, 0.3)
	vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_hbox.add_child(vsep)

	# ---- RIGHT: level grid area ----
	# Margin wrapper for content area padding
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	main_hbox.add_child(content_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	content_margin.add_child(right_vbox)

	# Region header bar
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 12)
	right_vbox.add_child(header)

	_region_title_label = Label.new()
	_region_title_label.text = ""
	_region_title_label.add_theme_font_size_override("font_size", 24)
	_region_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_region_title_label)

	_region_progress_label = Label.new()
	_region_progress_label.text = ""
	_region_progress_label.add_theme_font_size_override("font_size", 16)
	_region_progress_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(_region_progress_label)

	# Separator under header
	var sep3 := HSeparator.new()
	right_vbox.add_child(sep3)

	# Level container (holds one region panel at a time)
	_level_container = Control.new()
	_level_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_level_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_level_container)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Populate level nodes grouped by region.
func populate(levels: Array, save_data: Dictionary) -> void:
	_save_data = save_data
	_all_levels = levels
	_rebuild_levels()


func _rebuild_levels() -> void:
	# Clear existing panels and buttons
	for panel in _region_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	_region_panels.clear()
	for btn in _region_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_region_buttons.clear()

	# Group levels by region
	var regions: Dictionary = {}
	for level_def in _all_levels:
		var region: int = level_def.get("region", 1) as int
		var region_name: String = level_def.get("region_name", "Region %d" % region) as String
		if not regions.has(region):
			regions[region] = {"name": region_name, "levels": []}
		regions[region]["levels"].append(level_def)

	var completed: Dictionary = _save_data.get("levels_completed", {})
	var selected_diff: int = _difficulty_option.selected
	var region_keys: Array = regions.keys()
	region_keys.sort()

	for region_num in region_keys:
		var region_data: Dictionary = regions[region_num]
		var region_name: String = region_data["name"]
		var region_levels: Array = region_data["levels"]
		var idx: int = _region_panels.size()
		var color: Color = _REGION_COLORS[mini(idx, _REGION_COLORS.size() - 1)]

		# Count completed levels in this region for selected difficulty
		var completed_count: int = 0
		for ldef in region_levels:
			var lid: String = ldef.get("id", "") as String
			if _is_level_completed(completed, lid, selected_diff):
				completed_count += 1

		# Tab button in sidebar
		var tab_btn := Button.new()
		tab_btn.text = "  %d. %s" % [region_num, region_name]
		tab_btn.custom_minimum_size = Vector2(0, 40)
		tab_btn.add_theme_font_size_override("font_size", 14)
		tab_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tab_idx: int = idx
		tab_btn.pressed.connect(func() -> void:
			AudioManager.play_ui_click()
			_select_region(tab_idx)
		)

		# Show completion badge
		if completed_count == region_levels.size():
			tab_btn.text += "  ★"

		_region_tabs.add_child(tab_btn)
		_region_buttons.append(tab_btn)

		# Panel with centered grid for this region
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		# Transparent panel bg
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		panel.add_theme_stylebox_override("panel", panel_style)

		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(scroll)

		var center_container := VBoxContainer.new()
		center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_container.alignment = BoxContainer.ALIGNMENT_CENTER
		scroll.add_child(center_container)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center_container.add_child(grid)

		# Populate levels — check completion per selected difficulty
		var prev_completed: bool = true
		if region_num > 1:
			var prev_region_levels: Array = regions.get(region_num - 1, {}).get("levels", [])
			if prev_region_levels.size() > 0:
				var prev_last_id: String = prev_region_levels[-1].get("id", "") as String
				prev_completed = _is_level_completed(completed, prev_last_id, selected_diff)
			else:
				prev_completed = false

		for level_def in region_levels:
			var id: String = level_def.get("id", "") as String
			var level_num: int = level_def.get("level_number", 0) as int
			var is_boss: bool = level_def.get("is_boss_level", false) as bool
			var display: String = "%d-%d" % [region_num, level_num]
			if is_boss:
				display += "\n" + tr("UI_BOSS")
			var diff_record: Dictionary = _get_diff_record(completed, id, selected_diff)
			var stars: int = diff_record.get("best_stars", 0) as int
			var locked: bool = not prev_completed

			var node := LevelNode.new()
			node.custom_minimum_size = Vector2(88, 80)
			node.setup(id, display, stars, locked)
			node.level_selected.connect(_on_level_selected)
			grid.add_child(node)

			prev_completed = _is_level_completed(completed, id, selected_diff)

		# Store metadata for header display
		panel.set_meta("region_name", region_name)
		panel.set_meta("region_color", color)
		panel.set_meta("completed", completed_count)
		panel.set_meta("total", region_levels.size())

		_level_container.add_child(panel)
		_region_panels.append(panel)

	# Select first region
	if _region_panels.size() > 0:
		_select_region(0)


func _select_region(idx: int) -> void:
	_current_region = idx
	for i in _region_panels.size():
		_region_panels[i].visible = (i == idx)

	# Update header
	if idx < _region_panels.size():
		var panel: Control = _region_panels[idx]
		var color: Color = panel.get_meta("region_color", Color.WHITE)
		var rname: String = panel.get_meta("region_name", "")
		var done: int = panel.get_meta("completed", 0)
		var total: int = panel.get_meta("total", 0)

		_region_title_label.text = rname
		_region_title_label.add_theme_color_override("font_color", color)

		_region_progress_label.text = tr("UI_PROGRESS_COMPLETED").replace("{0}", str(done)).replace("{1}", str(total))
		if done == total and total > 0:
			_region_progress_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			_region_progress_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Style sidebar tabs
	for i in _region_buttons.size():
		var color: Color = _REGION_COLORS[mini(i, _REGION_COLORS.size() - 1)]
		if i == idx:
			_region_buttons[i].add_theme_color_override("font_color", Color.WHITE)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(color.r, color.g, color.b, 0.25)
			style.set_border_width_all(0)
			style.border_width_left = 3
			style.border_color = color
			style.set_content_margin_all(6)
			style.content_margin_left = 10
			_region_buttons[i].add_theme_stylebox_override("normal", style)
			_region_buttons[i].add_theme_stylebox_override("hover", style)
		else:
			_region_buttons[i].add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			style.set_border_width_all(0)
			style.set_content_margin_all(6)
			style.content_margin_left = 10
			_region_buttons[i].add_theme_stylebox_override("normal", style)
			var hover_style := StyleBoxFlat.new()
			hover_style.bg_color = Color(color.r, color.g, color.b, 0.1)
			hover_style.set_border_width_all(0)
			hover_style.set_content_margin_all(6)
			hover_style.content_margin_left = 10
			_region_buttons[i].add_theme_stylebox_override("hover", hover_style)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_level_selected(level_id: String) -> void:
	var difficulty: int = _difficulty_option.selected
	level_chosen.emit(level_id, difficulty)


func _on_difficulty_changed(_index: int) -> void:
	# Rebuild level display for new difficulty
	var saved_region: int = _current_region
	_rebuild_levels()
	if saved_region < _region_panels.size():
		_select_region(saved_region)


## Check if a level is completed at a specific difficulty.
## Handles both old flat format and new per-difficulty format.
func _is_level_completed(completed: Dictionary, level_id: String, difficulty: int) -> bool:
	if not completed.has(level_id):
		return false
	var level_data = completed[level_id]
	if not (level_data is Dictionary):
		return false
	var diff_key: String = str(difficulty)
	# New per-difficulty format: level_data[str(difficulty)] = { completed, best_stars }
	if level_data.has(diff_key):
		return (level_data[diff_key] as Dictionary).get("completed", false) as bool
	# Old flat format fallback: level_data = { completed, best_stars, best_difficulty }
	if level_data.has("completed"):
		return level_data.get("completed", false) as bool
	return false


## Get the record for a level at a specific difficulty.
func _get_diff_record(completed: Dictionary, level_id: String, difficulty: int) -> Dictionary:
	if not completed.has(level_id):
		return {}
	var level_data = completed[level_id]
	if not (level_data is Dictionary):
		return {}
	var diff_key: String = str(difficulty)
	if level_data.has(diff_key):
		return (level_data[diff_key] as Dictionary).duplicate(true)
	# Old flat format fallback
	if level_data.has("best_stars"):
		return level_data.duplicate(true)
	return {}
