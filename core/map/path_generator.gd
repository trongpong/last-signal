class_name PathGenerator
extends RefCounted

var _last_seed: int = 0

# --- Public API ---

func generate(path_type: String, map_scale: float, level_number: int, path_seed: int) -> Dictionary:
	_last_seed = path_seed
	seed(path_seed)
	match path_type:
		"zigzag":
			return _build_result("zigzag", [_gen_zigzag(map_scale, level_number)], map_scale)
		"spiral":
			return _build_result("spiral", [_gen_spiral(map_scale, level_number)], map_scale)
		"branching":
			return _build_result("branching", _gen_branching(map_scale, level_number), map_scale)
		"multi_entry":
			return _build_result("multi_entry", _gen_multi_entry(map_scale, level_number, path_seed), map_scale)
		_:
			return _build_result("zigzag", [_gen_zigzag(map_scale, level_number)], map_scale)

# --- Helper accessors ---

func _playable_y_min(map_scale: float) -> float:
	return 57.0

func _playable_y_max(map_scale: float) -> float:
	return 720.0 * map_scale - 72.0

func _world_width(map_scale: float) -> float:
	return 1280.0 * map_scale

# --- Path generators ---

func _gen_zigzag(map_scale: float, level_number: int) -> Array:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)

	var start_y: float = randf_range(y_min, y_max)
	var end_y: float = randf_range(y_min, y_max)

	# Between 5 and 8 waypoints total (including start and end off-screen)
	var mid_count: int = randi_range(3, 6)  # interior zig-zag points
	var path: Array = []

	# Start off-screen left
	path.append(Vector2(-33.0, start_y))

	# Interior waypoints alternating high/low
	var step: float = w / float(mid_count + 1)
	for i in range(mid_count):
		var x: float = step * float(i + 1)
		# Alternate between y_min-region and y_max-region with some randomness
		var y: float
		if i % 2 == 0:
			y = randf_range(y_min, y_min + (y_max - y_min) * 0.4)
		else:
			y = randf_range(y_min + (y_max - y_min) * 0.6, y_max)
		path.append(Vector2(x, y))

	# End off-screen right
	path.append(Vector2(w + 33.0, end_y))

	return path

func _gen_spiral(map_scale: float, level_number: int) -> Array:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var mid_y: float = (y_min + y_max) * 0.5

	# 8-12 waypoints total
	var total_points: int = randi_range(8, 12)
	var path: Array = []

	# Start off-screen left
	var start_y: float = randf_range(y_min, y_max)
	path.append(Vector2(-33.0, start_y))

	# Phase 1: move right to about 40-55% of width
	var forward_end_x: float = randf_range(w * 0.40, w * 0.55)
	var phase1_count: int = int(float(total_points) * 0.35)
	phase1_count = max(phase1_count, 2)
	for i in range(phase1_count):
		var t: float = float(i + 1) / float(phase1_count + 1)
		var x: float = forward_end_x * t
		var y: float = randf_range(y_min, y_max)
		path.append(Vector2(x, y))

	# Phase 2: loop back — X decreases from forward_end_x back toward 20-35%
	var loop_back_x: float = randf_range(w * 0.20, w * 0.35)
	var phase2_count: int = int(float(total_points) * 0.30)
	phase2_count = max(phase2_count, 2)
	for i in range(phase2_count):
		var t: float = float(i + 1) / float(phase2_count + 1)
		var x: float = forward_end_x + (loop_back_x - forward_end_x) * t
		# Y swings to the opposite half from mid to add visual interest
		var y: float
		if start_y < mid_y:
			y = randf_range(mid_y, y_max)
		else:
			y = randf_range(y_min, mid_y)
		path.append(Vector2(x, y))

	# Phase 3: resume forward to off-screen right
	var remaining: int = total_points - 1 - phase1_count - phase2_count
	remaining = max(remaining, 2)
	for i in range(remaining):
		var t: float = float(i + 1) / float(remaining + 1)
		var x: float = loop_back_x + (w - loop_back_x) * t
		var y: float = randf_range(y_min, y_max)
		path.append(Vector2(x, y))

	# End off-screen right
	var end_y: float = randf_range(y_min, y_max)
	path.append(Vector2(w + 33.0, end_y))

	return path

func _gen_branching(map_scale: float, level_number: int) -> Array:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	var mid_y: float = (y_min + y_max) * 0.5

	# Shared start and end points
	var start_y: float = randf_range(y_min + 20.0, y_max - 20.0)
	var split_x: float = randf_range(w * 0.25, w * 0.40)
	var merge_x: float = randf_range(w * 0.60, w * 0.75)
	var end_y: float = randf_range(y_min + 20.0, y_max - 20.0)

	# Split point
	var split_y: float = randf_range(y_min + 20.0, y_max - 20.0)
	var merge_y: float = randf_range(y_min + 20.0, y_max - 20.0)

	# Upper branch: goes through upper half
	var upper_mid_x: float = randf_range(split_x + 30.0, merge_x - 30.0)
	var upper_mid_y: float = randf_range(y_min, mid_y - 10.0)

	# Lower branch: goes through lower half
	var lower_mid_x: float = randf_range(split_x + 30.0, merge_x - 30.0)
	var lower_mid_y: float = randf_range(mid_y + 10.0, y_max)

	var path_upper: Array = [
		Vector2(-33.0, start_y),
		Vector2(split_x, split_y),
		Vector2(upper_mid_x, upper_mid_y),
		Vector2(merge_x, merge_y),
		Vector2(w + 33.0, end_y)
	]

	var path_lower: Array = [
		Vector2(-33.0, start_y),
		Vector2(split_x, split_y),
		Vector2(lower_mid_x, lower_mid_y),
		Vector2(merge_x, merge_y),
		Vector2(w + 33.0, end_y)
	]

	return [path_upper, path_lower]

func _gen_multi_entry(map_scale: float, level_number: int, path_seed: int) -> Array:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)

	# Divide vertical space into thirds for band separation
	var band_height: float = (y_max - y_min) / 3.0
	var top_band_y: float = y_min + band_height * 0.5
	var mid_band_y: float = y_min + band_height * 1.5
	var bot_band_y: float = y_min + band_height * 2.5

	# Shared exit point on right side
	var exit_x: float = w + 33.0
	var exit_y: float = randf_range(y_min + 20.0, y_max - 20.0)

	# Mid convergence point
	var conv_x: float = randf_range(w * 0.60, w * 0.75)
	var conv_y: float = randf_range(y_min + 30.0, y_max - 30.0)

	# Path from top band (enter from left, upper region)
	var top_start_y: float = randf_range(y_min, y_min + band_height)
	var top_mid_x: float = randf_range(w * 0.25, w * 0.50)
	var top_mid_y: float = randf_range(y_min, top_band_y + band_height * 0.5)
	var path_top: Array = [
		Vector2(-33.0, top_start_y),
		Vector2(top_mid_x, top_mid_y),
		Vector2(conv_x, conv_y),
		Vector2(exit_x, exit_y)
	]

	# Path from bottom band (enter from left, lower region)
	var bot_start_y: float = randf_range(y_min + band_height * 2.0, y_max)
	var bot_mid_x: float = randf_range(w * 0.25, w * 0.50)
	var bot_mid_y: float = randf_range(bot_band_y - band_height * 0.5, y_max)
	var path_bot: Array = [
		Vector2(-33.0, bot_start_y),
		Vector2(bot_mid_x, bot_mid_y),
		Vector2(conv_x, conv_y),
		Vector2(exit_x, exit_y)
	]

	var paths: Array = [path_top, path_bot]

	# Optional 3rd path from top edge for higher levels or larger maps
	if level_number > 3 or map_scale >= 2.0:
		var top_edge_x: float = randf_range(w * 0.20, w * 0.60)
		var top_edge_mid_x: float = randf_range(top_edge_x, w * 0.70)
		var top_edge_mid_y: float = randf_range(y_min + 10.0, mid_band_y)
		var path_top_edge: Array = [
			Vector2(top_edge_x, -33.0),
			Vector2(top_edge_mid_x, top_edge_mid_y),
			Vector2(conv_x, conv_y),
			Vector2(exit_x, exit_y)
		]
		paths.append(path_top_edge)

	# Crossing avoidance: retry with incremented seed if paths cross
	if _paths_intersect(paths):
		seed(path_seed + 1)
		return _gen_multi_entry(map_scale, level_number, path_seed + 1)

	return paths

# --- Crossing avoidance ---

func _paths_intersect(paths: Array) -> bool:
	for i in range(paths.size()):
		for j in range(i + 1, paths.size()):
			if _two_paths_cross(paths[i], paths[j]):
				return true
	return false

func _two_paths_cross(path_a: Array, path_b: Array) -> bool:
	# Compare each segment of path_a against each segment of path_b
	for i in range(path_a.size() - 1):
		var a1: Vector2 = path_a[i]
		var a2: Vector2 = path_a[i + 1]
		for j in range(path_b.size() - 1):
			var b1: Vector2 = path_b[j]
			var b2: Vector2 = path_b[j + 1]
			# Skip shared endpoints (branching paths share start/end)
			if a1.is_equal_approx(b1) or a1.is_equal_approx(b2) or a2.is_equal_approx(b1) or a2.is_equal_approx(b2):
				continue
			if _segments_intersect(a1, a2, b1, b2):
				return true
	return false

func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	# Parametric cross-product test
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var cross: float = d1.x * d2.y - d1.y * d2.x
	if absf(cross) < 1e-6:
		return false  # Parallel or collinear
	var diff: Vector2 = p3 - p1
	var t: float = (diff.x * d2.y - diff.y * d2.x) / cross
	var u: float = (diff.x * d1.y - diff.y * d1.x) / cross
	return t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0

# --- Result builder ---

func _build_result(path_type: String, paths: Array, map_scale: float) -> Dictionary:
	var w: float = _world_width(map_scale)
	var y_min: float = _playable_y_min(map_scale)
	var y_max: float = _playable_y_max(map_scale)
	# Exit is the last point of the first path (clamped to playable area)
	var last_path: Array = paths[0]
	var exit_pos: Vector2 = last_path[last_path.size() - 1]
	return {
		"type": path_type,
		"paths": paths,
		"exit": exit_pos
	}
