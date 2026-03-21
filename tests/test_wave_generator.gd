extends GutTest

## Tests for core/wave_system/wave_generator.gd

var gen: WaveGenerator

func before_each() -> void:
	gen = WaveGenerator.new()

func after_each() -> void:
	gen = null


# ---------------------------------------------------------------------------
# _get_available_enemies
# ---------------------------------------------------------------------------

func test_available_enemies_wave_1_includes_starter_types() -> void:
	var avail: Array = gen._get_available_enemies(1)
	assert_true(avail.has("scout_basic"))
	assert_true(avail.has("drone_basic"))

func test_available_enemies_wave_1_excludes_late_types() -> void:
	var avail: Array = gen._get_available_enemies(1)
	assert_false(avail.has("shielder_elite"))

func test_available_enemies_wave_25_includes_all() -> void:
	var avail: Array = gen._get_available_enemies(25)
	assert_eq(avail.size(), WaveGenerator.ENEMY_POOL.size())

func test_available_enemies_grows_with_wave_number() -> void:
	var avail_1: Array = gen._get_available_enemies(1)
	var avail_10: Array = gen._get_available_enemies(10)
	assert_gt(avail_10.size(), avail_1.size())

func test_available_enemies_wave_5_includes_tank() -> void:
	var avail: Array = gen._get_available_enemies(5)
	assert_true(avail.has("tank_heavy"))

func test_available_enemies_wave_4_excludes_tank() -> void:
	var avail: Array = gen._get_available_enemies(4)
	assert_false(avail.has("tank_heavy"))

# ---------------------------------------------------------------------------
# _is_boss_wave
# ---------------------------------------------------------------------------

func test_is_boss_wave_false_wave_1() -> void:
	assert_false(gen._is_boss_wave(1))

func test_is_boss_wave_true_wave_10() -> void:
	assert_true(gen._is_boss_wave(10))

func test_is_boss_wave_true_wave_20() -> void:
	assert_true(gen._is_boss_wave(20))

func test_is_boss_wave_false_wave_11() -> void:
	assert_false(gen._is_boss_wave(11))

# ---------------------------------------------------------------------------
# generate_wave — structure
# ---------------------------------------------------------------------------

func test_generate_wave_returns_wave_definition() -> void:
	var wd: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	assert_not_null(wd)
	assert_true(wd is WaveDefinition)

func test_generate_wave_sets_wave_number() -> void:
	var wd: WaveDefinition = gen.generate_wave(7, Enums.Difficulty.NORMAL)
	assert_eq(wd.wave_number, 7)

func test_generate_wave_not_boss_on_odd_waves() -> void:
	var wd: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.NORMAL)
	assert_false(wd.is_boss_wave)

func test_generate_wave_boss_on_wave_10() -> void:
	var wd: WaveDefinition = gen.generate_wave(10, Enums.Difficulty.NORMAL)
	assert_true(wd.is_boss_wave)

func test_generate_wave_has_sub_waves() -> void:
	var wd: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	assert_gt(wd.sub_waves.size(), 0)

func test_generate_wave_sub_waves_are_sub_wave_definition() -> void:
	var wd: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	for sw in wd.sub_waves:
		assert_true(sw is SubWaveDefinition)

# ---------------------------------------------------------------------------
# generate_wave — enemy counts scale with wave number
# ---------------------------------------------------------------------------

func test_enemy_count_increases_with_wave_number() -> void:
	var wd1: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	var wd5: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.NORMAL)
	assert_gt(wd5.get_total_enemy_count(), wd1.get_total_enemy_count())

func test_enemy_count_positive_wave_1() -> void:
	var wd: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	assert_gt(wd.get_total_enemy_count(), 0)

# ---------------------------------------------------------------------------
# generate_wave — difficulty scaling
# ---------------------------------------------------------------------------

func test_nightmare_has_more_enemies_than_normal() -> void:
	var normal_wd: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.NORMAL)
	var nightmare_wd: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.NIGHTMARE)
	assert_gt(nightmare_wd.get_total_enemy_count(), normal_wd.get_total_enemy_count())

func test_hard_has_more_enemies_than_normal() -> void:
	var normal_wd: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.NORMAL)
	var hard_wd: WaveDefinition = gen.generate_wave(5, Enums.Difficulty.HARD)
	assert_gt(hard_wd.get_total_enemy_count(), normal_wd.get_total_enemy_count())

# ---------------------------------------------------------------------------
# generate_wave — boss wave specifics
# ---------------------------------------------------------------------------

func test_boss_wave_has_more_enemies_than_normal_wave() -> void:
	var normal_wd: WaveDefinition = gen.generate_wave(9, Enums.Difficulty.NORMAL)
	var boss_wd: WaveDefinition = gen.generate_wave(10, Enums.Difficulty.NORMAL)
	assert_gt(boss_wd.get_total_enemy_count(), normal_wd.get_total_enemy_count())

func test_boss_wave_enemy_id_is_valid() -> void:
	var wd: WaveDefinition = gen.generate_wave(10, Enums.Difficulty.NORMAL)
	for sw: SubWaveDefinition in wd.sub_waves:
		assert_ne(sw.enemy_id, "", "Boss wave sub-wave enemy_id must not be empty")

# ---------------------------------------------------------------------------
# generate_wave — variety grows
# ---------------------------------------------------------------------------

func test_late_waves_have_multiple_enemy_types() -> void:
	# Wave 25 has all enemies unlocked; expect at least 2 sub-wave types
	var wd: WaveDefinition = gen.generate_wave(25, Enums.Difficulty.NORMAL)
	assert_gt(wd.sub_waves.size(), 1)

func test_wave_1_enemy_ids_are_from_pool() -> void:
	var wd: WaveDefinition = gen.generate_wave(1, Enums.Difficulty.NORMAL)
	for sw: SubWaveDefinition in wd.sub_waves:
		assert_true(
			WaveGenerator.ENEMY_POOL.has(sw.enemy_id),
			"enemy_id '%s' must be in ENEMY_POOL" % sw.enemy_id
		)

# ---------------------------------------------------------------------------
# generate_wave — spawn intervals are positive
# ---------------------------------------------------------------------------

func test_sub_wave_spawn_intervals_positive() -> void:
	for wave_num in [1, 5, 10, 20]:
		var wd: WaveDefinition = gen.generate_wave(wave_num, Enums.Difficulty.NORMAL)
		for sw: SubWaveDefinition in wd.sub_waves:
			assert_gt(sw.spawn_interval, 0.0,
				"Wave %d sub-wave interval must be positive" % wave_num)
