class_name LevelData

## Static helper that returns hand-crafted wave sequences for specific levels.
## Returns an Array[WaveDefinition].  Each WaveDefinition has its sub_waves
## populated from hand-authored data.
##
## Levels covered:
##   1_1  – "First Contact"  (5 waves, tutorial pacing)
##   1_2  – "Outer Gate"     (8 waves, introduces drone_fast)
##   1_3  – "Relay Defense"  (10 waves, first armoured enemy)
##
## All other levels fall back to WaveGenerator (procedural).

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns an Array of WaveDefinitions for the given level id.
## Returns an empty Array if no hand-crafted data exists for that id.
static func get_waves(level_id: String) -> Array:
	match level_id:
		"1_1":
			return _level_1_1()
		"1_2":
			return _level_1_2()
		"1_3":
			return _level_1_3()
	return []

# ---------------------------------------------------------------------------
# Level 1-1: First Contact
## 5 gentle waves — only scout_basic and drone_basic.
# ---------------------------------------------------------------------------

static func _level_1_1() -> Array:
	var waves: Array = []

	# Wave 1 — 6 scouts
	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 6, 0.6, 0.0),
	]))
	# Wave 2 — 6 scouts + 3 drones
	waves.append(_make_wave(2, false, [
		_sub("scout_basic", 6, 0.6, 0.0),
		_sub("drone_basic", 3, 0.8, 4.0),
	]))
	# Wave 3 — 8 scouts
	waves.append(_make_wave(3, false, [
		_sub("scout_basic", 8, 0.5, 0.0),
	]))
	# Wave 4 — 5 drones + 5 scouts
	waves.append(_make_wave(4, false, [
		_sub("drone_basic", 5, 0.7, 0.0),
		_sub("scout_basic", 5, 0.5, 4.5),
	]))
	# Wave 5 — mini-boss wave: 4 drones + 10 scouts
	waves.append(_make_wave(5, true, [
		_sub("drone_basic", 4, 1.0, 0.0),
		_sub("scout_basic", 10, 0.4, 5.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-2: Outer Gate
## 8 waves — introduces drone_fast on wave 4.
# ---------------------------------------------------------------------------

static func _level_1_2() -> Array:
	var waves: Array = []

	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 8, 0.5, 0.0),
	]))
	waves.append(_make_wave(2, false, [
		_sub("scout_basic", 8, 0.5, 0.0),
		_sub("drone_basic", 4, 0.7, 5.0),
	]))
	waves.append(_make_wave(3, false, [
		_sub("drone_basic", 8, 0.6, 0.0),
		_sub("scout_basic", 6, 0.5, 6.0),
	]))
	# Wave 4 — first drone_fast appearance
	waves.append(_make_wave(4, false, [
		_sub("scout_basic", 6, 0.5, 0.0),
		_sub("drone_fast", 4, 0.4, 4.0),
	]))
	waves.append(_make_wave(5, false, [
		_sub("drone_basic", 8, 0.5, 0.0),
		_sub("drone_fast", 4, 0.35, 5.5),
	]))
	waves.append(_make_wave(6, false, [
		_sub("scout_basic", 10, 0.45, 0.0),
		_sub("drone_fast", 6, 0.35, 6.0),
	]))
	waves.append(_make_wave(7, false, [
		_sub("drone_basic", 10, 0.5, 0.0),
		_sub("drone_fast", 8, 0.35, 6.5),
	]))
	# Wave 8 — boss: mass swarm
	waves.append(_make_wave(8, true, [
		_sub("drone_fast", 6, 0.3, 0.0),
		_sub("scout_basic", 12, 0.4, 3.0),
		_sub("drone_basic", 8, 0.5, 8.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Level 1-3: Relay Defense
## 10 waves — introduces tank_heavy on wave 6.
# ---------------------------------------------------------------------------

static func _level_1_3() -> Array:
	var waves: Array = []

	waves.append(_make_wave(1, false, [
		_sub("scout_basic", 10, 0.5, 0.0),
	]))
	waves.append(_make_wave(2, false, [
		_sub("drone_basic", 8, 0.55, 0.0),
		_sub("scout_basic", 6, 0.45, 5.0),
	]))
	waves.append(_make_wave(3, false, [
		_sub("drone_fast", 6, 0.35, 0.0),
		_sub("drone_basic", 6, 0.5, 4.0),
	]))
	waves.append(_make_wave(4, false, [
		_sub("scout_basic", 12, 0.45, 0.0),
		_sub("drone_fast", 6, 0.35, 6.5),
	]))
	waves.append(_make_wave(5, false, [
		_sub("drone_basic", 10, 0.5, 0.0),
		_sub("drone_fast", 8, 0.35, 6.0),
	]))
	# Wave 6 — tank_heavy debut
	waves.append(_make_wave(6, false, [
		_sub("tank_heavy", 2, 1.5, 0.0),
		_sub("scout_basic", 12, 0.4, 4.0),
	]))
	waves.append(_make_wave(7, false, [
		_sub("tank_heavy", 3, 1.5, 0.0),
		_sub("drone_fast", 8, 0.35, 5.5),
	]))
	waves.append(_make_wave(8, false, [
		_sub("drone_basic", 12, 0.45, 0.0),
		_sub("tank_heavy", 3, 1.5, 7.0),
		_sub("drone_fast", 6, 0.35, 12.0),
	]))
	waves.append(_make_wave(9, false, [
		_sub("scout_basic", 14, 0.4, 0.0),
		_sub("drone_fast", 10, 0.3, 7.0),
		_sub("tank_heavy", 4, 1.5, 12.0),
	]))
	# Wave 10 — boss: tanks + escorts
	waves.append(_make_wave(10, true, [
		_sub("tank_heavy", 4, 2.0, 0.0),
		_sub("drone_fast", 10, 0.3, 10.0),
		_sub("scout_basic", 16, 0.35, 16.0),
	]))

	return waves

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_wave(number: int, is_boss: bool, sub_waves: Array) -> WaveDefinition:
	var wd := WaveDefinition.new()
	wd.wave_number = number
	wd.is_boss_wave = is_boss
	wd.sub_waves = sub_waves
	return wd


static func _sub(enemy_id: String, count: int, interval: float, delay: float) -> SubWaveDefinition:
	return SubWaveDefinition.new(enemy_id, count, interval, delay)
