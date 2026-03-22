extends GutTest

## Tests for core/progression/skill_tree.gd and core/progression/skill_node.gd

var _tree: SkillTree

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_node(idx: int, prereq: int, cost: int, dmg: float = 0.0, fr: float = 0.0, rng: float = 0.0, hero: bool = false) -> SkillNode:
	var n := SkillNode.new()
	n.id = "node_%d" % idx
	n.display_name = "Node %d" % idx
	n.node_index = idx
	n.cost = cost
	n.prerequisite_index = prereq
	n.damage_bonus = dmg
	n.fire_rate_bonus = fr
	n.range_bonus = rng
	n.is_hero_unlock = hero
	return n

## Build a 4-node tree:
## 0 (no prereq) → 1 (prereq 0) → 3 (prereq 1)
## 2 (no prereq)
func _make_tree() -> SkillTree:
	var t := SkillTree.new()
	t.tower_type = Enums.TowerType.PULSE_CANNON
	t.nodes.append(_make_node(0, -1, 80, 5.0, 0.0, 0.0))
	t.nodes.append(_make_node(1, 0, 100, 0.0, 0.1, 0.0))
	t.nodes.append(_make_node(2, -1, 120, 0.0, 0.0, 20.0))
	t.nodes.append(_make_node(3, 1, 200, 3.0, 0.0, 0.0, true))
	return t

func before_each() -> void:
	_tree = _make_tree()

# ---------------------------------------------------------------------------
# can_unlock_node
# ---------------------------------------------------------------------------

func test_can_unlock_root_node_with_empty_unlocked() -> void:
	assert_true(_tree.can_unlock_node(0, {}))

func test_can_unlock_independent_node_with_empty_unlocked() -> void:
	assert_true(_tree.can_unlock_node(2, {}))

func test_cannot_unlock_node_at_max_level() -> void:
	assert_false(_tree.can_unlock_node(0, {0: 5}))

func test_can_unlock_node_below_max_level() -> void:
	assert_true(_tree.can_unlock_node(1, {}))

func test_can_unlock_node_with_other_nodes_unlocked() -> void:
	assert_true(_tree.can_unlock_node(1, {0: 1}))

func test_can_unlock_node_when_others_at_various_levels() -> void:
	assert_true(_tree.can_unlock_node(3, {0: 1, 1: 1}))

func test_can_still_level_up_when_below_max() -> void:
	assert_true(_tree.can_unlock_node(3, {0: 1}))

func test_invalid_index_returns_false() -> void:
	assert_false(_tree.can_unlock_node(99, {}))

func test_negative_index_returns_false() -> void:
	assert_false(_tree.can_unlock_node(-1, {}))

# ---------------------------------------------------------------------------
# get_node_cost
# ---------------------------------------------------------------------------

func test_cost_of_node_at_level_zero() -> void:
	# Uses Constants.SKILL_NODE_COSTS[0] = 80
	assert_eq(_tree.get_node_cost(0), 80)

func test_cost_of_any_node_at_level_zero() -> void:
	# All nodes at level 0 use SKILL_NODE_COSTS[0]
	assert_eq(_tree.get_node_cost(1), 80)

func test_cost_invalid_index_returns_zero() -> void:
	assert_eq(_tree.get_node_cost(99), 0)

# ---------------------------------------------------------------------------
# get_total_cost
# ---------------------------------------------------------------------------

func test_total_cost_sums_all_nodes_all_levels() -> void:
	# 4 nodes, each with max_level=5
	# Per node: SKILL_NODE_COSTS[0..4] = 80+100+120+200+250 = 750
	# Total: 4 * 750 = 3000
	assert_eq(_tree.get_total_cost(), 3000)

func test_empty_tree_total_cost_is_zero() -> void:
	var t := SkillTree.new()
	assert_eq(t.get_total_cost(), 0)

# ---------------------------------------------------------------------------
# get_unlockable_nodes
# ---------------------------------------------------------------------------

func test_unlockable_with_nothing_unlocked() -> void:
	var unlockable := _tree.get_unlockable_nodes({})
	# All 4 nodes are unlockable at level 0
	assert_true(unlockable.has(0))
	assert_true(unlockable.has(1))
	assert_true(unlockable.has(2))
	assert_true(unlockable.has(3))

func test_unlockable_after_partial_leveling() -> void:
	var unlockable := _tree.get_unlockable_nodes({0: 1})
	# Node 0 still unlockable (level 1 < max 5)
	assert_true(unlockable.has(0))
	assert_true(unlockable.has(1))

func test_unlockable_when_all_maxed_is_empty() -> void:
	var unlockable := _tree.get_unlockable_nodes({0: 5, 1: 5, 2: 5, 3: 5})
	assert_eq(unlockable.size(), 0)

# ---------------------------------------------------------------------------
# get_stat_bonuses
# ---------------------------------------------------------------------------

func test_stat_bonuses_empty_unlocked_all_zero() -> void:
	var bonuses := _tree.get_stat_bonuses({})
	assert_almost_eq(bonuses["damage"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["range"] as float, 0.0, 0.001)

func test_stat_bonuses_single_damage_node() -> void:
	var bonuses := _tree.get_stat_bonuses({0: 1})
	assert_almost_eq(bonuses["damage"] as float, 5.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.0, 0.001)

func test_stat_bonuses_fire_rate_node() -> void:
	var bonuses := _tree.get_stat_bonuses({1: 1})
	assert_almost_eq(bonuses["fire_rate"] as float, 0.1, 0.001)

func test_stat_bonuses_range_node() -> void:
	var bonuses := _tree.get_stat_bonuses({2: 1})
	assert_almost_eq(bonuses["range"] as float, 20.0, 0.001)

func test_stat_bonuses_multiple_nodes_sum() -> void:
	var bonuses := _tree.get_stat_bonuses({0: 1, 1: 1, 2: 1, 3: 1})
	# damage: 5 + 0 + 0 + 3 = 8
	assert_almost_eq(bonuses["damage"] as float, 8.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.1, 0.001)
	assert_almost_eq(bonuses["range"] as float, 20.0, 0.001)

func test_stat_bonuses_invalid_index_skipped() -> void:
	var bonuses := _tree.get_stat_bonuses({0: 1, 99: 1})
	assert_almost_eq(bonuses["damage"] as float, 5.0, 0.001)

func test_stat_bonuses_scale_with_level() -> void:
	var bonuses := _tree.get_stat_bonuses({0: 3})
	# damage: 5.0 * 3 = 15.0
	assert_almost_eq(bonuses["damage"] as float, 15.0, 0.001)

# ---------------------------------------------------------------------------
# SkillNode properties
# ---------------------------------------------------------------------------

func test_skill_node_is_hero_unlock_flag() -> void:
	var n: SkillNode = _tree.nodes[3]
	assert_true(n.is_hero_unlock)

func test_skill_node_not_hero_unlock_by_default() -> void:
	var n: SkillNode = _tree.nodes[0]
	assert_false(n.is_hero_unlock)
