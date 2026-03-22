class_name WaveRewardManager
extends Node

## Manages the roguelite buff card system for endless mode.
## Every N waves, presents random buff choices that stack for the run.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal reward_choices_ready(choices: Array)
signal reward_picked(reward: Dictionary)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _pool: Array = []
var _picked: Array = []
var _current_choices: Array = []

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup() -> void:
	_build_pool()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func should_offer_reward(wave_number: int) -> bool:
	return wave_number > 0 and wave_number % Constants.WAVE_REWARD_INTERVAL == 0

func generate_choices() -> Array:
	var shuffled: Array = _pool.duplicate()
	shuffled.shuffle()
	_current_choices = shuffled.slice(0, Constants.WAVE_REWARD_CHOICE_COUNT)
	return _current_choices

func pick_reward(index: int) -> void:
	if index < 0 or index >= _current_choices.size():
		return
	var reward: Dictionary = _current_choices[index]
	_picked.append(reward)
	reward_picked.emit(reward)

func pick_random() -> void:
	if _current_choices.is_empty():
		return
	pick_reward(randi() % _current_choices.size())

func get_modifiers() -> Dictionary:
	var result: Dictionary = {}
	for reward in _picked:
		var mods: Dictionary = reward.get("modifiers", {})
		for key in mods:
			result[key] = result.get(key, 0.0) + (mods[key] as float)
	return result

func get_modifier_value(key: String, default: float = 0.0) -> float:
	var mods: Dictionary = get_modifiers()
	return mods.get(key, default) as float

func get_picked_rewards() -> Array:
	return _picked

func get_pool_size() -> int:
	return _pool.size()

# ---------------------------------------------------------------------------
# Pool construction
# ---------------------------------------------------------------------------

func _build_pool() -> void:
	_pool.clear()
	# Offensive
	_add("overcharged_capacitors", "Overcharged Capacitors", "All towers +10% damage",
		Enums.WaveRewardCategory.OFFENSIVE, Color(1.0, 0.4, 0.2), {"damage_mult": 0.10})
	_add("rapid_cycling", "Rapid Cycling", "All towers +8% fire rate",
		Enums.WaveRewardCategory.OFFENSIVE, Color(0.2, 0.8, 1.0), {"fire_rate_mult": 0.08})
	_add("extended_range", "Extended Range", "All towers +12% range",
		Enums.WaveRewardCategory.OFFENSIVE, Color(0.4, 1.0, 0.4), {"range_mult": 0.12})
	_add("armor_piercing", "Armor Piercing", "All damage ignores 15% of enemy armor",
		Enums.WaveRewardCategory.OFFENSIVE, Color(0.9, 0.9, 0.3), {"armor_pierce_pct": 0.15})
	_add("critical_strike", "Critical Strike", "5% chance for 3x damage on all attacks",
		Enums.WaveRewardCategory.OFFENSIVE, Color(1.0, 0.2, 0.2), {"crit_chance": 0.05})
	# Defensive
	_add("reinforced_nexus", "Reinforced Nexus", "+2 lives",
		Enums.WaveRewardCategory.DEFENSIVE, Color(0.3, 1.0, 0.3), {"lives_add": 2.0})
	_add("emergency_protocols", "Emergency Protocols", "When a life is lost, all enemies take 100 damage",
		Enums.WaveRewardCategory.DEFENSIVE, Color(1.0, 0.6, 0.0), {"emergency_damage": 100.0})
	_add("temporal_buffer", "Temporal Buffer", "Enemies move 5% slower",
		Enums.WaveRewardCategory.DEFENSIVE, Color(0.5, 0.5, 1.0), {"enemy_speed_mult": -0.05})
	# Economic
	_add("salvage_operations", "Salvage Operations", "+20% gold from kills",
		Enums.WaveRewardCategory.ECONOMIC, Color(1.0, 0.85, 0.0), {"gold_mult": 0.20})
	_add("budget_engineering", "Budget Engineering", "Tower costs -10%",
		Enums.WaveRewardCategory.ECONOMIC, Color(0.0, 0.9, 0.6), {"tower_cost_mult": -0.10})
	_add("efficient_refunds", "Efficient Refunds", "Sell value +15%",
		Enums.WaveRewardCategory.ECONOMIC, Color(0.8, 0.8, 0.2), {"sell_value_mult": 0.15})
	# Risky
	_add("glass_cannon", "Glass Cannon", "+25% damage, but -1 life",
		Enums.WaveRewardCategory.RISKY, Color(1.0, 0.1, 0.1), {"damage_mult": 0.25, "lives_add": -1.0})
	_add("speed_demons", "Speed Demons", "Enemies +15% speed, but +30% gold",
		Enums.WaveRewardCategory.RISKY, Color(1.0, 0.5, 0.0), {"enemy_speed_mult": 0.15, "gold_mult": 0.30})
	_add("minimalist", "Minimalist", "Only 3 more towers, but +40% damage",
		Enums.WaveRewardCategory.RISKY, Color(0.8, 0.0, 0.8), {"damage_mult": 0.40, "tower_limit": 3.0})
	# Synergy/Specific
	_add("cryo_mastery", "Cryo Mastery", "Cryo slow +25%, duration +1s",
		Enums.WaveRewardCategory.SYNERGY_SPECIFIC, Color(0.5, 0.9, 1.0), {"cryo_slow_mult": 0.25, "cryo_duration_add": 1.0})
	_add("chain_reaction", "Chain Reaction", "Arc chain count +2",
		Enums.WaveRewardCategory.SYNERGY_SPECIFIC, Color(0.3, 0.6, 1.0), {"chain_count_add": 2.0})
	_add("carpet_protocol", "Carpet Protocol", "Missile splash radius +30%",
		Enums.WaveRewardCategory.SYNERGY_SPECIFIC, Color(1.0, 0.3, 0.0), {"splash_radius_mult": 0.30})
	_add("signal_leech", "Signal Leech", "Adaptation resistance decays 2x faster",
		Enums.WaveRewardCategory.SYNERGY_SPECIFIC, Color(0.0, 1.0, 0.5), {"adaptation_decay_mult": 1.0})

func _add(id: String, dname: String, desc: String, cat: int, color: Color, mods: Dictionary) -> void:
	_pool.append({
		"id": id,
		"display_name": dname,
		"description": desc,
		"category": cat,
		"icon_color": color,
		"modifiers": mods,
	})
