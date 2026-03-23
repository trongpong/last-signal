extends Node

## Central audio manager singleton for Last Signal.
## Manages music via MusicSystem and SFX via a pooled AudioStreamPlayer set.
## Registered as an autoload in project.godot.

const SFX_POOL_SIZE := 8
const MAX_SFX_CACHE: int = 64

var _music_system: MusicSystem
var _sfx_generator: SFXGenerator
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}  # key -> AudioStreamWAV
var _sfx_access_order: Array = []  # LRU tracking: oldest first
var _bg_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_buses()

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
# Procedural background music
# ---------------------------------------------------------------------------

## Generate and play a simple ambient drone loop using the synth engine.
## Creates a layered sine tone with a slow filter sweep for atmosphere.
func play_procedural_background() -> void:
	if _bg_player != null and _bg_player.playing:
		return

	var sample_rate: int = SFXGenerator.SAMPLE_RATE
	var duration: float = 8.0  # 8-second loop

	# Layer 1: deep bass drone at ~55 Hz (A1)
	var bass := SynthEngine.generate_sine(55.0, duration, sample_rate)
	# Layer 2: subtle fifth at ~82.5 Hz (E2)
	var fifth := SynthEngine.generate_sine(82.5, duration, sample_rate)
	# Layer 3: soft high harmonic at ~220 Hz (A3) through lowpass
	var harmonic := SynthEngine.generate_sine(220.0, duration, sample_rate)
	harmonic = SynthEngine.apply_filter_lowpass(harmonic, 300.0, sample_rate)

	# Mix layers: bass dominant, fifth softer, harmonic subtle
	var mixed := SynthEngine.mix(bass, fifth, 0.5, 0.25)
	mixed = SynthEngine.mix(mixed, harmonic, 1.0, 0.15)

	# Apply a gentle envelope for smooth looping (fade in/out at edges)
	mixed = SynthEngine.apply_adsr(mixed, 0.5, 0.2, 0.8, 0.5, sample_rate)

	var stream := _samples_to_stream(mixed)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = mixed.size()

	if _bg_player == null:
		_bg_player = AudioStreamPlayer.new()
		_bg_player.bus = "Music"
		_bg_player.name = "ProceduralBG"
		_bg_player.volume_db = linear_to_db(0.3)
		add_child(_bg_player)

	_bg_player.stream = stream
	_bg_player.play()


## Stop the procedural background drone.
func stop_procedural_background() -> void:
	if _bg_player != null and _bg_player.playing:
		_bg_player.stop()


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
## Uses LRU eviction to keep the cache within MAX_SFX_CACHE entries.
func _get_or_generate(key: String, generator: Callable) -> AudioStreamWAV:
	if _sfx_cache.has(key):
		# Move to end of access order (most recently used)
		_sfx_access_order.erase(key)
		_sfx_access_order.append(key)
		return _sfx_cache[key]
	var samples: PackedFloat32Array = generator.call()
	var stream := _samples_to_stream(samples)
	# Evict oldest entry if cache is full
	if _sfx_cache.size() >= MAX_SFX_CACHE:
		var oldest_key = _sfx_access_order.pop_front()
		_sfx_cache.erase(oldest_key)
	_sfx_cache[key] = stream
	_sfx_access_order.append(key)
	return stream


## Ensure "Music" and "SFX" audio buses exist, creating them if missing.
func _ensure_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")


## Convert a PackedFloat32Array of samples [-1,1] to an AudioStreamWAV (FORMAT_16_BITS, mono).
func _samples_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	return SynthEngine.samples_to_stream(samples, SFXGenerator.SAMPLE_RATE)
