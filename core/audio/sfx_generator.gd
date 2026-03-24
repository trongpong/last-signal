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


func generate_tower_place() -> AudioStreamWAV:
	var samples := SynthEngine.generate_square(180.0, 0.12, SAMPLE_RATE)
	samples = SynthEngine.apply_filter_lowpass(samples, 400.0, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.5, 0.04, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_tower_upgrade(tier: int) -> AudioStreamWAV:
	var base_freq := 440.0 + (tier - 1) * 110.0
	var target_freq := base_freq * 1.5
	var step1 := _generate_sweep(base_freq, target_freq, 0.15)
	var step2 := _generate_sweep(target_freq, target_freq * 1.33, 0.1)
	var samples := PackedFloat32Array()
	samples.append_array(step1)
	samples.append_array(step2)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.8, 0.03, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_tower_sell() -> AudioStreamWAV:
	var samples := _generate_sweep_square(180.0, 100.0, 0.1)
	samples = SynthEngine.apply_filter_lowpass(samples, 400.0, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.4, 0.03, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_enemy_hit() -> AudioStreamWAV:
	var samples := SynthEngine.generate_noise(0.03, SAMPLE_RATE)
	samples = SynthEngine.apply_filter_lowpass(samples, 300.0, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.001, 0.005, 0.3, 0.01, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_enemy_escape(escalation: float) -> AudioStreamWAV:
	var duration := 0.15 + escalation * 0.15
	var samples := _generate_sweep(600.0, 200.0, duration)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.6, duration * 0.3, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_wave_start(escalation: float) -> AudioStreamWAV:
	var duration := 0.1 + escalation * 0.3
	var base := SynthEngine.generate_saw(330.0, duration, SAMPLE_RATE)
	if escalation > 0.3:
		var mid := SynthEngine.generate_saw(440.0, duration, SAMPLE_RATE)
		base = SynthEngine.mix(base, mid, 1.0, escalation)
	if escalation > 0.6:
		var high := SynthEngine.generate_saw(550.0, duration, SAMPLE_RATE)
		base = SynthEngine.mix(base, high, 1.0, escalation * 0.7)
	var attack := 0.005 + escalation * 0.04
	base = SynthEngine.apply_adsr(base, attack, 0.02, 0.7, duration * 0.3, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(base, SAMPLE_RATE)


func generate_wave_complete(escalation: float) -> AudioStreamWAV:
	var duration := 0.2 + escalation * 0.3
	var note1 := SynthEngine.generate_sine(440.0, duration, SAMPLE_RATE)
	var note2 := SynthEngine.generate_sine(550.0, duration, SAMPLE_RATE)
	var samples := SynthEngine.mix(note1, note2, 0.7, 0.7)
	if escalation > 0.5:
		var note3 := SynthEngine.generate_sine(660.0, duration, SAMPLE_RATE)
		samples = SynthEngine.mix(samples, note3, 1.0, escalation * 0.6)
	samples = SynthEngine.apply_adsr(samples, 0.01, 0.03, 0.7, duration * 0.4, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_lives_lost(escalation: float) -> AudioStreamWAV:
	var duration := 0.1 + escalation * 0.2
	var tone := SynthEngine.generate_square(150.0, duration, SAMPLE_RATE)
	var noise := SynthEngine.generate_noise(duration, SAMPLE_RATE)
	noise = SynthEngine.apply_filter_lowpass(noise, 500.0, SAMPLE_RATE)
	var samples := SynthEngine.mix(tone, noise, 0.7, 0.5)
	if escalation > 0.5:
		var sub := SynthEngine.generate_sine(60.0, duration, SAMPLE_RATE)
		samples = SynthEngine.mix(samples, sub, 1.0, escalation * 0.6)
	samples = SynthEngine.apply_adsr(samples, 0.002, 0.02, 0.5, duration * 0.4, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_victory(escalation: float) -> AudioStreamWAV:
	var freqs := [523.25, 659.25, 783.99, 1046.50]
	var note_dur := 0.12 + escalation * 0.12
	var samples := PackedFloat32Array()
	for freq in freqs:
		var note := SynthEngine.generate_sine(freq, note_dur, SAMPLE_RATE)
		if escalation > 0.5:
			var harm := SynthEngine.generate_saw(freq, note_dur, SAMPLE_RATE)
			note = SynthEngine.mix(note, harm, 0.8, escalation * 0.3)
		note = SynthEngine.apply_adsr(note, 0.005, 0.02, 0.8, note_dur * 0.3, SAMPLE_RATE)
		samples.append_array(note)
	if escalation > 0.5:
		var tail := SynthEngine.generate_sine(1046.50, escalation * 0.5, SAMPLE_RATE)
		tail = SynthEngine.apply_adsr(tail, 0.01, 0.05, 0.6, escalation * 0.3, SAMPLE_RATE)
		samples.append_array(tail)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_defeat(escalation: float) -> AudioStreamWAV:
	var freqs := [261.63, 220.00, 174.61]
	var note_dur := 0.15 + escalation * 0.15
	var cutoff := 800.0
	var samples := PackedFloat32Array()
	for freq in freqs:
		var note := SynthEngine.generate_sine(freq, note_dur, SAMPLE_RATE)
		note = SynthEngine.apply_filter_lowpass(note, cutoff, SAMPLE_RATE)
		note = SynthEngine.apply_adsr(note, 0.01, 0.03, 0.7, note_dur * 0.3, SAMPLE_RATE)
		samples.append_array(note)
		cutoff *= 0.7
	if escalation > 0.5:
		var drone_dur := escalation * 1.0
		var e3 := SynthEngine.generate_sine(164.81, drone_dur, SAMPLE_RATE)
		var f3 := SynthEngine.generate_sine(174.61, drone_dur, SAMPLE_RATE)
		var drone := SynthEngine.mix(e3, f3, 0.5, 0.5)
		drone = SynthEngine.apply_filter_lowpass(drone, 200.0, SAMPLE_RATE)
		drone = SynthEngine.apply_adsr(drone, 0.05, 0.1, 0.4, drone_dur * 0.5, SAMPLE_RATE)
		samples.append_array(drone)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_gold_earn() -> AudioStreamWAV:
	var samples := SynthEngine.generate_sine(1200.0, 0.04, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.002, 0.005, 0.6, 0.015, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_gold_spend() -> AudioStreamWAV:
	var samples := _generate_sweep(900.0, 700.0, 0.05)
	samples = SynthEngine.apply_adsr(samples, 0.003, 0.008, 0.5, 0.02, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_diamond_earn() -> AudioStreamWAV:
	var tap1 := SynthEngine.generate_sine(1800.0, 0.03, SAMPLE_RATE)
	tap1 = SynthEngine.apply_adsr(tap1, 0.002, 0.005, 0.7, 0.01, SAMPLE_RATE)
	var gap := PackedFloat32Array()
	gap.resize(int(0.02 * SAMPLE_RATE))
	gap.fill(0.0)
	var tap2 := SynthEngine.generate_sine(2200.0, 0.03, SAMPLE_RATE)
	tap2 = SynthEngine.apply_adsr(tap2, 0.002, 0.005, 0.7, 0.01, SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.append_array(tap1)
	samples.append_array(gap)
	samples.append_array(tap2)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_cannot_afford() -> AudioStreamWAV:
	var samples := SynthEngine.generate_square(120.0, 0.08, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.002, 0.01, 0.4, 0.02, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_ui_click() -> AudioStreamWAV:
	var samples := SynthEngine.generate_sine(800.0, 0.03, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.001, 0.005, 0.6, 0.01, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_ui_hover() -> AudioStreamWAV:
	var samples := SynthEngine.generate_sine(600.0, 0.015, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.001, 0.003, 0.4, 0.005, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_ui_panel_open() -> AudioStreamWAV:
	var samples := SynthEngine.generate_noise(0.1, SAMPLE_RATE)
	var chunk_count := 10
	var chunk_size := samples.size() / chunk_count
	var result := PackedFloat32Array()
	for i in chunk_count:
		var t := float(i) / float(chunk_count)
		var cutoff := 200.0 + t * 600.0
		var start := i * chunk_size
		var end := start + chunk_size if i < chunk_count - 1 else samples.size()
		var chunk := samples.slice(start, end)
		chunk = SynthEngine.apply_filter_lowpass(chunk, cutoff, SAMPLE_RATE)
		result.append_array(chunk)
	result = SynthEngine.apply_adsr(result, 0.005, 0.02, 0.6, 0.03, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(result, SAMPLE_RATE)


func generate_ui_panel_close() -> AudioStreamWAV:
	var samples := SynthEngine.generate_noise(0.08, SAMPLE_RATE)
	var chunk_count := 8
	var chunk_size := samples.size() / chunk_count
	var result := PackedFloat32Array()
	for i in chunk_count:
		var t := float(i) / float(chunk_count)
		var cutoff := 800.0 - t * 600.0
		var start := i * chunk_size
		var end := start + chunk_size if i < chunk_count - 1 else samples.size()
		var chunk := samples.slice(start, end)
		chunk = SynthEngine.apply_filter_lowpass(chunk, cutoff, SAMPLE_RATE)
		result.append_array(chunk)
	result = SynthEngine.apply_adsr(result, 0.003, 0.015, 0.5, 0.025, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(result, SAMPLE_RATE)


func _generate_sweep(freq_start: float, freq_end: float, duration: float) -> PackedFloat32Array:
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / float(sample_count)
		var freq := freq_start + (freq_end - freq_start) * t
		phase += freq / SAMPLE_RATE
		samples[i] = sin(phase * TAU)
	return samples


func _generate_sweep_square(freq_start: float, freq_end: float, duration: float) -> PackedFloat32Array:
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / float(sample_count)
		var freq := freq_start + (freq_end - freq_start) * t
		phase += freq / SAMPLE_RATE
		samples[i] = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
	return samples


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
