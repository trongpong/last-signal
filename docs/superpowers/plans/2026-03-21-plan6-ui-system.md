# Plan 6: UI System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all UI screens — in-game HUD (lives, gold, wave counter, speed controls), tower build bar, tower upgrade panel, ability bar, main menu, campaign map, Tower Lab, Diamond Shop, and settings. All text uses `tr()` keys.

**Architecture:** UI is organized under `CanvasLayer` nodes. Each screen is a separate scene. HUD elements bind to singleton signals for reactive updates. All text uses translation keys.

**Tech Stack:** Godot 4.x, GDScript, Godot Control nodes

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Section 12

**Depends on:** Plans 1-5 (all systems)

---

## File Structure

```
res://
├── ui/
│   ├── hud/
│   │   ├── hud.tscn                   # Main HUD overlay
│   │   ├── hud.gd
│   │   ├── top_bar.tscn               # Lives, gold, wave, send button
│   │   ├── top_bar.gd
│   │   ├── tower_bar.tscn             # Tower build buttons
│   │   ├── tower_bar.gd
│   │   ├── ability_bar.tscn           # 3 ability slots + hero button
│   │   ├── ability_bar.gd
│   │   ├── tower_upgrade_panel.tscn   # Side panel for upgrades
│   │   ├── tower_upgrade_panel.gd
│   │   └── speed_controls.tscn/.gd
│   ├── menus/
│   │   ├── main_menu.tscn/.gd
│   │   ├── settings_menu.tscn/.gd
│   │   ├── pause_menu.tscn/.gd
│   │   └── level_complete.tscn/.gd
│   ├── tower_ui/
│   │   └── tower_button.tscn/.gd      # Reusable tower build button
│   └── meta/
│       ├── campaign_map.tscn/.gd
│       ├── level_node.tscn/.gd         # Clickable level on map
│       ├── tower_lab.tscn/.gd
│       ├── skill_tree_view.tscn/.gd
│       └── diamond_shop.tscn/.gd
└── tests/
    └── test_ui_translation_keys.gd
```

---

### Task 1: Implement Top Bar HUD

**Files:**
- Create: `ui/hud/top_bar.tscn`, `ui/hud/top_bar.gd`

- [ ] **Step 1: Create the scene**

Scene tree:
```
TopBar (HBoxContainer)
├── LivesLabel (Label) — text: tr("HUD_LIVES") + ": 20"
├── GoldLabel (Label) — text: tr("HUD_GOLD") + ": 350"
├── WaveLabel (Label) — text: tr("HUD_WAVE") + " 5/20"
├── SendButton (Button) — text: tr("HUD_SEND_WAVE")
└── SpeedButton (Button) — text: "1x"
```

- [ ] **Step 2: Write the script**

```gdscript
# ui/hud/top_bar.gd
extends HBoxContainer

signal send_wave_pressed()
signal speed_changed(speed: float)

@onready var lives_label: Label = $LivesLabel
@onready var gold_label: Label = $GoldLabel
@onready var wave_label: Label = $WaveLabel
@onready var send_button: Button = $SendButton
@onready var speed_button: Button = $SpeedButton

var _speed_index: int = 0


func _ready() -> void:
    send_button.pressed.connect(func(): send_wave_pressed.emit())
    speed_button.pressed.connect(_cycle_speed)


func update_lives(lives: int) -> void:
    lives_label.text = tr("HUD_LIVES") + ": %d" % lives


func update_gold(gold: int) -> void:
    gold_label.text = tr("HUD_GOLD") + ": %d" % gold


func update_wave(current: int, total: int) -> void:
    wave_label.text = tr("HUD_WAVE") + " %d/%d" % [current, total]


func set_send_enabled(enabled: bool) -> void:
    send_button.disabled = not enabled


func _cycle_speed() -> void:
    _speed_index = (_speed_index + 1) % Constants.SPEED_OPTIONS.size()
    var speed: float = Constants.SPEED_OPTIONS[_speed_index]
    speed_button.text = "%dx" % int(speed)
    speed_changed.emit(speed)
```

- [ ] **Step 3: Commit**

```bash
git add ui/hud/top_bar.tscn ui/hud/top_bar.gd
git commit -m "feat: implement TopBar HUD with lives, gold, wave, speed"
```

---

### Task 2: Implement Tower Build Bar

**Files:**
- Create: `ui/tower_ui/tower_button.tscn`, `ui/tower_ui/tower_button.gd`
- Create: `ui/hud/tower_bar.tscn`, `ui/hud/tower_bar.gd`

- [ ] **Step 1: Create TowerButton**

```gdscript
# ui/tower_ui/tower_button.gd
extends Button

signal tower_selected(tower_type: Enums.TowerType)

var tower_type: Enums.TowerType
var tower_cost: int = 0


func setup(def: TowerDefinition) -> void:
    tower_type = def.tower_type
    tower_cost = def.cost
    text = tr(def.display_name) + "\n%d" % def.cost
    modulate = def.color
    pressed.connect(func(): tower_selected.emit(tower_type))


func update_affordability(gold: int) -> void:
    disabled = gold < tower_cost
    modulate.a = 1.0 if not disabled else 0.5
```

- [ ] **Step 2: Create TowerBar**

```gdscript
# ui/hud/tower_bar.gd
extends HBoxContainer

signal tower_build_requested(tower_type: Enums.TowerType)

var _buttons: Array[Node] = []


func populate(definitions: Array[TowerDefinition], unlocked: Array[String]) -> void:
    for child in get_children():
        child.queue_free()
    _buttons.clear()

    for def in definitions:
        if def.id not in unlocked:
            continue
        var btn_scene := preload("res://ui/tower_ui/tower_button.tscn")
        var btn := btn_scene.instantiate()
        btn.setup(def)
        btn.tower_selected.connect(func(tt): tower_build_requested.emit(tt))
        add_child(btn)
        _buttons.append(btn)


func update_gold(gold: int) -> void:
    for btn in _buttons:
        btn.update_affordability(gold)
```

- [ ] **Step 3: Commit**

```bash
git add ui/tower_ui/ ui/hud/tower_bar.tscn ui/hud/tower_bar.gd
git commit -m "feat: implement tower build bar with affordability"
```

---

### Task 3: Implement Tower Upgrade Panel

**Files:**
- Create: `ui/hud/tower_upgrade_panel.tscn`, `ui/hud/tower_upgrade_panel.gd`

- [ ] **Step 1: Write the script**

```gdscript
# ui/hud/tower_upgrade_panel.gd
extends PanelContainer

signal upgrade_requested(tower: Tower, choice: int)
signal sell_requested(tower: Tower)
signal targeting_changed(tower: Tower, mode: Enums.TargetingMode)

@onready var tower_name_label: Label = $VBox/TowerName
@onready var stats_label: Label = $VBox/Stats
@onready var tier_label: Label = $VBox/TierLabel
@onready var upgrade_container: VBoxContainer = $VBox/Upgrades
@onready var sell_button: Button = $VBox/SellButton
@onready var targeting_button: Button = $VBox/TargetingButton
@onready var close_button: Button = $VBox/CloseButton

var _current_tower: Tower = null
var _targeting_modes := [
    Enums.TargetingMode.NEAREST,
    Enums.TargetingMode.STRONGEST,
    Enums.TargetingMode.WEAKEST,
    Enums.TargetingMode.FIRST,
    Enums.TargetingMode.LAST,
]
var _targeting_index: int = 0


func _ready() -> void:
    sell_button.pressed.connect(func(): if _current_tower: sell_requested.emit(_current_tower))
    targeting_button.pressed.connect(_cycle_targeting)
    close_button.pressed.connect(func(): hide())
    hide()


func show_for_tower(tower: Tower, sell_value: int) -> void:
    _current_tower = tower
    tower_name_label.text = tr(tower.definition.display_name)
    tier_label.text = "Tier %d" % tower.current_tier
    stats_label.text = "DMG: %.0f | Rate: %.1f | Range: %.0f" % [
        tower.current_damage, tower.current_fire_rate, tower.current_range]
    sell_button.text = tr("HUD_SELL") + " (%d)" % sell_value

    # Show upgrade options
    for child in upgrade_container.get_children():
        child.queue_free()
    var tree := tower.get_tier_tree()
    var options := tree.get_upgrade_options(tower.get_upgrade_path())
    for i in range(options.size()):
        var opt: Dictionary = options[i]
        var btn := Button.new()
        btn.text = tr(opt.get("display_name", opt.name)) + " (%d)" % opt.cost
        var choice := i
        btn.pressed.connect(func(): upgrade_requested.emit(_current_tower, choice))
        upgrade_container.add_child(btn)

    show()


func _cycle_targeting() -> void:
    if not _current_tower:
        return
    _targeting_index = (_targeting_index + 1) % _targeting_modes.size()
    var mode := _targeting_modes[_targeting_index]
    targeting_changed.emit(_current_tower, mode)
    var mode_names := ["Nearest", "Strongest", "Weakest", "First", "Last"]
    targeting_button.text = mode_names[_targeting_index]
```

- [ ] **Step 2: Create the scene in Godot editor matching the node structure**

- [ ] **Step 3: Commit**

```bash
git add ui/hud/tower_upgrade_panel.tscn ui/hud/tower_upgrade_panel.gd
git commit -m "feat: implement tower upgrade panel with tier tree and sell"
```

---

### Task 4: Implement Ability Bar

**Files:**
- Create: `ui/hud/ability_bar.tscn`, `ui/hud/ability_bar.gd`

- [ ] **Step 1: Write the script**

```gdscript
# ui/hud/ability_bar.gd
extends HBoxContainer

signal ability_activated(slot: int)
signal hero_summoned()

var _ability_buttons: Array[Button] = []
var _hero_button: Button


func setup(ability_ids: Array[String], hero_available: bool) -> void:
    for child in get_children():
        child.queue_free()
    _ability_buttons.clear()

    for i in range(ability_ids.size()):
        var btn := Button.new()
        var ability_key := "ABILITY_" + ability_ids[i].to_upper()
        btn.text = tr(ability_key)
        btn.custom_minimum_size = Vector2(100, 50)
        var slot := i
        btn.pressed.connect(func(): ability_activated.emit(slot))
        add_child(btn)
        _ability_buttons.append(btn)

    if hero_available:
        _hero_button = Button.new()
        _hero_button.text = "HERO"
        _hero_button.custom_minimum_size = Vector2(100, 50)
        _hero_button.pressed.connect(func(): hero_summoned.emit())
        add_child(_hero_button)


func update_cooldowns(abilities: Array[Ability]) -> void:
    for i in range(mini(abilities.size(), _ability_buttons.size())):
        var ability := abilities[i]
        var btn := _ability_buttons[i]
        if ability.is_ready():
            btn.disabled = false
            btn.text = tr("ABILITY_" + ability.ability_id.to_upper())
        else:
            btn.disabled = true
            var progress := ability.get_cooldown_progress()
            btn.text = "%d%%" % int(progress * 100)
```

- [ ] **Step 2: Commit**

```bash
git add ui/hud/ability_bar.tscn ui/hud/ability_bar.gd
git commit -m "feat: implement ability bar with cooldown display"
```

---

### Task 5: Assemble Main HUD

**Files:**
- Create: `ui/hud/hud.tscn`, `ui/hud/hud.gd`

- [ ] **Step 1: Create scene tree**

```
HUD (CanvasLayer)
├── TopBar (top of screen)
├── TowerUpgradePanel (right side, hidden by default)
├── BottomContainer (VBoxContainer, anchored bottom)
│   ├── TowerBar
│   └── AbilityBar
└── AdaptationWarning (TextureRect, top-right, hidden)
```

- [ ] **Step 2: Write the connector script**

```gdscript
# ui/hud/hud.gd
extends CanvasLayer

signal build_tower_requested(tower_type: Enums.TowerType)
signal upgrade_tower_requested(tower: Tower, choice: int)
signal sell_tower_requested(tower: Tower)
signal send_wave_requested()
signal ability_used(slot: int)
signal hero_summon_requested()

@onready var top_bar = $TopBar
@onready var tower_bar = $BottomContainer/TowerBar
@onready var ability_bar = $BottomContainer/AbilityBar
@onready var upgrade_panel = $TowerUpgradePanel
@onready var adaptation_warning = $AdaptationWarning


func _ready() -> void:
    top_bar.send_wave_pressed.connect(func(): send_wave_requested.emit())
    top_bar.speed_changed.connect(func(s): GameManager.set_game_speed(s))
    tower_bar.tower_build_requested.connect(func(tt): build_tower_requested.emit(tt))
    upgrade_panel.upgrade_requested.connect(func(t, c): upgrade_tower_requested.emit(t, c))
    upgrade_panel.sell_requested.connect(func(t): sell_tower_requested.emit(t))
    ability_bar.ability_activated.connect(func(s): ability_used.emit(s))
    ability_bar.hero_summoned.connect(func(): hero_summon_requested.emit())


func bind_signals(gm: GameManager, em: EconomyManager, wm: WaveManager) -> void:
    gm.lives_changed.connect(top_bar.update_lives)
    em.gold_changed.connect(top_bar.update_gold)
    em.gold_changed.connect(tower_bar.update_gold)
    wm.wave_started.connect(top_bar.update_wave)


func show_adaptation_warning(visible_flag: bool) -> void:
    adaptation_warning.visible = visible_flag
```

- [ ] **Step 3: Commit**

```bash
git add ui/hud/hud.tscn ui/hud/hud.gd
git commit -m "feat: assemble main HUD connecting all UI components"
```

---

### Task 6: Implement Main Menu

**Files:**
- Create: `ui/menus/main_menu.tscn`, `ui/menus/main_menu.gd`

- [ ] **Step 1: Write the script**

```gdscript
# ui/menus/main_menu.gd
extends Control

signal play_campaign()
signal play_endless()
signal open_tower_lab()
signal open_settings()

@onready var campaign_btn: Button = $VBox/CampaignButton
@onready var endless_btn: Button = $VBox/EndlessButton
@onready var lab_btn: Button = $VBox/TowerLabButton
@onready var settings_btn: Button = $VBox/SettingsButton
@onready var title_label: Label = $VBox/Title


func _ready() -> void:
    title_label.text = "LAST SIGNAL"
    campaign_btn.text = tr("UI_PLAY_CAMPAIGN")
    endless_btn.text = tr("UI_ENDLESS_MODE")
    lab_btn.text = tr("UI_TOWER_LAB")
    settings_btn.text = tr("UI_SETTINGS")

    campaign_btn.pressed.connect(func(): play_campaign.emit())
    endless_btn.pressed.connect(func(): play_endless.emit())
    lab_btn.pressed.connect(func(): open_tower_lab.emit())
    settings_btn.pressed.connect(func(): open_settings.emit())


func set_endless_unlocked(unlocked: bool) -> void:
    endless_btn.disabled = not unlocked
    endless_btn.modulate.a = 1.0 if unlocked else 0.5
```

- [ ] **Step 2: Create scene with centered VBoxContainer layout**

- [ ] **Step 3: Commit**

```bash
git add ui/menus/main_menu.tscn ui/menus/main_menu.gd
git commit -m "feat: implement main menu with i18n"
```

---

### Task 7: Implement Settings Menu

**Files:**
- Create: `ui/menus/settings_menu.tscn`, `ui/menus/settings_menu.gd`

- [ ] **Step 1: Write the script**

```gdscript
# ui/menus/settings_menu.gd
extends Control

signal back_pressed()

@onready var music_slider: HSlider = $VBox/MusicSlider
@onready var sfx_slider: HSlider = $VBox/SFXSlider
@onready var language_dropdown: OptionButton = $VBox/LanguageDropdown
@onready var back_btn: Button = $VBox/BackButton

const LANGUAGES := {"en": "English", "id": "Bahasa Indonesia", "zh": "Chinese", "ja": "Japanese", "ko": "Korean"}


func _ready() -> void:
    back_btn.text = tr("UI_BACK")
    back_btn.pressed.connect(func(): _save_settings(); back_pressed.emit())

    for code in LANGUAGES:
        language_dropdown.add_item(LANGUAGES[code])

    _load_settings()


func _load_settings() -> void:
    var settings: Dictionary = SaveManager.data.profile.settings
    music_slider.value = settings.get("music_vol", 0.8)
    sfx_slider.value = settings.get("sfx_vol", 0.8)


func _save_settings() -> void:
    SaveManager.data.profile.settings.music_vol = music_slider.value
    SaveManager.data.profile.settings.sfx_vol = sfx_slider.value
    var lang_idx := language_dropdown.selected
    if lang_idx >= 0:
        var lang_code: String = LANGUAGES.keys()[lang_idx]
        TranslationServer.set_locale(lang_code)
        SaveManager.data.profile.language = lang_code
    SaveManager.save_game()
```

- [ ] **Step 2: Create scene**

- [ ] **Step 3: Commit**

```bash
git add ui/menus/settings_menu.tscn ui/menus/settings_menu.gd
git commit -m "feat: implement settings menu with language, audio sliders"
```

---

### Task 8: Implement Campaign Map

**Files:**
- Create: `ui/meta/campaign_map.tscn`, `ui/meta/campaign_map.gd`
- Create: `ui/meta/level_node.tscn`, `ui/meta/level_node.gd`

- [ ] **Step 1: Write LevelNode**

```gdscript
# ui/meta/level_node.gd
extends Button

signal level_selected(level_id: String)

var level_id: String = ""
var stars: int = 0
var locked: bool = true


func setup(id: String, display_name: String, p_stars: int, p_locked: bool) -> void:
    level_id = id
    stars = p_stars
    locked = p_locked
    text = tr(display_name) + "\n" + ("*" .repeat(stars) if stars > 0 else "")
    disabled = locked
    pressed.connect(func(): level_selected.emit(level_id))
```

- [ ] **Step 2: Write CampaignMap**

```gdscript
# ui/meta/campaign_map.gd
extends Control

signal level_chosen(level_id: String, difficulty: Enums.Difficulty)
signal back_pressed()

@onready var region_container: VBoxContainer = $ScrollContainer/RegionContainer
@onready var back_btn: Button = $BackButton
@onready var difficulty_selector: OptionButton = $DifficultySelector

var _selected_difficulty: Enums.Difficulty = Enums.Difficulty.NORMAL


func _ready() -> void:
    back_btn.text = tr("UI_BACK")
    back_btn.pressed.connect(func(): back_pressed.emit())
    difficulty_selector.add_item(tr("DIFFICULTY_NORMAL"))
    difficulty_selector.add_item(tr("DIFFICULTY_HARD"))
    difficulty_selector.add_item(tr("DIFFICULTY_NIGHTMARE"))
    difficulty_selector.item_selected.connect(func(idx): _selected_difficulty = idx as Enums.Difficulty)


func populate(levels: Array[Dictionary], save_data: Dictionary) -> void:
    for child in region_container.get_children():
        child.queue_free()

    for level in levels:
        var node_scene := preload("res://ui/meta/level_node.tscn")
        var node := node_scene.instantiate()
        var completed: Dictionary = save_data.campaign.levels_completed
        var stars := completed.get(level.id, {}).get("stars", 0)
        var is_locked: bool = level.get("locked", false)
        node.setup(level.id, level.display_name, stars, is_locked)
        node.level_selected.connect(func(id): level_chosen.emit(id, _selected_difficulty))
        region_container.add_child(node)
```

- [ ] **Step 3: Commit**

```bash
git add ui/meta/campaign_map.tscn ui/meta/campaign_map.gd ui/meta/level_node.tscn ui/meta/level_node.gd
git commit -m "feat: implement campaign map with level nodes and difficulty selector"
```

---

### Task 9: Implement Tower Lab and Diamond Shop

**Files:**
- Create: `ui/meta/tower_lab.tscn`, `ui/meta/tower_lab.gd`
- Create: `ui/meta/diamond_shop.tscn`, `ui/meta/diamond_shop.gd`

- [ ] **Step 1: Write TowerLab**

```gdscript
# ui/meta/tower_lab.gd
extends Control

signal skill_unlock_requested(tower_type: Enums.TowerType, node_index: int)
signal global_upgrade_requested(upgrade_id: String)
signal back_pressed()

@onready var tower_list: VBoxContainer = $HSplit/TowerList
@onready var skill_view: VBoxContainer = $HSplit/SkillView
@onready var global_view: VBoxContainer = $HSplit/GlobalView
@onready var diamond_label: Label = $DiamondLabel
@onready var back_btn: Button = $BackButton

var _pm: ProgressionManager


func setup(pm: ProgressionManager, em: EconomyManager) -> void:
    _pm = pm
    diamond_label.text = "Diamonds: %d" % em.diamonds
    back_btn.pressed.connect(func(): back_pressed.emit())
    _populate_tower_list()
    _populate_global_upgrades()


func _populate_tower_list() -> void:
    for tt in Enums.TowerType.values():
        var btn := Button.new()
        var key := "TOWER_" + Enums.TowerType.keys()[tt]
        btn.text = tr(key)
        var tower_type := tt as Enums.TowerType
        btn.pressed.connect(func(): _show_skill_tree(tower_type))
        tower_list.add_child(btn)


func _show_skill_tree(tower_type: Enums.TowerType) -> void:
    for child in skill_view.get_children():
        child.queue_free()
    var tree := _pm._get_skill_tree(tower_type)
    var unlocked := _pm._unlocked_nodes.get(tower_type, [])
    for i in range(tree.nodes.size()):
        var node: SkillNode = tree.nodes[i]
        var btn := Button.new()
        var status := " [UNLOCKED]" if i in unlocked else " (%d diamonds)" % node.cost
        btn.text = tr(node.display_name) + status
        btn.disabled = i in unlocked or not tree.can_unlock_node(i, unlocked)
        if not btn.disabled:
            var idx := i
            var tt := tower_type
            btn.pressed.connect(func(): skill_unlock_requested.emit(tt, idx))
        skill_view.add_child(btn)


func _populate_global_upgrades() -> void:
    for upgrade_id in ProgressionManager.GLOBAL_UPGRADES:
        var tier := _pm.get_global_upgrade_tier(upgrade_id)
        var btn := Button.new()
        var cost_text := "MAXED" if tier >= 10 else "%d diamonds" % Constants.GLOBAL_UPGRADE_COSTS[tier]
        btn.text = "%s (Tier %d/10) - %s" % [upgrade_id.capitalize(), tier, cost_text]
        btn.disabled = tier >= 10
        if not btn.disabled:
            var uid := upgrade_id
            btn.pressed.connect(func(): global_upgrade_requested.emit(uid))
        global_view.add_child(btn)
```

- [ ] **Step 2: Write DiamondShop**

```gdscript
# ui/meta/diamond_shop.gd
extends Control

signal purchase_requested(pack_id: String)
signal watch_ad_requested()
signal back_pressed()

@onready var diamond_label: Label = $DiamondLabel
@onready var packs_container: VBoxContainer = $PacksContainer
@onready var ad_button: Button = $AdButton
@onready var back_btn: Button = $BackButton

const PACKS := [
    {"id": "small", "diamonds": 500, "price": "$0.99"},
    {"id": "medium", "diamonds": 2000, "price": "$3.99"},
    {"id": "large", "diamonds": 5000, "price": "$7.99"},
    {"id": "doubler", "diamonds": 0, "price": "$4.99", "label": "Diamond Doubler (2x forever)"},
]


func _ready() -> void:
    back_btn.text = tr("UI_BACK")
    back_btn.pressed.connect(func(): back_pressed.emit())
    ad_button.pressed.connect(func(): watch_ad_requested.emit())
    _populate_packs()


func update_diamonds(amount: int) -> void:
    diamond_label.text = "Diamonds: %d" % amount


func update_ad_button(ads_remaining: int) -> void:
    ad_button.text = "Watch Ad (+%d diamonds) [%d left today]" % [
        Constants.DIAMONDS_PER_AD, ads_remaining]
    ad_button.disabled = ads_remaining <= 0


func _populate_packs() -> void:
    for pack in PACKS:
        var btn := Button.new()
        if pack.has("label"):
            btn.text = "%s - %s" % [pack.label, pack.price]
        else:
            btn.text = "%d Diamonds - %s" % [pack.diamonds, pack.price]
        var pack_id: String = pack.id
        btn.pressed.connect(func(): purchase_requested.emit(pack_id))
        packs_container.add_child(btn)
```

- [ ] **Step 3: Commit**

```bash
git add ui/meta/tower_lab.tscn ui/meta/tower_lab.gd ui/meta/diamond_shop.tscn ui/meta/diamond_shop.gd
git commit -m "feat: implement Tower Lab and Diamond Shop UI"
```

---

### Task 10: Implement Pause Menu and Level Complete Screen

**Files:**
- Create: `ui/menus/pause_menu.tscn/.gd`, `ui/menus/level_complete.tscn/.gd`

- [ ] **Step 1: Write PauseMenu**

```gdscript
# ui/menus/pause_menu.gd
extends Control

signal resume_pressed()
signal restart_pressed()
signal quit_pressed()

func _ready() -> void:
    $VBox/ResumeBtn.text = tr("UI_RESUME")
    $VBox/RestartBtn.text = tr("UI_RESTART")
    $VBox/QuitBtn.text = tr("UI_QUIT_LEVEL")
    $VBox/ResumeBtn.pressed.connect(func(): resume_pressed.emit())
    $VBox/RestartBtn.pressed.connect(func(): restart_pressed.emit())
    $VBox/QuitBtn.pressed.connect(func(): quit_pressed.emit())
```

- [ ] **Step 2: Write LevelComplete**

```gdscript
# ui/menus/level_complete.gd
extends Control

signal continue_pressed()
signal restart_pressed()

@onready var stars_label: Label = $VBox/Stars
@onready var diamonds_label: Label = $VBox/Diamonds
@onready var continue_btn: Button = $VBox/ContinueBtn
@onready var restart_btn: Button = $VBox/RestartBtn


func _ready() -> void:
    continue_btn.pressed.connect(func(): continue_pressed.emit())
    restart_btn.pressed.connect(func(): restart_pressed.emit())


func show_results(stars: int, diamonds: int) -> void:
    stars_label.text = tr("STAR_RATING") + ": " + "*".repeat(stars)
    diamonds_label.text = "+" + str(diamonds) + " Diamonds"
    show()
```

- [ ] **Step 3: Commit**

```bash
git add ui/menus/pause_menu.tscn ui/menus/pause_menu.gd ui/menus/level_complete.tscn ui/menus/level_complete.gd
git commit -m "feat: implement pause menu and level complete screens"
```

---

### Task 11: Verify All Translation Keys

**Files:**
- Test: `tests/test_ui_translation_keys.gd`

- [ ] **Step 1: Write comprehensive translation key test**

```gdscript
# tests/test_ui_translation_keys.gd
extends GutTest

const REQUIRED_KEYS := [
    "UI_PLAY_CAMPAIGN", "UI_ENDLESS_MODE", "UI_TOWER_LAB", "UI_SETTINGS",
    "UI_MAIN_MENU", "UI_DIAMOND_SHOP", "UI_BACK", "UI_CONFIRM", "UI_CANCEL",
    "UI_PAUSE", "UI_RESUME", "UI_RESTART", "UI_QUIT_LEVEL",
    "TOWER_PULSE_CANNON", "TOWER_ARC_EMITTER", "TOWER_CRYO_ARRAY",
    "TOWER_MISSILE_POD", "TOWER_BEAM_SPIRE", "TOWER_NANO_HIVE", "TOWER_HARVESTER",
    "DIFFICULTY_NORMAL", "DIFFICULTY_HARD", "DIFFICULTY_NIGHTMARE",
    "HUD_WAVE", "HUD_SEND_WAVE", "HUD_SELL", "HUD_UPGRADE", "HUD_LIVES", "HUD_GOLD",
    "ENEMY_SCOUT", "ENEMY_DRONE", "ENEMY_TANK", "ENEMY_FLYER", "ENEMY_SHIELDER", "ENEMY_HEALER",
    "STAR_RATING",
    "ABILITY_ORBITAL_STRIKE", "ABILITY_EMP_BURST", "ABILITY_REPAIR_WAVE",
    "ABILITY_SHIELD_MATRIX", "ABILITY_OVERCLOCK", "ABILITY_SCRAP_SALVAGE",
]

func test_all_required_keys_have_translations():
    for key in REQUIRED_KEYS:
        assert_ne(tr(key), key, "Missing translation for key: " + key)
```

- [ ] **Step 2: Run test and fix any missing keys in CSV**

- [ ] **Step 3: Commit**

```bash
git add tests/test_ui_translation_keys.gd
git commit -m "feat: add translation key verification test"
```
