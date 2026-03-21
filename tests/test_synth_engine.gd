extends GutTest

## Tests for core/audio/synth_engine.gd

const SAMPLE_RATE := 44100
const FREQ := 440.0
const DURATION := 0.1


func test_generate_sine_length() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	assert_eq(samples.size(), int(DURATION * SAMPLE_RATE))


func test_generate_sine_range() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	for i in samples.size():
		assert_true(samples[i] >= -1.0 and samples[i] <= 1.0,
			"Sine sample %d out of range: %f" % [i, samples[i]])


func test_generate_sine_starts_near_zero() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	assert_almost_eq(samples[0], 0.0, 0.001)


func test_generate_square_length() -> void:
	var samples := SynthEngine.generate_square(FREQ, DURATION, SAMPLE_RATE)
	assert_eq(samples.size(), int(DURATION * SAMPLE_RATE))


func test_generate_square_values() -> void:
	var samples := SynthEngine.generate_square(FREQ, DURATION, SAMPLE_RATE)
	for i in samples.size():
		assert_true(
			is_equal_approx(samples[i], 1.0) or is_equal_approx(samples[i], -1.0),
			"Square wave should only contain 1.0 or -1.0, got %f at %d" % [samples[i], i]
		)


func test_generate_saw_length() -> void:
	var samples := SynthEngine.generate_saw(FREQ, DURATION, SAMPLE_RATE)
	assert_eq(samples.size(), int(DURATION * SAMPLE_RATE))


func test_generate_saw_range() -> void:
	var samples := SynthEngine.generate_saw(FREQ, DURATION, SAMPLE_RATE)
	for i in samples.size():
		assert_true(samples[i] >= -1.0 and samples[i] <= 1.0,
			"Saw sample %d out of range: %f" % [i, samples[i]])


func test_generate_noise_length() -> void:
	var samples := SynthEngine.generate_noise(DURATION, SAMPLE_RATE)
	assert_eq(samples.size(), int(DURATION * SAMPLE_RATE))


func test_generate_noise_range() -> void:
	var samples := SynthEngine.generate_noise(DURATION, SAMPLE_RATE)
	for i in samples.size():
		assert_true(samples[i] >= -1.0 and samples[i] <= 1.0,
			"Noise sample %d out of range: %f" % [i, samples[i]])


func test_generate_noise_has_variation() -> void:
	var samples := SynthEngine.generate_noise(DURATION, SAMPLE_RATE)
	# Noise should not be constant
	var first := samples[0]
	var all_same := true
	for i in minf(samples.size(), 100):
		if not is_equal_approx(samples[i], first):
			all_same = false
			break
	assert_false(all_same, "Noise should have variation")


func test_apply_adsr_length_preserved() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	var enveloped := SynthEngine.apply_adsr(samples, 0.01, 0.02, 0.7, 0.03, SAMPLE_RATE)
	assert_eq(enveloped.size(), samples.size())


func test_apply_adsr_starts_near_zero() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	var enveloped := SynthEngine.apply_adsr(samples, 0.02, 0.02, 0.7, 0.02, SAMPLE_RATE)
	assert_almost_eq(enveloped[0], 0.0, 0.01)


func test_apply_adsr_ends_near_zero() -> void:
	var samples := SynthEngine.generate_sine(FREQ, DURATION, SAMPLE_RATE)
	var enveloped := SynthEngine.apply_adsr(samples, 0.01, 0.02, 0.7, 0.04, SAMPLE_RATE)
	var last := enveloped[enveloped.size() - 1]
	assert_almost_eq(last, 0.0, 0.05)


func test_mix_length() -> void:
	var a := SynthEngine.generate_sine(440.0, DURATION, SAMPLE_RATE)
	var b := SynthEngine.generate_sine(880.0, DURATION, SAMPLE_RATE)
	var mixed := SynthEngine.mix(a, b, 0.5, 0.5)
	assert_eq(mixed.size(), a.size())


func test_mix_clamped() -> void:
	var a := SynthEngine.generate_sine(440.0, DURATION, SAMPLE_RATE)
	var b := SynthEngine.generate_sine(440.0, DURATION, SAMPLE_RATE)
	# Full volume on both — sum can exceed 1 before clamping
	var mixed := SynthEngine.mix(a, b, 1.0, 1.0)
	for i in mixed.size():
		assert_true(mixed[i] >= -1.0 and mixed[i] <= 1.0,
			"Mix should be clamped, got %f at %d" % [mixed[i], i])


func test_apply_filter_lowpass_length() -> void:
	var samples := SynthEngine.generate_noise(DURATION, SAMPLE_RATE)
	var filtered := SynthEngine.apply_filter_lowpass(samples, 1000.0, SAMPLE_RATE)
	assert_eq(filtered.size(), samples.size())


func test_apply_filter_lowpass_attenuates() -> void:
	# High frequency noise filtered at very low cutoff should have smaller RMS than unfiltered
	var samples := SynthEngine.generate_noise(0.5, SAMPLE_RATE)
	var filtered := SynthEngine.apply_filter_lowpass(samples, 100.0, SAMPLE_RATE)

	var rms_orig := 0.0
	var rms_filt := 0.0
	for i in samples.size():
		rms_orig += samples[i] * samples[i]
		rms_filt += filtered[i] * filtered[i]
	rms_orig = sqrt(rms_orig / samples.size())
	rms_filt = sqrt(rms_filt / filtered.size())

	assert_true(rms_filt < rms_orig, "Lowpass filter should reduce RMS of noise")
