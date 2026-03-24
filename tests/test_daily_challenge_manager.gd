extends GutTest

## Tests for core/campaign/daily_challenge_manager.gd

var _dcm: DailyChallengeManager
var _sm

func before_each() -> void:
	_sm = load("res://core/save/save_manager.gd").new()
	_sm.save_path = "user://test_daily_temp.json"
	add_child(_sm)
	_dcm = DailyChallengeManager.new()
	add_child(_dcm)
	_dcm.setup(_sm)

func after_each() -> void:
	if FileAccess.file_exists(_sm.save_path):
		DirAccess.remove_absolute(_sm.save_path)
	_dcm.queue_free()
	_sm.queue_free()

# ---------------------------------------------------------------------------
# Challenge generation
# ---------------------------------------------------------------------------

func test_get_today_challenge_returns_valid_type() -> void:
	var challenge: Dictionary = _dcm.get_today_challenge()
	assert_true(challenge.has("type"))
	assert_true(challenge.has("type_name"))
	assert_true(challenge.has("seed"))

func test_challenge_has_date() -> void:
	var challenge: Dictionary = _dcm.get_today_challenge()
	assert_true(challenge.has("date"))
	assert_false((challenge["date"] as String).is_empty())

func test_same_date_same_seed() -> void:
	var c1: Dictionary = _dcm.get_today_challenge()
	var c2: Dictionary = _dcm.get_today_challenge()
	assert_eq(c1["seed"], c2["seed"])

# ---------------------------------------------------------------------------
# Constraints
# ---------------------------------------------------------------------------

func test_constraints_have_wave_count() -> void:
	var constraints: Dictionary = _dcm.get_constraints()
	assert_eq(constraints.get("wave_count", 0), DailyChallengeManager.CHALLENGE_WAVE_COUNT)

func test_constraints_have_required_keys() -> void:
	var constraints: Dictionary = _dcm.get_constraints()
	assert_true(constraints.has("type"))
	assert_true(constraints.has("gold_multiplier"))
	assert_true(constraints.has("enemy_speed_mult"))

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

func test_not_completed_initially() -> void:
	assert_false(_dcm.is_completed_today())

func test_mark_completed_records() -> void:
	_dcm.mark_completed(3)
	assert_true(_dcm.is_completed_today())

func test_mark_completed_emits_signal() -> void:
	watch_signals(_dcm)
	_dcm.mark_completed(2)
	assert_signal_emitted(_dcm, "challenge_completed")

# ---------------------------------------------------------------------------
# Streak
# ---------------------------------------------------------------------------

func test_streak_starts_at_zero() -> void:
	assert_eq(_dcm.get_current_streak(), 0)

func test_streak_is_one_after_first_completion() -> void:
	_dcm.mark_completed(2)
	assert_eq(_dcm.get_current_streak(), 1)

# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------

func test_reward_base_50() -> void:
	assert_eq(_dcm.get_reward_diamonds(1), DailyChallengeManager.BASE_REWARD)

func test_reward_three_star_100() -> void:
	assert_eq(_dcm.get_reward_diamonds(3), DailyChallengeManager.BASE_REWARD + DailyChallengeManager.THREE_STAR_REWARD)

func test_reward_streak_bonus() -> void:
	# Simulate a streak by setting save data directly
	var dc: Dictionary = _sm.data.get("daily_challenges", {})
	dc["streak"] = 5
	var today: String = "%04d-%02d-%02d" % [
		Time.get_date_dict_from_system()["year"],
		Time.get_date_dict_from_system()["month"],
		Time.get_date_dict_from_system()["day"]
	]
	dc["last_completed_date"] = today
	_sm.data["daily_challenges"] = dc
	# 100 (3-star) + 5*10 (streak) = 150
	assert_eq(_dcm.get_reward_diamonds(3), 150)

func test_streak_bonus_caps_at_70() -> void:
	var dc: Dictionary = _sm.data.get("daily_challenges", {})
	dc["streak"] = 20  # way over cap
	var today: String = "%04d-%02d-%02d" % [
		Time.get_date_dict_from_system()["year"],
		Time.get_date_dict_from_system()["month"],
		Time.get_date_dict_from_system()["day"]
	]
	dc["last_completed_date"] = today
	_sm.data["daily_challenges"] = dc
	# 50 (base) + 70 (cap) = 120
	assert_eq(_dcm.get_reward_diamonds(1), 120)
