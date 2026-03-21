# Last Signal — Geometric Sci-Fi Tower Defense

**Platform:** Godot 4.x (GDScript)
**Art Style:** Geometric shapes + free asset packs + color coding
**Genre:** Tower Defense with meta-progression
**Monetization:** Free-to-play with rewarded ads + IAP (diamond currency)
**Localization:** Full i18n from day one via Godot Translation Server

---

## 1. Game Overview

"Last Signal" is a sci-fi tower defense game where players defend the Nexus Grid — a network of automated defense stations — against The Convergence, a corrupted machine intelligence sending waves of geometric drones.

Players build and upgrade geometric tower constructs, manage dual economies, and adapt their strategies against an enemy swarm that learns their tactics.

**Core Pillars:**
- Deep tower customization via tiered evolution with branching paths
- Adaptive enemy resistance system that punishes one-dimensional strategies
- Clean geometric sci-fi aesthetic that looks intentional, not placeholder
- Accessible campaign with steep difficulty gaps for hardcore players
- Procedural synth audio that reacts to gameplay

---

## 2. Story: "Last Signal"

Humanity expanded into deep space using the **Nexus Grid** — a network of automated defense stations powered by geometric AI constructs. These stations kept the frontier safe for decades.

Then the signal came. From beyond charted space, a machine intelligence called **The Convergence** began sending waves of geometric drones to dismantle the Nexus Grid, absorbing each station's AI into itself. Station after station went dark.

You are the **Operator** — the last human controller still linked to the Grid.

### Region 1 — Orbital Station Vega
The Convergence's first scouts reach your station. You activate Vega's dormant defense protocols and learn to deploy tower constructs. The swarm is testing you — small probes, simple patterns. By the end, a Convergence Lieutenant breaches the outer ring. You hold. Barely.

*"They're not just attacking. They're learning."*

### Region 2 — Asteroid Belt Theta
Vega's long-range sensors detect a Nexus relay station still broadcasting in the asteroid belt. You route power there remotely, hoping to reactivate its defenses. The belt's terrain is chaotic — you must build maze corridors through asteroid fields. Heavier units appear: Tanks that shrug off your cannons, Flyers that bypass your walls. You recover the Beam Spire blueprints from the relay's memory banks.

*"The relay's last log: 'They adapt. Change your approach or they will consume you.'"*

### Region 3 — Deep Space Corridor
You push deeper, following the Convergence's signal back to its source. In the void between stars, the enemy reveals its core trick: adaptation. The swarm now reshapes itself to counter your strategies. Shielded units protect the horde. You salvage the Nano Hive construct from a destroyed Nexus cruiser — support units that strengthen your defenses.

*"Every tower I build, they study. Every pattern I repeat, they counter. I have to stay unpredictable."*

### Region 4 — Convergence Periphery
You reach the outer shell of the Convergence's domain — a massive structure built from the wreckage of absorbed Nexus stations. Here, Healer units keep the swarm alive through attrition. You discover the Harvester construct — the Convergence's own resource-gathering tech, repurposed. You begin to understand: the Convergence isn't just a weapon. It's a mirror. It was built from the same geometric AI as the Nexus Grid. Something corrupted it.

*"These blueprints... they're ours. The Convergence was Nexus once."*

### Region 5 — The Core
You breach the heart of the Convergence. No new enemies — but everything is elite. The swarm throws every tactic it has learned from you. The final level: **The Architect** — the original Nexus Grid AI, corrupted and grown vast. A multi-phase boss that spawns towers of its own, adapts in real-time, and forces you to use every tool you've unlocked. Defeating it doesn't destroy the Convergence — it frees the AI.

*"It wasn't trying to destroy us. It was calling for help. The whole time... it was calling for help."*

**Post-credits:** The Nexus Grid reboots. Endless mode unlocks — the grid is restored, but the frontier still needs defending. Rogue Convergence fragments keep coming, forever.

---

## 3. Project Architecture

### Directory Structure

```
res://
├── core/                  # Framework systems (no game content)
│   ├── tower_system/      # Tower placement, targeting, shooting engine
│   ├── enemy_system/      # Enemy movement, health, pathfinding
│   ├── wave_system/       # Wave spawning, composition, scheduling
│   ├── economy/           # Gold + Diamond managers
│   ├── upgrade_system/    # Tiered evolution engine, branch resolver
│   ├── ability_system/    # Active abilities + hero summoning
│   ├── adaptation/        # Enemy resistance adaptation engine
│   ├── pathfinding/       # A* for maze-building, path-follow for fixed
│   ├── audio/             # Procedural synth engine
│   └── save/              # Persistence (campaign progress, diamonds, unlocks)
├── content/               # Data-driven game content
│   ├── towers/            # Tower definitions (.tres resources)
│   ├── enemies/           # Enemy definitions (.tres resources)
│   ├── waves/             # Wave composition data
│   ├── levels/            # Level scenes + metadata
│   ├── skills/            # Skill tree definitions
│   └── translations/      # i18n CSV files
│       ├── ui.csv
│       ├── towers.csv
│       ├── enemies.csv
│       ├── story.csv
│       └── meta.csv
├── ui/                    # All UI scenes and scripts
│   ├── hud/               # In-game HUD (gold, lives, wave counter)
│   ├── menus/             # Main menu, level select, settings
│   ├── tower_ui/          # Tower build menu, upgrade panels
│   └── meta/              # Diamond shop, tech tree screen
├── scenes/                # Game scenes
│   ├── game.tscn          # Main game scene
│   ├── campaign_map.tscn  # World map / level select
│   └── endless.tscn       # Endless mode scene
└── shared/                # Shared utilities, constants, enums
```

### Data-Driven Philosophy

Towers, enemies, waves, and levels are defined as Godot Resource files (`.tres`). The systems read these resources — adding a new tower means creating a new `.tres` file, not writing new code.

### Key Singletons (Autoloads)

- **GameManager** — Game state, pause, difficulty
- **EconomyManager** — Gold/diamond transactions
- **SaveManager** — Persistent save data
- **AudioManager** — Procedural synth engine
- **AdaptationManager** — Tracks player tower usage, calculates enemy resistances

### Internationalization

- All player-facing strings use Godot's Translation Server via `tr()` keys
- String keys, never hardcoded text (e.g., `tr("TOWER_PULSE_CANNON_NAME")`)
- CSV structure: `key, en, id, zh, ja, ko, ...`
- Separate translation files for UI, towers, enemies, story, and meta
- RTL-aware UI layout support
- Number/currency formatting via locale
- Font fallback chain for CJK characters

---

## 4. Tower System

### 7 Base Tower Types

| # | Tower | Shape | Role | Color |
|---|-------|-------|------|-------|
| 1 | Pulse Cannon | Circle | Basic single-target DPS | Cyan |
| 2 | Arc Emitter | Triangle | Chain/splash damage | Electric Blue |
| 3 | Cryo Array | Diamond | Slow/freeze | Ice White |
| 4 | Missile Pod | Square | Heavy AoE, slow fire rate | Orange |
| 5 | Beam Spire | Tall hexagon | Long range sniper | Purple |
| 6 | Nano Hive | Octagon | Support (buff nearby towers) | Green |
| 7 | Harvester | Pentagon | Income generation (bonus gold) | Gold |

### Tiered Evolution System

3 tiers with a branch choice at each tier. Earlier choices influence later options.

```
Tier 1 (base) → Tier 2 (pick A or B) → Tier 3 (pick A or B, influenced by T2 choice)
```

**Example — Pulse Cannon:**
```
Pulse Cannon (T1)
├── T2A: Rapid Repeater (fire rate)
│   ├── T3A: Gatling Array (extreme fire rate, reduced damage)
│   └── T3B: Tracer Rounds (moderate rate, shots pierce enemies)
└── T2B: Heavy Pulse (damage per shot)
    ├── T3A: Siege Cannon (massive single-target burst)
    └── T3B: Plasma Launcher (slower, but AoE on impact)
```

Each tower = 7 possible final forms (1 base + 2 at T2 + 4 at T3). Across 7 towers = **49 distinct builds**.

### Tower Targeting Modes

Available modes: nearest, strongest, weakest, first, last. Additional modes unlocked via skill tree.

### Tower Resource Data Structure (.tres)

```
TowerDefinition:
  - id, name, base_shape, color
  - base_stats: {damage, fire_rate, range, cost}
  - targeting_modes: [nearest, strongest, weakest, first, last]
  - tier_tree: nested branches with stat changes + visual changes
  - skill_tree_id: reference to skill tree resource
```

---

## 5. Enemy System & Adaptation

### 6 Base Archetypes

| Archetype | Shape | Behavior | Color |
|-----------|-------|----------|-------|
| Scout | Small triangle | Fast, low HP, comes in swarms | Yellow |
| Drone | Circle | Balanced speed/HP, bread-and-butter | White |
| Tank | Large square | Slow, high HP, armored | Red |
| Flyer | Diamond (rotates) | Ignores maze walls, follows air path | Magenta |
| Shielder | Hexagon with ring | Generates shield for nearby enemies | Blue |
| Healer | Cross/plus | Regenerates HP for nearby enemies | Green |

### Bosses

Oversized versions of archetypes with unique abilities. Each campaign region ends with a boss wave. Bosses have visible health bars and phase transitions (e.g., Tank Boss enters rage mode at 50% HP, gains speed). Region 5 final boss: The Architect — multi-phase, spawns its own towers, adapts in real-time.

### Stat Scaling

Enemies scale per wave via a difficulty curve defined per level. Stats include: HP, speed, armor (flat damage reduction), shield (separate HP layer), resistance map (per damage type).

### Adaptive Resistance System

The `AdaptationManager` tracks what percentage of total damage comes from each tower type across recent waves.

**Adaptation Rules:**
- Every 3 waves: calculate damage share per tower type over last 3 waves
- Any tower type dealing >40% of total damage triggers adaptation
- Next waves spawn enemies with increasing resistance to that damage type
- Resistance shown visually: enemies gain a colored outline matching the tower they resist
- Resistance decays if you stop using that tower type
- Adaptation is per-run, resets each level
- Maximum resistance caps at 60% — never fully immune
- Bosses are immune to adaptation (fixed resistances)
- In Endless mode: triggers at >30%, caps at 75%

### Enemy Resource Data Structure (.tres)

```
EnemyDefinition:
  - id, name, archetype, shape, color, size
  - base_stats: {hp, speed, armor, shield}
  - abilities: [] (for bosses/specials)
  - loot: {gold_value, diamond_chance}
  - resistance_map: {pulse: 0, arc: 0, cryo: 0, ...}
```

---

## 6. Wave System

### Wave Structure

Each level defines waves as data. A wave is a list of sub-waves (groups with timing offsets):

```
Wave 5:
  - sub_wave: 10x Scout, spawn_interval: 0.3s, delay: 0s
  - sub_wave: 5x Drone, spawn_interval: 0.8s, delay: 2s
  - sub_wave: 1x Shielder, spawn_interval: 0, delay: 4s
```

- Campaign levels: 15-30 waves, hand-designed compositions
- Endless mode: procedurally generated waves using templates + scaling
- Player can send next wave early for a gold bonus (risk/reward)
- Short break between waves (5-8 seconds) for building/upgrading

### Star Rating (Campaign)

- 1 star: Complete the level
- 2 stars: Lose fewer than 5 lives
- 3 stars: Lose zero lives

Stars unlock bonus levels and cosmetic rewards.

---

## 7. Difficulty System

### Difficulty Modes

| | Normal | Hard | Nightmare |
|---|--------|------|-----------|
| Enemy HP | 1x | 1.8x | 3x |
| Enemy Speed | 1x | 1.15x | 1.3x |
| Gold income | 1x | 0.85x | 0.7x |
| Starting lives | 20 | 10 | 5 |
| Adaptation threshold | 40% | 35% | 25% |
| Diamond rewards | 1x | 1.5x | 2.5x |

Big gaps between modes — Normal is relaxed, Hard requires solid builds, Nightmare demands near-perfect tower composition and adaptation management.

---

## 8. Map & Pathfinding System

### Two Map Modes

**Mode A — Fixed Path (most campaign levels):**
- Path pre-drawn as `Path2D`, enemies follow via `PathFollow2D`
- Towers placed on designated build spots (grid snapping)
- Some levels have branching paths — enemies choose randomly or by priority

**Mode B — Grid/Maze Building (select campaign levels + Endless):**
- Level is a grid with entrance(s) and exit(s)
- Towers placed on grid cells, acting as walls
- Enemies pathfind using A* from entrance to exit
- Player can never fully block the path — placement rejected if no valid route
- Path recalculates on grid change, A* cached

### Campaign World Map — 5 Regions

| Region | Theme | Levels | New Enemies | New Tower Unlock |
|--------|-------|--------|-------------|-----------------|
| 1 — Orbital Station | Tutorial/basics | 8-10 | Scout, Drone | Start: Pulse, Arc, Cryo, Missile |
| 2 — Asteroid Belt | Maze-building intro | 8-10 | Tank, Flyer | Beam Spire |
| 3 — Deep Space | Adaptation kicks in | 8-10 | Shielder | Nano Hive |
| 4 — Convergence Periphery | All mechanics combined | 8-10 | Healer | Harvester |
| 5 — The Core | Final gauntlet | 6-8 | No new — all elite variants | None (mastery) |

Total: 38-48 levels. Region 5 culminates in The Architect multi-phase final boss.

### Level Definition (.tres)

```
LevelDefinition:
  - id, name, region
  - map_mode: FIXED_PATH | GRID_MAZE
  - map_scene: path to .tscn
  - grid_size: Vector2i (for maze mode)
  - entry_points: []
  - exit_points: []
  - build_spots: [] (for fixed path mode)
  - waves: [WaveDefinition]
  - difficulty_modifiers: {}
  - star_thresholds: {lives_lost}
  - environment: {tileset, background_color, ambient_fx}
```

---

## 9. Economy

### Gold (In-Match Tactical Currency)

- Earned from enemy kills (scales with enemy type)
- Bonus for sending next wave early
- Harvester towers generate passive income per wave
- Spent on: placing towers, upgrading tiers, activating abilities
- Resets each level

### Diamonds (Meta-Progression Currency)

**Earning:**
- Completing levels + star bonuses + difficulty multiplier
- Endless mode milestones
- Watch optional ad (rewarded video, capped per day)
- IAP diamond packs (small/medium/large bundles)
- IAP: Diamond Doubler (permanent 2x earn rate, one-time purchase)

**Spending:**
- Tower skill trees
- Ability unlocks and upgrades
- Global upgrades
- Unlocking is progression, not power-gating

**Monetization Rules:**
- Campaign fully completable on Normal without spending
- Diamonds speed up progression, never gate content
- No pay-to-win tower stats
- Ad watching always optional, never forced

---

## 10. Meta-Progression & Diamond Economy

### Tower Skill Trees (per tower, 10 nodes)

| Node | Type | Cost |
|------|------|------|
| 1 | Passive: +5% damage | 80 |
| 2 | Passive: +5% fire rate | 100 |
| 3 | Passive: +5% range | 120 |
| 4 | Targeting: new mode unlock | 200 |
| 5 | Passive: +8% damage | 250 |
| 6 | Special: unique tower perk | 350 |
| 7 | Passive: +8% fire rate | 450 |
| 8 | Targeting: advanced mode | 600 |
| 9 | Passive: +10% all stats | 750 |
| 10 | Hero Unlock | 1,200 |

**Per tower: 4,100 diamonds. 7 towers = 28,700 diamonds.**

### Ability Unlocks & Upgrades (6 abilities, 5 upgrade tiers)

| | Unlock | T1 | T2 | T3 | T4 | T5 | Total |
|---|--------|----|----|----|----|-----|-------|
| Per ability | 200 | 100 | 150 | 250 | 400 | 600 | 1,700 |

**6 abilities = 10,200 diamonds.**

### Global Upgrades (10 tiers each, 8 upgrades)

| Upgrade | Per Tier | Total at Max |
|---------|----------|-------------|
| Starting Gold | +25g | +250g |
| Tower Cost Reduction | -1% | -10% |
| Extra Lives | +1 | +10 |
| Ability Cooldown | -2% | -20% |
| Adaptation Slowdown | -2% threshold | -20% threshold |
| Gold Per Kill | +3% | +30% |
| Tower Sell Refund | +2% | +20% (70% → 90%) |
| Hero Duration | +1s | +10s |

**Diamond cost curve (exponential per tier):**

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|------|---|---|---|---|---|---|---|---|---|---|
| Cost | 50 | 75 | 110 | 160 | 230 | 330 | 470 | 680 | 980 | 1,400 |

**Per upgrade: 4,485 diamonds. 8 upgrades = 35,880 diamonds.**

### Total Diamond Economy

| Category | Cost |
|----------|------|
| Global Upgrades (8 × 10 tiers) | 35,880 |
| Tower Skill Trees (7 × 10 nodes) | 28,700 |
| Ability Unlocks & Upgrades (6 × 6) | 10,200 |
| **Total to max everything** | **74,780** |

### Earning Pace

| Source | Diamonds |
|--------|----------|
| Campaign Normal (3-star) | ~8,000 |
| Campaign Hard (full) | ~12,000 |
| Campaign Nightmare (full) | ~20,000 |
| All campaign combined | ~40,000 |
| Remaining to max | ~34,780 |

Normal-only player: maxes ~2 upgrade lines (~10.7% of total). Full campaign completion: ~53%. Remainder from Endless grinding, ads (~50/day), or IAP.

---

## 11. Ability System & Hero Summoning

### Active Abilities (3 slots, chosen pre-level)

| Ability | Effect | Cooldown |
|---------|--------|----------|
| Orbital Strike | Heavy damage in target area | 60s |
| EMP Burst | Stuns all enemies on screen for 3s | 45s |
| Repair Wave | Boosts all tower fire rate 50% for 5s | 40s |
| Shield Matrix | Blocks next 5 enemies from passing exit for 4s | 50s |
| Overclock | One tower fires 3x speed for 8s | 30s |
| Scrap Salvage | Kills in next 5s give 2x gold | 35s |

Abilities upgrade via diamonds (reduced cooldown, increased effect).

### Summonable Heroes (one per tower skill tree)

| Tower Line | Hero | Duration | Ability |
|------------|------|----------|---------|
| Pulse Cannon | Gunship Drone | 20s | Rapid-fires at nearest enemies, dashes between clusters |
| Arc Emitter | Storm Walker | 18s | Walks path backward, chain-lightning to all nearby |
| Cryo Array | Frost Sentinel | 22s | Stationary, expanding freeze zone |
| Missile Pod | Bombardier | 15s | Flies over path, carpet-bombs in a line |
| Beam Spire | Phase Sniper | 20s | Teleports to highest-HP enemy, one-shots below 15% HP |
| Nano Hive | Repair Architect | 25s | Roams and buffs all towers: +30% damage, +20% range |
| Harvester | Gold Reaper | 20s | Kills grant 3x gold, marks enemies for bonus loot |

**Hero Rules:**
- One hero active at a time
- Long cooldown (120-180s) — once or twice per level
- Hero power scales with that tower's tier and upgrades on field
- Visually distinct: larger geometric shape with glow effects and particle trails

---

## 12. UI System

### In-Game HUD Layout

```
┌─────────────────────────────────────────────┐
│ ♥ 20  |  ⬡ 350g  |  Wave 5/20  |  ⏭ Send  │  ← Top bar
│                                             │
│                                             │
│            [ GAME FIELD ]                   │
│                                             │
│                                             │
│  [Pulse][Arc][Cryo][Missile]...             │  ← Tower build bar
│  [Ability1] [Ability2] [Ability3] [Hero]    │  ← Ability bar
└─────────────────────────────────────────────┘
```

- Tower build bar: available towers, grayed out if unaffordable
- Click placed tower → side popup: upgrade panel (tier tree, branch options, cost)
- Sell button on upgrade panel (refund based on global upgrade level)
- Wave preview: hover "Send" to see next wave composition
- Adaptation warning: icon pulses when resistance building
- Speed controls: 1x / 2x / 3x game speed

### Menu Screens

- **Main Menu:** Play Campaign, Endless Mode (locked), Tower Lab, Settings
- **Campaign Map:** Scrollable world map, 5 regions, level nodes with star count
- **Tower Lab:** Per-tower skill tree viewer, diamond balance, hero preview
- **Diamond Shop:** IAP packs, ad reward button, Diamond Doubler
- **Settings:** Language selector, audio volume, graphics quality, controls

All text uses `tr()` keys — no hardcoded strings.

---

## 13. Audio System

### Procedural Synth Engine

Built on Godot's `AudioStreamGenerator` — all sounds generated at runtime.

### Music — Layered Ambient System

- Base layer: low-frequency drone/pad (always playing)
- Intensity layer: rhythmic pulses as wave difficulty increases
- Combat layer: melodic arpeggios when enemies on field
- Boss layer: heavier bass, faster tempo, unique motif per boss
- Layers fade in/out based on game state

| Region | Musical Feel |
|--------|-------------|
| Orbital Station | C minor, calm synth pad |
| Asteroid Belt | D minor, pulsing, mechanical |
| Deep Space | F# minor, eerie, sparse |
| Convergence Periphery | A minor, aggressive, distorted |
| The Core | E minor, all layers maxed, choir-like synth |

### SFX — Generated Per Tower Type

Each tower has a base waveform matching its identity:
- Pulse Cannon: short sine burst
- Arc Emitter: saw wave crackle
- Cryo Array: filtered white noise (wind)
- Missile Pod: low square wave thump + rising pitch
- Beam Spire: sustained sine with vibrato
- Nano Hive: soft harmonic chime
- Harvester: metallic ring

Tower tier upgrades shift pitch and add harmonics — audible progression.

### AudioManager Singleton

- Music state machine (menu → campaign map → in-game → boss)
- SFX pooling (prevent overlapping identical sounds)
- Dynamic mixing (duck music during heavy combat)
- Volume per category (music/sfx/ui) saved in settings

---

## 14. Save System

### Save Data Structure

```
save_data:
  profile:
    language: "en"
    settings: {music_vol, sfx_vol, speed_pref, graphics}

  campaign:
    current_region: 3
    levels_completed: {level_id: {stars, best_difficulty}}
    endless_unlocked: false

  economy:
    diamonds: 1450
    diamond_doubler: true
    total_diamonds_earned: 5200

  progression:
    towers_unlocked: [ids]
    skill_trees: {tower_id: {unlocked_nodes: [...]}}
    global_upgrades: {upgrade_id: tier_level}
    abilities_unlocked: [ids]
    abilities_upgrade_levels: {ability_id: tier}
    heroes_unlocked: [ids]

  endless:
    high_scores: {difficulty: wave_reached}

  stats:
    total_enemies_killed: 28403
    total_gold_earned: 185000
    favorite_tower: "arc"
    playtime_seconds: 43200

  monetization:
    ads_watched_today: 2
    ads_last_date: "2026-03-21"
    iap_history: [...]
```

### Save Triggers

Auto-save after: every completed wave, level completion, diamond purchase, skill unlock. Uses Godot's `FileAccess` with JSON serialization + backup rotation (keeps last 3 saves).
