extends Control

## Root scene manager for Last Signal.
## Handles top-level screen transitions, bootstraps campaign/audio systems,
## and wires all major UI screens to their respective managers.

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _campaign_manager: CampaignManager = null
var _daily_challenge_manager: DailyChallengeManager = null
var _iap_manager: IAPManager = null
var _ad_manager: AdManager = null
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

	# Restore economy from save data
	var economy_data: Dictionary = SaveManager.data.get("economy", {})
	EconomyManager.diamonds = economy_data.get("diamonds", 0) as int
	EconomyManager.diamond_doubler = economy_data.get("diamond_doubler", false) as bool
	EconomyManager.total_diamonds_earned = economy_data.get("total_diamonds_earned", 0) as int

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

	# Bootstrap daily challenge manager
	_daily_challenge_manager = DailyChallengeManager.new()
	_daily_challenge_manager.name = "DailyChallengeManager"
	add_child(_daily_challenge_manager)
	_daily_challenge_manager.setup(SaveManager)

	# Bootstrap monetization managers
	_iap_manager = IAPManager.new()
	_iap_manager.name = "IAPManager"
	add_child(_iap_manager)

	_ad_manager = AdManager.new()
	_ad_manager.name = "AdManager"
	add_child(_ad_manager)

	# If returning from a completed/failed level, go to campaign map; otherwise main menu
	if GameManager.current_state in [Enums.GameState.VICTORY, Enums.GameState.DEFEAT]:
		GameManager.change_state(Enums.GameState.MENU)
		_show_campaign_map()
	else:
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
	menu.open_daily_challenge.connect(_show_daily_challenge)
	menu.open_tower_lab.connect(_show_tower_lab)
	menu.open_diamond_shop.connect(_show_diamond_shop)
	menu.open_settings.connect(_show_settings)
	_switch_screen(menu)


func _show_campaign_map() -> void:
	var map := CampaignMap.new()
	map.level_chosen.connect(_on_level_chosen)
	map.back_pressed.connect(_show_main_menu)
	_switch_screen(map)
	# populate after adding to tree so _ready() creates child nodes first
	var all_levels: Array = _campaign_manager.get_all_levels()
	map.populate(all_levels, SaveManager.data["campaign"])


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
	var level_def: Dictionary = _campaign_manager.get_level(_pending_level_id)
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
	# Disconnect stale connections first to prevent signal stacking across level transitions
	_disconnect_level_signals()
	GameManager.level_completed.connect(_on_campaign_level_complete)
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

	# Disconnect stale campaign signals, connect endless failure handler
	_disconnect_level_signals()
	GameManager.level_failed.connect(_on_endless_failed)


func _show_daily_challenge() -> void:
	AudioManager.set_music_state(Enums.GameState.MENU)
	var screen = load("res://ui/menus/daily_challenge_screen.gd").new()
	var challenge: Dictionary = _daily_challenge_manager.get_today_challenge()
	screen.setup(challenge)
	screen.play_pressed.connect(_start_daily_challenge)
	screen.back_pressed.connect(_show_main_menu)
	_switch_screen(screen)

func _start_daily_challenge() -> void:
	AudioManager.set_music_state(Enums.GameState.BUILDING)
	var game_scene := load("res://scenes/game.tscn").instantiate() as Node
	_switch_screen(game_scene)
	_disconnect_level_signals()
	# Pass challenge constraints to the game scene before starting
	var constraints: Dictionary = _daily_challenge_manager.get_constraints()
	var challenge: Dictionary = _daily_challenge_manager.get_today_challenge()
	constraints["seed"] = challenge.get("seed", 0)
	game_scene._challenge_constraints = constraints
	# Connect completion/failure handlers
	GameManager.level_completed.connect(_on_daily_challenge_complete)
	GameManager.level_failed.connect(_on_daily_challenge_failed)
	game_scene.start_level("daily_challenge", Enums.Difficulty.NORMAL)

func _show_tower_lab() -> void:
	AudioManager.set_music_state(Enums.GameState.MENU)

	var lab := TowerLab.new()
	var pm := ProgressionManager.new()
	pm.name = "ProgressionManager"
	add_child(pm)
	pm.setup(EconomyManager, SaveManager)
	lab.back_pressed.connect(func() -> void:
		pm.queue_free()
		_show_main_menu()
	)
	_switch_screen(lab)
	# setup() must be called after _switch_screen so _ready() has created child nodes
	lab.setup(pm, EconomyManager)


func _show_diamond_shop() -> void:
	AudioManager.set_music_state(Enums.GameState.MENU)

	var shop := DiamondShop.new()
	shop.back_pressed.connect(_show_main_menu)
	shop.purchase_requested.connect(_on_shop_purchase)
	shop.watch_ad_requested.connect(_on_shop_watch_ad)
	_switch_screen(shop)
	# Update diamond balance display and ad button after adding to tree
	shop.update_diamonds(EconomyManager.diamonds)
	if _ad_manager.has_no_ads(SaveManager):
		shop.mark_purchased("no_ads")
	shop.update_ad_button(_ad_manager.get_remaining_ads(SaveManager))
	if _iap_manager.has_doubler(SaveManager):
		shop.mark_purchased("doubler")
	if SaveManager.data.get("unlocks", {}).get("speed_x2", false):
		shop.mark_purchased("speed_x2")
	if SaveManager.data.get("unlocks", {}).get("speed_x3", false):
		shop.mark_purchased("speed_x3")


func _on_shop_purchase(pack_id: String) -> void:
	if pack_id == "speed_x2":
		# x2 speed is purchased with diamonds, not real money
		if not EconomyManager.can_afford_diamonds(500):
			return
		EconomyManager.spend_diamonds(500)
		SaveManager.data["unlocks"]["speed_x2"] = true
		SaveManager.sync_economy(EconomyManager)
		SaveManager.save_game()
	else:
		_iap_manager.request_purchase(pack_id, EconomyManager, SaveManager)
	# Refresh shop UI
	if _current_screen is DiamondShop:
		var shop: DiamondShop = _current_screen as DiamondShop
		shop.update_diamonds(EconomyManager.diamonds)
		if pack_id == "no_ads":
			shop.mark_purchased("no_ads")
			shop.update_ad_button(_ad_manager.get_remaining_ads(SaveManager))
		elif pack_id == "doubler":
			shop.mark_purchased("doubler")
		elif pack_id == "speed_x2":
			shop.mark_purchased("speed_x2")
		elif pack_id == "speed_x3":
			shop.mark_purchased("speed_x3")


func _on_shop_watch_ad() -> void:
	_ad_manager.request_ad(EconomyManager, SaveManager)
	# Refresh shop UI
	if _current_screen is DiamondShop:
		var shop: DiamondShop = _current_screen as DiamondShop
		shop.update_diamonds(EconomyManager.diamonds)
		shop.update_ad_button(_ad_manager.get_remaining_ads(SaveManager))


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

## Disconnect all level-related signal handlers to prevent stacking across transitions.
func _disconnect_level_signals() -> void:
	if GameManager.level_completed.is_connected(_on_campaign_level_complete):
		GameManager.level_completed.disconnect(_on_campaign_level_complete)
	if GameManager.level_completed.is_connected(_on_daily_challenge_complete):
		GameManager.level_completed.disconnect(_on_daily_challenge_complete)
	if GameManager.level_failed.is_connected(_on_campaign_level_failed):
		GameManager.level_failed.disconnect(_on_campaign_level_failed)
	if GameManager.level_failed.is_connected(_on_endless_failed):
		GameManager.level_failed.disconnect(_on_endless_failed)
	if GameManager.level_failed.is_connected(_on_daily_challenge_failed):
		GameManager.level_failed.disconnect(_on_daily_challenge_failed)


func _on_campaign_level_complete(level_id: String, stars: int) -> void:
	_campaign_manager.on_level_complete(level_id, stars, GameManager.current_difficulty)
	# Diamonds already awarded by GameLoop._on_all_waves_complete()
	# Just sync and save
	SaveManager.sync_economy(EconomyManager)
	SaveManager.save_game()
	# Navigation happens when user clicks Continue in the victory screen


func _on_campaign_level_failed(_level_id: String) -> void:
	# Return to campaign map after a short delay or immediately
	_show_campaign_map()


func _on_daily_challenge_complete(_level_id: String, stars: int) -> void:
	_daily_challenge_manager.mark_completed(stars)
	var diamonds: int = _daily_challenge_manager.get_reward_diamonds(stars)
	EconomyManager.add_diamonds(diamonds)
	SaveManager.sync_economy(EconomyManager)
	SaveManager.save_game()
	# Show rewarded interstitial for bonus diamonds
	if _ad_manager != null:
		var bonus: int = Constants.DAILY_CHALLENGE_RI_BONUS
		_ad_manager.show_rewarded_interstitial(EconomyManager, SaveManager, bonus)

func _on_daily_challenge_failed(_level_id: String) -> void:
	_show_main_menu()

func _on_endless_failed(_level_id: String) -> void:
	_show_main_menu()
