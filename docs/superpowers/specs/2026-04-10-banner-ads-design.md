# Banner Ads — Design Spec

**Date:** 2026-04-10
**Status:** Approved, pending implementation plan

## Goal

Add non-intrusive banner ads to Last Signal to increase ad revenue without degrading the gameplay experience. Banners must never appear during active play, and must respect the existing No-Ads IAP.

## Scope

### Screens that show the banner

- `CampaignMap` (`ui/meta/campaign_map.tscn`)
- `TowerLab` (`ui/meta/tower_lab.tscn`)
- `DiamondShop` (`ui/meta/diamond_shop.tscn`)

### Screens that do NOT show the banner

- `MainMenu`
- `SettingsMenu`
- `LevelComplete` (post-game summary — high-emotion moment)
- `PauseMenu` (overlay during gameplay)
- `Game` (active play)
- `DailyChallengeScreen`

### Behavior summary

- Banner position: **bottom center**, anchored adaptive size, full width
- Banner persists across the 3 target screens (shown/hidden on screen transitions, not re-loaded)
- If `AdManager.has_no_ads(save)` is true, banner is a silent no-op — never loads or displays
- Desktop/editor builds skip the banner entirely (no simulation — there is no reward to simulate)
- If a player purchases No-Ads while the banner is visible, it disappears immediately via a new `IAPManager.no_ads_purchased` signal

## Ad Unit IDs

New constants in `core/monetization/ad_manager.gd`:

```gdscript
const BANNER_AD_UNIT_ID_ANDROID: String = "<TODO: create new banner unit in AdMob console>"
const BANNER_AD_UNIT_ID_TEST: String = "ca-app-pub-3940256099942544/6300978111"
```

The test ID is Google's public adaptive banner test ID. `_get_banner_ad_unit_id()` returns the test ID in debug builds, production ID otherwise — mirrors the existing `_get_ad_unit_id()` / `_get_ri_ad_unit_id()` pattern.

**Action item for user:** Create a new Banner ad unit in the AdMob console and replace the `<TODO>` placeholder before shipping.

## Architecture

### AdManager additions (`core/monetization/ad_manager.gd`)

New state:

```gdscript
var _banner_ad = null          # AdView instance (dynamic plugin class)
var _banner_loading: bool = false
var _banner_shown: bool = false  # desired visibility state; may be true while still loading
```

New public methods:

```gdscript
func show_banner(save) -> void
func hide_banner() -> void
func destroy_banner() -> void
```

New private methods:

```gdscript
func _load_banner() -> void
func _get_banner_ad_unit_id() -> String
func _on_banner_ad_loaded() -> void
func _on_banner_ad_failed_to_load(error) -> void
func _maybe_retry_banner() -> void
func _on_no_ads_purchased() -> void
```

`AdManager._ready()` adds one line to connect the No-Ads signal:

```gdscript
IAPManager.no_ads_purchased.connect(_on_no_ads_purchased)
```

`_on_no_ads_purchased()` simply calls `destroy_banner()`.

### `show_banner(save)` logic

1. If `has_no_ads(save)` → return (silent no-op)
2. If not `_is_mobile()` → return
3. Set `_banner_shown = true`
4. If `_banner_ad == null` and not `_banner_loading` → call `_load_banner()`
5. If `_banner_ad != null` → call `_banner_ad.show()`

### `hide_banner()` logic

1. Set `_banner_shown = false`
2. If `_banner_ad != null` → call `_banner_ad.hide()`
3. Does NOT destroy — keeps instance warm for the next screen transition

### `destroy_banner()` logic

Full cleanup: calls `_banner_ad.destroy()`, clears `_banner_ad`, `_banner_loading`, `_banner_shown`. Used by `_on_no_ads_purchased()` and (optionally) app shutdown.

### `_load_banner()` logic

Follows the existing dynamic plugin pattern from `_load_rewarded_ad()`:

- `AdView.new(_get_banner_ad_unit_id(), ad_size, AdPosition.Values.BOTTOM)` via `_new_instance_from("res://addons/admob/src/api/AdView.gd")`
- `AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)` via the `AdSize` GDScript class
- `AdListener.new()` callback with `on_ad_loaded = _on_banner_ad_loaded`, `on_ad_failed_to_load = _on_banner_ad_failed_to_load`
- `_ad_view.load_ad(AdRequest.new())`

### Load success callback

```gdscript
func _on_banner_ad_loaded() -> void:
    _banner_loading = false
    if _banner_shown and _banner_ad != null:
        _banner_ad.show()
```

The `_banner_shown` check handles the case where the user navigated away while the ad was still loading — in that case we don't call `.show()`.

### Load failure callback

```gdscript
func _on_banner_ad_failed_to_load(_error) -> void:
    _banner_ad = null
    _banner_loading = false
    if is_inside_tree():
        get_tree().create_timer(30.0).timeout.connect(_maybe_retry_banner)
```

`_maybe_retry_banner()` only re-loads if `_banner_shown` is still true (user is still on a banner-eligible screen).

Retry delay is 30s (longer than rewarded ad's 10s) because banner failures are less critical and don't block user action.

## IAPManager signal addition

`core/monetization/iap_manager.gd` currently writes `save.data["monetization"]["no_ads_purchased"] = true` at line 175 without emitting any signal.

Add:

```gdscript
signal no_ads_purchased
```

Emit it immediately after setting the save flag (line 175). `AdManager._ready()` connects to it and calls `destroy_banner()` on receipt, so the banner disappears the moment the purchase completes.

## Per-Screen Integration

Each of the 3 target screens gets 4 lines added:

```gdscript
# _ready()
AdManager.show_banner(SaveManager)

# _exit_tree()
AdManager.hide_banner()
```

Using `_exit_tree()` (not a manual back-button handler) is safe because `scenes/main.gd` switches screens by freeing the old scene, which fires `_exit_tree()` reliably. It also fires on app shutdown, which is fine — `hide_banner()` is idempotent.

**Files touched:**
- `ui/meta/campaign_map.gd`
- `ui/meta/tower_lab.gd`
- `ui/meta/diamond_shop.gd`

## Layout Margin Strategy

The adaptive banner overlays natively at the viewport bottom (~50–60px on most phones, capped at `min(device_height/8, 90)` per AdMob docs). Godot's layout does not know about this overlay, so we must reserve space.

**Decision:** Fixed 80px bottom margin on the root of each of the 3 target `.tscn` files. Rationale:
- 80px is a safe upper bound for adaptive banner height on phones
- When the banner is hidden (No-Ads, load failure, desktop), the 80px empty space at the bottom is visually invisible on the dark UI background
- Runtime dynamic sizing (query `_ad_view.get_height_in_pixels()`) would add complexity for a ~10px visual difference nobody will notice

**Implementation:** Each target scene's root layout will be wrapped in or modified to include a `MarginContainer` with `theme_override_constants/margin_bottom = 80`. Exact adjustment depends on the current layout of each scene — if a margin container already exists, we bump its value; otherwise we wrap the content.

## Testing

Banner ads cannot be unit-tested (native overlay, can't be mocked cleanly). Test plan is manual only:

### Desktop/editor

- Run CampaignMap, TowerLab, DiamondShop — confirm no errors, no banner, no layout glitches
- The 80px reserved margin should be visually invisible

### Android debug build

- Enter CampaignMap → banner appears at bottom within ~2s
- Navigate CampaignMap → TowerLab → DiamondShop → banner stays visible across transitions, no reload
- Navigate to MainMenu → banner hides
- Navigate back to CampaignMap → banner re-shows instantly (warm AdView)
- Enter active gameplay → banner hidden throughout the match
- Return to CampaignMap after match → banner re-shows

### No-Ads IAP

- Purchase No-Ads from DiamondShop while banner is visible → banner disappears immediately (validates the `no_ads_purchased` signal wiring)
- Restart app, visit all 3 target screens → no banner ever shows

### Load failure

- Enable airplane mode, enter CampaignMap → no crash, no banner, AdManager schedules 30s retry
- Disable airplane mode after 30s → banner loads and appears on next retry

### Regression check

- Existing rewarded ad flow (diamonds for watching): still works
- Existing rewarded interstitial flow (daily challenge entry): still works

## Out of Scope

- Interstitial (non-rewarded) ads
- Banner ads on additional screens (MainMenu, Settings, LevelComplete)
- Runtime-dynamic banner height
- Automated tests for banner flow
- Banner A/B testing or mediation

## Open Action Items

1. **User:** Create a Banner ad unit in the AdMob console and supply the production ID to replace `<TODO>` in `BANNER_AD_UNIT_ID_ANDROID`.
