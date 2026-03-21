# Plan 7: Audio System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the procedural synth audio engine — layered ambient music that reacts to game state, per-tower SFX generation, and the AudioManager singleton for state-based music transitions and dynamic mixing.

**Architecture:** All audio is generated at runtime using Godot's `AudioStreamGenerator`. The music system uses layered `AudioStreamPlayer` nodes with crossfading. SFX are short generated waveforms cached per tower type. The AudioManager handles state transitions and mixing.

**Tech Stack:** Godot 4.x, GDScript, AudioStreamGenerator

**Spec:** `docs/superpowers/specs/2026-03-21-last-signal-td-design.md` — Section 13

**Depends on:** Plan 1 (Foundation)

---

## File Structure

```
res://
├── core/
│   └── audio/
│       ├── audio_manager.gd            # AudioManager singleton
│       ├── synth_engine.gd             # Low-level waveform generation
│       ├── music_layer.gd              # Single music layer (pad, rhythm, melody, boss)
│       ├── music_system.gd             # Manages all layers, crossfading
│       └── sfx_generator.gd            # Generates and caches tower/enemy SFX
└── tests/
    ├── test_synth_engine.gd
    ├── test_music_system.gd
    └── test_sfx_generator.gd
```

---

### Task 1: Implement SynthEngine (Waveform Generation)

**Files:**
- Create: `core/audio/synth_engine.gd`
- Test: `tests/test_synth_engine.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_synth_engine.gd
extends GutTest

func test_generate_sine():
    var samples := SynthEngine.generate_sine(440.0, 0.1, 44100)
    assert_gt(samples.size(), 0)
    assert_eq(samples.size(), 4410)  # 0.1s * 44100

func test_generate_square():
    var samples := SynthEngine.generate_square(440.0, 0.1, 44100)
    assert_eq(samples.size(), 4410)
    # Square wave should have values near -1 or 1
    assert_true(absf(samples[0]) > 0.5 or samples[0] == 0.0)

func test_generate_saw():
    var samples := SynthEngine.generate_saw(440.0, 0.1, 44100)
    assert_eq(samples.size(), 4410)

func test_generate_noise():
    var samples := SynthEngine.generate_noise(0.1, 44100)
    assert_eq(samples.size(), 4410)

func test_apply_envelope():
    var samples := SynthEngine.generate_sine(440.0, 0.5, 44100)
    var enveloped := SynthEngine.apply_adsr(samples, 0.01, 0.05, 0.7, 0.1, 44100)
    assert_eq(enveloped.size(), samples.size())
    # Attack should ramp up, release should ramp down
    assert_lt(absf(enveloped[0]), absf(enveloped[440]))  # Start < after attack

func test_mix_samples():
    var a := SynthEngine.generate_sine(440.0, 0.1, 44100)
    var b := SynthEngine.generate_sine(880.0, 0.1, 44100)
    var mixed := SynthEngine.mix(a, b, 0.5, 0.5)
    assert_eq(mixed.size(), a.size())
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/audio/synth_engine.gd
class_name SynthEngine
extends RefCounted

## Low-level waveform generation utilities.
## All functions return PackedFloat32Array of mono samples.


static func generate_sine(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
    var samples := PackedFloat32Array()
    var count := int(duration * sample_rate)
    samples.resize(count)
    for i in range(count):
        var t := float(i) / sample_rate
        samples[i] = sin(TAU * freq * t)
    return samples


static func generate_square(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
    var samples := PackedFloat32Array()
    var count := int(duration * sample_rate)
    samples.resize(count)
    for i in range(count):
        var t := float(i) / sample_rate
        samples[i] = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
    return samples


static func generate_saw(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
    var samples := PackedFloat32Array()
    var count := int(duration * sample_rate)
    samples.resize(count)
    for i in range(count):
        var t := float(i) / sample_rate
        samples[i] = 2.0 * fmod(t * freq, 1.0) - 1.0
    return samples


static func generate_noise(duration: float, sample_rate: int) -> PackedFloat32Array:
    var samples := PackedFloat32Array()
    var count := int(duration * sample_rate)
    samples.resize(count)
    for i in range(count):
        samples[i] = randf_range(-1.0, 1.0)
    return samples


static func apply_adsr(samples: PackedFloat32Array, attack: float, decay: float,
        sustain: float, release: float, sample_rate: int) -> PackedFloat32Array:
    var result := PackedFloat32Array()
    result.resize(samples.size())
    var attack_samples := int(attack * sample_rate)
    var decay_samples := int(decay * sample_rate)
    var release_samples := int(release * sample_rate)
    var sustain_start := attack_samples + decay_samples
    var release_start := samples.size() - release_samples

    for i in range(samples.size()):
        var envelope: float
        if i < attack_samples:
            envelope = float(i) / maxf(float(attack_samples), 1.0)
        elif i < sustain_start:
            var decay_progress := float(i - attack_samples) / maxf(float(decay_samples), 1.0)
            envelope = 1.0 - (1.0 - sustain) * decay_progress
        elif i < release_start:
            envelope = sustain
        else:
            var release_progress := float(i - release_start) / maxf(float(release_samples), 1.0)
            envelope = sustain * (1.0 - release_progress)
        result[i] = samples[i] * envelope
    return result


static func mix(a: PackedFloat32Array, b: PackedFloat32Array,
        vol_a: float, vol_b: float) -> PackedFloat32Array:
    var length := mini(a.size(), b.size())
    var result := PackedFloat32Array()
    result.resize(length)
    for i in range(length):
        result[i] = clampf(a[i] * vol_a + b[i] * vol_b, -1.0, 1.0)
    return result


static func apply_filter_lowpass(samples: PackedFloat32Array, cutoff: float,
        sample_rate: int) -> PackedFloat32Array:
    var result := PackedFloat32Array()
    result.resize(samples.size())
    var rc := 1.0 / (TAU * cutoff)
    var dt := 1.0 / sample_rate
    var alpha := dt / (rc + dt)
    result[0] = samples[0]
    for i in range(1, samples.size()):
        result[i] = result[i-1] + alpha * (samples[i] - result[i-1])
    return result
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/audio/synth_engine.gd tests/test_synth_engine.gd
git commit -m "feat: implement SynthEngine with sine, square, saw, noise, ADSR"
```

---

### Task 2: Implement MusicLayer and MusicSystem

**Files:**
- Create: `core/audio/music_layer.gd`
- Create: `core/audio/music_system.gd`
- Test: `tests/test_music_system.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_music_system.gd
extends GutTest

var music: MusicSystem

func before_each():
    music = MusicSystem.new()
    add_child(music)

func after_each():
    music.queue_free()

func test_initial_state_is_silent():
    assert_eq(music.get_active_layers(), 0)

func test_set_region_changes_key():
    music.set_region(1)
    assert_eq(music.current_key, "C")
    music.set_region(3)
    assert_eq(music.current_key, "F#")

func test_activate_base_layer():
    music.set_region(1)
    music.set_game_state(Enums.GameState.BUILDING)
    assert_ge(music.get_active_layers(), 1)

func test_combat_activates_more_layers():
    music.set_region(1)
    music.set_game_state(Enums.GameState.BUILDING)
    var building_layers := music.get_active_layers()
    music.set_game_state(Enums.GameState.WAVE_ACTIVE)
    assert_gt(music.get_active_layers(), building_layers)

func test_set_intensity():
    music.set_region(1)
    music.set_game_state(Enums.GameState.WAVE_ACTIVE)
    music.set_intensity(0.8)
    # Higher intensity should be reflected
    assert_almost_eq(music.intensity, 0.8, 0.01)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write MusicLayer**

```gdscript
# core/audio/music_layer.gd
class_name MusicLayer
extends AudioStreamPlayer

## A single music layer (pad, rhythm, melody, boss).
## Generates and loops a synth pattern.

var layer_name: String = ""
var target_volume: float = 0.0
var _fade_speed: float = 2.0

func _process(delta: float) -> void:
    # Smooth volume fading
    var current_db := volume_db
    var target_db := linear_to_db(target_volume) if target_volume > 0.01 else -80.0
    volume_db = move_toward(current_db, target_db, _fade_speed * delta * 10.0)

    if volume_db <= -79.0 and playing:
        stop()
    elif volume_db > -79.0 and not playing and target_volume > 0.01:
        play()


func fade_in(vol: float = 1.0) -> void:
    target_volume = vol


func fade_out() -> void:
    target_volume = 0.0
```

- [ ] **Step 4: Write MusicSystem**

```gdscript
# core/audio/music_system.gd
class_name MusicSystem
extends Node

const REGION_KEYS := {1: "C", 2: "D", 3: "F#", 4: "A", 5: "E"}

var current_key: String = "C"
var intensity: float = 0.0

var _base_layer: MusicLayer
var _intensity_layer: MusicLayer
var _combat_layer: MusicLayer
var _boss_layer: MusicLayer
var _current_state: Enums.GameState = Enums.GameState.MENU


func _ready() -> void:
    _base_layer = _create_layer("base")
    _intensity_layer = _create_layer("intensity")
    _combat_layer = _create_layer("combat")
    _boss_layer = _create_layer("boss")


func set_region(region: int) -> void:
    current_key = REGION_KEYS.get(region, "C")


func set_game_state(state: Enums.GameState) -> void:
    _current_state = state
    match state:
        Enums.GameState.MENU:
            _base_layer.fade_out()
            _intensity_layer.fade_out()
            _combat_layer.fade_out()
            _boss_layer.fade_out()
        Enums.GameState.BUILDING:
            _base_layer.fade_in(0.6)
            _intensity_layer.fade_out()
            _combat_layer.fade_out()
            _boss_layer.fade_out()
        Enums.GameState.WAVE_ACTIVE:
            _base_layer.fade_in(0.6)
            _intensity_layer.fade_in(0.4)
            _combat_layer.fade_in(0.5)
            _boss_layer.fade_out()
        Enums.GameState.VICTORY, Enums.GameState.DEFEAT:
            _base_layer.fade_in(0.3)
            _intensity_layer.fade_out()
            _combat_layer.fade_out()
            _boss_layer.fade_out()


func set_boss_active(active: bool) -> void:
    if active:
        _boss_layer.fade_in(0.7)
        _combat_layer.fade_in(0.3)
    else:
        _boss_layer.fade_out()


func set_intensity(value: float) -> void:
    intensity = clampf(value, 0.0, 1.0)
    _intensity_layer.target_volume = intensity * 0.5


func get_active_layers() -> int:
    var count := 0
    if _base_layer.target_volume > 0.01: count += 1
    if _intensity_layer.target_volume > 0.01: count += 1
    if _combat_layer.target_volume > 0.01: count += 1
    if _boss_layer.target_volume > 0.01: count += 1
    return count


func _create_layer(layer_name: String) -> MusicLayer:
    var layer := MusicLayer.new()
    layer.layer_name = layer_name
    layer.bus = "Music"
    add_child(layer)
    return layer
```

- [ ] **Step 5: Run test to verify it passes**

- [ ] **Step 6: Commit**

```bash
git add core/audio/music_layer.gd core/audio/music_system.gd tests/test_music_system.gd
git commit -m "feat: implement layered music system with state transitions"
```

---

### Task 3: Implement SFXGenerator

**Files:**
- Create: `core/audio/sfx_generator.gd`
- Test: `tests/test_sfx_generator.gd`

- [ ] **Step 1: Write the test**

```gdscript
# tests/test_sfx_generator.gd
extends GutTest

var sfx: SFXGenerator

func before_each():
    sfx = SFXGenerator.new()

func test_generate_tower_sfx():
    var samples := sfx.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 1)
    assert_gt(samples.size(), 0)

func test_different_towers_different_sounds():
    var pulse := sfx.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 1)
    var cryo := sfx.generate_tower_fire(Enums.TowerType.CRYO_ARRAY, 1)
    # They should differ (different waveform types)
    assert_ne(pulse[100], cryo[100])

func test_higher_tier_different_pitch():
    var t1 := sfx.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 1)
    var t3 := sfx.generate_tower_fire(Enums.TowerType.PULSE_CANNON, 3)
    # Higher tier = higher harmonics, sounds will differ
    assert_ne(t1[100], t3[100])

func test_generate_enemy_death():
    var samples := sfx.generate_enemy_death(1.0)
    assert_gt(samples.size(), 0)

func test_generate_hero_summon():
    var samples := sfx.generate_hero_summon()
    assert_gt(samples.size(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write implementation**

```gdscript
# core/audio/sfx_generator.gd
class_name SFXGenerator
extends RefCounted

const SAMPLE_RATE := 44100

# Tower base frequencies and waveforms
const TOWER_SFX := {
    Enums.TowerType.PULSE_CANNON: {"wave": "sine", "freq": 880.0, "duration": 0.08},
    Enums.TowerType.ARC_EMITTER: {"wave": "saw", "freq": 660.0, "duration": 0.12},
    Enums.TowerType.CRYO_ARRAY: {"wave": "noise", "freq": 0.0, "duration": 0.15},
    Enums.TowerType.MISSILE_POD: {"wave": "square", "freq": 220.0, "duration": 0.2},
    Enums.TowerType.BEAM_SPIRE: {"wave": "sine", "freq": 1100.0, "duration": 0.3},
    Enums.TowerType.NANO_HIVE: {"wave": "sine", "freq": 1320.0, "duration": 0.1},
    Enums.TowerType.HARVESTER: {"wave": "square", "freq": 990.0, "duration": 0.06},
}


func generate_tower_fire(tower_type: Enums.TowerType, tier: int) -> PackedFloat32Array:
    var config: Dictionary = TOWER_SFX.get(tower_type, TOWER_SFX[Enums.TowerType.PULSE_CANNON])
    var freq: float = config.freq * (1.0 + (tier - 1) * 0.15)
    var duration: float = config.duration

    var samples: PackedFloat32Array
    match config.wave:
        "sine":
            samples = SynthEngine.generate_sine(freq, duration, SAMPLE_RATE)
        "square":
            samples = SynthEngine.generate_square(freq, duration, SAMPLE_RATE)
        "saw":
            samples = SynthEngine.generate_saw(freq, duration, SAMPLE_RATE)
        "noise":
            samples = SynthEngine.generate_noise(duration, SAMPLE_RATE)
            samples = SynthEngine.apply_filter_lowpass(samples, 2000.0, SAMPLE_RATE)
        _:
            samples = SynthEngine.generate_sine(freq, duration, SAMPLE_RATE)

    # Add harmonics for higher tiers
    if tier > 1 and config.wave != "noise":
        var harmonic := SynthEngine.generate_sine(freq * 2.0, duration, SAMPLE_RATE)
        samples = SynthEngine.mix(samples, harmonic, 0.7, 0.3 * (tier - 1) * 0.15)

    samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.6, 0.03, SAMPLE_RATE)
    return samples


func generate_enemy_death(size_scale: float) -> PackedFloat32Array:
    var freq := 440.0 / size_scale
    var samples := SynthEngine.generate_noise(0.15, SAMPLE_RATE)
    var tone := SynthEngine.generate_sine(freq, 0.15, SAMPLE_RATE)
    samples = SynthEngine.mix(samples, tone, 0.5, 0.5)
    samples = SynthEngine.apply_adsr(samples, 0.001, 0.03, 0.3, 0.05, SAMPLE_RATE)
    return samples


func generate_hero_summon() -> PackedFloat32Array:
    var duration := 0.5
    var rising := SynthEngine.generate_sine(440.0, duration, SAMPLE_RATE)
    # Pitch sweep up
    var count := int(duration * SAMPLE_RATE)
    for i in range(count):
        var t := float(i) / SAMPLE_RATE
        var freq := 440.0 + t * 880.0
        rising[i] = sin(TAU * freq * t) * 0.8
    rising = SynthEngine.apply_adsr(rising, 0.05, 0.1, 0.8, 0.15, SAMPLE_RATE)
    return rising


func generate_ability_activate() -> PackedFloat32Array:
    var samples := SynthEngine.generate_sine(660.0, 0.2, SAMPLE_RATE)
    var high := SynthEngine.generate_sine(1320.0, 0.2, SAMPLE_RATE)
    samples = SynthEngine.mix(samples, high, 0.6, 0.4)
    samples = SynthEngine.apply_adsr(samples, 0.01, 0.05, 0.5, 0.08, SAMPLE_RATE)
    return samples
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat: implement SFXGenerator with per-tower procedural sounds"
```

---

### Task 4: Implement AudioManager Singleton

**Files:**
- Create: `core/audio/audio_manager.gd`

- [ ] **Step 1: Write implementation**

```gdscript
# core/audio/audio_manager.gd
class_name AudioManager
extends Node

var music_system: MusicSystem
var sfx_generator: SFXGenerator
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8
var _sfx_cache: Dictionary = {}


func _ready() -> void:
    music_system = MusicSystem.new()
    add_child(music_system)
    sfx_generator = SFXGenerator.new()

    # Create SFX player pool
    for i in range(_sfx_pool_size):
        var player := AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        _sfx_players.append(player)


func set_music_region(region: int) -> void:
    music_system.set_region(region)


func set_music_state(state: Enums.GameState) -> void:
    music_system.set_game_state(state)


func set_boss_music(active: bool) -> void:
    music_system.set_boss_active(active)


func play_tower_fire(tower_type: Enums.TowerType, tier: int) -> void:
    var key := "%d_%d" % [tower_type, tier]
    if key not in _sfx_cache:
        _sfx_cache[key] = _samples_to_stream(sfx_generator.generate_tower_fire(tower_type, tier))
    _play_sfx(_sfx_cache[key])


func play_enemy_death(size_scale: float) -> void:
    var stream := _samples_to_stream(sfx_generator.generate_enemy_death(size_scale))
    _play_sfx(stream)


func play_hero_summon() -> void:
    var stream := _samples_to_stream(sfx_generator.generate_hero_summon())
    _play_sfx(stream)


func play_ability_activate() -> void:
    var stream := _samples_to_stream(sfx_generator.generate_ability_activate())
    _play_sfx(stream)


func set_music_volume(vol: float) -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(vol))


func set_sfx_volume(vol: float) -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(vol))


func _play_sfx(stream: AudioStream) -> void:
    for player in _sfx_players:
        if not player.playing:
            player.stream = stream
            player.play()
            return
    # All players busy — skip this sound (prevent overlap)


func _samples_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SFXGenerator.SAMPLE_RATE
    stream.stereo = false

    var byte_data := PackedByteArray()
    byte_data.resize(samples.size() * 2)
    for i in range(samples.size()):
        var value := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
        byte_data[i * 2] = value & 0xFF
        byte_data[i * 2 + 1] = (value >> 8) & 0xFF
    stream.data = byte_data
    return stream
```

- [ ] **Step 2: Register as autoload**

Add to `project.godot` `[autoload]`:
```ini
AudioManager="*res://core/audio/audio_manager.gd"
```

- [ ] **Step 3: Create audio buses in Godot editor**

Add buses: "Music", "SFX", "UI" in the Audio bus layout.

- [ ] **Step 4: Commit**

```bash
git add core/audio/audio_manager.gd project.godot
git commit -m "feat: implement AudioManager singleton with SFX pool and music control"
```
