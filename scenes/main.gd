extends Node

## Root scene manager for Last Signal.
## Handles top-level screen transitions, bootstraps campaign/audio systems,
## and wires all major UI screens to their respective managers.

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _campaign_manager: CampaignManager = null
var _current_screen: Node = null

## Level id and difficulty selected on the campaign map, used when launching.
var _pending_level_id: String = ""
var _pending_difficulty: int = Enums.Difficulty.NORMAL

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Load saved progress
	SaveManager.load_game()

	# Apply saved audio settings
	var settings: Dictionary = SaveManager.data.get("profile", {}).get("settings", {})
	AudioManager.set_music_volume(settings.get("music_vol", 1.0) as float)
	AudioManager.set_sfx_volume(settings.get("sfx_vol", 1.0) as float)

	# Apply saved locale
	var lang: String = SaveManager.data.get("profile", {}).get("language", "en") as String
	TranslationServer.set_locale(lang)

	# Bootstrap campaign manager
	_campaign_manager = CampaignManager.new()
	_campaign_manager.name = "CampaignManager"
	add_child(_campaign_manager)
	_campaign_manager.setup(SaveManager)

	# Start at main menu
	_show_main_menu()

# ---------------------------------------------------------------------------
# Screen transitions
# ---------------------------------------------------------------------------

func _show_main_menu() -> void:
	AudioManager.set_music_state(Enums.GameState.MENU)

	var menu := MainMenu.new()
	menu.set_endless_unlocked(_campaign_manager.is_endless_unlocked())
	menu.play_campaign.connect(_show_campaign_map)
	menu.play_endless.connect(_start_endless)
	menu.open_tower_lab.connect(_show_tower_lab)
	menu.open_settings.connect(_show_settings)
	_switch_screen(menu)


func _show_campaign_map() -> void:
	var map := CampaignMap.new()
	var all_levels: Array = []
	for region in range(1, _campaign_manager._registry.get_region_count() + 1):
		all_levels.append_array(_campaign_manager._registry.get_levels_for_region(region))
	map.populate(all_levels, SaveManager.data["campaign"])
	map.level_chosen.connect(_on_level_chosen)
	map.back_pressed.connect(_show_main_menu)
	_switch_screen(map)


func _on_level_chosen(level_id: String, difficulty: int) -> void:
	if not _campaign_manager.is_level_unlocked(level_id):
		return  # silently ignore locked levels
	_pending_level_id = level_id
	_pending_difficulty = difficulty
	_start_campaign_level()


func _start_campaign_level() -> void:
	if _pending_level_id.is_empty():
		return

	AudioManager.set_music_state(Enums.GameState.BUILDING)

	# Determine region for adaptive music
	var level_def: Dictionary = _campaign_manager._registry.get_level(_pending_level_id)
	if not level_def.is_empty():
		var region: int = level_def.get("region", 1) as int
		AudioManager.set_music_region(region)

	# Load the game scene; wire completion/failure back to campaign
	var game_scene := load("res://scenes/game.tscn").instantiate() as Node
	_switch_screen(game_scene)

	# Start the level via GameManager (already present as autoload)
	if game_scene.has_method("start_level"):
		game_scene.start_level(_pending_level_id, _pending_difficulty)

	# Wire level_completed on GameManager to record campaign progress
	if not GameManager.level_completed.is_connected(_on_campaign_level_complete):
		GameManager.level_completed.connect(_on_campaign_level_complete)
	if not GameManager.level_failed.is_connected(_on_campaign_level_failed):
		GameManager.level_failed.connect(_on_campaign_level_failed)


func _start_endless() -> void:
	if not _campaign_manager.is_endless_unlocked():
		return

	AudioManager.set_music_state(Enums.GameState.BUILDING)
	AudioManager.set_music_region(5)

	# Load the game scene in endless mode
	var game_scene := load("res://scenes/game.tscn").instantiate() as Node
	_switch_screen(game_scene)

	# GameManager start without a campaign level_id flags endless intent
	GameManager.start_level("endless", _pending_difficulty)

	if not GameManager.level_failed.is_connected(_on_endless_failed):
		GameManager.level_failed.connect(_on_endless_failed)


func _show_tower_lab() -> void:
	AudioManager.set_music_state(Enums.GameState.MENU)

	var lab := TowerLab.new()
	var pm := ProgressionManager.new()
	pm.name = "ProgressionManager"
	add_child(pm)
	pm.setup(EconomyManager, SaveManager)
	lab.setup(pm, EconomyManager)
	lab.back_pressed.connect(func() -> void:
		pm.queue_free()
		_show_main_menu()
	)
	_switch_screen(lab)


func _show_settings() -> void:
	var settings := SettingsMenu.new()
	settings.back_pressed.connect(_show_main_menu)
	_switch_screen(settings)

# ---------------------------------------------------------------------------
# Screen swap helper
# ---------------------------------------------------------------------------

func _switch_screen(new_screen: Node) -> void:
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = new_screen
	add_child(new_screen)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_campaign_level_complete(level_id: String, stars: int) -> void:
	_campaign_manager.on_level_complete(level_id, stars, GameManager.current_difficulty)
	# Award diamonds: base = stars * 10, scaled by difficulty
	var constants := Constants.new()
	var mult: float = constants.DIFFICULTY_DIAMOND_MULT.get(
		GameManager.current_difficulty, 1.0) as float
	constants.free()
	var diamonds: int = int(float(stars * 10) * mult)
	EconomyManager.add_diamonds(diamonds)
	SaveManager.sync_economy(EconomyManager)
	SaveManager.save_game()


func _on_campaign_level_failed(_level_id: String) -> void:
	# Return to campaign map after a short delay or immediately
	_show_campaign_map()


func _on_endless_failed(_level_id: String) -> void:
	_show_main_menu()
