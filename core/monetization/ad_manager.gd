class_name AdManager
extends Node

## Manages rewarded-ad viewing with a per-day cap.
## Uses Constants.MAX_ADS_PER_DAY and Constants.DIAMONDS_PER_AD.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal ad_reward_granted(diamonds: int)
signal ad_failed

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if the player can still watch an ad today.
func can_watch_ad(save) -> bool:
	if save == null:
		return false
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return watched < Constants.MAX_ADS_PER_DAY

## Returns the number of ads remaining today.
func get_remaining_ads(save) -> int:
	if save == null:
		return 0
	_check_date_reset(save)
	var watched: int = save.data["monetization"].get("ads_watched_today", 0) as int
	return max(0, Constants.MAX_ADS_PER_DAY - watched)

## Attempt to watch a rewarded ad.
## Grants DIAMONDS_PER_AD diamonds if within the daily limit.
## Emits ad_reward_granted on success or ad_failed if limit reached.
func request_ad(economy, save) -> void:
	if not can_watch_ad(save):
		ad_failed.emit()
		return

	# Increment watch count
	save.data["monetization"]["ads_watched_today"] += 1

	# Grant diamonds
	var reward: int = Constants.DIAMONDS_PER_AD
	if economy != null:
		economy.add_diamonds(reward)

	if save != null and economy != null:
		save.sync_economy(economy)
		save.save_game()

	ad_reward_granted.emit(reward)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Resets the daily ad counter if the calendar date has changed since last reset.
func _check_date_reset(save) -> void:
	if save == null:
		return

	var today: String = Time.get_date_string_from_system()
	var last_reset: String = save.data["monetization"].get("ads_last_reset_date", "") as String

	if today != last_reset:
		save.data["monetization"]["ads_watched_today"] = 0
		save.data["monetization"]["ads_last_reset_date"] = today
