extends Node

## Manages rewarded-ad viewing with a per-day cap.
## Uses Poing-Studios godot-admob-plugin v4.1.0 on Android/iOS.
## All calls are gated by `_available` — desktop/editor falls back to
## instant simulation. Pattern mirrors 2048plus/scripts/ads/AdMobManager.gd.

# ---------------------------------------------------------------------------
# Ad Unit IDs
# ---------------------------------------------------------------------------

const AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/4258670828"
const DC_AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/5883745702"
const BANNER_AD_UNIT_ID_ANDROID: String = "ca-app-pub-3637456949556000/4533230854"
const BANNER_RESERVED_HEIGHT_DEFAULT: float = 180.0

# Actual banner pixel height — starts at a conservative default (covers ~3x
# density devices for a 50dp banner), then updates to the real value after
# the native plugin reports it via AdView.get_height_in_pixels().
var _banner_reserve: float = BANNER_RESERVED_HEIGHT_DEFAULT

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ad_reward_granted(diamonds: int)
signal ad_failed
signal rewarded_interstitial_reward_granted(diamonds: int)
signal rewarded_interstitial_dismissed
signal bonus_ad_reward_granted(diamonds: int)
signal bonus_ad_failed
signal banner_reserve_changed(pixels: float)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _available: bool = false

var _rewarded_ad: RewardedAd = null
var _ad_loading: bool = false
var _pending_economy = null
var _pending_save = null
var _bonus_pending_economy = null
var _bonus_pending_save = null
var _bonus_pending_diamonds: int = 0
var _bonus_mode: bool = false

# Rewarded interstitial state
var _ri_ad: RewardedInterstitialAd = null
var _ri_loading: bool = false
var _ri_pending_economy = null
var _ri_pending_save = null
var _ri_pending_diamonds: int = 0
var _ri_rewarded: bool = false

# Banner ad state
var _banner_ad: AdView = null
var _banner_loading: bool = false
var _banner_shown: bool = false

# Shared listener/callback objects — created up front; harmless no-ops on desktop
var _rewarded_load_callback: RewardedAdLoadCallback = null
var _rewarded_content_callback: FullScreenContentCallback = null
var _reward_listener: OnUserEarnedRewardListener = null
var _ri_load_callback: RewardedInterstitialAdLoadCallback = null
var _ri_content_callback: FullScreenContentCallback = null
var _ri_reward_listener: OnUserEarnedRewardListener = null
var _banner_listener: AdListener = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	IAPManager.no_ads_purchased.connect(_on_no_ads_purchased)

	_available = Engine.has_singleton("PoingGodotAdMob")
	if not _available:
		return

	_setup_callbacks()
	MobileAds.initialize()
	_load_rewarded_ad()
	_load_ri_ad()

func _setup_callbacks() -> void:
	_rewarded_load_callback = RewardedAdLoadCallback.new()
	_rewarded_load_callback.on_ad_loaded = _on_rewarded_ad_loaded
	_rewarded_load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load

	_rewarded_content_callback = FullScreenContentCallback.new()
	_rewarded_content_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed

	_reward_listener = OnUserEarnedRewardListener.new()
	_reward_listener.on_user_earned_reward = _on_user_earned_reward

	_ri_load_callback = RewardedInterstitialAdLoadCallback.new()
	_ri_load_callback.on_ad_loaded = _on_ri_ad_loaded
	_ri_load_callback.on_ad_failed_to_load = _on_ri_ad_failed_to_load

	_ri_content_callback = FullScreenContentCallback.new()
	_ri_content_callback.on_ad_dismissed_full_screen_content = _on_ri_ad_dismissed

	_ri_reward_listener = OnUserEarnedRewardListener.new()
	_ri_reward_listener.on_user_earned_reward = _on_ri_user_earned_reward

	_banner_listener = AdListener.new()
	_banner_listener.on_ad_loaded = _on_banner_ad_loaded
	_banner_listener.on_ad_failed_to_load = _on_banner_ad_failed_to_load

# ---------------------------------------------------------------------------
# Ad loading
# ---------------------------------------------------------------------------

func _load_rewarded_ad() -> void:
	if _ad_loading or not _available:
		return
	_ad_loading = true
	RewardedAdLoader.new().load(AD_UNIT_ID_ANDROID, AdRequest.new(), _rewarded_load_callback)

func _on_rewarded_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad
	_ad_loading = false
	_rewarded_ad.full_screen_content_callback = _rewarded_content_callback

func _on_rewarded_ad_failed_to_load(_error) -> void:
	_rewarded_ad = null
	_ad_loading = false
	if is_inside_tree():
		get_tree().create_timer(10.0).timeout.connect(_load_rewarded_ad)

func _on_ad_dismissed() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	_bonus_mode = false
	_load_rewarded_ad()

# ---------------------------------------------------------------------------
# Rewarded Interstitial loading
# ---------------------------------------------------------------------------

func _load_ri_ad() -> void:
	if _ri_loading or not _available:
		return
	_ri_loading = true
	RewardedInterstitialAdLoader.new().load(DC_AD_UNIT_ID_ANDROID, AdRequest.new(), _ri_load_callback)

func _on_ri_ad_loaded(ad: RewardedInterstitialAd) -> void:
	_ri_ad = ad
	_ri_loading = false
	_ri_ad.full_screen_content_callback = _ri_content_callback

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

	if _available and _ri_ad != null:
		_ri_pending_economy = economy
		_ri_pending_save = save
		_ri_pending_diamonds = bonus_diamonds
		_ri_rewarded = false
		_ri_ad.show(_ri_reward_listener)
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

	if _available:
		if _rewarded_ad != null:
			_bonus_pending_economy = economy
			_bonus_pending_save = save
			_bonus_pending_diamonds = bonus_diamonds
			_bonus_mode = true
			_rewarded_ad.show(_reward_listener)
			return
		bonus_ad_failed.emit()
		return

	# Desktop/editor simulation: grant reward directly
	_grant_bonus(economy, save, bonus_diamonds)

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

	if _available and _rewarded_ad != null:
		_pending_economy = economy
		_pending_save = save
		_bonus_mode = false
		_rewarded_ad.show(_reward_listener)
		return

	# Simulation fallback
	_grant_reward(economy, save)

# ---------------------------------------------------------------------------
# Reward callback
# ---------------------------------------------------------------------------

func _on_user_earned_reward(_rewarded_item) -> void:
	if _bonus_mode:
		if _bonus_pending_economy != null and _bonus_pending_save != null:
			_grant_bonus(_bonus_pending_economy, _bonus_pending_save, _bonus_pending_diamonds)
		_bonus_pending_economy = null
		_bonus_pending_save = null
		_bonus_pending_diamonds = 0
	else:
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
		save.save_game()

# ---------------------------------------------------------------------------
# Banner ads
# ---------------------------------------------------------------------------

func show_banner(save) -> void:
	if has_no_ads(save):
		return
	if not _available:
		return
	_banner_shown = true
	if _banner_ad == null and not _banner_loading:
		_load_banner()
		return
	if _banner_ad != null:
		_banner_ad.show()

func hide_banner() -> void:
	_banner_shown = false
	if _banner_ad != null:
		_banner_ad.hide()

func destroy_banner() -> void:
	_banner_shown = false
	_banner_loading = false
	if _banner_ad != null:
		_banner_ad.destroy()
		_banner_ad = null

func get_banner_reserve(save) -> float:
	if not _available:
		return 0.0
	if has_no_ads(save):
		return 0.0
	return _banner_reserve

func apply_banner_reserve(control: Control, save) -> void:
	if control == null:
		return
	control.offset_bottom = -get_banner_reserve(save)

## Anchors a ColorRect/Panel so it paints the full screen including the area
## reserved for the banner. The background stays at PRESET_FULL_RECT relative
## to its (shrunken) parent, but extends downward by `reserve` pixels to cover
## the banner strip. Called once after adding the bg; re-applied on
## banner_reserve_changed for dynamic resize.
func extend_bg_over_banner(bg: Control, save) -> void:
	if bg == null:
		return
	bg.offset_bottom = get_banner_reserve(save)

func _load_banner() -> void:
	if _banner_loading or not _available:
		return
	_banner_loading = true
	_banner_ad = AdView.new(BANNER_AD_UNIT_ID_ANDROID, AdSize.BANNER, AdPosition.Values.BOTTOM)
	_banner_ad.ad_listener = _banner_listener
	_banner_ad.load_ad(AdRequest.new())

func _on_banner_ad_loaded() -> void:
	_banner_loading = false
	if _banner_ad != null:
		var px: int = _banner_ad.get_height_in_pixels()
		if px > 0:
			var new_reserve: float = float(px)
			if not is_equal_approx(new_reserve, _banner_reserve):
				_banner_reserve = new_reserve
				banner_reserve_changed.emit(_banner_reserve)
	if _banner_shown and _banner_ad != null:
		_banner_ad.show()

func _on_banner_ad_failed_to_load(_error) -> void:
	_banner_ad = null
	_banner_loading = false
	if is_inside_tree():
		get_tree().create_timer(30.0).timeout.connect(_maybe_retry_banner)

func _maybe_retry_banner() -> void:
	if _banner_shown and _banner_ad == null and not _banner_loading:
		_load_banner()

func _on_no_ads_purchased() -> void:
	destroy_banner()
