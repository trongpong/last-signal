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
var _adaptation_warning: Label

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_hud()


func _build_hud() -> void:
	# Root control that fills the viewport
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top bar (anchored to top)
	_top_bar = TopBar.new()
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size = Vector2(0, 48)
	root.add_child(_top_bar)
	_top_bar.send_wave_pressed.connect(_on_send_wave_pressed)
	_top_bar.speed_changed.connect(_on_speed_changed)

	# Tower bar (anchored to bottom)
	_tower_bar = TowerBar.new()
	_tower_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tower_bar.custom_minimum_size = Vector2(0, 64)
	root.add_child(_tower_bar)
	_tower_bar.tower_build_requested.connect(_on_build_requested)

	# Tower upgrade panel (right side, hidden by default)
	_upgrade_panel = TowerUpgradePanel.new()
	_upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_upgrade_panel.custom_minimum_size = Vector2(200, 0)
	root.add_child(_upgrade_panel)
	_upgrade_panel.upgrade_requested.connect(_on_upgrade_requested)
	_upgrade_panel.sell_requested.connect(_on_sell_requested)
	_upgrade_panel.targeting_changed.connect(_on_targeting_changed)

	# Ability bar (above bottom bar)
	_ability_bar = AbilityBar.new()
	_ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ability_bar.position = Vector2(0, -120)
	root.add_child(_ability_bar)
	_ability_bar.ability_activated.connect(_on_ability_used)
	_ability_bar.hero_summoned.connect(_on_hero_summon)

	# Adaptation warning label (centre screen, hidden by default)
	_adaptation_warning = Label.new()
	_adaptation_warning.text = tr("ENDLESS_RESISTANCE")
	_adaptation_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
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
	_top_bar.set_send_enabled(false)

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

# ---------------------------------------------------------------------------
# Tower / Ability bar control
# ---------------------------------------------------------------------------

## Populate the tower bar with available definitions and unlocked ids.
func populate_tower_bar(definitions: Array, unlocked: Array) -> void:
	_tower_bar.populate(definitions, unlocked)


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
	_top_bar.set_send_enabled(false)


func _on_wave_complete(_wave_number: int) -> void:
	pass  # break_started will enable the send button


func _on_break_started(_duration: float) -> void:
	_top_bar.set_send_enabled(true)


func _on_state_changed(new_state: int, _old_state: int) -> void:
	match new_state:
		Enums.GameState.BUILDING:
			_tower_bar.show()
		Enums.GameState.WAVE_ACTIVE:
			_tower_bar.show()
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
