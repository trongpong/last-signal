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

# ---------------------------------------------------------------------------
# Child nodes
# ---------------------------------------------------------------------------

var _top_bar: TopBar
var _tower_bar: TowerBar
var _upgrade_panel: TowerUpgradePanel
var _ability_bar: AbilityBar
var _send_wave_btn: Button
var _adaptation_warning: Label
var _root: Control

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_hud()


func _build_hud() -> void:
	# Root control that fills the viewport
	_root = Control.new()
	var root := _root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top bar background (semi-transparent dark)
	var top_bar_bg := ColorRect.new()
	top_bar_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	top_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar_bg.anchor_top = 0.0
	top_bar_bg.anchor_bottom = 0.0
	top_bar_bg.offset_top = 0.0
	top_bar_bg.offset_bottom = 56.0
	top_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar_bg)

	# Top bar (anchored to top, 56px height, with horizontal padding)
	_top_bar = TopBar.new()
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_top = 0.0
	_top_bar.offset_bottom = 56.0
	_top_bar.offset_left = 4.0
	_top_bar.offset_right = -4.0
	root.add_child(_top_bar)
	_top_bar.speed_changed.connect(_on_speed_changed)
	_top_bar.toast_requested.connect(show_toast)

	# Gold border line under top bar (1px)
	var top_bar_border := ColorRect.new()
	top_bar_border.color = Color(0.8, 0.7, 0.2, 0.5)
	top_bar_border.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar_border.anchor_top = 0.0
	top_bar_border.anchor_bottom = 0.0
	top_bar_border.offset_top = 56.0
	top_bar_border.offset_bottom = 57.0
	top_bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar_border)

	# Gold border line above tower bar (1px)
	var tower_bar_border := ColorRect.new()
	tower_bar_border.color = Color(0.8, 0.7, 0.2, 0.5)
	tower_bar_border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tower_bar_border.anchor_top = 1.0
	tower_bar_border.anchor_bottom = 1.0
	tower_bar_border.offset_top = -73.0
	tower_bar_border.offset_bottom = -72.0
	tower_bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tower_bar_border)

	# Tower bar background (semi-transparent dark)
	var tower_bar_bg := ColorRect.new()
	tower_bar_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	tower_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tower_bar_bg.anchor_top = 1.0
	tower_bar_bg.anchor_bottom = 1.0
	tower_bar_bg.offset_top = -72.0
	tower_bar_bg.offset_bottom = 0.0
	tower_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tower_bar_bg)

	# Tower bar (anchored to bottom, 72px height)
	_tower_bar = TowerBar.new()
	_tower_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tower_bar.anchor_top = 1.0
	_tower_bar.anchor_bottom = 1.0
	_tower_bar.offset_top = -72.0
	_tower_bar.offset_bottom = 0.0
	root.add_child(_tower_bar)
	_tower_bar.tower_build_requested.connect(_on_build_requested)

	# Tower upgrade panel (slides up from bottom, centered 70% width, hidden by default)
	_upgrade_panel = TowerUpgradePanel.new()
	_upgrade_panel.anchor_top = 1.0
	_upgrade_panel.anchor_bottom = 1.0
	_upgrade_panel.anchor_left = 0.15
	_upgrade_panel.anchor_right = 0.85
	_upgrade_panel.offset_top = -300.0
	_upgrade_panel.offset_bottom = -72.0
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
	_ability_bar.offset_left = 0.0
	_ability_bar.offset_right = 80.0
	_ability_bar.offset_bottom = -72.0
	# offset_top is set dynamically after ability buttons are created;
	# use a default that accommodates ~3 ability slots (3 * 64 + margins)
	_ability_bar.offset_top = -(72.0 + 210.0)
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
	_send_wave_btn.offset_bottom = -72.0
	_send_wave_btn.offset_top = -72.0 - 56.0
	_send_wave_btn.offset_right = 0.0
	_send_wave_btn.offset_left = -140.0
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)
	root.add_child(_send_wave_btn)

	# Adaptation warning label (centre screen, hidden by default)
	_adaptation_warning = Label.new()
	_adaptation_warning.text = tr("ENDLESS_RESISTANCE")
	_adaptation_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_adaptation_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_adaptation_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_adaptation_warning.hide()
	root.add_child(_adaptation_warning)

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
	var tw := create_tween()
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


func _on_wave_complete(_wave_number: int) -> void:
	pass  # break_started will enable the send button


func _on_break_started(_duration: float) -> void:
	if _send_wave_btn != null:
		_send_wave_btn.disabled = false


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
	send_wave_requested.emit()


func _on_speed_changed(speed: float) -> void:
	Engine.time_scale = speed


func _on_build_requested(tower_type: int) -> void:
	build_tower_requested.emit(tower_type)


func _on_upgrade_requested(tower: Tower, choice: int) -> void:
	upgrade_tower_requested.emit(tower, choice)


func _on_sell_requested(tower: Tower) -> void:
	sell_tower_requested.emit(tower)


func _on_targeting_changed(tower: Tower, mode: int) -> void:
	tower.set_targeting_mode(mode)


func _on_ability_used(slot: int) -> void:
	ability_used.emit(slot)


func _on_hero_summon() -> void:
	hero_summon_requested.emit()
