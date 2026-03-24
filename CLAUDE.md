# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Last Signal** is a sci-fi tower defense game built in Godot 4.6 with GDScript. Players defend the Nexus Grid against The Convergence — waves of corrupted machine drones. Features 7 tower types with 3-tier branching upgrade trees (8 end-states each), 6 enemy archetypes, adaptive enemy resistance, campaign progression, endless mode, and a between-wave signal decode minigame.

## Running Tests

Tests use the GUT (Godot Unit Test) addon (867 passing tests).

- **All tests:** Editor → Tools → GUT → Run Tests
- **Single test:** Set `"selected": "res://tests/test_file.gd"` in `.gutconfig.json`, then run GUT
- **Command line:** `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (requires Godot in PATH)
- **Headless caveat:** GUT editor plugin is NOT enabled (causes class_name import failures). Running headless requires manually adding 9 GUT class entries to `.godot/global_script_class_cache.cfg`. See `godot --headless --import` to regenerate the cache (strips GUT entries — re-add after).

Test files live in `res://tests/`, prefixed with `test_`, extending `GutTest`. Tests use `before_each`/`after_each` for setup, `watch_signals()` for signal assertions, and create fresh mock managers per test.

## Architecture

### Autoload Singletons (registered in project.godot)
- **GameManager** — game state machine (MENU→BUILDING→WAVE_ACTIVE→WAVE_COMPLETE→VICTORY/DEFEAT), lives, difficulty, pause
- **EconomyManager** — match gold (transient) + permanent diamonds, gold modifiers, diamond doubler
- **SaveManager** — JSON persistence to `user://last_signal_save.json`
- **AudioManager** — music/SFX volume, state-based music switching

**Important:** Access autoloads directly by name (`SaveManager.data`, `AudioManager.play_sfx()`). Do NOT use `Engine.has_singleton()` / `Engine.get_singleton()` — those are for native GDExtension singletons, not GDScript autoloads.

### Core Systems (`core/`)
Each system is a self-contained directory with its own nodes and resources:
- **GameLoop** (`game_loop.gd`) — single-level orchestrator; wires GameManager, EconomyManager, WaveManager, AdaptationManager together. Skips diamond awards for daily challenges (handled by DailyChallengeManager). Entry point: `setup()` then `start_level()`
- **Tower System** — Tower node + TowerDefinition resource + TowerTargeting + TowerRenderer + Projectile + TowerPlacer. Tower exposes `get_effective_*()` methods that aggregate base stats + tier upgrade specials + skill tree specials.
- **Enemy System** — Enemy node + EnemyDefinition resource + EnemyHealth + EnemyRenderer + PathProvider (abstract). Min 1 damage per hit after all reductions. Enraged modifier preserves difficulty speed multiplier.
- **Wave System** — WaveManager sequences waves, SubWaveDefinition defines spawn groups, WaveGenerator creates procedural waves for endless mode. Break timer pauses during signal decode minigame.
- **Adaptation** — AdaptationManager tracks tower usage per wave; if player over-relies on one damage type, enemies gain resistance (checked every 3 waves). Unused damage types also decay resistance.
- **Pathfinding** — FixedPathProvider (follows Path2D) and GridPathProvider (A* for maze mode) both implement PathProvider interface
- **Upgrade System** — TierTree manages 3-tier branching upgrades (2 choices per tier, 8 end-states). `apply_upgrades()` handles stat multipliers; `collect_specials()` gathers special strings (e.g., `chain_count+1`, `splash+20`, `pierce+1`) which Tower's `get_effective_*()` methods parse and apply.
- **Progression** — GlobalUpgrade (one-time purchases) + SkillTree (diamond-based skill nodes, 5 nodes × 5 levels per tower)
- **Campaign** — CampaignManager (level unlock tracking, per-difficulty star records) + LevelRegistry (level definitions)
- **Ability System** — Ability + AbilityDefinition + AbilityManager + Hero/HeroDefinition
- **Monetization** — AdManager (rewarded ads, x2 bonus, daily challenge RI), IAPManager (diamond packs, doubler, no-ads)
- **Audio** — SynthEngine (waveform generation), MusicSystem (adaptive layers), SFXGenerator (procedural SFX)

### Content Layer (`content/`)
Data-driven design — towers, enemies, and waves are `.tres` Resource files. Adding new content means creating a new resource file, not writing new code. Translations use Godot's TranslationServer with CSV files (`content/translations/ui.csv`, 226 keys, English + Vietnamese).

### Scene Flow
```
Main (scenes/main.tscn) → routes between screens
  ├─ MainMenu
  ├─ CampaignMap
  ├─ DailyChallengeScreen
  └─ Game (scenes/game.tscn)
      ├─ Map (Path2D for enemy routes)
      ├─ Towers, Enemies, Projectiles (runtime children)
      ├─ Signal Decode Minigame (between waves)
      └─ UI/HUD (CanvasLayer)
```

### Signal-Driven Communication
Systems communicate via signals, not direct calls. Key patterns:
- GameManager emits `state_changed`, `lives_changed`, `level_completed`, `level_failed`
- WaveManager emits `wave_started`, `wave_complete`, `all_waves_complete`, `enemy_spawn_requested`, `break_started`
- Enemy emits `enemy_died`, `enemy_reached_exit`
- GameLoop connects these together and calls manager methods in response

### Constants & Enums
- **`shared/enums.gd`** — all game enums (Difficulty, GameState, TowerType, EnemyArchetype, DamageType, etc.)
- **`shared/constants.gd`** — all balance values. Dictionaries keyed by enum values use `var` (not `const`) because GDScript enum keys require runtime resolution. Access via `Constants.new()` for instance dictionaries or `Constants.CONST_NAME` for true constants.

## General Rules

- **Only implement exactly what is requested.** Do not add extra features or expand scope without asking first.
- **Save plans/design docs to files immediately** (e.g., `docs/plan.md`) — don't just output them to the conversation.
- **Break large tasks into checkpoints.** Commit and tell the user how to test after each phase. Do not start the next phase until the user confirms the current one works.

## Bug Fixing

- **Grep first, fix second.** Before fixing any bug, grep the entire project for all instances of the same pattern. List every file and line affected, then fix ALL of them in one pass.
- After applying a fix, verify no regressions by checking all files that reference the changed functions.
- **Run tests after fixing** to catch regressions: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`

## Godot 4 Compatibility

- This is a **Godot 4.6 GDScript** project. Use Godot 4 APIs only.
- Use `get_viewport().get_mouse_position()` — NOT `get_global_mouse_position()`
- Do NOT use `class_name` on autoloaded scripts
- Do NOT use `Engine.has_singleton()` for autoloads — access them directly by name
- Overlay/modal UI backdrops must use `mouse_filter = STOP` to block clicks to game behind
- Non-interactive HUD elements must have `mouse_filter = IGNORE` or `PASS`
- Always verify API compatibility with Godot 4 before using any method

## Build & Release

- Keep release notes concise — **3-5 bullet points maximum**. Do not write lengthy release notes.
- Build AAB: `godot --headless --export-release "Android" build/game.aab`

## Code Conventions

- **Classes:** PascalCase. **Methods/vars:** snake_case. **Constants:** UPPER_SNAKE_CASE. **Private:** prefixed with `_`
- All public methods and parameters have type hints: `func method(param: Type) -> ReturnType:`
- Signal names use past tense: `enemy_died`, `wave_complete`, `level_completed`
- Guard clauses for early returns: `if not condition: return`
- Composition over inheritance — systems are composed as child nodes (Tower creates TowerTargeting, TowerRenderer, etc.)
- All user-facing text uses `tr("KEY")` for i18n support (English + Vietnamese in `content/translations/ui.csv`)
- Tower upgrade specials use string patterns: `chain_count+N`, `splash+N`, `slow_factor-N`, `pierce+N`, `income+N`, `buff_damage_mult+N`
