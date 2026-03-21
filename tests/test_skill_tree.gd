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
	assert_true(_tree.can_unlock_node(0, []))

func test_can_unlock_independent_node_with_empty_unlocked() -> void:
	assert_true(_tree.can_unlock_node(2, []))

func test_cannot_unlock_node_that_is_already_unlocked() -> void:
	assert_false(_tree.can_unlock_node(0, [0]))

func test_cannot_unlock_node_missing_prereq() -> void:
	assert_false(_tree.can_unlock_node(1, []))

func test_can_unlock_node_when_prereq_satisfied() -> void:
	assert_true(_tree.can_unlock_node(1, [0]))

func test_can_unlock_deep_node_when_prereqs_met() -> void:
	assert_true(_tree.can_unlock_node(3, [0, 1]))

func test_cannot_unlock_deep_node_with_only_root_unlocked() -> void:
	assert_false(_tree.can_unlock_node(3, [0]))

func test_invalid_index_returns_false() -> void:
	assert_false(_tree.can_unlock_node(99, []))

func test_negative_index_returns_false() -> void:
	assert_false(_tree.can_unlock_node(-1, []))

# ---------------------------------------------------------------------------
# get_node_cost
# ---------------------------------------------------------------------------

func test_cost_of_first_node() -> void:
	assert_eq(_tree.get_node_cost(0), 80)

func test_cost_of_second_node() -> void:
	assert_eq(_tree.get_node_cost(1), 100)

func test_cost_invalid_index_returns_zero() -> void:
	assert_eq(_tree.get_node_cost(99), 0)

# ---------------------------------------------------------------------------
# get_total_cost
# ---------------------------------------------------------------------------

func test_total_cost_sums_all_nodes() -> void:
	# 80 + 100 + 120 + 200 = 500
	assert_eq(_tree.get_total_cost(), 500)

func test_empty_tree_total_cost_is_zero() -> void:
	var t := SkillTree.new()
	assert_eq(t.get_total_cost(), 0)

# ---------------------------------------------------------------------------
# get_unlockable_nodes
# ---------------------------------------------------------------------------

func test_unlockable_with_nothing_unlocked() -> void:
	var unlockable := _tree.get_unlockable_nodes([])
	# Nodes 0 and 2 have no prereqs
	assert_true(unlockable.has(0))
	assert_true(unlockable.has(2))
	assert_false(unlockable.has(1))
	assert_false(unlockable.has(3))

func test_unlockable_after_unlocking_root() -> void:
	var unlockable := _tree.get_unlockable_nodes([0])
	assert_true(unlockable.has(1))
	assert_false(unlockable.has(0))

func test_unlockable_when_all_unlocked_is_empty() -> void:
	var unlockable := _tree.get_unlockable_nodes([0, 1, 2, 3])
	assert_eq(unlockable.size(), 0)

# ---------------------------------------------------------------------------
# get_stat_bonuses
# ---------------------------------------------------------------------------

func test_stat_bonuses_empty_unlocked_all_zero() -> void:
	var bonuses := _tree.get_stat_bonuses([])
	assert_almost_eq(bonuses["damage"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.0, 0.001)
	assert_almost_eq(bonuses["range"] as float, 0.0, 0.001)

func test_stat_bonuses_single_damage_node() -> void:
	var bonuses := _tree.get_stat_bonuses([0])
	assert_almost_eq(bonuses["damage"] as float, 5.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.0, 0.001)

func test_stat_bonuses_fire_rate_node() -> void:
	var bonuses := _tree.get_stat_bonuses([1])
	assert_almost_eq(bonuses["fire_rate"] as float, 0.1, 0.001)

func test_stat_bonuses_range_node() -> void:
	var bonuses := _tree.get_stat_bonuses([2])
	assert_almost_eq(bonuses["range"] as float, 20.0, 0.001)

func test_stat_bonuses_multiple_nodes_sum() -> void:
	var bonuses := _tree.get_stat_bonuses([0, 1, 2, 3])
	# damage: 5 + 0 + 0 + 3 = 8
	assert_almost_eq(bonuses["damage"] as float, 8.0, 0.001)
	assert_almost_eq(bonuses["fire_rate"] as float, 0.1, 0.001)
	assert_almost_eq(bonuses["range"] as float, 20.0, 0.001)

func test_stat_bonuses_invalid_index_skipped() -> void:
	var bonuses := _tree.get_stat_bonuses([0, 99])
	assert_almost_eq(bonuses["damage"] as float, 5.0, 0.001)

# ---------------------------------------------------------------------------
# SkillNode properties
# ---------------------------------------------------------------------------

func test_skill_node_is_hero_unlock_flag() -> void:
	var n: SkillNode = _tree.nodes[3]
	assert_true(n.is_hero_unlock)

func test_skill_node_not_hero_unlock_by_default() -> void:
	var n: SkillNode = _tree.nodes[0]
	assert_false(n.is_hero_unlock)
