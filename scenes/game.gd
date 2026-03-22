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
# Spatial hashing for tower combat
# ---------------------------------------------------------------------------

const CELL_SIZE: float = 200.0
var _spatial_grid: Dictionary = {}  # Vector2i -> Array[Enemy]

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _hud: HUD
var _pause_menu: PauseMenu = null
var _level_id: String = ""
var _difficulty: int = Enums.Difficulty.NORMAL
var _wave_manager: WaveManager
var _adaptation_manager: AdaptationManager
var _game_loop: GameLoop

## Path2D nodes that enemies follow (one per lane)
var _enemy_paths: Array[Path2D] = []

## Cached level registry for wave count lookups and path generation
var _level_registry: LevelRegistry

## All tower definitions keyed by Enums.TowerType
var _tower_defs: Dictionary = {}

## Currently selected tower type for placement
var _selected_tower_type: int = Enums.TowerType.PULSE_CANNON

## Currently selected placed tower (for upgrade panel)
var _selected_tower: Tower = null

## Long-press detection state
var _touch_start_time: float = 0.0
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_touching: bool = false

## Tower placer for sell value calculations
var _tower_placer: TowerPlacer

## Progression manager for skill bonuses and global upgrades
var _progression_manager: ProgressionManager

## Camera for panning/zooming on maps with map_scale > 1.0
var _game_camera: GameCamera = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Build the HUD using the proper HUD class
	_setup_hud()

	# Cache the level registry for wave count lookups and path generation
	_level_registry = LevelRegistry.new()
	_level_registry.register_levels()

	# Load all tower definitions
	_load_tower_definitions()

	# Create tower placer for sell value calculations
	_tower_placer = TowerPlacer.new()
	add_child(_tower_placer)

	# Create progression manager for skill bonuses and global upgrades
	_progression_manager = ProgressionManager.new()
	_progression_manager.name = "ProgressionManager"
	add_child(_progression_manager)
	_progression_manager.setup(EconomyManager, SaveManager)

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

	# Apply starting gold — enough for 3-4 basic towers
	var starting_gold: int = 300 + _progression_manager.get_starting_gold_bonus()
	EconomyManager.add_gold(starting_gold)

	# Start level in GameManager
	GameManager.start_level(level_id, difficulty)

	# Build enemy paths for this level (must happen after _level_id is set)
	_setup_enemy_paths()

	# Create GameCamera for maps larger than 1x viewport
	var level_def: Dictionary = _level_registry.get_level(_level_id.replace("level_", ""))
	var map_scale: float = level_def.get("map_scale", 1.0)
	if map_scale > 1.0:
		_game_camera = GameCamera.new()
		_game_camera.name = "GameCamera"
		add_child(_game_camera)
		var world_size := Vector2(1280.0 * map_scale, 720.0 * map_scale)
		_game_camera.setup(map_scale, world_size)

	# Scale background, grid overlay, and field border to world size
	var ws := Vector2(1280.0 * map_scale, 720.0 * map_scale)
	for child in map.get_children():
		if child is _GridOverlay:
			child.world_size = ws
			child.queue_redraw()
		elif child is _FieldBorder:
			child.world_size = ws
			child.queue_redraw()
		elif child is ColorRect:
			child.size = ws

	# Apply extra lives from global upgrades (after start_level sets base lives)
	var extra_lives: int = _progression_manager.get_extra_lives()
	if extra_lives > 0:
		GameManager.lives += extra_lives
		GameManager.lives_changed.emit(GameManager.lives, GameManager.lives_lost)

	# Load wave data — hand-crafted levels first, then procedural fallback
	var waves: Array = []
	var LevelDataClass = load("res://content/levels/level_data.gd")
	if LevelDataClass and LevelDataClass.has_method("get_waves"):
		waves = LevelDataClass.get_waves(level_id)

	# Procedural fallback via WaveGenerator for levels without hand-crafted data
	if waves.is_empty():
		var generator := WaveGenerator.new()
		var wave_count: int = _get_level_wave_count(level_id)
		for w in range(1, wave_count + 1):
			waves.append(generator.generate_wave(w, difficulty))

	# Setup wave manager
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	if waves.size() > 0:
		_wave_manager.load_waves(waves)
	_wave_manager.enemy_spawn_requested.connect(_on_enemy_spawn_requested)

	# Setup adaptation manager
	_adaptation_manager = AdaptationManager.new()
	add_child(_adaptation_manager)
	_adaptation_manager.setup(difficulty, false)

	# Setup game loop orchestrator
	_game_loop = GameLoop.new()
	add_child(_game_loop)
	_game_loop.setup(GameManager, EconomyManager, _wave_manager, _adaptation_manager)

	# Bind HUD to manager signals (must happen after wave manager is created)
	_hud.bind_signals(GameManager, EconomyManager, _wave_manager)

	# Listen for victory/defeat from game loop
	_game_loop.level_victory.connect(_on_level_victory)
	GameManager.level_failed.connect(_on_level_failed)

	# Populate the tower bar with all loaded definitions
	var all_defs: Array = _tower_defs.values()
	var unlocked_ids: Array = []
	for def in all_defs:
		unlocked_ids.append(def.id)
	_hud.populate_tower_bar(all_defs, unlocked_ids)

	# Update tower bar prices with global discount
	var discount: int = _progression_manager.get_tower_cost_discount()
	if discount > 0:
		_hud.update_tower_bar_costs(discount)

	# Highlight the default selected tower type
	_hud.select_tower_type(_selected_tower_type)

# ---------------------------------------------------------------------------
# Enemy path setup
# ---------------------------------------------------------------------------

func _setup_enemy_paths() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var level_paths: Dictionary = {}
	if LevelDataClass and LevelDataClass.has_method("get_level_paths"):
		level_paths = LevelDataClass.get_level_paths(_level_id)

	if level_paths.is_empty():
		# Try procedural generation via PathGenerator
		var level_def: Dictionary = _level_registry.get_level(_level_id.replace("level_", ""))
		if level_def.is_empty() or level_def.get("map_mode", 0) == Enums.MapMode.GRID_MAZE:
			return
		var gen := PathGenerator.new()
		var path_type: String = level_def.get("path_type", "zigzag")
		var ms: float = level_def.get("map_scale", 1.0)
		level_paths = gen.generate(path_type, ms, level_def.get("level_number", 1), _level_id.hash())

	if level_paths.is_empty():
		return

	var path_colors: Array = [
		Color(0.2, 0.5, 0.9, 0.6),
		Color(0.9, 0.5, 0.2, 0.6),
		Color(0.2, 0.9, 0.3, 0.6),
	]
	var glow_colors: Array = [
		Color(0.2, 0.4, 0.8, 0.15),
		Color(0.8, 0.4, 0.2, 0.15),
		Color(0.2, 0.8, 0.3, 0.15),
	]
	for i in range(level_paths["paths"].size()):
		var points: Array = level_paths["paths"][i]
		var path2d := Path2D.new()
		var curve := Curve2D.new()
		for pt in points:
			curve.add_point(pt)
		path2d.curve = curve
		map.add_child(path2d)
		_enemy_paths.append(path2d)

		var color_idx: int = mini(i, path_colors.size() - 1)
		_draw_path_visual(points, path_colors[color_idx], glow_colors[color_idx])

func _draw_path_visual(points: Array, color: Color, glow_color: Color) -> void:
	var glow_line := Line2D.new()
	glow_line.width = 20.0
	glow_line.default_color = glow_color
	glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
	glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for pt in points:
		glow_line.add_point(pt)
	map.add_child(glow_line)

	var path_line := Line2D.new()
	path_line.width = 8.0
	path_line.default_color = color
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for pt in points:
		path_line.add_point(pt)
	map.add_child(path_line)

	_draw_path_markers(points, color)

# Draw small tick marks to indicate travel direction
func _draw_path_markers(path_points: Array, color: Color) -> void:
	var marker_color := Color(color.r, color.g, color.b, 0.8)
	for i in range(path_points.size() - 1):
		var from: Vector2 = path_points[i]
		var to: Vector2 = path_points[i + 1]
		var mid: Vector2 = (from + to) * 0.5
		var dir: Vector2 = (to - from).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x) * 12.0

		var marker := Line2D.new()
		marker.width = 3.0
		marker.default_color = marker_color
		marker.add_point(mid - dir * 10.0 + perp)
		marker.add_point(mid + dir * 10.0)
		marker.add_point(mid - dir * 10.0 - perp)
		map.add_child(marker)

# ---------------------------------------------------------------------------
# Enemy spawning
# ---------------------------------------------------------------------------

func _on_enemy_spawn_requested(enemy_id: String, path_index: int = 0) -> void:
	# Load the EnemyDefinition resource
	var def_path: String = "res://content/enemies/%s.tres" % enemy_id
	if not ResourceLoader.exists(def_path):
		push_warning("game.gd: enemy definition not found: %s" % def_path)
		return

	var def: EnemyDefinition = load(def_path) as EnemyDefinition
	if def == null:
		push_warning("game.gd: failed to load enemy definition: %s" % def_path)
		return

	# Use path_index to pick the correct Path2D
	if _enemy_paths.is_empty():
		return
	var path: Path2D = _enemy_paths[clampi(path_index, 0, _enemy_paths.size() - 1)]

	# Create a PathFollow2D for this enemy to follow the selected path
	var path_follow := PathFollow2D.new()
	path_follow.rotates = false
	path_follow.loop = false
	path_follow.progress = 0.0
	path.add_child(path_follow)

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

func _input(event: InputEvent) -> void:
	# Handle Escape key to toggle pause menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		return

	# Don't process game input during victory/defeat or pause
	if GameManager.current_state in [Enums.GameState.VICTORY, Enums.GameState.DEFEAT, Enums.GameState.PAUSED]:
		return
	if not (event is InputEventMouseButton):
		# Handle drag cancellation for long-press
		if event is InputEventMouseMotion:
			if _is_touching and event.position.distance_to(_touch_start_pos) >= 10.0:
				_is_touching = false
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	# Ignore clicks in the HUD bar areas (top 56px and bottom 72px)
	var vp_size := get_viewport_rect().size
	if mb.position.y < 56.0 or mb.position.y > vp_size.y - 72.0:
		return

	# Ignore clicks on the send wave button area (bottom-right 140x56 above tower bar)
	if mb.position.x > vp_size.x - 140.0 and mb.position.y > vp_size.y - 72.0 - 56.0:
		return

	if mb.pressed:
		_touch_start_time = Time.get_ticks_msec() / 1000.0
		_touch_start_pos = mb.position
		_is_touching = true
	else:
		if _is_touching:
			_is_touching = false
			var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _touch_start_time
			if elapsed < Constants.LONG_PRESS_DURATION:
				_handle_tap(mb.position)

## Convert viewport-space coordinates to world-space coordinates.
## When no camera is active (map_scale = 1.0), returns the position unchanged.
func _viewport_to_world(viewport_pos: Vector2) -> Vector2:
	if _game_camera == null:
		return viewport_pos
	return get_canvas_transform().affine_inverse() * viewport_pos

func _handle_tap(viewport_pos: Vector2) -> void:
	var pos: Vector2 = _viewport_to_world(viewport_pos)
	# If in build mode (tower type selected, no tower inspected), prioritize placement
	if _selected_tower_type >= 0 and _selected_tower == null:
		_try_place_tower(pos)
		return

	# Check if tapping an existing tower -> select it, show upgrade panel
	var tapped_tower: Tower = _find_tower_at(pos)
	if tapped_tower:
		_hide_tower_range()
		_selected_tower = tapped_tower
		_show_tower_range(tapped_tower)
		_touch_feedback(tapped_tower)
		var sell_value: int = _tower_placer.calculate_sell_value(
			tapped_tower.get_total_investment(),
			tapped_tower.current_tier,
			_progression_manager.get_sell_refund_bonus()
		)
		_hud.show_upgrade_panel(tapped_tower, sell_value)
		return

	# If upgrade panel is showing, close it and return to build mode
	if _selected_tower != null:
		_hide_tower_range()
		_selected_tower = null
		_hud.hide_upgrade_panel()
		return

	# Nothing hit -> deselect everything
	_hide_tower_range()
	_set_build_mode_indicators(false)
	_selected_tower = null
	_selected_tower_type = -1
	_hud.deselect_tower_type()
	_hud.hide_upgrade_panel()

func _try_place_tower(click_pos: Vector2) -> void:
	var def: TowerDefinition = _tower_defs.get(_selected_tower_type) as TowerDefinition
	if def == null:
		return

	# Prevent placement too close to existing towers
	if _is_position_occupied(click_pos):
		return

	# Check we can afford it (apply tower cost discount from global upgrades)
	var discount: int = _progression_manager.get_tower_cost_discount()
	var cost: int = maxi(def.cost - int(float(def.cost) * float(discount) / 100.0), 1)
	if not EconomyManager.can_afford(cost):
		return

	# Spend gold and place tower
	EconomyManager.spend_gold(cost)

	var tower := Tower.new()
	tower.global_position = click_pos
	towers.add_child(tower)
	tower.initialize(def)

	# Apply skill tree bonuses from progression
	var bonuses: Dictionary = _progression_manager.get_skill_bonuses(def.tower_type)
	tower.apply_skill_bonuses(bonuses)

	# Show occupy indicator on the newly placed tower (if in build mode)
	if _selected_tower_type >= 0:
		_ensure_occupy_indicator(tower)

# ---------------------------------------------------------------------------
# Tower combat — run every frame for each placed tower
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Long-press detection for tower info tooltip
	if _is_touching:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _touch_start_time
		if elapsed > Constants.LONG_PRESS_DURATION:
			_is_touching = false
			var world_pos: Vector2 = _viewport_to_world(_touch_start_pos)
			var tower_at: Tower = _find_tower_at(world_pos)
			if tower_at:
				_hide_tower_range()
				_selected_tower = tower_at
				_show_tower_range(tower_at)
				_touch_feedback(tower_at)
				var sell_value: int = _tower_placer.calculate_sell_value(
					tower_at.get_total_investment(),
					tower_at.current_tier,
					_progression_manager.get_sell_refund_bonus()
				)
				_hud.show_upgrade_panel(tower_at, sell_value)

	# Fire each ready tower
	_process_tower_combat()

func _rebuild_spatial_grid() -> void:
	_spatial_grid.clear()
	for child in enemies.get_children():
		if child is Enemy and child.is_alive():
			var cell := Vector2i(floori(child.global_position.x / CELL_SIZE), floori(child.global_position.y / CELL_SIZE))
			if not _spatial_grid.has(cell):
				_spatial_grid[cell] = []
			_spatial_grid[cell].append(child)


func _get_nearby_enemies(pos: Vector2, range_val: float) -> Array:
	var result: Array = []
	var cell_range: int = ceili(range_val / CELL_SIZE)
	var center_cell := Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))
	for dx in range(-cell_range, cell_range + 1):
		for dy in range(-cell_range, cell_range + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
			if _spatial_grid.has(cell):
				result.append_array(_spatial_grid[cell])
	return result


func _process_tower_combat() -> void:
	if towers.get_child_count() == 0 or enemies.get_child_count() == 0:
		return

	# Rebuild spatial grid once per frame
	_rebuild_spatial_grid()

	if _spatial_grid.is_empty():
		return

	# For each tower, attempt to fire using spatial lookup
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var tower := child as Tower
		if not tower.can_fire():
			continue

		# Only check nearby enemies via spatial hash
		var nearby: Array = _get_nearby_enemies(tower.global_position, tower.current_range)
		if nearby.is_empty():
			continue

		# Build enemy data array for targeting from nearby enemies only
		var enemy_data: Array = []
		var enemy_nodes: Array = []
		for enemy in nearby:
			enemy_data.append({
				"position": enemy.global_position,
				"hp": enemy.get_hp_percentage(),
				"progress": enemy.get_progress_ratio(),
				"alive": true,
			})
			enemy_nodes.append(enemy)

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
		proj.hit_target.connect(_on_projectile_hit.bind(target_enemy.get_instance_id()))
		projectiles.add_child(proj)

		tower.fired.emit(tower, target_enemy.global_position)
		tower.on_fired()

# ---------------------------------------------------------------------------
# Projectile hit
# ---------------------------------------------------------------------------

func _on_projectile_hit(hit_pos: Vector2, damage: float, damage_type: int, splash_radius: float, target_id: int) -> void:
	if splash_radius > 0.0:
		for child in enemies.get_children():
			if not (child is Enemy):
				continue
			var e := child as Enemy
			if not e.is_alive():
				continue
			if e.global_position.distance_to(hit_pos) <= splash_radius:
				_deal_damage_to_enemy(e, damage, damage_type)
	else:
		var target := instance_from_id(target_id)
		if target != null and target is Enemy and target.is_alive():
			_deal_damage_to_enemy(target as Enemy, damage, damage_type)

func _deal_damage_to_enemy(enemy: Enemy, damage: float, damage_type: int) -> void:
	var health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth
	if health == null:
		return
	health.take_damage(damage, damage_type as Enums.DamageType)

	# Floating damage number
	_show_damage_popup(enemy.global_position, damage, damage_type)

	# Record damage for the adaptation system
	if _game_loop:
		_game_loop.on_damage_dealt(damage_type, damage)

# ---------------------------------------------------------------------------
# Enemy death and exit
# ---------------------------------------------------------------------------

func _on_enemy_died(enemy: Enemy) -> void:
	var gold: int = enemy.get_gold_value() + _progression_manager.get_gold_per_kill_bonus()
	if gold > 0:
		EconomyManager.add_gold(gold)
	if _wave_manager:
		_wave_manager.on_enemy_died()

func _on_enemy_reached_exit(enemy: Enemy) -> void:
	GameManager.lose_life()
	if _wave_manager:
		_wave_manager.on_enemy_reached_exit()

# ---------------------------------------------------------------------------
# Victory / Defeat
# ---------------------------------------------------------------------------

func _on_level_victory(level_id: String, stars: int, diamonds: int) -> void:
	var screen := LevelComplete.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(screen)
	screen.show_results(stars, diamonds)
	screen.continue_pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	screen.restart_pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)

func _on_level_failed(level_id: String) -> void:
	var wave_reached: int = 0
	if _wave_manager:
		wave_reached = _wave_manager.current_wave_index + 1
	var screen := LevelFailed.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(screen)
	screen.show_results(wave_reached)
	screen.retry_pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	screen.quit_pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)

# ---------------------------------------------------------------------------
# HUD setup
# ---------------------------------------------------------------------------

func _setup_hud() -> void:
	_hud = HUD.new()
	add_child(_hud)

	# Dark background for sci-fi feel
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -10
	map.add_child(bg)

	# Playable field border — subtle lines marking the tower-placeable area
	var field_border := _FieldBorder.new()
	field_border.z_index = -8
	map.add_child(field_border)

	# Add a subtle grid overlay for sci-fi feel
	var grid := _GridOverlay.new()
	grid.z_index = -9
	map.add_child(grid)

	# Create pause menu (hidden by default) and add to UI layer
	_pause_menu = PauseMenu.new()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(_pause_menu)
	_pause_menu.resume_pressed.connect(func() -> void:
		_pause_menu.hide()
		GameManager.toggle_pause()
	)
	_pause_menu.restart_pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	_pause_menu.quit_pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	_pause_menu.settings_requested.connect(func() -> void:
		print("Settings from pause not yet implemented")
	)

	# Connect HUD signals to game logic
	_hud.build_tower_requested.connect(_on_build_tower_requested)
	_hud.send_wave_requested.connect(_on_send_wave_requested)
	_hud.sell_tower_requested.connect(_on_sell_tower_requested)
	_hud.upgrade_tower_requested.connect(_on_upgrade_tower_requested)
	_hud.ability_used.connect(_on_ability_used)

# ---------------------------------------------------------------------------
# Tower definition loading
# ---------------------------------------------------------------------------

## Returns wave count for a level from the registry, or a default of 10.
func _get_level_wave_count(level_id: String) -> int:
	var id: String = level_id
	if id.begins_with("level_"):
		id = id.substr(6)
	var level_def: Dictionary = _level_registry.get_level(id)
	if level_def.is_empty():
		return 10
	return level_def.get("wave_count", 10) as int


func _load_tower_definitions() -> void:
	var tower_files: Array[String] = [
		"res://content/towers/pulse_cannon.tres",
		"res://content/towers/arc_emitter.tres",
		"res://content/towers/cryo_array.tres",
		"res://content/towers/missile_pod.tres",
		"res://content/towers/beam_spire.tres",
		"res://content/towers/nano_hive.tres",
		"res://content/towers/harvester.tres",
	]
	for path in tower_files:
		if ResourceLoader.exists(path):
			var def: TowerDefinition = load(path) as TowerDefinition
			if def != null:
				_tower_defs[def.tower_type] = def

# ---------------------------------------------------------------------------
# Tower selection
# ---------------------------------------------------------------------------

## Find a placed tower near the given screen position.
## Returns null if no tower is close enough.
func _find_tower_at(pos: Vector2) -> Tower:
	var best_tower: Tower = null
	var best_dist: float = Constants.TOUCH_SELECT_RADIUS
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var dist: float = pos.distance_to(child.global_position)
		if dist < best_dist:
			best_dist = dist
			best_tower = child as Tower
	return best_tower

## Brief scale pulse to give visual touch feedback on a selected tower.
func _touch_feedback(node: Node2D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.05)

# ---------------------------------------------------------------------------
# Pause menu
# ---------------------------------------------------------------------------

func _toggle_pause() -> void:
	if _pause_menu == null:
		return
	if _pause_menu.visible:
		_pause_menu.hide()
		GameManager.toggle_pause()
	else:
		GameManager.toggle_pause()
		_pause_menu.show_animated()


## Returns true if the position is too close to any existing tower.
func _is_position_occupied(pos: Vector2) -> bool:
	for child in towers.get_children():
		if not (child is Tower):
			continue
		if pos.distance_to(child.global_position) < Constants.TOUCH_SELECT_RADIUS:
			return true
	return false


## Show range indicator on a selected tower.
func _show_tower_range(tower: Tower) -> void:
	var renderer := tower.get_node_or_null("TowerRenderer") as TowerRenderer
	if renderer != null:
		renderer.show_range = true
		renderer.queue_redraw()


## Hide range indicator on the currently selected tower.
func _hide_tower_range() -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		var renderer := _selected_tower.get_node_or_null("TowerRenderer") as TowerRenderer
		if renderer != null:
			renderer.show_range = false
			renderer.queue_redraw()


## Show or hide occupied-area indicators on ALL placed towers (used in build mode).
## Draws a subtle circle matching TOUCH_SELECT_RADIUS so players can see where
## they cannot place a new tower.
func _set_build_mode_indicators(visible: bool) -> void:
	for child in towers.get_children():
		if not (child is Tower):
			continue
		if visible:
			_ensure_occupy_indicator(child as Tower)
		else:
			_remove_occupy_indicator(child as Tower)


func _ensure_occupy_indicator(tower: Tower) -> void:
	if tower.get_node_or_null("OccupyIndicator") != null:
		return
	var indicator := _OccupyIndicator.new()
	indicator.name = "OccupyIndicator"
	indicator.z_index = -1
	tower.add_child(indicator)


func _remove_occupy_indicator(tower: Tower) -> void:
	var indicator := tower.get_node_or_null("OccupyIndicator")
	if indicator != null:
		indicator.queue_free()

# ---------------------------------------------------------------------------
# HUD signal handlers
# ---------------------------------------------------------------------------

func _on_build_tower_requested(tower_type: int) -> void:
	# Toggle: tapping the same tower type again exits build mode
	if _selected_tower_type == tower_type:
		_selected_tower_type = -1
		_hud.deselect_tower_type()
		_set_build_mode_indicators(false)
		return
	_selected_tower_type = tower_type
	# Highlight the selected tower in the bar
	_hud.select_tower_type(tower_type)
	# Deselect any selected placed tower
	_hide_tower_range()
	_selected_tower = null
	_hud.hide_upgrade_panel()
	# Show all placed tower ranges so player can see occupied areas
	_set_build_mode_indicators(true)

func _on_send_wave_requested() -> void:
	if _game_loop:
		_game_loop.send_wave()

func _on_sell_tower_requested(tower: Tower) -> void:
	if not is_instance_valid(tower):
		return
	_hide_tower_range()
	var sell_value: int = _tower_placer.calculate_sell_value(
		tower.get_total_investment(),
		tower.current_tier,
		_progression_manager.get_sell_refund_bonus()
	)
	EconomyManager.add_gold(sell_value)
	tower.sell()
	_selected_tower = null
	_hud.hide_upgrade_panel()

func _on_upgrade_tower_requested(tower: Tower, choice: int) -> void:
	if not is_instance_valid(tower):
		return
	var tier_tree: TierTree = tower.get_tier_tree()
	if tier_tree == null:
		return
	var options: Array = tier_tree.get_upgrade_options(tower.get_upgrade_path())
	if choice < 0 or choice >= options.size():
		return
	var branch: Dictionary = options[choice]
	var cost: int = branch.get("cost", 0) as int
	if not EconomyManager.can_afford(cost):
		return
	EconomyManager.spend_gold(cost)
	tower.apply_upgrade(choice)
	# Refresh the upgrade panel with updated tower stats
	var sell_value: int = _tower_placer.calculate_sell_value(
		tower.get_total_investment(),
		tower.current_tier,
		_progression_manager.get_sell_refund_bonus()
	)
	_hud.show_upgrade_panel(tower, sell_value)

func _on_ability_used(slot: int) -> void:
	pass  # Ability system not yet fully implemented

# ---------------------------------------------------------------------------
# Damage popup
# ---------------------------------------------------------------------------

func _show_damage_popup(world_pos: Vector2, damage: float, damage_type: int) -> void:
	# Convert world position to screen position so popups render correctly with camera zoom
	var screen_pos: Vector2 = get_canvas_transform() * (world_pos + Vector2(randf_range(-10, 10), -20))
	var label := Label.new()
	label.text = str(int(damage))
	label.position = screen_pos
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Color by damage type
	var colors: Dictionary = {
		0: Color.CYAN, 1: Color.YELLOW, 2: Color(0.5, 0.8, 1.0),
		3: Color.ORANGE_RED, 4: Color.WHITE, 5: Color.GREEN, 6: Color.GOLD
	}
	label.add_theme_color_override("font_color", colors.get(damage_type, Color.WHITE))
	ui.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)

# ---------------------------------------------------------------------------
# Inner classes
# ---------------------------------------------------------------------------

class _OccupyIndicator extends Node2D:
	## Draws a subtle circle showing the tower's selection hitbox area.
	func _draw() -> void:
		var radius: float = Constants.TOUCH_SELECT_RADIUS
		# Filled circle — red tint to signal "occupied"
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.2, 0.08))
		# Border ring
		var points := PackedVector2Array()
		var segments: int = 24
		for i in range(segments + 1):
			var angle: float = TAU * float(i) / float(segments)
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
		for i in range(segments):
			draw_line(points[i], points[i + 1], Color(1.0, 0.3, 0.2, 0.25), 1.0)


class _FieldBorder extends Node2D:
	## Draws subtle border lines at the edges of the tower-placeable area
	## to visually separate it from the HUD (top bar and tower bar).
	var world_size: Vector2 = Vector2(1280, 720)

	func _draw() -> void:
		var top_y: float = 57.0  # just below top bar
		var bottom_y: float = world_size.y - 72.0  # just above tower bar
		var border_color := Color(0.2, 0.4, 0.7, 0.2)
		# Top edge of play field
		draw_line(Vector2(0, top_y), Vector2(world_size.x, top_y), border_color, 1.0)
		# Bottom edge of play field
		draw_line(Vector2(0, bottom_y), Vector2(world_size.x, bottom_y), border_color, 1.0)


class _GridOverlay extends Node2D:
	var world_size: Vector2 = Vector2(1280, 720)

	func _draw() -> void:
		var grid_size: float = 64.0
		var color := Color(0.1, 0.15, 0.25, 0.15)
		# Only draw grid in the playable area (between top bar and tower bar)
		var top_y: float = 57.0
		var bottom_y: float = world_size.y - 72.0
		# Vertical lines
		var x: float = 0.0
		while x <= world_size.x:
			draw_line(Vector2(x, top_y), Vector2(x, bottom_y), color, 1.0)
			x += grid_size
		# Horizontal lines
		var y: float = top_y
		while y <= bottom_y:
			draw_line(Vector2(0, y), Vector2(world_size.x, y), color, 1.0)
			y += grid_size
