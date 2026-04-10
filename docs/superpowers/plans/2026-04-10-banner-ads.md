# Banner Ads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **No-commit mode:** Per user instruction, this plan does NOT include `git commit` steps. All changes are left in the working tree for the user to review and commit manually.

**Goal:** Add a non-intrusive adaptive banner ad at the bottom of CampaignMap, TowerLab, and DiamondShop screens using Google AdMob via the Poing-Studios plugin.

**Architecture:** One persistent `AdView` instance owned by the `AdManager` autoload, shown/hidden on screen transitions. The `IAPManager` emits a new `no_ads_purchased` signal so `AdManager` can destroy the banner instantly when the player purchases No-Ads. Each target screen reserves 80px at the bottom via a shared helper on `AdManager`.

**Tech Stack:** Godot 4.6, GDScript, Poing-Studios godot-admob-plugin v4.1.0 (classes: `AdView`, `AdSize`, `AdPosition`, `AdListener`, `AdRequest`, `LoadAdError`).

**Reference spec:** `docs/superpowers/specs/2026-04-10-banner-ads-design.md`

---

## File Map

**Modified:**
- `core/monetization/ad_manager.gd` — banner state, public API, load/show/hide/destroy logic, no-ads signal hookup, layout-reserve helper
- `core/monetization/iap_manager.gd` — add `no_ads_purchased` signal and emit it when the no_ads pack is applied
- `ui/meta/campaign_map.gd` — `_ready()` calls `show_banner` + layout reserve; `_exit_tree()` calls `hide_banner`
- `ui/meta/tower_lab.gd` — same
- `ui/meta/diamond_shop.gd` — same

**Not modified:** The three `.tscn` files are bare (root node + script only — layout is 100% built in code), so no scene surgery is required. All layout changes happen in `_build_layout()` via a helper call.

**Not created:** No new files. All additions slot into existing modules.

---

## Task 1: Add banner ad unit constants and helper getter to AdManager

**Files:**
- Modify: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Add constants**

Open `core/monetization/ad_manager.gd`. Below the existing `DC_AD_UNIT_ID_TEST` constant (around line 18), add:

```gdscript
const BANNER_AD_UNIT_ID_ANDROID: String = "<TODO: replace with real banner ad unit from AdMob console>"
const BANNER_AD_UNIT_ID_TEST: String = "ca-app-pub-3940256099942544/6300978111"
const BANNER_RESERVED_HEIGHT: float = 80.0
```

The test ID is Google's public adaptive banner test ID (safe to commit).

- [ ] **Step 2: Add getter for the right ad unit per build type**

Below the existing `_get_ri_ad_unit_id()` function (around line 76), add:

```gdscript
func _get_banner_ad_unit_id() -> String:
	if OS.is_debug_build():
		return BANNER_AD_UNIT_ID_TEST
	return BANNER_AD_UNIT_ID_ANDROID
```

- [ ] **Step 3: Verify file still parses**

Run in Godot editor: **Project → Reload Current Project** (or just switch to the script tab). Confirm no parse errors in the output panel.

---

## Task 2: Add banner state variables and stub public API to AdManager

**Files:**
- Modify: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Add state variables**

In the `# State` section of `core/monetization/ad_manager.gd` (around line 49, after the existing `_ri_rewarded` variable), add:

```gdscript
# Banner ad state
var _banner_ad = null
var _banner_loading: bool = false
var _banner_shown: bool = false
```

- [ ] **Step 2: Add public method stubs**

At the end of the file (after `_check_date_reset()`), add:

```gdscript
# ---------------------------------------------------------------------------
# Banner ads
# ---------------------------------------------------------------------------

func show_banner(save) -> void:
	pass

func hide_banner() -> void:
	pass

func destroy_banner() -> void:
	pass

func get_banner_reserve(save) -> float:
	return 0.0

func apply_banner_reserve(control: Control, save) -> void:
	pass
```

These stubs let other tasks wire up callers without waiting for full logic.

- [ ] **Step 3: Verify parse**

Reload script tab in Godot. Confirm no parse errors.

---

## Task 3: Implement `get_banner_reserve` and `apply_banner_reserve` helpers

These are used by the per-screen integration tasks. Implementing them early lets the screens compile even before banner logic is fleshed out.

**Files:**
- Modify: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Replace the `get_banner_reserve` stub**

Find the stub and replace with:

```gdscript
func get_banner_reserve(save) -> float:
	if not _is_mobile():
		return 0.0
	if has_no_ads(save):
		return 0.0
	return BANNER_RESERVED_HEIGHT
```

- [ ] **Step 2: Replace the `apply_banner_reserve` stub**

Find the stub and replace with:

```gdscript
func apply_banner_reserve(control: Control, save) -> void:
	if control == null:
		return
	control.offset_bottom = -get_banner_reserve(save)
```

This sets `offset_bottom` on the root Control of each screen. On mobile without no-ads, this shifts the effective viewport up by 80px. Because Godot Controls don't clip children by default, the background ColorRect (which uses `PRESET_FULL_RECT`) will still render to the full viewport visually via its own anchoring — but the interactive content will respect the reduced layout bounds.

Note: this relies on each screen calling `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` on itself in `_build_layout()` BEFORE `apply_banner_reserve` is called. All three target screens already do this.

- [ ] **Step 3: Verify parse**

Reload script tab in Godot. Confirm no parse errors.

---

## Task 4: Implement AdManager banner load/show/hide/destroy

This is the core plugin integration. Mirrors the existing `_load_rewarded_ad()` dynamic loading pattern but uses `AdView` instead of `RewardedAdLoader`.

**Files:**
- Modify: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Implement `show_banner`**

Replace the `show_banner` stub with:

```gdscript
func show_banner(save) -> void:
	if has_no_ads(save):
		return
	if not _is_mobile():
		return
	_banner_shown = true
	if _banner_ad == null and not _banner_loading:
		_load_banner()
		return
	if _banner_ad != null:
		_banner_ad.show()
```

- [ ] **Step 2: Implement `hide_banner`**

Replace the `hide_banner` stub with:

```gdscript
func hide_banner() -> void:
	_banner_shown = false
	if _banner_ad != null:
		_banner_ad.hide()
```

- [ ] **Step 3: Implement `destroy_banner`**

Replace the `destroy_banner` stub with:

```gdscript
func destroy_banner() -> void:
	_banner_shown = false
	_banner_loading = false
	if _banner_ad != null:
		_banner_ad.destroy()
		_banner_ad = null
```

- [ ] **Step 4: Implement `_load_banner` (private)**

At the end of the banner section, add:

```gdscript
func _load_banner() -> void:
	if _banner_loading or not _is_mobile():
		return

	var ad_view_script = ResourceLoader.load("res://addons/admob/src/api/AdView.gd", "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	var ad_size_script = ResourceLoader.load("res://addons/admob/src/api/core/AdSize.gd", "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	var ad_position_script = ResourceLoader.load("res://addons/admob/src/api/core/AdPosition.gd", "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	if ad_view_script == null or ad_size_script == null or ad_position_script == null:
		return

	# FULL_WIDTH const on AdSize is -1 (per addons/admob/src/api/core/AdSize.gd:28)
	var ad_size = ad_size_script.get_current_orientation_anchored_adaptive_banner_ad_size(-1)
	if ad_size == null:
		return

	# AdPosition.Values.BOTTOM (per addons/admob/src/api/core/AdPosition.gd enum order: TOP=0, BOTTOM=1)
	var bottom_position: int = ad_position_script.Values.BOTTOM

	_banner_loading = true
	_banner_ad = ad_view_script.new(_get_banner_ad_unit_id(), ad_size, bottom_position)

	# AdListener lives under listeners/ subdirectory, not api/ root — must use full path
	var listener = _new_instance_from("res://addons/admob/src/api/listeners/AdListener.gd")
	if listener == null:
		_banner_loading = false
		_banner_ad = null
		return
	listener.on_ad_loaded = _on_banner_ad_loaded
	listener.on_ad_failed_to_load = _on_banner_ad_failed_to_load
	_banner_ad.ad_listener = listener

	var ad_request = _new_instance_from("res://addons/admob/src/api/core/AdRequest.gd")
	if ad_request == null:
		_banner_loading = false
		return
	_banner_ad.load_ad(ad_request)
```

- [ ] **Step 5: Implement load callbacks**

Add below `_load_banner`:

```gdscript
func _on_banner_ad_loaded() -> void:
	_banner_loading = false
	if _banner_shown and _banner_ad != null:
		_banner_ad.show()

func _on_banner_ad_failed_to_load(_error) -> void:
	_banner_ad = null
	_banner_loading = false
	if is_inside_tree():
		get_tree().create_timer(30.0).timeout.connect(_maybe_retry_banner)

func _maybe_retry_banner() -> void:
	if _banner_shown and _banner_ad == null and not _banner_loading:
		_load_banner()
```

The `_banner_shown` check in `_maybe_retry_banner` prevents retrying if the user has since navigated off the banner screens.

- [ ] **Step 6: Verify parse**

Reload script tab in Godot. Confirm no parse errors.

- [ ] **Step 7: Desktop smoke test**

Run the game in the editor. Open the existing main menu → navigate to Diamond Shop (which will become a banner screen in Task 7). No banner should appear (desktop), no errors in output. This confirms the desktop short-circuit (`_is_mobile()` check) works.

---

## Task 5: Add `no_ads_purchased` signal to IAPManager

**Files:**
- Modify: `core/monetization/iap_manager.gd`

- [ ] **Step 1: Add the signal declaration**

In `core/monetization/iap_manager.gd`, find the existing signals block (around line 12-13):

```gdscript
signal purchase_complete(pack_id: String, diamonds: int)
signal purchase_failed(pack_id: String)
```

Add one line below:

```gdscript
signal no_ads_purchased
```

- [ ] **Step 2: Emit the signal when no_ads is applied**

Find the `_apply_purchase()` function and its `"no_ads":` match case (around line 173-175):

```gdscript
		"no_ads":
			if save != null:
				save.data["monetization"]["no_ads_purchased"] = true
```

Replace with:

```gdscript
		"no_ads":
			if save != null:
				save.data["monetization"]["no_ads_purchased"] = true
			no_ads_purchased.emit()
```

- [ ] **Step 3: Verify parse**

Reload script tab. Confirm no parse errors.

---

## Task 6: Wire AdManager to the `no_ads_purchased` signal

**Files:**
- Modify: `core/monetization/ad_manager.gd`

- [ ] **Step 1: Connect the signal in `_ready`**

Find the existing `_ready()` function in `core/monetization/ad_manager.gd` (around line 55):

```gdscript
func _ready() -> void:
	if not _is_mobile():
		return
	# Initialize AdMob via dynamic call
	var mobile_ads_class = _get_class("MobileAds")
	if mobile_ads_class != null and mobile_ads_class.has_method("initialize"):
		mobile_ads_class.initialize()
	_load_rewarded_ad()
	_load_ri_ad()
```

Add the signal connection **before** the `_is_mobile` short-circuit (so it still fires on desktop — IAPManager runs on desktop too in simulation mode):

```gdscript
func _ready() -> void:
	IAPManager.no_ads_purchased.connect(_on_no_ads_purchased)
	if not _is_mobile():
		return
	# Initialize AdMob via dynamic call
	var mobile_ads_class = _get_class("MobileAds")
	if mobile_ads_class != null and mobile_ads_class.has_method("initialize"):
		mobile_ads_class.initialize()
	_load_rewarded_ad()
	_load_ri_ad()
```

- [ ] **Step 2: Add the handler**

In the banner ads section (after `_maybe_retry_banner`), add:

```gdscript
func _on_no_ads_purchased() -> void:
	destroy_banner()
```

- [ ] **Step 3: Verify parse**

Reload script tab. Confirm no parse errors.

- [ ] **Step 4: Autoload order sanity check**

Open `project.godot` and confirm `IAPManager` is listed in the `[autoload]` section BEFORE `AdManager`. If not, `AdManager._ready()` will fail because `IAPManager` won't exist yet. Godot loads autoloads in the order they appear in the file.

If the order is wrong, move the `AdManager` line below `IAPManager`. If you're unsure, search for `[autoload]` in `project.godot` and list both lines.

---

## Task 7: Wire banner into DiamondShop

**Files:**
- Modify: `ui/meta/diamond_shop.gd`

- [ ] **Step 1: Add `show_banner` + reserve to `_ready`**

Find the existing `_ready()` (line 44):

```gdscript
func _ready() -> void:
	_build_layout()
```

Replace with:

```gdscript
func _ready() -> void:
	_build_layout()
	AdManager.apply_banner_reserve(self, SaveManager)
	AdManager.show_banner(SaveManager)
```

- [ ] **Step 2: Add `_exit_tree` handler**

Below `_ready()`, add:

```gdscript
func _exit_tree() -> void:
	AdManager.hide_banner()
```

- [ ] **Step 3: Verify parse**

Reload script tab. Confirm no parse errors.

- [ ] **Step 4: Desktop layout test**

Run the game in editor. Open main menu → Diamond Shop. Verify:
- No errors in output
- Shop content still visible (diamond packs, buy buttons, back button)
- No visible layout gap at the bottom (on desktop, `get_banner_reserve` returns 0, so `offset_bottom` stays at 0)

---

## Task 8: Wire banner into CampaignMap

**Files:**
- Modify: `ui/meta/campaign_map.gd`

- [ ] **Step 1: Add `show_banner` + reserve to `_ready`**

Find the existing `_ready()` (line 61):

```gdscript
func _ready() -> void:
	_build_layout()
```

Replace with:

```gdscript
func _ready() -> void:
	_build_layout()
	AdManager.apply_banner_reserve(self, SaveManager)
	AdManager.show_banner(SaveManager)
```

- [ ] **Step 2: Add `_exit_tree` handler**

Below `_ready()`, add:

```gdscript
func _exit_tree() -> void:
	AdManager.hide_banner()
```

- [ ] **Step 3: Verify parse**

Reload script tab. Confirm no parse errors.

- [ ] **Step 4: Desktop layout test**

Run the game. Open main menu → Campaign Map. Verify:
- No errors
- Region tabs, level grid, and back button all still reachable
- No visible layout gap on desktop

---

## Task 9: Wire banner into TowerLab

**Files:**
- Modify: `ui/meta/tower_lab.gd`

- [ ] **Step 1: Add `show_banner` + reserve to `_ready`**

Find the existing `_ready()` (line 73):

```gdscript
func _ready() -> void:
	_build_layout()
```

Replace with:

```gdscript
func _ready() -> void:
	_build_layout()
	AdManager.apply_banner_reserve(self, SaveManager)
	AdManager.show_banner(SaveManager)
```

- [ ] **Step 2: Add `_exit_tree` handler**

Below `_ready()`, add:

```gdscript
func _exit_tree() -> void:
	AdManager.hide_banner()
```

- [ ] **Step 3: Verify parse**

Reload script tab. Confirm no parse errors.

- [ ] **Step 4: Desktop layout test**

Run the game. Open main menu → Tower Lab. Verify:
- No errors
- Tower sidebar, skill tree, tab buttons, back button all visible and clickable
- No visible layout gap on desktop

---

## Task 10: Full desktop regression check

**Files:** None modified.

- [ ] **Step 1: Run existing GUT test suite**

Run from the command line:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

Expected: 867 tests pass (same count as before). If any test fails, read the failure message — likely a missing method signature or a parser issue in `ad_manager.gd` or `iap_manager.gd`.

- [ ] **Step 2: Manual desktop flow test**

Open the project in the Godot editor and click Play. Test each flow:

1. Main Menu → Campaign Map → back → Main Menu (no errors, no banner)
2. Main Menu → Tower Lab → back → Main Menu (no errors, no banner)
3. Main Menu → Diamond Shop → back → Main Menu (no errors, no banner)
4. Campaign Map → pick a level → play through → win → return to Campaign Map (no errors)
5. Diamond Shop → click "Watch Ad for Diamonds" → verify existing rewarded-ad simulation still grants 150 diamonds (regression check on rewarded flow)

Expected: all flows work as before. Banner has zero visible effect on desktop.

---

## Task 11: Android debug build and device test

Banner ads cannot be tested on desktop — this task is the only way to verify the feature works.

**Files:** None modified.

- [ ] **Step 1: Replace the placeholder ad unit ID**

Open `core/monetization/ad_manager.gd` and find `BANNER_AD_UNIT_ID_ANDROID`. For debug testing this is fine left as `<TODO>` because debug builds use the test ID. For a real production ship, you must create a Banner ad unit in the AdMob console and paste its ID here. Skip this step for debug builds only.

- [ ] **Step 2: Build debug APK**

Run:

```bash
godot --headless --export-debug "Android" build/last-signal-debug.apk
```

Expected: APK written to `build/last-signal-debug.apk` with no errors.

- [ ] **Step 3: Install on an Android device**

With device connected via USB and developer mode enabled:

```bash
adb install -r build/last-signal-debug.apk
```

Expected: "Success" output from adb.

- [ ] **Step 4: Run the banner test plan on device**

Launch the app on the device. Perform each check and mark the result:

1. [ ] Open **Campaign Map** → banner test ad appears at the bottom within ~3s
2. [ ] Back to Main Menu → banner hides; no banner on Main Menu
3. [ ] Navigate to **Tower Lab** → banner re-shows instantly (no reload flash — it's warm)
4. [ ] Navigate to **Diamond Shop** → banner still visible; no reload
5. [ ] Start a level from Campaign Map → banner hides during gameplay (even between waves)
6. [ ] Win or lose the level → banner still hidden on LevelComplete overlay
7. [ ] Return to Campaign Map from the level → banner re-shows
8. [ ] Verify no buttons or UI are covered by the banner on any of the 3 screens
9. [ ] Verify existing rewarded ad flow still works: Diamond Shop → "Watch Ad for Diamonds" → grants diamonds

- [ ] **Step 5: No-Ads IAP simulation test**

On the device, manually set the no-ads flag in the save file (or use the existing IAP flow if set up). Expected result:
- While the banner is visible on Campaign Map, purchasing no-ads → banner disappears immediately (validates the `no_ads_purchased` signal wiring)
- After restart, visit all 3 target screens → no banner ever appears

Alternative if IAP simulation is hard: in the editor, temporarily edit your save file's `"monetization": {"no_ads_purchased": true}` then build/install. Visit all 3 screens and verify no banner.

- [ ] **Step 6: Load failure test**

On device, enable airplane mode. Open Campaign Map. Expected:
- No crash
- No banner (obviously)
- After ~30s of wait, disable airplane mode. Navigate away and back to Campaign Map → banner eventually loads and appears

---

## Task 12: User handoff

**Files:** None modified.

- [ ] **Step 1: Summarize what was done**

Write a short summary for the user covering:
- Which files changed and what each change does
- The `<TODO>` placeholder in `BANNER_AD_UNIT_ID_ANDROID` that must be replaced with a real ad unit ID from the AdMob console before shipping production
- Any behavior that was surprising during testing

- [ ] **Step 2: Leave changes uncommitted**

Per user instruction, do NOT run `git add` or `git commit`. Leave the working tree dirty for the user to review with `git diff`.
