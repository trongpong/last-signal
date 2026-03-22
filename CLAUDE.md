# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Last Signal** is a sci-fi tower defense game built in Godot 4.6 with GDScript. Players defend the Nexus Grid against The Convergence — waves of corrupted machine drones. Features 7 tower types with branching upgrade trees, 6 enemy archetypes, adaptive enemy resistance, campaign progression, and endless mode.

## Running Tests

Tests use the GUT (Godot Unit Test) addon. Run from the Godot editor:
- **All tests:** Editor → Tools → GUT → Run Tests
- **Single test:** Set `"selected": "res://tests/test_file.gd"` in `.gutconfig.json`, then run GUT
- **Command line:** `godot --headless -s addons/gut/gut_cmdln.gd` (requires Godot in PATH)

Test files live in `res://tests/`, prefixed with `test_`, extending `GutTest`. Tests use `before_each`/`after_each` for setup, `watch_signals()` for signal assertions, and create fresh mock managers per test.

## Architecture

### Autoload Singletons (registered in project.godot)
- **GameManager** — game state machine (MENU→BUILDING→WAVE_ACTIVE→WAVE_COMPLETE→VICTORY/DEFEAT), lives, difficulty, pause
- **EconomyManager** — match gold (transient) + permanent diamonds, gold modifiers
- **SaveManager** — JSON persistence to `user://last_signal_save.json`
- **AudioManager** — music/SFX volume, state-based music switching

### Core Systems (`core/`)
Each system is a self-contained directory with its own nodes and resources:
- **GameLoop** (`game_loop.gd`) — single-level orchestrator; wires GameManager, EconomyManager, WaveManager, AdaptationManager together. Entry point: `setup()` then `start_level()`
- **Tower System** — Tower node + TowerDefinition resource + TowerTargeting + TowerRenderer + Projectile + TowerPlacer
- **Enemy System** — Enemy node + EnemyDefinition resource + EnemyHealth + EnemyRenderer + PathProvider (abstract)
- **Wave System** — WaveManager sequences waves, SubWaveDefinition defines spawn groups, WaveGenerator creates procedural waves for endless mode
- **Adaptation** — AdaptationManager tracks tower usage per wave; if player over-relies on one damage type, enemies gain resistance (checked every 3 waves)
- **Pathfinding** — FixedPathProvider (follows Path2D) and GridPathProvider (A* for maze mode) both implement PathProvider interface
- **Upgrade System** — TierTree manages 3-tier branching upgrades (2 choices per tier), applying stat multipliers
- **Progression** — GlobalUpgrade (one-time purchases) + SkillTree (diamond-based skill nodes)
- **Campaign** — CampaignManager (level unlock tracking) + LevelRegistry (level definitions)
- **Ability System** — Ability + AbilityDefinition + AbilityManager + Hero/HeroDefinition
- **Audio** — SynthEngine (waveform generation), MusicSystem (adaptive layers), SFXGenerator (procedural SFX)

### Content Layer (`content/`)
Data-driven design — towers, enemies, and waves are `.tres` Resource files. Adding new content means creating a new resource file, not writing new code. Translations use Godot's TranslationServer with CSV files.

### Scene Flow
```
Main (scenes/main.tscn) → routes between screens
  ├─ MainMenu
  ├─ CampaignMap
  └─ Game (scenes/game.tscn)
      ├─ Map (Path2D for enemy routes)
      ├─ Towers, Enemies, Projectiles (runtime children)
      └─ UI/HUD (CanvasLayer)
```

### Signal-Driven Communication
Systems communicate via signals, not direct calls. Key patterns:
- GameManager emits `state_changed`, `lives_changed`, `level_completed`, `level_failed`
- WaveManager emits `wave_started`, `wave_complete`, `all_waves_complete`, `enemy_spawn_requested`
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

## Godot 4 Compatibility

- This is a **Godot 4.6 GDScript** project. Use Godot 4 APIs only.
- Use `get_viewport().get_mouse_position()` — NOT `get_global_mouse_position()`
- Do NOT use `class_name` on autoloaded scripts
- HUD/UI nodes must have `mouse_filter = IGNORE` or `PASS` to avoid blocking game input
- Always verify API compatibility with Godot 4 before using any method

## Build & Release

- Keep release notes concise — **3-5 bullet points maximum**. Do not write lengthy release notes.

## Code Conventions

- **Classes:** PascalCase. **Methods/vars:** snake_case. **Constants:** UPPER_SNAKE_CASE. **Private:** prefixed with `_`
- All public methods and parameters have type hints: `func method(param: Type) -> ReturnType:`
- Signal names use past tense: `enemy_died`, `wave_complete`, `level_completed`
- Guard clauses for early returns: `if not condition: return`
- Composition over inheritance — systems are composed as child nodes (Tower creates TowerTargeting, TowerRenderer, etc.)
- All user-facing text uses `tr("KEY")` for i18n support
