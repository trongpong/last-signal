class_name SFXGenerator
extends RefCounted

## Procedural sound effect generator for Last Signal.
## Generates AudioStreamWAV-compatible PackedFloat32Array buffers for all game SFX.

const SAMPLE_RATE := 44100

## Per-tower SFX configuration: {wave, freq, duration}
const TOWER_SFX: Dictionary = {
	Enums.TowerType.PULSE_CANNON: {wave = "sine",   freq = 880.0,  duration = 0.08},
	Enums.TowerType.ARC_EMITTER:  {wave = "saw",    freq = 660.0,  duration = 0.12},
	Enums.TowerType.CRYO_ARRAY:   {wave = "noise",  freq = 0.0,    duration = 0.15},
	Enums.TowerType.MISSILE_POD:  {wave = "square", freq = 220.0,  duration = 0.20},
	Enums.TowerType.BEAM_SPIRE:   {wave = "sine",   freq = 1100.0, duration = 0.30},
	Enums.TowerType.NANO_HIVE:    {wave = "sine",   freq = 1320.0, duration = 0.10},
	Enums.TowerType.HARVESTER:    {wave = "square", freq = 990.0,  duration = 0.06},
}


## Generate a tower fire sound.
## tier (1..n) adds harmonic layers for higher-tier towers.
func generate_tower_fire(tower_type: Enums.TowerType, tier: int) -> PackedFloat32Array:
	if not TOWER_SFX.has(tower_type):
		return PackedFloat32Array()

	var cfg: Dictionary = TOWER_SFX[tower_type]
	var wave: String = cfg.wave
	var freq: float = cfg.freq
	var duration: float = cfg.duration

	var base_samples := _generate_wave(wave, freq, duration)

	# Add harmonics for higher tiers (tier 2 = 2nd harmonic, tier 3 = 3rd, etc.)
	var mixed := base_samples
	if tier >= 2 and freq > 0.0:
		var harmonic_vol := 0.5
		for t in range(2, tier + 1):
			var harmonic := _generate_wave(wave, freq * t, duration)
			mixed = SynthEngine.mix(mixed, harmonic, 1.0, harmonic_vol)
			harmonic_vol *= 0.5

	# ADSR: short attack, short decay, medium sustain, short release
	var attack := minf(0.005, duration * 0.1)
	var decay := minf(0.01, duration * 0.15)
	var sustain := 0.7
	var release := minf(0.02, duration * 0.3)
	return SynthEngine.apply_adsr(mixed, attack, decay, sustain, release, SAMPLE_RATE)


## Generate an enemy death sound based on size (1.0 = normal, >1 = larger/bigger boom).
func generate_enemy_death(size_scale: float) -> PackedFloat32Array:
	var duration := clampf(0.1 * size_scale, 0.05, 0.5)
	var tone_freq := 200.0 / maxf(size_scale, 0.1)

	var noise := SynthEngine.generate_noise(duration, SAMPLE_RATE)
	var tone := SynthEngine.generate_sine(tone_freq, duration, SAMPLE_RATE)

	# Larger enemies have more noise, less tone
	var noise_vol := clampf(0.4 + size_scale * 0.2, 0.4, 0.9)
	var tone_vol := clampf(0.6 - size_scale * 0.1, 0.1, 0.6)
	var mixed := SynthEngine.mix(noise, tone, noise_vol, tone_vol)

	return SynthEngine.apply_adsr(mixed, 0.002, 0.03, 0.3, duration * 0.5, SAMPLE_RATE)


## Generate a hero summon sound — a rising pitch sweep.
func generate_hero_summon() -> PackedFloat32Array:
	var duration := 0.6
	var num_samples := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)

	# Rising sweep from 200 Hz to 1200 Hz
	var freq_start := 200.0
	var freq_end := 1200.0
	var phase := 0.0
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var freq := freq_start + (freq_end - freq_start) * (t / duration)
		phase += 2.0 * PI * freq / SAMPLE_RATE
		samples[i] = sin(phase)

	# Blend with a shimmer harmonic at 2x
	var shimmer := PackedFloat32Array()
	shimmer.resize(num_samples)
	var phase2 := 0.0
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var freq := (freq_start + (freq_end - freq_start) * (t / duration)) * 2.0
		phase2 += 2.0 * PI * freq / SAMPLE_RATE
		shimmer[i] = sin(phase2)

	var mixed := SynthEngine.mix(samples, shimmer, 0.7, 0.3)
	return SynthEngine.apply_adsr(mixed, 0.05, 0.1, 0.8, 0.15, SAMPLE_RATE)


## Generate an ability activation sound — dual sine chord.
func generate_ability_activate() -> PackedFloat32Array:
	var duration := 0.25
	var freq_a := 523.25  # C5
	var freq_b := 783.99  # G5

	var sine_a := SynthEngine.generate_sine(freq_a, duration, SAMPLE_RATE)
	var sine_b := SynthEngine.generate_sine(freq_b, duration, SAMPLE_RATE)
	var mixed := SynthEngine.mix(sine_a, sine_b, 0.6, 0.6)
	return SynthEngine.apply_adsr(mixed, 0.01, 0.05, 0.6, 0.08, SAMPLE_RATE)


func _generate_wave(wave: String, freq: float, duration: float) -> PackedFloat32Array:
	match wave:
		"sine":
			return SynthEngine.generate_sine(freq, duration, SAMPLE_RATE)
		"square":
			return SynthEngine.generate_square(freq, duration, SAMPLE_RATE)
		"saw":
			return SynthEngine.generate_saw(freq, duration, SAMPLE_RATE)
		"noise":
			return SynthEngine.generate_noise(duration, SAMPLE_RATE)
		_:
			return SynthEngine.generate_noise(duration, SAMPLE_RATE)
