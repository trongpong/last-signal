class_name SynthEngine
extends RefCounted

## Procedural audio synthesis engine for Last Signal.
## All functions are static and operate on PackedFloat32Array sample buffers.


static func generate_sine(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
	var num_samples := int(duration * sample_rate)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	var two_pi_freq := 2.0 * PI * freq
	for i in num_samples:
		samples[i] = sin(two_pi_freq * i / sample_rate)
	return samples


static func generate_square(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
	var num_samples := int(duration * sample_rate)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	var period := sample_rate / freq
	for i in num_samples:
		var phase := fmod(float(i), period) / period
		samples[i] = 1.0 if phase < 0.5 else -1.0
	return samples


static func generate_saw(freq: float, duration: float, sample_rate: int) -> PackedFloat32Array:
	var num_samples := int(duration * sample_rate)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	var period := sample_rate / freq
	for i in num_samples:
		var phase := fmod(float(i), period) / period
		samples[i] = 2.0 * phase - 1.0
	return samples


static func generate_noise(duration: float, sample_rate: int) -> PackedFloat32Array:
	var num_samples := int(duration * sample_rate)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	for i in num_samples:
		samples[i] = randf_range(-1.0, 1.0)
	return samples


## Apply ADSR envelope to a sample buffer.
## Returns a new buffer with the envelope applied.
static func apply_adsr(
	samples: PackedFloat32Array,
	attack: float,
	decay: float,
	sustain: float,
	release: float,
	sample_rate: int
) -> PackedFloat32Array:
	var num_samples := samples.size()
	var result := PackedFloat32Array()
	result.resize(num_samples)

	var attack_samples := int(attack * sample_rate)
	var decay_samples := int(decay * sample_rate)
	var release_samples := int(release * sample_rate)
	var sustain_start := attack_samples + decay_samples
	var release_start := num_samples - release_samples

	for i in num_samples:
		var env := 0.0
		if i < attack_samples:
			env = float(i) / maxf(float(attack_samples), 1.0)
		elif i < sustain_start:
			var decay_progress := float(i - attack_samples) / maxf(float(decay_samples), 1.0)
			env = 1.0 - decay_progress * (1.0 - sustain)
		elif i < release_start:
			env = sustain
		else:
			var release_progress := float(i - release_start) / maxf(float(release_samples), 1.0)
			env = sustain * (1.0 - release_progress)
		result[i] = samples[i] * env

	return result


## Mix two sample arrays together with per-array volume scaling.
## Output is clamped to [-1, 1]. Arrays must be the same length.
static func mix(
	a: PackedFloat32Array,
	b: PackedFloat32Array,
	vol_a: float,
	vol_b: float
) -> PackedFloat32Array:
	var num_samples := a.size()
	var result := PackedFloat32Array()
	result.resize(num_samples)
	var b_size := b.size()
	for i in num_samples:
		var sample_b := b[i] if i < b_size else 0.0
		result[i] = clampf(a[i] * vol_a + sample_b * vol_b, -1.0, 1.0)
	return result


## Convert a PackedFloat32Array of samples [-1,1] to an AudioStreamWAV (FORMAT_16_BITS, mono).
static func samples_to_stream(samples: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	var num_samples := samples.size()
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)
	for i in num_samples:
		var int16_val := clampi(int(clampf(samples[i], -1.0, 1.0) * 32767.0), -32768, 32767)
		byte_array[i * 2]     = int16_val & 0xFF
		byte_array[i * 2 + 1] = (int16_val >> 8) & 0xFF
	stream.data = byte_array
	return stream


## Simple single-pole RC lowpass filter.
## cutoff is in Hz.
static func apply_filter_lowpass(
	samples: PackedFloat32Array,
	cutoff: float,
	sample_rate: int
) -> PackedFloat32Array:
	var num_samples := samples.size()
	var result := PackedFloat32Array()
	result.resize(num_samples)

	var rc := 1.0 / (2.0 * PI * cutoff)
	var dt := 1.0 / sample_rate
	var alpha := dt / (rc + dt)

	var prev := 0.0
	for i in num_samples:
		prev = prev + alpha * (samples[i] - prev)
		result[i] = prev

	return result
