extends GutTest

## Verifies that every translation key referenced by the Plan 6 UI scripts
## exists in content/translations/ui.csv.
## Run with the GUT addon in the Godot editor.

# ---------------------------------------------------------------------------
# All keys used by the UI scripts — single source of truth
# ---------------------------------------------------------------------------

const REQUIRED_KEYS: Array = [
	# top_bar.gd
	"HUD_LIVES",
	"HUD_GOLD",
	"HUD_WAVE",
	"HUD_SEND_WAVE",
	"HUD_SPEED",

	# tower_button.gd / tower_bar.gd
	"TOWER_PULSE_CANNON",
	"TOWER_ARC_EMITTER",
	"TOWER_CRYO_ARRAY",
	"TOWER_MISSILE_POD",
	"TOWER_BEAM_SPIRE",
	"TOWER_NANO_HIVE",
	"TOWER_HARVESTER",

	# tower_upgrade_panel.gd
	"TIER",
	"HUD_TARGETING",
	"TARGETING_NEAREST",
	"TARGETING_STRONGEST",
	"TARGETING_WEAKEST",
	"TARGETING_FIRST",
	"TARGETING_LAST",
	"HUD_SELL",
	"HUD_UPGRADE",
	"UI_COMPLETED",

	# ability_bar.gd
	"ABILITY_ORBITAL_STRIKE",
	"ABILITY_EMP_BURST",
	"ABILITY_REPAIR_WAVE",
	"ABILITY_SHIELD_MATRIX",
	"ABILITY_OVERCLOCK",
	"ABILITY_SCRAP_SALVAGE",

	# hud.gd
	"ENDLESS_RESISTANCE",

	# main_menu.gd
	"UI_PLAY_CAMPAIGN",
	"UI_ENDLESS_MODE",
	"UI_TOWER_LAB",
	"UI_SETTINGS",

	# settings_menu.gd
	"SETTINGS_MUSIC_VOLUME",
	"SETTINGS_SFX_VOLUME",
	"SETTINGS_LANGUAGE",
	"SETTINGS_DAMAGE_NUMBERS",
	"SETTINGS_RANGE_ON_HOVER",
	"UI_BACK",

	# level_node.gd
	"UI_LOCKED",

	# campaign_map.gd
	"UI_LEVEL_SELECT",
	"UI_REGION",
	"DIFFICULTY_NORMAL",
	"DIFFICULTY_HARD",
	"DIFFICULTY_NIGHTMARE",

	# tower_lab.gd
	"UI_DIAMOND_SHOP",
	"UI_DIAMONDS",
	"SKILL_TREE",
	"GLOBAL_UPGRADES",
	"UI_UPGRADE",
	"UI_UNLOCK",

	# diamond_shop.gd
	"WATCH_AD",
	"NO_ADS",
	"ADS_REMAINING",

	# pause_menu.gd
	"UI_PAUSE",
	"UI_RESUME",
	"UI_RESTART",
	"UI_QUIT_LEVEL",

	# level_complete.gd
	"UI_VICTORY",
	"UI_STARS",
	"UI_CONTINUE",
]

# ---------------------------------------------------------------------------
# Setup — parse CSV once
# ---------------------------------------------------------------------------

var _csv_keys: Array = []

func before_all() -> void:
	var file := FileAccess.open("res://content/translations/ui.csv", FileAccess.READ)
	if file == null:
		push_error("test_ui_translation_keys: cannot open translations CSV")
		return
	file.get_line()  # skip header row
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts: Array = line.split(",", false, 1)
		if parts.size() >= 1:
			_csv_keys.append(parts[0] as String)
	file.close()


func _has_key(key: String) -> bool:
	return _csv_keys.has(key)

# ---------------------------------------------------------------------------
# Individual per-key tests (one assert each = clear failure reporting)
# ---------------------------------------------------------------------------

func test_hud_lives_key() -> void:
	assert_true(_has_key("HUD_LIVES"), "Missing: HUD_LIVES")

func test_hud_gold_key() -> void:
	assert_true(_has_key("HUD_GOLD"), "Missing: HUD_GOLD")

func test_hud_wave_key() -> void:
	assert_true(_has_key("HUD_WAVE"), "Missing: HUD_WAVE")

func test_hud_send_wave_key() -> void:
	assert_true(_has_key("HUD_SEND_WAVE"), "Missing: HUD_SEND_WAVE")

func test_hud_speed_key() -> void:
	assert_true(_has_key("HUD_SPEED"), "Missing: HUD_SPEED")

func test_hud_sell_key() -> void:
	assert_true(_has_key("HUD_SELL"), "Missing: HUD_SELL")

func test_hud_upgrade_key() -> void:
	assert_true(_has_key("HUD_UPGRADE"), "Missing: HUD_UPGRADE")

func test_hud_targeting_key() -> void:
	assert_true(_has_key("HUD_TARGETING"), "Missing: HUD_TARGETING")

func test_targeting_modes() -> void:
	assert_true(_has_key("TARGETING_NEAREST"),  "Missing: TARGETING_NEAREST")
	assert_true(_has_key("TARGETING_STRONGEST"), "Missing: TARGETING_STRONGEST")
	assert_true(_has_key("TARGETING_WEAKEST"),  "Missing: TARGETING_WEAKEST")
	assert_true(_has_key("TARGETING_FIRST"),    "Missing: TARGETING_FIRST")
	assert_true(_has_key("TARGETING_LAST"),     "Missing: TARGETING_LAST")

func test_tier_key() -> void:
	assert_true(_has_key("TIER"), "Missing: TIER")

func test_ability_keys() -> void:
	assert_true(_has_key("ABILITY_ORBITAL_STRIKE"),  "Missing: ABILITY_ORBITAL_STRIKE")
	assert_true(_has_key("ABILITY_EMP_BURST"),       "Missing: ABILITY_EMP_BURST")
	assert_true(_has_key("ABILITY_REPAIR_WAVE"),     "Missing: ABILITY_REPAIR_WAVE")
	assert_true(_has_key("ABILITY_SHIELD_MATRIX"),   "Missing: ABILITY_SHIELD_MATRIX")
	assert_true(_has_key("ABILITY_OVERCLOCK"),       "Missing: ABILITY_OVERCLOCK")
	assert_true(_has_key("ABILITY_SCRAP_SALVAGE"),   "Missing: ABILITY_SCRAP_SALVAGE")

func test_tower_keys() -> void:
	assert_true(_has_key("TOWER_PULSE_CANNON"), "Missing: TOWER_PULSE_CANNON")
	assert_true(_has_key("TOWER_ARC_EMITTER"),  "Missing: TOWER_ARC_EMITTER")
	assert_true(_has_key("TOWER_CRYO_ARRAY"),   "Missing: TOWER_CRYO_ARRAY")
	assert_true(_has_key("TOWER_MISSILE_POD"),  "Missing: TOWER_MISSILE_POD")
	assert_true(_has_key("TOWER_BEAM_SPIRE"),   "Missing: TOWER_BEAM_SPIRE")
	assert_true(_has_key("TOWER_NANO_HIVE"),    "Missing: TOWER_NANO_HIVE")
	assert_true(_has_key("TOWER_HARVESTER"),    "Missing: TOWER_HARVESTER")

func test_main_menu_keys() -> void:
	assert_true(_has_key("UI_PLAY_CAMPAIGN"), "Missing: UI_PLAY_CAMPAIGN")
	assert_true(_has_key("UI_ENDLESS_MODE"),  "Missing: UI_ENDLESS_MODE")
	assert_true(_has_key("UI_TOWER_LAB"),     "Missing: UI_TOWER_LAB")
	assert_true(_has_key("UI_SETTINGS"),      "Missing: UI_SETTINGS")

func test_settings_menu_keys() -> void:
	assert_true(_has_key("SETTINGS_MUSIC_VOLUME"),   "Missing: SETTINGS_MUSIC_VOLUME")
	assert_true(_has_key("SETTINGS_SFX_VOLUME"),     "Missing: SETTINGS_SFX_VOLUME")
	assert_true(_has_key("SETTINGS_LANGUAGE"),       "Missing: SETTINGS_LANGUAGE")
	assert_true(_has_key("SETTINGS_DAMAGE_NUMBERS"), "Missing: SETTINGS_DAMAGE_NUMBERS")
	assert_true(_has_key("SETTINGS_RANGE_ON_HOVER"), "Missing: SETTINGS_RANGE_ON_HOVER")

func test_campaign_map_keys() -> void:
	assert_true(_has_key("UI_LEVEL_SELECT"),    "Missing: UI_LEVEL_SELECT")
	assert_true(_has_key("UI_REGION"),          "Missing: UI_REGION")
	assert_true(_has_key("UI_LOCKED"),          "Missing: UI_LOCKED")
	assert_true(_has_key("DIFFICULTY_NORMAL"),  "Missing: DIFFICULTY_NORMAL")
	assert_true(_has_key("DIFFICULTY_HARD"),    "Missing: DIFFICULTY_HARD")
	assert_true(_has_key("DIFFICULTY_NIGHTMARE"), "Missing: DIFFICULTY_NIGHTMARE")

func test_tower_lab_keys() -> void:
	assert_true(_has_key("SKILL_TREE"),      "Missing: SKILL_TREE")
	assert_true(_has_key("GLOBAL_UPGRADES"), "Missing: GLOBAL_UPGRADES")
	assert_true(_has_key("UI_UNLOCK"),       "Missing: UI_UNLOCK")
	assert_true(_has_key("UI_UPGRADE"),      "Missing: UI_UPGRADE")
	assert_true(_has_key("UI_COMPLETED"),    "Missing: UI_COMPLETED")

func test_diamond_shop_keys() -> void:
	assert_true(_has_key("UI_DIAMOND_SHOP"), "Missing: UI_DIAMOND_SHOP")
	assert_true(_has_key("UI_DIAMONDS"),     "Missing: UI_DIAMONDS")
	assert_true(_has_key("WATCH_AD"),        "Missing: WATCH_AD")
	assert_true(_has_key("NO_ADS"),          "Missing: NO_ADS")
	assert_true(_has_key("ADS_REMAINING"),   "Missing: ADS_REMAINING")

func test_pause_menu_keys() -> void:
	assert_true(_has_key("UI_PAUSE"),      "Missing: UI_PAUSE")
	assert_true(_has_key("UI_RESUME"),     "Missing: UI_RESUME")
	assert_true(_has_key("UI_RESTART"),    "Missing: UI_RESTART")
	assert_true(_has_key("UI_QUIT_LEVEL"), "Missing: UI_QUIT_LEVEL")

func test_level_complete_keys() -> void:
	assert_true(_has_key("UI_VICTORY"),  "Missing: UI_VICTORY")
	assert_true(_has_key("UI_STARS"),    "Missing: UI_STARS")
	assert_true(_has_key("UI_CONTINUE"), "Missing: UI_CONTINUE")

func test_hud_adaptation_warning_key() -> void:
	assert_true(_has_key("ENDLESS_RESISTANCE"), "Missing: ENDLESS_RESISTANCE")

func test_common_ui_keys() -> void:
	assert_true(_has_key("UI_BACK"),    "Missing: UI_BACK")
	assert_true(_has_key("UI_CONFIRM"), "Missing: UI_CONFIRM")
	assert_true(_has_key("UI_CANCEL"),  "Missing: UI_CANCEL")

# ---------------------------------------------------------------------------
# Bulk coverage check — ensures REQUIRED_KEYS array stays in sync with CSV
# ---------------------------------------------------------------------------

func test_all_required_keys_present() -> void:
	var missing: Array = []
	for key in REQUIRED_KEYS:
		if not _has_key(key):
			missing.append(key)
	assert_eq(missing.size(), 0,
		"Missing translation keys: %s" % str(missing))
