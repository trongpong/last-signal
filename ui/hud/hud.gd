class_name HUD
extends CanvasLayer

## Main HUD assembly. Owns TopBar, TowerBar, TowerUpgradePanel, and AbilityBar.
## Call bind_signals() with manager references to wire everything together.

# ---------------------------------------------------------------------------
# Signals (forwarded outward to the game scene)
# ---------------------------------------------------------------------------

signal build_tower_requested(tower_type: int)
signal upgrade_tower_requested(tower: Tower, choice: int)
signal sell_tower_requested(tower: Tower)
signal send_wave_requested
signal ability_used(slot: int)
signal hero_summon_requested
signal pause_requested

# ---------------------------------------------------------------------------
# Child nodes
# ---------------------------------------------------------------------------

var _top_bar: TopBar
var _tower_bar: TowerBar
var _upgrade_panel: TowerUpgradePanel
var _ability_bar: AbilityBar
var _send_wave_btn: Button
var _break_countdown_label: Label
var _break_remaining: float = 0.0
var _break_active: bool = false
var _break_paused: bool = false
var _adaptation_warning: Label
var _resistance_panel: VBoxContainer
var _resistance_bars: Dictionary = {}  # DamageType -> ProgressBar
var _root: Control
var tower_bar_total: float = 72.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_hud()

func _process(delta: float) -> void:
	if _break_active and not _break_paused and _break_countdown_label != null:
		_break_remaining -= delta
		if _break_remaining <= 0.0:
			_break_remaining = 0.0
			_break_active = false
			_break_countdown_label.visible = false
		else:
			_break_countdown_label.text = "%ds" % ceili(_break_remaining)
			_break_countdown_label.visible = true


func _get_safe_margin() -> float:
	## Returns horizontal safe area margin for rounded screen corners.
	## Falls back to a sensible default (16px) on devices without safe area info.
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	var left_inset: float = safe_area.position.x
	var top_inset: float = safe_area.position.y
	var right_inset: float = maxf(screen_size.x - safe_area.end.x, 0.0)
	var margin: float = maxf(maxf(left_inset, right_inset), maxf(top_inset, 0.0))
	# Use at least 16px on any device for comfort, cap at 48px
	return clampf(margin, 16.0, 48.0)


func _build_hud() -> void:
	# Root control that fills the viewport
	_root = Control.new()
	var root := _root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var safe: float = _get_safe_margin()

	# Detect top safe area inset (status bar, notch, rounded corners)
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	var top_inset: float = maxf(safe_area.position.y, 8.0)
	var bot_inset: float = maxf(screen_size.y - safe_area.end.y, 0.0)

	# Top bar background (semi-transparent dark)
	var top_bar_bg := ColorRect.new()
	top_bar_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	top_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar_bg.anchor_top = 0.0
	top_bar_bg.anchor_bottom = 0.0
	top_bar_bg.offset_top = 0.0
	top_bar_bg.offset_bottom = top_inset + 56.0
	top_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar_bg)

	# Top bar (pushed down by top inset for status bar / rounded corners)
	_top_bar = TopBar.new()
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_top = top_inset
	_top_bar.offset_bottom = top_inset + 56.0
	_top_bar.offset_left = safe
	_top_bar.offset_right = -safe
	root.add_child(_top_bar)
	_top_bar.speed_changed.connect(_on_speed_changed)
	_top_bar.toast_requested.connect(show_toast)
	_top_bar.pause_requested.connect(func() -> void: pause_requested.emit())

	# Gold border line under top bar (1px)
	var top_bar_border := ColorRect.new()
	top_bar_border.color = Color(0.8, 0.7, 0.2, 0.5)
	top_bar_border.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar_border.anchor_top = 0.0
	top_bar_border.anchor_bottom = 0.0
	top_bar_border.offset_top = top_inset + 56.0
	top_bar_border.offset_bottom = top_inset + 57.0
	top_bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar_border)

	# Gold border line above tower bar (1px)
	var tower_bar_border := ColorRect.new()
	tower_bar_border.color = Color(0.8, 0.7, 0.2, 0.5)
	tower_bar_border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tower_bar_border.anchor_top = 1.0
	tower_bar_border.anchor_bottom = 1.0
	tower_bar_border.offset_top = -(73.0 + bot_inset)
	tower_bar_border.offset_bottom = -(72.0 + bot_inset)
	tower_bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tower_bar_border)

	# Tower bar background (semi-transparent dark, extended to screen bottom)
	var tower_bar_bg := ColorRect.new()
	tower_bar_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	tower_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tower_bar_bg.anchor_top = 1.0
	tower_bar_bg.anchor_bottom = 1.0
	tower_bar_bg.offset_top = -(72.0 + bot_inset)
	tower_bar_bg.offset_bottom = 0.0
	tower_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tower_bar_bg)

	# Tower bar (pushed up by bottom inset for navigation bar / rounded corners)
	_tower_bar = TowerBar.new()
	_tower_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tower_bar.anchor_top = 1.0
	_tower_bar.anchor_bottom = 1.0
	_tower_bar.offset_top = -(72.0 + bot_inset)
	_tower_bar.offset_bottom = -bot_inset
	_tower_bar.offset_left = safe
	_tower_bar.offset_right = -safe
	root.add_child(_tower_bar)
	_tower_bar.tower_build_requested.connect(_on_build_requested)

	tower_bar_total = 72.0 + bot_inset

	# Tower upgrade panel (slides up from bottom, centered 70% width, hidden by default)
	_upgrade_panel = TowerUpgradePanel.new()
	_upgrade_panel.anchor_top = 1.0
	_upgrade_panel.anchor_bottom = 1.0
	_upgrade_panel.anchor_left = 0.15
	_upgrade_panel.anchor_right = 0.85
	_upgrade_panel.offset_top = -(300.0 + bot_inset)
	_upgrade_panel.offset_bottom = -tower_bar_total
	root.add_child(_upgrade_panel)
	_upgrade_panel.upgrade_requested.connect(_on_upgrade_requested)
	_upgrade_panel.sell_requested.connect(_on_sell_requested)
	_upgrade_panel.targeting_changed.connect(_on_targeting_changed)

	# Ability bar (vertical stack, bottom-left, above tower bar)
	_ability_bar = AbilityBar.new()
	_ability_bar.anchor_left = 0.0
	_ability_bar.anchor_right = 0.0
	_ability_bar.anchor_top = 1.0
	_ability_bar.anchor_bottom = 1.0
	_ability_bar.offset_left = safe
	_ability_bar.offset_right = safe + 80.0
	_ability_bar.offset_bottom = -tower_bar_total
	_ability_bar.offset_top = -(tower_bar_total + 210.0)
	root.add_child(_ability_bar)
	_ability_bar.ability_activated.connect(_on_ability_used)
	_ability_bar.hero_summoned.connect(_on_hero_summon)

	# Send wave button (bottom-right, above tower bar, 140x56)
	_send_wave_btn = Button.new()
	_send_wave_btn.text = tr("HUD_SEND_WAVE")
	_send_wave_btn.add_theme_font_size_override("font_size", 18)
	_send_wave_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_send_wave_btn.custom_minimum_size = Vector2(140, 56)
	_send_wave_btn.anchor_bottom = 1.0
	_send_wave_btn.anchor_right = 1.0
	_send_wave_btn.anchor_top = 1.0
	_send_wave_btn.anchor_left = 1.0
	_send_wave_btn.offset_bottom = -tower_bar_total
	_send_wave_btn.offset_top = -tower_bar_total - 56.0
	_send_wave_btn.offset_right = -safe
	_send_wave_btn.offset_left = -140.0 - safe
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)
	root.add_child(_send_wave_btn)

	# Break countdown label (above send wave button)
	_break_countdown_label = Label.new()
	_break_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_break_countdown_label.add_theme_font_size_override("font_size", 14)
	_break_countdown_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_break_countdown_label.anchor_top = 1.0
	_break_countdown_label.anchor_bottom = 1.0
	_break_countdown_label.anchor_left = 1.0
	_break_countdown_label.anchor_right = 1.0
	_break_countdown_label.offset_bottom = -tower_bar_total - 58.0
	_break_countdown_label.offset_top = -tower_bar_total - 76.0
	_break_countdown_label.offset_right = -safe
	_break_countdown_label.offset_left = -140.0 - safe
	_break_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_break_countdown_label.visible = false
	root.add_child(_break_countdown_label)

	# Adaptation warning label (centre screen, hidden by default)
	_adaptation_warning = Label.new()
	_adaptation_warning.text = tr("ENDLESS_RESISTANCE")
	_adaptation_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_adaptation_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_adaptation_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_adaptation_warning.hide()
	root.add_child(_adaptation_warning)

	# Resistance meter panel (collapsible, top-right)
	_build_resistance_panel(root, safe, top_inset)

func _build_resistance_panel(root: Control, safe: float = 16.0, top_inset: float = 8.0) -> void:
	_resistance_panel = VBoxContainer.new()
	_resistance_panel.anchor_left = 1.0
	_resistance_panel.anchor_right = 1.0
	_resistance_panel.anchor_top = 0.0
	_resistance_panel.anchor_bottom = 0.0
	_resistance_panel.offset_left = -160.0 - safe
	_resistance_panel.offset_right = -safe
	_resistance_panel.offset_top = top_inset + 60.0
	_resistance_panel.offset_bottom = 250.0
	_resistance_panel.add_theme_constant_override("separation", 2)
	_resistance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resistance_panel.visible = false
	root.add_child(_resistance_panel)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resistance_panel.add_child(bg)
	_resistance_panel.move_child(bg, 0)

	# Header label
	var header := Label.new()
	header.text = tr("UI_RESISTANCE")
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resistance_panel.add_child(header)

	# Colored bars per damage type
	var type_info: Array = [
		[Enums.DamageType.PULSE, "Pulse", Color(0.0, 1.0, 1.0)],
		[Enums.DamageType.ARC, "Arc", Color(0.267, 0.533, 1.0)],
		[Enums.DamageType.CRYO, "Cryo", Color(0.7, 0.9, 1.0)],
		[Enums.DamageType.MISSILE, "Missile", Color(1.0, 0.647, 0.0)],
		[Enums.DamageType.BEAM, "Beam", Color(0.502, 0.0, 0.502)],
	]
	for info in type_info:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_resistance_panel.add_child(row)

		var lbl := Label.new()
		lbl.text = info[1] as String
		lbl.custom_minimum_size = Vector2(42, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", info[2] as Color)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 75.0
		bar.value = 0.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(80, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		bar_style.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bar_style)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = info[2] as Color
		fill_style.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill_style)
		row.add_child(bar)

		var pct := Label.new()
		pct.text = "0%"
		pct.custom_minimum_size = Vector2(30, 0)
		pct.add_theme_font_size_override("font_size", 11)
		pct.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pct)

		_resistance_bars[info[0] as int] = {"bar": bar, "label": pct}


## Update the resistance meter with current adaptation values.
func update_resistance_meter(resistances: Dictionary) -> void:
	var any_active: bool = false
	for dtype in _resistance_bars.keys():
		var res_val: float = resistances.get(dtype, 0.0) as float
		var entry: Dictionary = _resistance_bars[dtype] as Dictionary
		(entry["bar"] as ProgressBar).value = res_val * 100.0
		(entry["label"] as Label).text = "%d%%" % int(res_val * 100.0)
		if res_val > 0.0:
			any_active = true
	_resistance_panel.visible = any_active


# ---------------------------------------------------------------------------
# Manager binding
# ---------------------------------------------------------------------------

## Connect HUD to manager signals.
## gm: GameManager, em: EconomyManager, wm: WaveManager
func bind_signals(gm, em, wm: WaveManager) -> void:
	# GameManager
	gm.lives_changed.connect(_on_lives_changed)
	gm.state_changed.connect(_on_state_changed)

	# EconomyManager
	em.gold_changed.connect(_on_gold_changed)

	# WaveManager
	wm.wave_started.connect(_on_wave_started)
	wm.wave_complete.connect(_on_wave_complete)
	wm.break_started.connect(_on_break_started)

	# Seed initial values
	_top_bar.update_lives(gm.lives)
	_top_bar.update_gold(em.gold)
	_top_bar.update_wave(wm.current_wave_index + 1, wm.total_waves)
	if _send_wave_btn != null:
		_send_wave_btn.disabled = false

# ---------------------------------------------------------------------------
# Tower selection
# ---------------------------------------------------------------------------

## Show the upgrade panel for the given tower.
func show_upgrade_panel(tower: Tower, sell_value: int) -> void:
	_upgrade_panel.show_for_tower(tower, sell_value)


## Hide the upgrade panel.
func hide_upgrade_panel() -> void:
	_upgrade_panel.hide_panel()


## Returns true if the viewport-space position falls on a visible interactive overlay.
## Used by the game scene to filter clicks that should not place towers.
func is_point_on_overlay(pos: Vector2) -> bool:
	var overlays: Array[Control] = [
		_upgrade_panel,
		_ability_bar,
		_send_wave_btn,
	]
	for overlay in overlays:
		if overlay != null and overlay.visible:
			if Rect2(overlay.global_position, overlay.size).has_point(pos):
				return true
	return false

# ---------------------------------------------------------------------------
# Adaptation warning
# ---------------------------------------------------------------------------

## Show or hide the adaptation warning banner.
func show_adaptation_warning(visible: bool) -> void:
	if _adaptation_warning != null:
		_adaptation_warning.visible = visible


## Show a temporary toast message at the top-center of the screen.
func show_toast(message: String) -> void:
	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 70.0
	toast.offset_bottom = 100.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(toast)
	var tw := toast.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)

# ---------------------------------------------------------------------------
# Tower / Ability bar control
# ---------------------------------------------------------------------------

## Highlight the selected tower type in the tower bar.
func select_tower_type(tower_type: int) -> void:
	_tower_bar.select_tower(tower_type)


## Clear tower selection highlight.
func deselect_tower_type() -> void:
	_tower_bar.deselect_all()


## Populate the tower bar with available definitions and unlocked ids.
func populate_tower_bar(definitions: Array, unlocked: Array) -> void:
	_tower_bar.populate(definitions, unlocked)


## Update displayed tower costs with a discount percentage.
func update_tower_bar_costs(discount_percent: int) -> void:
	_tower_bar.apply_cost_discount(discount_percent)


## Set which speed options are available based on unlocks.
func set_available_speeds(has_x2: bool, has_x3: bool) -> void:
	_top_bar.set_available_speeds(has_x2, has_x3)


## Setup ability bar loadout.
func setup_ability_bar(ability_ids: Array, hero_available: bool) -> void:
	_ability_bar.setup(ability_ids, hero_available)


## Forward cooldown refresh to ability bar.
func update_ability_cooldowns(abilities: Array) -> void:
	_ability_bar.update_cooldowns(abilities)

# ---------------------------------------------------------------------------
# Private callbacks — manager signals
# ---------------------------------------------------------------------------

func _on_lives_changed(new_lives: int, _lost: int) -> void:
	_top_bar.update_lives(new_lives)


func _on_gold_changed(new_gold: int, _delta: int) -> void:
	_top_bar.update_gold(new_gold)
	_tower_bar.update_gold(new_gold)


func _on_wave_started(wave_number: int, total_waves: int) -> void:
	_top_bar.update_wave(wave_number, total_waves)
	if _send_wave_btn != null:
		_send_wave_btn.disabled = true
	_break_active = false
	if _break_countdown_label != null:
		_break_countdown_label.visible = false


func _on_wave_complete(_wave_number: int) -> void:
	pass  # break_started will enable the send button


func pause_break_countdown() -> void:
	_break_paused = true

func unpause_break_countdown() -> void:
	_break_paused = false

func _on_break_started(duration: float) -> void:
	if _send_wave_btn != null:
		_send_wave_btn.disabled = false
	_break_remaining = duration
	_break_active = true
	_break_paused = false


func _on_state_changed(new_state: int, _old_state: int) -> void:
	match new_state:
		Enums.GameState.BUILDING:
			_tower_bar.show()
			if _send_wave_btn != null:
				_send_wave_btn.disabled = false
		Enums.GameState.WAVE_ACTIVE:
			_tower_bar.show()
			if _send_wave_btn != null:
				_send_wave_btn.disabled = true
		Enums.GameState.WAVE_COMPLETE:
			if _send_wave_btn != null:
				_send_wave_btn.disabled = false
		_:
			pass

# ---------------------------------------------------------------------------
# Private callbacks — child widget signals
# ---------------------------------------------------------------------------

func _on_send_wave_pressed() -> void:
	AudioManager.play_ui_click()
	send_wave_requested.emit()


func _on_speed_changed(speed: float) -> void:
	GameManager.game_speed = speed
	Engine.time_scale = speed


func _on_build_requested(tower_type: int) -> void:
	build_tower_requested.emit(tower_type)


func _on_upgrade_requested(tower: Tower, choice: int) -> void:
	upgrade_tower_requested.emit(tower, choice)


func _on_sell_requested(tower: Tower) -> void:
	sell_tower_requested.emit(tower)


func _on_targeting_changed(_tower: Tower, _mode: int) -> void:
	# Tower targeting is already applied by TowerUpgradePanel before emitting the signal.
	pass


func _on_ability_used(slot: int) -> void:
	ability_used.emit(slot)


func _on_hero_summon() -> void:
	hero_summon_requested.emit()
