# Last Signal — Complete Game Design Document

> The definitive spec for Last Signal. All game systems, mechanics, content, and balance values in one place.

---

## 1. Game Overview

**Genre:** Sci-fi tower defense with meta-progression
**Engine:** Godot 4.6, GDScript
**Platform:** Mobile-first (Android), desktop secondary
**Viewport:** 1920×1080, portrait-capable
**Rendering:** No sprites — all visuals drawn procedurally via `_draw()` using geometric shapes

**Premise:** Players defend the Nexus Grid against The Convergence — waves of corrupted machine drones. Place towers, upgrade them, discover synergies, and adapt as the enemy evolves resistance to your strategies.

**Core Loop:**
```
Place towers → Survive waves → Earn gold (match) + diamonds (permanent)
  → Spend diamonds on skill trees / global upgrades / abilities
    → Stronger runs → harder content → more diamonds → repeat
```

**Unique Mechanic — Adaptive Resistance:** The Convergence learns. If the player over-relies on one damage type, enemies gain resistance to it. This forces strategic diversity and makes every run a shifting puzzle.

---

## 2. Architecture

### Autoload Singletons (registered in project.godot)

| Singleton | Responsibility |
|-----------|---------------|
| **GameManager** | State machine (MENU→BUILDING→WAVE_ACTIVE→WAVE_COMPLETE→VICTORY/DEFEAT/PAUSED), lives, difficulty, pause |
| **EconomyManager** | Match gold (transient, resets per level) + permanent diamonds, gold modifiers, difficulty multiplier |
| **SaveManager** | JSON persistence to `user://last_signal_save.json` — profile, settings, progression, mastery, daily challenges |
| **AudioManager** | Music/SFX volume, 8-slot SFX player pool, stream caching, state-based music switching |

### Signal-Driven Communication

Systems communicate via signals, never direct calls. GameLoop connects everything:
- GameManager emits `state_changed`, `lives_changed`, `level_completed`, `level_failed`
- WaveManager emits `wave_started`, `wave_complete`, `all_waves_complete`, `enemy_spawn_requested`
- Enemy emits `enemy_died`, `enemy_reached_exit`
- AdaptationManager emits `adaptation_changed`
- SynergyManager emits `synergy_activated`
- AbilityManager emits `ability_activated`

### Data-Driven Design

All content defined as Godot Resource (`.tres`) files or generated dynamically from Constants. Adding new towers, enemies, or waves means creating data — not writing new code.

### Scene Flow

```
Main (scenes/main.tscn) → routes between screens
  ├─ MainMenu
  ├─ CampaignMap (with difficulty selector)
  ├─ DailyChallengeScreen
  └─ Game (scenes/game.tscn)
      ├─ Map (Path2D for enemy routes)
      ├─ Towers, Enemies, Projectiles (runtime children)
      ├─ GameCamera (zoom/pan)
      └─ UI/HUD (CanvasLayer)
```

---

## 3. Difficulty & Scoring

### Difficulty Levels

| Setting | HP Mult | Speed Mult | Gold Mult | Starting Lives |
|---------|---------|------------|-----------|----------------|
| Normal | 1.0× | 1.0× | 1.0× | 20 |
| Hard | 1.8× | 1.15× | 0.85× | 10 |
| Nightmare | 3.0× | 1.3× | 0.7× | 5 |

### Star Rating

| Stars | Condition |
|-------|-----------|
| 3 | No lives lost |
| 2 | ≤5 lives lost |
| 1 | >5 lives lost (level completed) |

---

## 4. Economy

### Match Currency: Gold (transient, resets per level)
- Starting gold: 200 (base) + global upgrade bonus
- Gold per enemy kill: defined per EnemyDefinition, modified by difficulty multiplier
- Early-send bonus: remaining break time converted to bonus gold
- Sell refund: (total cost invested × base refund rate) + global upgrade bonus

### Permanent Currency: Diamonds
- Earned from: level completion (star-based), endless milestones, daily challenges, ads, IAP
- Spent on: skill tree nodes, global upgrades, ability unlocks/upgrades, hero unlocks
- Diamond doubler IAP: 2× all diamond earnings permanently

### Gold Modifiers (stackable)
- Difficulty multiplier (0.7–1.0)
- Scrap Salvage ability (2× for duration)
- Wave reward buffs (Salvage Operations +20%, Speed Demons +30%)
- Harvester tower income bonus
- Synergy bonus (Efficiency: Harvester +30%)

---

## 5. Tower System

### 5.1 Tower Types

7 tower types, each an octagonal geometric shape drawn via `_draw()`. Outline color and complexity increase with tier.

| Tower | Role | Damage Type | Base Damage | Fire Rate | Range | Special |
|-------|------|-------------|-------------|-----------|-------|---------|
| **Pulse Cannon** | Raw single-target DPS | PULSE | 25 | 1.0/s | 150px | — |
| **Arc Emitter** | Chain/multi-target | ARC | 15 | 0.8/s | 130px | Chains to 2 targets |
| **Cryo Array** | Slow/control | CRYO | 10 | 0.6/s | 140px | Slows enemies 30% for 2s |
| **Missile Pod** | AoE/splash | MISSILE | 40 | 0.4/s | 160px | 60px splash radius |
| **Beam Spire** | Pierce/sustained | BEAM | 20 | 1.2/s | 180px | Hits through first target |
| **Nano Hive** | Support/buff aura | NANO | 0 | — | 120px | Buffs nearby tower damage +15% |
| **Harvester** | Economy/income | HARVEST | 8 | 0.5/s | 100px | Generates bonus gold per kill |

### 5.2 Targeting Modes

All towers support 5 targeting modes, cycled via UI:
- **Nearest** — closest enemy in range
- **Strongest** — highest current HP
- **Weakest** — lowest current HP
- **First** — furthest along path (most dangerous)
- **Last** — least path progress

### 5.3 Tier Tree (Branching Upgrades)

Each tower has a 3-tier upgrade tree with 2 choices per tier, creating up to 8 possible end-state evolutions.

Structure: `Tier 1 (2 choices) → Tier 2 (2 choices each) → Tier 3 (2 choices each)`

Each tier node defines:
- `name`, `display_name`
- Stat multipliers: `damage`, `fire_rate`, `range`
- `cost` (gold, increases per tier)
- Optional `special_ability` (unlocked at higher tiers)
- Array of `next_tier` branches

Sell value = total gold invested × refund rate (base + global upgrade bonus).

### 5.4 Tower Synergies

When two specific tower types are placed within 100px of each other, both gain a passive synergy bonus. A glowing line connects synergized towers. Each tower participates in only one synergy at a time (strongest priority).

| Pair | Synergy Name | Effect |
|------|-------------|--------|
| Cryo + Arc | **Shatter** | Frozen/slowed enemies take 2× chain damage from Arc |
| Pulse + Missile | **Barrage** | Both gain +15% fire rate |
| Nano Hive + Beam | **Amplify** | Beam pierces through first target, hitting a second |
| Cryo + Missile | **Frostbite** | Slowed enemies take +25% splash damage |
| Harvester + Nano | **Efficiency** | Harvester income +30% |
| Pulse + Cryo | **Cold Snap** | Pulse hits on slowed enemies extend slow by 0.5s |
| Arc + Beam | **Conduit** | Beam can chain to 1 additional target via Arc's chain system |
| Missile + Beam | **Focus Fire** | If both target same enemy, that enemy takes +20% damage from all sources for 2s |

**Discovery UX:**
- First time a synergy activates: toast "SYNERGY DISCOVERED: Shatter" with sparkle VFX
- Tower Lab UI shows discovered synergies with descriptions
- Undiscovered synergies show as "???" — encourages experimentation

---

## 6. Enemy System

### 6.1 Archetypes

6 archetypes, each rendered as a geometric polygon via `_draw()`. Side count increases with complexity.

| Archetype | Shape | Role | Special Behavior |
|-----------|-------|------|-----------------|
| **Scout** | Triangle (3) | Fast, fragile | **Scatter Signal:** on death, allies within 100px gain +20% speed for 3s |
| **Drone** | Square (4) | Balanced swarm | **Overwhelm:** when 5+ drones alive, all gain +10% speed |
| **Tank** | Pentagon (5) | Slow, tough | **Fortified:** takes 25% reduced damage from the first tower type that hits it per wave |
| **Flyer** | Hexagon (6) | Ignores ground path | **Altitude:** flies straight-line from spawn to exit (shorter path, bypasses maze) |
| **Shielder** | Heptagon (7) | Protects allies | **Shield Aura:** every 5s, grants 30 shield to allies within 60px (max 100 shield) |
| **Healer** | Octagon (8) | Sustains allies | **Heal Pulse:** every 4s, restores 15% max HP to allies within 80px |

### 6.2 Health System

Each enemy has up to 3 health layers:
1. **Shield** (blue bar) — absorbs damage first, no armor reduction, granted by Shielders
2. **Armor** (yellow bar) — flat damage reduction per hit
3. **HP** (red bar) — base health, minimum 1 damage per hit after all reductions

Damage is further modified by:
- **Resistance** (0–75%) — per damage type, applied by adaptation system
- **Fortified** (Tank only) — 25% reduction from first tower type to hit

### 6.3 Elite Modifiers (Endless Mode)

Starting at wave 15 in endless mode, random enemies spawn as Elites with a visible modifier and unique VFX.

| Modifier | Visual | Effect | Counter |
|----------|--------|--------|---------|
| **Regenerating** | Green pulse every 2s | Heals 2% max HP/sec | Burst damage, focus fire |
| **Splitting** | Fracture lines | On death, spawns 2 copies at 30% HP, 80% speed | Splash/AoE damage |
| **Phasing** | Flickers/ghosts every 3s | Untargetable for 0.5s every 3s | High fire rate towers |
| **Magnetic** | Pull aura ring | Allies within 60px move 15% faster | Kill first, isolate |
| **Reflective** | Mirror sheen | 15% damage reflected; attacking tower paused 0.3s | Diverse tower spread |
| **Enraged** | Red glow, growing size | +5% speed per 3s alive, caps at +50% | Fast kill, high DPS |

**Elite Scaling:**

| Wave Range | Elite Rate |
|------------|-----------|
| 15–19 | 1 elite per wave |
| 20–29 | 2 elites per wave |
| 30–49 | 20% of enemies are elite |
| 50+ | 40% elite, can stack 2 modifiers |

---

## 7. Wave System

### 7.1 Wave Structure

Each wave is defined by one or more SubWaveDefinitions:
- `enemy_type`: which archetype to spawn
- `count`: how many
- `spawn_interval`: seconds between spawns
- `delay`: seconds before this sub-wave starts
- `path_index`: which path to spawn on (for multi-path levels)

Wave break: 6 seconds between waves. Player can "send early" for gold bonus proportional to remaining break time.

### 7.2 Adaptive Resistance

The game's signature mechanic. Tracked by AdaptationManager.

**How it works:**
1. AdaptationManager records all damage dealt per damage type during each wave
2. Every 3 waves, it checks: is any one damage type dominant?
3. Dominant threshold: >40% of total damage (Normal/Hard) or >25% (Nightmare)
4. If dominant: enemies gain +10% resistance to that type (max 60% Normal, 75% Nightmare/Endless)
5. If a type is no longer dominant: resistance decays 5% per check

**Player-Facing Feedback:**
- **Wave banner** after adaptation checks:
  - Resistance rising: "THE CONVERGENCE ADAPTS — [Type] resistance increasing" (red tint, 3s)
  - Resistance falling: "THE CONVERGENCE DESTABILIZES — [Type] resistance fading" (green tint, 3s)
- **Enemy visual evolution:** enemies with >20% resistance gain colored overlays:
  - CRYO → frost-cracked blue armor lines
  - MISSILE → thicker dark plating outline
  - ARC → trailing ground-wire particles
  - PULSE → pulsing red energy shield shimmer
  - BEAM → reflective mirror-sheen overlay
- **HUD resistance meter:** collapsible panel showing resistance levels per damage type (colored bars, 0–75%)

### 7.3 Endless Wave Generation

WaveGenerator creates procedural waves for endless mode:
- Enemy pool unlocks progressively: Scout/Drone (wave 1), Tank/Flyer (wave 5), Shielder (wave 12), Healer (wave 18)
- HP and count scale with wave number
- Elite modifiers applied starting wave 15

---

## 8. Pathfinding & Maps

### 8.1 Path Types

| Type | Description | Implementation |
|------|-------------|---------------|
| **Fixed Path** | Enemies follow a pre-defined Path2D curve | FixedPathProvider |
| **Grid/Maze** | Player-built maze, enemies pathfind via A* | GridPathProvider (10×10 grid, 64px cells) |
| **Flyer Straight-Line** | Flying enemies go direct spawn→exit | FlyerPathProvider |
| **Multi-Path** | Multiple entry/exit points, enemies assigned to paths via SubWaveDefinition.path_index | Multiple Path2D nodes |

### 8.2 Procedural Path Shapes

PathGenerator creates deterministic paths from seed with 4 shapes:
- **Zigzag** — 4 right-angle turns across the map
- **Spiral** — concentric rectangles spiraling inward
- **Branching** — 2 paths from center, rejoin at exit
- **Multi-Entry** — 3–4 entry points converging to single exit

### 8.3 Camera System

GameCamera (Camera2D wrapper):
- Per-level `map_scale` field (0.8–1.2) controls zoom level
- Smooth zoom transitions when level loads
- Pan clamped to level extents
- Mid-game camera events (e.g., boss arrival pan)

### 8.4 Grid/Maze Rules

- GridManager validates tower placements don't block the exit path
- A* recalculates when towers are placed or sold
- Invalid placements rejected with visual feedback

---

## 9. Abilities & Heroes

### 9.1 Abilities

6 active abilities with cooldowns, assigned to a 3-slot loadout. Unlocked and upgraded with diamonds.

| Ability | Cooldown | Target | Effect | Upgrade per Tier |
|---------|----------|--------|--------|-----------------|
| **Orbital Strike** | 60s | Position | 1s delay, then 500 damage in 80px radius. Screen shake. | +100 damage, +10px radius |
| **EMP Burst** | 45s | Global | All on-screen enemies stunned 3s | +0.5s duration |
| **Repair Wave** | 40s | Global | Restore 1 lost life | +1 life at tier 3 and 5 |
| **Shield Matrix** | 50s | Position | 120px zone, enemies 50% reduced speed for 6s | +1s duration, +20px radius |
| **Overclock** | 30s | Tower | Target tower fires at 3× speed for 8s | +1s duration, +0.5× fire rate |
| **Scrap Salvage** | 35s | Global | Kills in next 10s drop 2× gold | +2s duration, +0.25× gold mult |

**Costs:**
- Unlock: 200 diamonds
- Upgrade: 100, 200, 300, 450, 600 diamonds (5 tiers)

Cooldown reduction from global upgrades applied multiplicatively.

### 9.2 Heroes

Each tower type's skill tree culminates in a hero unlock (node 10). Heroes are temporary summonable units:
- Base duration: 20s (extended by global upgrades)
- Summon cooldown: 150s
- Rendered as 8-sided cyan octagon glyph
- One hero active at a time

---

## 10. Meta-Progression

### 10.1 Skill Trees (Per Tower)

Each of the 7 tower types has a 10-node linear skill tree. Nodes unlock sequentially (node N requires node N-1). Node costs escalate: 80→120→180→260→380→540→760→920→1080→1200 diamonds.

| Tower | Nodes 1–3 | Nodes 4–6 | Nodes 7–9 | Node 10 |
|-------|-----------|-----------|-----------|---------|
| **Pulse Cannon** | +5% damage/level | +3% fire rate/level | Piercing Rounds (projectiles hit 2 targets at level 7+) | Hero unlock |
| **Arc Emitter** | +1 chain target at level 3 | +4% chain range/level | Conductive Residue (chained enemies +10% damage for 2s) | Hero unlock |
| **Cryo Array** | +0.05s slow duration/level | +3% range/level | Flash Freeze (5% chance to fully stop enemy 1s) | Hero unlock |
| **Missile Pod** | +4% splash radius/level | +3% damage/level | Cluster Munitions (on impact, scatter 3 mini-projectiles) | Hero unlock |
| **Beam Spire** | +5% damage/level | +3% range/level | Overload Beam (3 consecutive same-target hits → 2× damage) | Hero unlock |
| **Nano Hive** | +3% buff range/level | +2% buff damage mult/level | Repair Drones (heal nearby towers — reduce cooldowns 1s/pulse) | Hero unlock |
| **Harvester** | +10 income/level | +3% range/level | Salvage Protocol (enemies killed in range +15% gold) | Hero unlock |

### 10.2 Global Upgrades

8 permanent upgrades purchased with diamonds. Each has 5–10 tiers with exponential cost scaling: 50, 75, 110, 160, 230, 330, 470, 680, 980, 1400.

| Upgrade | Effect per Tier | Max Tiers |
|---------|----------------|-----------|
| Starting Gold | +25 gold | 10 |
| Starting Lives | +1 life | 5 |
| Tower Cost Reduction | -2% build cost | 10 |
| Wave Clear Bonus | +10 gold per wave clear | 10 |
| Tower Sell Refund | +3% refund rate | 5 |
| Diamond Bonus | +5% diamond earnings | 10 |
| Ability Cooldown | -2% base cooldown | 10 |
| Harvester Efficiency | +5% income | 5 |

### 10.3 Tower Mastery

Lifetime stats tracked per tower type across all matches. At kill thresholds, unlock mastery rewards.

| Tier | Threshold | Reward |
|------|-----------|--------|
| Bronze | 500 kills | Cosmetic: subtle glow outline |
| Silver | 2,000 kills | +3% permanent damage bonus |
| Gold | 8,000 kills | Cosmetic: unique tower shape variant |
| Diamond | 25,000 kills | Profile title + unique upgrade path color |
| Master | 100,000 kills | "Mastered" badge + tower costs -5% permanently |

**Tracked stats per tower type:**
- Total kills
- Total damage dealt
- Waves active (across all matches)
- Highest single-hit damage
- Most kills in a single match

Mastery rewards applied as permanent modifiers via ProgressionManager.

---

## 11. Campaign

### 11.1 Regions

5 regions with progressive complexity. Completing each region unlocks a new tower type and the next region.

| Region | Levels | Path Mode | Tower Unlock | Theme |
|--------|--------|-----------|-------------|-------|
| 1 | 10 (1-1 → 1-10) | Fixed path | — (starter towers) | Tutorial/Introduction |
| 2 | 10 (2-1 → 2-10) | Grid/maze | Beam Spire | Maze Defense |
| 3 | 9 (3-1 → 3-9) | Fixed path | Nano Hive | Multi-path |
| 4 | 9 (4-1 → 4-9) | Mixed | Harvester | Advanced |
| 5 | 8 (5-1 → 5-8) | Grid/maze | — | Final Boss |

**Total: 46 campaign levels.**

### 11.2 Wave Counts

Base formula: `15 + 1 × (level_index - 1)` waves per level. Boss levels get +5 waves.

### 11.3 Unlock Progression

- Level 1-1: always unlocked
- Each level requires completing the previous level
- Region N+1 requires Region N boss (final level) completion
- Endless mode unlocks after completing all 46 campaign levels

### 11.4 Milestone Levels (Hand-Crafted)

13 levels with unique hand-crafted path layouts and map variety:
- 1-1, 1-5, 1-10 (region 1)
- 2-5, 2-10 (region 2)
- 3-5, 3-9 (region 3)
- 4-5, 4-9 (region 4)
- 5-5, 5-8 (final boss)
- 2 bonus endless maps

### 11.5 Story

DialogueOverlay shows i18n'd story text at region boundaries, introducing the Convergence threat narrative. Minimal — 2–3 lines per trigger point.

---

## 12. Endless Mode

### 12.1 Wave Generation

- Procedural via WaveGenerator with deterministic seed
- Enemy pool grows: Scout/Drone → +Tank/Flyer (wave 5) → +Shielder (wave 12) → +Healer (wave 18)
- HP and enemy count scale per wave
- Elite modifiers from wave 15+ (see section 6.3)

### 12.2 Milestones

| Wave | Diamond Reward |
|------|---------------|
| 10 | 50 |
| 25 | 100 |
| 50 | 200 |
| 75 | 300 |
| 100 | 500 |

### 12.3 Roguelite Wave Rewards

Every 5 waves, pause and present 3 random buff cards. Player picks 1. Buffs stack for the entire run. 8-second timer to choose (random pick if no selection).

**Buff Pool (18+ cards across categories):**

**Offensive:**

| Card | Effect |
|------|--------|
| Overcharged Capacitors | All towers +10% damage |
| Rapid Cycling | All towers +8% fire rate |
| Extended Range | All towers +12% range |
| Armor Piercing | All damage ignores 15% of enemy armor |
| Critical Strike | All attacks 5% chance to deal 3× damage |

**Defensive:**

| Card | Effect |
|------|--------|
| Reinforced Nexus | +2 lives |
| Emergency Protocols | When a life is lost, all enemies take 100 damage |
| Temporal Buffer | Enemies move 5% slower globally |

**Economic:**

| Card | Effect |
|------|--------|
| Salvage Operations | +20% gold from kills |
| Budget Engineering | Tower costs -10% |
| Efficient Refunds | Sell value +15% |

**Risky/Trade-off:**

| Card | Effect |
|------|--------|
| Glass Cannon | All towers +25% damage, but -1 life |
| Speed Demons | Enemies +15% speed, but +30% gold |
| Minimalist | Can only build 3 more towers, but all towers +40% damage |

**Synergy-Specific:**

| Card | Effect |
|------|--------|
| Cryo Mastery | Cryo slow +25%, slow duration +1s |
| Chain Reaction | Arc chain count +2 |
| Carpet Protocol | Missile splash +30% radius |
| Signal Leech | Adaptation resistance decays 2× faster |

UI: 3-card overlay with brief descriptions and icon colors per category.

---

## 13. Daily Challenges

One challenge per day, fixed seed (`hash(date_string)`), deterministic map/waves/constraints. Everyone gets the same challenge.

### 13.1 Challenge Types (Weekly Rotation)

| Day | Type | Example Constraint |
|-----|------|--------------------|
| Mon | Restricted Towers | Only 2 of 7 tower types available, enemies +30% speed |
| Tue | Economy | 50% gold income; reward doubles if 3-star |
| Wed | Survival | 1 starting life, tower costs -40% |
| Thu | Speed | 0s between waves, 2× gold |
| Fri | Puzzle | Pre-placed towers, choose upgrades only |
| Sat | Chaos | 2 enemy paths simultaneously |
| Sun | Boss Rush | Bosses every 3 waves, 3× diamonds |

### 13.2 Rewards

| Condition | Diamonds |
|-----------|----------|
| Complete challenge | 50 |
| 3-star clear | +100 |
| Streak bonus (per consecutive day) | +10 (caps at +70) |

Streak resets on a missed day.

---

## 14. Signal Decode Minigame

Between-wave activity during the 6-second break. Purely optional — no penalty for skipping.

### How It Works

1. A non-intrusive prompt appears bottom-center: "Intercepted Convergence transmission — decode it?"
2. A sequence of sci-fi glyphs flashes (SHOWING phase)
3. Player taps the glyphs back in order within 4 seconds (INPUT phase)

### Scaling

| Wave Range | Sequence Length |
|------------|---------------|
| 1–10 | 4 symbols |
| 11–25 | 5 symbols |
| 26+ | 6 symbols |

### Rewards (random on success)

- +20 gold
- +5% tower damage next wave
- -3s on one ability cooldown

Fail/skip: nothing happens.

---

## 15. Monetization

### 15.1 In-App Purchases

| Pack | Price | Diamonds |
|------|-------|----------|
| Small | $0.99 | 500 |
| Medium | $3.99 | 2,000 |
| Large | $7.99 | 5,000 |
| Diamond Doubler | $4.99 | 2× all diamond earnings permanently |

### 15.2 Rewarded Ads

- 10 ads per day (resets at UTC midnight)
- 150 diamonds per ad
- Daily limit tracked in SaveManager

### 15.3 x2 Diamond Bonus (Level Complete)

- "x2 Diamonds" button on the level complete screen
- Player watches a rewarded ad to double the diamond reward for that level
- Does not count toward the daily rewarded ad limit
- "Remove Ads" users get the x2 bonus instantly without watching

### 15.4 Rewarded Interstitial

- Shown automatically after completing a daily challenge
- Rewards +100 bonus diamonds if the player watches the full ad
- "Remove Ads" users get the bonus instantly without watching
- Does not count toward the daily rewarded ad limit

### 15.5 "Remove Ads" Perk

- All ad-gated rewards (shop diamonds, x2 bonus, interstitial bonus) are granted instantly without showing ads
- Daily ad claims in the Diamond Shop remain available with no daily limit

### 15.5 Speed Unlocks

- x2 Speed: purchasable in Diamond Shop
- x3 Speed: purchasable in Diamond Shop
- Speed cycles: 1× → 2× → 3× (if unlocked)

---

## 16. UI System

### 16.1 HUD (In-Game)

All UI built programmatically in code (no .tscn scene files). All text uses `tr("KEY")` for i18n.

**Top Bar:**
- Lives counter, Gold counter, Wave counter (current/total)
- Send Wave button (with early-send gold bonus display)
- Speed toggle button (1×/2×/3×)

**Bottom Bar:**
- Tower build buttons (one per available tower type, shows cost, disabled if unaffordable)
- Ability bar (3 slots + hero button, shows cooldown percentage during recharge)

**Side Panel (Tower Upgrade):**
- Appears when tower selected
- Shows current tier, stat values
- Tier tree branch choices with cost
- Targeting mode cycle button
- Sell button with refund value

**Overlays:**
- Adaptation resistance meter (collapsible, colored bars 0–75%)
- Signal Decode minigame (between waves)
- Wave Reward card selector (endless mode, every 5 waves)
- Toast notifications (synergy discovered, resistance changes, etc.)

### 16.2 Menus

| Screen | Elements |
|--------|----------|
| **Main Menu** | Play Campaign, Endless Mode, Daily Challenge, Tower Lab, Diamond Shop, Settings |
| **Campaign Map** | Difficulty selector, level nodes with star display, region headers, lock indicators |
| **Daily Challenge** | Today's challenge description, play button (or "Completed"), streak counter |
| **Tower Lab** | Skill tree visualization per tower, global upgrade list, discovered synergies, mastery progress |
| **Diamond Shop** | IAP pack buttons, ad button with daily counter, speed unlock buttons |
| **Settings** | Music volume slider, SFX volume slider, damage numbers toggle, range-on-hover toggle, fullscreen toggle, colorblind mode toggle, language selector (English / Tiếng Việt) |
| **Pause Menu** | Resume, Restart, Quit (with confirm dialog), gold earned, enemies killed |
| **Level Complete** | Star rating display, diamond reward, continue button |
| **Level Failed** | Wave reached, restart/quit buttons |

### 16.3 Internationalization

- Two supported languages: English (`en`), Vietnamese (`vi`)
- All player-facing text uses `tr("KEY")` with translation keys
- CSV translation file: `content/translations/ui.csv` → compiled to `.translation` resources
- TranslationServer locale set from settings, persisted in SaveManager

---

## 17. Audio System

All audio is procedurally generated at runtime — no audio asset files.

### 17.1 Synth Engine

SynthEngine generates waveforms via AudioStreamGenerator:
- Oscillators: sine, square, saw, noise
- ADSR envelope (attack, decay, sustain, release)
- Lowpass filter mixing

### 17.2 Adaptive Music

4-layer system that responds to game state:

| Layer | Volume | Active During |
|-------|--------|--------------|
| Base | 0.6 | BUILDING, WAVE_ACTIVE |
| Intensity | 0.0–0.4 | WAVE_ACTIVE (scales with player health / enemy count) |
| Combat | 0.5 | WAVE_ACTIVE |
| Boss | 0.7 | Boss waves |

Music keys per region: Region 1=C, 2=D, 3=F#, 4=A, 5=E.

Silent during MENU state. Crossfade between layers on state transitions.

### 17.3 Procedural SFX

- Per-tower-type firing sounds (frequency scales with tier: base × (1.0 + (tier-1) × 0.15))
- Enemy death sounds (scaled by enemy size)
- Ability activation sounds
- Hero summon sounds
- UI interaction sounds
- 8-slot player pool with round-robin for overlapping sounds

---

## 18. Visual Polish & Game Feel

| Event | Effect |
|-------|--------|
| **Tower placed** | 0.3s power-on assembly animation (builds from bottom up) |
| **Enemy killed** | Death particles scale with enemy size; bosses get screen shake + flash |
| **Wave start** | Camera pulse (subtle zoom out/in 0.2s) + klaxon SFX |
| **Gold earned** | Floating "+15g" text rises and fades from kill position |
| **Life lost** | Screen border flashes red 0.5s; persistent red vignette if 1 life remaining |
| **Ability used** | Brief 0.1s time-slow "moment of impact" pause |
| **Upgrade applied** | Tower pulses white, expanding ring wave VFX |
| **Synergy discovered** | Synergy line draws itself with sparkle trail, "SYNERGY" text popup |
| **Adaptation change** | Enemy sprites briefly glitch/distort when resistance changes |
| **Low lives** | Persistent red vignette overlay when ≤1 life remaining |

---

## 19. Save Data Structure

Persisted as JSON to `user://last_signal_save.json`:

```
{
  "profile": {
    "language": "en",
    "settings": {
      "music_vol": 1.0,
      "sfx_vol": 1.0,
      "show_damage_numbers": true,
      "show_range_on_hover": true,
      "colorblind_mode": false
    }
  },
  "campaign": {
    "unlocked_levels": [...],
    "stars": { "1_1": 3, ... },
    "current_region": 1
  },
  "progression": {
    "diamonds": 0,
    "skill_trees": { "pulse_cannon": { "unlocked_nodes": [0, 1] }, ... },
    "global_upgrades": { "starting_gold": 3, ... },
    "abilities": { "unlocked": [...], "loadout": [...], "levels": { ... } }
  },
  "tower_mastery": {
    "pulse_cannon": { "kills": 1500, "damage": 50000.0, "waves": 200, ... },
    ...
  },
  "daily_challenge": {
    "last_completed": "2026-03-23",
    "streak": 5
  },
  "endless": {
    "high_score": 47,
    "milestones_claimed": [10, 25]
  },
  "synergies_discovered": ["shatter", "barrage"],
  "iap": {
    "diamond_doubler": false,
    "no_ads": false,
    "speed_x2": false,
    "speed_x3": false
  },
  "ads": {
    "today_count": 2,
    "last_reset": "2026-03-23"
  }
}
```

---

## 20. Constants & Balance Reference

All balance values live in `shared/constants.gd`. Key values:

**Adaptation:**
- Check interval: every 3 waves
- Dominance threshold: 40% (Normal/Hard), 25% (Nightmare)
- Resistance gain: +10% per check
- Resistance cap: 60% (Normal), 75% (Nightmare/Endless)
- Resistance decay: 5% per check when not dominant

**Synergy:**
- Range: 100px proximity
- One synergy per tower (strongest priority)

**Mastery Tiers:**
- Bronze: 500, Silver: 2000, Gold: 8000, Diamond: 25000, Master: 100000 kills

**Speed Options:** [1.0, 2.0, 3.0]

**Wave Break Duration:** 6 seconds

**Signal Decode:** 4-second input window

**Hero Duration:** 20s base, 150s summon cooldown

**Grid:** 10×10 cells, 64px cell size

---

*This document is the single source of truth for Last Signal's design. All implementation should reference this spec.*
