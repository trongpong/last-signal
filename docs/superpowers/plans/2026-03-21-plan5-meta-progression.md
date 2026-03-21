# Plan 5: Meta-Progression + Abilities + Heroes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the diamond-funded meta-progression systems — tower skill trees, global upgrades (10 tiers), active abilities with cooldowns, hero summoning, and ability/hero upgrade paths.

**Architecture:** Skill trees and global upgrades are data-driven Resources. `ProgressionManager` coordinates unlocks with `SaveManager` and `EconomyManager`. Abilities are self-contained nodes with cooldown logic. Heroes are temporary scene instances with autonomous AI.

**Tech Stack:** Godot 4.x, GDScript, GUT

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Sections 10, 11

**Depends on:** Plan 1 (Foundation), Plan 3 (Towers)

---

## File Structure

```
res://
├── core/
│   ├── ability_system/
│   │   ├── ability.gd                  # Base ability with cooldown
│   │   ├── ability_definition.gd       # AbilityDefinition Resource
│   │   ├── ability_manager.gd          # 3-slot ability loadout management
│   │   ├── hero.gd                     # Base hero unit (temporary)
│   │   └── hero_definition.gd          # HeroDefinition Resource
│   └── progression/
│       ├── progression_manager.gd      # Coordinates all meta-progression
│       ├── skill_tree.gd               # Per-tower skill tree data
│       ├── skill_node.gd               # Individual skill node Resource
│       └── global_upgrade.gd           # Global upgrade definitions
├── content/
│   ├── skills/
│   │   └── (per-tower skill tree .tres files)
│   └── abilities/
│       └── (ability definition .tres files)
└── tests/
    ├── test_ability.gd
    ├── test_ability_manager.gd
    ├── test_hero.gd
    ├── test_progression_manager.gd
    ├── test_skill_tree.gd
    └── test_global_upgrade.gd
```

---

### Task 1: Implement SkillTree and SkillNode

**Files:**
- Create: `core/progression/skill_node.gd`
- Create: `core/progression/skill_tree.gd`
- Test: `tests/test_skill_tree.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_skill_tree.gd
extends GutTest

func _make_test_skill_tree() -> SkillTree:
    var tree := SkillTree.new()
    tree.tower_type = Enums.TowerType.PULSE_CANNON
    tree.nodes = []
    for i in range(10):
        var node := SkillNode.new()
        node.id = "node_%d" % i
        node.cost = Constants.SKILL_NODE_COSTS[i]
        node.node_index = i
        node.prerequisite_index = i - 1 if i > 0 else -1
        tree.nodes.append(node)
    tree.nodes[9].is_hero_unlock = true
    return tree

func test_skill_tree_has_10_nodes():
    var tree := _make_test_skill_tree()
    assert_eq(tree.nodes.size(), 10)

func test_first_node_unlockable():
    var tree := _make_test_skill_tree()
    assert_true(tree.can_unlock_node(0, []))

func test_second_node_requires_first():
    var tree := _make_test_skill_tree()
    assert_false(tree.can_unlock_node(1, []))
    assert_true(tree.can_unlock_node(1, [0]))

func test_get_node_cost():
    var tree := _make_test_skill_tree()
    assert_eq(tree.get_node_cost(0), 80)
    assert_eq(tree.get_node_cost(9), 1200)

func test_total_cost():
    var tree := _make_test_skill_tree()
    var total := tree.get_total_cost()
    assert_eq(total, 4100)

func test_hero_node_is_last():
    var tree := _make_test_skill_tree()
    assert_true(tree.nodes[9].is_hero_unlock)

func test_get_unlockable_nodes():
    var tree := _make_test_skill_tree()
    var unlockable := tree.get_unlockable_nodes([0, 1])
    assert_eq(unlockable.size(), 1)
    assert_eq(unlockable[0], 2)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/progression/skill_node.gd
class_name SkillNode
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var node_index: int = 0
@export var cost: int = 0
@export var prerequisite_index: int = -1
@export var is_hero_unlock: bool = false

# Stat bonuses (multiplicative)
@export var damage_bonus: float = 0.0
@export var fire_rate_bonus: float = 0.0
@export var range_bonus: float = 0.0
@export var special: String = ""
```

```gdscript
# core/progression/skill_tree.gd
class_name SkillTree
extends Resource

@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var nodes: Array[SkillNode] = []


func can_unlock_node(node_index: int, unlocked: Array) -> bool:
    if node_index < 0 or node_index >= nodes.size():
        return false
    if node_index in unlocked:
        return false
    var prereq := nodes[node_index].prerequisite_index
    if prereq >= 0 and prereq not in unlocked:
        return false
    return true


func get_node_cost(node_index: int) -> int:
    if node_index < 0 or node_index >= nodes.size():
        return -1
    return nodes[node_index].cost


func get_total_cost() -> int:
    var total := 0
    for node in nodes:
        total += node.cost
    return total


func get_unlockable_nodes(unlocked: Array) -> Array[int]:
    var result: Array[int] = []
    for i in range(nodes.size()):
        if can_unlock_node(i, unlocked):
            result.append(i)
    return result


func get_stat_bonuses(unlocked: Array) -> Dictionary:
    var bonuses := {"damage": 0.0, "fire_rate": 0.0, "range": 0.0}
    for idx in unlocked:
        if idx >= 0 and idx < nodes.size():
            bonuses.damage += nodes[idx].damage_bonus
            bonuses.fire_rate += nodes[idx].fire_rate_bonus
            bonuses.range += nodes[idx].range_bonus
    return bonuses
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/progression/skill_node.gd core/progression/skill_tree.gd tests/test_skill_tree.gd
git commit -m "feat: implement SkillTree and SkillNode for tower meta-progression"
```

---

### Task 2: Implement GlobalUpgrade System

**Files:**
- Create: `core/progression/global_upgrade.gd`
- Test: `tests/test_global_upgrade.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_global_upgrade.gd
extends GutTest

func test_global_upgrade_cost_at_tier():
    var upgrade := GlobalUpgrade.new()
    upgrade.id = "starting_gold"
    assert_eq(upgrade.get_cost_for_tier(0), 50)
    assert_eq(upgrade.get_cost_for_tier(9), 1400)

func test_global_upgrade_value_at_tier():
    var upgrade := GlobalUpgrade.new()
    upgrade.id = "starting_gold"
    upgrade.value_per_tier = 25.0
    assert_eq(upgrade.get_value_at_tier(5), 125.0)

func test_global_upgrade_max_tier():
    var upgrade := GlobalUpgrade.new()
    assert_eq(upgrade.max_tier, 10)

func test_global_upgrade_is_maxed():
    var upgrade := GlobalUpgrade.new()
    assert_false(upgrade.is_maxed(5))
    assert_true(upgrade.is_maxed(10))

func test_total_cost_to_max():
    var upgrade := GlobalUpgrade.new()
    assert_eq(upgrade.get_total_cost_to_max(), 4485)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/progression/global_upgrade.gd
class_name GlobalUpgrade
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var value_per_tier: float = 0.0
@export var max_tier: int = 10


func get_cost_for_tier(tier: int) -> int:
    if tier < 0 or tier >= Constants.GLOBAL_UPGRADE_COSTS.size():
        return -1
    return Constants.GLOBAL_UPGRADE_COSTS[tier]


func get_value_at_tier(tier: int) -> float:
    return value_per_tier * tier


func is_maxed(current_tier: int) -> bool:
    return current_tier >= max_tier


func get_total_cost_to_max() -> int:
    var total := 0
    for cost in Constants.GLOBAL_UPGRADE_COSTS:
        total += cost
    return total
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/progression/global_upgrade.gd tests/test_global_upgrade.gd
git commit -m "feat: implement GlobalUpgrade with 10-tier exponential cost"
```

---

### Task 3: Implement ProgressionManager

**Files:**
- Create: `core/progression/progression_manager.gd`
- Test: `tests/test_progression_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_progression_manager.gd
extends GutTest

var pm: ProgressionManager
var em: EconomyManager
var sm: SaveManager

func before_each():
    em = EconomyManager.new()
    sm = SaveManager.new()
    sm.save_path = "user://test_progression_save.json"
    pm = ProgressionManager.new()
    add_child(em)
    add_child(sm)
    add_child(pm)
    pm.setup(em, sm)

func after_each():
    pm.queue_free()
    sm.queue_free()
    em.queue_free()
    if FileAccess.file_exists("user://test_progression_save.json"):
        DirAccess.remove_absolute("user://test_progression_save.json")

func test_unlock_skill_node_success():
    em.add_diamonds(500)
    var result := pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
    assert_true(result)
    assert_eq(em.diamonds, 420)  # 500 - 80

func test_unlock_skill_node_insufficient_diamonds():
    em.add_diamonds(10)
    var result := pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
    assert_false(result)

func test_unlock_skill_node_prerequisite_not_met():
    em.add_diamonds(500)
    var result := pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 1)
    assert_false(result)

func test_upgrade_global():
    em.add_diamonds(500)
    var result := pm.upgrade_global("starting_gold")
    assert_true(result)
    assert_eq(pm.get_global_upgrade_tier("starting_gold"), 1)

func test_upgrade_global_tracks_tier():
    em.add_diamonds(5000)
    pm.upgrade_global("starting_gold")
    pm.upgrade_global("starting_gold")
    assert_eq(pm.get_global_upgrade_tier("starting_gold"), 2)

func test_get_starting_gold_bonus():
    em.add_diamonds(5000)
    pm.upgrade_global("starting_gold")
    pm.upgrade_global("starting_gold")
    # 2 tiers * 25g = 50g bonus
    assert_eq(pm.get_starting_gold_bonus(), 50)

func test_get_extra_lives():
    em.add_diamonds(5000)
    pm.upgrade_global("extra_lives")
    pm.upgrade_global("extra_lives")
    pm.upgrade_global("extra_lives")
    assert_eq(pm.get_extra_lives(), 3)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/progression/progression_manager.gd
class_name ProgressionManager
extends Node

signal skill_unlocked(tower_type: Enums.TowerType, node_index: int)
signal global_upgraded(upgrade_id: String, new_tier: int)
signal hero_unlocked(tower_type: Enums.TowerType)

var _em: EconomyManager
var _sm: SaveManager
var _skill_trees: Dictionary = {}      # TowerType -> SkillTree
var _unlocked_nodes: Dictionary = {}   # TowerType -> Array[int]
var _global_tiers: Dictionary = {}     # upgrade_id -> int

const GLOBAL_UPGRADES := {
    "starting_gold": 25.0,
    "tower_cost_reduction": 1.0,
    "extra_lives": 1.0,
    "ability_cooldown": 2.0,
    "adaptation_slowdown": 2.0,
    "gold_per_kill": 3.0,
    "tower_sell_refund": 2.0,
    "hero_duration": 1.0,
}


func setup(em: EconomyManager, sm: SaveManager) -> void:
    _em = em
    _sm = sm
    _load_from_save()


func unlock_skill_node(tower_type: Enums.TowerType, node_index: int) -> bool:
    var tree := _get_skill_tree(tower_type)
    if not tree:
        return false
    var unlocked := _unlocked_nodes.get(tower_type, [])
    if not tree.can_unlock_node(node_index, unlocked):
        return false
    var cost := tree.get_node_cost(node_index)
    if not _em.spend_diamonds(cost):
        return false
    unlocked.append(node_index)
    _unlocked_nodes[tower_type] = unlocked
    skill_unlocked.emit(tower_type, node_index)
    if tree.nodes[node_index].is_hero_unlock:
        hero_unlocked.emit(tower_type)
    _save_to_save()
    return true


func upgrade_global(upgrade_id: String) -> bool:
    var current_tier := _global_tiers.get(upgrade_id, 0)
    if current_tier >= 10:
        return false
    var cost := Constants.GLOBAL_UPGRADE_COSTS[current_tier]
    if not _em.spend_diamonds(cost):
        return false
    _global_tiers[upgrade_id] = current_tier + 1
    global_upgraded.emit(upgrade_id, current_tier + 1)
    _save_to_save()
    return true


func get_global_upgrade_tier(upgrade_id: String) -> int:
    return _global_tiers.get(upgrade_id, 0)


func get_starting_gold_bonus() -> int:
    return int(get_global_upgrade_tier("starting_gold") * GLOBAL_UPGRADES["starting_gold"])


func get_extra_lives() -> int:
    return int(get_global_upgrade_tier("extra_lives") * GLOBAL_UPGRADES["extra_lives"])


func get_tower_cost_discount() -> float:
    return get_global_upgrade_tier("tower_cost_reduction") * GLOBAL_UPGRADES["tower_cost_reduction"] / 100.0


func get_ability_cooldown_reduction() -> float:
    return get_global_upgrade_tier("ability_cooldown") * GLOBAL_UPGRADES["ability_cooldown"] / 100.0


func get_sell_refund_bonus() -> float:
    return get_global_upgrade_tier("tower_sell_refund") * GLOBAL_UPGRADES["tower_sell_refund"] / 100.0


func get_hero_duration_bonus() -> float:
    return get_global_upgrade_tier("hero_duration") * GLOBAL_UPGRADES["hero_duration"]


func get_gold_per_kill_bonus() -> float:
    return get_global_upgrade_tier("gold_per_kill") * GLOBAL_UPGRADES["gold_per_kill"] / 100.0


func get_skill_bonuses(tower_type: Enums.TowerType) -> Dictionary:
    var tree := _get_skill_tree(tower_type)
    if not tree:
        return {"damage": 0.0, "fire_rate": 0.0, "range": 0.0}
    return tree.get_stat_bonuses(_unlocked_nodes.get(tower_type, []))


func is_hero_unlocked(tower_type: Enums.TowerType) -> bool:
    var unlocked := _unlocked_nodes.get(tower_type, [])
    var tree := _get_skill_tree(tower_type)
    if not tree or tree.nodes.is_empty():
        return false
    return tree.nodes.size() - 1 in unlocked


func _get_skill_tree(tower_type: Enums.TowerType) -> SkillTree:
    if tower_type in _skill_trees:
        return _skill_trees[tower_type]
    # Build default skill tree
    var tree := SkillTree.new()
    tree.tower_type = tower_type
    for i in range(10):
        var node := SkillNode.new()
        node.id = "node_%d" % i
        node.cost = Constants.SKILL_NODE_COSTS[i]
        node.node_index = i
        node.prerequisite_index = i - 1 if i > 0 else -1
        node.is_hero_unlock = (i == 9)
        node.damage_bonus = [0.05, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.10, 0.0][i]
        node.fire_rate_bonus = [0.0, 0.05, 0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.10, 0.0][i]
        node.range_bonus = [0.0, 0.0, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.10, 0.0][i]
        tree.nodes.append(node)
    _skill_trees[tower_type] = tree
    return tree


func _load_from_save() -> void:
    _global_tiers = _sm.data.progression.global_upgrades.duplicate()
    for tower_key in _sm.data.progression.skill_trees:
        var tower_type: Enums.TowerType = int(tower_key)
        _unlocked_nodes[tower_type] = _sm.data.progression.skill_trees[tower_key].unlocked_nodes.duplicate()


func _save_to_save() -> void:
    _sm.data.progression.global_upgrades = _global_tiers.duplicate()
    for tower_type in _unlocked_nodes:
        var key := str(int(tower_type))
        _sm.data.progression.skill_trees[key] = {
            "unlocked_nodes": _unlocked_nodes[tower_type].duplicate()
        }
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/progression/progression_manager.gd tests/test_progression_manager.gd
git commit -m "feat: implement ProgressionManager with skill trees and global upgrades"
```

---

### Task 4: Implement Ability System

**Files:**
- Create: `core/ability_system/ability_definition.gd`
- Create: `core/ability_system/ability.gd`
- Create: `core/ability_system/ability_manager.gd`
- Test: `tests/test_ability.gd`
- Test: `tests/test_ability_manager.gd`

- [ ] **Step 1: Write the tests**

```gdscript
# tests/test_ability.gd
extends GutTest

func test_ability_starts_ready():
    var ability := Ability.new()
    add_child(ability)
    ability.initialize("orbital_strike", 60.0)
    assert_true(ability.is_ready())
    ability.queue_free()

func test_ability_goes_on_cooldown():
    var ability := Ability.new()
    add_child(ability)
    ability.initialize("orbital_strike", 60.0)
    ability.activate()
    assert_false(ability.is_ready())
    ability.queue_free()

func test_ability_cooldown_ticks():
    var ability := Ability.new()
    add_child(ability)
    ability.initialize("orbital_strike", 1.0)
    ability.activate()
    ability._process(1.1)
    assert_true(ability.is_ready())
    ability.queue_free()

func test_ability_cooldown_reduction():
    var ability := Ability.new()
    add_child(ability)
    ability.initialize("orbital_strike", 60.0)
    ability.cooldown_reduction = 0.2
    ability.activate()
    assert_almost_eq(ability._cooldown_remaining, 48.0, 0.1)
    ability.queue_free()
```

```gdscript
# tests/test_ability_manager.gd
extends GutTest

var am: AbilityManager

func before_each():
    am = AbilityManager.new()
    add_child(am)

func after_each():
    am.queue_free()

func test_set_loadout():
    am.set_loadout(["orbital_strike", "emp_burst", "repair_wave"])
    assert_eq(am.get_loadout().size(), 3)

func test_activate_ability():
    am.set_loadout(["orbital_strike", "emp_burst", "repair_wave"])
    var result := am.activate_ability(0, Vector2(100, 100))
    assert_true(result)

func test_cannot_activate_on_cooldown():
    am.set_loadout(["orbital_strike", "emp_burst", "repair_wave"])
    am.activate_ability(0, Vector2(100, 100))
    var result := am.activate_ability(0, Vector2(100, 100))
    assert_false(result)

func test_max_3_slots():
    am.set_loadout(["orbital_strike", "emp_burst", "repair_wave", "overclock"])
    assert_eq(am.get_loadout().size(), 3)
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Write implementations**

```gdscript
# core/ability_system/ability_definition.gd
class_name AbilityDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var ability_type: Enums.AbilityType = Enums.AbilityType.ORBITAL_STRIKE
@export var base_cooldown: float = 60.0
@export var base_duration: float = 0.0
@export var base_value: float = 0.0
@export var targets_position: bool = true
@export var targets_tower: bool = false
```

```gdscript
# core/ability_system/ability.gd
class_name Ability
extends Node

signal activated(ability_id: String, target: Vector2)
signal cooldown_complete(ability_id: String)

var ability_id: String = ""
var base_cooldown: float = 60.0
var cooldown_reduction: float = 0.0
var _cooldown_remaining: float = 0.0


func initialize(id: String, cooldown: float) -> void:
    ability_id = id
    base_cooldown = cooldown


func is_ready() -> bool:
    return _cooldown_remaining <= 0.0


func get_cooldown_progress() -> float:
    if base_cooldown <= 0.0:
        return 1.0
    var effective := base_cooldown * (1.0 - cooldown_reduction)
    if effective <= 0.0:
        return 1.0
    return 1.0 - (_cooldown_remaining / effective)


func activate(target: Vector2 = Vector2.ZERO) -> bool:
    if not is_ready():
        return false
    _cooldown_remaining = base_cooldown * (1.0 - cooldown_reduction)
    activated.emit(ability_id, target)
    return true


func _process(delta: float) -> void:
    if _cooldown_remaining > 0.0:
        _cooldown_remaining -= delta
        if _cooldown_remaining <= 0.0:
            _cooldown_remaining = 0.0
            cooldown_complete.emit(ability_id)
```

```gdscript
# core/ability_system/ability_manager.gd
class_name AbilityManager
extends Node

signal ability_activated(ability_id: String, slot: int, target: Vector2)

const MAX_SLOTS := 3

var _abilities: Array[Ability] = []
var _loadout_ids: Array[String] = []

const ABILITY_COOLDOWNS := {
    "orbital_strike": 60.0,
    "emp_burst": 45.0,
    "repair_wave": 40.0,
    "shield_matrix": 50.0,
    "overclock": 30.0,
    "scrap_salvage": 35.0,
}


func set_loadout(ability_ids: Array) -> void:
    # Clear existing
    for ability in _abilities:
        ability.queue_free()
    _abilities.clear()
    _loadout_ids.clear()

    for i in range(mini(ability_ids.size(), MAX_SLOTS)):
        var id: String = ability_ids[i]
        var ability := Ability.new()
        add_child(ability)
        ability.initialize(id, ABILITY_COOLDOWNS.get(id, 60.0))
        _abilities.append(ability)
        _loadout_ids.append(id)


func get_loadout() -> Array[String]:
    return _loadout_ids


func activate_ability(slot: int, target: Vector2) -> bool:
    if slot < 0 or slot >= _abilities.size():
        return false
    var ability := _abilities[slot]
    if ability.activate(target):
        ability_activated.emit(ability.ability_id, slot, target)
        return true
    return false


func get_ability(slot: int) -> Ability:
    if slot < 0 or slot >= _abilities.size():
        return null
    return _abilities[slot]


func set_cooldown_reduction(reduction: float) -> void:
    for ability in _abilities:
        ability.cooldown_reduction = reduction
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add core/ability_system/ tests/test_ability.gd tests/test_ability_manager.gd
git commit -m "feat: implement ability system with 3-slot loadout and cooldowns"
```

---

### Task 5: Implement Hero System

**Files:**
- Create: `core/ability_system/hero_definition.gd`
- Create: `core/ability_system/hero.gd`
- Test: `tests/test_hero.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_hero.gd
extends GutTest

func test_hero_spawns_with_duration():
    var hero := Hero.new()
    add_child(hero)
    hero.initialize("gunship_drone", 20.0, Vector2(100, 100))
    assert_true(hero.is_active())
    assert_eq(hero._duration_remaining, 20.0)
    hero.queue_free()

func test_hero_despawns_after_duration():
    var hero := Hero.new()
    add_child(hero)
    hero.initialize("gunship_drone", 1.0, Vector2(100, 100))
    watch_signals(hero)
    hero._process(1.1)
    assert_signal_emitted(hero, "expired")
    hero.queue_free()

func test_hero_duration_bonus():
    var hero := Hero.new()
    add_child(hero)
    hero.initialize("gunship_drone", 20.0, Vector2(100, 100))
    hero.apply_duration_bonus(5.0)
    assert_eq(hero._duration_remaining, 25.0)
    hero.queue_free()

func test_hero_cooldown():
    assert_ge(Hero.SUMMON_COOLDOWN, 120.0)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/ability_system/hero_definition.gd
class_name HeroDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tower_type: Enums.TowerType = Enums.TowerType.PULSE_CANNON
@export var base_duration: float = 20.0
@export var shape_sides: int = 8
@export var shape_radius: float = 24.0
@export var color: Color = Color.CYAN
@export var damage: float = 50.0
@export var attack_speed: float = 2.0
@export var movement_speed: float = 200.0
@export var special_ability: String = ""
```

```gdscript
# core/ability_system/hero.gd
class_name Hero
extends Node2D

signal expired(hero: Hero)

const SUMMON_COOLDOWN := 150.0

var hero_id: String = ""
var _duration_remaining: float = 0.0
var _active: bool = false


func initialize(id: String, duration: float, spawn_pos: Vector2) -> void:
    hero_id = id
    _duration_remaining = duration
    _active = true
    global_position = spawn_pos


func is_active() -> bool:
    return _active


func apply_duration_bonus(bonus: float) -> void:
    _duration_remaining += bonus


func _process(delta: float) -> void:
    if not _active:
        return
    _duration_remaining -= delta
    if _duration_remaining <= 0.0:
        _active = false
        expired.emit(self)


func _draw() -> void:
    if not _active:
        return
    # Glow effect
    draw_circle(Vector2.ZERO, 28.0, Color(1.0, 1.0, 1.0, 0.15))
    # Main shape (large octagon)
    var points := PackedVector2Array()
    for i in range(8):
        var angle := (TAU / 8) * i - PI / 2.0
        points.append(Vector2(cos(angle), sin(angle)) * 24.0)
    draw_colored_polygon(points, Color.CYAN)
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/ability_system/hero_definition.gd core/ability_system/hero.gd tests/test_hero.gd
git commit -m "feat: implement Hero with timed duration and summon system"
```
