extends GutTest

## Tests for core/wave_system/wave_definition.gd and sub_wave_definition.gd

# ---------------------------------------------------------------------------
# SubWaveDefinition
# ---------------------------------------------------------------------------

func test_sub_wave_default_enemy_id() -> void:
	var sw := SubWaveDefinition.new()
	assert_eq(sw.enemy_id, "")

func test_sub_wave_default_count() -> void:
	var sw := SubWaveDefinition.new()
	assert_eq(sw.count, 1)

func test_sub_wave_default_spawn_interval() -> void:
	var sw := SubWaveDefinition.new()
	assert_almost_eq(sw.spawn_interval, Constants.DEFAULT_SPAWN_INTERVAL, 0.0001)

func test_sub_wave_default_delay() -> void:
	var sw := SubWaveDefinition.new()
	assert_almost_eq(sw.delay, 0.0, 0.0001)

func test_sub_wave_init_sets_values() -> void:
	var sw := SubWaveDefinition.new("drone_basic", 5, 0.3, 1.0)
	assert_eq(sw.enemy_id, "drone_basic")
	assert_eq(sw.count, 5)
	assert_almost_eq(sw.spawn_interval, 0.3, 0.0001)
	assert_almost_eq(sw.delay, 1.0, 0.0001)

# ---------------------------------------------------------------------------
# WaveDefinition
# ---------------------------------------------------------------------------

func test_wave_default_wave_number() -> void:
	var wd := WaveDefinition.new()
	assert_eq(wd.wave_number, 1)

func test_wave_default_sub_waves_empty() -> void:
	var wd := WaveDefinition.new()
	assert_eq(wd.sub_waves.size(), 0)

func test_wave_default_not_boss() -> void:
	var wd := WaveDefinition.new()
	assert_false(wd.is_boss_wave)

func test_get_total_enemy_count_empty() -> void:
	var wd := WaveDefinition.new()
	assert_eq(wd.get_total_enemy_count(), 0)

func test_get_total_enemy_count_single_sub_wave() -> void:
	var wd := WaveDefinition.new()
	wd.sub_waves.append(SubWaveDefinition.new("drone", 10))
	assert_eq(wd.get_total_enemy_count(), 10)

func test_get_total_enemy_count_multiple_sub_waves() -> void:
	var wd := WaveDefinition.new()
	wd.sub_waves.append(SubWaveDefinition.new("scout", 5))
	wd.sub_waves.append(SubWaveDefinition.new("tank", 3))
	wd.sub_waves.append(SubWaveDefinition.new("drone", 7))
	assert_eq(wd.get_total_enemy_count(), 15)

func test_wave_is_boss_wave_settable() -> void:
	var wd := WaveDefinition.new()
	wd.is_boss_wave = true
	assert_true(wd.is_boss_wave)

func test_wave_number_settable() -> void:
	var wd := WaveDefinition.new()
	wd.wave_number = 5
	assert_eq(wd.wave_number, 5)
