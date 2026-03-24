class_name AdManager
extends Node

## Manages rewarded-ad viewing with a per-day cap.
## Uses Poing-Studios godot-admob-plugin v4.1.0 on Android/iOS at runtime.
## All plugin access is fully dynamic via ClassDB to avoid parse errors
## in the editor where plugin classes don't exist.
## Falls back to instant simulation on desktop/editor.

# ---------------------------------------------------------------------------
# Ad Unit IDs
# ---------------------------------------------------------------------------

const AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/4258670828"
const AD_UNIT_ID_TEST: String = "ca-app-pub-3940256099942544/5224354917"

const DC_AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/5883745702"
const DC_AD_UNIT_ID_TEST: String = "ca-app-pub-3940256099942544/5354046379"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ad_reward_granted(diamonds: int)
signal ad_failed
signal rewarded_interstitial_reward_granted(diamonds: int)
signal rewarded_interstitial_dismissed
signal bonus_ad_reward_granted(diamonds: int)
signal bonus_ad_failed

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _rewarded_ad = null
var _ad_loading: bool = false
var _pending_economy = null
var _pending_save = null
var _bonus_pending_economy = null
var _bonus_pending_save = null
var _bonus_pending_diamonds: int = 0

# Rewarded interstitial state
var _ri_ad = null
var _ri_loading: bool = false
var _ri_pending_economy = null
var _ri_pending_save = null
var _ri_pending_diamonds: int = 0
var _ri_rewarded: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if not _is_mobile():
		return
	# Initialize AdMob via dynamic call
	var mobile_ads_class = _get_class("MobileAds")
	if mobile_ads_class != null and mobile_ads_class.has_method("initialize"):
		mobile_ads_class.initialize()
	_load_rewarded_ad()
	_load_ri_ad()

func _is_mobile() -> bool:
	return OS.get_name() in ["Android", "iOS"]

func _get_ad_unit_id() -> String:
	if OS.is_debug_build():
		return AD_UNIT_ID_TEST
	return AD_UNIT_ID_ANDROID

func _get_ri_ad_unit_id() -> String:
	if OS.is_debug_build():
		return DC_AD_UNIT_ID_TEST
	return DC_AD_UNIT_ID_ANDROID

## Safely get a GDScript class by name from the global scope.
## Returns null if the class doesn't exist (e.g., plugin not loaded).
func _get_class(class_name_str: String):
	var script = ResourceLoader.load("res://addons/admob/src/api/%s.gd" % class_name_str, "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	if script != null:
		return script
	return null

func _new_instance(class_name_str: String):
	var script = _get_class(class_name_str)
	if script != null:
		return script.new()
	return null

func _new_instance_from(path: String):
	var script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	if script != null:
		return script.new()
	return null

# ---------------------------------------------------------------------------
# Ad loading
# ---------------------------------------------------------------------------

func _load_rewarded_ad() -> void:
	if _ad_loading or not _is_mobile():
		return

	var loader = _new_instance("RewardedAdLoader")
	if loader == null:
		return

	_ad_loading = true
	var callback = _new_instance_from("res://addons/admob/src/api/listeners/RewardedAdLoadCallback.gd")
	if callback == null:
		_ad_loading = false
		return
	callback.on_ad_loaded = _on_rewarded_ad_loaded
	callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load

	var ad_request = _new_instance_from("res://addons/admob/src/api/core/AdRequest.gd")
	if ad_request == null:
		_ad_loading = false
		return
	loader.load(_get_ad_unit_id(), ad_request, callback)

func _on_rewarded_ad_loaded(ad) -> void:
	_rewarded_ad = ad
	_ad_loading = false
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed

func _on_rewarded_ad_failed_to_load(_error) -> void:
	_rewarded_ad = null
	_ad_loading = false
	if is_inside_tree():
		get_tree().create_timer(10.0).timeout.connect(_load_rewarded_ad)

func _on_ad_dismissed() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	_load_rewarded_ad()

# ---------------------------------------------------------------------------
# Rewarded Interstitial loading
# ---------------------------------------------------------------------------

func _load_ri_ad() -> void:
	if _ri_loading or not _is_mobile():
		return

	var loader = _new_instance("RewardedInterstitialAdLoader")
	if loader == null:
		return

	_ri_loading = true
	var callback = _new_instance_from("res://addons/admob/src/api/listeners/RewardedInterstitialAdLoadCallback.gd")
	if callback == null:
		_ri_loading = false
		return
	callback.on_ad_loaded = _on_ri_ad_loaded
	callback.on_ad_failed_to_load = _on_ri_ad_failed_to_load

	var ad_request = _new_instance_from("res://addons/admob/src/api/core/AdRequest.gd")
	if ad_request == null:
		_ri_loading = false
		return
	loader.load(_get_ri_ad_unit_id(), ad_request, callback)

func _on_ri_ad_loaded(ad) -> void:
	_ri_ad = ad
	_ri_loading = false
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_ri_ad_dismissed

func _on_ri_ad_failed_to_load(_error) -> void:
	_ri_ad = null
	_ri_loading = false
	if is_inside_tree():
		get_tree().create_timer(15.0).timeout.connect(_load_ri_ad)

func _on_ri_ad_dismissed() -> void:
	if _ri_rewarded and _ri_pending_economy != null and _ri_pending_save != null:
		_ri_pending_economy.add_diamonds(_ri_pending_diamonds)
		_ri_pending_save.sync_economy(_ri_pending_economy)
		_ri_pending_save.save_game()
		rewarded_interstitial_reward_granted.emit(_ri_pending_diamonds)
	else:
		rewarded_interstitial_dismissed.emit()
	_ri_rewarded = false
	_ri_pending_economy = null
	_ri_pending_save = null
	_ri_pending_diamonds = 0
	if _ri_ad != null:
		_ri_ad.destroy()
		_ri_ad = null
	_load_ri_ad()

func _on_ri_user_earned_reward(_rewarded_item) -> void:
	_ri_rewarded = true

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func can_watch_ad(save) -> bool:
	if save == null:
		return false
	if has_no_ads(save):
		return true
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return watched < Constants.MAX_ADS_PER_DAY

func get_remaining_ads(save) -> int:
	if save == null:
		return 0
	if has_no_ads(save):
		return Constants.MAX_ADS_PER_DAY
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return max(0, Constants.MAX_ADS_PER_DAY - watched)

func has_no_ads(save) -> bool:
	if save == null:
		return false
	return save.data["monetization"].get("no_ads_purchased", false) as bool

## Shows a rewarded interstitial ad. Grants bonus_diamonds on watch.
## Emits rewarded_interstitial_reward_granted on success, rewarded_interstitial_dismissed otherwise.
func show_rewarded_interstitial(economy, save, bonus_diamonds: int) -> void:
	# No-ads users get the bonus instantly without watching
	if has_no_ads(save):
		if economy != null:
			economy.add_diamonds(bonus_diamonds)
		if save != null and economy != null:
			save.sync_economy(economy)
			save.save_game()
		rewarded_interstitial_reward_granted.emit(bonus_diamonds)
		return

	if _is_mobile() and _ri_ad != null:
		_ri_pending_economy = economy
		_ri_pending_save = save
		_ri_pending_diamonds = bonus_diamonds
		_ri_rewarded = false
		var reward_listener = _new_instance_from("res://addons/admob/src/api/listeners/OnUserEarnedRewardListener.gd")
		if reward_listener != null:
			reward_listener.on_user_earned_reward = _on_ri_user_earned_reward
			_ri_ad.show(reward_listener)
			return

	# Desktop/editor simulation: grant reward directly
	if economy != null:
		economy.add_diamonds(bonus_diamonds)
	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()
	rewarded_interstitial_reward_granted.emit(bonus_diamonds)

## Shows a rewarded ad for a custom bonus (e.g. x2 diamonds on level complete).
## Does NOT count toward the daily ad limit.
## Emits bonus_ad_reward_granted on success, bonus_ad_failed on failure.
func show_bonus_ad(economy, save, bonus_diamonds: int) -> void:
	# No-ads users get the bonus instantly without watching
	if has_no_ads(save):
		_grant_bonus(economy, save, bonus_diamonds)
		return

	if _is_mobile() and _rewarded_ad != null:
		_bonus_pending_economy = economy
		_bonus_pending_save = save
		_bonus_pending_diamonds = bonus_diamonds
		var reward_listener = _new_instance_from("res://addons/admob/src/api/listeners/OnUserEarnedRewardListener.gd")
		if reward_listener != null:
			reward_listener.on_user_earned_reward = _on_bonus_ad_earned
			_rewarded_ad.show(reward_listener)
			return

	# Desktop/editor simulation: grant reward directly
	_grant_bonus(economy, save, bonus_diamonds)

func _on_bonus_ad_earned(_rewarded_item) -> void:
	if _bonus_pending_economy != null and _bonus_pending_save != null:
		_grant_bonus(_bonus_pending_economy, _bonus_pending_save, _bonus_pending_diamonds)
	_bonus_pending_economy = null
	_bonus_pending_save = null
	_bonus_pending_diamonds = 0

func _grant_bonus(economy, save, bonus: int) -> void:
	if economy != null:
		economy.add_diamonds(bonus)
	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()
	bonus_ad_reward_granted.emit(bonus)

func request_ad(economy, save) -> void:
	# No-ads users get the reward instantly without watching
	if has_no_ads(save):
		_grant_reward(economy, save)
		return

	if not can_watch_ad(save):
		ad_failed.emit()
		return

	if _is_mobile() and _rewarded_ad != null:
		_pending_economy = economy
		_pending_save = save
		var reward_listener = _new_instance_from("res://addons/admob/src/api/listeners/OnUserEarnedRewardListener.gd")
		if reward_listener != null:
			reward_listener.on_user_earned_reward = _on_user_earned_reward
			_rewarded_ad.show(reward_listener)
			return

	# Simulation fallback
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

func _grant_reward(economy, save) -> void:
	if not has_no_ads(save):
		save.data["monetization"]["ads_watched_today"] += 1
	var reward: int = Constants.DIAMONDS_PER_AD
	if economy != null:
		economy.add_diamonds(reward)
	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()
	ad_reward_granted.emit(reward)

func _check_date_reset(save) -> void:
	if save == null:
		return
	var today: String = Time.get_date_string_from_system()
	var last_reset: String = save.data["monetization"].get("ads_last_reset_date", "") as String
	if today != last_reset:
		save.data["monetization"]["ads_watched_today"] = 0
		save.data["monetization"]["ads_last_reset_date"] = today
