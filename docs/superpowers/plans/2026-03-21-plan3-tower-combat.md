# Plan 3: Tower System + Combat

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tower framework — base tower class, 7 tower types with geometric rendering, targeting system, projectile/shooting system, tiered evolution with branching, tower placement (both build-spot and grid), and selling.

**Architecture:** Towers are scenes built from `TowerDefinition` resources. The targeting system selects enemies based on mode (nearest/strongest/etc). The tier tree is stored as nested data in the resource. Towers draw themselves with `_draw()` like enemies. Projectiles are lightweight scenes that handle collision.

**Tech Stack:** Godot 4.x, GDScript, GUT

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Sections 4, 8

**Depends on:** Plan 1 (Foundation), Plan 2 (Enemy System — for targeting)

---

## File Structure

```
res://
├── core/
│   ├── tower_system/
│   │   ├── tower.gd                    # Base tower class (Node2D)
│   │   ├── tower.tscn                  # Base tower scene
│   │   ├── tower_definition.gd         # TowerDefinition Resource
│   │   ├── tower_renderer.gd           # Geometric shape drawing
│   │   ├── tower_targeting.gd          # Target selection logic
│   │   ├── tower_placer.gd             # Placement validation + ghost preview
│   │   └── projectile.gd              # Projectile base class
│   └── upgrade_system/
│       ├── tier_tree.gd                # Tier tree data structure
│       └── upgrade_manager.gd          # Handles tier upgrades + branching
├── content/
│   └── towers/
│       ├── pulse_cannon.tres
│       ├── arc_emitter.tres
│       ├── cryo_array.tres
│       ├── missile_pod.tres
│       ├── beam_spire.tres
│       ├── nano_hive.tres
│       └── harvester.tres
└── tests/
    ├── test_tower_definition.gd
    ├── test_tower_targeting.gd
    ├── test_tower.gd
    ├── test_projectile.gd
    ├── test_tier_tree.gd
    ├── test_tower_placer.gd
    └── test_integration_tower_combat.gd
```

---

### Task 1: Create TowerDefinition Resource

**Files:**
- Create: `core/tower_system/tower_definition.gd`
- Test: `tests/test_tower_definition.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_tower_definition.gd
extends GutTest

func test_create_tower_definition():
    var def := TowerDefinition.new()
    def.id = "pulse_cannon"
    def.display_name = "TOWER_PULSE_CANNON"
    def.tower_type = Enums.TowerType.PULSE_CANNON
    def.damage_type = Enums.DamageType.PULSE
    def.base_damage = 25.0
    def.base_fire_rate = 1.0
    def.base_range = 200.0
    def.cost = 100
    assert_eq(def.id, "pulse_cannon")
    assert_eq(def.cost, 100)

func test_tower_shape_and_color():
    var def := TowerDefinition.new()
    def.shape_sides = 8
    def.shape_radius = 16.0
    def.color = Color.CYAN
    assert_eq(def.shape_sides, 8)
    assert_eq(def.color, Color.CYAN)

func test_tier_tree_default_empty():
    var def := TowerDefinition.new()
    assert_eq(def.tier_branches.size(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/tower_system/tower_definition.gd
class_name TowerDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var damage_type: Enums.DamageType = Enums.DamageType.PULSE
@export var base_damage: float = 10.0
@export var base_fire_rate: float = 1.0
@export var base_range: float = 200.0
@export var cost: int = 100
@export var shape_sides: int = 8
@export var shape_radius: float = 16.0
@export var color: Color = Color.CYAN
@export var targeting_modes: Array[Enums.TargetingMode] = [
    Enums.TargetingMode.NEAREST,
    Enums.TargetingMode.STRONGEST,
    Enums.TargetingMode.WEAKEST,
    Enums.TargetingMode.FIRST,
    Enums.TargetingMode.LAST,
]
@export var is_support: bool = false
@export var is_income: bool = false
@export var projectile_speed: float = 400.0
@export var splash_radius: float = 0.0
@export var slow_factor: float = 0.0
@export var slow_duration: float = 0.0
@export var chain_count: int = 0
@export var chain_range: float = 0.0
@export var buff_range: float = 0.0
@export var buff_damage_mult: float = 0.0
@export var buff_fire_rate_mult: float = 0.0
@export var income_per_wave: int = 0
@export var skill_tree_id: String = ""

# Tier tree: Array of branches. Each branch is a Dictionary:
# { "name": String, "display_name": String, "damage_mult": float,
#   "fire_rate_mult": float, "range_mult": float, "cost": int,
#   "special": String, "branches": Array (next tier) }
@export var tier_branches: Array[Dictionary] = []
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/tower_system/tower_definition.gd tests/test_tower_definition.gd
git commit -m "feat: create TowerDefinition resource type"
```

---

### Task 2: Implement TowerTargeting

**Files:**
- Create: `core/tower_system/tower_targeting.gd`
- Test: `tests/test_tower_targeting.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_tower_targeting.gd
extends GutTest

var targeting: TowerTargeting

func before_each():
    targeting = TowerTargeting.new()
    add_child(targeting)

func after_each():
    targeting.queue_free()

func _make_mock_enemy(pos: Vector2, hp: float, progress: float) -> Dictionary:
    return {"position": pos, "hp": hp, "progress": progress, "alive": true}

func test_nearest_target():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(200, 100), 50.0, 0.5),
        _make_mock_enemy(Vector2(150, 100), 100.0, 0.3),
        _make_mock_enemy(Vector2(300, 100), 30.0, 0.8),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.NEAREST, enemies)
    assert_eq(result, 1)  # index of closest enemy

func test_strongest_target():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(200, 100), 50.0, 0.5),
        _make_mock_enemy(Vector2(150, 100), 100.0, 0.3),
        _make_mock_enemy(Vector2(180, 100), 30.0, 0.8),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.STRONGEST, enemies)
    assert_eq(result, 1)  # highest HP

func test_weakest_target():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(200, 100), 50.0, 0.5),
        _make_mock_enemy(Vector2(150, 100), 100.0, 0.3),
        _make_mock_enemy(Vector2(180, 100), 30.0, 0.8),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.WEAKEST, enemies)
    assert_eq(result, 2)  # lowest HP

func test_first_target():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(200, 100), 50.0, 0.5),
        _make_mock_enemy(Vector2(150, 100), 100.0, 0.8),
        _make_mock_enemy(Vector2(180, 100), 30.0, 0.3),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.FIRST, enemies)
    assert_eq(result, 1)  # highest progress

func test_last_target():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(200, 100), 50.0, 0.5),
        _make_mock_enemy(Vector2(150, 100), 100.0, 0.8),
        _make_mock_enemy(Vector2(180, 100), 30.0, 0.3),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.LAST, enemies)
    assert_eq(result, 2)  # lowest progress

func test_out_of_range_returns_negative():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        _make_mock_enemy(Vector2(500, 500), 50.0, 0.5),
    ]
    var result := targeting.select_target(tower_pos, 100.0, Enums.TargetingMode.NEAREST, enemies)
    assert_eq(result, -1)

func test_empty_enemies_returns_negative():
    var result := targeting.select_target(Vector2.ZERO, 100.0, Enums.TargetingMode.NEAREST, [])
    assert_eq(result, -1)

func test_dead_enemies_skipped():
    var tower_pos := Vector2(100, 100)
    var enemies := [
        {"position": Vector2(120, 100), "hp": 0.0, "progress": 0.5, "alive": false},
        _make_mock_enemy(Vector2(150, 100), 50.0, 0.3),
    ]
    var result := targeting.select_target(tower_pos, 250.0, Enums.TargetingMode.NEAREST, enemies)
    assert_eq(result, 1)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/tower_system/tower_targeting.gd
class_name TowerTargeting
extends Node

## Selects a target from a list of enemies based on targeting mode.
## Returns the index of the selected enemy, or -1 if none in range.


func select_target(tower_pos: Vector2, attack_range: float,
        mode: Enums.TargetingMode, enemies: Array) -> int:
    var best_index := -1
    var best_value := -INF if mode in [Enums.TargetingMode.STRONGEST, Enums.TargetingMode.FIRST] else INF

    for i in range(enemies.size()):
        var enemy: Dictionary = enemies[i]
        if not enemy.alive:
            continue
        var dist := tower_pos.distance_to(enemy.position)
        if dist > attack_range:
            continue

        var value: float
        match mode:
            Enums.TargetingMode.NEAREST:
                value = dist
                if value < best_value:
                    best_value = value
                    best_index = i
            Enums.TargetingMode.STRONGEST:
                value = enemy.hp
                if value > best_value:
                    best_value = value
                    best_index = i
            Enums.TargetingMode.WEAKEST:
                value = enemy.hp
                if value < best_value:
                    best_value = value
                    best_index = i
            Enums.TargetingMode.FIRST:
                value = enemy.progress
                if value > best_value:
                    best_value = value
                    best_index = i
            Enums.TargetingMode.LAST:
                value = enemy.progress
                if value < best_value:
                    best_value = value
                    best_index = i

    return best_index
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/tower_system/tower_targeting.gd tests/test_tower_targeting.gd
git commit -m "feat: implement tower targeting system with 5 modes"
```

---

### Task 3: Implement Projectile

**Files:**
- Create: `core/tower_system/projectile.gd`
- Test: `tests/test_projectile.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_projectile.gd
extends GutTest

func test_projectile_moves_toward_target():
    var proj := Projectile.new()
    add_child(proj)
    proj.global_position = Vector2(0, 0)
    proj.initialize(Vector2(100, 0), 500.0, 25.0, Enums.DamageType.PULSE, 0.0)
    proj._process(0.1)
    assert_gt(proj.global_position.x, 0.0)
    proj.queue_free()

func test_projectile_has_damage_info():
    var proj := Projectile.new()
    add_child(proj)
    proj.initialize(Vector2(100, 0), 500.0, 25.0, Enums.DamageType.PULSE, 0.0)
    assert_eq(proj.damage, 25.0)
    assert_eq(proj.damage_type, Enums.DamageType.PULSE)
    proj.queue_free()

func test_projectile_splash_radius():
    var proj := Projectile.new()
    add_child(proj)
    proj.initialize(Vector2(100, 0), 500.0, 25.0, Enums.DamageType.MISSILE, 50.0)
    assert_eq(proj.splash_radius, 50.0)
    proj.queue_free()

func test_projectile_expires_after_max_distance():
    var proj := Projectile.new()
    add_child(proj)
    proj.global_position = Vector2(0, 0)
    proj.initialize(Vector2(100, 0), 5000.0, 25.0, Enums.DamageType.PULSE, 0.0)
    # Move way past target
    for i in range(100):
        proj._process(0.1)
    assert_true(proj.is_queued_for_deletion() or proj._expired)
    proj.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/tower_system/projectile.gd
class_name Projectile
extends Node2D

signal hit_target(position: Vector2, damage: float, damage_type: Enums.DamageType, splash_radius: float)

var target_position: Vector2
var speed: float
var damage: float
var damage_type: Enums.DamageType
var splash_radius: float
var _expired: bool = false
var _distance_traveled: float = 0.0
var _max_distance: float = 2000.0
var _direction: Vector2

const HIT_THRESHOLD := 10.0
const PROJECTILE_RADIUS := 3.0
const PROJECTILE_COLOR := Color(1.0, 1.0, 1.0, 0.9)


func initialize(target_pos: Vector2, p_speed: float, p_damage: float,
        p_damage_type: Enums.DamageType, p_splash_radius: float) -> void:
    target_position = target_pos
    speed = p_speed
    damage = p_damage
    damage_type = p_damage_type
    splash_radius = p_splash_radius
    _direction = (target_pos - global_position).normalized()


func _process(delta: float) -> void:
    if _expired:
        return
    var move_dist := speed * delta
    global_position += _direction * move_dist
    _distance_traveled += move_dist

    # Check if reached target
    if global_position.distance_to(target_position) < HIT_THRESHOLD:
        _on_hit()
    elif _distance_traveled > _max_distance:
        _expired = true
        queue_free()


func _draw() -> void:
    draw_circle(Vector2.ZERO, PROJECTILE_RADIUS, PROJECTILE_COLOR)


func _on_hit() -> void:
    _expired = true
    hit_target.emit(global_position, damage, damage_type, splash_radius)
    queue_free()
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/tower_system/projectile.gd tests/test_projectile.gd
git commit -m "feat: implement Projectile with movement and hit detection"
```

---

### Task 4: Implement TowerRenderer

**Files:**
- Create: `core/tower_system/tower_renderer.gd`

- [ ] **Step 1: Write implementation**

```gdscript
# core/tower_system/tower_renderer.gd
class_name TowerRenderer
extends Node2D

## Draws geometric shapes for towers using _draw().

var shape_sides: int = 8
var shape_radius: float = 16.0
var base_color: Color = Color.CYAN
var tier: int = 1
var show_range: bool = false
var attack_range: float = 200.0

const RANGE_COLOR := Color(1.0, 1.0, 1.0, 0.1)
const RANGE_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.2)


func setup(definition: TowerDefinition) -> void:
    shape_sides = definition.shape_sides
    shape_radius = definition.shape_radius
    base_color = definition.color
    attack_range = definition.base_range


func _draw() -> void:
    # Range indicator
    if show_range:
        draw_circle(Vector2.ZERO, attack_range, RANGE_COLOR)
        draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, RANGE_OUTLINE_COLOR, 1.0)

    var radius := shape_radius + (tier - 1) * 2.0
    var points := _get_polygon_points(shape_sides, radius)

    # Base platform (slightly larger, darker)
    var platform_points := _get_polygon_points(shape_sides, radius + 4.0)
    draw_colored_polygon(platform_points, base_color.darkened(0.5))

    # Main shape
    draw_colored_polygon(points, base_color)

    # Outline (brighter at higher tiers)
    var outline_color := base_color.lightened(0.2 + tier * 0.1)
    for i in range(points.size()):
        var next := (i + 1) % points.size()
        draw_line(points[i], points[next], outline_color, 1.5 + tier * 0.5)

    # Tier indicator dots
    if tier > 1:
        for i in range(tier):
            var dot_x := (i - (tier - 1) / 2.0) * 6.0
            draw_circle(Vector2(dot_x, radius + 8.0), 2.0, outline_color)


func _get_polygon_points(sides: int, radius: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(sides):
        var angle := (TAU / sides) * i - PI / 2.0
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
```

- [ ] **Step 2: Verify visually in editor**

- [ ] **Step 3: Commit**

```bash
git add core/tower_system/tower_renderer.gd
git commit -m "feat: implement geometric TowerRenderer with tier visuals"
```

---

### Task 5: Implement TierTree and UpgradeManager

**Files:**
- Create: `core/upgrade_system/tier_tree.gd`
- Create: `core/upgrade_system/upgrade_manager.gd`
- Test: `tests/test_tier_tree.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_tier_tree.gd
extends GutTest

func _make_pulse_cannon_tree() -> Array[Dictionary]:
    return [
        {
            "name": "rapid_repeater", "display_name": "TOWER_RAPID_REPEATER",
            "damage_mult": 1.0, "fire_rate_mult": 1.5, "range_mult": 1.0,
            "cost": 150, "special": "",
            "branches": [
                {"name": "gatling_array", "display_name": "TOWER_GATLING_ARRAY",
                 "damage_mult": 0.6, "fire_rate_mult": 3.0, "range_mult": 1.0,
                 "cost": 300, "special": "", "branches": []},
                {"name": "tracer_rounds", "display_name": "TOWER_TRACER_ROUNDS",
                 "damage_mult": 1.0, "fire_rate_mult": 1.5, "range_mult": 1.0,
                 "cost": 300, "special": "pierce", "branches": []},
            ]
        },
        {
            "name": "heavy_pulse", "display_name": "TOWER_HEAVY_PULSE",
            "damage_mult": 2.0, "fire_rate_mult": 0.8, "range_mult": 1.0,
            "cost": 150, "special": "",
            "branches": [
                {"name": "siege_cannon", "display_name": "TOWER_SIEGE_CANNON",
                 "damage_mult": 4.0, "fire_rate_mult": 0.4, "range_mult": 1.2,
                 "cost": 300, "special": "", "branches": []},
                {"name": "plasma_launcher", "display_name": "TOWER_PLASMA_LAUNCHER",
                 "damage_mult": 2.5, "fire_rate_mult": 0.6, "range_mult": 1.0,
                 "cost": 300, "special": "splash", "branches": []},
            ]
        },
    ]

func test_tier_tree_get_options_at_tier_2():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    var options := tree.get_upgrade_options([])
    assert_eq(options.size(), 2)
    assert_eq(options[0].name, "rapid_repeater")
    assert_eq(options[1].name, "heavy_pulse")

func test_tier_tree_get_options_at_tier_3():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    var options := tree.get_upgrade_options([0])  # Chose rapid_repeater
    assert_eq(options.size(), 2)
    assert_eq(options[0].name, "gatling_array")
    assert_eq(options[1].name, "tracer_rounds")

func test_apply_upgrade_calculates_stats():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    var stats := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
    var upgraded := tree.apply_upgrades(stats, [0])  # rapid_repeater
    assert_eq(upgraded.damage, 25.0)    # 25 * 1.0
    assert_eq(upgraded.fire_rate, 1.5)  # 1.0 * 1.5
    assert_eq(upgraded.range, 200.0)    # 200 * 1.0

func test_apply_two_upgrades():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    var stats := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
    var upgraded := tree.apply_upgrades(stats, [0, 0])  # rapid -> gatling
    assert_almost_eq(upgraded.fire_rate, 4.5, 0.01)  # 1.0 * 1.5 * 3.0

func test_get_total_upgrade_cost():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    assert_eq(tree.get_total_cost([0, 0]), 450)  # 150 + 300

func test_no_options_at_max_tier():
    var tree := TierTree.new()
    tree.branches = _make_pulse_cannon_tree()
    var options := tree.get_upgrade_options([0, 0])  # Already at T3
    assert_eq(options.size(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/upgrade_system/tier_tree.gd
class_name TierTree
extends RefCounted

## Manages the tiered evolution branching tree for a tower.

var branches: Array[Dictionary] = []


func get_upgrade_options(chosen_path: Array) -> Array[Dictionary]:
    var current := branches
    for choice_idx in chosen_path:
        if choice_idx < 0 or choice_idx >= current.size():
            return []
        current = current[choice_idx].get("branches", [])
    return current


func apply_upgrades(base_stats: Dictionary, chosen_path: Array) -> Dictionary:
    var stats := base_stats.duplicate()
    var current := branches
    for choice_idx in chosen_path:
        if choice_idx < 0 or choice_idx >= current.size():
            break
        var branch: Dictionary = current[choice_idx]
        stats.damage *= branch.get("damage_mult", 1.0)
        stats.fire_rate *= branch.get("fire_rate_mult", 1.0)
        stats.range *= branch.get("range_mult", 1.0)
        current = branch.get("branches", [])
    return stats


func get_total_cost(chosen_path: Array) -> int:
    var total := 0
    var current := branches
    for choice_idx in chosen_path:
        if choice_idx < 0 or choice_idx >= current.size():
            break
        total += current[choice_idx].get("cost", 0)
        current = current[choice_idx].get("branches", [])
    return total


func get_next_upgrade_cost(chosen_path: Array, choice: int) -> int:
    var options := get_upgrade_options(chosen_path)
    if choice < 0 or choice >= options.size():
        return -1
    return options[choice].get("cost", 0)


func get_current_tier(chosen_path: Array) -> int:
    return chosen_path.size() + 1
```

```gdscript
# core/upgrade_system/upgrade_manager.gd
class_name UpgradeManager
extends Node

## Manages tower upgrades within a match. Coordinates with EconomyManager.

signal tower_upgraded(tower: Node, new_tier: int)

func try_upgrade(tower: Node, choice: int, economy: EconomyManager) -> bool:
    if not tower.has_method("get_tier_tree") or not tower.has_method("get_upgrade_path"):
        return false

    var tree: TierTree = tower.get_tier_tree()
    var path: Array = tower.get_upgrade_path()
    var cost := tree.get_next_upgrade_cost(path, choice)

    if cost < 0:
        return false
    if not economy.spend_gold(cost):
        return false

    tower.apply_upgrade(choice)
    tower_upgraded.emit(tower, tree.get_current_tier(tower.get_upgrade_path()))
    return true
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/upgrade_system/tier_tree.gd core/upgrade_system/upgrade_manager.gd tests/test_tier_tree.gd
git commit -m "feat: implement TierTree and UpgradeManager for tower evolution"
```

---

### Task 6: Implement TowerPlacer

**Files:**
- Create: `core/tower_system/tower_placer.gd`
- Test: `tests/test_tower_placer.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_tower_placer.gd
extends GutTest

func test_build_spot_placement_valid():
    var placer := TowerPlacer.new()
    var build_spots := [Vector2(100, 100), Vector2(200, 200), Vector2(300, 300)]
    placer.set_build_spots(build_spots)
    var result := placer.get_nearest_build_spot(Vector2(105, 95))
    assert_almost_eq(result.x, 100.0, 1.0)
    assert_almost_eq(result.y, 100.0, 1.0)

func test_build_spot_too_far():
    var placer := TowerPlacer.new()
    var build_spots := [Vector2(100, 100)]
    placer.set_build_spots(build_spots)
    var result := placer.get_nearest_build_spot(Vector2(500, 500))
    assert_eq(result, Vector2(-1, -1))

func test_build_spot_already_occupied():
    var placer := TowerPlacer.new()
    var build_spots := [Vector2(100, 100)]
    placer.set_build_spots(build_spots)
    placer.mark_occupied(Vector2(100, 100))
    var result := placer.get_nearest_build_spot(Vector2(105, 95))
    assert_eq(result, Vector2(-1, -1))

func test_sell_frees_spot():
    var placer := TowerPlacer.new()
    var build_spots := [Vector2(100, 100)]
    placer.set_build_spots(build_spots)
    placer.mark_occupied(Vector2(100, 100))
    placer.mark_free(Vector2(100, 100))
    var result := placer.get_nearest_build_spot(Vector2(105, 95))
    assert_almost_eq(result.x, 100.0, 1.0)

func test_calculate_sell_value():
    var placer := TowerPlacer.new()
    # Tower cost 100, upgraded 150 = total 250, refund 70% = 175
    assert_eq(placer.calculate_sell_value(250, 0), 175)

func test_calculate_sell_value_with_upgrade_tiers():
    var placer := TowerPlacer.new()
    # With 5 global refund upgrade tiers: 70% + 5*2% = 80%
    # 250 * 0.8 = 200
    assert_eq(placer.calculate_sell_value(250, 5), 200)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/tower_system/tower_placer.gd
class_name TowerPlacer
extends Node

const SNAP_DISTANCE := 40.0
const INVALID_SPOT := Vector2(-1, -1)

var _build_spots: Array[Vector2] = []
var _occupied_spots: Dictionary = {}  # Vector2 -> bool


func set_build_spots(spots: Array) -> void:
    _build_spots.clear()
    for spot in spots:
        _build_spots.append(spot as Vector2)


func get_nearest_build_spot(world_pos: Vector2) -> Vector2:
    var best_spot := INVALID_SPOT
    var best_dist := SNAP_DISTANCE
    for spot in _build_spots:
        if spot in _occupied_spots:
            continue
        var dist := world_pos.distance_to(spot)
        if dist < best_dist:
            best_dist = dist
            best_spot = spot
    return best_spot


func mark_occupied(spot: Vector2) -> void:
    _occupied_spots[spot] = true


func mark_free(spot: Vector2) -> void:
    _occupied_spots.erase(spot)


func is_occupied(spot: Vector2) -> bool:
    return spot in _occupied_spots


func calculate_sell_value(total_investment: int, refund_upgrade_tier: int) -> int:
    var refund_rate := Constants.BASE_SELL_REFUND + refund_upgrade_tier * Constants.SELL_REFUND_PER_UPGRADE_TIER
    return int(total_investment * refund_rate)
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/tower_system/tower_placer.gd tests/test_tower_placer.gd
git commit -m "feat: implement TowerPlacer with build spots and sell calculation"
```

---

### Task 7: Implement Base Tower

**Files:**
- Create: `core/tower_system/tower.gd`
- Test: `tests/test_tower.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_tower.gd
extends GutTest

func _make_pulse_def() -> TowerDefinition:
    var def := TowerDefinition.new()
    def.id = "pulse_cannon"
    def.display_name = "TOWER_PULSE_CANNON"
    def.tower_type = Enums.TowerType.PULSE_CANNON
    def.damage_type = Enums.DamageType.PULSE
    def.base_damage = 25.0
    def.base_fire_rate = 1.0
    def.base_range = 200.0
    def.cost = 100
    def.shape_sides = 8
    def.shape_radius = 16.0
    def.color = Color.CYAN
    def.projectile_speed = 400.0
    def.tier_branches = [
        {"name": "t2a", "damage_mult": 1.0, "fire_rate_mult": 1.5,
         "range_mult": 1.0, "cost": 150, "branches": []},
        {"name": "t2b", "damage_mult": 2.0, "fire_rate_mult": 0.8,
         "range_mult": 1.0, "cost": 150, "branches": []},
    ]
    return def

func test_tower_initializes():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    assert_eq(tower.definition.id, "pulse_cannon")
    assert_eq(tower.current_damage, 25.0)
    assert_eq(tower.current_fire_rate, 1.0)
    assert_eq(tower.current_range, 200.0)
    tower.queue_free()

func test_tower_total_investment():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    assert_eq(tower.get_total_investment(), 100)
    tower.queue_free()

func test_tower_apply_upgrade():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    tower.apply_upgrade(0)  # t2a: fire_rate * 1.5
    assert_eq(tower.current_tier, 2)
    assert_almost_eq(tower.current_fire_rate, 1.5, 0.01)
    assert_eq(tower.get_total_investment(), 250)  # 100 + 150
    tower.queue_free()

func test_tower_get_tier_tree():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    var tree := tower.get_tier_tree()
    assert_not_null(tree)
    tower.queue_free()

func test_tower_get_upgrade_path():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    assert_eq(tower.get_upgrade_path().size(), 0)
    tower.apply_upgrade(1)
    assert_eq(tower.get_upgrade_path().size(), 1)
    assert_eq(tower.get_upgrade_path()[0], 1)
    tower.queue_free()

func test_tower_targeting_mode():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    assert_eq(tower.targeting_mode, Enums.TargetingMode.NEAREST)
    tower.set_targeting_mode(Enums.TargetingMode.STRONGEST)
    assert_eq(tower.targeting_mode, Enums.TargetingMode.STRONGEST)
    tower.queue_free()

func test_tower_fire_cooldown():
    var tower := Tower.new()
    add_child(tower)
    tower.initialize(_make_pulse_def())
    assert_true(tower.can_fire())
    tower.on_fired()
    assert_false(tower.can_fire())
    tower.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/tower_system/tower.gd
class_name Tower
extends Node2D

signal fired(target_position: Vector2, damage: float, damage_type: Enums.DamageType)
signal sold(tower: Tower, refund: int)

var definition: TowerDefinition
var renderer: TowerRenderer
var targeting: TowerTargeting
var targeting_mode: Enums.TargetingMode = Enums.TargetingMode.NEAREST

var current_damage: float = 0.0
var current_fire_rate: float = 0.0
var current_range: float = 0.0
var current_tier: int = 1

var _tier_tree: TierTree
var _upgrade_path: Array = []
var _fire_cooldown: float = 0.0
var _total_investment: int = 0
var _buff_damage_mult: float = 1.0
var _buff_fire_rate_mult: float = 1.0


func initialize(def: TowerDefinition) -> void:
    definition = def
    _total_investment = def.cost

    current_damage = def.base_damage
    current_fire_rate = def.base_fire_rate
    current_range = def.base_range

    _tier_tree = TierTree.new()
    _tier_tree.branches = def.tier_branches

    targeting = TowerTargeting.new()
    add_child(targeting)

    renderer = TowerRenderer.new()
    renderer.setup(def)
    add_child(renderer)


func _process(delta: float) -> void:
    if _fire_cooldown > 0.0:
        _fire_cooldown -= delta


func can_fire() -> bool:
    return _fire_cooldown <= 0.0


func on_fired() -> void:
    _fire_cooldown = 1.0 / (current_fire_rate * _buff_fire_rate_mult)


func get_effective_damage() -> float:
    return current_damage * _buff_damage_mult


func apply_upgrade(choice: int) -> void:
    _upgrade_path.append(choice)
    current_tier = _tier_tree.get_current_tier(_upgrade_path)
    var cost := _tier_tree.get_next_upgrade_cost(
        _upgrade_path.slice(0, _upgrade_path.size() - 1), choice)
    _total_investment += cost

    var base_stats := {
        "damage": definition.base_damage,
        "fire_rate": definition.base_fire_rate,
        "range": definition.base_range,
    }
    var upgraded := _tier_tree.apply_upgrades(base_stats, _upgrade_path)
    current_damage = upgraded.damage
    current_fire_rate = upgraded.fire_rate
    current_range = upgraded.range

    if renderer:
        renderer.tier = current_tier
        renderer.attack_range = current_range
        renderer.queue_redraw()


func set_targeting_mode(mode: Enums.TargetingMode) -> void:
    targeting_mode = mode


func get_tier_tree() -> TierTree:
    return _tier_tree


func get_upgrade_path() -> Array:
    return _upgrade_path


func get_total_investment() -> int:
    return _total_investment


func apply_buff(damage_mult: float, fire_rate_mult: float) -> void:
    _buff_damage_mult = damage_mult
    _buff_fire_rate_mult = fire_rate_mult


func clear_buff() -> void:
    _buff_damage_mult = 1.0
    _buff_fire_rate_mult = 1.0
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/tower_system/tower.gd tests/test_tower.gd
git commit -m "feat: implement base Tower with upgrades, targeting, and combat"
```

---

### Task 8: Create Tower Definition Resources (.tres)

**Files:**
- Create: 7 tower .tres files in `content/towers/`

- [ ] **Step 1: Create tower definitions**

Create in Godot Editor as `TowerDefinition` resources:

| Field | Pulse | Arc | Cryo | Missile | Beam | Nano | Harvester |
|-------|-------|-----|------|---------|------|------|-----------|
| id | pulse_cannon | arc_emitter | cryo_array | missile_pod | beam_spire | nano_hive | harvester |
| damage_type | PULSE | ARC | CRYO | MISSILE | BEAM | NANO | HARVEST |
| base_damage | 25 | 15 | 8 | 60 | 80 | 0 | 0 |
| base_fire_rate | 1.0 | 0.8 | 1.2 | 0.3 | 0.2 | 0 | 0 |
| base_range | 200 | 180 | 160 | 250 | 350 | 150 | 100 |
| cost | 100 | 120 | 90 | 180 | 250 | 150 | 200 |
| shape_sides | 8 | 3 | 4 | 4 | 6 | 8 | 5 |
| shape_radius | 16 | 14 | 14 | 16 | 18 | 16 | 14 |
| color | Cyan | #4488FF | #EEEEFF | Orange | Purple | Green | Gold |
| splash_radius | 0 | 0 | 0 | 60 | 0 | 0 | 0 |
| slow_factor | 0 | 0 | 0.5 | 0 | 0 | 0 | 0 |
| slow_duration | 0 | 0 | 2.0 | 0 | 0 | 0 | 0 |
| chain_count | 0 | 3 | 0 | 0 | 0 | 0 | 0 |
| is_support | false | false | false | false | false | true | false |
| is_income | false | false | false | false | false | false | true |
| income_per_wave | 0 | 0 | 0 | 0 | 0 | 0 | 50 |

- [ ] **Step 2: Commit**

```bash
git add content/towers/
git commit -m "feat: create 7 tower definition resources"
```

---

### Task 9: Integration Test — Tower Shoots Enemy

**Files:**
- Test: `tests/test_integration_tower_combat.gd`

- [ ] **Step 1: Write integration test**

```gdscript
# tests/test_integration_tower_combat.gd
extends GutTest

func test_tower_targets_nearest_enemy():
    var tower := Tower.new()
    add_child(tower)
    var def := TowerDefinition.new()
    def.id = "pulse_cannon"
    def.base_damage = 25.0
    def.base_fire_rate = 1.0
    def.base_range = 200.0
    def.projectile_speed = 400.0
    def.damage_type = Enums.DamageType.PULSE
    def.shape_sides = 8
    def.shape_radius = 16.0
    def.color = Color.CYAN
    tower.initialize(def)
    tower.global_position = Vector2(100, 100)

    # Mock enemies
    var enemies := [
        {"position": Vector2(200, 100), "hp": 50.0, "progress": 0.5, "alive": true},
        {"position": Vector2(150, 100), "hp": 100.0, "progress": 0.3, "alive": true},
    ]

    var target_idx := tower.targeting.select_target(
        tower.global_position, tower.current_range,
        tower.targeting_mode, enemies)
    assert_eq(target_idx, 1)  # Nearest

    tower.queue_free()

func test_tower_upgrade_increases_stats():
    var tower := Tower.new()
    add_child(tower)
    var def := TowerDefinition.new()
    def.id = "pulse_cannon"
    def.base_damage = 25.0
    def.base_fire_rate = 1.0
    def.base_range = 200.0
    def.cost = 100
    def.shape_sides = 8
    def.shape_radius = 16.0
    def.color = Color.CYAN
    def.tier_branches = [
        {"name": "t2a", "damage_mult": 1.0, "fire_rate_mult": 2.0,
         "range_mult": 1.0, "cost": 150, "branches": [
            {"name": "t3a", "damage_mult": 0.6, "fire_rate_mult": 3.0,
             "range_mult": 1.0, "cost": 300, "branches": []},
         ]},
    ]
    tower.initialize(def)

    # T1 -> T2
    tower.apply_upgrade(0)
    assert_almost_eq(tower.current_fire_rate, 2.0, 0.01)
    assert_eq(tower.current_tier, 2)

    # T2 -> T3
    tower.apply_upgrade(0)
    assert_almost_eq(tower.current_fire_rate, 6.0, 0.01)
    assert_eq(tower.current_tier, 3)
    assert_eq(tower.get_total_investment(), 550)  # 100+150+300

    tower.queue_free()
```

- [ ] **Step 2: Run all tests**

Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_integration_tower_combat.gd
git commit -m "feat: add tower combat integration tests"
```
