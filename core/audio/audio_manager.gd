class_name AudioManager
extends Node

## Central audio manager singleton for Last Signal.
## Manages music via MusicSystem and SFX via a pooled AudioStreamPlayer set.
## Registered as an autoload in project.godot.

const SFX_POOL_SIZE := 8

var _music_system: MusicSystem
var _sfx_generator: SFXGenerator
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}  # key -> AudioStreamWAV


func _ready() -> void:
	_music_system = MusicSystem.new()
	_music_system.name = "MusicSystem"
	add_child(_music_system)

	_sfx_generator = SFXGenerator.new()

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_sfx_players.append(player)


# ---------------------------------------------------------------------------
# Music control
# ---------------------------------------------------------------------------

func set_music_region(region: int) -> void:
	_music_system.set_region(region)


func set_music_state(state: Enums.GameState) -> void:
	_music_system.set_game_state(state)


func set_boss_music(active: bool) -> void:
	_music_system.set_boss_active(active)


# ---------------------------------------------------------------------------
# SFX playback
# ---------------------------------------------------------------------------

func play_tower_fire(tower_type: Enums.TowerType, tier: int = 1) -> void:
	var cache_key := "tower_fire_%d_%d" % [tower_type, tier]
	var stream := _get_or_generate(cache_key, func():
		return _sfx_generator.generate_tower_fire(tower_type, tier)
	)
	_play_sfx(stream)


func play_enemy_death(size_scale: float = 1.0) -> void:
	# Quantize size to avoid cache bloat
	var quantized := snappedf(size_scale, 0.25)
	var cache_key := "enemy_death_%.2f" % quantized
	var stream := _get_or_generate(cache_key, func():
		return _sfx_generator.generate_enemy_death(quantized)
	)
	_play_sfx(stream)


func play_hero_summon() -> void:
	var stream := _get_or_generate("hero_summon", func():
		return _sfx_generator.generate_hero_summon()
	)
	_play_sfx(stream)


func play_ability_activate() -> void:
	var stream := _get_or_generate("ability_activate", func():
		return _sfx_generator.generate_ability_activate()
	)
	_play_sfx(stream)


# ---------------------------------------------------------------------------
# Volume control
# ---------------------------------------------------------------------------

func set_music_volume(vol: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(vol, 0.0, 1.0)))


func set_sfx_volume(vol: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(vol, 0.0, 1.0)))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Find a free SFX player in the pool and play the stream on it.
func _play_sfx(stream: AudioStreamWAV) -> void:
	if stream == null:
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All players busy — steal the first one
	_sfx_players[0].stop()
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


## Return a cached AudioStreamWAV or generate and cache a new one.
func _get_or_generate(key: String, generator: Callable) -> AudioStreamWAV:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	var samples: PackedFloat32Array = generator.call()
	var stream := _samples_to_stream(samples)
	_sfx_cache[key] = stream
	return stream


## Convert a PackedFloat32Array of samples [-1,1] to an AudioStreamWAV (FORMAT_16_BITS, mono).
func _samples_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SFXGenerator.SAMPLE_RATE

	var num_samples := samples.size()
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)  # 2 bytes per 16-bit sample

	for i in num_samples:
		var int16_val := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		# Clamp to int16 range
		int16_val = clampi(int16_val, -32768, 32767)
		# Write little-endian int16
		byte_array[i * 2]     = int16_val & 0xFF
		byte_array[i * 2 + 1] = (int16_val >> 8) & 0xFF

	stream.data = byte_array
	return stream
