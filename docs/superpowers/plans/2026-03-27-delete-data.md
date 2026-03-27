# Delete Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Data" section to the settings screen with three reset options (Reset Progress, Reset Stats, Reset Everything), each with a confirmation dialog, returning to main menu after reset.

**Architecture:** Three new public methods on SaveManager handle the data reset logic. SettingsMenu gets a new Data section with buttons and confirmation panels. A new `data_reset` signal on SettingsMenu tells `main.gd` to navigate back to the main menu.

**Tech Stack:** Godot 4.6, GDScript

---

### Task 1: Add reset methods to SaveManager

**Files:**
- Modify: `core/save/save_manager.gd:310-324` (append after `apply_economy`)
- Test: `tests/test_save_manager.gd`

- [ ] **Step 1: Write failing test for `reset_progress()`**

Add to `tests/test_save_manager.gd` at the end of the file:

```gdscript
# ---------------------------------------------------------------------------
# Data reset
# ---------------------------------------------------------------------------

func test_reset_progress_clears_campaign() -> void:
	sm.data["campaign"]["levels_completed"]["level_01"] = {"0": {"best_stars": 3, "completed": true}}
	sm.data["campaign"]["endless_unlocked"] = true
	sm.reset_progress()
	var defaults := sm.get_default_save_data()
	assert_eq(sm.data["campaign"], defaults["campaign"])

func test_reset_progress_clears_progression() -> void:
	sm.data["progression"]["skill_trees"]["pulse"] = {"level": 3}
	sm.data["progression"]["towers_unlocked"].append("VOID_PRISM")
	sm.reset_progress()
	var defaults := sm.get_default_save_data()
	assert_eq(sm.data["progression"], defaults["progression"])

func test_reset_progress_clears_endless() -> void:
	sm.data["endless"]["high_scores"]["endless_01"] = 500
	sm.reset_progress()
	assert_true(sm.data["endless"]["high_scores"].is_empty())

func test_reset_progress_clears_daily_challenges() -> void:
	sm.data["daily_challenges"]["streak"] = 7
	sm.data["daily_challenges"]["last_completed_date"] = "2026-03-27"
	sm.reset_progress()
	var defaults := sm.get_default_save_data()
	assert_eq(sm.data["daily_challenges"], defaults["daily_challenges"])

func test_reset_progress_clears_tower_mastery() -> void:
	sm.data["tower_mastery"]["pulse"] = {"kills": 100}
	sm.reset_progress()
	assert_true(sm.data["tower_mastery"].is_empty())

func test_reset_progress_preserves_economy() -> void:
	sm.data["economy"]["diamonds"] = 999
	sm.reset_progress()
	assert_eq(sm.data["economy"]["diamonds"], 999)

func test_reset_progress_preserves_stats() -> void:
	sm.data["stats"]["total_enemies_killed"] = 5000
	sm.reset_progress()
	assert_eq(sm.data["stats"]["total_enemies_killed"], 5000)

func test_reset_progress_preserves_settings() -> void:
	sm.data["profile"]["settings"]["music_vol"] = 0.5
	sm.reset_progress()
	assert_eq(sm.data["profile"]["settings"]["music_vol"], 0.5)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
Expected: FAIL — `reset_progress` method does not exist.

- [ ] **Step 3: Write failing test for `reset_stats()`**

Add to `tests/test_save_manager.gd`:

```gdscript
func test_reset_stats_clears_stats() -> void:
	sm.data["stats"]["total_enemies_killed"] = 5000
	sm.data["stats"]["total_gold_earned"] = 100000
	sm.data["stats"]["total_waves_survived"] = 200
	sm.data["stats"]["total_play_time_seconds"] = 36000
	sm.reset_stats()
	var defaults := sm.get_default_save_data()
	assert_eq(sm.data["stats"], defaults["stats"])

func test_reset_stats_preserves_economy() -> void:
	sm.data["economy"]["diamonds"] = 999
	sm.reset_stats()
	assert_eq(sm.data["economy"]["diamonds"], 999)

func test_reset_stats_preserves_campaign() -> void:
	sm.data["campaign"]["levels_completed"]["level_01"] = {"0": {"best_stars": 3, "completed": true}}
	sm.reset_stats()
	assert_false(sm.data["campaign"]["levels_completed"].is_empty())
```

- [ ] **Step 4: Write failing test for `reset_all()`**

Add to `tests/test_save_manager.gd`:

```gdscript
func test_reset_all_returns_to_defaults() -> void:
	sm.data["economy"]["diamonds"] = 999
	sm.data["campaign"]["levels_completed"]["level_01"] = {"0": {"best_stars": 3, "completed": true}}
	sm.data["progression"]["skill_trees"]["pulse"] = {"level": 3}
	sm.data["profile"]["settings"]["music_vol"] = 0.5
	sm.data["stats"]["total_enemies_killed"] = 5000
	sm.reset_all()
	var defaults := sm.get_default_save_data()
	assert_eq(sm.data, defaults)
```

- [ ] **Step 5: Implement the three reset methods**

Add to `core/save/save_manager.gd` after the `apply_economy` method (after line 323):

```gdscript
# ---------------------------------------------------------------------------
# Data Reset
# ---------------------------------------------------------------------------

## Resets campaign, progression, endless, daily challenges, and tower mastery
## to defaults. Preserves economy, stats, settings, monetization, and unlocks.
func reset_progress() -> void:
	var defaults := get_default_save_data()
	data["campaign"] = defaults["campaign"].duplicate(true)
	data["progression"] = defaults["progression"].duplicate(true)
	data["endless"] = defaults["endless"].duplicate(true)
	data["daily_challenges"] = defaults["daily_challenges"].duplicate(true)
	data["tower_mastery"] = defaults["tower_mastery"].duplicate(true)
	save_game()

## Resets stats to defaults. Preserves all other data.
func reset_stats() -> void:
	var defaults := get_default_save_data()
	data["stats"] = defaults["stats"].duplicate(true)
	save_game()

## Full factory reset — replaces all data with defaults.
func reset_all() -> void:
	data = get_default_save_data()
	save_game()
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
Expected: All new tests PASS.

- [ ] **Step 7: Commit**

```bash
git add core/save/save_manager.gd tests/test_save_manager.gd
git commit -m "feat(save): add reset_progress, reset_stats, reset_all methods"
```

---

### Task 2: Add translation keys

**Files:**
- Modify: `content/translations/ui.csv:227` (append before blank line at end)

- [ ] **Step 1: Add translation entries**

Append these lines to `content/translations/ui.csv` before the trailing blank line (after line 227, `TOAST_DECODE_LIFE`):

```csv
SETTINGS_DATA,Data,Dữ liệu
UI_RESET_PROGRESS,Reset Progress,Đặt lại Tiến trình
UI_RESET_STATS,Reset Stats,Đặt lại Thống kê
UI_RESET_EVERYTHING,Reset Everything,Đặt lại Tất cả
UI_CONFIRM_RESET_PROGRESS,"This will erase all campaign progress, tower upgrades, and challenge history. Economy and stats are kept. Continue?","Thao tác này sẽ xóa toàn bộ tiến trình chiến dịch, nâng cấp tháp và lịch sử thử thách. Kinh tế và thống kê được giữ lại. Tiếp tục?"
UI_CONFIRM_RESET_STATS,This will erase all gameplay statistics. Continue?,Thao tác này sẽ xóa toàn bộ thống kê. Tiếp tục?
UI_CONFIRM_RESET_EVERYTHING,This will erase ALL saved data and return everything to defaults. This cannot be undone. Continue?,Thao tác này sẽ xóa TẤT CẢ dữ liệu đã lưu và đặt lại mọi thứ về mặc định. Không thể hoàn tác. Tiếp tục?
```

- [ ] **Step 2: Commit**

```bash
git add content/translations/ui.csv
git commit -m "feat(i18n): add delete data translation keys"
```

---

### Task 3: Add Data section to settings screen

**Files:**
- Modify: `ui/menus/settings_menu.gd`

- [ ] **Step 1: Add the `data_reset` signal**

Add a new signal after the existing `back_pressed` signal at line 11 of `settings_menu.gd`:

```gdscript
signal data_reset
```

- [ ] **Step 2: Add instance variables for confirmation panels**

Add after the `_colorblind_check` variable (after line 32):

```gdscript
var _confirm_overlay: ColorRect
var _confirm_label: Label
var _confirm_yes_btn: Button
var _confirm_no_btn: Button
var _pending_reset_action: Callable
```

- [ ] **Step 3: Build the Data section in `_build_layout()`**

Add the following code inside `_build_layout()`, after the language `_language_option` is added to vbox (after line 253, before the focus neighbors block):

```gdscript
	vbox.add_child(HSeparator.new())

	# --- Data section ---
	var data_header := Label.new()
	data_header.text = tr("SETTINGS_DATA")
	data_header.add_theme_font_size_override("font_size", 16)
	data_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(data_header)

	var reset_progress_btn := Button.new()
	reset_progress_btn.text = tr("UI_RESET_PROGRESS")
	reset_progress_btn.focus_mode = Control.FOCUS_ALL
	reset_progress_btn.custom_minimum_size = Vector2(260, 56)
	reset_progress_btn.add_theme_font_size_override("font_size", 20)
	reset_progress_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	reset_progress_btn.pressed.connect(_on_reset_progress_pressed)
	vbox.add_child(reset_progress_btn)

	var reset_stats_btn := Button.new()
	reset_stats_btn.text = tr("UI_RESET_STATS")
	reset_stats_btn.focus_mode = Control.FOCUS_ALL
	reset_stats_btn.custom_minimum_size = Vector2(260, 56)
	reset_stats_btn.add_theme_font_size_override("font_size", 20)
	reset_stats_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	reset_stats_btn.pressed.connect(_on_reset_stats_pressed)
	vbox.add_child(reset_stats_btn)

	var reset_all_btn := Button.new()
	reset_all_btn.text = tr("UI_RESET_EVERYTHING")
	reset_all_btn.focus_mode = Control.FOCUS_ALL
	reset_all_btn.custom_minimum_size = Vector2(260, 56)
	reset_all_btn.add_theme_font_size_override("font_size", 20)
	reset_all_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	reset_all_btn.pressed.connect(_on_reset_all_pressed)
	vbox.add_child(reset_all_btn)
```

- [ ] **Step 4: Update focus navigation to include the new buttons**

Replace the existing focus neighbors block (lines 256-266) with:

```gdscript
	# Focus neighbors for arrow key navigation
	var controls: Array[Control] = [
		_music_slider, _sfx_slider,
		_damage_numbers_check, _range_on_hover_check,
		_fullscreen_check, _colorblind_check, _language_option,
		reset_progress_btn, reset_stats_btn, reset_all_btn
	]
	for i in controls.size():
		var prev_path := controls[(i - 1 + controls.size()) % controls.size()].get_path()
		var next_path := controls[(i + 1) % controls.size()].get_path()
		controls[i].focus_neighbor_top = prev_path
		controls[i].focus_neighbor_bottom = next_path
```

- [ ] **Step 5: Build the confirmation overlay**

Add after the `_build_layout()` method's focus navigation block, still inside `_build_layout()`, before the final `_music_slider.grab_focus()`:

```gdscript
	# --- Confirmation overlay (shared, hidden by default) ---
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var confirm_center := CenterContainer.new()
	confirm_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(confirm_center)

	var confirm_panel := PanelContainer.new()
	confirm_panel.custom_minimum_size = Vector2(400, 0)
	confirm_center.add_child(confirm_panel)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 16)
	confirm_panel.add_child(confirm_vbox)

	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 24)
	confirm_margin.add_theme_constant_override("margin_right", 24)
	confirm_margin.add_theme_constant_override("margin_top", 24)
	confirm_margin.add_theme_constant_override("margin_bottom", 24)
	confirm_panel.add_child(confirm_margin)

	var confirm_inner := VBoxContainer.new()
	confirm_inner.add_theme_constant_override("separation", 16)
	confirm_margin.add_child(confirm_inner)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_font_size_override("font_size", 18)
	confirm_inner.add_child(_confirm_label)

	_confirm_yes_btn = Button.new()
	_confirm_yes_btn.text = tr("UI_YES")
	_confirm_yes_btn.focus_mode = Control.FOCUS_ALL
	_confirm_yes_btn.custom_minimum_size = Vector2(260, 56)
	_confirm_yes_btn.add_theme_font_size_override("font_size", 20)
	_confirm_yes_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_confirm_yes_btn.pressed.connect(_on_confirm_yes)
	confirm_inner.add_child(_confirm_yes_btn)

	_confirm_no_btn = Button.new()
	_confirm_no_btn.text = tr("UI_NO")
	_confirm_no_btn.focus_mode = Control.FOCUS_ALL
	_confirm_no_btn.custom_minimum_size = Vector2(260, 56)
	_confirm_no_btn.add_theme_font_size_override("font_size", 20)
	_confirm_no_btn.pressed.connect(_on_confirm_no)
	confirm_inner.add_child(_confirm_no_btn)

	_confirm_yes_btn.focus_neighbor_bottom = _confirm_no_btn.get_path()
	_confirm_yes_btn.focus_neighbor_top = _confirm_no_btn.get_path()
	_confirm_no_btn.focus_neighbor_top = _confirm_yes_btn.get_path()
	_confirm_no_btn.focus_neighbor_bottom = _confirm_yes_btn.get_path()
```

- [ ] **Step 6: Add reset button callbacks and confirmation handlers**

Add these methods after `_on_back_pressed()` at the end of `settings_menu.gd`:

```gdscript
func _show_confirm(message: String, action: Callable) -> void:
	_confirm_label.text = message
	_pending_reset_action = action
	_confirm_overlay.visible = true
	_confirm_yes_btn.grab_focus()


func _on_confirm_yes() -> void:
	AudioManager.play_ui_click()
	_confirm_overlay.visible = false
	_pending_reset_action.call()
	data_reset.emit()


func _on_confirm_no() -> void:
	AudioManager.play_ui_click()
	_confirm_overlay.visible = false


func _on_reset_progress_pressed() -> void:
	AudioManager.play_ui_click()
	_show_confirm(tr("UI_CONFIRM_RESET_PROGRESS"), SaveManager.reset_progress)


func _on_reset_stats_pressed() -> void:
	AudioManager.play_ui_click()
	_show_confirm(tr("UI_CONFIRM_RESET_STATS"), SaveManager.reset_stats)


func _on_reset_all_pressed() -> void:
	AudioManager.play_ui_click()
	_show_confirm(tr("UI_CONFIRM_RESET_EVERYTHING"), SaveManager.reset_all)
```

- [ ] **Step 7: Commit**

```bash
git add ui/menus/settings_menu.gd
git commit -m "feat(settings): add Data section with reset progress/stats/all buttons"
```

---

### Task 4: Wire `data_reset` signal in main.gd

**Files:**
- Modify: `scenes/main.gd:282-285`

- [ ] **Step 1: Connect `data_reset` signal in `_show_settings()`**

Replace the `_show_settings()` method in `scenes/main.gd` (lines 282-285):

```gdscript
func _show_settings() -> void:
	var settings := SettingsMenu.new()
	settings.back_pressed.connect(_show_main_menu)
	settings.data_reset.connect(_on_data_reset)
	_switch_screen(settings)
```

- [ ] **Step 2: Add the `_on_data_reset()` handler**

Add after `_show_settings()`:

```gdscript
func _on_data_reset() -> void:
	# Re-apply defaults to runtime managers
	var eco_data: Dictionary = SaveManager.data.get("economy", {})
	EconomyManager.diamonds = eco_data.get("diamonds", 0) as int
	EconomyManager.diamond_doubler = eco_data.get("diamond_doubler", false) as bool
	EconomyManager.total_diamonds_earned = eco_data.get("total_diamonds_earned", 0) as int

	var settings: Dictionary = SaveManager.data.get("profile", {}).get("settings", {})
	AudioManager.set_music_volume(settings.get("music_vol", 1.0) as float)
	AudioManager.set_sfx_volume(settings.get("sfx_vol", 1.0) as float)

	var lang: String = SaveManager.data.get("profile", {}).get("language", "en") as String
	TranslationServer.set_locale(lang)

	# Re-setup campaign manager with reset data
	_campaign_manager.setup(SaveManager)
	_daily_challenge_manager.setup(SaveManager)

	_show_main_menu()
```

- [ ] **Step 3: Commit**

```bash
git add scenes/main.gd
git commit -m "feat(main): wire data_reset signal to return to main menu"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
Expected: All tests pass including the new reset tests.

- [ ] **Step 2: Manual in-editor test**

Launch the game in the Godot editor and verify:
1. Open Settings → scroll down to "Data" section
2. Tap "Reset Progress" → confirmation dialog appears with correct warning text
3. Tap "No" → dialog dismisses, returns focus to button
4. Tap "Reset Progress" → "Yes" → returns to main menu, campaign progress is cleared
5. Repeat for "Reset Stats" and "Reset Everything"
6. After "Reset Everything", verify settings (volume, language) are also reset

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix(settings): address issues found during manual testing"
```
