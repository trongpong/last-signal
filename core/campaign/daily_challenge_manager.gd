class_name DailyChallengeManager
extends Node

## Generates a deterministic daily challenge from the date.
## Tracks completion, streak, and rewards via SaveManager.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal challenge_completed(diamonds: int, stars: int)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const BASE_REWARD: int = 50
const THREE_STAR_REWARD: int = 100
const STREAK_BONUS_PER_DAY: int = 10
const STREAK_BONUS_CAP: int = 70
const CHALLENGE_WAVE_COUNT: int = 20

## Day-of-week to challenge type mapping (0=Sunday, 1=Monday, ..., 6=Saturday)
const DAY_TO_TYPE: Dictionary = {
	0: Enums.DailyChallengeType.BOSS_RUSH,
	1: Enums.DailyChallengeType.RESTRICTED_TOWERS,
	2: Enums.DailyChallengeType.ECONOMY,
	3: Enums.DailyChallengeType.SURVIVAL,
	4: Enums.DailyChallengeType.SPEED,
	5: Enums.DailyChallengeType.PUZZLE,
	6: Enums.DailyChallengeType.CHAOS,
}

const TYPE_NAMES: Dictionary = {
	Enums.DailyChallengeType.RESTRICTED_TOWERS: "Restricted Towers",
	Enums.DailyChallengeType.ECONOMY: "Economy",
	Enums.DailyChallengeType.SURVIVAL: "Survival",
	Enums.DailyChallengeType.SPEED: "Speed",
	Enums.DailyChallengeType.PUZZLE: "Puzzle",
	Enums.DailyChallengeType.CHAOS: "Chaos",
	Enums.DailyChallengeType.BOSS_RUSH: "Boss Rush",
}

const TYPE_DESCRIPTIONS: Dictionary = {
	Enums.DailyChallengeType.RESTRICTED_TOWERS: "Only 2 tower types available. Enemies +30% speed.",
	Enums.DailyChallengeType.ECONOMY: "50% gold income. Survive 20 waves.",
	Enums.DailyChallengeType.SURVIVAL: "1 starting life. Tower costs -40%.",
	Enums.DailyChallengeType.SPEED: "No wave breaks. 2x gold income.",
	Enums.DailyChallengeType.PUZZLE: "Pre-placed towers. Upgrades only.",
	Enums.DailyChallengeType.CHAOS: "Double enemy paths. Good luck.",
	Enums.DailyChallengeType.BOSS_RUSH: "Bosses every 3 waves. 3x diamond reward.",
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _save_manager = null

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(save_manager) -> void:
	_save_manager = save_manager

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_today_challenge() -> Dictionary:
	var date: Dictionary = Time.get_date_dict_from_system()
	var today: String = _date_string(date)
	var day_of_week: int = date.get("weekday", 0) as int
	var challenge_type: int = DAY_TO_TYPE.get(day_of_week, Enums.DailyChallengeType.ECONOMY)
	var completed: bool = is_completed_today()
	return {
		"type": challenge_type,
		"type_name": TYPE_NAMES.get(challenge_type, "Challenge"),
		"description": TYPE_DESCRIPTIONS.get(challenge_type, ""),
		"date": today,
		"seed": hash(today),
		"completed": completed,
		"streak": get_current_streak(),
	}

func get_constraints() -> Dictionary:
	var date: Dictionary = Time.get_date_dict_from_system()
	var day_of_week: int = date.get("weekday", 0) as int
	var challenge_type: int = DAY_TO_TYPE.get(day_of_week, Enums.DailyChallengeType.ECONOMY)
	var today: String = _date_string(date)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	return _generate_constraints(challenge_type, rng)

func is_completed_today() -> bool:
	if _save_manager == null:
		return false
	var today: String = _date_string(Time.get_date_dict_from_system())
	var dc: Dictionary = _save_manager.data.get("daily_challenges", {})
	return dc.get("last_completed_date", "") == today

func get_current_streak() -> int:
	if _save_manager == null:
		return 0
	var dc: Dictionary = _save_manager.data.get("daily_challenges", {})
	var last_date: String = dc.get("last_completed_date", "") as String
	if last_date.is_empty():
		return 0
	var today: String = _date_string(Time.get_date_dict_from_system())
	if last_date == today:
		return dc.get("streak", 0) as int
	# Check if yesterday was last completed
	var yesterday: String = _get_yesterday_string()
	if last_date == yesterday:
		return dc.get("streak", 0) as int
	return 0

func mark_completed(stars: int) -> void:
	if _save_manager == null:
		return
	var today: String = _date_string(Time.get_date_dict_from_system())
	var dc: Dictionary = _save_manager.data.get("daily_challenges", {})
	var last_date: String = dc.get("last_completed_date", "") as String
	var yesterday: String = _get_yesterday_string()

	if last_date == yesterday:
		dc["streak"] = (dc.get("streak", 0) as int) + 1
	elif last_date != today:
		dc["streak"] = 1

	dc["last_completed_date"] = today
	var history: Dictionary = dc.get("history", {})
	history[today] = {"completed": true, "stars": stars}
	dc["history"] = history
	_save_manager.data["daily_challenges"] = dc
	_save_manager.save_game()

	var diamonds: int = get_reward_diamonds(stars)
	challenge_completed.emit(diamonds, stars)

func get_reward_diamonds(stars: int) -> int:
	var base: int = BASE_REWARD
	if stars >= 3:
		base = THREE_STAR_REWARD
	var streak_bonus: int = mini(get_current_streak() * STREAK_BONUS_PER_DAY, STREAK_BONUS_CAP)
	return base + streak_bonus

# ---------------------------------------------------------------------------
# Constraint Generation
# ---------------------------------------------------------------------------

func _generate_constraints(challenge_type: int, rng: RandomNumberGenerator) -> Dictionary:
	var constraints: Dictionary = {
		"type": challenge_type,
		"wave_count": CHALLENGE_WAVE_COUNT,
		"allowed_towers": [],
		"gold_multiplier": 1.0,
		"starting_lives": -1,
		"wave_break_duration": -1.0,
		"enemy_speed_mult": 1.0,
		"diamond_reward_mult": 1.0,
		"tower_cost_mult": 1.0,
	}
	match challenge_type:
		Enums.DailyChallengeType.RESTRICTED_TOWERS:
			var all_types: Array = [0, 1, 2, 3, 4, 5, 6]
			var t1: int = all_types[rng.randi() % all_types.size()]
			all_types.erase(t1)
			var t2: int = all_types[rng.randi() % all_types.size()]
			constraints["allowed_towers"] = [t1, t2]
			constraints["enemy_speed_mult"] = 1.3
		Enums.DailyChallengeType.ECONOMY:
			constraints["gold_multiplier"] = 0.5
		Enums.DailyChallengeType.SURVIVAL:
			constraints["starting_lives"] = 1
			constraints["tower_cost_mult"] = 0.6
		Enums.DailyChallengeType.SPEED:
			constraints["wave_break_duration"] = 0.0
			constraints["gold_multiplier"] = 2.0
		Enums.DailyChallengeType.PUZZLE:
			constraints["allowed_towers"] = []
			constraints["tower_cost_mult"] = 0.0
		Enums.DailyChallengeType.CHAOS:
			constraints["enemy_speed_mult"] = 1.1
		Enums.DailyChallengeType.BOSS_RUSH:
			constraints["diamond_reward_mult"] = 3.0
	return constraints

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _date_string(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [date.get("year", 2026), date.get("month", 1), date.get("day", 1)]

func _get_yesterday_string() -> String:
	var unix: int = int(Time.get_unix_time_from_system()) - 86400
	var date: Dictionary = Time.get_date_dict_from_unix_time(unix)
	return _date_string(date)
