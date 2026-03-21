# Plan 8: Content + Monetization + Endless Mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the campaign content (5 regions, 38-48 levels, boss encounters), endless mode, monetization layer (IAP + rewarded ads), story dialogue system, and wire everything into a complete playable game.

**Architecture:** Levels are `.tscn` scenes paired with `LevelDefinition` resources. Campaign progression is managed by a `CampaignManager` that tracks region unlocks and level availability. Monetization uses Godot's IAP plugin interface. Endless mode reuses the game scene with the WaveGenerator from Plan 4. Story dialogue is shown via a simple overlay between levels.

**Tech Stack:** Godot 4.x, GDScript, GUT

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Sections 2, 8, 9

**Depends on:** Plans 1-7 (all systems)

---

## File Structure

```
res://
├── core/
│   ├── campaign/
│   │   ├── campaign_manager.gd         # Campaign progression logic
│   │   └── level_registry.gd           # Registry of all level definitions
│   ├── endless/
│   │   └── endless_manager.gd          # Endless mode orchestrator
│   ├── monetization/
│   │   ├── iap_manager.gd              # In-app purchase interface
│   │   └── ad_manager.gd               # Rewarded ads interface
│   └── story/
│       └── dialogue_overlay.gd         # Story text display between levels
├── content/
│   ├── levels/
│   │   ├── region_1/                   # 8-10 level .tscn + .tres per level
│   │   ├── region_2/
│   │   ├── region_3/
│   │   ├── region_4/
│   │   └── region_5/
│   └── story/
│       └── dialogues.tres              # Story dialogue data
├── scenes/
│   ├── game.tscn                       # (already exists — wire up fully)
│   ├── main.tscn                       # Root scene with screen management
│   └── endless.tscn                    # Endless mode scene
├── ui/
│   └── story/
│       └── dialogue_overlay.tscn/.gd
└── tests/
    ├── test_campaign_manager.gd
    ├── test_level_registry.gd
    ├── test_endless_manager.gd
    └── test_integration_full_game.gd
```

---

### Task 1: Implement LevelRegistry

**Files:**
- Create: `core/campaign/level_registry.gd`
- Test: `tests/test_level_registry.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_level_registry.gd
extends GutTest

var registry: LevelRegistry

func before_each():
    registry = LevelRegistry.new()
    registry.register_levels()

func test_has_5_regions():
    assert_eq(registry.get_region_count(), 5)

func test_region_1_has_levels():
    var levels := registry.get_levels_for_region(1)
    assert_gte(levels.size(), 8)

func test_get_level_by_id():
    var level := registry.get_level("level_1_1")
    assert_not_null(level)
    assert_eq(level.region, 1)

func test_total_level_count():
    var total := registry.get_total_level_count()
    assert_gte(total, 38)
    assert_le(total, 48)

func test_levels_have_waves():
    var level := registry.get_level("level_1_1")
    assert_gt(level.wave_count, 0)

func test_region_5_has_final_boss():
    var levels := registry.get_levels_for_region(5)
    var last: Dictionary = levels[-1]
    assert_true(last.has_final_boss)

func test_get_region_tower_unlock():
    assert_eq(registry.get_tower_unlock_for_region(2), "beam_spire")
    assert_eq(registry.get_tower_unlock_for_region(3), "nano_hive")
    assert_eq(registry.get_tower_unlock_for_region(4), "harvester")
    assert_eq(registry.get_tower_unlock_for_region(5), "")
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/campaign/level_registry.gd
class_name LevelRegistry
extends RefCounted

var _levels: Dictionary = {}     # level_id -> Dictionary
var _regions: Dictionary = {}    # region_number -> Array[String] (level_ids)

const REGION_TOWER_UNLOCKS := {
    2: "beam_spire", 3: "nano_hive", 4: "harvester", 5: ""
}

const REGION_ENEMY_UNLOCKS := {
    1: ["scout", "drone"],
    2: ["tank", "flyer"],
    3: ["shielder"],
    4: ["healer"],
    5: [],
}


func register_levels() -> void:
    # Region 1: Orbital Station (10 levels, fixed path, tutorial)
    _register_region(1, 10, "Orbital Station", Enums.MapMode.FIXED_PATH, 15, false)
    # Region 2: Asteroid Belt (10 levels, introduces maze)
    _register_region(2, 10, "Asteroid Belt", Enums.MapMode.GRID_MAZE, 18, false)
    # Region 3: Deep Space (9 levels, adaptation)
    _register_region(3, 9, "Deep Space", Enums.MapMode.FIXED_PATH, 22, false)
    # Region 4: Convergence Periphery (9 levels, mixed)
    _register_region(4, 9, "Convergence Periphery", Enums.MapMode.FIXED_PATH, 25, false)
    # Region 5: The Core (8 levels, final boss)
    _register_region(5, 8, "The Core", Enums.MapMode.GRID_MAZE, 28, true)


func get_region_count() -> int:
    return _regions.size()


func get_levels_for_region(region: int) -> Array:
    var ids: Array = _regions.get(region, [])
    var levels: Array = []
    for id in ids:
        levels.append(_levels[id])
    return levels


func get_level(level_id: String) -> Dictionary:
    return _levels.get(level_id, {})


func get_total_level_count() -> int:
    return _levels.size()


func get_tower_unlock_for_region(region: int) -> String:
    return REGION_TOWER_UNLOCKS.get(region, "")


func _register_region(region: int, count: int, region_name: String,
        default_mode: Enums.MapMode, base_wave_count: int, has_final: bool) -> void:
    _regions[region] = []
    for i in range(count):
        var level_id := "level_%d_%d" % [region, i + 1]
        var is_boss := (i == count - 1)
        var is_final := is_boss and has_final
        var wave_count := base_wave_count + i
        if is_boss:
            wave_count += 5

        # Alternate map modes for variety in later regions
        var map_mode := default_mode
        if region >= 3 and i % 3 == 2:
            map_mode = Enums.MapMode.GRID_MAZE if default_mode == Enums.MapMode.FIXED_PATH \
                else Enums.MapMode.FIXED_PATH

        _levels[level_id] = {
            "id": level_id,
            "region": region,
            "region_name": region_name,
            "display_name": "LEVEL_%d_%d" % [region, i + 1],
            "level_number": i + 1,
            "map_mode": map_mode,
            "wave_count": wave_count,
            "is_boss_level": is_boss,
            "has_final_boss": is_final,
        }
        _regions[region].append(level_id)
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/campaign/level_registry.gd tests/test_level_registry.gd
git commit -m "feat: implement LevelRegistry with 5 regions and 46 levels"
```

---

### Task 2: Implement CampaignManager

**Files:**
- Create: `core/campaign/campaign_manager.gd`
- Test: `tests/test_campaign_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_campaign_manager.gd
extends GutTest

var cm: CampaignManager
var sm: SaveManager

func before_each():
    sm = SaveManager.new()
    sm.save_path = "user://test_campaign_save.json"
    add_child(sm)
    cm = CampaignManager.new()
    add_child(cm)
    cm.setup(sm)

func after_each():
    cm.queue_free()
    sm.queue_free()
    if FileAccess.file_exists("user://test_campaign_save.json"):
        DirAccess.remove_absolute("user://test_campaign_save.json")

func test_first_level_unlocked():
    assert_true(cm.is_level_unlocked("level_1_1"))

func test_second_level_locked_initially():
    assert_false(cm.is_level_unlocked("level_1_2"))

func test_completing_level_unlocks_next():
    cm.on_level_complete("level_1_1", 3, Enums.Difficulty.NORMAL)
    assert_true(cm.is_level_unlocked("level_1_2"))

func test_completing_region_unlocks_tower():
    # Complete all region 1 levels
    for i in range(10):
        cm.on_level_complete("level_1_%d" % (i + 1), 1, Enums.Difficulty.NORMAL)
    var unlocked := cm.get_unlocked_towers()
    assert_has(unlocked, "beam_spire")

func test_completing_all_regions_unlocks_endless():
    for region in range(1, 6):
        var count := cm._registry.get_levels_for_region(region).size()
        for i in range(count):
            cm.on_level_complete("level_%d_%d" % [region, i + 1], 1, Enums.Difficulty.NORMAL)
    assert_true(cm.is_endless_unlocked())

func test_get_current_region():
    assert_eq(cm.get_current_region(), 1)
    for i in range(10):
        cm.on_level_complete("level_1_%d" % (i + 1), 1, Enums.Difficulty.NORMAL)
    assert_eq(cm.get_current_region(), 2)

func test_get_total_stars():
    cm.on_level_complete("level_1_1", 3, Enums.Difficulty.NORMAL)
    cm.on_level_complete("level_1_2", 2, Enums.Difficulty.NORMAL)
    assert_eq(cm.get_total_stars(), 5)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/campaign/campaign_manager.gd
class_name CampaignManager
extends Node

signal level_unlocked(level_id: String)
signal region_unlocked(region: int)
signal tower_unlocked(tower_id: String)
signal endless_unlocked()

var _sm: SaveManager
var _registry: LevelRegistry

const STARTING_TOWERS := ["pulse_cannon", "arc_emitter", "cryo_array", "missile_pod"]


func setup(sm: SaveManager) -> void:
    _sm = sm
    _registry = LevelRegistry.new()
    _registry.register_levels()


func is_level_unlocked(level_id: String) -> bool:
    var level := _registry.get_level(level_id)
    if level.is_empty():
        return false
    # First level of region 1 is always unlocked
    if level.region == 1 and level.level_number == 1:
        return true
    # Otherwise, previous level must be completed
    var prev_id := "level_%d_%d" % [level.region, level.level_number - 1]
    if level.level_number == 1:
        # First level of a new region — last level of previous region must be complete
        var prev_region := level.region - 1
        var prev_levels := _registry.get_levels_for_region(prev_region)
        if prev_levels.is_empty():
            return false
        prev_id = prev_levels[-1].id
    return prev_id in _sm.data.campaign.levels_completed


func on_level_complete(level_id: String, stars: int, difficulty: Enums.Difficulty) -> void:
    _sm.set_level_complete(level_id, stars, difficulty)
    var level := _registry.get_level(level_id)

    # Check if next level is now unlocked
    var next_id := "level_%d_%d" % [level.region, level.level_number + 1]
    var next := _registry.get_level(next_id)
    if not next.is_empty():
        level_unlocked.emit(next_id)

    # Check if region is complete
    if level.is_boss_level:
        var new_region := level.region + 1
        if new_region <= 5:
            region_unlocked.emit(new_region)
            var tower := _registry.get_tower_unlock_for_region(new_region)
            if tower != "":
                tower_unlocked.emit(tower)

    # Check if all regions complete
    if _are_all_regions_complete():
        _sm.data.campaign.endless_unlocked = true
        endless_unlocked.emit()

    _sm.save_game()


func is_endless_unlocked() -> bool:
    return _sm.data.campaign.endless_unlocked


func get_current_region() -> int:
    for region in range(1, 6):
        var levels := _registry.get_levels_for_region(region)
        for level in levels:
            if level.id not in _sm.data.campaign.levels_completed:
                return region
    return 5


func get_unlocked_towers() -> Array[String]:
    var towers: Array[String] = STARTING_TOWERS.duplicate()
    for region in range(2, 6):
        var prev_region_levels := _registry.get_levels_for_region(region - 1)
        if prev_region_levels.is_empty():
            continue
        var boss_id: String = prev_region_levels[-1].id
        if boss_id in _sm.data.campaign.levels_completed:
            var tower := _registry.get_tower_unlock_for_region(region)
            if tower != "":
                towers.append(tower)
    return towers


func get_total_stars() -> int:
    var total := 0
    for level_data in _sm.data.campaign.levels_completed.values():
        total += level_data.get("stars", 0)
    return total


func _are_all_regions_complete() -> bool:
    for region in range(1, 6):
        var levels := _registry.get_levels_for_region(region)
        for level in levels:
            if level.id not in _sm.data.campaign.levels_completed:
                return false
    return true
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/campaign/campaign_manager.gd tests/test_campaign_manager.gd
git commit -m "feat: implement CampaignManager with region progression and unlocks"
```

---

### Task 3: Implement EndlessManager

**Files:**
- Create: `core/endless/endless_manager.gd`
- Test: `tests/test_endless_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_endless_manager.gd
extends GutTest

var em: EndlessManager

func before_each():
    em = EndlessManager.new()
    add_child(em)

func after_each():
    em.queue_free()

func test_initial_wave_is_1():
    em.start(Enums.Difficulty.NORMAL)
    assert_eq(em.current_wave, 0)

func test_next_wave_increments():
    em.start(Enums.Difficulty.NORMAL)
    var wave := em.generate_next_wave()
    assert_not_null(wave)
    assert_eq(em.current_wave, 1)

func test_milestone_diamonds():
    assert_eq(em.get_milestone_diamonds(10), 50)
    assert_eq(em.get_milestone_diamonds(25), 100)
    assert_eq(em.get_milestone_diamonds(50), 200)

func test_is_milestone():
    assert_true(em.is_milestone(10))
    assert_true(em.is_milestone(25))
    assert_false(em.is_milestone(7))

func test_get_high_score():
    em.start(Enums.Difficulty.NORMAL)
    em.current_wave = 42
    em.record_high_score()
    assert_eq(em.get_high_score(Enums.Difficulty.NORMAL), 42)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/endless/endless_manager.gd
class_name EndlessManager
extends Node

signal milestone_reached(wave: int, diamonds: int)

var current_wave: int = 0
var _difficulty: Enums.Difficulty
var _generator: WaveGenerator
var _high_scores: Dictionary = {}

const MILESTONES := {10: 50, 25: 100, 50: 200, 75: 300, 100: 500}


func start(difficulty: Enums.Difficulty) -> void:
    _difficulty = difficulty
    current_wave = 0
    _generator = WaveGenerator.new()


func generate_next_wave() -> WaveDefinition:
    current_wave += 1
    var wave := _generator.generate_wave(current_wave, _difficulty)

    if is_milestone(current_wave):
        var diamonds := get_milestone_diamonds(current_wave)
        milestone_reached.emit(current_wave, diamonds)

    return wave


func is_milestone(wave: int) -> bool:
    return wave in MILESTONES


func get_milestone_diamonds(wave: int) -> int:
    return MILESTONES.get(wave, 0)


func record_high_score() -> void:
    var prev := _high_scores.get(_difficulty, 0)
    if current_wave > prev:
        _high_scores[_difficulty] = current_wave


func get_high_score(difficulty: Enums.Difficulty) -> int:
    return _high_scores.get(difficulty, 0)
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/endless/endless_manager.gd tests/test_endless_manager.gd
git commit -m "feat: implement EndlessManager with milestones and high scores"
```

---

### Task 4: Implement Monetization Layer

**Files:**
- Create: `core/monetization/iap_manager.gd`
- Create: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Write IAPManager**

```gdscript
# core/monetization/iap_manager.gd
class_name IAPManager
extends Node

## Interface for in-app purchases.
## Actual platform implementation (Google Play, App Store) will be
## connected via Godot plugins. This provides the game-side logic.

signal purchase_complete(pack_id: String, diamonds: int)
signal purchase_failed(pack_id: String, reason: String)

const PACKS := {
    "small": {"diamonds": 500, "price_usd": 0.99},
    "medium": {"diamonds": 2000, "price_usd": 3.99},
    "large": {"diamonds": 5000, "price_usd": 7.99},
    "doubler": {"diamonds": 0, "price_usd": 4.99},
}


func request_purchase(pack_id: String, economy: EconomyManager, save: SaveManager) -> void:
    if pack_id not in PACKS:
        purchase_failed.emit(pack_id, "Invalid pack")
        return

    # In a real implementation, this would call the platform IAP API
    # and wait for a callback. For now, simulate success.
    var pack: Dictionary = PACKS[pack_id]

    if pack_id == "doubler":
        economy.diamond_doubler = true
        save.data.economy.diamond_doubler = true
    else:
        economy.add_diamonds(pack.diamonds)

    save.data.monetization.iap_history.append({
        "pack_id": pack_id,
        "timestamp": Time.get_unix_time_from_system(),
    })
    save.save_game()
    purchase_complete.emit(pack_id, pack.diamonds)


func has_doubler(save: SaveManager) -> bool:
    return save.data.economy.diamond_doubler
```

- [ ] **Step 2: Write AdManager**

```gdscript
# core/monetization/ad_manager.gd
class_name AdManager
extends Node

## Interface for rewarded video ads.

signal ad_reward_granted(diamonds: int)
signal ad_failed(reason: String)


func can_watch_ad(save: SaveManager) -> bool:
    _check_date_reset(save)
    return save.data.monetization.ads_watched_today < Constants.MAX_ADS_PER_DAY


func get_remaining_ads(save: SaveManager) -> int:
    _check_date_reset(save)
    return Constants.MAX_ADS_PER_DAY - save.data.monetization.ads_watched_today


func request_ad(economy: EconomyManager, save: SaveManager) -> void:
    if not can_watch_ad(save):
        ad_failed.emit("Daily ad limit reached")
        return

    # In a real implementation, show rewarded video ad
    # On success callback:
    _on_ad_complete(economy, save)


func _on_ad_complete(economy: EconomyManager, save: SaveManager) -> void:
    economy.add_diamonds(Constants.DIAMONDS_PER_AD)
    save.data.monetization.ads_watched_today += 1
    save.save_game()
    ad_reward_granted.emit(Constants.DIAMONDS_PER_AD)


func _check_date_reset(save: SaveManager) -> void:
    var today := Time.get_date_string_from_system()
    if save.data.monetization.ads_last_date != today:
        save.data.monetization.ads_watched_today = 0
        save.data.monetization.ads_last_date = today
```

- [ ] **Step 3: Commit**

```bash
git add core/monetization/iap_manager.gd core/monetization/ad_manager.gd
git commit -m "feat: implement IAP and ad manager interfaces"
```

---

### Task 5: Implement Story Dialogue Overlay

**Files:**
- Create: `ui/story/dialogue_overlay.tscn`, `ui/story/dialogue_overlay.gd`

- [ ] **Step 1: Write implementation**

```gdscript
# ui/story/dialogue_overlay.gd
extends CanvasLayer

signal dialogue_finished()

@onready var background: ColorRect = $Background
@onready var text_label: RichTextLabel = $Panel/TextLabel
@onready var continue_btn: Button = $Panel/ContinueButton

var _dialogues: Array[String] = []
var _current_index: int = 0


func _ready() -> void:
    continue_btn.pressed.connect(_next)
    continue_btn.text = tr("UI_CONFIRM")
    hide()


func show_dialogue(dialogue_keys: Array[String]) -> void:
    _dialogues = dialogue_keys
    _current_index = 0
    _display_current()
    show()


func _display_current() -> void:
    if _current_index < _dialogues.size():
        text_label.text = tr(_dialogues[_current_index])
    else:
        hide()
        dialogue_finished.emit()


func _next() -> void:
    _current_index += 1
    _display_current()
```

- [ ] **Step 2: Commit**

```bash
git add ui/story/dialogue_overlay.tscn ui/story/dialogue_overlay.gd
git commit -m "feat: implement story dialogue overlay with i18n"
```

---

### Task 6: Wire Up Main Scene (Root Screen Manager)

**Files:**
- Create: `scenes/main.tscn`, `scenes/main.gd`

- [ ] **Step 1: Write root scene manager**

```gdscript
# scenes/main.gd
extends Node

## Root scene — manages screen transitions between menu, campaign map, game, etc.

var _current_screen: Node = null

@onready var main_menu := preload("res://ui/menus/main_menu.tscn")
@onready var campaign_map := preload("res://ui/meta/campaign_map.tscn")
@onready var settings_menu := preload("res://ui/menus/settings_menu.tscn")
@onready var tower_lab := preload("res://ui/meta/tower_lab.tscn")
@onready var diamond_shop := preload("res://ui/meta/diamond_shop.tscn")
@onready var game_scene := preload("res://scenes/game.tscn")

var _campaign_manager: CampaignManager


func _ready() -> void:
    SaveManager.load_game()
    _campaign_manager = CampaignManager.new()
    add_child(_campaign_manager)
    _campaign_manager.setup(SaveManager)
    _show_main_menu()


func _show_main_menu() -> void:
    _switch_screen(main_menu.instantiate())
    _current_screen.play_campaign.connect(func(): _show_campaign_map())
    _current_screen.play_endless.connect(func(): _start_endless())
    _current_screen.open_tower_lab.connect(func(): _show_tower_lab())
    _current_screen.open_settings.connect(func(): _show_settings())
    _current_screen.set_endless_unlocked(_campaign_manager.is_endless_unlocked())
    AudioManager.set_music_state(Enums.GameState.MENU)


func _show_campaign_map() -> void:
    _switch_screen(campaign_map.instantiate())
    _current_screen.level_chosen.connect(_start_campaign_level)
    _current_screen.back_pressed.connect(func(): _show_main_menu())


func _start_campaign_level(level_id: String, difficulty: Enums.Difficulty) -> void:
    var game := game_scene.instantiate()
    _switch_screen(game)
    var level_data := _campaign_manager._registry.get_level(level_id)
    game.start_level(level_id, difficulty)
    AudioManager.set_music_region(level_data.region)
    AudioManager.set_music_state(Enums.GameState.BUILDING)


func _start_endless() -> void:
    var game := game_scene.instantiate()
    _switch_screen(game)
    # Endless mode setup handled by game scene
    AudioManager.set_music_region(5)
    AudioManager.set_music_state(Enums.GameState.BUILDING)


func _show_tower_lab() -> void:
    _switch_screen(tower_lab.instantiate())
    _current_screen.back_pressed.connect(func(): _show_main_menu())


func _show_settings() -> void:
    _switch_screen(settings_menu.instantiate())
    _current_screen.back_pressed.connect(func(): _show_main_menu())


func _switch_screen(new_screen: Node) -> void:
    if _current_screen:
        _current_screen.queue_free()
    _current_screen = new_screen
    add_child(_current_screen)
```

- [ ] **Step 2: Update project.godot main scene**

```ini
run/main_scene="res://scenes/main.tscn"
```

- [ ] **Step 3: Commit**

```bash
git add scenes/main.tscn scenes/main.gd project.godot
git commit -m "feat: implement root scene manager with screen transitions"
```

---

### Task 7: Create Initial Campaign Level Content (Region 1)

**Files:**
- Create: `content/levels/region_1/level_1_1.tres` (and wave data)

- [ ] **Step 1: Create first playable level data**

For the first 3 levels of Region 1, create `WaveDefinition` resources with hand-crafted wave compositions:

**Level 1-1: Tutorial (10 waves)**
| Wave | Enemies |
|------|---------|
| 1 | 5x Scout |
| 2 | 8x Scout |
| 3 | 3x Drone |
| 4 | 10x Scout + 2x Drone |
| 5 | 5x Drone |
| 6 | 12x Scout |
| 7 | 6x Drone |
| 8 | 15x Scout + 4x Drone |
| 9 | 8x Drone |
| 10 | BOSS: 1x Drone Boss + 10x Scout |

Create these as `.tres` resources in Godot editor.

- [ ] **Step 2: Create the level scene (.tscn)**

For level 1-1 (fixed path):
- Node2D root with a Path2D that curves through the screen
- Define build spots alongside the path
- Set background color to dark blue (space station theme)

- [ ] **Step 3: Commit**

```bash
git add content/levels/region_1/
git commit -m "feat: create Region 1 first 3 campaign levels"
```

---

### Task 8: Full Integration Test

**Files:**
- Test: `tests/test_integration_full_game.gd`

- [ ] **Step 1: Write integration test**

```gdscript
# tests/test_integration_full_game.gd
extends GutTest

## Verifies the complete game flow: menu → campaign → level → victory → progression

func test_complete_level_flow():
    var sm := SaveManager.new()
    sm.save_path = "user://test_full_game_save.json"
    add_child(sm)
    var gm := GameManager.new()
    var em := EconomyManager.new()
    var wm := WaveManager.new()
    var am := AdaptationManager.new()
    var game_loop := GameLoop.new()
    var pm := ProgressionManager.new()
    var cm := CampaignManager.new()
    add_child(gm)
    add_child(em)
    add_child(wm)
    add_child(am)
    add_child(game_loop)
    add_child(pm)
    add_child(cm)

    cm.setup(sm)
    pm.setup(em, sm)
    game_loop.setup(gm, em, wm, am)

    # Start level
    var waves: Array[WaveDefinition] = [WaveDefinition.new()]
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, waves)
    assert_eq(gm.current_state, Enums.GameState.BUILDING)

    # Simulate wave completion
    wm.load_waves(waves)
    wm.current_wave_index = 0
    game_loop.on_all_waves_complete()
    assert_eq(gm.current_state, Enums.GameState.VICTORY)

    # Record in campaign
    var stars := gm.calculate_stars()
    cm.on_level_complete("level_1_1", stars, Enums.Difficulty.NORMAL)
    assert_true(cm.is_level_unlocked("level_1_2"))

    # Verify diamonds earned
    assert_gt(em.diamonds, 0)

    # Spend diamonds on skill unlock
    var initial_diamonds := em.diamonds
    if initial_diamonds >= 80:
        var result := pm.unlock_skill_node(Enums.TowerType.PULSE_CANNON, 0)
        assert_true(result)
        assert_eq(em.diamonds, initial_diamonds - 80)

    # Cleanup
    for node in [cm, pm, game_loop, am, wm, em, gm, sm]:
        node.queue_free()
    if FileAccess.file_exists("user://test_full_game_save.json"):
        DirAccess.remove_absolute("user://test_full_game_save.json")

func test_endless_mode_flow():
    var endless := EndlessManager.new()
    add_child(endless)
    endless.start(Enums.Difficulty.NORMAL)

    # Generate waves
    for i in range(25):
        var wave := endless.generate_next_wave()
        assert_not_null(wave)
        assert_gt(wave.get_total_enemy_count(), 0)

    assert_eq(endless.current_wave, 25)
    endless.record_high_score()
    assert_eq(endless.get_high_score(Enums.Difficulty.NORMAL), 25)

    endless.queue_free()
```

- [ ] **Step 2: Run all tests**

Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_integration_full_game.gd
git commit -m "feat: add full game integration tests"
```
