extends GutTest

func test_zigzag_generates_valid_path() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("zigzag", 1.0, 1, "1_4".hash())
	assert_true(result.has("paths"), "Result should have paths")
	assert_eq(result["paths"].size(), 1, "Zigzag should have 1 path")
	var path: Array = result["paths"][0]
	assert_true(path.size() >= 5, "Should have at least 5 waypoints")
	assert_true(path[0].x <= 0, "Start should be off-screen left")
	assert_true(path[path.size() - 1].x >= 1280, "End should be off-screen right")

func test_branching_generates_two_paths() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("branching", 1.0, 5, "1_5".hash())
	assert_eq(result["paths"].size(), 2, "Branching should have 2 paths")

func test_multi_entry_generates_multiple_paths() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("multi_entry", 2.0, 1, "3_5".hash())
	assert_true(result["paths"].size() >= 2, "Multi-entry should have 2+ paths")

func test_deterministic_generation() -> void:
	var gen := PathGenerator.new()
	var r1: Dictionary = gen.generate("zigzag", 1.0, 1, 42)
	var r2: Dictionary = gen.generate("zigzag", 1.0, 1, 42)
	assert_eq(r1["paths"][0], r2["paths"][0], "Same seed should produce same path")

func test_spiral_has_loop_back() -> void:
	var gen := PathGenerator.new()
	var result: Dictionary = gen.generate("spiral", 1.0, 1, "1_10".hash())
	var path: Array = result["paths"][0]
	var has_loop: bool = false
	for i in range(1, path.size()):
		if path[i].x < path[i - 1].x:
			has_loop = true
			break
	assert_true(has_loop, "Spiral should have at least one X decrease (loop-back)")
