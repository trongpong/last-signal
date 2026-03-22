extends GutTest

## Tests for core/tower_system/projectile.gd

var _proj: Projectile

func before_each() -> void:
	_proj = Projectile.new()
	add_child(_proj)

func after_each() -> void:
	if is_instance_valid(_proj):
		_proj.queue_free()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func test_not_initialized_by_default() -> void:
	assert_false(_proj._initialized)

func test_initialize_sets_target_pos() -> void:
	_proj.initialize(Vector2(100, 50), 400.0, 25.0, Enums.DamageType.PULSE)
	assert_eq(_proj._target_pos, Vector2(100, 50))

func test_initialize_sets_speed() -> void:
	_proj.initialize(Vector2(100, 0), 300.0, 10.0, Enums.DamageType.ARC)
	assert_almost_eq(_proj._speed, 300.0, 0.001)

func test_initialize_sets_damage() -> void:
	_proj.initialize(Vector2(100, 0), 400.0, 42.0, Enums.DamageType.PULSE)
	assert_almost_eq(_proj._damage, 42.0, 0.001)

func test_initialize_sets_damage_type() -> void:
	_proj.initialize(Vector2(100, 0), 400.0, 10.0, Enums.DamageType.CRYO)
	assert_eq(_proj._damage_type, Enums.DamageType.CRYO)

func test_initialize_sets_splash_radius() -> void:
	_proj.initialize(Vector2(100, 0), 400.0, 10.0, Enums.DamageType.MISSILE, 60.0)
	assert_almost_eq(_proj._splash_radius, 60.0, 0.001)

func test_initialize_default_splash_radius_zero() -> void:
	_proj.initialize(Vector2(100, 0), 400.0, 10.0, Enums.DamageType.PULSE)
	assert_almost_eq(_proj._splash_radius, 0.0, 0.001)

func test_initialize_clamps_speed_to_one() -> void:
	_proj.initialize(Vector2(100, 0), -50.0, 10.0, Enums.DamageType.PULSE)
	assert_almost_eq(_proj._speed, 1.0, 0.001)

func test_initialize_sets_initialized_flag() -> void:
	_proj.initialize(Vector2(100, 0), 400.0, 10.0, Enums.DamageType.PULSE)
	assert_true(_proj._initialized)

# ---------------------------------------------------------------------------
# Movement (process simulation)
# ---------------------------------------------------------------------------

func test_projectile_moves_toward_target() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(200, 0), 400.0, 10.0, Enums.DamageType.PULSE)
	_proj._process(0.1)
	assert_gt(_proj.global_position.x, 0.0)

func test_projectile_travel_distance_increases() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(500, 0), 400.0, 10.0, Enums.DamageType.PULSE)
	_proj._process(0.1)
	assert_gt(_proj._travel_distance, 0.0)

# ---------------------------------------------------------------------------
# Hit detection
# ---------------------------------------------------------------------------

func test_hit_signal_emitted_when_reaching_target() -> void:
	_proj.global_position = Vector2.ZERO
	# Target very close — within HIT_THRESHOLD
	_proj.initialize(Vector2(5, 0), 400.0, 25.0, Enums.DamageType.PULSE)
	watch_signals(_proj)
	_proj._process(0.016)
	assert_signal_emitted(_proj, "hit_target")

func test_hit_signal_carries_damage() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(5, 0), 400.0, 33.0, Enums.DamageType.BEAM)
	watch_signals(_proj)
	_proj._process(0.016)
	var args = get_signal_parameters(_proj, "hit_target")
	assert_almost_eq(args[1] as float, 33.0, 0.001)

func test_hit_signal_carries_damage_type() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(5, 0), 400.0, 10.0, Enums.DamageType.ARC)
	watch_signals(_proj)
	_proj._process(0.016)
	var args = get_signal_parameters(_proj, "hit_target")
	assert_eq(args[2], Enums.DamageType.ARC)

func test_hit_signal_carries_splash_radius() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(5, 0), 400.0, 10.0, Enums.DamageType.MISSILE, 75.0)
	watch_signals(_proj)
	_proj._process(0.016)
	var args = get_signal_parameters(_proj, "hit_target")
	assert_almost_eq(args[3] as float, 75.0, 0.001)

# ---------------------------------------------------------------------------
# Max distance expiry
# ---------------------------------------------------------------------------

func test_no_process_when_not_initialized() -> void:
	# Should not crash or move
	_proj.global_position = Vector2.ZERO
	_proj._process(1.0)
	assert_eq(_proj.global_position, Vector2.ZERO)

func test_travel_distance_accumulates_across_frames() -> void:
	_proj.global_position = Vector2.ZERO
	_proj.initialize(Vector2(5000, 0), 100.0, 10.0, Enums.DamageType.PULSE)
	_proj._process(0.1)
	_proj._process(0.1)
	assert_almost_eq(_proj._travel_distance, 20.0, 0.5)
