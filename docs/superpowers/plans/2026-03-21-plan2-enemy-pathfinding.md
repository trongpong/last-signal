# Plan 2: Enemy & Pathfinding Systems

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the enemy framework — base enemy class, 6 archetypes with geometric rendering, health/armor/shield system, and both pathfinding modes (fixed-path following and A* grid maze).

**Architecture:** Enemies are scenes composed of a base `Enemy` class that reads `EnemyDefinition` resources. Pathfinding is abstracted behind a `PathProvider` interface so enemies don't care whether they're on a fixed path or A* grid. Geometric shapes are drawn via Godot's `_draw()` method — no sprites needed.

**Tech Stack:** Godot 4.x, GDScript, GUT, AStar2D

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Sections 5, 8

**Depends on:** Plan 1 (Foundation)

---

## File Structure

```
res://
├── core/
│   ├── enemy_system/
│   │   ├── enemy.gd                    # Base enemy class (Node2D)
│   │   ├── enemy.tscn                  # Base enemy scene
│   │   ├── enemy_definition.gd         # EnemyDefinition Resource script
│   │   ├── enemy_health.gd             # Health/armor/shield component
│   │   └── enemy_renderer.gd           # Geometric shape drawing
│   └── pathfinding/
│       ├── path_provider.gd            # Abstract interface for pathfinding
│       ├── fixed_path_provider.gd      # Path2D follower
│       ├── grid_path_provider.gd       # A* grid pathfinding
│       └── grid_manager.gd             # Grid state, tower blocking, path validation
├── content/
│   └── enemies/
│       ├── scout.tres
│       ├── drone.tres
│       ├── tank.tres
│       ├── flyer.tres
│       ├── shielder.tres
│       └── healer.tres
└── tests/
    ├── test_enemy.gd
    ├── test_enemy_health.gd
    ├── test_enemy_definition.gd
    ├── test_fixed_path_provider.gd
    ├── test_grid_path_provider.gd
    └── test_grid_manager.gd
```

---

### Task 1: Create EnemyDefinition Resource

**Files:**
- Create: `core/enemy_system/enemy_definition.gd`
- Test: `tests/test_enemy_definition.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_enemy_definition.gd
extends GutTest

func test_create_enemy_definition():
    var def := EnemyDefinition.new()
    def.id = "scout"
    def.display_name = "ENEMY_SCOUT"
    def.archetype = Enums.EnemyArchetype.SCOUT
    def.base_hp = 50.0
    def.speed = 200.0
    def.armor = 0.0
    def.shield = 0.0
    def.gold_value = 5
    assert_eq(def.id, "scout")
    assert_eq(def.archetype, Enums.EnemyArchetype.SCOUT)
    assert_eq(def.base_hp, 50.0)

func test_default_resistance_map():
    var def := EnemyDefinition.new()
    assert_eq(def.resistance_map.size(), 0)

func test_enemy_shape_and_color():
    var def := EnemyDefinition.new()
    def.shape_sides = 3
    def.shape_radius = 10.0
    def.color = Color.YELLOW
    assert_eq(def.shape_sides, 3)
    assert_eq(def.color, Color.YELLOW)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/enemy_system/enemy_definition.gd
class_name EnemyDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: Enums.EnemyArchetype = Enums.EnemyArchetype.DRONE
@export var base_hp: float = 100.0
@export var speed: float = 150.0
@export var armor: float = 0.0
@export var shield: float = 0.0
@export var gold_value: int = 10
@export var diamond_chance: float = 0.0
@export var shape_sides: int = 4
@export var shape_radius: float = 12.0
@export var color: Color = Color.WHITE
@export var size_scale: float = 1.0
@export var resistance_map: Dictionary = {}
@export var abilities: Array[String] = []
@export var is_boss: bool = false
@export var is_flying: bool = false
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/enemy_system/enemy_definition.gd tests/test_enemy_definition.gd
git commit -m "feat: create EnemyDefinition resource type"
```

---

### Task 2: Implement EnemyHealth Component

**Files:**
- Create: `core/enemy_system/enemy_health.gd`
- Test: `tests/test_enemy_health.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_enemy_health.gd
extends GutTest

var health: EnemyHealth

func before_each():
    health = EnemyHealth.new()
    add_child(health)

func after_each():
    health.queue_free()

func test_initialize_hp():
    health.initialize(100.0, 0.0, 0.0)
    assert_eq(health.current_hp, 100.0)
    assert_eq(health.max_hp, 100.0)

func test_take_damage_basic():
    health.initialize(100.0, 0.0, 0.0)
    health.take_damage(30.0, Enums.DamageType.PULSE)
    assert_eq(health.current_hp, 70.0)

func test_armor_reduces_damage():
    health.initialize(100.0, 10.0, 0.0)
    health.take_damage(30.0, Enums.DamageType.PULSE)
    # 30 - 10 armor = 20 damage
    assert_eq(health.current_hp, 80.0)

func test_armor_minimum_damage():
    health.initialize(100.0, 50.0, 0.0)
    health.take_damage(10.0, Enums.DamageType.PULSE)
    # Minimum 1 damage even with high armor
    assert_eq(health.current_hp, 99.0)

func test_shield_absorbs_first():
    health.initialize(100.0, 0.0, 50.0)
    health.take_damage(30.0, Enums.DamageType.PULSE)
    assert_eq(health.current_shield, 20.0)
    assert_eq(health.current_hp, 100.0)

func test_shield_overflow_to_hp():
    health.initialize(100.0, 0.0, 20.0)
    health.take_damage(50.0, Enums.DamageType.PULSE)
    assert_eq(health.current_shield, 0.0)
    assert_eq(health.current_hp, 70.0)

func test_resistance_reduces_damage():
    health.initialize(100.0, 0.0, 0.0)
    health.resistance_map = { Enums.DamageType.PULSE: 0.5 }
    health.take_damage(100.0, Enums.DamageType.PULSE)
    assert_eq(health.current_hp, 50.0)

func test_death_signal():
    health.initialize(50.0, 0.0, 0.0)
    watch_signals(health)
    health.take_damage(50.0, Enums.DamageType.PULSE)
    assert_signal_emitted(health, "died")

func test_is_alive():
    health.initialize(50.0, 0.0, 0.0)
    assert_true(health.is_alive())
    health.take_damage(50.0, Enums.DamageType.PULSE)
    assert_false(health.is_alive())

func test_health_changed_signal():
    health.initialize(100.0, 0.0, 0.0)
    watch_signals(health)
    health.take_damage(20.0, Enums.DamageType.PULSE)
    assert_signal_emitted(health, "health_changed")

func test_heal():
    health.initialize(100.0, 0.0, 0.0)
    health.take_damage(50.0, Enums.DamageType.PULSE)
    health.heal(20.0)
    assert_eq(health.current_hp, 70.0)

func test_heal_cannot_exceed_max():
    health.initialize(100.0, 0.0, 0.0)
    health.take_damage(10.0, Enums.DamageType.PULSE)
    health.heal(50.0)
    assert_eq(health.current_hp, 100.0)

func test_add_shield():
    health.initialize(100.0, 0.0, 0.0)
    health.add_shield(30.0)
    assert_eq(health.current_shield, 30.0)

func test_hp_percentage():
    health.initialize(100.0, 0.0, 0.0)
    health.take_damage(25.0, Enums.DamageType.PULSE)
    assert_almost_eq(health.get_hp_percentage(), 0.75, 0.01)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/enemy_system/enemy_health.gd
class_name EnemyHealth
extends Node

signal health_changed(hp: float, max_hp: float, shield: float)
signal died()

var max_hp: float = 0.0
var current_hp: float = 0.0
var armor: float = 0.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var resistance_map: Dictionary = {}

const MIN_DAMAGE := 1.0


func initialize(hp: float, p_armor: float, shield: float) -> void:
    max_hp = hp
    current_hp = hp
    armor = p_armor
    max_shield = shield
    current_shield = shield


func take_damage(amount: float, damage_type: Enums.DamageType) -> void:
    var effective := amount

    # Apply resistance
    if damage_type in resistance_map:
        effective *= (1.0 - resistance_map[damage_type])

    # Apply armor
    effective = maxf(effective - armor, MIN_DAMAGE)

    # Shield absorbs first
    if current_shield > 0.0:
        if effective <= current_shield:
            current_shield -= effective
            health_changed.emit(current_hp, max_hp, current_shield)
            return
        else:
            effective -= current_shield
            current_shield = 0.0

    current_hp -= effective
    current_hp = maxf(current_hp, 0.0)
    health_changed.emit(current_hp, max_hp, current_shield)

    if current_hp <= 0.0:
        died.emit()


func heal(amount: float) -> void:
    current_hp = minf(current_hp + amount, max_hp)
    health_changed.emit(current_hp, max_hp, current_shield)


func add_shield(amount: float) -> void:
    current_shield += amount
    health_changed.emit(current_hp, max_hp, current_shield)


func is_alive() -> bool:
    return current_hp > 0.0


func get_hp_percentage() -> float:
    if max_hp == 0.0:
        return 0.0
    return current_hp / max_hp
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/enemy_system/enemy_health.gd tests/test_enemy_health.gd
git commit -m "feat: implement EnemyHealth with armor, shield, and resistance"
```

---

### Task 3: Implement EnemyRenderer (Geometric Drawing)

**Files:**
- Create: `core/enemy_system/enemy_renderer.gd`

- [ ] **Step 1: Write implementation**

```gdscript
# core/enemy_system/enemy_renderer.gd
class_name EnemyRenderer
extends Node2D

## Draws geometric shapes for enemies using _draw().
## No sprites needed — all visuals are procedural.

var shape_sides: int = 4
var shape_radius: float = 12.0
var base_color: Color = Color.WHITE
var size_scale: float = 1.0
var rotation_speed: float = 0.0
var resistance_outline_color: Color = Color.TRANSPARENT
var show_health_bar: bool = false
var hp_percentage: float = 1.0
var shield_percentage: float = 0.0

const HEALTH_BAR_WIDTH := 30.0
const HEALTH_BAR_HEIGHT := 4.0
const HEALTH_BAR_OFFSET := -20.0


func setup(definition: EnemyDefinition) -> void:
    shape_sides = definition.shape_sides
    shape_radius = definition.shape_radius
    base_color = definition.color
    size_scale = definition.size_scale
    if definition.archetype == Enums.EnemyArchetype.FLYER:
        rotation_speed = 2.0


func _process(delta: float) -> void:
    if rotation_speed != 0.0:
        rotation += rotation_speed * delta
    queue_redraw()


func _draw() -> void:
    var radius := shape_radius * size_scale
    var points := _get_polygon_points(shape_sides, radius)

    # Main shape fill
    draw_colored_polygon(points, base_color)

    # Shape outline
    var outline_color := base_color.lightened(0.3)
    for i in range(points.size()):
        var next := (i + 1) % points.size()
        draw_line(points[i], points[next], outline_color, 1.5)

    # Adaptation resistance outline (colored ring)
    if resistance_outline_color != Color.TRANSPARENT:
        var outer_points := _get_polygon_points(shape_sides, radius + 3.0)
        for i in range(outer_points.size()):
            var next := (i + 1) % outer_points.size()
            draw_line(outer_points[i], outer_points[next], resistance_outline_color, 2.0)

    # Health bar (for bosses or when damaged)
    if show_health_bar and hp_percentage < 1.0:
        _draw_health_bar()


func _draw_health_bar() -> void:
    var bar_pos := Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_OFFSET)
    # Background
    draw_rect(Rect2(bar_pos, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color(0.2, 0.2, 0.2, 0.8))
    # HP fill
    var hp_width := HEALTH_BAR_WIDTH * hp_percentage
    var hp_color := Color.GREEN if hp_percentage > 0.5 else (Color.YELLOW if hp_percentage > 0.25 else Color.RED)
    draw_rect(Rect2(bar_pos, Vector2(hp_width, HEALTH_BAR_HEIGHT)), hp_color)
    # Shield overlay
    if shield_percentage > 0.0:
        var shield_width := HEALTH_BAR_WIDTH * shield_percentage
        draw_rect(Rect2(bar_pos + Vector2(0, -2), Vector2(shield_width, 2.0)), Color(0.3, 0.5, 1.0, 0.8))


func _get_polygon_points(sides: int, radius: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(sides):
        var angle := (TAU / sides) * i - PI / 2.0
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
```

- [ ] **Step 2: Test manually in editor**

Create a temporary scene with an `EnemyRenderer` node, set `shape_sides=3`, `base_color=Color.YELLOW`, run scene — verify a yellow triangle is drawn.

- [ ] **Step 3: Commit**

```bash
git add core/enemy_system/enemy_renderer.gd
git commit -m "feat: implement geometric EnemyRenderer with health bars"
```

---

### Task 4: Implement PathProvider Interface and FixedPathProvider

**Files:**
- Create: `core/pathfinding/path_provider.gd`
- Create: `core/pathfinding/fixed_path_provider.gd`
- Test: `tests/test_fixed_path_provider.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_fixed_path_provider.gd
extends GutTest

var provider: FixedPathProvider
var path: Path2D
var follow: PathFollow2D

func before_each():
    path = Path2D.new()
    var curve := Curve2D.new()
    curve.add_point(Vector2(0, 0))
    curve.add_point(Vector2(100, 0))
    curve.add_point(Vector2(100, 100))
    path.curve = curve
    add_child(path)

    follow = PathFollow2D.new()
    follow.rotates = false
    follow.loop = false
    path.add_child(follow)

    provider = FixedPathProvider.new()
    provider.path_follow = follow
    add_child(provider)

func after_each():
    provider.queue_free()
    path.queue_free()

func test_initial_progress_is_zero():
    assert_eq(provider.get_progress_ratio(), 0.0)

func test_move_advances_progress():
    provider.move(50.0, 0.1)
    assert_gt(provider.get_progress_ratio(), 0.0)

func test_reached_end():
    assert_false(provider.has_reached_end())
    # Move a lot to reach the end
    for i in range(100):
        provider.move(200.0, 0.1)
    assert_true(provider.has_reached_end())

func test_get_position():
    var pos := provider.get_current_position()
    assert_eq(pos, Vector2(0, 0))
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/pathfinding/path_provider.gd
class_name PathProvider
extends Node

## Abstract interface for enemy pathfinding.
## Subclasses implement fixed-path following or A* grid navigation.

func move(_speed: float, _delta: float) -> void:
    pass

func get_current_position() -> Vector2:
    return Vector2.ZERO

func get_progress_ratio() -> float:
    return 0.0

func has_reached_end() -> bool:
    return false
```

```gdscript
# core/pathfinding/fixed_path_provider.gd
class_name FixedPathProvider
extends PathProvider

## Follows a Path2D using PathFollow2D.

var path_follow: PathFollow2D


func move(speed: float, delta: float) -> void:
    if path_follow:
        path_follow.progress += speed * delta


func get_current_position() -> Vector2:
    if path_follow:
        return path_follow.global_position
    return Vector2.ZERO


func get_progress_ratio() -> float:
    if path_follow:
        return path_follow.progress_ratio
    return 0.0


func has_reached_end() -> bool:
    if path_follow:
        return path_follow.progress_ratio >= 1.0
    return false
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/pathfinding/path_provider.gd core/pathfinding/fixed_path_provider.gd tests/test_fixed_path_provider.gd
git commit -m "feat: implement PathProvider interface and FixedPathProvider"
```

---

### Task 5: Implement GridManager and GridPathProvider

**Files:**
- Create: `core/pathfinding/grid_manager.gd`
- Create: `core/pathfinding/grid_path_provider.gd`
- Test: `tests/test_grid_path_provider.gd`
- Test: `tests/test_grid_manager.gd`

- [ ] **Step 1: Write GridManager test**

```gdscript
# tests/test_grid_manager.gd
extends GutTest

var grid: GridManager

func before_each():
    grid = GridManager.new()
    grid.initialize(Vector2i(10, 10), Vector2(64, 64))
    grid.set_entry_point(Vector2i(0, 5))
    grid.set_exit_point(Vector2i(9, 5))
    add_child(grid)

func after_each():
    grid.queue_free()

func test_grid_dimensions():
    assert_eq(grid.grid_size, Vector2i(10, 10))

func test_cell_to_world():
    var world := grid.cell_to_world(Vector2i(1, 1))
    assert_eq(world, Vector2(96.0, 96.0))  # (1 * 64 + 32, 1 * 64 + 32)

func test_world_to_cell():
    var cell := grid.world_to_cell(Vector2(96.0, 96.0))
    assert_eq(cell, Vector2i(1, 1))

func test_can_place_tower_on_empty():
    assert_true(grid.can_place_tower(Vector2i(3, 3)))

func test_cannot_place_tower_on_entry():
    assert_false(grid.can_place_tower(Vector2i(0, 5)))

func test_cannot_place_tower_on_exit():
    assert_false(grid.can_place_tower(Vector2i(9, 5)))

func test_place_tower_blocks_cell():
    grid.place_tower(Vector2i(3, 3))
    assert_false(grid.can_place_tower(Vector2i(3, 3)))

func test_remove_tower_frees_cell():
    grid.place_tower(Vector2i(3, 3))
    grid.remove_tower(Vector2i(3, 3))
    assert_true(grid.can_place_tower(Vector2i(3, 3)))

func test_path_exists():
    assert_true(grid.has_valid_path())

func test_blocking_path_rejected():
    # Fill a column to block the path
    for y in range(10):
        if grid.can_place_tower(Vector2i(5, y)):
            grid.place_tower(Vector2i(5, y))
    # The last placement that would block should fail
    # (can_place_tower checks path validity)
    assert_true(grid.has_valid_path())

func test_get_path_returns_cells():
    var path := grid.get_path_cells()
    assert_gt(path.size(), 0)
    assert_eq(path[0], Vector2i(0, 5))
    assert_eq(path[-1], Vector2i(9, 5))
```

- [ ] **Step 2: Write GridPathProvider test**

```gdscript
# tests/test_grid_path_provider.gd
extends GutTest

var grid: GridManager
var provider: GridPathProvider

func before_each():
    grid = GridManager.new()
    grid.initialize(Vector2i(10, 10), Vector2(64, 64))
    grid.set_entry_point(Vector2i(0, 5))
    grid.set_exit_point(Vector2i(9, 5))
    add_child(grid)

    provider = GridPathProvider.new()
    provider.setup(grid)
    add_child(provider)

func after_each():
    provider.queue_free()
    grid.queue_free()

func test_initial_position_is_entry():
    var pos := provider.get_current_position()
    var expected := grid.cell_to_world(Vector2i(0, 5))
    assert_almost_eq(pos.x, expected.x, 1.0)
    assert_almost_eq(pos.y, expected.y, 1.0)

func test_move_toward_exit():
    var start := provider.get_current_position()
    provider.move(200.0, 0.1)
    var after := provider.get_current_position()
    assert_ne(start, after)

func test_eventually_reaches_end():
    for i in range(500):
        provider.move(200.0, 0.1)
    assert_true(provider.has_reached_end())
```

- [ ] **Step 3: Run tests to verify they fail**

- [ ] **Step 4: Write GridManager implementation**

```gdscript
# core/pathfinding/grid_manager.gd
class_name GridManager
extends Node

signal path_updated()

var grid_size: Vector2i = Vector2i.ZERO
var cell_size: Vector2 = Vector2(64, 64)
var _occupied: Dictionary = {}  # Vector2i -> bool
var _entry_points: Array[Vector2i] = []
var _exit_points: Array[Vector2i] = []
var _astar: AStar2D
var _cached_path: PackedVector2Array = PackedVector2Array()


func initialize(size: Vector2i, p_cell_size: Vector2) -> void:
    grid_size = size
    cell_size = p_cell_size
    _astar = AStar2D.new()
    _rebuild_astar()


func set_entry_point(cell: Vector2i) -> void:
    _entry_points.append(cell)


func set_exit_point(cell: Vector2i) -> void:
    _exit_points.append(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * cell_size.x + cell_size.x / 2.0,
                   cell.y * cell_size.y + cell_size.y / 2.0)


func world_to_cell(world: Vector2) -> Vector2i:
    return Vector2i(int(world.x / cell_size.x), int(world.y / cell_size.y))


func can_place_tower(cell: Vector2i) -> bool:
    if cell in _occupied:
        return false
    if cell in _entry_points or cell in _exit_points:
        return false
    if not _is_in_bounds(cell):
        return false
    # Check if placing here still leaves a valid path
    _occupied[cell] = true
    _rebuild_astar()
    var valid := has_valid_path()
    _occupied.erase(cell)
    _rebuild_astar()
    return valid


func place_tower(cell: Vector2i) -> bool:
    if not can_place_tower(cell):
        return false
    _occupied[cell] = true
    _rebuild_astar()
    _update_cached_path()
    path_updated.emit()
    return true


func remove_tower(cell: Vector2i) -> void:
    _occupied.erase(cell)
    _rebuild_astar()
    _update_cached_path()
    path_updated.emit()


func has_valid_path() -> bool:
    if _entry_points.is_empty() or _exit_points.is_empty():
        return false
    var from_id := _cell_to_id(_entry_points[0])
    var to_id := _cell_to_id(_exit_points[0])
    if not _astar.has_point(from_id) or not _astar.has_point(to_id):
        return false
    return _astar.get_id_path(from_id, to_id).size() > 0


func get_path_cells() -> Array[Vector2i]:
    if _entry_points.is_empty() or _exit_points.is_empty():
        return []
    var from_id := _cell_to_id(_entry_points[0])
    var to_id := _cell_to_id(_exit_points[0])
    var id_path := _astar.get_id_path(from_id, to_id)
    var cells: Array[Vector2i] = []
    for id in id_path:
        cells.append(_id_to_cell(id))
    return cells


func get_path_world() -> PackedVector2Array:
    return _cached_path


func is_occupied(cell: Vector2i) -> bool:
    return cell in _occupied


func _is_in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y


func _cell_to_id(cell: Vector2i) -> int:
    return cell.y * grid_size.x + cell.x


func _id_to_cell(id: int) -> Vector2i:
    return Vector2i(id % grid_size.x, id / grid_size.x)


func _rebuild_astar() -> void:
    _astar.clear()
    # Add all non-occupied cells
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var cell := Vector2i(x, y)
            if cell not in _occupied:
                var id := _cell_to_id(cell)
                _astar.add_point(id, Vector2(x, y))
    # Connect neighbors
    for y in range(grid_size.y):
        for x in range(grid_size.x):
            var cell := Vector2i(x, y)
            if cell in _occupied:
                continue
            var id := _cell_to_id(cell)
            # 4-directional
            for neighbor in [Vector2i(x+1, y), Vector2i(x, y+1)]:
                if _is_in_bounds(neighbor) and neighbor not in _occupied:
                    var nid := _cell_to_id(neighbor)
                    _astar.connect_points(id, nid)


func _update_cached_path() -> void:
    _cached_path.clear()
    var cells := get_path_cells()
    for cell in cells:
        _cached_path.append(cell_to_world(cell))
```

- [ ] **Step 5: Write GridPathProvider implementation**

```gdscript
# core/pathfinding/grid_path_provider.gd
class_name GridPathProvider
extends PathProvider

## Follows an A*-computed path on a grid.

var _grid: GridManager
var _path_points: PackedVector2Array = PackedVector2Array()
var _current_index: int = 0
var _current_position: Vector2 = Vector2.ZERO
var _reached_end: bool = false


func setup(grid: GridManager) -> void:
    _grid = grid
    _path_points = grid.get_path_world()
    if _path_points.size() > 0:
        _current_position = _path_points[0]
        _current_index = 0
    _grid.path_updated.connect(_on_path_updated)


func move(speed: float, delta: float) -> void:
    if _reached_end or _path_points.is_empty():
        return

    var distance := speed * delta
    while distance > 0.0 and _current_index < _path_points.size() - 1:
        var target := _path_points[_current_index + 1]
        var to_target := target - _current_position
        var dist_to_target := to_target.length()

        if distance >= dist_to_target:
            _current_position = target
            distance -= dist_to_target
            _current_index += 1
        else:
            _current_position += to_target.normalized() * distance
            distance = 0.0

    if _current_index >= _path_points.size() - 1:
        _reached_end = true


func get_current_position() -> Vector2:
    return _current_position


func get_progress_ratio() -> float:
    if _path_points.size() <= 1:
        return 1.0
    return float(_current_index) / float(_path_points.size() - 1)


func has_reached_end() -> bool:
    return _reached_end


func _on_path_updated() -> void:
    # Recompute path from current position
    var new_path := _grid.get_path_world()
    if new_path.is_empty():
        return
    # Find closest point in new path
    var closest_idx := 0
    var closest_dist := INF
    for i in range(new_path.size()):
        var dist := _current_position.distance_to(new_path[i])
        if dist < closest_dist:
            closest_dist = dist
            closest_idx = i
    _path_points = new_path
    _current_index = closest_idx
```

- [ ] **Step 6: Run tests to verify they pass**

- [ ] **Step 7: Commit**

```bash
git add core/pathfinding/grid_manager.gd core/pathfinding/grid_path_provider.gd
git add tests/test_grid_manager.gd tests/test_grid_path_provider.gd
git commit -m "feat: implement GridManager and GridPathProvider with A* pathfinding"
```

---

### Task 6: Implement Base Enemy Scene

**Files:**
- Create: `core/enemy_system/enemy.gd`
- Create: `core/enemy_system/enemy.tscn`
- Test: `tests/test_enemy.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_enemy.gd
extends GutTest

func _make_scout_definition() -> EnemyDefinition:
    var def := EnemyDefinition.new()
    def.id = "scout"
    def.display_name = "ENEMY_SCOUT"
    def.archetype = Enums.EnemyArchetype.SCOUT
    def.base_hp = 50.0
    def.speed = 200.0
    def.armor = 0.0
    def.shield = 0.0
    def.gold_value = 5
    def.shape_sides = 3
    def.shape_radius = 8.0
    def.color = Color.YELLOW
    return def

func test_enemy_initializes_from_definition():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.NORMAL)
    assert_eq(enemy.definition.id, "scout")
    assert_true(enemy.health.is_alive())
    enemy.queue_free()

func test_enemy_hp_scales_with_difficulty():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.HARD)
    # 50 * 1.8 = 90
    assert_eq(enemy.health.max_hp, 90.0)
    enemy.queue_free()

func test_enemy_speed_scales_with_difficulty():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.NIGHTMARE)
    # 200 * 1.3 = 260
    assert_eq(enemy.effective_speed, 260.0)
    enemy.queue_free()

func test_enemy_death_emits_signal():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.NORMAL)
    watch_signals(enemy)
    enemy.health.take_damage(100.0, Enums.DamageType.PULSE)
    assert_signal_emitted(enemy, "enemy_died")
    enemy.queue_free()

func test_enemy_gold_value():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.NORMAL)
    assert_eq(enemy.get_gold_value(), 5)
    enemy.queue_free()

func test_enemy_reached_exit_emits_signal():
    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(_make_scout_definition(), Enums.Difficulty.NORMAL)
    watch_signals(enemy)
    enemy.on_reached_exit()
    assert_signal_emitted(enemy, "enemy_reached_exit")
    enemy.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/enemy_system/enemy.gd
class_name Enemy
extends Node2D

signal enemy_died(enemy: Enemy)
signal enemy_reached_exit(enemy: Enemy)

var definition: EnemyDefinition
var health: EnemyHealth
var renderer: EnemyRenderer
var path_provider: PathProvider
var effective_speed: float = 0.0
var _difficulty: Enums.Difficulty
var _slowed: bool = false
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0


func initialize(def: EnemyDefinition, difficulty: Enums.Difficulty) -> void:
    definition = def
    _difficulty = difficulty

    # Scale stats by difficulty
    var hp := def.base_hp * Constants.DIFFICULTY_HP_MULT[difficulty]
    effective_speed = def.speed * Constants.DIFFICULTY_SPEED_MULT[difficulty]

    # Setup health
    health = EnemyHealth.new()
    add_child(health)
    health.initialize(hp, def.armor, def.shield)
    health.resistance_map = def.resistance_map.duplicate()
    health.died.connect(_on_died)
    health.health_changed.connect(_on_health_changed)

    # Setup renderer
    renderer = EnemyRenderer.new()
    add_child(renderer)
    renderer.setup(def)
    renderer.show_health_bar = def.is_boss


func _process(delta: float) -> void:
    # Handle slow effect
    if _slowed:
        _slow_timer -= delta
        if _slow_timer <= 0.0:
            _slowed = false
            _slow_factor = 1.0

    # Move along path
    if path_provider:
        var speed := effective_speed * _slow_factor
        path_provider.move(speed, delta)
        global_position = path_provider.get_current_position()

        if path_provider.has_reached_end():
            on_reached_exit()


func apply_slow(factor: float, duration: float) -> void:
    _slowed = true
    _slow_factor = factor
    _slow_timer = duration


func get_gold_value() -> int:
    return definition.gold_value


func on_reached_exit() -> void:
    enemy_reached_exit.emit(self)
    queue_free()


func _on_died() -> void:
    enemy_died.emit(self)
    # Death animation could go here
    queue_free()


func _on_health_changed(hp: float, max_hp: float, shield: float) -> void:
    if renderer:
        renderer.hp_percentage = hp / max_hp if max_hp > 0.0 else 0.0
        renderer.show_health_bar = true
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/enemy_system/enemy.gd tests/test_enemy.gd
git commit -m "feat: implement base Enemy with health, rendering, and pathfinding"
```

---

### Task 7: Create Enemy Definition Resources (.tres)

**Files:**
- Create: `content/enemies/scout.tres`
- Create: `content/enemies/drone.tres`
- Create: `content/enemies/tank.tres`
- Create: `content/enemies/flyer.tres`
- Create: `content/enemies/shielder.tres`
- Create: `content/enemies/healer.tres`

- [ ] **Step 1: Create all 6 enemy .tres files**

These are created in Godot Editor by creating new `EnemyDefinition` resources with the following values:

| Field | Scout | Drone | Tank | Flyer | Shielder | Healer |
|-------|-------|-------|------|-------|----------|--------|
| id | scout | drone | tank | flyer | shielder | healer |
| display_name | ENEMY_SCOUT | ENEMY_DRONE | ENEMY_TANK | ENEMY_FLYER | ENEMY_SHIELDER | ENEMY_HEALER |
| archetype | SCOUT | DRONE | TANK | FLYER | SHIELDER | HEALER |
| base_hp | 50 | 100 | 400 | 80 | 150 | 120 |
| speed | 200 | 150 | 80 | 160 | 120 | 100 |
| armor | 0 | 0 | 15 | 0 | 5 | 0 |
| shield | 0 | 0 | 0 | 0 | 50 | 0 |
| gold_value | 5 | 10 | 25 | 15 | 20 | 20 |
| shape_sides | 3 | 6 | 4 | 4 | 6 | 4 |
| shape_radius | 8 | 12 | 18 | 10 | 14 | 12 |
| color | Yellow | White | Red | Magenta | Blue | Green |
| is_flying | false | false | false | true | false | false |

- [ ] **Step 2: Verify resources load in test**

```gdscript
# Quick load verification (add to test_enemy_definition.gd)
func test_load_scout_resource():
    var scout := load("res://content/enemies/scout.tres") as EnemyDefinition
    assert_not_null(scout)
    assert_eq(scout.id, "scout")
    assert_eq(scout.archetype, Enums.EnemyArchetype.SCOUT)
```

- [ ] **Step 3: Commit**

```bash
git add content/enemies/
git commit -m "feat: create 6 enemy archetype definition resources"
```

---

### Task 8: Integration Test — Enemy on Path

**Files:**
- Test: `tests/test_integration_enemy_path.gd`

- [ ] **Step 1: Write integration test**

```gdscript
# tests/test_integration_enemy_path.gd
extends GutTest

func test_enemy_follows_fixed_path():
    # Setup path
    var path := Path2D.new()
    var curve := Curve2D.new()
    curve.add_point(Vector2(0, 0))
    curve.add_point(Vector2(500, 0))
    path.curve = curve
    add_child(path)

    var follow := PathFollow2D.new()
    follow.rotates = false
    follow.loop = false
    path.add_child(follow)

    # Setup enemy
    var scout_def := EnemyDefinition.new()
    scout_def.id = "scout"
    scout_def.base_hp = 50.0
    scout_def.speed = 200.0
    scout_def.shape_sides = 3
    scout_def.shape_radius = 8.0
    scout_def.color = Color.YELLOW

    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(scout_def, Enums.Difficulty.NORMAL)

    var provider := FixedPathProvider.new()
    provider.path_follow = follow
    enemy.add_child(provider)
    enemy.path_provider = provider

    # Simulate movement
    var initial_pos := enemy.global_position
    for i in range(10):
        enemy._process(0.1)

    assert_ne(enemy.global_position, initial_pos)

    # Cleanup
    enemy.queue_free()
    path.queue_free()

func test_enemy_follows_grid_path():
    var grid := GridManager.new()
    grid.initialize(Vector2i(5, 5), Vector2(64, 64))
    grid.set_entry_point(Vector2i(0, 2))
    grid.set_exit_point(Vector2i(4, 2))
    add_child(grid)

    var drone_def := EnemyDefinition.new()
    drone_def.id = "drone"
    drone_def.base_hp = 100.0
    drone_def.speed = 150.0
    drone_def.shape_sides = 6
    drone_def.shape_radius = 12.0
    drone_def.color = Color.WHITE

    var enemy := Enemy.new()
    add_child(enemy)
    enemy.initialize(drone_def, Enums.Difficulty.NORMAL)

    var provider := GridPathProvider.new()
    provider.setup(grid)
    enemy.add_child(provider)
    enemy.path_provider = provider

    # Simulate
    for i in range(10):
        enemy._process(0.1)

    assert_ne(enemy.global_position, Vector2.ZERO)

    enemy.queue_free()
    grid.queue_free()
```

- [ ] **Step 2: Run all tests**

Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_integration_enemy_path.gd
git commit -m "feat: add enemy-pathfinding integration tests"
```
