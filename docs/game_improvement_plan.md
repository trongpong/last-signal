# Last Signal — Game Improvement Plan

> Prioritized roadmap for making the game more fun, more addictive, and more replayable.
> Each phase builds on the previous. Items within a phase can be worked in parallel.

---

## Phase 1 — Activate Existing Infrastructure

These systems are already architected (classes, managers, cost curves, UI hooks exist) but have **zero content resources**. Filling them in transforms retention overnight.

### 1.1 Meta-Progression: Skill Trees + Global Upgrades

**Problem:** No permanent progression between matches. Players have no reason to replay.

**What exists:** `SkillTree`, `SkillNode`, `GlobalUpgrade` classes; cost arrays in `Constants` (skill: 80–1200 diamonds across 10 tiers; global: 50–1400 diamonds); `ProgressionManager` applies bonuses; Tower Lab UI renders trees. **What's missing:** `.tres` resource files.

**Skill tree nodes per tower (create one SkillTree .tres per tower type):**

| Tower | Node 1 | Node 2 | Node 3 |
|-------|--------|--------|--------|
| Pulse Cannon | +5% damage/level | +3% fire rate/level | "Piercing Rounds" — projectiles hit 2 targets (level 3+) |
| Arc Emitter | +1 chain target at level 3 | +4% chain range/level | "Conductive Residue" — chained enemies take +10% damage for 2s |
| Cryo Array | +0.05s slow duration/level | +3% range/level | "Flash Freeze" — 5% chance to fully stop enemy for 1s |
| Missile Pod | +4% splash radius/level | +3% damage/level | "Cluster Munitions" — on impact, scatter 3 mini-projectiles |
| Beam Spire | +5% damage/level | +3% range/level | "Overload Beam" — after 3 consecutive hits on same target, deal 2x damage |
| Nano Hive | +3% buff range/level | +2% buff damage mult/level | "Repair Drones" — heal nearby towers (reduce ability cooldowns by 1s/pulse) |
| Harvester | +10 income/level | +3% range/level | "Salvage Protocol" — enemies killed in range drop +15% gold |

**Global upgrades (create GlobalUpgrade .tres per upgrade):**

| Upgrade | Effect/Tier | Max Tier |
|---------|-------------|----------|
| Starting Gold | +25 gold | 10 |
| Starting Lives | +1 life | 5 |
| Tower Cost Reduction | -2% build cost | 10 |
| Wave Clear Bonus | +10 gold | 10 |
| Tower Sell Refund | +3% refund rate | 5 |
| Diamond Bonus | +5% diamond earnings | 10 |
| Ability Cooldown | -2% base cooldown | 10 |
| Harvester Efficiency | +5% income | 5 |

---

### 1.2 Abilities — The Panic Buttons

**Problem:** Combat is passive after tower placement. No clutch moments, no agency during waves.

**What exists:** `Ability`, `AbilityDefinition`, `AbilityManager` (3 slots, cooldown system, position/tower targeting); 6 ability names with cooldowns hardcoded in `AbilityManager`; unlock/upgrade cost arrays in `Constants` (unlock: 200 diamonds; upgrade: 100–600 diamonds across 5 tiers); Ability Bar UI. **What's missing:** `AbilityDefinition` `.tres` files and the actual effect implementations.

| Ability | Cooldown | Target | Effect | Upgrade Scaling |
|---------|----------|--------|--------|----------------|
| Orbital Strike | 60s | Position | After 1s delay, deal 500 damage in 80px radius. Screen shake. | +100 damage/tier, +10px radius/tier |
| EMP Burst | 45s | Global | All enemies on screen stunned for 3s. | +0.5s duration/tier |
| Repair Wave | 40s | Global | Restore 1 lost life. | +1 life restored at tier 3 and 5 |
| Shield Matrix | 50s | Position | 120px zone where enemies take 50% reduced speed for 6s. | +1s duration/tier, +20px radius/tier |
| Overclock | 30s | Tower | Target tower fires at 3x speed for 8s. | +1s duration/tier, +0.5x fire rate/tier |
| Scrap Salvage | 35s | Global | All enemies killed in next 10s drop 2x gold. | +2s duration/tier, +0.25x gold mult/tier |

**Implementation notes:**
- Orbital Strike: spawn AoE damage zone after tween delay; reuse Projectile splash logic.
- EMP Burst: iterate `enemies` group, set `speed_modifier = 0.0` for duration, restore after.
- Repair Wave: call `GameManager.add_lives(amount)`.
- Shield Matrix: spawn area node, enemies inside get `speed_modifier *= 0.5`.
- Overclock: set target tower `fire_rate_modifier *= 3.0`, restore after duration.
- Scrap Salvage: set `EconomyManager.gold_modifier *= 2.0` for duration, restore after.

---

## Phase 2 — Make Combat Feel Alive

### 2.1 Enemy Special Behaviors

**Problem:** All 17 enemies are stat-only HP bags. Healers don't heal. Shielders don't shield allies. Combat is flat and non-reactive.

**What exists:** `EnemyDefinition.abilities` array (currently empty for all); archetype enum system; `EnemyHealth` handles shield/armor/resistance. **What's missing:** ability implementations and wiring.

| Archetype | Behavior | Mechanic | Player Counter-Strategy |
|-----------|----------|----------|------------------------|
| **Healer** | Heal Pulse | Every 4s, restore 15% max HP to all allies within 80px. Green pulse VFX. | Prioritize Healer with STRONGEST targeting or Beam Spire range. |
| **Shielder** | Shield Aura | Every 5s, grant 30 shield points to allies within 60px (max 100 shield). Blue dome VFX. | Kill Shielder first or use high-burst damage to punch through shields. |
| **Scout** | Scatter Signal | On death, all allies within 100px gain +20% speed for 3s. Yellow flash VFX. | Use Cryo slow to counteract. Avoid killing scouts near groups. |
| **Flyer** | Altitude | Ignores ground path, flies in a straight line from spawn to exit (shorter path). | Forces specific tower placement along flight line. |
| **Tank** | Fortified | Takes 25% reduced damage from the first tower type that hits it per wave. Visible armor glow matches damage color. | Forces damage type diversity per tank. |
| **Drone Swarm** | Overwhelm | When 5+ Drone Swarm units are alive simultaneously, all gain +10% speed. | Splash damage (Missile Pod) to thin the herd fast. |

**Implementation approach:**
- Add `_process_abilities(delta)` to `Enemy` base class, called each frame.
- Each ability is a timer-based check using `_ability_cooldown` tracking.
- Healer/Shielder query the `enemies` group for nearby allies.
- Scout's on-death ability triggers in the existing `enemy_died` signal handler.
- Flyer straight-line path: add `PathProvider` override that returns a 2-point path.

---

### 2.2 Visible Adaptation (Surface the Resistance System)

**Problem:** The adaptation system is the game's most unique mechanic, but it's completely invisible to the player. It feels like a hidden nerf rather than a dramatic game event.

**What exists:** `AdaptationManager` tracks damage per type, checks every 3 waves, applies resistance 0.0–0.75. `EnemyHealth.take_damage()` applies resistance reduction. **What's missing:** player-facing feedback.

**Changes:**

1. **Wave announcement banner:**
   - After each adaptation check (every 3 waves), show a 3-second banner:
   - Resistance rising: `"⚠ THE CONVERGENCE ADAPTS — [DamageType] resistance increasing"` (red tint)
   - Resistance falling: `"THE CONVERGENCE DESTABILIZES — [DamageType] resistance fading"` (green tint)
   - No change: no banner

2. **Enemy visual evolution:**
   - Enemies with >20% resistance to a damage type gain a subtle visual indicator:
   - CRYO resistance → frost-cracked blue armor lines on sprite
   - MISSILE resistance → thicker dark plating outline
   - ARC resistance → trailing ground-wire particles
   - PULSE resistance → pulsing red energy shield shimmer
   - BEAM resistance → reflective mirror-sheen overlay
   - Implementation: add optional `_draw()` overlays in `EnemyRenderer` keyed by resistance map.

3. **HUD resistance meter:**
   - Small collapsible panel showing current resistance levels per damage type (colored bars, 0–75%).
   - Updates after each adaptation check. Helps player plan next tower investment.

---

## Phase 3 — Strategic Depth

### 3.1 Tower Synergy Combos

**Problem:** Tower placement is purely about coverage and range. No spatial puzzle-solving or discovery.

**Mechanic:** When two specific tower types are placed within 100px of each other, both gain a passive synergy bonus. A glowing line connects synergized towers. Each tower can only participate in one synergy at a time (strongest takes priority).

| Pair | Synergy Name | Effect |
|------|-------------|--------|
| Cryo + Arc | Shatter | Frozen/slowed enemies take 2x chain damage from Arc |
| Pulse + Missile | Barrage | Both gain +15% fire rate |
| Nano Hive + Beam | Amplify | Beam projectiles pierce through first target, hitting a second |
| Cryo + Missile | Frostbite | Slowed enemies take +25% splash damage |
| Harvester + Nano | Efficiency | Harvester income +30% |
| Pulse + Cryo | Cold Snap | Pulse hits on slowed enemies extend slow by 0.5s |
| Arc + Beam | Conduit | Beam can chain to 1 additional target via Arc's chain system |
| Missile + Beam | Focus Fire | If both target same enemy, that enemy takes +20% damage from all sources for 2s |

**Implementation approach:**
- `SynergyManager` node in GameLoop: maintains a dictionary of active synergies.
- On tower placed/sold, recalculate synergies for nearby towers (spatial query, 100px radius).
- Each synergy applies a modifier via the existing stat modifier system or a flag on the tower/projectile.
- Visual: draw a Line2D between synergized towers with a glow shader.

**Discovery UX:**
- First time a synergy activates, show a brief "SYNERGY DISCOVERED: Shatter" toast.
- Tower Lab UI shows discovered synergies with descriptions.
- Undiscovered synergies show as "???" — encourages experimentation.

---

### 3.2 Elite Enemy Modifiers (Endless Mode)

**Problem:** Endless mode becomes monotonous after wave 20 — just bigger numbers. No surprises.

**Mechanic:** Starting at wave 15 in endless mode, random enemies in each wave spawn as "Elites" with a visible modifier prefix and unique VFX. Elite spawn rate increases with wave number.

| Modifier | Visual | Effect | Counter |
|----------|--------|--------|---------|
| Regenerating | Green pulse every 2s | Heals 2% max HP/sec | Burst damage, focus fire |
| Splitting | Fracture lines on body | On death, spawns 2 copies at 30% HP and 80% speed | Splash damage, AoE |
| Phasing | Flickers/ghosts every 3s | Untargetable for 0.5s every 3s | High fire rate towers |
| Magnetic | Pull aura ring | Allies within 60px move 15% faster | Kill first, isolate |
| Reflective | Mirror sheen surface | 15% damage reflected; attacking tower paused 0.3s | Diverse tower spread |
| Enraged | Red glow, growing size | Gains +5% speed per 3s alive. Caps at +50%. | Fast kill, high DPS |

**Scaling:**
- Wave 15–19: 1 elite per wave
- Wave 20–29: 2 elites per wave
- Wave 30–49: 20% of enemies are elite
- Wave 50+: 40% of enemies are elite, can have 2 modifiers ("Regenerating Phasing Tank")

**Implementation:**
- `EliteModifier` resource class: `modifier_type`, `visual_color`, `stat_overrides`.
- On enemy spawn, roll for elite based on wave number. Apply modifier to `Enemy` instance.
- Each modifier hooks into existing systems (HP regen in `_process`, split in `enemy_died` handler, etc.).

---

## Phase 4 — Long-Term Engagement Hooks

### 4.1 Roguelite Wave Rewards (Endless Mode)

**Problem:** Endless runs lack variety. Every run at the same wave count plays identically.

**Mechanic:** After every 5 waves in endless, pause and present 3 random buff cards. Player picks one. Buffs stack for the entire run.

**Buff pool (30+ cards across categories):**

**Offensive:**
- "Overcharged Capacitors" — All towers +10% damage
- "Rapid Cycling" — All towers +8% fire rate
- "Extended Range" — All towers +12% range
- "Armor Piercing" — All damage ignores 15% of enemy armor
- "Critical Strike" — All attacks have 5% chance to deal 3x damage

**Defensive:**
- "Reinforced Nexus" — +2 lives
- "Emergency Protocols" — When a life is lost, all enemies take 100 damage
- "Temporal Buffer" — Enemies move 5% slower globally

**Economic:**
- "Salvage Operations" — +20% gold from kills
- "Budget Engineering" — Tower costs -10%
- "Efficient Refunds" — Sell value +15%

**Risky/Trade-off:**
- "Glass Cannon" — All towers +25% damage, but -1 life
- "Speed Demons" — Enemies +15% speed, but +30% gold
- "Minimalist" — Can only build 3 more towers, but all towers +40% damage

**Synergy/Specific:**
- "Cryo Mastery" — Cryo slow effect +25%, slow duration +1s
- "Chain Reaction" — Arc chain count +2
- "Carpet Protocol" — Missile splash +30% radius
- "Signal Leech" — Adaptation resistance decays 2x faster

**Implementation:**
- `WaveReward` resource: `title`, `description`, `icon_color`, `modifiers: Dictionary`.
- `WaveRewardManager`: maintains pool, tracks picked rewards, applies global modifiers.
- UI: 3-card overlay between waves with brief descriptions. 8-second timer to choose (random if no pick).
- Modifiers applied through existing `fire_rate_modifier`, `damage_modifier`, `gold_modifier` systems.

---

### 4.2 Daily Challenge Mode

**Problem:** No daily reason to open the game. No shared competitive experience.

**Mechanic:** One challenge per day, fixed seed, everyone gets the same map/waves/constraint. Results posted to a local leaderboard (or online if desired later).

**Challenge types (rotate weekly):**

| Day | Type | Example |
|-----|------|---------|
| Mon | Restricted Towers | "Cryo Protocol" — Only Cryo + Pulse available. Enemies +30% speed. |
| Tue | Economy | "Budget Run" — 50% gold income. Reward doubles if 3-star. |
| Wed | Survival | "One Signal" — 1 starting life. Towers cost -40%. |
| Thu | Speed | "No Breaks" — 0s between waves. 2x gold. |
| Fri | Puzzle | "Fixed Layout" — Pre-placed towers, you choose upgrades only. |
| Sat | Chaos | "Double Trouble" — 2 enemy paths simultaneously. |
| Sun | Boss Rush | "Convergence Core" — Bosses every 3 waves. 3x diamonds. |

**Rewards:**
- Complete: 50 diamonds
- 3-star: 100 diamonds
- Top 10% (if leaderboard): 150 diamonds
- Streak bonus: +10 diamonds per consecutive day completed (caps at +70)

**Implementation:**
- Daily seed: `hash(date_string)` determines map, waves, constraints.
- `DailyChallengeManager`: generates challenge from seed, tracks completion/streak in `SaveManager`.
- Reuses existing `GameLoop` with modifier overrides (restricted tower list, gold multiplier, etc.).
- Streak counter saved in profile. Resets on miss.

---

### 4.3 Tower Mastery System

**Problem:** No long-term attachment to specific towers. No visible progression within a single tower type.

**Mechanic:** Each tower type tracks lifetime stats across all matches. At thresholds, unlock mastery rewards.

| Tier | Threshold | Reward |
|------|-----------|--------|
| Bronze | 500 kills | Cosmetic: subtle glow outline on tower |
| Silver | 2,000 kills | +3% permanent damage bonus (stacks with skill tree) |
| Gold | 8,000 kills | Cosmetic: unique tower shape variant |
| Diamond | 25,000 kills | Title for profile + unique upgrade path color |
| Master | 100,000 kills | "Mastered" badge + tower costs -5% permanently |

**Tracked stats per tower type:**
- Total kills
- Total damage dealt
- Waves active (across all matches)
- Highest single-hit damage
- Most kills in a single match

**Implementation:**
- `tower_mastery` dictionary in save data: `{ tower_type_id: { kills: int, damage: float, ... } }`.
- On `enemy_died`, credit the killing tower's type.
- Mastery rewards applied as permanent modifiers in `ProgressionManager`.
- Tower Lab UI shows mastery progress bars and unlocked rewards per tower.

---

## Phase 5 — Polish & Feel

### 5.1 Signal Decode Minigame (Between Waves)

**Problem:** The 6-second wave break is dead time. Player waits passively.

**Mechanic:** During wave breaks, a small "Signal Decode" prompt appears (bottom-center, non-intrusive). A 4-symbol sequence flashes (using the game's sci-fi glyphs), player taps them back in order within 4 seconds.

- **Success:** Bonus reward (random): +20 gold, or +5% tower damage next wave, or -3s on one ability cooldown.
- **Fail or skip:** Nothing happens. No penalty. Purely optional.
- **Lore tie-in:** "Intercepted Convergence transmission — decode it?"

**Scaling:** Sequence length grows: 4 symbols (waves 1–10), 5 symbols (11–25), 6 symbols (26+). Rewards scale with difficulty.

**Implementation:**
- `SignalDecodeMinigame` UI node, child of HUD.
- Appears during `WAVE_COMPLETE` state, hides on `WAVE_ACTIVE`.
- 4–6 `TextureButton` glyph buttons. Random sequence generated per wave.
- Input validated against expected sequence. Reward applied via `EconomyManager` or temporary modifier.

---

### 5.2 Juice & Game Feel Improvements

Small changes that make the game feel more satisfying:

| Element | Improvement |
|---------|-------------|
| **Tower placement** | Brief "power on" animation — tower assembles from bottom up over 0.3s |
| **Enemy kill** | Scale up death particle based on enemy size. Boss deaths get screen shake + flash. |
| **Wave start** | Quick camera pulse (subtle zoom out/in over 0.2s) + klaxon SFX |
| **Gold earned** | Floating "+15g" text that rises and fades from enemy death position |
| **Life lost** | Screen border flashes red for 0.5s. If 1 life remaining, persistent red vignette. |
| **Ability used** | Brief time-slow (0.1s) when activated, like a "moment of impact" pause |
| **Upgrade applied** | Tower pulses white and emits expanding ring wave |
| **Combo discovered** | Synergy line draws itself with a sparkle trail, brief "SYNERGY" text popup |
| **Adaptation warning** | Enemy sprites briefly glitch/distort when resistance changes |

---

## Summary

| Phase | Items | What It Unlocks |
|-------|-------|-----------------|
| **1** | Meta-progression + Abilities | "One more run" loop. Player agency during waves. |
| **2** | Enemy behaviors + Visible adaptation | Combat that feels alive and reactive. |
| **3** | Tower synergies + Elite modifiers | Strategic depth and spatial puzzle-solving. |
| **4** | Roguelite rewards + Dailies + Mastery | Long-term retention, daily habit, tower attachment. |
| **5** | Signal Decode + Juice/Feel | Polish that makes everything *feel* good. |

Each phase is independently shippable. Phase 1 is the highest priority — it activates infrastructure that already exists and has the largest impact on player retention.
