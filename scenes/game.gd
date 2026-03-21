extends Node2D

## Root script for the main game scene.
## Creates HUD, loads level data, manages the game loop.
## Handles enemy spawning, path drawing, tower placement, and combat.

# ---------------------------------------------------------------------------
# Child node references (set up in game.tscn)
# ---------------------------------------------------------------------------

@onready var map: Node2D = $Map
@onready var towers: Node2D = $Towers
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var ui: CanvasLayer = $UI

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _hud: Control
var _level_id: String = ""
var _difficulty: int = Enums.Difficulty.NORMAL
var _wave_manager: WaveManager
var _adaptation_manager: AdaptationManager

## The Path2D that enemies follow across the screen
var _enemy_path: Path2D

## Line2D that visually displays the enemy path
var _path_line: Line2D

## The pulse cannon TowerDefinition loaded once at startup
var _pulse_cannon_def: TowerDefinition

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Build the HUD
	_build_hud()

	# Create and draw the enemy path
	_setup_enemy_path()

	# Load tower definition for placement
	_pulse_cannon_def = load("res://content/towers/pulse_cannon.tres") as TowerDefinition

	# Connect to manager signals
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	EconomyManager.gold_changed.connect(_on_gold_changed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_level(level_id: String, difficulty: int = Enums.Difficulty.NORMAL) -> void:
	_level_id = level_id
	_difficulty = difficulty

	# Reset match economy
	EconomyManager.reset_match_economy()
	var c := Constants.new()
	var gold_modifier: float = c.DIFFICULTY_GOLD_MULT.get(difficulty, 1.0)
	EconomyManager.set_gold_modifier(gold_modifier)

	# Apply starting gold from meta-progression
	var starting_gold: int = c.DIFFICULTY_LIVES.get(difficulty, 20) * 5  # base gold
	EconomyManager.add_gold(starting_gold)

	# Start level in GameManager
	GameManager.start_level(level_id, difficulty)

	# Load wave data
	var waves: Array = []
	var LevelDataClass = load("res://content/levels/level_data.gd")
	if LevelDataClass and LevelDataClass.has_method("get_waves"):
		waves = LevelDataClass.get_waves(level_id)

	# Setup wave manager
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	if waves.size() > 0:
		_wave_manager.load_waves(waves)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_complete.connect(_on_wave_complete)
	_wave_manager.all_waves_complete.connect(_on_all_waves_complete)
	_wave_manager.enemy_spawn_requested.connect(_on_enemy_spawn_requested)

	# Setup adaptation manager
	_adaptation_manager = AdaptationManager.new()
	add_child(_adaptation_manager)
	_adaptation_manager.setup(difficulty, false)

	# Update HUD
	_update_hud()

# ---------------------------------------------------------------------------
# Enemy path setup
# ---------------------------------------------------------------------------

func _setup_enemy_path() -> void:
	# Create the Path2D with a winding route across the screen
	_enemy_path = Path2D.new()
	_enemy_path.name = "EnemyPath"
	map.add_child(_enemy_path)

	var curve := Curve2D.new()
	# Path points: off-screen left → across screen → off-screen right
	var path_points: Array[Vector2] = [
		Vector2(-50,  540),
		Vector2(300,  300),
		Vector2(700,  600),
		Vector2(1100, 250),
		Vector2(1500, 500),
		Vector2(1970, 540),
	]
	for pt in path_points:
		curve.add_point(pt)
	_enemy_path.curve = curve

	# Draw the path visually with a Line2D
	_path_line = Line2D.new()
	_path_line.name = "PathLine"
	_path_line.width = 6.0
	_path_line.default_color = Color(0.2, 0.5, 0.9, 0.6)
	_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for pt in path_points:
		_path_line.add_point(pt)
	map.add_child(_path_line)

	# Draw arrow/directional markers along the path
	_draw_path_markers(path_points)

# Draw small tick marks to indicate travel direction
func _draw_path_markers(path_points: Array[Vector2]) -> void:
	for i in range(path_points.size() - 1):
		var from: Vector2 = path_points[i]
		var to: Vector2 = path_points[i + 1]
		var mid: Vector2 = (from + to) * 0.5
		var dir: Vector2 = (to - from).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x) * 12.0

		var marker := Line2D.new()
		marker.width = 3.0
		marker.default_color = Color(0.3, 0.7, 1.0, 0.8)
		marker.add_point(mid - dir * 10.0 + perp)
		marker.add_point(mid + dir * 10.0)
		marker.add_point(mid - dir * 10.0 - perp)
		map.add_child(marker)

# ---------------------------------------------------------------------------
# Enemy spawning
# ---------------------------------------------------------------------------

func _on_enemy_spawn_requested(enemy_id: String) -> void:
	# Load the EnemyDefinition resource
	var def_path: String = "res://content/enemies/%s.tres" % enemy_id
	if not ResourceLoader.exists(def_path):
		push_warning("game.gd: enemy definition not found: %s" % def_path)
		return

	var def: EnemyDefinition = load(def_path) as EnemyDefinition
	if def == null:
		push_warning("game.gd: failed to load enemy definition: %s" % def_path)
		return

	# Create a PathFollow2D for this enemy to follow the shared path
	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_follow.progress = 0.0
	_enemy_path.add_child(path_follow)

	# Create and wire up the FixedPathProvider
	var provider := FixedPathProvider.new()
	provider.setup(path_follow)

	# Create the Enemy node
	var enemy := Enemy.new()
	enemy.add_child(provider)
	enemy.set_path_provider(provider)

	enemies.add_child(enemy)
	enemy.initialize(def, _difficulty)

	# Position at path start
	enemy.global_position = path_follow.global_position

	# Connect death and exit signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_exit.connect(_on_enemy_reached_exit)

# ---------------------------------------------------------------------------
# Tower placement
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_place_tower(mb.position)

func _try_place_tower(click_pos: Vector2) -> void:
	if _pulse_cannon_def == null:
		return

	# Check we can afford it
	var cost: int = _pulse_cannon_def.cost
	if not EconomyManager.can_afford(cost):
		_show_info("Not enough gold! (need %d)" % cost)
		return

	# Spend gold and place tower
	EconomyManager.spend_gold(cost)

	var tower := Tower.new()
	tower.global_position = click_pos
	towers.add_child(tower)
	tower.initialize(_pulse_cannon_def)

	_update_hud()

# ---------------------------------------------------------------------------
# Tower combat — run every frame for each placed tower
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Keep gold display updated
	if _hud:
		var gold_label := _hud.get_node_or_null("TopBar/GoldLabel") as Label
		if gold_label:
			gold_label.text = "GOLD: %d" % EconomyManager.gold

	# Fire each ready tower
	_process_tower_combat()

func _process_tower_combat() -> void:
	if towers.get_child_count() == 0 or enemies.get_child_count() == 0:
		return

	# Build enemy data array for targeting
	var enemy_data: Array = []
	var enemy_nodes: Array = []
	for child in enemies.get_children():
		if child is Enemy and child.is_alive():
			enemy_data.append({
				"position": child.global_position,
				"hp": child.get_hp_percentage(),
				"progress": child.get_progress_ratio(),
				"alive": true,
			})
			enemy_nodes.append(child)

	if enemy_data.is_empty():
		return

	# For each tower, attempt to fire
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var tower := child as Tower
		if not tower.can_fire():
			continue

		var idx: int = tower._targeting.select_target(
			tower.global_position,
			tower.current_range,
			tower.targeting_mode,
			enemy_data
		)
		if idx < 0:
			continue

		var target_enemy: Enemy = enemy_nodes[idx] as Enemy

		# Spawn a projectile
		var proj := Projectile.new()
		proj.global_position = tower.global_position
		proj.initialize(
			target_enemy.global_position,
			tower._definition.projectile_speed,
			tower.get_effective_damage(),
			tower._definition.damage_type,
			tower._definition.splash_radius
		)
		proj.hit_target.connect(_on_projectile_hit.bind(target_enemy))
		projectiles.add_child(proj)

		tower.fired.emit(tower, target_enemy.global_position)
		tower.on_fired()

# ---------------------------------------------------------------------------
# Projectile hit
# ---------------------------------------------------------------------------

func _on_projectile_hit(hit_pos: Vector2, damage: float, damage_type: int, splash_radius: float, target_enemy: Enemy) -> void:
	if splash_radius > 0.0:
		# Area damage: hit all enemies within splash_radius
		for child in enemies.get_children():
			if not (child is Enemy):
				continue
			var e := child as Enemy
			if not e.is_alive():
				continue
			if e.global_position.distance_to(hit_pos) <= splash_radius:
				_deal_damage_to_enemy(e, damage, damage_type)
	else:
		# Single target
		if is_instance_valid(target_enemy) and target_enemy.is_alive():
			_deal_damage_to_enemy(target_enemy, damage, damage_type)

func _deal_damage_to_enemy(enemy: Enemy, damage: float, damage_type: int) -> void:
	var health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth
	if health == null:
		return
	health.take_damage(damage, damage_type as Enums.DamageType)

# ---------------------------------------------------------------------------
# Enemy death and exit
# ---------------------------------------------------------------------------

func _on_enemy_died(enemy: Enemy) -> void:
	var gold: int = enemy.get_gold_value()
	if gold > 0:
		EconomyManager.add_gold(gold)
	if _wave_manager:
		_wave_manager.on_enemy_died()

func _on_enemy_reached_exit(enemy: Enemy) -> void:
	GameManager.lose_life()
	if _wave_manager:
		_wave_manager.on_enemy_reached_exit()

# ---------------------------------------------------------------------------
# HUD building
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hud)

	# Dark background for sci-fi feel
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	map.add_child(bg)

	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 50
	top_bar.add_theme_constant_override("separation", 30)
	top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.add_child(top_bar)

	var lives_label := Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "LIVES: 20"
	lives_label.add_theme_color_override("font_color", Color.CYAN)
	top_bar.add_child(lives_label)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "GOLD: 0"
	gold_label.add_theme_color_override("font_color", Color.GOLD)
	top_bar.add_child(gold_label)

	var wave_label := Label.new()
	wave_label.name = "WaveLabel"
	wave_label.text = "WAVE: 0/0"
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	top_bar.add_child(wave_label)

	var send_btn := Button.new()
	send_btn.name = "SendButton"
	send_btn.text = "SEND WAVE"
	send_btn.pressed.connect(_on_send_wave_pressed)
	top_bar.add_child(send_btn)

	var speed_btn := Button.new()
	speed_btn.name = "SpeedButton"
	speed_btn.text = "1x"
	speed_btn.pressed.connect(_on_speed_pressed)
	top_bar.add_child(speed_btn)

	# Center info label
	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.set_anchors_preset(Control.PRESET_CENTER)
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", Color.CYAN)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(info_label)

	# Bottom bar with placement hint and back button
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -50
	bottom_bar.add_theme_constant_override("separation", 10)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud.add_child(bottom_bar)

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Left-click to place Pulse Cannon (100g)"
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(hint_label)

	var back_btn := Button.new()
	back_btn.text = "BACK TO MAP"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	bottom_bar.add_child(back_btn)


func _update_hud() -> void:
	if not _hud:
		return
	var top_bar := _hud.get_node_or_null("TopBar")
	if not top_bar:
		return

	var lives_label := top_bar.get_node_or_null("LivesLabel") as Label
	if lives_label:
		lives_label.text = "LIVES: %d" % GameManager.lives

	var gold_label := top_bar.get_node_or_null("GoldLabel") as Label
	if gold_label:
		gold_label.text = "GOLD: %d" % EconomyManager.gold

	var wave_label := top_bar.get_node_or_null("WaveLabel") as Label
	if wave_label:
		var current := _wave_manager.current_wave_index + 1 if _wave_manager else 0
		var total := _wave_manager.total_waves if _wave_manager else 0
		wave_label.text = "WAVE: %d/%d" % [current, total]

	var info_label := _hud.get_node_or_null("InfoLabel") as Label
	if info_label:
		match GameManager.current_state:
			Enums.GameState.BUILDING:
				info_label.text = "BUILDING PHASE — Place towers and send wave"
			Enums.GameState.WAVE_ACTIVE:
				info_label.text = "WAVE IN PROGRESS"
			Enums.GameState.WAVE_COMPLETE:
				info_label.text = "WAVE COMPLETE"
			Enums.GameState.VICTORY:
				info_label.text = "VICTORY! Stars: %d" % GameManager.calculate_stars()
			Enums.GameState.DEFEAT:
				info_label.text = "DEFEAT"
			_:
				info_label.text = ""

func _show_info(msg: String) -> void:
	var info_label := _hud.get_node_or_null("InfoLabel") as Label
	if info_label:
		info_label.text = msg

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_state_changed(new_state: int, _old_state: int) -> void:
	_update_hud()

func _on_lives_changed(new_lives: int, _lives_lost: int) -> void:
	_update_hud()

func _on_gold_changed(_new_gold: int, _delta: int) -> void:
	_update_hud()

func _on_wave_started(wave_number: int, total_waves: int) -> void:
	GameManager.change_state(Enums.GameState.WAVE_ACTIVE)
	_update_hud()

func _on_wave_complete(wave_number: int) -> void:
	GameManager.change_state(Enums.GameState.WAVE_COMPLETE)
	_update_hud()

func _on_all_waves_complete() -> void:
	GameManager.complete_level()
	_update_hud()

func _on_send_wave_pressed() -> void:
	if _wave_manager and _wave_manager.has_more_waves():
		_wave_manager.start_next_wave()
	elif _wave_manager and _wave_manager.current_wave_index == -1:
		_wave_manager.start_next_wave()

func _on_speed_pressed() -> void:
	var speeds := [1.0, 2.0, 3.0]
	var current_idx := speeds.find(GameManager.game_speed)
	var next_idx := (current_idx + 1) % speeds.size()
	GameManager.set_game_speed(speeds[next_idx])
	var speed_btn := _hud.get_node_or_null("TopBar/SpeedButton") as Button
	if speed_btn:
		speed_btn.text = "%dx" % int(speeds[next_idx])
