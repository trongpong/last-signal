extends GutTest

## Tests for core/progression/tower_mastery_manager.gd

var _tmm: TowerMasteryManager
var _sm

func before_each() -> void:
	_sm = load("res://core/save/save_manager.gd").new()
	_sm.save_path = "user://test_mastery_temp.json"
	add_child(_sm)
	_tmm = TowerMasteryManager.new()
	add_child(_tmm)
	_tmm.setup(_sm)

func after_each() -> void:
	if FileAccess.file_exists(_sm.save_path):
		DirAccess.remove_absolute(_sm.save_path)
	_tmm.queue_free()
	_sm.queue_free()

# ---------------------------------------------------------------------------
# Record kills
# ---------------------------------------------------------------------------

func test_record_kill_increments() -> void:
	_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	assert_eq(_tmm.get_lifetime_kills(Enums.TowerType.PULSE_CANNON), 2)

func test_record_damage_accumulates() -> void:
	_tmm.record_damage(Enums.TowerType.ARC_EMITTER, 50.0)
	_tmm.record_damage(Enums.TowerType.ARC_EMITTER, 30.0)
	assert_almost_eq(_tmm.get_lifetime_damage(Enums.TowerType.ARC_EMITTER), 80.0, 0.01)

func test_different_tower_types_independent() -> void:
	_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	_tmm.record_kill(Enums.TowerType.CRYO_ARRAY)
	assert_eq(_tmm.get_lifetime_kills(Enums.TowerType.PULSE_CANNON), 1)
	assert_eq(_tmm.get_lifetime_kills(Enums.TowerType.CRYO_ARRAY), 1)

# ---------------------------------------------------------------------------
# Mastery tiers
# ---------------------------------------------------------------------------

func test_tier_minus_one_at_zero_kills() -> void:
	assert_eq(_tmm.get_mastery_tier(Enums.TowerType.PULSE_CANNON), -1)

func test_tier_bronze_at_500_kills() -> void:
	for i in range(500):
		_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	assert_eq(_tmm.get_mastery_tier(Enums.TowerType.PULSE_CANNON), 0)

func test_tier_silver_at_2000_kills() -> void:
	for i in range(2000):
		_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	assert_eq(_tmm.get_mastery_tier(Enums.TowerType.PULSE_CANNON), 1)

# ---------------------------------------------------------------------------
# Bonuses
# ---------------------------------------------------------------------------

func test_no_bonus_below_bronze() -> void:
	var bonuses: Dictionary = _tmm.get_mastery_bonuses(Enums.TowerType.PULSE_CANNON)
	assert_almost_eq(bonuses["damage_bonus"] as float, 0.0, 0.001)

func test_silver_bonus_is_3_percent() -> void:
	for i in range(2000):
		_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	var bonuses: Dictionary = _tmm.get_mastery_bonuses(Enums.TowerType.PULSE_CANNON)
	# Bronze (0%) + Silver (3%) = 3%
	assert_almost_eq(bonuses["damage_bonus"] as float, 0.03, 0.001)

func test_gold_bonus_is_6_percent() -> void:
	for i in range(8000):
		_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	var bonuses: Dictionary = _tmm.get_mastery_bonuses(Enums.TowerType.PULSE_CANNON)
	# Bronze (0%) + Silver (3%) + Gold (3%) = 6%
	assert_almost_eq(bonuses["damage_bonus"] as float, 0.06, 0.001)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_commit_match_stats_persists() -> void:
	for i in range(100):
		_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	_tmm.commit_match_stats()
	# Create a new manager and verify it loads
	var tmm2 := TowerMasteryManager.new()
	add_child(tmm2)
	tmm2.setup(_sm)
	assert_eq(tmm2.get_lifetime_kills(Enums.TowerType.PULSE_CANNON), 100)
	tmm2.queue_free()

func test_commit_clears_match_stats() -> void:
	_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	_tmm.commit_match_stats()
	# Match stats should be reset, but lifetime should persist
	_tmm.record_kill(Enums.TowerType.PULSE_CANNON)
	assert_eq(_tmm.get_lifetime_kills(Enums.TowerType.PULSE_CANNON), 2)
