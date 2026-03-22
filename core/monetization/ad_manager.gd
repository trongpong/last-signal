class_name AdManager
extends Node

## Manages rewarded-ad viewing with a per-day cap.
## Uses Poing-Studios godot-admob-plugin v4.1.0 when the native plugin is
## present on Android/iOS. Falls back to instant simulation on desktop/editor.
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

var _rewarded_ad: RewardedAd = null
var _ad_loading: bool = false
var _pending_economy = null
var _pending_save = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if _is_mobile():
		MobileAds.initialize()
		_load_rewarded_ad()

func _is_mobile() -> bool:
	return OS.get_name() in ["Android", "iOS"]

func _get_ad_unit_id() -> String:
	if OS.is_debug_build():
		return AD_UNIT_ID_TEST
	return AD_UNIT_ID_ANDROID

# ---------------------------------------------------------------------------
# Ad loading
# ---------------------------------------------------------------------------

func _load_rewarded_ad() -> void:
	if _ad_loading:
		return
	_ad_loading = true

	var loader := RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_rewarded_ad_loaded
	callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load
	loader.load(_get_ad_unit_id(), AdRequest.new(), callback)

func _on_rewarded_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad
	_ad_loading = false

	# Wire close callback to pre-load next ad
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed

func _on_rewarded_ad_failed_to_load(_error) -> void:
	_rewarded_ad = null
	_ad_loading = false
	# Retry after delay
	if is_inside_tree():
		get_tree().create_timer(10.0).timeout.connect(_load_rewarded_ad)

func _on_ad_dismissed() -> void:
	# Destroy old ad and pre-load next one
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
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
## On mobile with AdMob plugin: shows a real ad, reward granted on completion.
## On desktop/editor: simulates instantly (no actual ad shown).
func request_ad(economy, save) -> void:
	if not can_watch_ad(save):
		ad_failed.emit()
		return

	if _is_mobile() and _rewarded_ad != null:
		# Show real AdMob rewarded ad — reward granted via callback
		_pending_economy = economy
		_pending_save = save
		var reward_listener := OnUserEarnedRewardListener.new()
		reward_listener.on_user_earned_reward = _on_user_earned_reward
		_rewarded_ad.show(reward_listener)
		return

	# Simulation fallback (desktop/editor or ad not loaded)
	_grant_reward(economy, save)

# ---------------------------------------------------------------------------
# Reward callback
# ---------------------------------------------------------------------------

func _on_user_earned_reward(_rewarded_item) -> void:
	if _pending_economy != null and _pending_save != null:
		_grant_reward(_pending_economy, _pending_save)
	_pending_economy = null
	_pending_save = null

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
