class_name TowerPlacer
extends Node

## Manages tower build spots: snapping, occupancy, and sell value calculation.
## Build spots are Vector2 world positions. SNAP_DISTANCE is the maximum
## radius within which a world position snaps to a build spot.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SNAP_DISTANCE: float = 40.0
const INVALID_SPOT: Vector2 = Vector2(-1.0, -1.0)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _spots: Array[Vector2] = []
var _occupied: Dictionary = {}  # Vector2 → bool

# ---------------------------------------------------------------------------
# Build Spot Setup
# ---------------------------------------------------------------------------

## Replace all build spots with the given list.
func set_build_spots(spots: Array) -> void:
	_spots.clear()
	_occupied.clear()
	for s in spots:
		var v := s as Vector2
		_spots.append(v)
		_occupied[v] = false

# ---------------------------------------------------------------------------
# Snapping
# ---------------------------------------------------------------------------

## Returns the nearest unoccupied build spot within SNAP_DISTANCE of world_pos.
## Returns INVALID_SPOT if none found.
func get_nearest_build_spot(world_pos: Vector2) -> Vector2:
	var best_spot: Vector2 = INVALID_SPOT
	var best_dist: float = INF
	for spot in _spots:
		if _occupied.get(spot, false) as bool:
			continue
		var dist: float = world_pos.distance_to(spot)
		if dist <= SNAP_DISTANCE and dist < best_dist:
			best_dist = dist
			best_spot = spot
	return best_spot

# ---------------------------------------------------------------------------
# Occupancy
# ---------------------------------------------------------------------------

## Mark a spot as occupied.
func mark_occupied(spot: Vector2) -> void:
	if _occupied.has(spot):
		_occupied[spot] = true

## Mark a spot as free.
func mark_free(spot: Vector2) -> void:
	if _occupied.has(spot):
		_occupied[spot] = false

## Returns true if the spot is currently occupied.
func is_occupied(spot: Vector2) -> bool:
	return _occupied.get(spot, false) as bool

# ---------------------------------------------------------------------------
# Sell Value
# ---------------------------------------------------------------------------

## Calculate gold refund when selling a tower.
## total_investment: total gold spent on the tower (base cost + all upgrades)
## refund_upgrade_tier: the tower's current upgrade tier (depth of chosen path)
## bonus_percent: additional refund percent from global upgrades (default 0)
## Returns floored gold value.
func calculate_sell_value(total_investment: int, refund_upgrade_tier: int, bonus_percent: int = 0) -> int:
	var refund_rate: float = minf(Constants.BASE_SELL_REFUND + float(refund_upgrade_tier) * Constants.SELL_REFUND_PER_UPGRADE_TIER + float(bonus_percent) / 100.0, 0.95)
	return int(float(total_investment) * refund_rate)
