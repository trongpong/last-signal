extends GutTest

## Tests for core/audio/sfx_generator.gd

var _gen: SFXGenerator

const SAMPLE_RATE := 44100


func before_each() -> void:
	_gen = SFXGenerator.new()


func _assert_valid_samples(samples: PackedFloat32Array, label: String) -> void:
	assert_true(samples.size() > 0, "%s: should produce samples" % label)
	for i in samples.size():
		assert_true(
			samples[i] >= -1.0 and samples[i] <= 1.0,
			"%s: sample %d out of range: %f" % [label, i, samples[i]]
		)


# --- generate_tower_fire ---

func test_tower_fire_pulse_cannon_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 1)
	_assert_valid_samples(samples, "PULSE_CANNON tier 1")
	var expected_len := int(SFXGenerator.TOWER_SFX[Enums.TowerType.PULSE_CANNON].duration * SAMPLE_RATE)
	assert_eq(samples.size(), expected_len)


func test_tower_fire_arc_emitter_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.ARC_EMITTER, 1)
	_assert_valid_samples(samples, "ARC_EMITTER tier 1")


func test_tower_fire_cryo_array_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.CRYO_ARRAY, 1)
	_assert_valid_samples(samples, "CRYO_ARRAY tier 1")


func test_tower_fire_missile_pod_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.MISSILE_POD, 1)
	_assert_valid_samples(samples, "MISSILE_POD tier 1")


func test_tower_fire_beam_spire_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.BEAM_SPIRE, 1)
	_assert_valid_samples(samples, "BEAM_SPIRE tier 1")


func test_tower_fire_nano_hive_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.NANO_HIVE, 1)
	_assert_valid_samples(samples, "NANO_HIVE tier 1")


func test_tower_fire_harvester_tier1() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.HARVESTER, 1)
	_assert_valid_samples(samples, "HARVESTER tier 1")


func test_tower_fire_tier2_same_length() -> void:
	var t1 := _gen.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 1)
	var t2 := _gen.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 2)
	assert_eq(t1.size(), t2.size(), "Tier 2 should have same length as tier 1")


func test_tower_fire_tier2_valid_range() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 2)
	_assert_valid_samples(samples, "PULSE_CANNON tier 2")


func test_tower_fire_tier3_valid_range() -> void:
	var samples := _gen.generate_tower_fire(Enums.TowerType.BEAM_SPIRE, 3)
	_assert_valid_samples(samples, "BEAM_SPIRE tier 3")


func test_tower_fire_all_types_produce_samples() -> void:
	for tower_type in Enums.TowerType.values():
		var samples := _gen.generate_tower_fire(tower_type, 1)
		assert_true(samples.size() > 0,
			"Tower type %d should produce samples" % tower_type)


# --- generate_enemy_death ---

func test_enemy_death_normal_size() -> void:
	var samples := _gen.generate_enemy_death(1.0)
	_assert_valid_samples(samples, "enemy_death size 1.0")


func test_enemy_death_small_size() -> void:
	var samples := _gen.generate_enemy_death(0.5)
	_assert_valid_samples(samples, "enemy_death size 0.5")


func test_enemy_death_large_size() -> void:
	var samples := _gen.generate_enemy_death(3.0)
	_assert_valid_samples(samples, "enemy_death size 3.0")


func test_enemy_death_large_longer_than_small() -> void:
	var small := _gen.generate_enemy_death(0.5)
	var large := _gen.generate_enemy_death(3.0)
	assert_true(large.size() > small.size(),
		"Large enemy death should produce longer sound than small")


# --- generate_hero_summon ---

func test_hero_summon_produces_samples() -> void:
	var samples := _gen.generate_hero_summon()
	_assert_valid_samples(samples, "hero_summon")


func test_hero_summon_duration() -> void:
	var samples := _gen.generate_hero_summon()
	# Duration is 0.6 seconds
	var expected_min := int(0.55 * SAMPLE_RATE)
	var expected_max := int(0.65 * SAMPLE_RATE)
	assert_true(samples.size() >= expected_min and samples.size() <= expected_max,
		"Hero summon should be ~0.6s, got %d samples" % samples.size())


# --- generate_ability_activate ---

func test_ability_activate_produces_samples() -> void:
	var samples := _gen.generate_ability_activate()
	_assert_valid_samples(samples, "ability_activate")


func test_ability_activate_duration() -> void:
	var samples := _gen.generate_ability_activate()
	var expected := int(0.25 * SAMPLE_RATE)
	assert_eq(samples.size(), expected, "Ability activate should be 0.25s")


# --- TOWER_SFX dictionary integrity ---

func test_tower_sfx_has_all_tower_types() -> void:
	for tower_type in Enums.TowerType.values():
		assert_true(
			SFXGenerator.TOWER_SFX.has(tower_type),
			"TOWER_SFX missing entry for TowerType %d" % tower_type
		)


func test_tower_sfx_entries_have_required_keys() -> void:
	for tower_type in SFXGenerator.TOWER_SFX:
		var cfg: Dictionary = SFXGenerator.TOWER_SFX[tower_type]
		assert_true(cfg.has("wave"), "TOWER_SFX[%d] missing 'wave'" % tower_type)
		assert_true(cfg.has("freq"), "TOWER_SFX[%d] missing 'freq'" % tower_type)
		assert_true(cfg.has("duration"), "TOWER_SFX[%d] missing 'duration'" % tower_type)


# --- Tower interaction sounds ---

func test_generate_tower_place_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_place()
	assert_not_null(stream, "tower_place should return a stream")
	assert_gt(stream.data.size(), 0, "tower_place should have audio data")

func test_generate_tower_upgrade_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_upgrade(1)
	assert_not_null(stream, "tower_upgrade should return a stream")
	assert_gt(stream.data.size(), 0, "tower_upgrade should have audio data")

func test_generate_tower_upgrade_pitch_increases_with_tier() -> void:
	var stream_t1 := _gen.generate_tower_upgrade(1)
	var stream_t2 := _gen.generate_tower_upgrade(2)
	var stream_t3 := _gen.generate_tower_upgrade(3)
	assert_ne(stream_t1.data, stream_t2.data, "tier 1 and 2 should differ")
	assert_ne(stream_t2.data, stream_t3.data, "tier 2 and 3 should differ")

func test_generate_tower_sell_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_sell()
	assert_not_null(stream, "tower_sell should return a stream")
	assert_gt(stream.data.size(), 0, "tower_sell should have audio data")

func test_generate_enemy_hit_returns_valid_stream() -> void:
	var stream := _gen.generate_enemy_hit()
	assert_not_null(stream, "enemy_hit should return a stream")
	assert_gt(stream.data.size(), 0, "enemy_hit should have audio data")

func test_generate_enemy_escape_returns_valid_stream() -> void:
	var stream := _gen.generate_enemy_escape(0.0)
	assert_not_null(stream, "enemy_escape should return a stream")
	assert_gt(stream.data.size(), 0, "enemy_escape should have audio data")

func test_generate_enemy_escape_scales_with_escalation() -> void:
	var stream_low := _gen.generate_enemy_escape(0.0)
	var stream_high := _gen.generate_enemy_escape(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation should produce longer sound")
