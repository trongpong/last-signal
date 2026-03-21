class_name WaveDefinition
extends Resource

## Data resource describing a single wave of enemies.
## Contains one or more SubWaveDefinitions that define which enemies spawn,
## how many, and when they spawn relative to wave start.

## The sequential number of this wave (1-indexed for display purposes)
@export var wave_number: int = 1

## Array of SubWaveDefinition objects defining enemy groups in this wave.
## Because SubWaveDefinition is not a Resource, stored as plain Array.
var sub_waves: Array = []

## Whether this is a boss wave (used to trigger special UI/music)
@export var is_boss_wave: bool = false


## Returns the sum of all enemy counts across all sub-waves.
func get_total_enemy_count() -> int:
	var total: int = 0
	for sw in sub_waves:
		if sw is SubWaveDefinition:
			total += sw.count
	return total
