# Plan 1: Foundation + Core Game Loop

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the Godot 4.x project with core singletons (GameManager, EconomyManager, SaveManager), i18n infrastructure, shared types, and a minimal playable game scene.

**Architecture:** Data-driven framework using Godot Resources (.tres). All game content is defined as data, not code. Singletons manage game state, economy, and persistence. All player-facing strings go through Godot's TranslationServer from day one.

**Tech Stack:** Godot 4.x, GDScript, GUT (Godot Unit Testing) addon, CSV translations

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md`

---

## File Structure

```
res://
├── project.godot
├── addons/gut/                        # GUT testing addon
├── tests/
│   ├── test_game_manager.gd
│   ├── test_economy_manager.gd
│   ├── test_save_manager.gd
│   └── test_i18n.gd
├── core/
│   ├── game_manager.gd                # GameManager singleton
│   ├── economy/
│   │   └── economy_manager.gd         # EconomyManager singleton
│   └── save/
│       └── save_manager.gd            # SaveManager singleton
├── shared/
│   ├── enums.gd                       # Game-wide enums
│   └── constants.gd                   # Game-wide constants
├── content/
│   └── translations/
│       ├── ui.en.translation          # Compiled from CSV
│       └── ui.csv                     # UI translation strings
└── scenes/
    └── game.tscn                      # Minimal game scene (placeholder)
```

---

### Task 1: Initialize Godot Project

**Files:**
- Create: `project.godot`
- Create: directory structure

- [ ] **Step 1: Create Godot project file**

Create the project via Godot Editor or manually create `project.godot`:

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but it can also be edited via code.

config_version=5

[application]

config/name="Last Signal"
config/description="Geometric Sci-Fi Tower Defense"
run/main_scene="res://scenes/game.tscn"
config/features=PackedStringArray("4.4")

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[internationalization]

locale/translations=PackedStringArray("res://content/translations/ui.en.translation")

[rendering]

renderer/rendering_method="mobile"
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p core/economy core/save core/tower_system core/enemy_system core/wave_system
mkdir -p core/upgrade_system core/ability_system core/adaptation core/pathfinding core/audio
mkdir -p shared tests scenes
mkdir -p content/towers content/enemies content/waves content/levels content/skills
mkdir -p content/translations
mkdir -p ui/hud ui/menus ui/tower_ui ui/meta
```

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: initialize Godot project for Last Signal"
```

---

### Task 2: Install GUT Testing Addon

**Files:**
- Create: `addons/gut/` (from asset library or git)

- [ ] **Step 1: Install GUT**

Download GUT from Godot Asset Library or clone:
```bash
# Option A: Download from https://github.com/bitwes/Gut/releases
# Extract to addons/gut/

# Option B: If using git
git clone https://github.com/bitwes/Gut.git addons/gut
```

- [ ] **Step 2: Create GUT configuration**

Create `.gutconfig.json` in project root:

```json
{
  "dirs": ["res://tests/"],
  "prefix": "test_",
  "suffix": ".gd",
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true
}
```

- [ ] **Step 3: Enable the addon in project.godot**

Add to `project.godot`:
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 4: Commit**

```bash
git add addons/ .gutconfig.json project.godot
git commit -m "feat: add GUT testing framework"
```

---

### Task 3: Define Shared Enums

**Files:**
- Create: `shared/enums.gd`
- Test: `tests/test_enums.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_enums.gd
extends GutTest

func test_difficulty_enum_has_three_values():
    assert_eq(Enums.Difficulty.size(), 3)

func test_difficulty_enum_values():
    assert_eq(Enums.Difficulty.NORMAL, 0)
    assert_eq(Enums.Difficulty.HARD, 1)
    assert_eq(Enums.Difficulty.NIGHTMARE, 2)

func test_map_mode_enum():
    assert_eq(Enums.MapMode.FIXED_PATH, 0)
    assert_eq(Enums.MapMode.GRID_MAZE, 1)

func test_tower_type_enum_has_seven_values():
    assert_eq(Enums.TowerType.size(), 7)

func test_enemy_archetype_enum_has_six_values():
    assert_eq(Enums.EnemyArchetype.size(), 6)

func test_targeting_mode_enum():
    assert_eq(Enums.TargetingMode.NEAREST, 0)
    assert_eq(Enums.TargetingMode.STRONGEST, 1)
    assert_eq(Enums.TargetingMode.WEAKEST, 2)
    assert_eq(Enums.TargetingMode.FIRST, 3)
    assert_eq(Enums.TargetingMode.LAST, 4)

func test_game_state_enum():
    assert_eq(Enums.GameState.MENU, 0)
    assert_eq(Enums.GameState.BUILDING, 1)
    assert_eq(Enums.GameState.WAVE_ACTIVE, 2)
    assert_eq(Enums.GameState.WAVE_COMPLETE, 3)
    assert_eq(Enums.GameState.VICTORY, 4)
    assert_eq(Enums.GameState.DEFEAT, 5)
    assert_eq(Enums.GameState.PAUSED, 6)
```

- [ ] **Step 2: Run test to verify it fails**

Run: Open Godot Editor > GUT tab > Run All Tests
Expected: FAIL — `Enums` class not found

- [ ] **Step 3: Write implementation**

```gdscript
# shared/enums.gd
class_name Enums

enum Difficulty { NORMAL, HARD, NIGHTMARE }

enum MapMode { FIXED_PATH, GRID_MAZE }

enum TowerType {
    PULSE_CANNON,
    ARC_EMITTER,
    CRYO_ARRAY,
    MISSILE_POD,
    BEAM_SPIRE,
    NANO_HIVE,
    HARVESTER,
}

enum EnemyArchetype {
    SCOUT,
    DRONE,
    TANK,
    FLYER,
    SHIELDER,
    HEALER,
}

enum TargetingMode { NEAREST, STRONGEST, WEAKEST, FIRST, LAST }

enum GameState {
    MENU,
    BUILDING,
    WAVE_ACTIVE,
    WAVE_COMPLETE,
    VICTORY,
    DEFEAT,
    PAUSED,
}

enum DamageType {
    PULSE,
    ARC,
    CRYO,
    MISSILE,
    BEAM,
    NANO,
    HARVEST,
}

enum AbilityType {
    ORBITAL_STRIKE,
    EMP_BURST,
    REPAIR_WAVE,
    SHIELD_MATRIX,
    OVERCLOCK,
    SCRAP_SALVAGE,
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: GUT > Run All Tests
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add shared/enums.gd tests/test_enums.gd
git commit -m "feat: add shared game enums"
```

---

### Task 4: Define Shared Constants

**Files:**
- Create: `shared/constants.gd`
- Test: `tests/test_constants.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_constants.gd
extends GutTest

func test_difficulty_hp_multipliers():
    assert_eq(Constants.DIFFICULTY_HP_MULT[Enums.Difficulty.NORMAL], 1.0)
    assert_eq(Constants.DIFFICULTY_HP_MULT[Enums.Difficulty.HARD], 1.8)
    assert_eq(Constants.DIFFICULTY_HP_MULT[Enums.Difficulty.NIGHTMARE], 3.0)

func test_difficulty_speed_multipliers():
    assert_eq(Constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.NORMAL], 1.0)
    assert_eq(Constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.HARD], 1.15)
    assert_eq(Constants.DIFFICULTY_SPEED_MULT[Enums.Difficulty.NIGHTMARE], 1.3)

func test_difficulty_gold_multipliers():
    assert_eq(Constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NORMAL], 1.0)
    assert_eq(Constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.HARD], 0.85)
    assert_eq(Constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NIGHTMARE], 0.7)

func test_difficulty_starting_lives():
    assert_eq(Constants.DIFFICULTY_LIVES[Enums.Difficulty.NORMAL], 20)
    assert_eq(Constants.DIFFICULTY_LIVES[Enums.Difficulty.HARD], 10)
    assert_eq(Constants.DIFFICULTY_LIVES[Enums.Difficulty.NIGHTMARE], 5)

func test_difficulty_adaptation_thresholds():
    assert_eq(Constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.NORMAL], 0.4)
    assert_eq(Constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.HARD], 0.35)
    assert_eq(Constants.DIFFICULTY_ADAPTATION_THRESHOLD[Enums.Difficulty.NIGHTMARE], 0.25)

func test_difficulty_diamond_multipliers():
    assert_eq(Constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.NORMAL], 1.0)
    assert_eq(Constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.HARD], 1.5)
    assert_eq(Constants.DIFFICULTY_DIAMOND_MULT[Enums.Difficulty.NIGHTMARE], 2.5)

func test_base_sell_refund():
    assert_eq(Constants.BASE_SELL_REFUND, 0.7)

func test_adaptation_constants():
    assert_eq(Constants.ADAPTATION_CHECK_INTERVAL, 3)
    assert_eq(Constants.ADAPTATION_MAX_RESISTANCE, 0.6)
    assert_eq(Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS, 0.75)
    assert_eq(Constants.ADAPTATION_ENDLESS_THRESHOLD, 0.3)

func test_global_upgrade_costs():
    assert_eq(Constants.GLOBAL_UPGRADE_COSTS.size(), 10)
    assert_eq(Constants.GLOBAL_UPGRADE_COSTS[0], 50)
    assert_eq(Constants.GLOBAL_UPGRADE_COSTS[9], 1400)

func test_star_thresholds():
    assert_eq(Constants.STAR_2_MAX_LIVES_LOST, 5)
    assert_eq(Constants.STAR_3_MAX_LIVES_LOST, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `Constants` class not found

- [ ] **Step 3: Write implementation**

```gdscript
# shared/constants.gd
class_name Constants

# --- Difficulty Multipliers ---
const DIFFICULTY_HP_MULT := {
    Enums.Difficulty.NORMAL: 1.0,
    Enums.Difficulty.HARD: 1.8,
    Enums.Difficulty.NIGHTMARE: 3.0,
}

const DIFFICULTY_SPEED_MULT := {
    Enums.Difficulty.NORMAL: 1.0,
    Enums.Difficulty.HARD: 1.15,
    Enums.Difficulty.NIGHTMARE: 1.3,
}

const DIFFICULTY_GOLD_MULT := {
    Enums.Difficulty.NORMAL: 1.0,
    Enums.Difficulty.HARD: 0.85,
    Enums.Difficulty.NIGHTMARE: 0.7,
}

const DIFFICULTY_LIVES := {
    Enums.Difficulty.NORMAL: 20,
    Enums.Difficulty.HARD: 10,
    Enums.Difficulty.NIGHTMARE: 5,
}

const DIFFICULTY_ADAPTATION_THRESHOLD := {
    Enums.Difficulty.NORMAL: 0.4,
    Enums.Difficulty.HARD: 0.35,
    Enums.Difficulty.NIGHTMARE: 0.25,
}

const DIFFICULTY_DIAMOND_MULT := {
    Enums.Difficulty.NORMAL: 1.0,
    Enums.Difficulty.HARD: 1.5,
    Enums.Difficulty.NIGHTMARE: 2.5,
}

# --- Economy ---
const BASE_SELL_REFUND := 0.7
const SELL_REFUND_PER_UPGRADE_TIER := 0.02
const EARLY_SEND_GOLD_BONUS := 50

# --- Adaptation ---
const ADAPTATION_CHECK_INTERVAL := 3
const ADAPTATION_MAX_RESISTANCE := 0.6
const ADAPTATION_MAX_RESISTANCE_ENDLESS := 0.75
const ADAPTATION_ENDLESS_THRESHOLD := 0.3
const ADAPTATION_RESISTANCE_INCREMENT := 0.1
const ADAPTATION_DECAY_RATE := 0.05

# --- Star Rating ---
const STAR_2_MAX_LIVES_LOST := 5
const STAR_3_MAX_LIVES_LOST := 0

# --- Wave Timing ---
const WAVE_BREAK_DURATION := 6.0
const DEFAULT_SPAWN_INTERVAL := 0.5

# --- Game Speed ---
const SPEED_OPTIONS := [1.0, 2.0, 3.0]

# --- Hero ---
const HERO_BASE_COOLDOWN := 150.0
const HERO_DURATION_PER_UPGRADE_TIER := 1.0

# --- Global Upgrade Costs (10 tiers, exponential) ---
const GLOBAL_UPGRADE_COSTS := [50, 75, 110, 160, 230, 330, 470, 680, 980, 1400]

# --- Ability Upgrade Costs ---
const ABILITY_UNLOCK_COST := 200
const ABILITY_UPGRADE_COSTS := [100, 150, 250, 400, 600]

# --- Tower Skill Tree Node Costs ---
const SKILL_NODE_COSTS := [80, 100, 120, 200, 250, 350, 450, 600, 750, 1200]

# --- Ads ---
const MAX_ADS_PER_DAY := 5
const DIAMONDS_PER_AD := 10
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add shared/constants.gd tests/test_constants.gd
git commit -m "feat: add shared game constants and difficulty tables"
```

---

### Task 5: Implement GameManager Singleton

**Files:**
- Create: `core/game_manager.gd`
- Test: `tests/test_game_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_game_manager.gd
extends GutTest

var gm: GameManager

func before_each():
    gm = GameManager.new()
    add_child(gm)

func after_each():
    gm.queue_free()

func test_initial_state_is_menu():
    assert_eq(gm.current_state, Enums.GameState.MENU)

func test_initial_difficulty_is_normal():
    assert_eq(gm.current_difficulty, Enums.Difficulty.NORMAL)

func test_set_difficulty():
    gm.set_difficulty(Enums.Difficulty.HARD)
    assert_eq(gm.current_difficulty, Enums.Difficulty.HARD)

func test_change_state_emits_signal():
    watch_signals(gm)
    gm.change_state(Enums.GameState.BUILDING)
    assert_signal_emitted(gm, "state_changed")

func test_change_state_updates_current_state():
    gm.change_state(Enums.GameState.BUILDING)
    assert_eq(gm.current_state, Enums.GameState.BUILDING)

func test_start_level_sets_building_state():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    assert_eq(gm.current_state, Enums.GameState.BUILDING)
    assert_eq(gm.current_level_id, "level_1_1")

func test_lives_initialized_from_difficulty():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    assert_eq(gm.lives, 20)

func test_lives_initialized_hard():
    gm.start_level("level_1_1", Enums.Difficulty.HARD)
    assert_eq(gm.lives, 10)

func test_lose_life_decrements():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    gm.lose_life()
    assert_eq(gm.lives, 19)

func test_lose_life_emits_signal():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    watch_signals(gm)
    gm.lose_life()
    assert_signal_emitted(gm, "lives_changed")

func test_lose_all_lives_triggers_defeat():
    gm.start_level("level_1_1", Enums.Difficulty.NIGHTMARE)
    for i in range(5):
        gm.lose_life()
    assert_eq(gm.current_state, Enums.GameState.DEFEAT)

func test_lives_lost_tracking():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    gm.lose_life()
    gm.lose_life()
    assert_eq(gm.lives_lost, 2)

func test_calculate_stars_3_star():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    assert_eq(gm.calculate_stars(), 3)

func test_calculate_stars_2_star():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    gm.lose_life()
    gm.lose_life()
    assert_eq(gm.calculate_stars(), 2)

func test_calculate_stars_1_star():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    for i in range(6):
        gm.lose_life()
    assert_eq(gm.calculate_stars(), 1)

func test_game_speed():
    gm.set_game_speed(2.0)
    assert_eq(gm.game_speed, 2.0)

func test_pause_and_unpause():
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    gm.toggle_pause()
    assert_eq(gm.current_state, Enums.GameState.PAUSED)
    gm.toggle_pause()
    assert_eq(gm.current_state, Enums.GameState.BUILDING)
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `GameManager` class not found

- [ ] **Step 3: Write implementation**

```gdscript
# core/game_manager.gd
class_name GameManager
extends Node

signal state_changed(old_state: Enums.GameState, new_state: Enums.GameState)
signal lives_changed(new_lives: int)
signal difficulty_changed(new_difficulty: Enums.Difficulty)
signal game_speed_changed(new_speed: float)
signal level_started(level_id: String)
signal level_completed(level_id: String, stars: int)
signal level_failed(level_id: String)

var current_state: Enums.GameState = Enums.GameState.MENU
var current_difficulty: Enums.Difficulty = Enums.Difficulty.NORMAL
var current_level_id: String = ""
var lives: int = 0
var lives_lost: int = 0
var game_speed: float = 1.0
var _state_before_pause: Enums.GameState = Enums.GameState.MENU


func set_difficulty(difficulty: Enums.Difficulty) -> void:
    current_difficulty = difficulty
    difficulty_changed.emit(difficulty)


func change_state(new_state: Enums.GameState) -> void:
    var old_state := current_state
    current_state = new_state
    state_changed.emit(old_state, new_state)


func start_level(level_id: String, difficulty: Enums.Difficulty) -> void:
    current_level_id = level_id
    current_difficulty = difficulty
    lives = Constants.DIFFICULTY_LIVES[difficulty]
    lives_lost = 0
    change_state(Enums.GameState.BUILDING)
    level_started.emit(level_id)


func lose_life() -> void:
    lives -= 1
    lives_lost += 1
    lives_changed.emit(lives)
    if lives <= 0:
        change_state(Enums.GameState.DEFEAT)
        level_failed.emit(current_level_id)


func complete_level() -> void:
    var stars := calculate_stars()
    change_state(Enums.GameState.VICTORY)
    level_completed.emit(current_level_id, stars)


func calculate_stars() -> int:
    if lives_lost <= Constants.STAR_3_MAX_LIVES_LOST:
        return 3
    elif lives_lost <= Constants.STAR_2_MAX_LIVES_LOST:
        return 2
    else:
        return 1


func set_game_speed(speed: float) -> void:
    game_speed = speed
    Engine.time_scale = speed
    game_speed_changed.emit(speed)


func toggle_pause() -> void:
    if current_state == Enums.GameState.PAUSED:
        change_state(_state_before_pause)
        get_tree().paused = false
    else:
        _state_before_pause = current_state
        change_state(Enums.GameState.PAUSED)
        get_tree().paused = true
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All PASS

- [ ] **Step 5: Register as autoload in project.godot**

Add to `project.godot`:
```ini
[autoload]

GameManager="*res://core/game_manager.gd"
```

- [ ] **Step 6: Commit**

```bash
git add core/game_manager.gd tests/test_game_manager.gd project.godot
git commit -m "feat: implement GameManager singleton with state, lives, difficulty"
```

---

### Task 6: Implement EconomyManager Singleton

**Files:**
- Create: `core/economy/economy_manager.gd`
- Test: `tests/test_economy_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_economy_manager.gd
extends GutTest

var em: EconomyManager

func before_each():
    em = EconomyManager.new()
    add_child(em)

func after_each():
    em.queue_free()

# --- Gold tests ---

func test_initial_gold_is_zero():
    assert_eq(em.gold, 0)

func test_add_gold():
    em.add_gold(100)
    assert_eq(em.gold, 100)

func test_spend_gold_success():
    em.add_gold(100)
    var result := em.spend_gold(50)
    assert_true(result)
    assert_eq(em.gold, 50)

func test_spend_gold_insufficient():
    em.add_gold(30)
    var result := em.spend_gold(50)
    assert_false(result)
    assert_eq(em.gold, 30)

func test_can_afford():
    em.add_gold(100)
    assert_true(em.can_afford(100))
    assert_true(em.can_afford(50))
    assert_false(em.can_afford(101))

func test_gold_signal_emitted_on_add():
    watch_signals(em)
    em.add_gold(50)
    assert_signal_emitted(em, "gold_changed")

func test_gold_signal_emitted_on_spend():
    em.add_gold(100)
    watch_signals(em)
    em.spend_gold(50)
    assert_signal_emitted(em, "gold_changed")

func test_reset_gold():
    em.add_gold(500)
    em.reset_match_economy()
    assert_eq(em.gold, 0)

# --- Diamond tests ---

func test_initial_diamonds_is_zero():
    assert_eq(em.diamonds, 0)

func test_add_diamonds():
    em.add_diamonds(100)
    assert_eq(em.diamonds, 100)

func test_add_diamonds_with_doubler():
    em.diamond_doubler = true
    em.add_diamonds(100)
    assert_eq(em.diamonds, 200)

func test_spend_diamonds_success():
    em.add_diamonds(100)
    var result := em.spend_diamonds(50)
    assert_true(result)
    assert_eq(em.diamonds, 50)

func test_spend_diamonds_insufficient():
    em.add_diamonds(30)
    var result := em.spend_diamonds(50)
    assert_false(result)
    assert_eq(em.diamonds, 30)

func test_diamonds_signal_emitted():
    watch_signals(em)
    em.add_diamonds(50)
    assert_signal_emitted(em, "diamonds_changed")

func test_total_diamonds_earned_tracking():
    em.add_diamonds(100)
    em.add_diamonds(50)
    assert_eq(em.total_diamonds_earned, 150)

func test_spend_diamonds_does_not_affect_total_earned():
    em.add_diamonds(100)
    em.spend_diamonds(50)
    assert_eq(em.total_diamonds_earned, 100)

# --- Gold difficulty modifier ---

func test_gold_with_difficulty_modifier():
    em.set_gold_modifier(0.85)
    em.add_gold(100)
    assert_eq(em.gold, 85)

func test_reset_match_preserves_diamonds():
    em.add_diamonds(500)
    em.add_gold(300)
    em.reset_match_economy()
    assert_eq(em.gold, 0)
    assert_eq(em.diamonds, 500)
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `EconomyManager` class not found

- [ ] **Step 3: Write implementation**

```gdscript
# core/economy/economy_manager.gd
class_name EconomyManager
extends Node

signal gold_changed(new_amount: int)
signal diamonds_changed(new_amount: int)

var gold: int = 0
var diamonds: int = 0
var diamond_doubler: bool = false
var total_diamonds_earned: int = 0
var _gold_modifier: float = 1.0


func set_gold_modifier(modifier: float) -> void:
    _gold_modifier = modifier


func add_gold(amount: int) -> void:
    var modified := int(amount * _gold_modifier)
    gold += modified
    gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
    if gold < amount:
        return false
    gold -= amount
    gold_changed.emit(gold)
    return true


func can_afford(amount: int) -> bool:
    return gold >= amount


func add_diamonds(amount: int) -> void:
    var actual := amount * 2 if diamond_doubler else amount
    diamonds += actual
    total_diamonds_earned += actual
    diamonds_changed.emit(diamonds)


func spend_diamonds(amount: int) -> bool:
    if diamonds < amount:
        return false
    diamonds -= amount
    diamonds_changed.emit(diamonds)
    return true


func can_afford_diamonds(amount: int) -> bool:
    return diamonds >= amount


func reset_match_economy() -> void:
    gold = 0
    _gold_modifier = 1.0
    gold_changed.emit(gold)
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All PASS

- [ ] **Step 5: Register as autoload in project.godot**

Add to `[autoload]`:
```ini
EconomyManager="*res://core/economy/economy_manager.gd"
```

- [ ] **Step 6: Commit**

```bash
git add core/economy/economy_manager.gd tests/test_economy_manager.gd project.godot
git commit -m "feat: implement EconomyManager with gold and diamond systems"
```

---

### Task 7: Implement SaveManager Singleton

**Files:**
- Create: `core/save/save_manager.gd`
- Test: `tests/test_save_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_save_manager.gd
extends GutTest

var sm: SaveManager
var _test_save_path := "user://test_save.json"

func before_each():
    sm = SaveManager.new()
    sm.save_path = _test_save_path
    add_child(sm)

func after_each():
    sm.queue_free()
    # Clean up test save files
    for i in range(4):
        var path: String = _test_save_path if i == 0 else _test_save_path + ".bak" + str(i)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func test_default_save_data_structure():
    var data := sm.get_default_save_data()
    assert_has(data, "profile")
    assert_has(data, "campaign")
    assert_has(data, "economy")
    assert_has(data, "progression")
    assert_has(data, "endless")
    assert_has(data, "stats")
    assert_has(data, "monetization")

func test_default_profile():
    var data := sm.get_default_save_data()
    assert_eq(data.profile.language, "en")
    assert_has(data.profile, "settings")

func test_default_economy():
    var data := sm.get_default_save_data()
    assert_eq(data.economy.diamonds, 0)
    assert_eq(data.economy.diamond_doubler, false)

func test_save_and_load():
    sm.data.economy.diamonds = 500
    sm.save_game()
    # Create a new SaveManager and load
    var sm2 := SaveManager.new()
    sm2.save_path = _test_save_path
    add_child(sm2)
    sm2.load_game()
    assert_eq(sm2.data.economy.diamonds, 500)
    sm2.queue_free()

func test_save_creates_file():
    sm.save_game()
    assert_true(FileAccess.file_exists(_test_save_path))

func test_load_nonexistent_returns_defaults():
    sm.load_game()
    assert_eq(sm.data.economy.diamonds, 0)

func test_set_level_complete():
    sm.set_level_complete("level_1_1", 3, Enums.Difficulty.NORMAL)
    assert_eq(sm.data.campaign.levels_completed["level_1_1"].stars, 3)
    assert_eq(sm.data.campaign.levels_completed["level_1_1"].best_difficulty, Enums.Difficulty.NORMAL)

func test_set_level_complete_keeps_best():
    sm.set_level_complete("level_1_1", 2, Enums.Difficulty.NORMAL)
    sm.set_level_complete("level_1_1", 3, Enums.Difficulty.NORMAL)
    assert_eq(sm.data.campaign.levels_completed["level_1_1"].stars, 3)

func test_set_level_complete_does_not_downgrade():
    sm.set_level_complete("level_1_1", 3, Enums.Difficulty.HARD)
    sm.set_level_complete("level_1_1", 1, Enums.Difficulty.NORMAL)
    assert_eq(sm.data.campaign.levels_completed["level_1_1"].stars, 3)
    assert_eq(sm.data.campaign.levels_completed["level_1_1"].best_difficulty, Enums.Difficulty.HARD)

func test_backup_rotation():
    sm.save_game()
    sm.data.economy.diamonds = 100
    sm.save_game()
    sm.data.economy.diamonds = 200
    sm.save_game()
    # Should have backup files
    assert_true(FileAccess.file_exists(_test_save_path + ".bak1"))

func test_save_signal():
    watch_signals(sm)
    sm.save_game()
    assert_signal_emitted(sm, "game_saved")

func test_load_signal():
    sm.save_game()
    watch_signals(sm)
    sm.load_game()
    assert_signal_emitted(sm, "game_loaded")
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `SaveManager` class not found

- [ ] **Step 3: Write implementation**

```gdscript
# core/save/save_manager.gd
class_name SaveManager
extends Node

signal game_saved()
signal game_loaded()

const MAX_BACKUPS := 3

var save_path: String = "user://last_signal_save.json"
var data: Dictionary = {}


func _ready() -> void:
    data = get_default_save_data()


func get_default_save_data() -> Dictionary:
    return {
        "profile": {
            "language": "en",
            "settings": {
                "music_vol": 0.8,
                "sfx_vol": 0.8,
                "ui_vol": 1.0,
                "speed_pref": 1.0,
                "graphics": "medium",
            },
        },
        "campaign": {
            "current_region": 1,
            "levels_completed": {},
            "endless_unlocked": false,
        },
        "economy": {
            "diamonds": 0,
            "diamond_doubler": false,
            "total_diamonds_earned": 0,
        },
        "progression": {
            "towers_unlocked": ["pulse_cannon", "arc_emitter", "cryo_array", "missile_pod"],
            "skill_trees": {},
            "global_upgrades": {},
            "abilities_unlocked": [],
            "abilities_upgrade_levels": {},
            "heroes_unlocked": [],
        },
        "endless": {
            "high_scores": {},
        },
        "stats": {
            "total_enemies_killed": 0,
            "total_gold_earned": 0,
            "favorite_tower": "",
            "playtime_seconds": 0,
        },
        "monetization": {
            "ads_watched_today": 0,
            "ads_last_date": "",
            "iap_history": [],
        },
    }


func save_game() -> void:
    _rotate_backups()
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        game_saved.emit()


func load_game() -> void:
    if not FileAccess.file_exists(save_path):
        data = get_default_save_data()
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file:
        var json := JSON.new()
        var result := json.parse(file.get_as_text())
        file.close()
        if result == OK:
            var loaded: Dictionary = json.data
            data = _merge_with_defaults(loaded)
            game_loaded.emit()
        else:
            push_warning("SaveManager: Failed to parse save file, using defaults")
            data = get_default_save_data()


func set_level_complete(level_id: String, stars: int, difficulty: Enums.Difficulty) -> void:
    if level_id in data.campaign.levels_completed:
        var existing: Dictionary = data.campaign.levels_completed[level_id]
        if stars > existing.stars:
            existing.stars = stars
        if difficulty > existing.best_difficulty:
            existing.best_difficulty = difficulty
    else:
        data.campaign.levels_completed[level_id] = {
            "stars": stars,
            "best_difficulty": difficulty,
        }


func _rotate_backups() -> void:
    if not FileAccess.file_exists(save_path):
        return
    # Shift existing backups
    for i in range(MAX_BACKUPS, 1, -1):
        var old_path := save_path + ".bak" + str(i - 1)
        var new_path := save_path + ".bak" + str(i)
        if FileAccess.file_exists(old_path):
            if FileAccess.file_exists(new_path):
                DirAccess.remove_absolute(new_path)
            DirAccess.rename_absolute(old_path, new_path)
    # Current save becomes bak1
    var bak1 := save_path + ".bak1"
    if FileAccess.file_exists(bak1):
        DirAccess.remove_absolute(bak1)
    DirAccess.copy_absolute(save_path, bak1)


func _merge_with_defaults(loaded: Dictionary) -> Dictionary:
    var defaults := get_default_save_data()
    return _deep_merge(defaults, loaded)


func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    for key in override:
        if key in result and result[key] is Dictionary and override[key] is Dictionary:
            result[key] = _deep_merge(result[key], override[key])
        else:
            result[key] = override[key]
    return result
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All PASS

- [ ] **Step 5: Register as autoload in project.godot**

Add to `[autoload]`:
```ini
SaveManager="*res://core/save/save_manager.gd"
```

- [ ] **Step 6: Commit**

```bash
git add core/save/save_manager.gd tests/test_save_manager.gd project.godot
git commit -m "feat: implement SaveManager with JSON persistence and backup rotation"
```

---

### Task 8: Set Up i18n Infrastructure

**Files:**
- Create: `content/translations/ui.csv`
- Test: `tests/test_i18n.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_i18n.gd
extends GutTest

func test_ui_translation_keys_exist():
    # These keys should be defined in ui.csv
    assert_ne(tr("UI_PLAY_CAMPAIGN"), "UI_PLAY_CAMPAIGN")
    assert_ne(tr("UI_ENDLESS_MODE"), "UI_ENDLESS_MODE")
    assert_ne(tr("UI_TOWER_LAB"), "UI_TOWER_LAB")
    assert_ne(tr("UI_SETTINGS"), "UI_SETTINGS")
    assert_ne(tr("UI_MAIN_MENU"), "UI_MAIN_MENU")

func test_tower_name_keys():
    assert_ne(tr("TOWER_PULSE_CANNON"), "TOWER_PULSE_CANNON")
    assert_ne(tr("TOWER_ARC_EMITTER"), "TOWER_ARC_EMITTER")
    assert_ne(tr("TOWER_CRYO_ARRAY"), "TOWER_CRYO_ARRAY")
    assert_ne(tr("TOWER_MISSILE_POD"), "TOWER_MISSILE_POD")
    assert_ne(tr("TOWER_BEAM_SPIRE"), "TOWER_BEAM_SPIRE")
    assert_ne(tr("TOWER_NANO_HIVE"), "TOWER_NANO_HIVE")
    assert_ne(tr("TOWER_HARVESTER"), "TOWER_HARVESTER")

func test_difficulty_keys():
    assert_ne(tr("DIFFICULTY_NORMAL"), "DIFFICULTY_NORMAL")
    assert_ne(tr("DIFFICULTY_HARD"), "DIFFICULTY_HARD")
    assert_ne(tr("DIFFICULTY_NIGHTMARE"), "DIFFICULTY_NIGHTMARE")

func test_hud_keys():
    assert_ne(tr("HUD_WAVE"), "HUD_WAVE")
    assert_ne(tr("HUD_SEND_WAVE"), "HUD_SEND_WAVE")
    assert_ne(tr("HUD_SELL"), "HUD_SELL")
    assert_ne(tr("HUD_UPGRADE"), "HUD_UPGRADE")
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — translation keys return themselves (no translation loaded)

- [ ] **Step 3: Create translation CSV files**

```csv
key,en
UI_PLAY_CAMPAIGN,Play Campaign
UI_ENDLESS_MODE,Endless Mode
UI_TOWER_LAB,Tower Lab
UI_SETTINGS,Settings
UI_MAIN_MENU,Main Menu
UI_DIAMOND_SHOP,Diamond Shop
UI_BACK,Back
UI_CONFIRM,Confirm
UI_CANCEL,Cancel
UI_PAUSE,Pause
UI_RESUME,Resume
UI_RESTART,Restart
UI_QUIT_LEVEL,Quit Level
TOWER_PULSE_CANNON,Pulse Cannon
TOWER_ARC_EMITTER,Arc Emitter
TOWER_CRYO_ARRAY,Cryo Array
TOWER_MISSILE_POD,Missile Pod
TOWER_BEAM_SPIRE,Beam Spire
TOWER_NANO_HIVE,Nano Hive
TOWER_HARVESTER,Harvester
DIFFICULTY_NORMAL,Normal
DIFFICULTY_HARD,Hard
DIFFICULTY_NIGHTMARE,Nightmare
HUD_WAVE,Wave
HUD_SEND_WAVE,Send Wave
HUD_SELL,Sell
HUD_UPGRADE,Upgrade
HUD_LIVES,Lives
HUD_GOLD,Gold
HUD_SPEED,Speed
ENEMY_SCOUT,Scout
ENEMY_DRONE,Drone
ENEMY_TANK,Tank
ENEMY_FLYER,Flyer
ENEMY_SHIELDER,Shielder
ENEMY_HEALER,Healer
STAR_RATING,Stars
ABILITY_ORBITAL_STRIKE,Orbital Strike
ABILITY_EMP_BURST,EMP Burst
ABILITY_REPAIR_WAVE,Repair Wave
ABILITY_SHIELD_MATRIX,Shield Matrix
ABILITY_OVERCLOCK,Overclock
ABILITY_SCRAP_SALVAGE,Scrap Salvage
```

Save as `content/translations/ui.csv`.

- [ ] **Step 4: Import CSV in Godot**

Open Godot Editor. The CSV will auto-import and generate `.translation` files. Verify `content/translations/ui.en.translation` is created.

Ensure `project.godot` references the translation:
```ini
[internationalization]
locale/translations=PackedStringArray("res://content/translations/ui.en.translation")
```

- [ ] **Step 5: Run test to verify it passes**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add content/translations/ project.godot
git commit -m "feat: add i18n infrastructure with initial English translation keys"
```

---

### Task 9: Create Minimal Game Scene

**Files:**
- Create: `scenes/game.tscn`
- Create: `scenes/game.gd`

- [ ] **Step 1: Create game scene script**

```gdscript
# scenes/game.gd
extends Node2D

## Main game scene. Orchestrates tower placement, enemy waves, and game state.
## This is the minimal scaffold — systems will be connected in later plans.

@onready var game_manager: GameManager = get_node("/root/GameManager")
@onready var economy_manager: EconomyManager = get_node("/root/EconomyManager")


func _ready() -> void:
    pass


func start_level(level_id: String, difficulty: Enums.Difficulty) -> void:
    game_manager.start_level(level_id, difficulty)
    economy_manager.reset_match_economy()
    economy_manager.set_gold_modifier(
        Constants.DIFFICULTY_GOLD_MULT[difficulty]
    )
```

- [ ] **Step 2: Create game scene (.tscn)**

Create `scenes/game.tscn` in Godot Editor:
- Root node: `Node2D` named "Game"
- Attach `scenes/game.gd` script
- Add child `Node2D` named "Map" (placeholder for level geometry)
- Add child `Node2D` named "Towers" (container for placed towers)
- Add child `Node2D` named "Enemies" (container for spawned enemies)
- Add child `Node2D` named "Projectiles" (container for projectiles)
- Add child `CanvasLayer` named "UI" (for HUD overlay)

Scene tree:
```
Game (Node2D) [game.gd]
├── Map (Node2D)
├── Towers (Node2D)
├── Enemies (Node2D)
├── Projectiles (Node2D)
└── UI (CanvasLayer)
```

- [ ] **Step 3: Set as main scene**

Verify `project.godot` has:
```ini
run/main_scene="res://scenes/game.tscn"
```

- [ ] **Step 4: Run the project to verify it launches**

Run: Press F5 in Godot Editor
Expected: Empty window opens without errors

- [ ] **Step 5: Commit**

```bash
git add scenes/game.gd scenes/game.tscn project.godot
git commit -m "feat: create minimal game scene with node structure"
```

---

### Task 10: Integration Smoke Test

**Files:**
- Test: `tests/test_integration_foundation.gd`

- [ ] **Step 1: Write integration test**

```gdscript
# tests/test_integration_foundation.gd
extends GutTest

## Verifies all foundation systems work together.

var gm: GameManager
var em: EconomyManager
var sm: SaveManager

func before_each():
    gm = GameManager.new()
    em = EconomyManager.new()
    sm = SaveManager.new()
    sm.save_path = "user://test_integration_save.json"
    add_child(gm)
    add_child(em)
    add_child(sm)

func after_each():
    gm.queue_free()
    em.queue_free()
    sm.queue_free()
    if FileAccess.file_exists("user://test_integration_save.json"):
        DirAccess.remove_absolute("user://test_integration_save.json")

func test_full_level_flow():
    # Start a level on Normal
    gm.start_level("level_1_1", Enums.Difficulty.NORMAL)
    assert_eq(gm.current_state, Enums.GameState.BUILDING)
    assert_eq(gm.lives, 20)

    # Set up economy for this difficulty
    em.reset_match_economy()
    em.set_gold_modifier(Constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.NORMAL])

    # Earn gold from kills
    em.add_gold(100)
    assert_eq(em.gold, 100)

    # Spend gold on a tower
    assert_true(em.spend_gold(60))
    assert_eq(em.gold, 40)

    # Lose some lives
    gm.lose_life()
    gm.lose_life()
    assert_eq(gm.lives, 18)

    # Complete the level
    gm.complete_level()
    assert_eq(gm.current_state, Enums.GameState.VICTORY)

    # Calculate stars (2 lives lost = 3 stars? No, 2 <= 0 is false, 2 <= 5 is true = 2 stars)
    # Wait: 2 lives lost. Star 3 = 0 lives lost. Star 2 = <=5 lives lost. So 2 stars.
    assert_eq(gm.calculate_stars(), 2)

    # Earn diamonds for completion
    em.add_diamonds(100)
    assert_eq(em.diamonds, 100)

    # Save progress
    sm.set_level_complete("level_1_1", gm.calculate_stars(), Enums.Difficulty.NORMAL)
    sm.data.economy.diamonds = em.diamonds
    sm.save_game()

    # Verify save
    var sm2 := SaveManager.new()
    sm2.save_path = "user://test_integration_save.json"
    add_child(sm2)
    sm2.load_game()
    assert_eq(sm2.data.campaign.levels_completed["level_1_1"].stars, 2)
    assert_eq(sm2.data.economy.diamonds, 100)
    sm2.queue_free()

func test_hard_difficulty_modifiers():
    gm.start_level("level_1_1", Enums.Difficulty.HARD)
    assert_eq(gm.lives, 10)

    em.reset_match_economy()
    em.set_gold_modifier(Constants.DIFFICULTY_GOLD_MULT[Enums.Difficulty.HARD])
    em.add_gold(100)
    # 100 * 0.85 = 85
    assert_eq(em.gold, 85)

func test_diamond_doubler():
    sm.data.economy.diamond_doubler = true
    em.diamond_doubler = true
    em.add_diamonds(100)
    assert_eq(em.diamonds, 200)
```

- [ ] **Step 2: Run all tests**

Run: GUT > Run All Tests
Expected: All tests PASS across all test files

- [ ] **Step 3: Commit**

```bash
git add tests/test_integration_foundation.gd
git commit -m "feat: add integration smoke tests for foundation systems"
```
