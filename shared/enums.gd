class_name Enums

## Shared enumerations for Last Signal tower defense game.
## All enums are defined here for global access via class_name.

enum Difficulty {
	NORMAL,
	HARD,
	NIGHTMARE
}

enum MapMode {
	FIXED_PATH,
	GRID_MAZE
}

enum TowerType {
	PULSE_CANNON,
	ARC_EMITTER,
	CRYO_ARRAY,
	MISSILE_POD,
	BEAM_SPIRE,
	NANO_HIVE,
	HARVESTER
}

enum EnemyArchetype {
	SCOUT,
	DRONE,
	TANK,
	FLYER,
	SHIELDER,
	HEALER
}

enum TargetingMode {
	NEAREST,
	STRONGEST,
	WEAKEST,
	FIRST,
	LAST
}

enum GameState {
	MENU,
	BUILDING,
	WAVE_ACTIVE,
	WAVE_COMPLETE,
	VICTORY,
	DEFEAT,
	PAUSED
}

enum DamageType {
	PULSE,
	ARC,
	CRYO,
	MISSILE,
	BEAM,
	NANO,
	HARVEST
}

enum AbilityType {
	ORBITAL_STRIKE,
	EMP_BURST,
	REPAIR_WAVE,
	SHIELD_MATRIX,
	OVERCLOCK,
	SCRAP_SALVAGE
}
