class_name GridManager
extends Node

## Manages a grid for the GRID_MAZE map mode.
## Handles tower placement validation (ensuring path remains passable),
## A* pathfinding, and converting between cell and world coordinates.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever the path changes (tower placed/removed or init).
signal path_updated(path_cells: Array)

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

var _grid_size: Vector2i = Vector2i(20, 12)
var _cell_size: Vector2 = Vector2(64.0, 64.0)
var _entry_cell: Vector2i = Vector2i(-1, -1)
var _exit_cell: Vector2i = Vector2i(-1, -1)
var _occupied: Dictionary = {}   # Vector2i → true
var _astar: AStar2D = null
var _path_cells: Array = []       # Array[Vector2i] of current path

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Sets up the grid with the given size (in cells) and cell dimensions.
func initialize(size: Vector2i, cell_size: Vector2) -> void:
	_grid_size = size
	_cell_size = cell_size
	_occupied.clear()
	_astar = AStar2D.new()
	_path_cells = []
	_populate_astar()

## Sets the entry cell (where enemies spawn).
func set_entry_point(cell: Vector2i) -> void:
	_entry_cell = cell
	_rebuild_astar()

## Sets the exit cell (where enemies escape).
func set_exit_point(cell: Vector2i) -> void:
	_exit_cell = cell
	_rebuild_astar()

# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

## Returns the world-space center of a grid cell.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * _cell_size.x + _cell_size.x * 0.5,
		cell.y * _cell_size.y + _cell_size.y * 0.5
	)

## Returns the grid cell that contains the given world position.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / _cell_size.x),
		int(world_pos.y / _cell_size.y)
	)

# ---------------------------------------------------------------------------
# Tower placement
# ---------------------------------------------------------------------------

## Returns true if a tower can be placed at cell:
##   - Cell is inside grid bounds
##   - Cell is not already occupied
##   - Cell is not the entry or exit point
##   - A valid path still exists after hypothetical placement
func can_place_tower(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false
	if _occupied.has(cell):
		return false
	if cell == _entry_cell or cell == _exit_cell:
		return false
	# Simulate placement and check path
	_occupied[cell] = true
	_rebuild_astar()
	var valid := has_valid_path()
	# Undo simulation
	_occupied.erase(cell)
	_rebuild_astar()
	return valid

## Places a tower at the cell (call only after can_place_tower() returns true).
func place_tower(cell: Vector2i) -> void:
	_occupied[cell] = true
	_rebuild_astar()
	_emit_path_updated()

## Removes a tower at the cell.
func remove_tower(cell: Vector2i) -> void:
	_occupied.erase(cell)
	_rebuild_astar()
	_emit_path_updated()

## Returns true if a path exists from entry to exit.
func has_valid_path() -> bool:
	if _entry_cell == Vector2i(-1, -1) or _exit_cell == Vector2i(-1, -1):
		return false
	var entry_id: int = _cell_to_id(_entry_cell)
	var exit_id: int = _cell_to_id(_exit_cell)
	if not _astar.has_point(entry_id) or not _astar.has_point(exit_id):
		return false
	var path: PackedVector2Array = _astar.get_point_path(entry_id, exit_id)
	return path.size() > 0

## Returns the current path as an Array[Vector2i] of cells.
func get_path_cells() -> Array:
	return _path_cells.duplicate()

## Returns the current path as world-space Vector2 positions.
func get_path_world() -> Array:
	var world_path: Array = []
	for cell in _path_cells:
		world_path.append(cell_to_world(cell))
	return world_path

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y

func _cell_to_id(cell: Vector2i) -> int:
	return cell.y * _grid_size.x + cell.x

func _id_to_cell(id: int) -> Vector2i:
	if id < 0 or id >= _grid_size.x * _grid_size.y:
		return Vector2i(-1, -1)
	return Vector2i(id % _grid_size.x, id / _grid_size.x)

func _populate_astar() -> void:
	if _astar == null:
		return
	_astar.clear()
	for y in range(_grid_size.y):
		for x in range(_grid_size.x):
			var cell := Vector2i(x, y)
			if not _occupied.has(cell):
				var id: int = _cell_to_id(cell)
				_astar.add_point(id, Vector2(float(x), float(y)))
	_connect_astar_neighbors()

func _rebuild_astar() -> void:
	_populate_astar()
	_update_path_cells()

func _connect_astar_neighbors() -> void:
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(_grid_size.y):
		for x in range(_grid_size.x):
			var cell := Vector2i(x, y)
			if _occupied.has(cell):
				continue
			var id: int = _cell_to_id(cell)
			for dir in directions:
				var neighbor: Vector2i = cell + dir
				if _is_in_bounds(neighbor) and not _occupied.has(neighbor):
					var neighbor_id: int = _cell_to_id(neighbor)
					if not _astar.are_points_connected(id, neighbor_id):
						_astar.connect_points(id, neighbor_id)

func _update_path_cells() -> void:
	_path_cells = []
	if _entry_cell == Vector2i(-1, -1) or _exit_cell == Vector2i(-1, -1):
		return
	var entry_id: int = _cell_to_id(_entry_cell)
	var exit_id: int = _cell_to_id(_exit_cell)
	if not _astar.has_point(entry_id) or not _astar.has_point(exit_id):
		return
	var id_path: PackedInt64Array = _astar.get_id_path(entry_id, exit_id)
	for pid in id_path:
		_path_cells.append(_id_to_cell(pid))

func _emit_path_updated() -> void:
	path_updated.emit(_path_cells.duplicate())
