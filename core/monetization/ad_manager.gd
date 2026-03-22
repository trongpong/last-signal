class_name AdManager
extends Node

## Manages rewarded-ad viewing with a per-day cap.
## Uses Poing-Studios godot-admob-plugin when available, falls back to
## instant simulation for desktop/editor development.
## Uses Constants.MAX_ADS_PER_DAY and Constants.DIAMONDS_PER_AD.

# ---------------------------------------------------------------------------
# Ad Unit IDs
# ---------------------------------------------------------------------------

## Production AdMob rewarded ad unit ID (Android)
const AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/4258670828"
## Test ad unit ID — use during development
const AD_UNIT_ID_TEST: String = "ca-app-pub-3940256099942544/5224354917"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ad_reward_granted(diamonds: int)
signal ad_failed

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _admob_available: bool = false
var _rewarded_ad_loaded: bool = false
var _pending_economy = null
var _pending_save = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_admob_available = Engine.has_singleton("AdMob")
	if _admob_available:
		_init_admob()

func _init_admob() -> void:
	var admob = Engine.get_singleton("AdMob")
	if admob == null:
		_admob_available = false
		return

	# Initialize AdMob — use test ads in debug builds
	var is_debug: bool = OS.is_debug_build()
	admob.initialize(is_debug)

	# Connect rewarded ad signals
	if admob.has_signal("rewarded_ad_loaded"):
		admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	if admob.has_signal("rewarded_ad_failed_to_load"):
		admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	if admob.has_signal("user_earned_reward"):
		admob.user_earned_reward.connect(_on_user_earned_reward)
	if admob.has_signal("rewarded_ad_closed"):
		admob.rewarded_ad_closed.connect(_on_rewarded_ad_closed)

	# Pre-load the first rewarded ad
	_load_rewarded_ad()

func _get_ad_unit_id() -> String:
	if OS.is_debug_build():
		return AD_UNIT_ID_TEST
	return AD_UNIT_ID_ANDROID

func _load_rewarded_ad() -> void:
	if not _admob_available:
		return
	var admob = Engine.get_singleton("AdMob")
	if admob != null and admob.has_method("load_rewarded_ad"):
		admob.load_rewarded_ad(_get_ad_unit_id())

# ---------------------------------------------------------------------------
# AdMob signal callbacks
# ---------------------------------------------------------------------------

func _on_rewarded_ad_loaded() -> void:
	_rewarded_ad_loaded = true

func _on_rewarded_ad_failed_to_load(_error_code: int = 0) -> void:
	_rewarded_ad_loaded = false
	# Retry after a delay
	get_tree().create_timer(10.0).timeout.connect(_load_rewarded_ad)

func _on_user_earned_reward(_currency: String = "", _amount: int = 0) -> void:
	# Reward is granted here — the ad was watched successfully
	if _pending_economy != null and _pending_save != null:
		_grant_reward(_pending_economy, _pending_save)
	_pending_economy = null
	_pending_save = null

func _on_rewarded_ad_closed() -> void:
	# Pre-load the next ad
	_load_rewarded_ad()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if the player can still watch an ad today.
func can_watch_ad(save) -> bool:
	if save == null:
		return false
	if has_no_ads(save):
		return false
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return watched < Constants.MAX_ADS_PER_DAY

## Returns the number of ads remaining today.
func get_remaining_ads(save) -> int:
	if save == null:
		return 0
	if has_no_ads(save):
		return 0
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return max(0, Constants.MAX_ADS_PER_DAY - watched)

## Returns true if the player has purchased the no-ads upgrade.
func has_no_ads(save) -> bool:
	if save == null:
		return false
	return save.data["monetization"].get("no_ads_purchased", false) as bool

## Attempt to watch a rewarded ad.
## On Android with AdMob: shows a real ad, reward granted on completion.
## On desktop/editor: simulates instantly (no actual ad shown).
func request_ad(economy, save) -> void:
	if not can_watch_ad(save):
		ad_failed.emit()
		return

	if _admob_available and _rewarded_ad_loaded:
		# Show real AdMob rewarded ad — reward granted via callback
		_pending_economy = economy
		_pending_save = save
		var admob = Engine.get_singleton("AdMob")
		if admob != null and admob.has_method("show_rewarded_ad"):
			admob.show_rewarded_ad()
			return
		# Fallback if show failed
		_pending_economy = null
		_pending_save = null

	# Simulation fallback (desktop/editor or ad not loaded)
	_grant_reward(economy, save)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Grants the ad reward: increments watch count, adds diamonds, saves.
func _grant_reward(economy, save) -> void:
	save.data["monetization"]["ads_watched_today"] += 1

	var reward: int = Constants.DIAMONDS_PER_AD
	if economy != null:
		economy.add_diamonds(reward)

	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()

	ad_reward_granted.emit(reward)

## Resets the daily ad counter if the calendar date has changed since last reset.
func _check_date_reset(save) -> void:
	if save == null:
		return

	var today: String = Time.get_date_string_from_system()
	var last_reset: String = save.data["monetization"].get("ads_last_reset_date", "") as String

	if today != last_reset:
		save.data["monetization"]["ads_watched_today"] = 0
		save.data["monetization"]["ads_last_reset_date"] = today
