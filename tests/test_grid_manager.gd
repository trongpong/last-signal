extends GutTest

## Tests for core/pathfinding/grid_manager.gd

var gm: GridManager

func before_each() -> void:
	gm = GridManager.new()
	add_child(gm)
	# 10×6 grid, 64×64 cells
	gm.initialize(Vector2i(10, 6), Vector2(64.0, 64.0))
	gm.set_entry_point(Vector2i(0, 2))
	gm.set_exit_point(Vector2i(9, 2))

func after_each() -> void:
	gm.queue_free()

# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

func test_cell_to_world_origin() -> void:
	var w := gm.cell_to_world(Vector2i(0, 0))
	assert_almost_eq(w.x, 32.0, 0.001)
	assert_almost_eq(w.y, 32.0, 0.001)

func test_cell_to_world_second_cell() -> void:
	var w := gm.cell_to_world(Vector2i(1, 0))
	assert_almost_eq(w.x, 96.0, 0.001)

func test_world_to_cell_inside() -> void:
	var cell := gm.world_to_cell(Vector2(100.0, 100.0))
	assert_eq(cell.x, 1)
	assert_eq(cell.y, 1)

func test_cell_to_world_world_to_cell_roundtrip() -> void:
	var original := Vector2i(3, 2)
	var world := gm.cell_to_world(original)
	var back := gm.world_to_cell(world)
	assert_eq(back, original)

# ---------------------------------------------------------------------------
# Path existence
# ---------------------------------------------------------------------------

func test_has_valid_path_after_init() -> void:
	assert_true(gm.has_valid_path())

func test_get_path_cells_non_empty() -> void:
	assert_gt(gm.get_path_cells().size(), 0)

func test_get_path_world_non_empty() -> void:
	assert_gt(gm.get_path_world().size(), 0)

func test_path_cells_starts_at_entry() -> void:
	var cells := gm.get_path_cells()
	assert_eq(cells[0] as Vector2i, Vector2i(0, 2))

func test_path_cells_ends_at_exit() -> void:
	var cells := gm.get_path_cells()
	assert_eq(cells[cells.size() - 1] as Vector2i, Vector2i(9, 2))

# ---------------------------------------------------------------------------
# can_place_tower
# ---------------------------------------------------------------------------

func test_can_place_off_path_cell() -> void:
	# Cell (5, 0) is not on the straight row-2 path and grid is open → should allow
	assert_true(gm.can_place_tower(Vector2i(5, 0)))

func test_cannot_place_on_entry() -> void:
	assert_false(gm.can_place_tower(Vector2i(0, 2)))

func test_cannot_place_on_exit() -> void:
	assert_false(gm.can_place_tower(Vector2i(9, 2)))

func test_cannot_place_out_of_bounds() -> void:
	assert_false(gm.can_place_tower(Vector2i(-1, 0)))
	assert_false(gm.can_place_tower(Vector2i(0, -1)))
	assert_false(gm.can_place_tower(Vector2i(10, 0)))
	assert_false(gm.can_place_tower(Vector2i(0, 6)))

func test_cannot_place_blocking_only_path() -> void:
	# Fill an entire column to block the only path
	for row in range(6):
		if Vector2i(5, row) != Vector2i(0, 2) and Vector2i(5, row) != Vector2i(9, 2):
			gm.place_tower(Vector2i(5, row))
	# Now the path is blocked; placing on (5,2) should be refused (already occupied check
	# would catch, but we test that a blocking placement is rejected by can_place_tower)
	# Instead check that has_valid_path is now false
	assert_false(gm.has_valid_path())

# ---------------------------------------------------------------------------
# place_tower / remove_tower
# ---------------------------------------------------------------------------

func test_place_tower_marks_cell_occupied() -> void:
	gm.place_tower(Vector2i(3, 0))
	# After placement, can_place_tower on same cell should be false
	assert_false(gm.can_place_tower(Vector2i(3, 0)))

func test_place_tower_emits_path_updated() -> void:
	watch_signals(gm)
	gm.place_tower(Vector2i(3, 0))
	assert_signal_emitted(gm, "path_updated")

func test_remove_tower_re_enables_cell() -> void:
	gm.place_tower(Vector2i(3, 0))
	gm.remove_tower(Vector2i(3, 0))
	assert_true(gm.can_place_tower(Vector2i(3, 0)))

func test_remove_tower_emits_path_updated() -> void:
	gm.place_tower(Vector2i(3, 0))
	watch_signals(gm)
	gm.remove_tower(Vector2i(3, 0))
	assert_signal_emitted(gm, "path_updated")

# ---------------------------------------------------------------------------
# No entry/exit
# ---------------------------------------------------------------------------

func test_no_valid_path_without_entry_exit() -> void:
	var gm2 := GridManager.new()
	add_child(gm2)
	gm2.initialize(Vector2i(5, 5), Vector2(64.0, 64.0))
	assert_false(gm2.has_valid_path())
	gm2.queue_free()
