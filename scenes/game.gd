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

## Grid manager for maze mode levels
var _grid_manager: GridManager = null

## Synergy manager for tower combo detection
var _synergy_manager: SynergyManager = null
var _synergy_lines: Node2D = null

## Previous adaptation resistances for banner comparison
var _previous_resistances: Dictionary = {}

## Roguelite wave reward manager (endless only)
var _wave_reward_manager: WaveRewardManager = null
var _wave_reward_ui = null

## Tower mastery manager
var _tower_mastery_manager: TowerMasteryManager = null

## Signal decode minigame
var _signal_decode_minigame = null
var _signal_decode_damage_buff: float = 0.0

## Juice: life tracking for flash effects
var _prev_lives: int = 0

## Match stats for pause menu
var _match_kills: int = 0
var _match_gold: int = 0
var _low_life_vignette: ColorRect = null

## Ability system
var _ability_manager: AbilityManager = null
var _pending_ability_slot: int = -1

## Daily challenge constraints (empty = not a daily challenge)
var _challenge_constraints: Dictionary = {}

## Active hero on the field (only one at a time)
var _hero: Hero = null

## Targeting type for each ability
const ABILITY_TARGETING: Dictionary = {
	"orbital_strike": "position",
	"emp_burst": "global",
	"repair_wave": "global",
	"shield_matrix": "position",
	"overclock": "tower",
	"scrap_salvage": "global",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _exit_tree() -> void:
	# Always restore time scale when leaving the game scene to prevent
	# ability time-slow from persisting into menus or next level
	Engine.time_scale = 1.0


func _ready() -> void:
	# Build the HUD using the proper HUD class
	_setup_hud()

	# Cache the level registry for wave count lookups and path generation
	_level_registry = LevelRegistry.new()
	_level_registry.register_levels()

	# Load all tower definitions
	_load_tower_definitions()
	if _tower_defs.is_empty():
		push_error("game.gd: no tower definitions loaded — cannot start game")

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

	# Apply daily challenge constraints (gold modifier, starting lives, etc.)
	var cc_lives: int = -1
	if not _challenge_constraints.is_empty():
		var cc := _challenge_constraints
		var gold_mult_c: float = cc.get("gold_multiplier", 1.0) as float
		if gold_mult_c != 1.0:
			gold_modifier *= gold_mult_c
			EconomyManager.set_gold_modifier(gold_modifier)
		cc_lives = cc.get("starting_lives", -1) as int

	# Apply starting gold — enough for 3-4 basic towers
	var starting_gold: int = 200 + _progression_manager.get_starting_gold_bonus()
	EconomyManager.add_gold(starting_gold)

	# Start level in GameManager (sets lives from difficulty constants)
	GameManager.start_level(level_id, difficulty)

	# Override lives after start_level so GameManager's own Constants lookup is bypassed
	if cc_lives > 0:
		GameManager.lives = cc_lives
		GameManager.lives_changed.emit(GameManager.lives, GameManager.lives_lost)

	# Create GameCamera for maps larger than 1x viewport
	var level_def: Dictionary = _level_registry.get_level(_level_id.replace("level_", ""))
	# Daily challenge and endless don't have level registry entries — use defaults
	if level_def.is_empty():
		level_def = {"map_scale": 1.0, "map_mode": Enums.MapMode.FIXED_PATH, "path_type": "zigzag", "level_number": 1}
	var map_scale: float = level_def.get("map_scale", 1.0)
	if map_scale > 1.0:
		_game_camera = GameCamera.new()
		_game_camera.name = "GameCamera"
		add_child(_game_camera)
		var cam_vp := get_viewport_rect().size
		var world_size := Vector2(maxf(1280.0 * map_scale, cam_vp.x), maxf(720.0 * map_scale, cam_vp.y))
		_game_camera.setup(map_scale, world_size)

	# Initialize GridManager for GRID_MAZE levels with scaled grid size
	# Must happen BEFORE _setup_enemy_paths() so grid A* path is available
	if level_def.get("map_mode", 0) == Enums.MapMode.GRID_MAZE:
		_grid_manager = GridManager.new()
		_grid_manager.name = "GridManager"
		add_child(_grid_manager)
		var grid_w: int = int(20 * map_scale)
		var grid_h: int = int(12 * map_scale)
		_grid_manager.initialize(Vector2i(grid_w, grid_h), Vector2(64.0, 64.0))
		_grid_manager.set_entry_point(Vector2i(0, grid_h / 2))
		_grid_manager.set_exit_point(Vector2i(grid_w - 1, grid_h / 2))

	# Seed RNG for daily challenge deterministic paths
	if not _challenge_constraints.is_empty():
		seed(_challenge_constraints.get("seed", 0))

	# Build enemy paths for this level (must happen after _level_id and _grid_manager are set)
	_setup_enemy_paths()

	# Bail out early if no paths were generated (prevents game hang)
	if _enemy_paths.is_empty():
		push_error("game.gd: no enemy paths for level %s — aborting" % _level_id)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return

	# Scale field border and grid overlay to world size (use actual viewport for expand mode)
	var vp_rect := get_viewport_rect().size
	var ws := Vector2(maxf(1280.0 * map_scale, vp_rect.x), maxf(720.0 * map_scale, vp_rect.y))
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
		# Daily challenge uses its own wave count, seed, and boss interval
		if not _challenge_constraints.is_empty():
			wave_count = _challenge_constraints.get("wave_count", 20) as int
			seed(_challenge_constraints.get("seed", 0))
			if _challenge_constraints.get("type", -1) == Enums.DailyChallengeType.BOSS_RUSH:
				generator.boss_wave_interval = 3
		for w in range(1, wave_count + 1):
			waves.append(generator.generate_wave(w, difficulty))

	# Setup wave manager
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	if waves.size() > 0:
		_wave_manager.load_waves(waves)
	_wave_manager.enemy_spawn_requested.connect(_on_enemy_spawn_requested)
	# Apply daily challenge wave break override
	if not _challenge_constraints.is_empty():
		var cc_break: float = _challenge_constraints.get("wave_break_duration", -1.0) as float
		if cc_break >= 0.0:
			_wave_manager.break_duration_override = cc_break

	# Setup adaptation manager
	_adaptation_manager = AdaptationManager.new()
	add_child(_adaptation_manager)
	_adaptation_manager.setup(difficulty, _level_id == "endless")
	# Apply adaptation slowdown from global upgrades
	var adapt_bonus: float = _progression_manager.get_global_upgrade_tier("adaptation_slowdown") * 0.02
	if adapt_bonus > 0.0:
		_adaptation_manager.apply_threshold_bonus(adapt_bonus)
	_adaptation_manager.adaptation_changed.connect(_on_adaptation_changed)

	# Setup synergy manager
	_synergy_manager = SynergyManager.new()
	_synergy_manager.name = "SynergyManager"
	add_child(_synergy_manager)
	var prog_synergies: Array = SaveManager.data.get("progression", {}).get("synergies_discovered", [])
	_synergy_manager.load_discovered(prog_synergies)
	_synergy_manager.synergy_activated.connect(_on_synergy_activated)
	_synergy_lines = Node2D.new()
	_synergy_lines.name = "SynergyLines"
	add_child(_synergy_lines)

	# Setup wave reward manager (endless only)
	if _level_id == "endless":
		_wave_reward_manager = WaveRewardManager.new()
		_wave_reward_manager.name = "WaveRewardManager"
		add_child(_wave_reward_manager)
		_wave_reward_manager.setup()
		_wave_manager.wave_complete.connect(_check_wave_reward)

	# Setup tower mastery manager
	_tower_mastery_manager = TowerMasteryManager.new()
	_tower_mastery_manager.name = "TowerMasteryManager"
	add_child(_tower_mastery_manager)
	_tower_mastery_manager.setup(SaveManager)

	# Setup game loop orchestrator
	_game_loop = GameLoop.new()
	add_child(_game_loop)
	_game_loop.setup(GameManager, EconomyManager, _wave_manager, _adaptation_manager)
	# Apply daily challenge diamond reward multiplier
	if not _challenge_constraints.is_empty():
		_game_loop.diamond_reward_mult = _challenge_constraints.get("diamond_reward_mult", 1.0) as float

	# Bind HUD to manager signals (must happen after wave manager is created)
	_hud.bind_signals(GameManager, EconomyManager, _wave_manager)

	# Listen for victory/defeat from game loop
	_game_loop.level_victory.connect(_on_level_victory)
	GameManager.level_failed.connect(_on_level_failed)

	# Signal decode minigame during wave breaks
	_wave_manager.break_started.connect(_show_signal_decode)
	_wave_manager.wave_started.connect(_on_wave_started_dismiss_decode)

	# Juice: life flash effects
	_prev_lives = GameManager.lives
	GameManager.lives_changed.connect(_on_lives_changed_fx)

	# Populate the tower bar — only show towers the player has unlocked
	var all_defs: Array = _tower_defs.values()
	var unlocked_ids: Array = SaveManager.data.get("progression", {}).get("towers_unlocked", [
		"PULSE_CANNON", "ARC_EMITTER", "CRYO_ARRAY", "MISSILE_POD"
	]).duplicate()
	# Convert enum names to definition ids (lowercase with underscore)
	var unlocked_def_ids: Array = []
	for uid in unlocked_ids:
		unlocked_def_ids.append((uid as String).to_lower())
	# Daily challenge: restrict towers if constraints specify allowed_towers
	if not _challenge_constraints.is_empty():
		var allowed: Array = _challenge_constraints.get("allowed_towers", [])
		if allowed.size() > 0:
			# allowed contains tower type ints; convert to def ids
			var restricted: Array = []
			for def in all_defs:
				if allowed.has(def.tower_type):
					restricted.append(def.id)
			unlocked_def_ids = restricted
		elif _challenge_constraints.get("tower_cost_mult", 1.0) == 0.0:
			# Puzzle mode: no building allowed
			unlocked_def_ids = []
	_hud.populate_tower_bar(all_defs, unlocked_def_ids)

	# Update tower bar prices with global discount
	var discount: int = _progression_manager.get_tower_cost_discount()
	if discount > 0:
		_hud.update_tower_bar_costs(discount)

	# Set available speed options based on unlocks
	var has_x2: bool = SaveManager.data.get("unlocks", {}).get("speed_x2", false)
	var has_x3: bool = SaveManager.data.get("unlocks", {}).get("speed_x3", false)
	_hud.set_available_speeds(has_x2, has_x3)

	# Highlight the default selected tower type
	_hud.select_tower_type(_selected_tower_type)

	# Setup ability manager from saved loadout
	var prog_data: Dictionary = SaveManager.data.get("progression", {})
	var unlocked_abilities: Array = prog_data.get("abilities_unlocked", [])
	if unlocked_abilities.size() > 0:
		_ability_manager = AbilityManager.new()
		_ability_manager.name = "AbilityManager"
		add_child(_ability_manager)
		_ability_manager.set_loadout(unlocked_abilities)
		# Apply cooldown reduction from global upgrades
		var cd_reduction_secs: float = _progression_manager.get_ability_cooldown_reduction()
		if cd_reduction_secs > 0.0:
			# Convert seconds to fraction based on average cooldown (~45s)
			_ability_manager.set_cooldown_reduction(clampf(cd_reduction_secs / 45.0, 0.0, 0.8))
		var hero_available: bool = _progression_manager.is_hero_unlocked(
			_selected_tower_type
		) or _heroes_any_unlocked()
		_hud.setup_ability_bar(unlocked_abilities, hero_available)

	# Wire income collection to wave_complete
	_wave_manager.wave_complete.connect(_collect_harvester_income)

	# PUZZLE challenge: pre-place towers along the path
	if not _challenge_constraints.is_empty() and _challenge_constraints.get("type", -1) == Enums.DailyChallengeType.PUZZLE:
		_preplace_puzzle_towers()

# ---------------------------------------------------------------------------
# Puzzle tower pre-placement
# ---------------------------------------------------------------------------

func _preplace_puzzle_towers() -> void:
	if _enemy_paths.is_empty():
		return
	var path: Path2D = _enemy_paths[0]
	if path.curve == null or path.curve.point_count < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _challenge_constraints.get("seed", 0) as int
	var tower_types: Array = [
		Enums.TowerType.PULSE_CANNON, Enums.TowerType.ARC_EMITTER,
		Enums.TowerType.CRYO_ARRAY, Enums.TowerType.MISSILE_POD,
	]
	var path_length: float = path.curve.get_baked_length()
	var tower_count: int = rng.randi_range(8, 12)
	for i in range(tower_count):
		var progress: float = path_length * (float(i + 1) / float(tower_count + 1))
		var path_pos: Vector2 = path.to_global(path.curve.sample_baked(progress))
		# Offset tower away from path so it doesn't block enemies
		var offset_dir: float = -1.0 if i % 2 == 0 else 1.0
		var offset_dist: float = rng.randf_range(60.0, 120.0)
		var tangent: Vector2 = path.curve.sample_baked(minf(progress + 5.0, path_length)) - path.curve.sample_baked(progress)
		var perp := Vector2(-tangent.y, tangent.x).normalized()
		var tower_pos: Vector2 = path_pos + perp * offset_dir * offset_dist
		var tt: int = tower_types[rng.randi() % tower_types.size()]
		var def: TowerDefinition = _tower_defs.get(tt) as TowerDefinition
		if def == null:
			continue
		var tower := Tower.new()
		tower.global_position = tower_pos
		towers.add_child(tower)
		tower.initialize(def)
		var bonuses: Dictionary = _progression_manager.get_skill_bonuses(def.tower_type)
		tower.apply_skill_bonuses(bonuses)

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
		# Daily challenge and endless use default path settings
		if level_def.is_empty():
			if _level_id in ["daily_challenge", "endless"]:
				var pt: String = "zigzag"
				# CHAOS challenge: use branching (2 paths)
				if not _challenge_constraints.is_empty() and _challenge_constraints.get("type", -1) == Enums.DailyChallengeType.CHAOS:
					pt = "branching"
				level_def = {"map_scale": 1.0, "map_mode": Enums.MapMode.FIXED_PATH, "path_type": pt, "level_number": 1}
			else:
				return
		# GRID_MAZE levels: build path from GridManager A*
		if level_def.get("map_mode", 0) == Enums.MapMode.GRID_MAZE and _grid_manager != null:
			var grid_world_path: Array = _grid_manager.get_path_world()
			if grid_world_path.size() >= 2:
				level_paths = {"type": "grid_maze", "paths": [grid_world_path]}
			else:
				return
		else:
			var gen := PathGenerator.new()
			var path_type: String = level_def.get("path_type", "zigzag")
			var ms: float = level_def.get("map_scale", 1.0)
			level_paths = gen.generate(path_type, ms, level_def.get("level_number", 1), _level_id.hash())

	if level_paths.is_empty():
		return

	# Scale hand-crafted paths from 1280-based coordinates to actual viewport width
	var vp_w: float = get_viewport_rect().size.x
	var vp_h: float = get_viewport_rect().size.y
	if vp_w > 1280.0:
		var scale_x: float = vp_w / 1280.0
		for path_arr in level_paths["paths"]:
			for pi in range(path_arr.size()):
				var pt: Vector2 = path_arr[pi] as Vector2
				path_arr[pi] = Vector2(pt.x * scale_x, pt.y)
		if level_paths.has("exit"):
			var ex: Vector2 = level_paths["exit"] as Vector2
			level_paths["exit"] = Vector2(ex.x * scale_x, ex.y)

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
		# Notify wave manager so the wave can still clear
		if _wave_manager:
			_wave_manager.on_enemy_died()
		return

	var def: EnemyDefinition = load(def_path) as EnemyDefinition
	if def == null:
		push_warning("game.gd: failed to load enemy definition: %s" % def_path)
		if _wave_manager:
			_wave_manager.on_enemy_died()
		return

	# Use path_index to pick the correct Path2D
	if _enemy_paths.is_empty():
		if _wave_manager:
			_wave_manager.on_enemy_died()
		return
	var path: Path2D = _enemy_paths[clampi(path_index, 0, _enemy_paths.size() - 1)]

	var enemy := Enemy.new()

	if def.is_flying and path.curve != null and path.curve.point_count >= 2:
		# Flyers fly straight from path start to end
		var start_pos: Vector2 = path.to_global(path.curve.get_point_position(0))
		var end_pos: Vector2 = path.to_global(path.curve.get_point_position(path.curve.point_count - 1))
		var flyer_provider := FlyerPathProvider.new()
		flyer_provider.setup(start_pos, end_pos)
		enemy.add_child(flyer_provider)
		enemy.set_path_provider(flyer_provider)
		enemies.add_child(enemy)
		enemy.add_to_group("enemies")
		enemy.initialize(def, _difficulty)
		enemy.global_position = start_pos
	else:
		# Ground enemies follow the Path2D curve
		var path_follow := PathFollow2D.new()
		path_follow.rotates = false
		path_follow.loop = false
		path_follow.progress = 0.0
		path.add_child(path_follow)
		var provider := FixedPathProvider.new()
		provider.setup(path_follow)
		enemy.add_child(provider)
		enemy.set_path_provider(provider)
		enemies.add_child(enemy)
		enemy.add_to_group("enemies")
		enemy.initialize(def, _difficulty)
		enemy.global_position = path_follow.global_position

	# Apply adaptive resistance from AdaptationManager to newly spawned enemies
	if _adaptation_manager != null:
		var adapt_res: Dictionary = _adaptation_manager.get_resistances()
		if not adapt_res.is_empty():
			var health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth
			if health != null:
				for dtype in adapt_res.keys():
					health.apply_resistance_bonus(dtype as int, adapt_res[dtype] as float)
			var renderer := enemy.get_node_or_null("EnemyRenderer") as EnemyRenderer
			if renderer != null and health != null:
				renderer.set_resistance_map(health.get_resistance_map())

	# Store spawn context for splitting elites
	enemy.initialize_spawn_context(path_index, _difficulty)

	# Apply wave reward speed modifier to spawned enemies
	var speed_mod: float = _get_reward_mod("enemy_speed_mult")
	if speed_mod != 0.0:
		enemy.apply_speed_multiplier(1.0 + speed_mod)

	# Apply daily challenge enemy speed constraint
	if not _challenge_constraints.is_empty():
		var cc_speed: float = _challenge_constraints.get("enemy_speed_mult", 1.0) as float
		if cc_speed != 1.0:
			enemy.apply_speed_multiplier(cc_speed)

	# Apply elite modifiers in endless mode
	_maybe_apply_elite(enemy)

	# Connect death and exit signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_exit.connect(_on_enemy_reached_exit)
	if enemy.has_elite_modifier(Enums.EliteModifier.SPLITTING):
		enemy.elite_split_requested.connect(_on_elite_split_requested)

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

	# Ignore clicks in the HUD bar areas (account for safe area insets)
	var vp_size := get_viewport_rect().size
	var sa := DisplayServer.get_display_safe_area()
	var top_h: float = maxf(sa.position.y, 8.0) + 56.0
	var bot_h: float = maxf(DisplayServer.screen_get_size().y - sa.end.y, 4.0) + 72.0
	if mb.position.y < top_h or mb.position.y > vp_size.y - bot_h:
		return

	# Ignore clicks on the send wave button area (bottom-right 140x56 above tower bar)
	if mb.position.x > vp_size.x - 140.0 and mb.position.y > vp_size.y - bot_h - 56.0:
		return

	# Ignore clicks on any visible HUD overlay (upgrade panel, ability bar, etc.)
	if _is_click_on_hud_overlay(mb.position):
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

	# Handle pending ability targeting
	if _pending_ability_slot >= 0:
		var slot: int = _pending_ability_slot
		_pending_ability_slot = -1
		if _ability_manager != null and slot < _ability_manager.get_loadout().size():
			var ab_id: String = _ability_manager.get_loadout()[slot]
			var targeting: String = ABILITY_TARGETING.get(ab_id, "global")
			if targeting == "position":
				if _ability_manager.activate_ability(slot, pos):
					_execute_ability(ab_id, pos)
			elif targeting == "tower":
				var target_tower: Tower = _find_tower_at(pos)
				if target_tower != null:
					if _ability_manager.activate_ability(slot, target_tower):
						_execute_ability(ab_id, target_tower)
		return

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
		_hud.show_toast(tr("TOAST_PLACEMENT_BLOCKED"))
		return

	# Grid maze mode: validate placement doesn't block the path
	if _grid_manager != null:
		var cell: Vector2i = _grid_manager.world_to_cell(click_pos)
		if not _grid_manager.can_place_tower(cell):
			_hud.show_toast(tr("TOAST_PLACEMENT_BLOCKED"))
			return

	# Check we can afford it (apply tower cost discount from global upgrades + challenge constraint)
	var discount: int = _progression_manager.get_tower_cost_discount()
	var cost: int = maxi(def.cost - int(float(def.cost) * float(discount) / 100.0), 1)
	if not _challenge_constraints.is_empty():
		var cost_mult: float = _challenge_constraints.get("tower_cost_mult", 1.0) as float
		cost = maxi(int(float(cost) * cost_mult), 1)
	if not EconomyManager.can_afford(cost):
		_hud.show_toast(tr("TOAST_NOT_ENOUGH_GOLD"))
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

	# Apply tower mastery bonuses
	if _tower_mastery_manager != null:
		var mastery: Dictionary = _tower_mastery_manager.get_mastery_bonuses(def.tower_type)
		tower.apply_mastery_bonuses(mastery)

	# Tower placement "power on" animation
	tower.scale = Vector2(1.0, 0.0)
	var place_tw := create_tween()
	place_tw.tween_property(tower, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var ring := _PlacementRing.new()
	ring.global_position = tower.global_position
	ring.setup(def.color)
	add_child(ring)

	# Mark grid cell as occupied in maze mode
	if _grid_manager != null:
		var cell: Vector2i = _grid_manager.world_to_cell(click_pos)
		_grid_manager.place_tower(cell)
		tower.set_meta("grid_cell", cell)

	# Recalculate support tower buffs and synergies
	_recalculate_all_buffs()
	_recalculate_synergies()

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

	# Update ability cooldown display
	if _ability_manager != null:
		_hud.update_ability_cooldowns(_ability_manager.get_abilities())

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
		# Skip support towers (e.g. Nano Hive) — they buff, not attack
		if tower.is_support_tower():
			continue

		# Only check nearby enemies via spatial hash
		var nearby: Array = _get_nearby_enemies(tower.global_position, tower.current_range)
		if nearby.is_empty():
			continue

		# Build enemy data array for targeting from nearby enemies only
		var enemy_data: Array = []
		var enemy_nodes: Array = []
		for enemy in nearby:
			# Skip phasing elites — they are untargetable
			if enemy is Enemy and (enemy as Enemy).is_phasing():
				continue
			enemy_data.append({
				"position": enemy.global_position,
				"hp": enemy.get_hp_percentage(),
				"progress": enemy.get_progress_ratio(),
				"alive": enemy.is_alive(),
			})
			enemy_nodes.append(enemy)

		var idx: int = tower.select_target(
			tower.global_position,
			tower.current_range,
			tower.targeting_mode,
			enemy_data
		)
		if idx < 0:
			continue

		var target_enemy: Enemy = enemy_nodes[idx] as Enemy

		# Track last target for Focus Fire synergy
		tower.set_last_target_id(target_enemy.get_instance_id())

		# Spawn a projectile — use effective stats (base + skill bonuses)
		_spawn_tower_projectile(tower, target_enemy)

		# Multi-shot skill: fire at additional nearby targets
		if tower.has_special("multi_shot") and tower.get_special_level("multi_shot") >= 3:
			var extra_targets: int = 2
			var fired_at: Array = [idx]
			for _s in range(extra_targets):
				var best_idx: int = -1
				var best_dist: float = tower.current_range * tower.current_range
				for ei in range(enemy_nodes.size()):
					if fired_at.has(ei):
						continue
					var e: Enemy = enemy_nodes[ei] as Enemy
					if not e.is_alive():
						continue
					var d: float = tower.global_position.distance_squared_to(e.global_position)
					if d < best_dist:
						best_dist = d
						best_idx = ei
				if best_idx >= 0:
					fired_at.append(best_idx)
					_spawn_tower_projectile(tower, enemy_nodes[best_idx] as Enemy)

		tower.fired.emit(tower, target_enemy.global_position)
		tower.on_fired()
		AudioManager.play_tower_fire(tower.get_tower_type(), tower.current_tier)

# ---------------------------------------------------------------------------
# Projectile hit
# ---------------------------------------------------------------------------

func _on_projectile_hit(hit_pos: Vector2, damage: float, damage_type: int, splash_radius: float, target_id: int, tower_id: int = 0) -> void:
	# Look up the source tower for specials
	var source_tower: Tower = null
	if tower_id > 0:
		var inst = instance_from_id(tower_id)
		if inst is Tower:
			source_tower = inst as Tower
	var armor_pierce: bool = source_tower != null and source_tower.has_special("armor_pierce") and source_tower.get_special_level("armor_pierce") >= 2
	var src_tower_type: int = source_tower.get_tower_type() if source_tower != null else -1

	# Wave reward modifiers: damage mult, crit, armor pierce
	var reward_dmg_mult: float = 1.0 + _get_reward_mod("damage_mult") + _signal_decode_damage_buff
	damage *= reward_dmg_mult
	var crit_chance: float = _get_reward_mod("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		damage *= 3.0
	var reward_armor_pierce: float = _get_reward_mod("armor_pierce_pct")
	if reward_armor_pierce > 0.0 and randf() < reward_armor_pierce:
		armor_pierce = true

	var hit_enemies: Array = []
	var synergy: int = source_tower.get_synergy_type() if source_tower != null else -1

	if splash_radius > 0.0:
		for child in enemies.get_children():
			if not (child is Enemy):
				continue
			var e := child as Enemy
			if not e.is_alive():
				continue
			if e.global_position.distance_to(hit_pos) <= splash_radius:
				# Frostbite synergy: slowed enemies take +25% splash damage
				var splash_dmg: float = damage
				if synergy == Enums.SynergyType.FROSTBITE and e.is_slowed():
					splash_dmg *= Constants.SYNERGY_FROSTBITE_SPLASH_DAMAGE_MULT
				_deal_damage_to_enemy(e, splash_dmg, damage_type, armor_pierce, src_tower_type)
				hit_enemies.append(e)
	else:
		var target := instance_from_id(target_id)
		if target != null and target is Enemy and target.is_alive():
			_deal_damage_to_enemy(target as Enemy, damage, damage_type, armor_pierce, src_tower_type)
			hit_enemies.append(target)

	if source_tower == null or hit_enemies.is_empty():
		return

	# Reflective elite: pause attacking tower briefly
	for e in hit_enemies:
		if is_instance_valid(e) and e.has_elite_modifier(Enums.EliteModifier.REFLECTIVE):
			source_tower.add_fire_cooldown(Constants.ELITE_REFLECTIVE_PAUSE)
			break

	# Apply slow on hit (Cryo Array base mechanic + skill bonuses)
	var slow_factor: float = source_tower.get_effective_slow_factor()
	var slow_duration: float = source_tower.get_effective_slow_duration()
	if slow_duration > 0.0 and slow_factor < 1.0:
		for e in hit_enemies:
			if is_instance_valid(e) and e.is_alive():
				e.apply_slow(slow_factor, slow_duration)

	# Cold Snap synergy: extend slow on already-slowed enemies
	if synergy == Enums.SynergyType.COLD_SNAP:
		for e in hit_enemies:
			if is_instance_valid(e) and e.is_alive() and e.is_slowed():
				e.extend_slow(Constants.SYNERGY_COLD_SNAP_SLOW_EXTEND)

	# Freeze chance skill — small chance to fully stop enemy
	if source_tower.has_special("freeze_chance") and source_tower.get_special_level("freeze_chance") >= 3:
		for e in hit_enemies:
			if is_instance_valid(e) and e.is_alive() and randf() < 0.08:
				e.apply_slow(0.05, 1.5)

	# Chain to nearby enemies (Arc Emitter base mechanic + skill bonuses)
	var chain_count: int = source_tower.get_effective_chain_count()
	# Conduit synergy: +1 chain target
	if synergy == Enums.SynergyType.CONDUIT:
		chain_count += 1
	if chain_count > 0 and hit_enemies.size() > 0:
		var chain_range: float = source_tower.get_effective_chain_range()
		var chain_damage: float = damage * 0.7
		# Shatter synergy: chain damage doubled on slowed enemies (applied in _apply_chain_damage)
		_apply_chain_damage(hit_enemies[0].global_position, chain_count, chain_range, chain_damage, damage_type, hit_enemies, armor_pierce, synergy == Enums.SynergyType.SHATTER, src_tower_type)

	# Pierce — damage additional enemies behind the target (tier upgrades use "pierce+N", skill tree uses bare "pierce")
	if source_tower.get_effective_pierce() > 0:
		_apply_pierce(hit_pos, damage * 0.8, damage_type, hit_enemies, armor_pierce, src_tower_type)

	# Amplify synergy: extra pierce for Beam towers
	if synergy == Enums.SynergyType.AMPLIFY and splash_radius <= 0.0:
		_apply_pierce(hit_pos, damage * 0.8, damage_type, hit_enemies, armor_pierce, src_tower_type)

	# Focus Fire synergy: if partner's last target matches, debuff the enemy
	if synergy == Enums.SynergyType.FOCUS_FIRE and hit_enemies.size() > 0:
		var partner = instance_from_id(source_tower.get_synergy_partner_id())
		if partner != null and partner is Tower:
			var target_e: Enemy = hit_enemies[0] as Enemy
			if (partner as Tower).get_last_target_id() == target_e.get_instance_id():
				target_e.apply_focus_fire(Constants.SYNERGY_FOCUS_FIRE_DAMAGE_MULT, Constants.SYNERGY_FOCUS_FIRE_DURATION)

func _deal_damage_to_enemy(enemy: Enemy, damage: float, damage_type: int, ignore_armor: bool = false, tower_type: int = -1) -> void:
	var health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth
	if health == null:
		return
	# Track last damage source for kill attribution
	if tower_type >= 0:
		enemy.set_last_damage_source(tower_type)
	# Focus Fire debuff: enemy takes increased damage from all sources
	var effective_damage: float = damage * enemy.get_damage_multiplier()
	health.take_damage(effective_damage, damage_type as Enums.DamageType, ignore_armor)

	# Floating damage number (show actual damage dealt, not pre-debuff value)
	_show_damage_popup(enemy.global_position, effective_damage, damage_type)

	# Record damage for the adaptation system
	if _game_loop:
		_game_loop.on_damage_dealt(damage_type, damage)
	# Record damage for tower mastery
	if tower_type >= 0 and _tower_mastery_manager != null:
		_tower_mastery_manager.record_damage(tower_type, effective_damage)

# ---------------------------------------------------------------------------
# Enemy death and exit
# ---------------------------------------------------------------------------

func _on_enemy_died(enemy: Enemy) -> void:
	var gold: int = enemy.get_gold_value() + _progression_manager.get_gold_per_kill_bonus()
	var gold_mult: float = 1.0 + _get_reward_mod("gold_mult")
	gold = int(float(gold) * gold_mult)
	if gold > 0:
		EconomyManager.add_gold(gold)
		_show_gold_popup(enemy.global_position, gold)
	_match_kills += 1
	_match_gold += gold
	# Boss death: camera shake + white flash
	if enemy.is_boss():
		if _game_camera != null:
			_game_camera.shake(8.0, 0.4)
		_flash_screen(Color.WHITE, 0.15)
	# Tower mastery kill attribution
	var killing_tower_type: int = enemy.get_last_damage_source()
	if killing_tower_type >= 0 and _tower_mastery_manager != null:
		_tower_mastery_manager.record_kill(killing_tower_type)
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
	if _tower_mastery_manager != null:
		_tower_mastery_manager.commit_match_stats()
	_hud.hide_upgrade_panel()
	_selected_tower = null
	var screen := LevelComplete.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.z_index = 200
	ui.add_child(screen)
	screen.show_results(stars, diamonds)
	screen.continue_pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	screen.restart_pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	# x2 diamond ad button
	var ad_mgr: AdManager = get_node_or_null("/root/Main/AdManager") as AdManager
	if ad_mgr == null:
		screen.hide_double_button()
	else:
		screen.double_diamonds_requested.connect(func() -> void:
			ad_mgr.bonus_ad_reward_granted.connect(func(_bonus: int) -> void:
				screen.on_double_diamonds_granted()
			, CONNECT_ONE_SHOT)
			ad_mgr.bonus_ad_failed.connect(func() -> void:
				screen.hide_double_button()
			, CONNECT_ONE_SHOT)
			ad_mgr.show_bonus_ad(EconomyManager, SaveManager, diamonds)
		)

func _on_level_failed(level_id: String) -> void:
	if _tower_mastery_manager != null:
		_tower_mastery_manager.commit_match_stats()
	_hud.hide_upgrade_panel()
	_selected_tower = null
	var wave_reached: int = 0
	if _wave_manager:
		wave_reached = _wave_manager.current_wave_index + 1
	var screen := LevelFailed.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.z_index = 200
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

	# Dark background for sci-fi feel — fill entire viewport including expanded area
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	var vp_size := get_viewport_rect().size
	bg.position = Vector2(-vp_size.x, -vp_size.y)
	bg.size = vp_size * 3.0  # oversized to cover any pan/zoom
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
	_pause_menu.settings_requested.connect(_on_pause_settings)

	# Connect HUD signals to game logic
	_hud.build_tower_requested.connect(_on_build_tower_requested)
	_hud.send_wave_requested.connect(_on_send_wave_requested)
	_hud.sell_tower_requested.connect(_on_sell_tower_requested)
	_hud.pause_requested.connect(_toggle_pause)
	_hud.upgrade_tower_requested.connect(_on_upgrade_tower_requested)
	_hud.ability_used.connect(_on_ability_used)
	_hud.hero_summon_requested.connect(_on_hero_summon_requested)

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
		var wave: int = _wave_manager.current_wave_index + 1 if _wave_manager else 0
		_pause_menu.update_stats(wave, _match_gold, _match_kills)
		_pause_menu.show_animated()


## Returns true if the viewport-space position hits a visible HUD overlay with buttons.
func _is_click_on_hud_overlay(pos: Vector2) -> bool:
	return _hud.is_point_on_overlay(pos)


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
	# Free grid cell in maze mode
	if _grid_manager != null and tower.has_meta("grid_cell"):
		_grid_manager.remove_tower(tower.get_meta("grid_cell") as Vector2i)
	tower.sell()
	_selected_tower = null
	_hud.hide_upgrade_panel()
	_recalculate_all_buffs()
	_recalculate_synergies()

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
	# Upgrade pulse VFX
	var upgrade_tw := create_tween()
	upgrade_tw.tween_property(tower, "scale", Vector2(1.2, 1.2), 0.1)
	upgrade_tw.tween_property(tower, "scale", Vector2(1.0, 1.0), 0.1)
	var up_ring := _PlacementRing.new()
	up_ring.global_position = tower.global_position
	up_ring.setup(Color.WHITE)
	add_child(up_ring)
	# Refresh the upgrade panel with updated tower stats
	var sell_value: int = _tower_placer.calculate_sell_value(
		tower.get_total_investment(),
		tower.current_tier,
		_progression_manager.get_sell_refund_bonus()
	)
	_hud.show_upgrade_panel(tower, sell_value)

func _on_ability_used(slot: int) -> void:
	if _ability_manager == null:
		return
	var loadout: Array[String] = _ability_manager.get_loadout()
	if slot < 0 or slot >= loadout.size():
		return
	var ab: Ability = _ability_manager.get_ability(slot)
	if ab == null or not ab.is_ready():
		return
	var ab_id: String = loadout[slot]
	var targeting: String = ABILITY_TARGETING.get(ab_id, "global")
	if targeting == "global":
		if _ability_manager.activate_ability(slot):
			_execute_ability(ab_id, null)
	else:
		# Enter targeting mode — next tap will fire the ability
		_pending_ability_slot = slot
		_hud.show_toast(tr("TOAST_TAP_TO_TARGET"))

func _on_hero_summon_requested() -> void:
	if _hero != null and _hero.is_active():
		return  # Only one hero at a time
	AudioManager.play_hero_summon()
	# Find any unlocked hero
	var hero_tower_type: int = -1
	for tt in range(7):
		if _progression_manager.is_hero_unlocked(tt):
			hero_tower_type = tt
			break
	if hero_tower_type < 0:
		return
	# Spawn hero at center of the map (account for map scale)
	var level_def_h: Dictionary = _level_registry.get_level(_level_id.replace("level_", ""))
	var ms_h: float = level_def_h.get("map_scale", 1.0)
	var spawn_pos := Vector2(640.0 * ms_h, 360.0 * ms_h)
	_hero = Hero.new()
	_hero.name = "Hero"
	var duration: float = 20.0 + _progression_manager.get_hero_duration_bonus()
	_hero.initialize(str(hero_tower_type), duration, spawn_pos)
	_hero.set_color(Color(0.4, 0.8, 1.0))
	_hero.attacked.connect(_on_hero_attacked)
	_hero.expired.connect(_on_hero_expired)
	add_child(_hero)

func _on_hero_attacked(target: Node2D, damage: float) -> void:
	if target is Enemy and target.is_alive():
		_deal_damage_to_enemy(target as Enemy, damage, Enums.DamageType.BEAM)

func _on_hero_expired(_hero_ref: Hero) -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.queue_free()
	_hero = null

func _on_pause_settings() -> void:
	# Use a dedicated CanvasLayer above the HUD so settings covers everything
	var settings_layer := CanvasLayer.new()
	settings_layer.layer = 10
	settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_layer)
	var settings := SettingsMenu.new()
	settings.process_mode = Node.PROCESS_MODE_ALWAYS
	settings.back_pressed.connect(func() -> void:
		settings_layer.queue_free()
		_pause_menu.show_animated()
	)
	_pause_menu.hide()
	settings_layer.add_child(settings)

func _on_adaptation_changed(resistances: Dictionary) -> void:
	var type_names: Dictionary = {
		Enums.DamageType.PULSE: "Pulse",
		Enums.DamageType.ARC: "Arc",
		Enums.DamageType.CRYO: "Cryo",
		Enums.DamageType.MISSILE: "Missile",
		Enums.DamageType.BEAM: "Beam",
		Enums.DamageType.NANO: "Nano",
		Enums.DamageType.HARVEST: "Harvest",
	}
	# Show rising/falling banners comparing to previous state
	var rising: PackedStringArray = PackedStringArray()
	var falling: PackedStringArray = PackedStringArray()
	for key in resistances.keys():
		var cur: float = resistances[key] as float
		var prev: float = _previous_resistances.get(key, 0.0) as float
		var dtype_name: String = type_names.get(key, "Unknown")
		if cur > prev:
			rising.append(dtype_name)
		elif cur < prev and cur >= 0.0:
			falling.append(dtype_name)
	if rising.size() > 0:
		var msg: String = tr("TOAST_RESISTANCE_RISING").replace("{0}", ", ".join(rising))
		_hud.show_toast(msg)
	if falling.size() > 0:
		var msg: String = tr("TOAST_RESISTANCE_FALLING").replace("{0}", ", ".join(falling))
		_hud.show_toast(msg)
	_previous_resistances = resistances.duplicate()
	# Update HUD resistance meter
	_hud.update_resistance_meter(resistances)
	# Glitch effect on all visible enemies
	if rising.size() > 0:
		for child in enemies.get_children():
			if child is Enemy and child.is_alive():
				_apply_glitch_effect(child as Enemy)

# ---------------------------------------------------------------------------
# Ability effects
# ---------------------------------------------------------------------------

func _execute_ability(ability_id: String, target: Variant) -> void:
	# Brief time-slow "moment of impact" pause (0.1s)
	Engine.time_scale = 0.2
	get_tree().create_timer(0.1, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = GameManager.game_speed
	)
	match ability_id:
		"orbital_strike":
			_ability_orbital_strike(target as Vector2)
		"emp_burst":
			_ability_emp_burst()
		"repair_wave":
			_ability_repair_wave()
		"shield_matrix":
			_ability_shield_matrix(target as Vector2)
		"overclock":
			_ability_overclock(target as Tower)
		"scrap_salvage":
			_ability_scrap_salvage()

func _ability_orbital_strike(pos: Vector2) -> void:
	# Warning indicator
	_spawn_ability_effect(pos, 80.0, Color(1.0, 0.4, 0.1, 0.3))
	# Damage after 1s delay
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var damage: float = 500.0
		var radius: float = 80.0
		for child in enemies.get_children():
			if child is Enemy and child.is_alive():
				if child.global_position.distance_to(pos) <= radius:
					var health := child.get_node_or_null("EnemyHealth") as EnemyHealth
					if health:
						health.take_damage(damage, Enums.DamageType.BEAM)
						_show_damage_popup(child.global_position, damage, Enums.DamageType.BEAM)
		_spawn_ability_effect(pos, 80.0, Color(1.0, 0.6, 0.2, 0.8))
	)

func _ability_emp_burst() -> void:
	for child in enemies.get_children():
		if child is Enemy and child.is_alive():
			child.apply_slow(0.0, 3.0)
	_hud.show_toast("EMP BURST!")

func _ability_repair_wave() -> void:
	# Cap at the actual starting lives for this run (respects daily challenge overrides)
	var max_lives: int = (GameManager.lives + GameManager.lives_lost) + _progression_manager.get_extra_lives()
	if GameManager.lives < max_lives:
		GameManager.lives += 1
		GameManager.lives_changed.emit(GameManager.lives, GameManager.lives_lost)
	_hud.show_toast("+1 " + tr("HUD_LIVES"))

func _ability_shield_matrix(pos: Vector2) -> void:
	var zone := _AbilityZone.new()
	zone.global_position = pos
	zone.setup(120.0, 6.0, 0.5)
	add_child(zone)

func _ability_overclock(tower: Tower) -> void:
	if not is_instance_valid(tower):
		return
	tower.apply_buff(self, 1.0, 3.0)
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(tower):
			tower.remove_buff(self)
	)
	_hud.show_toast("OVERCLOCK!")

func _ability_scrap_salvage() -> void:
	var original: float = EconomyManager.get_gold_modifier()
	EconomyManager.set_gold_modifier(original * 2.0)
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_inside_tree():
			EconomyManager.set_gold_modifier(original)
	)
	_hud.show_toast("2x GOLD!")

# ---------------------------------------------------------------------------
# Combat helpers (chain, pierce, buffs, income)
# ---------------------------------------------------------------------------

## Spawns a projectile from a tower toward a target enemy.
func _spawn_tower_projectile(tower: Tower, target_enemy: Enemy) -> void:
	if not tower.is_initialized():
		return
	var proj := Projectile.new()
	proj.global_position = tower.global_position
	proj.initialize(
		target_enemy.global_position,
		tower.get_projectile_speed(),
		tower.get_effective_damage(),
		tower.get_damage_type(),
		tower.get_effective_splash()
	)
	proj.hit_target.connect(_on_projectile_hit.bind(target_enemy.get_instance_id(), tower.get_instance_id()))
	projectiles.add_child(proj)

## Chain damage to nearby enemies from an initial hit position.
func _apply_chain_damage(origin: Vector2, chain_count: int, chain_range: float, damage: float, damage_type: int, already_hit: Array, armor_pierce: bool, shatter: bool = false, tower_type: int = -1) -> void:
	var last_pos: Vector2 = origin
	var hit_set: Array = already_hit.duplicate()
	for _c in range(chain_count):
		var best_enemy: Enemy = null
		var best_dist: float = chain_range * chain_range
		for child in enemies.get_children():
			if not (child is Enemy) or not child.is_alive():
				continue
			if hit_set.has(child):
				continue
			var d: float = last_pos.distance_squared_to(child.global_position)
			if d < best_dist:
				best_dist = d
				best_enemy = child as Enemy
		if best_enemy == null:
			break
		# Shatter synergy: slowed enemies take 2x chain damage
		var chain_dmg: float = damage
		if shatter and best_enemy.is_slowed():
			chain_dmg *= Constants.SYNERGY_SHATTER_CHAIN_DAMAGE_MULT
		_deal_damage_to_enemy(best_enemy, chain_dmg, damage_type, armor_pierce, tower_type)
		hit_set.append(best_enemy)
		last_pos = best_enemy.global_position
		damage *= 0.8  # Each chain hop does less damage

## Pierce: damage one additional enemy near the hit position.
func _apply_pierce(hit_pos: Vector2, damage: float, damage_type: int, already_hit: Array, armor_pierce: bool, tower_type: int = -1) -> void:
	var best_enemy: Enemy = null
	var best_dist: float = 100.0 * 100.0  # 100px pierce range
	for child in enemies.get_children():
		if not (child is Enemy) or not child.is_alive():
			continue
		if already_hit.has(child):
			continue
		var d: float = hit_pos.distance_squared_to(child.global_position)
		if d < best_dist:
			best_dist = d
			best_enemy = child as Enemy
	if best_enemy != null:
		_deal_damage_to_enemy(best_enemy, damage, damage_type, armor_pierce, tower_type)

## Recalculates all support tower buffs on all combat towers.
## Apply elite modifiers to an enemy in endless mode based on wave number.
func _maybe_apply_elite(enemy: Enemy) -> void:
	if _level_id != "endless":
		return
	var wave: int = _wave_manager.current_wave_index + 1
	if wave < Constants.ELITE_START_WAVE:
		return

	var elite_chance: float = 0.0
	if wave >= 50:
		elite_chance = 0.40
	elif wave >= 30:
		elite_chance = 0.20
	elif wave >= 20:
		elite_chance = 0.15
	else:
		elite_chance = 0.08

	if randf() >= elite_chance:
		return

	var modifier: int = _pick_random_elite_modifier()
	enemy.apply_elite_modifier(modifier)

	if wave >= Constants.ELITE_DOUBLE_MODIFIER_WAVE and randf() < 0.30:
		var second: int = _pick_random_elite_modifier()
		if second != modifier:
			enemy.apply_elite_modifier(second)

func _pick_random_elite_modifier() -> int:
	var pool: Array = [
		Enums.EliteModifier.REGENERATING,
		Enums.EliteModifier.SPLITTING,
		Enums.EliteModifier.PHASING,
		Enums.EliteModifier.MAGNETIC,
		Enums.EliteModifier.REFLECTIVE,
		Enums.EliteModifier.ENRAGED,
	]
	return pool[randi() % pool.size()]

func _on_elite_split_requested(pos: Vector2, def: EnemyDefinition, difficulty: int, path_idx: int, progress: float, remaining_mods: Array) -> void:
	if _enemy_paths.is_empty():
		return
	var path: Path2D = _enemy_paths[clampi(path_idx, 0, _enemy_paths.size() - 1)]
	for _i in range(Constants.ELITE_SPLIT_COUNT):
		var split := Enemy.new()
		if def.is_flying and path.curve != null and path.curve.point_count >= 2:
			var start_pos: Vector2 = pos
			var end_pos: Vector2 = path.to_global(path.curve.get_point_position(path.curve.point_count - 1))
			var flyer_provider := FlyerPathProvider.new()
			flyer_provider.setup(start_pos, end_pos)
			split.add_child(flyer_provider)
			split.set_path_provider(flyer_provider)
		else:
			var path_follow := PathFollow2D.new()
			path_follow.rotates = false
			path_follow.loop = false
			path.add_child(path_follow)
			path_follow.progress_ratio = clampf(progress, 0.0, 0.99)
			var provider := FixedPathProvider.new()
			provider.setup(path_follow)
			split.add_child(provider)
			split.set_path_provider(provider)
		enemies.add_child(split)
		split.add_to_group("enemies")
		split.initialize(def, difficulty)
		split.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		# Scale down HP for split copies
		var health: EnemyHealth = split.get_node_or_null("EnemyHealth")
		if health != null:
			health.set_hp_fraction(Constants.ELITE_SPLIT_HP_FRACTION)
		split.apply_speed_multiplier(Constants.ELITE_SPLIT_SPEED_MULT)
		# Apply remaining modifiers (no SPLITTING to prevent infinite chain)
		for mod in remaining_mods:
			split.apply_elite_modifier(mod as int)
		split.initialize_spawn_context(path_idx, difficulty)
		split.enemy_died.connect(_on_enemy_died)
		split.enemy_reached_exit.connect(_on_enemy_reached_exit)
		if _wave_manager:
			_wave_manager.register_extra_enemy()

func _recalculate_synergies() -> void:
	if _synergy_manager == null:
		return
	_synergy_manager.recalculate(towers)
	# Apply stat-based synergy buffs
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var t := child as Tower
		if t.get_synergy_type() == Enums.SynergyType.BARRAGE:
			t.apply_buff(_synergy_manager, 1.0, Constants.SYNERGY_BARRAGE_FIRE_RATE_MULT)
	# Redraw synergy lines
	for line_child in _synergy_lines.get_children():
		line_child.queue_free()
	var drawn: Dictionary = {}
	for child in towers.get_children():
		if not (child is Tower) or not (child as Tower).has_synergy():
			continue
		var t := child as Tower
		var pair_key: String = "%d_%d" % [mini(t.get_instance_id(), t.get_synergy_partner_id()), maxi(t.get_instance_id(), t.get_synergy_partner_id())]
		if drawn.has(pair_key):
			continue
		drawn[pair_key] = true
		var partner = instance_from_id(t.get_synergy_partner_id())
		if partner == null or not (partner is Tower):
			continue
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(1.0, 0.85, 0.0, 0.4)
		line.add_point(t.global_position)
		line.add_point((partner as Tower).global_position)
		_synergy_lines.add_child(line)

func _on_synergy_activated(_tower_a: Tower, _tower_b: Tower, synergy_type: int, synergy_name: String) -> void:
	_hud.show_toast(tr("SYNERGY_DISCOVERED") + ": " + synergy_name)
	var prog: Dictionary = SaveManager.data.get("progression", {})
	var discovered: Array = prog.get("synergies_discovered", [])
	if not discovered.has(synergy_type):
		discovered.append(synergy_type)
		prog["synergies_discovered"] = discovered
		SaveManager.save_game()

## Check if a wave reward should be offered after this wave.
func _check_wave_reward(wave_number: int) -> void:
	if _wave_reward_manager == null or _wave_manager == null:
		return
	if not _wave_reward_manager.should_offer_reward(wave_number):
		return
	# Pause the break timer while showing the reward UI
	_wave_manager.pause_break()
	var choices: Array = _wave_reward_manager.generate_choices()
	_show_wave_reward_ui(choices)

func _show_wave_reward_ui(choices: Array) -> void:
	var reward_ui = load("res://ui/hud/wave_reward_ui.gd").new()
	reward_ui.setup(choices)
	reward_ui.card_chosen.connect(_on_wave_reward_chosen)
	reward_ui.timer_expired.connect(_on_wave_reward_timeout)
	add_child(reward_ui)
	_wave_reward_ui = reward_ui

func _on_wave_reward_chosen(index: int) -> void:
	_wave_reward_manager.pick_reward(index)
	_apply_wave_reward_modifiers()
	_dismiss_wave_reward_ui()

func _on_wave_reward_timeout() -> void:
	_wave_reward_manager.pick_random()
	_apply_wave_reward_modifiers()
	_dismiss_wave_reward_ui()

func _dismiss_wave_reward_ui() -> void:
	if _wave_reward_ui != null:
		_wave_reward_ui.queue_free()
		_wave_reward_ui = null
	# Resume the break
	if _wave_manager != null:
		_wave_manager.resume_break(Constants.WAVE_BREAK_DURATION)

func _apply_wave_reward_modifiers() -> void:
	if _wave_reward_manager == null:
		return
	var mods: Dictionary = _wave_reward_manager.get_modifiers()
	# Apply immediate effects
	var lives_add: int = int(mods.get("lives_add", 0.0))
	if lives_add != 0:
		GameManager.lives = maxi(GameManager.lives + lives_add, 1)
		GameManager.lives_changed.emit(GameManager.lives, GameManager.lives_lost)
	# Apply adaptation decay multiplier
	var decay_mult: float = 1.0 + mods.get("adaptation_decay_mult", 0.0)
	if decay_mult > 1.0 and _adaptation_manager != null:
		_adaptation_manager.set_decay_multiplier(decay_mult)
	# Show toast for last picked reward
	var picked: Array = _wave_reward_manager.get_picked_rewards()
	if picked.size() > 0:
		var last: Dictionary = picked[picked.size() - 1]
		_hud.show_toast(last.get("display_name", "Buff") as String)

## Helper to get wave reward modifier value (0.0 if no manager).
func _get_reward_mod(key: String, default: float = 0.0) -> float:
	if _wave_reward_manager == null:
		return default
	return _wave_reward_manager.get_modifier_value(key, default)

# ---------------------------------------------------------------------------
# Signal Decode Minigame
# ---------------------------------------------------------------------------

func _show_signal_decode(_duration: float) -> void:
	if _wave_reward_ui != null:
		return
	# Pause the break timer so it doesn't expire while the minigame is active
	_wave_manager.pause_break()
	_hud.pause_break_countdown()
	var wave_num: int = _wave_manager.current_wave_index + 1
	var minigame = load("res://ui/hud/signal_decode_minigame.gd").new()
	minigame.setup(wave_num, _hud.tower_bar_total)
	minigame.decode_succeeded.connect(_on_decode_succeeded)
	minigame.decode_finished.connect(_on_decode_finished)
	ui.add_child(minigame)
	_signal_decode_minigame = minigame

func _on_decode_succeeded(reward_type: int, reward_value: float) -> void:
	match reward_type:
		0:  # GOLD
			EconomyManager.add_gold(int(reward_value))
			_hud.show_toast("+%d gold" % int(reward_value))
		1:  # DAMAGE_BUFF
			_signal_decode_damage_buff += reward_value
			_hud.show_toast("+%d%% damage" % int(reward_value * 100))
		2:  # EXTRA_LIFE
			GameManager.add_lives(int(reward_value))
			_hud.show_toast("+%d life" % int(reward_value))

func _on_decode_finished() -> void:
	if _signal_decode_minigame != null:
		_signal_decode_minigame.queue_free()
		_signal_decode_minigame = null
	# Resume the break timer from where it was paused (no re-emit to avoid re-triggering minigame)
	_wave_manager.unpause_break()
	_hud.unpause_break_countdown()

func _on_wave_started_dismiss_decode(_wave_number: int, _total_waves: int) -> void:
	if _signal_decode_minigame != null:
		_signal_decode_minigame.skip()


# ---------------------------------------------------------------------------
# Juice: Screen Flash + Life Effects
# ---------------------------------------------------------------------------

func _flash_screen(color: Color, duration: float) -> void:
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.4)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, duration)
	tw.tween_callback(flash.queue_free)

func _on_lives_changed_fx(new_lives: int, _delta: int) -> void:
	if new_lives < _prev_lives:
		_flash_screen(Color.RED, 0.5)
		if _game_camera != null:
			_game_camera.shake(4.0, 0.3)
	if new_lives == 1 and _low_life_vignette == null:
		_low_life_vignette = ColorRect.new()
		_low_life_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_low_life_vignette.color = Color(1.0, 0.0, 0.0, 0.08)
		_low_life_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(_low_life_vignette)
	elif new_lives > 1 and _low_life_vignette != null:
		_low_life_vignette.queue_free()
		_low_life_vignette = null
	_prev_lives = new_lives

# ---------------------------------------------------------------------------
# Juice: Gold Popup + Adaptation Glitch
# ---------------------------------------------------------------------------

func _show_gold_popup(world_pos: Vector2, amount: int) -> void:
	var screen_pos: Vector2 = get_canvas_transform() * (world_pos + Vector2(randf_range(-5, 5), -10))
	var label := Label.new()
	label.text = "+%dg" % amount
	label.position = screen_pos
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)

func _apply_glitch_effect(enemy: Enemy) -> void:
	var renderer := enemy.get_node_or_null("EnemyRenderer") as Node2D
	if renderer == null:
		return
	var tw := create_tween()
	tw.tween_property(renderer, "position", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.03)
	tw.tween_property(renderer, "position", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.03)
	tw.tween_property(renderer, "position", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.03)
	tw.tween_property(renderer, "position", Vector2.ZERO, 0.06)
	tw.parallel().tween_property(renderer, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.05)
	tw.tween_property(renderer, "modulate", Color.WHITE, 0.1)

func _recalculate_all_buffs() -> void:
	for child in towers.get_children():
		if child is Tower:
			(child as Tower).clear_buff()
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var support := child as Tower
		if not support.is_support_tower():
			continue
		var buff_range: float = support.get_effective_buff_range()
		var dmg_mult: float = support.get_effective_buff_damage_mult()
		var fr_mult: float = support.get_effective_buff_fire_rate_mult()
		if buff_range <= 0.0:
			continue
		for other_child in towers.get_children():
			if not (other_child is Tower) or other_child == child:
				continue
			if support.global_position.distance_to(other_child.global_position) <= buff_range:
				(other_child as Tower).apply_buff(support, dmg_mult, fr_mult)

## Collects income from all Harvester towers on wave complete.
func _collect_harvester_income(_wave_number: int) -> void:
	for child in towers.get_children():
		if not (child is Tower):
			continue
		var tower := child as Tower
		if not tower.is_income_tower():
			continue
		var income: int = tower.get_effective_income()
		# Efficiency synergy: +30% income
		if tower.get_synergy_type() == Enums.SynergyType.EFFICIENCY:
			income = int(float(income) * Constants.SYNERGY_EFFICIENCY_INCOME_MULT)
		if income > 0:
			EconomyManager.add_gold(income)

## Returns true if any hero is unlocked.
func _heroes_any_unlocked() -> bool:
	for tt in range(7):
		if _progression_manager.is_hero_unlocked(tt):
			return true
	return false

## Spawns a brief expanding ring effect at the given position.
func _spawn_ability_effect(pos: Vector2, radius: float, color: Color) -> void:
	var effect := _AbilityEffect.new()
	effect.global_position = pos
	effect.setup(radius, color)
	add_child(effect)

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

class _PlacementRing extends Node2D:
	## Expanding colored ring for tower placement/upgrade.
	var _color: Color = Color.CYAN
	var _radius: float = 20.0

	func setup(color: Color) -> void:
		_color = color

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(3.0, 3.0), 0.4)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, _radius, 0, TAU, 16, _color, 2.0)

class _AbilityEffect extends Node2D:
	## Expanding ring VFX for ability impacts.
	var _radius: float = 80.0
	var _color: Color = Color.WHITE

	func setup(radius: float, color: Color) -> void:
		_radius = radius
		_color = color

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.4)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, _radius, 0, TAU, 24, _color, 3.0)
		draw_circle(Vector2.ZERO, _radius * 0.3, Color(_color.r, _color.g, _color.b, 0.3))


class _AbilityZone extends Node2D:
	## Timed area that slows enemies within its radius.
	var _radius: float = 120.0
	var _duration: float = 6.0
	var _slow_factor: float = 0.5
	var _timer: float = 0.0

	func setup(radius: float, duration: float, slow_factor: float) -> void:
		_radius = radius
		_duration = duration
		_slow_factor = slow_factor
		_timer = duration

	func _process(delta: float) -> void:
		_timer -= delta
		queue_redraw()
		if _timer <= 0.0:
			queue_free()
			return
		# Slow enemies in radius
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D and node.has_method("apply_slow"):
				if global_position.distance_to(node.global_position) <= _radius:
					node.apply_slow(_slow_factor, 0.5)

	func _draw() -> void:
		var alpha: float = clampf(_timer / _duration, 0.0, 1.0) * 0.3
		draw_circle(Vector2.ZERO, _radius, Color(0.3, 0.5, 1.0, alpha))
		draw_arc(Vector2.ZERO, _radius, 0, TAU, 24, Color(0.4, 0.6, 1.0, alpha + 0.2), 2.0)


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
