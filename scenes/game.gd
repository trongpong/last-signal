extends Node2D

## Root script for the main game scene.
## Creates HUD, loads level data, manages the game loop.

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
var _game_loop: GameLoop
var _wave_manager: WaveManager
var _adaptation_manager: AdaptationManager

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Build the HUD
	_build_hud()

	# Connect to manager signals
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.lives_changed.connect(_on_lives_changed)

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
	var LevelData = load("res://content/levels/level_data.gd")
	if LevelData and LevelData.has_method("get_waves"):
		waves = LevelData.get_waves(level_id)

	# Setup wave manager
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	if waves.size() > 0:
		_wave_manager.load_waves(waves)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_complete.connect(_on_wave_complete)
	_wave_manager.all_waves_complete.connect(_on_all_waves_complete)

	# Setup adaptation manager
	_adaptation_manager = AdaptationManager.new()
	add_child(_adaptation_manager)
	_adaptation_manager.setup(difficulty, false)

	# Update HUD
	_update_hud()

# ---------------------------------------------------------------------------
# HUD building
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_hud.add_child(info_label)

	# Bottom bar with back button
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -50
	bottom_bar.add_theme_constant_override("separation", 10)
	_hud.add_child(bottom_bar)

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

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_state_changed(new_state: int, _old_state: int) -> void:
	_update_hud()

func _on_lives_changed(new_lives: int, _lives_lost: int) -> void:
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

func _process(_delta: float) -> void:
	# Keep gold display updated
	if _hud:
		var gold_label := _hud.get_node_or_null("TopBar/GoldLabel") as Label
		if gold_label:
			gold_label.text = "GOLD: %d" % EconomyManager.gold
