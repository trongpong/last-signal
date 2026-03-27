# Delete Data in Settings Screen

## Overview

Add a "Data" section to the settings screen with three reset options, each with a confirmation dialog. After any reset, the game returns to the main menu.

## Reset Options

### 1. Reset Progress (orange text)
Clears:
- `campaign` — current_region, levels_completed, endless_unlocked
- `progression` — towers_unlocked (reset to defaults), skill_trees, global_upgrades, abilities_unlocked, abilities_upgrade_levels, heroes_unlocked, synergies_discovered
- `endless` — high_scores
- `daily_challenges` — last_completed_date, streak, history
- `tower_mastery`

Preserves: economy, stats, settings, monetization, unlocks.

### 2. Reset Stats (orange text)
Clears:
- `stats` — total_waves_survived, total_enemies_killed, total_gold_earned, total_play_time_seconds

Preserves: everything else.

### 3. Reset Everything (red text)
Resets all data to factory defaults (equivalent to `get_default_save_data()`). This includes economy, settings, progression, stats, monetization, unlocks — everything.

## UI Layout

New "Data" section added at the bottom of the settings screen, below the Language section, separated by an `HSeparator`.

Each reset option is a `Button` matching existing settings button styling (minimum size 260x56, font size 20). Reset Progress and Reset Stats use orange (`Color(1.0, 0.6, 0.2)`). Reset Everything uses red (`Color(1.0, 0.3, 0.3)`).

### Confirmation Dialog

Each button reveals a `PanelContainer` confirmation panel (hidden by default) with:
- Warning label describing what will be lost (centered, specific per action)
- "Yes" button (confirms the action)
- "No" button (cancels, hides the panel, returns focus to the reset button)

Pattern matches the existing pause menu quit confirmation.

## Flow

1. Player taps a reset button
2. Confirmation panel appears with specific warning text
3. **Confirm**: SaveManager resets the relevant sections, saves, settings menu emits `data_reset` signal
4. `main.gd` receives `data_reset`, navigates to main menu
5. **Cancel**: Confirmation hides, focus returns to reset button

## Implementation Scope

### `save_manager.gd`
Add three public methods:
- `reset_progress() -> void` — resets campaign, progression, endless, daily_challenges, tower_mastery to defaults, then saves
- `reset_stats() -> void` — resets stats to defaults, then saves
- `reset_all() -> void` — replaces `data` with `get_default_save_data()`, then saves

### `settings_menu.gd`
- Add "Data" section with 3 buttons and 3 confirmation panels
- Add `data_reset` signal
- Wire button callbacks to call SaveManager reset methods and emit `data_reset`
- Set up focus navigation for the new buttons

### `main.gd` (or parent handling settings)
- Connect `data_reset` signal to navigate back to main menu

### `content/translations/ui.csv`
Add translation keys (~10):
- `SETTINGS_DATA` — section label
- `UI_RESET_PROGRESS` — button label
- `UI_RESET_STATS` — button label
- `UI_RESET_EVERYTHING` — button label
- `UI_CONFIRM_RESET_PROGRESS` — warning text
- `UI_CONFIRM_RESET_STATS` — warning text
- `UI_CONFIRM_RESET_EVERYTHING` — warning text
- `UI_YES` — (may already exist)
- `UI_NO` — (may already exist)

### `test_save_manager.gd`
Add tests:
- `test_reset_progress` — verify only progress sections are cleared
- `test_reset_stats` — verify only stats section is cleared
- `test_reset_all` — verify full factory reset
- Each test should verify preserved sections remain unchanged
