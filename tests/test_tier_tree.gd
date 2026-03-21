extends GutTest

## Tests for core/upgrade_system/tier_tree.gd

var _tree: TierTree

# Helper: build a two-level tree with two top branches, each with one sub-branch
func _make_tree() -> TierTree:
	var t := TierTree.new()
	t.setup([
		{
			"name": "rapid",
			"display_name": "Rapid Fire",
			"damage_mult": 0.9,
			"fire_rate_mult": 1.5,
			"range_mult": 1.0,
			"cost": 80,
			"special": "",
			"branches": [
				{
					"name": "rapid_overcharge",
					"display_name": "Overcharge",
					"damage_mult": 1.3,
					"fire_rate_mult": 1.2,
					"range_mult": 1.0,
					"cost": 150,
					"special": "",
					"branches": []
				}
			]
		},
		{
			"name": "sniper",
			"display_name": "Long Range",
			"damage_mult": 1.4,
			"fire_rate_mult": 0.8,
			"range_mult": 1.6,
			"cost": 100,
			"special": "",
			"branches": [
				{
					"name": "sniper_piercing",
					"display_name": "Piercing",
					"damage_mult": 1.5,
					"fire_rate_mult": 1.0,
					"range_mult": 1.0,
					"cost": 200,
					"special": "pierce",
					"branches": []
				}
			]
		}
	])
	return t

func before_each() -> void:
	_tree = _make_tree()

# ---------------------------------------------------------------------------
# get_upgrade_options
# ---------------------------------------------------------------------------

func test_empty_path_returns_top_level_branches() -> void:
	var options := _tree.get_upgrade_options([])
	assert_eq(options.size(), 2)

func test_options_after_choosing_rapid() -> void:
	var options := _tree.get_upgrade_options([0])
	assert_eq(options.size(), 1)
	assert_eq((options[0] as Dictionary).get("name"), "rapid_overcharge")

func test_options_after_choosing_sniper() -> void:
	var options := _tree.get_upgrade_options([1])
	assert_eq(options.size(), 1)
	assert_eq((options[0] as Dictionary).get("name"), "sniper_piercing")

func test_options_at_leaf_returns_empty() -> void:
	var options := _tree.get_upgrade_options([0, 0])
	assert_eq(options.size(), 0)

func test_invalid_choice_returns_empty() -> void:
	var options := _tree.get_upgrade_options([99])
	assert_eq(options.size(), 0)

# ---------------------------------------------------------------------------
# get_current_tier
# ---------------------------------------------------------------------------

func test_tier_zero_for_empty_path() -> void:
	assert_eq(_tree.get_current_tier([]), 0)

func test_tier_one_after_first_choice() -> void:
	assert_eq(_tree.get_current_tier([0]), 1)

func test_tier_two_after_two_choices() -> void:
	assert_eq(_tree.get_current_tier([0, 0]), 2)

# ---------------------------------------------------------------------------
# get_next_upgrade_cost
# ---------------------------------------------------------------------------

func test_cost_of_first_rapid_branch() -> void:
	assert_eq(_tree.get_next_upgrade_cost([], 0), 80)

func test_cost_of_first_sniper_branch() -> void:
	assert_eq(_tree.get_next_upgrade_cost([], 1), 100)

func test_cost_of_second_tier_rapid() -> void:
	assert_eq(_tree.get_next_upgrade_cost([0], 0), 150)

func test_cost_of_second_tier_sniper() -> void:
	assert_eq(_tree.get_next_upgrade_cost([1], 0), 200)

func test_cost_invalid_choice_returns_zero() -> void:
	assert_eq(_tree.get_next_upgrade_cost([], 99), 0)

func test_cost_at_leaf_returns_zero() -> void:
	assert_eq(_tree.get_next_upgrade_cost([0, 0], 0), 0)

# ---------------------------------------------------------------------------
# get_total_cost
# ---------------------------------------------------------------------------

func test_total_cost_empty_path_is_zero() -> void:
	assert_eq(_tree.get_total_cost([]), 0)

func test_total_cost_rapid_tier1() -> void:
	assert_eq(_tree.get_total_cost([0]), 80)

func test_total_cost_sniper_tier1() -> void:
	assert_eq(_tree.get_total_cost([1]), 100)

func test_total_cost_rapid_both_tiers() -> void:
	assert_eq(_tree.get_total_cost([0, 0]), 230)  # 80 + 150

func test_total_cost_sniper_both_tiers() -> void:
	assert_eq(_tree.get_total_cost([1, 0]), 300)  # 100 + 200

# ---------------------------------------------------------------------------
# apply_upgrades
# ---------------------------------------------------------------------------

func test_apply_upgrades_no_path_returns_base() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	var result := _tree.apply_upgrades(base, [])
	assert_almost_eq(result.get("damage") as float, 25.0, 0.001)
	assert_almost_eq(result.get("fire_rate") as float, 1.0, 0.001)
	assert_almost_eq(result.get("range") as float, 200.0, 0.001)

func test_apply_upgrades_rapid_tier1_boosts_fire_rate() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	var result := _tree.apply_upgrades(base, [0])
	# damage_mult=0.9 → 22.5, fire_rate_mult=1.5 → 1.5, range_mult=1.0 → 200
	assert_almost_eq(result.get("damage") as float, 22.5, 0.001)
	assert_almost_eq(result.get("fire_rate") as float, 1.5, 0.001)
	assert_almost_eq(result.get("range") as float, 200.0, 0.001)

func test_apply_upgrades_sniper_tier1_boosts_range() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	var result := _tree.apply_upgrades(base, [1])
	# damage_mult=1.4 → 35.0, fire_rate_mult=0.8 → 0.8, range_mult=1.6 → 320
	assert_almost_eq(result.get("damage") as float, 35.0, 0.001)
	assert_almost_eq(result.get("fire_rate") as float, 0.8, 0.001)
	assert_almost_eq(result.get("range") as float, 320.0, 0.001)

func test_apply_upgrades_two_tiers_compound() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	var result := _tree.apply_upgrades(base, [0, 0])
	# Tier1: dmg*0.9=22.5, rate*1.5=1.5
	# Tier2: dmg*1.3=29.25, rate*1.2=1.8
	assert_almost_eq(result.get("damage") as float, 29.25, 0.01)
	assert_almost_eq(result.get("fire_rate") as float, 1.8, 0.001)

func test_apply_upgrades_does_not_modify_original_base() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	_tree.apply_upgrades(base, [1])
	assert_almost_eq(base.get("damage") as float, 25.0, 0.001)

func test_apply_upgrades_invalid_path_stops_gracefully() -> void:
	var base := {"damage": 25.0, "fire_rate": 1.0, "range": 200.0}
	var result := _tree.apply_upgrades(base, [99])
	# Should not crash; base returned unchanged (path breaks on first invalid step)
	assert_almost_eq(result.get("damage") as float, 25.0, 0.001)

# ---------------------------------------------------------------------------
# Empty tree
# ---------------------------------------------------------------------------

func test_empty_tree_returns_empty_options() -> void:
	var empty := TierTree.new()
	assert_eq(empty.get_upgrade_options([]).size(), 0)

func test_empty_tree_total_cost_zero() -> void:
	var empty := TierTree.new()
	assert_eq(empty.get_total_cost([]), 0)

func test_empty_tree_apply_returns_base() -> void:
	var empty := TierTree.new()
	var base := {"damage": 10.0, "fire_rate": 2.0, "range": 100.0}
	var result := empty.apply_upgrades(base, [])
	assert_almost_eq(result.get("damage") as float, 10.0, 0.001)
