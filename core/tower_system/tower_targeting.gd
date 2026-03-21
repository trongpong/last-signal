class_name TowerTargeting
extends Node

## Selects a target enemy index from a list of enemy data dictionaries.
## Each enemy dictionary must contain:
##   position: Vector2
##   hp: float
##   progress: float  (0.0 = start, 1.0 = end)
##   alive: bool
##
## Returns the index into the array, or -1 if no valid target is found.

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Select a target from enemies based on the given targeting mode.
## tower_pos: world position of the firing tower
## attack_range: maximum distance in world units
## mode: Enums.TargetingMode value
## enemies: Array of Dictionaries (position, hp, progress, alive)
## Returns index of chosen target, or -1.
func select_target(tower_pos: Vector2, attack_range: float, mode: int, enemies: Array) -> int:
	match mode:
		Enums.TargetingMode.NEAREST:
			return _select_nearest(tower_pos, attack_range, enemies)
		Enums.TargetingMode.STRONGEST:
			return _select_strongest(tower_pos, attack_range, enemies)
		Enums.TargetingMode.WEAKEST:
			return _select_weakest(tower_pos, attack_range, enemies)
		Enums.TargetingMode.FIRST:
			return _select_first(tower_pos, attack_range, enemies)
		Enums.TargetingMode.LAST:
			return _select_last(tower_pos, attack_range, enemies)
	return -1

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns true if the enemy at index i is a valid target (alive and in range).
func _is_valid(tower_pos: Vector2, attack_range: float, enemies: Array, i: int) -> bool:
	var e: Dictionary = enemies[i]
	if not (e.get("alive", false) as bool):
		return false
	var dist: float = (tower_pos.distance_to(e.get("position", Vector2.ZERO) as Vector2))
	return dist <= attack_range

## NEAREST: closest enemy to the tower.
func _select_nearest(tower_pos: Vector2, attack_range: float, enemies: Array) -> int:
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(enemies.size()):
		if not _is_valid(tower_pos, attack_range, enemies, i):
			continue
		var dist: float = tower_pos.distance_to(enemies[i].get("position", Vector2.ZERO) as Vector2)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

## STRONGEST: enemy with the highest current HP.
func _select_strongest(tower_pos: Vector2, attack_range: float, enemies: Array) -> int:
	var best_idx: int = -1
	var best_hp: float = -INF
	for i in range(enemies.size()):
		if not _is_valid(tower_pos, attack_range, enemies, i):
			continue
		var hp: float = enemies[i].get("hp", 0.0) as float
		if hp > best_hp:
			best_hp = hp
			best_idx = i
	return best_idx

## WEAKEST: enemy with the lowest current HP.
func _select_weakest(tower_pos: Vector2, attack_range: float, enemies: Array) -> int:
	var best_idx: int = -1
	var best_hp: float = INF
	for i in range(enemies.size()):
		if not _is_valid(tower_pos, attack_range, enemies, i):
			continue
		var hp: float = enemies[i].get("hp", 0.0) as float
		if hp < best_hp:
			best_hp = hp
			best_idx = i
	return best_idx

## FIRST: enemy farthest along the path (highest progress).
func _select_first(tower_pos: Vector2, attack_range: float, enemies: Array) -> int:
	var best_idx: int = -1
	var best_progress: float = -INF
	for i in range(enemies.size()):
		if not _is_valid(tower_pos, attack_range, enemies, i):
			continue
		var progress: float = enemies[i].get("progress", 0.0) as float
		if progress > best_progress:
			best_progress = progress
			best_idx = i
	return best_idx

## LAST: enemy least far along the path (lowest progress).
func _select_last(tower_pos: Vector2, attack_range: float, enemies: Array) -> int:
	var best_idx: int = -1
	var best_progress: float = INF
	for i in range(enemies.size()):
		if not _is_valid(tower_pos, attack_range, enemies, i):
			continue
		var progress: float = enemies[i].get("progress", 0.0) as float
		if progress < best_progress:
			best_progress = progress
			best_idx = i
	return best_idx
