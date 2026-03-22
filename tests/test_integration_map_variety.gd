extends GutTest

func test_zigzag_level_creates_single_path() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("1_1")
	assert_eq(paths["type"], "zigzag")
	assert_eq(paths["paths"].size(), 1)

func test_branching_level_creates_two_paths() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("1_5")
	assert_eq(paths["type"], "branching")
	assert_eq(paths["paths"].size(), 2)

func test_spiral_level_has_loop_back() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("1_10")
	assert_eq(paths["type"], "spiral")
	var path: Array = paths["paths"][0]
	var has_loop: bool = false
	for i in range(1, path.size()):
		if path[i].x < path[i - 1].x:
			has_loop = true
			break
	assert_true(has_loop, "Spiral should have at least one X decrease")

func test_procedural_fallback_for_unknown_level() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("1_7")
	assert_true(paths.is_empty(), "Non-milestone should have no hand-crafted data")
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("zigzag", 1.0, 7, "1_7".hash())
	assert_true(result["paths"].size() > 0, "PathGenerator should produce paths")

func test_map_scale_matches_region() -> void:
	var reg := LevelRegistry.new()
	reg.register_levels()
	for region in range(1, 6):
		var level_id: String = "%d_1" % region
		var level: Dictionary = reg.get_level(level_id)
		var expected: float = 1.0 + float(region - 1) * 0.5
		assert_eq(level["map_scale"], expected, "Region %d should have scale %.1f" % [region, expected])

func test_multi_entry_level_has_multiple_paths() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("3_9")
	assert_eq(paths["type"], "multi_entry")
	assert_true(paths["paths"].size() >= 2, "Multi-entry should have 2+ paths")

func test_scaled_level_path_coordinates() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var paths: Dictionary = LevelDataClass.get_level_paths("3_1")
	if paths.is_empty():
		pass_test("No hand-crafted data for 3_1")
		return
	# Scale 2.0: world width = 2560, so exit X should be > 2500
	var first_path: Array = paths["paths"][0]
	var last_point: Vector2 = first_path[first_path.size() - 1]
	assert_true(last_point.x > 2500, "Scale 2.0 level exit should be beyond 2500px X")

func test_all_milestone_levels_have_wave_data() -> void:
	var LevelDataClass = load("res://content/levels/level_data.gd")
	var milestones: Array = ["1_1", "1_2", "1_3", "1_5", "1_10", "2_1", "2_10", "3_1", "3_9", "4_1", "4_9", "5_1", "5_8"]
	for level_id in milestones:
		var waves: Array = LevelDataClass.get_waves(level_id)
		assert_true(waves.size() > 0, "Milestone %s should have wave data" % level_id)
