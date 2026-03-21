# Plan 4: Wave System + Difficulty + Adaptation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the wave spawning system, early-send bonus, game loop orchestration (building → wave → complete → repeat), difficulty scaling, the adaptive resistance engine, and star rating calculation.

**Architecture:** Waves are data-driven via `WaveDefinition` resources. The `WaveManager` spawns enemies according to wave data. The `AdaptationManager` singleton tracks damage per tower type and adjusts enemy resistances. The game scene orchestrates the build/wave cycle.

**Tech Stack:** Godot 4.x, GDScript, GUT

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Sections 5, 6, 7

**Depends on:** Plan 1 (Foundation), Plan 2 (Enemies), Plan 3 (Towers)

---

## File Structure

```
res://
├── core/
│   ├── wave_system/
│   │   ├── wave_definition.gd          # WaveDefinition + SubWaveDefinition Resources
│   │   ├── wave_manager.gd             # Spawns enemies per wave data
│   │   └── wave_generator.gd           # Procedural wave gen for endless mode
│   ├── adaptation/
│   │   └── adaptation_manager.gd       # AdaptationManager singleton
│   └── game_loop.gd                    # Orchestrates build → wave → complete cycle
├── content/
│   └── waves/                          # Wave .tres files per level
└── tests/
    ├── test_wave_definition.gd
    ├── test_wave_manager.gd
    ├── test_adaptation_manager.gd
    ├── test_game_loop.gd
    └── test_wave_generator.gd
```

---

### Task 1: Create WaveDefinition Resources

**Files:**
- Create: `core/wave_system/wave_definition.gd`
- Test: `tests/test_wave_definition.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_wave_definition.gd
extends GutTest

func test_create_sub_wave():
    var sw := SubWaveDefinition.new()
    sw.enemy_id = "scout"
    sw.count = 10
    sw.spawn_interval = 0.3
    sw.delay = 0.0
    assert_eq(sw.enemy_id, "scout")
    assert_eq(sw.count, 10)

func test_create_wave_definition():
    var wave := WaveDefinition.new()
    wave.wave_number = 5
    var sw := SubWaveDefinition.new()
    sw.enemy_id = "scout"
    sw.count = 10
    wave.sub_waves.append(sw)
    assert_eq(wave.sub_waves.size(), 1)
    assert_eq(wave.get_total_enemy_count(), 10)

func test_wave_total_enemies_multiple_sub_waves():
    var wave := WaveDefinition.new()
    var sw1 := SubWaveDefinition.new()
    sw1.count = 10
    var sw2 := SubWaveDefinition.new()
    sw2.count = 5
    wave.sub_waves.append(sw1)
    wave.sub_waves.append(sw2)
    assert_eq(wave.get_total_enemy_count(), 15)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/wave_system/wave_definition.gd
class_name WaveDefinition
extends Resource

@export var wave_number: int = 1
@export var sub_waves: Array[SubWaveDefinition] = []
@export var is_boss_wave: bool = false

func get_total_enemy_count() -> int:
    var total := 0
    for sw in sub_waves:
        total += sw.count
    return total


class SubWaveDefinition:
    extends Resource
    @export var enemy_id: String = ""
    @export var count: int = 1
    @export var spawn_interval: float = 0.5
    @export var delay: float = 0.0
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/wave_system/wave_definition.gd tests/test_wave_definition.gd
git commit -m "feat: create WaveDefinition and SubWaveDefinition resources"
```

---

### Task 2: Implement WaveManager

**Files:**
- Create: `core/wave_system/wave_manager.gd`
- Test: `tests/test_wave_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_wave_manager.gd
extends GutTest

var wm: WaveManager

func before_each():
    wm = WaveManager.new()
    add_child(wm)

func after_each():
    wm.queue_free()

func test_initial_state():
    assert_eq(wm.current_wave_index, -1)
    assert_false(wm.is_wave_active)

func test_load_waves():
    var waves: Array[WaveDefinition] = []
    var w := WaveDefinition.new()
    w.wave_number = 1
    waves.append(w)
    wm.load_waves(waves)
    assert_eq(wm.total_waves, 1)

func test_start_next_wave():
    var waves: Array[WaveDefinition] = []
    var w := WaveDefinition.new()
    w.wave_number = 1
    var sw := SubWaveDefinition.new()
    sw.enemy_id = "scout"
    sw.count = 3
    sw.spawn_interval = 0.1
    sw.delay = 0.0
    w.sub_waves.append(sw)
    waves.append(w)
    wm.load_waves(waves)

    watch_signals(wm)
    wm.start_next_wave()
    assert_true(wm.is_wave_active)
    assert_eq(wm.current_wave_index, 0)
    assert_signal_emitted(wm, "wave_started")

func test_has_more_waves():
    var waves: Array[WaveDefinition] = []
    waves.append(WaveDefinition.new())
    waves.append(WaveDefinition.new())
    wm.load_waves(waves)
    assert_true(wm.has_more_waves())
    wm.current_wave_index = 1
    assert_false(wm.has_more_waves())

func test_early_send_bonus():
    wm._break_timer = 3.0
    var bonus := wm.get_early_send_bonus()
    assert_gt(bonus, 0)

func test_all_waves_complete_signal():
    var waves: Array[WaveDefinition] = []
    var w := WaveDefinition.new()
    w.wave_number = 1
    waves.append(w)
    wm.load_waves(waves)
    wm.current_wave_index = 0
    wm.is_wave_active = false
    watch_signals(wm)
    wm.on_wave_enemies_cleared()
    assert_signal_emitted(wm, "all_waves_complete")
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/wave_system/wave_manager.gd
class_name WaveManager
extends Node

signal wave_started(wave_number: int, total_waves: int)
signal wave_complete(wave_number: int)
signal all_waves_complete()
signal enemy_spawn_requested(enemy_id: String)
signal break_started(duration: float)

var current_wave_index: int = -1
var total_waves: int = 0
var is_wave_active: bool = false

var _waves: Array[WaveDefinition] = []
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _break_timer: float = 0.0
var _is_break: bool = false
var _enemies_alive: int = 0


func load_waves(waves: Array[WaveDefinition]) -> void:
    _waves = waves
    total_waves = waves.size()
    current_wave_index = -1


func start_next_wave() -> void:
    if not has_more_waves():
        return
    _is_break = false
    current_wave_index += 1
    is_wave_active = true
    _build_spawn_queue(_waves[current_wave_index])
    wave_started.emit(current_wave_index + 1, total_waves)


func has_more_waves() -> bool:
    return current_wave_index < total_waves - 1


func get_current_wave() -> WaveDefinition:
    if current_wave_index >= 0 and current_wave_index < _waves.size():
        return _waves[current_wave_index]
    return null


func get_early_send_bonus() -> int:
    if _break_timer <= 0.0:
        return 0
    return int(Constants.EARLY_SEND_GOLD_BONUS * (_break_timer / Constants.WAVE_BREAK_DURATION))


func on_enemy_died() -> void:
    _enemies_alive -= 1
    _check_wave_clear()


func on_enemy_reached_exit() -> void:
    _enemies_alive -= 1
    _check_wave_clear()


func on_wave_enemies_cleared() -> void:
    is_wave_active = false
    wave_complete.emit(current_wave_index + 1)
    if not has_more_waves():
        all_waves_complete.emit()
    else:
        _is_break = true
        _break_timer = Constants.WAVE_BREAK_DURATION
        break_started.emit(_break_timer)


func _process(delta: float) -> void:
    if _is_break:
        _break_timer -= delta
        if _break_timer <= 0.0:
            _is_break = false
            start_next_wave()
        return

    if not is_wave_active or _spawn_queue.is_empty():
        return

    _spawn_timer -= delta
    while _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
        var next: Dictionary = _spawn_queue[0]
        if next.delay > 0.0:
            next.delay -= delta
            if next.delay > 0.0:
                break

        _spawn_queue.pop_front()
        _enemies_alive += 1
        enemy_spawn_requested.emit(next.enemy_id)

        if not _spawn_queue.is_empty():
            _spawn_timer = _spawn_queue[0].get("interval", Constants.DEFAULT_SPAWN_INTERVAL)
        else:
            _spawn_timer = 0.0


func _build_spawn_queue(wave: WaveDefinition) -> void:
    _spawn_queue.clear()
    _enemies_alive = 0
    for sw in wave.sub_waves:
        for i in range(sw.count):
            _spawn_queue.append({
                "enemy_id": sw.enemy_id,
                "interval": sw.spawn_interval,
                "delay": sw.delay if i == 0 else 0.0,
            })
    _spawn_timer = 0.0


func _check_wave_clear() -> void:
    if is_wave_active and _enemies_alive <= 0 and _spawn_queue.is_empty():
        on_wave_enemies_cleared()
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/wave_system/wave_manager.gd tests/test_wave_manager.gd
git commit -m "feat: implement WaveManager with spawning, breaks, and early send"
```

---

### Task 3: Implement AdaptationManager

**Files:**
- Create: `core/adaptation/adaptation_manager.gd`
- Test: `tests/test_adaptation_manager.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_adaptation_manager.gd
extends GutTest

var am: AdaptationManager

func before_each():
    am = AdaptationManager.new()
    add_child(am)

func after_each():
    am.queue_free()

func test_initial_state():
    assert_eq(am.get_resistances().size(), 0)

func test_record_damage():
    am.record_damage(Enums.DamageType.PULSE, 100.0)
    am.record_damage(Enums.DamageType.ARC, 50.0)
    assert_eq(am.get_damage_share(Enums.DamageType.PULSE), 100.0)

func test_check_adaptation_no_trigger():
    am.setup(Enums.Difficulty.NORMAL, false)
    am.record_damage(Enums.DamageType.PULSE, 30.0)
    am.record_damage(Enums.DamageType.ARC, 70.0)
    am.check_adaptation()
    # Pulse = 30%, under 40% threshold, no adaptation
    var resistances := am.get_resistances()
    assert_false(resistances.has(Enums.DamageType.PULSE))

func test_check_adaptation_triggers():
    am.setup(Enums.Difficulty.NORMAL, false)
    am.record_damage(Enums.DamageType.PULSE, 60.0)
    am.record_damage(Enums.DamageType.ARC, 40.0)
    am.check_adaptation()
    # Pulse = 60%, over 40% threshold
    var resistances := am.get_resistances()
    assert_true(resistances.has(Enums.DamageType.PULSE))
    assert_gt(resistances[Enums.DamageType.PULSE], 0.0)

func test_resistance_caps():
    am.setup(Enums.Difficulty.NORMAL, false)
    for i in range(20):
        am.record_damage(Enums.DamageType.PULSE, 100.0)
        am.check_adaptation()
    var resistances := am.get_resistances()
    assert_le(resistances.get(Enums.DamageType.PULSE, 0.0),
              Constants.ADAPTATION_MAX_RESISTANCE)

func test_resistance_caps_endless():
    am.setup(Enums.Difficulty.NORMAL, true)
    for i in range(30):
        am.record_damage(Enums.DamageType.PULSE, 100.0)
        am.check_adaptation()
    var resistances := am.get_resistances()
    assert_le(resistances.get(Enums.DamageType.PULSE, 0.0),
              Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS)

func test_resistance_decays():
    am.setup(Enums.Difficulty.NORMAL, false)
    am.record_damage(Enums.DamageType.PULSE, 100.0)
    am.check_adaptation()
    var r1 := am.get_resistances().get(Enums.DamageType.PULSE, 0.0)
    # Now use different tower
    am.start_new_wave_window()
    am.record_damage(Enums.DamageType.ARC, 100.0)
    am.check_adaptation()
    var r2 := am.get_resistances().get(Enums.DamageType.PULSE, 0.0)
    assert_lt(r2, r1)

func test_reset():
    am.setup(Enums.Difficulty.NORMAL, false)
    am.record_damage(Enums.DamageType.PULSE, 100.0)
    am.check_adaptation()
    am.reset()
    assert_eq(am.get_resistances().size(), 0)

func test_nightmare_lower_threshold():
    am.setup(Enums.Difficulty.NIGHTMARE, false)
    am.record_damage(Enums.DamageType.PULSE, 30.0)
    am.record_damage(Enums.DamageType.ARC, 70.0)
    am.check_adaptation()
    # Pulse = 30%, over Nightmare's 25% threshold
    var resistances := am.get_resistances()
    assert_true(resistances.has(Enums.DamageType.PULSE))
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/adaptation/adaptation_manager.gd
class_name AdaptationManager
extends Node

signal adaptation_changed(resistances: Dictionary)

var _damage_log: Dictionary = {}      # DamageType -> float (accumulated)
var _resistances: Dictionary = {}     # DamageType -> float (0.0 - max)
var _threshold: float = 0.4
var _max_resistance: float = 0.6
var _is_endless: bool = false


func setup(difficulty: Enums.Difficulty, endless: bool) -> void:
    _is_endless = endless
    _threshold = Constants.ADAPTATION_ENDLESS_THRESHOLD if endless \
        else Constants.DIFFICULTY_ADAPTATION_THRESHOLD[difficulty]
    _max_resistance = Constants.ADAPTATION_MAX_RESISTANCE_ENDLESS if endless \
        else Constants.ADAPTATION_MAX_RESISTANCE


func record_damage(damage_type: Enums.DamageType, amount: float) -> void:
    _damage_log[damage_type] = _damage_log.get(damage_type, 0.0) + amount


func get_damage_share(damage_type: Enums.DamageType) -> float:
    return _damage_log.get(damage_type, 0.0)


func check_adaptation() -> void:
    var total := 0.0
    for amount in _damage_log.values():
        total += amount
    if total <= 0.0:
        return

    var dominant_types: Array[Enums.DamageType] = []
    for dtype in _damage_log:
        var share := _damage_log[dtype] / total
        if share > _threshold:
            dominant_types.append(dtype)

    # Increase resistance for dominant types
    for dtype in dominant_types:
        var current := _resistances.get(dtype, 0.0)
        _resistances[dtype] = minf(current + Constants.ADAPTATION_RESISTANCE_INCREMENT,
                                   _max_resistance)

    # Decay resistance for non-dominant types
    var to_remove: Array = []
    for dtype in _resistances:
        if dtype not in dominant_types:
            _resistances[dtype] -= Constants.ADAPTATION_DECAY_RATE
            if _resistances[dtype] <= 0.0:
                to_remove.append(dtype)
    for dtype in to_remove:
        _resistances.erase(dtype)

    adaptation_changed.emit(_resistances)


func start_new_wave_window() -> void:
    _damage_log.clear()


func get_resistances() -> Dictionary:
    return _resistances


func reset() -> void:
    _damage_log.clear()
    _resistances.clear()
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Register as autoload, commit**

```bash
git add core/adaptation/adaptation_manager.gd tests/test_adaptation_manager.gd project.godot
git commit -m "feat: implement AdaptationManager with resistance tracking"
```

---

### Task 4: Implement GameLoop Orchestrator

**Files:**
- Create: `core/game_loop.gd`
- Test: `tests/test_game_loop.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_game_loop.gd
extends GutTest

var game_loop: GameLoop
var gm: GameManager
var em: EconomyManager
var wm: WaveManager
var am: AdaptationManager

func before_each():
    gm = GameManager.new()
    em = EconomyManager.new()
    wm = WaveManager.new()
    am = AdaptationManager.new()
    game_loop = GameLoop.new()
    add_child(gm)
    add_child(em)
    add_child(wm)
    add_child(am)
    add_child(game_loop)
    game_loop.setup(gm, em, wm, am)

func after_each():
    game_loop.queue_free()
    am.queue_free()
    wm.queue_free()
    em.queue_free()
    gm.queue_free()

func test_start_level_initializes_systems():
    var waves: Array[WaveDefinition] = [WaveDefinition.new()]
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, waves)
    assert_eq(gm.current_state, Enums.GameState.BUILDING)
    assert_eq(em.gold, 0)

func test_send_wave_changes_state():
    var w := WaveDefinition.new()
    var sw := SubWaveDefinition.new()
    sw.enemy_id = "scout"
    sw.count = 1
    sw.spawn_interval = 0.1
    w.sub_waves.append(sw)
    var waves: Array[WaveDefinition] = [w]
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, waves)
    game_loop.send_wave()
    assert_eq(gm.current_state, Enums.GameState.WAVE_ACTIVE)

func test_enemy_death_grants_gold():
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, [WaveDefinition.new()])
    game_loop.on_enemy_killed(10)
    assert_eq(em.gold, 10)

func test_enemy_reach_exit_loses_life():
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, [WaveDefinition.new()])
    game_loop.on_enemy_reached_exit()
    assert_eq(gm.lives, 19)

func test_all_waves_complete_triggers_victory():
    var waves: Array[WaveDefinition] = [WaveDefinition.new()]
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, waves)
    wm.load_waves(waves)
    wm.current_wave_index = 0
    game_loop.on_all_waves_complete()
    assert_eq(gm.current_state, Enums.GameState.VICTORY)

func test_adaptation_checked_every_3_waves():
    var waves: Array[WaveDefinition] = []
    for i in range(4):
        waves.append(WaveDefinition.new())
    game_loop.start_level("level_1_1", Enums.Difficulty.NORMAL, waves)
    am.setup(Enums.Difficulty.NORMAL, false)
    am.record_damage(Enums.DamageType.PULSE, 100.0)
    game_loop._waves_since_adaptation_check = 2
    game_loop.on_wave_complete(3)
    # Should have triggered adaptation check
    assert_eq(game_loop._waves_since_adaptation_check, 0)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/game_loop.gd
class_name GameLoop
extends Node

signal level_victory(level_id: String, stars: int, diamonds: int)
signal level_defeat(level_id: String)

var _gm: GameManager
var _em: EconomyManager
var _wm: WaveManager
var _am: AdaptationManager
var _waves_since_adaptation_check: int = 0


func setup(gm: GameManager, em: EconomyManager, wm: WaveManager, am: AdaptationManager) -> void:
    _gm = gm
    _em = em
    _wm = wm
    _am = am
    _wm.wave_complete.connect(on_wave_complete)
    _wm.all_waves_complete.connect(on_all_waves_complete)


func start_level(level_id: String, difficulty: Enums.Difficulty,
        waves: Array[WaveDefinition]) -> void:
    _gm.start_level(level_id, difficulty)
    _em.reset_match_economy()
    _em.set_gold_modifier(Constants.DIFFICULTY_GOLD_MULT[difficulty])
    _wm.load_waves(waves)
    _am.setup(difficulty, false)
    _am.reset()
    _waves_since_adaptation_check = 0


func send_wave() -> void:
    if _wm.has_more_waves() or _wm.current_wave_index == -1:
        var bonus := _wm.get_early_send_bonus()
        if bonus > 0:
            _em.add_gold(bonus)
        _wm.start_next_wave()
        _gm.change_state(Enums.GameState.WAVE_ACTIVE)


func on_enemy_killed(gold_value: int) -> void:
    _em.add_gold(gold_value)
    _wm.on_enemy_died()
    _am.record_damage(Enums.DamageType.PULSE, 0.0)  # Actual damage recorded by tower


func on_enemy_reached_exit() -> void:
    _gm.lose_life()
    _wm.on_enemy_reached_exit()


func on_wave_complete(wave_number: int) -> void:
    _waves_since_adaptation_check += 1
    if _waves_since_adaptation_check >= Constants.ADAPTATION_CHECK_INTERVAL:
        _am.check_adaptation()
        _am.start_new_wave_window()
        _waves_since_adaptation_check = 0
    _gm.change_state(Enums.GameState.WAVE_COMPLETE)


func on_all_waves_complete() -> void:
    var stars := _gm.calculate_stars()
    var base_diamonds := 50 + stars * 25
    var diamond_mult := Constants.DIFFICULTY_DIAMOND_MULT[_gm.current_difficulty]
    var diamonds := int(base_diamonds * diamond_mult)
    _em.add_diamonds(diamonds)
    _gm.complete_level()
    level_victory.emit(_gm.current_level_id, stars, diamonds)
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/game_loop.gd tests/test_game_loop.gd
git commit -m "feat: implement GameLoop orchestrating waves, economy, and adaptation"
```

---

### Task 5: Implement WaveGenerator (Endless Mode)

**Files:**
- Create: `core/wave_system/wave_generator.gd`
- Test: `tests/test_wave_generator.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_wave_generator.gd
extends GutTest

var gen: WaveGenerator

func before_each():
    gen = WaveGenerator.new()

func test_generate_wave_returns_valid():
    var wave := gen.generate_wave(1, Enums.Difficulty.NORMAL)
    assert_not_null(wave)
    assert_gt(wave.sub_waves.size(), 0)
    assert_gt(wave.get_total_enemy_count(), 0)

func test_waves_scale_with_number():
    var wave_1 := gen.generate_wave(1, Enums.Difficulty.NORMAL)
    var wave_20 := gen.generate_wave(20, Enums.Difficulty.NORMAL)
    assert_gt(wave_20.get_total_enemy_count(), wave_1.get_total_enemy_count())

func test_boss_wave_every_10():
    var wave_10 := gen.generate_wave(10, Enums.Difficulty.NORMAL)
    assert_true(wave_10.is_boss_wave)
    var wave_5 := gen.generate_wave(5, Enums.Difficulty.NORMAL)
    assert_false(wave_5.is_boss_wave)

func test_all_archetypes_available():
    # After wave 30, all enemy types should appear
    var seen := {}
    for i in range(30, 40):
        var wave := gen.generate_wave(i, Enums.Difficulty.NORMAL)
        for sw in wave.sub_waves:
            seen[sw.enemy_id] = true
    assert_gte(seen.size(), 4)  # At least 4 different enemy types
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/wave_system/wave_generator.gd
class_name WaveGenerator
extends RefCounted

## Procedurally generates waves for endless mode.

const ENEMY_POOL := ["scout", "drone", "tank", "flyer", "shielder", "healer"]
const UNLOCK_WAVE := {"scout": 1, "drone": 1, "tank": 5, "flyer": 8, "shielder": 12, "healer": 18}


func generate_wave(wave_number: int, difficulty: Enums.Difficulty) -> WaveDefinition:
    var wave := WaveDefinition.new()
    wave.wave_number = wave_number
    wave.is_boss_wave = wave_number % 10 == 0

    var available := _get_available_enemies(wave_number)
    var base_count := 5 + wave_number * 2
    var hp_scale := 1.0 + wave_number * 0.1

    if wave.is_boss_wave:
        # Boss + escorts
        var boss_sw := SubWaveDefinition.new()
        boss_sw.enemy_id = available[randi() % available.size()]
        boss_sw.count = 1
        boss_sw.spawn_interval = 0.0
        boss_sw.delay = 2.0
        wave.sub_waves.append(boss_sw)
        base_count = int(base_count * 0.5)

    # Main sub-waves (1-3 groups)
    var groups := mini(1 + wave_number / 5, 3)
    for g in range(groups):
        var sw := SubWaveDefinition.new()
        sw.enemy_id = available[randi() % available.size()]
        sw.count = maxi(int(base_count / groups), 1)
        sw.spawn_interval = maxf(0.5 - wave_number * 0.01, 0.15)
        sw.delay = g * 2.0
        wave.sub_waves.append(sw)

    return wave


func _get_available_enemies(wave_number: int) -> Array[String]:
    var available: Array[String] = []
    for enemy_id in ENEMY_POOL:
        if wave_number >= UNLOCK_WAVE[enemy_id]:
            available.append(enemy_id)
    return available
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/wave_system/wave_generator.gd tests/test_wave_generator.gd
git commit -m "feat: implement WaveGenerator for endless mode"
```
