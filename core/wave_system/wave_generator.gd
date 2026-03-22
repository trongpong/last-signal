class_name WaveGenerator
extends RefCounted

## Procedurally generates WaveDefinitions for endless mode.
## Wave composition scales with wave number; new enemy types unlock progressively.
## Boss waves occur every 10 waves.

# ---------------------------------------------------------------------------
# Enemy pool
# ---------------------------------------------------------------------------

## All enemy IDs available in endless mode, in unlock order.
const ENEMY_POOL: Array = [
	"scout_basic",
	"drone_basic",
	"drone_fast",
	"tank_heavy",
	"scout_armored",
	"flyer_light",
	"shielder",
	"drone_swarm",
	"tank_boss",
	"healer_support",
	"flyer_heavy",
	"shielder_elite",
]

## Wave number at which each enemy in ENEMY_POOL becomes available.
## Indexed identically to ENEMY_POOL.
const UNLOCK_WAVE: Array = [
	1,   # scout_basic
	1,   # drone_basic
	3,   # drone_fast
	5,   # tank_heavy
	7,   # scout_armored
	8,   # flyer_light
	10,  # shielder
	12,  # drone_swarm
	15,  # tank_boss
	18,  # healer_support
	20,  # flyer_heavy
	25,  # shielder_elite
]

## Wave interval between boss waves.
const BOSS_WAVE_INTERVAL: int = 10

## Base enemy count for the first wave.
const BASE_ENEMY_COUNT: int = 8

## Additional enemies added per wave number.
const ENEMIES_PER_WAVE: int = 2

## Maximum number of different enemy types in a single wave sub-group.
const MAX_ENEMY_VARIETIES: int = 4

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Generates a WaveDefinition for the given wave number and difficulty.
## Higher wave numbers yield more enemies and greater variety.
func generate_wave(wave_number: int, difficulty: int) -> WaveDefinition:
	var wd := WaveDefinition.new()
	wd.wave_number = wave_number
	wd.is_boss_wave = _is_boss_wave(wave_number)

	var available: Array = _get_available_enemies(wave_number)
	if available.is_empty():
		# Fallback: always have at least the first enemy
		available = [ENEMY_POOL[0]]

	# Scale total enemy count with wave number and difficulty
	var total_count: int = _calculate_total_count(wave_number, difficulty)

	if wd.is_boss_wave:
		wd.sub_waves = _build_boss_sub_waves(available, total_count, wave_number)
	else:
		wd.sub_waves = _build_normal_sub_waves(available, total_count, wave_number)

	return wd


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns true if this is a boss wave (every BOSS_WAVE_INTERVAL).
func _is_boss_wave(wave_number: int) -> bool:
	return wave_number % BOSS_WAVE_INTERVAL == 0


## Returns all enemy IDs unlocked at or before the given wave number.
func _get_available_enemies(wave_number: int) -> Array:
	var result: Array = []
	for i in ENEMY_POOL.size():
		if UNLOCK_WAVE[i] <= wave_number:
			result.append(ENEMY_POOL[i])
	return result


## Calculates the total enemy count for a wave.
func _calculate_total_count(wave_number: int, difficulty: int) -> int:
	var base: int = BASE_ENEMY_COUNT + (wave_number - 1) * ENEMIES_PER_WAVE
	# Exponential scaling after wave 20 for endless mode
	if wave_number > 20:
		base += int(pow(float(wave_number - 20) / 10.0, 1.5) * 10.0)
	var multiplier: float = _difficulty_count_multiplier(difficulty)
	# Boss waves have 50% more enemies
	if _is_boss_wave(wave_number):
		multiplier *= 1.5
	return maxi(1, int(float(base) * multiplier))


## Returns a count multiplier based on difficulty.
func _difficulty_count_multiplier(difficulty: int) -> float:
	match difficulty:
		Enums.Difficulty.HARD:
			return 1.2
		Enums.Difficulty.NIGHTMARE:
			return 1.5
		_:
			return 1.0


## Builds sub-waves for a normal (non-boss) wave.
## Splits total_count across up to MAX_ENEMY_VARIETIES enemy types.
func _build_normal_sub_waves(available: Array, total_count: int, wave_number: int) -> Array:
	var result: Array = []
	# Pick up to MAX_ENEMY_VARIETIES from the end of the available list
	# (end = most recently unlocked = most interesting variety)
	var variety_count: int = mini(available.size(), MAX_ENEMY_VARIETIES)
	# Bias toward more recent enemies as wave number grows
	var variety_start: int = maxi(0, available.size() - variety_count)
	var chosen: Array = available.slice(variety_start, available.size())

	if chosen.is_empty():
		return result

	# Distribute total count evenly across chosen types (remainder to first type)
	var per_type: int = maxi(1, total_count / chosen.size())
	var remainder: int = total_count - per_type * chosen.size()

	var accumulated_delay: float = 0.0
	for i in chosen.size():
		var count: int = per_type + (1 if i == 0 else 0) * remainder
		if count <= 0:
			continue
		var sw := SubWaveDefinition.new(
			chosen[i],
			count,
			Constants.DEFAULT_SPAWN_INTERVAL,
			accumulated_delay
		)
		result.append(sw)
		# Stagger each sub-wave group by 2 seconds after the previous finishes
		accumulated_delay += float(count) * Constants.DEFAULT_SPAWN_INTERVAL + 2.0

	return result


## Builds sub-waves for a boss wave: a main boss group + supporting enemies.
func _build_boss_sub_waves(available: Array, total_count: int, wave_number: int) -> Array:
	var result: Array = []
	if available.is_empty():
		return result

	# Choose a boss-type enemy: prefer the last available (strongest)
	var boss_id: String = available[available.size() - 1]
	var boss_count: int = clampi(wave_number / BOSS_WAVE_INTERVAL, 1, 5)

	var boss_sw := SubWaveDefinition.new(boss_id, boss_count, 2.0, 0.0)
	result.append(boss_sw)

	# Fill remaining count with supporting enemies
	var support_count: int = maxi(0, total_count - boss_count)
	if support_count > 0 and available.size() > 1:
		var support_id: String = available[maxi(0, available.size() - 2)]
		var support_delay: float = float(boss_count) * 2.0 + 1.0
		var support_sw := SubWaveDefinition.new(
			support_id,
			support_count,
			Constants.DEFAULT_SPAWN_INTERVAL,
			support_delay
		)
		result.append(support_sw)

	return result
