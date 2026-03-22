class_name SubWaveDefinition
extends RefCounted

## Defines a single batch of enemies within a wave.
## Groups enemies of the same type that spawn together with a given interval.

## The enemy definition ID to spawn (matches EnemyDefinition.id)
var enemy_id: String = ""

## How many of this enemy to spawn
var count: int = 1

## Time in seconds between individual enemy spawns within this sub-wave
var spawn_interval: float = Constants.DEFAULT_SPAWN_INTERVAL

## Delay in seconds before this sub-wave begins (relative to wave start)
var delay: float = 0.0

## Index of the path this sub-wave's enemies should follow (0-based)
var path_index: int = 0


func _init(
	p_enemy_id: String = "",
	p_count: int = 1,
	p_spawn_interval: float = Constants.DEFAULT_SPAWN_INTERVAL,
	p_delay: float = 0.0,
	p_path_index: int = 0
) -> void:
	enemy_id = p_enemy_id
	count = p_count
	spawn_interval = p_spawn_interval
	delay = p_delay
	path_index = p_path_index
