# Audio Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand audio coverage from ~7% to near-complete with procedural SFX, an escalation system, and an event-driven audio router.

**Architecture:** New AudioEventRouter node listens to existing game signals and translates them into AudioManager play calls. SFXGenerator gains ~20 new procedural sound methods. Escalation factor (0.0–1.0) scales drama based on wave progression.

**Tech Stack:** Godot 4.6 GDScript, procedural audio via SynthEngine (sine/square/saw/noise + ADSR + lowpass), GUT test framework.

**Spec:** `docs/superpowers/specs/2026-03-24-audio-improvements-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `core/audio/audio_event_router.gd` | Listens to game signals, computes escalation, calls AudioManager play methods |
| `tests/test_audio_event_router.gd` | Tests for router: escalation calc, rate limiting, signal handling |
| `tests/test_audio_manager.gd` | Tests for AudioManager: pool size, new play methods, volume control |

### Modified Files
| File | Changes |
|------|---------|
| `core/audio/sfx_generator.gd` | Add ~20 new generate methods (gameplay, economy, UI, minigame) |
| `core/audio/audio_manager.gd` | Pool 8→12, volume param on `_play_sfx`, ~25 new play methods, instantiate router |
| `scenes/game.gd` | Add audio calls for tower place/upgrade/sell, enemy hit/escape, cannot-afford |
| `core/game_loop.gd` | Call `AudioManager.event_router.setup()`, suppress economy audio on reset |
| `ui/hud/signal_decode_minigame.gd` | Add glyph tone, correct/wrong, success/fail audio |
| `tests/test_sfx_generator.gd` | Add tests for all new generate methods |
| `tests/test_music_system.gd` | Add intensity escalation tests |
| 19 UI files (see Task 10) | Add `AudioManager.play_ui_click()` to button handlers |

### Untouched Files
- `core/audio/synth_engine.gd`
- `core/audio/music_layer.gd`
- `core/audio/music_system.gd`

---

## Task 1: SFXGenerator — Tower & Enemy Sounds

**Files:**
- Modify: `core/audio/sfx_generator.gd` (add methods after line 107)
- Modify: `tests/test_sfx_generator.gd` (add tests after line 153)

**Reference:** Spec Section 3 — Tower Interactions & Enemy Feedback

- [ ] **Step 1: Write failing tests for tower sounds**

Add to `tests/test_sfx_generator.gd` after the existing tests:

```gdscript
# --- Tower interaction sounds ---

func test_generate_tower_place_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_place()
	assert_not_null(stream, "tower_place should return a stream")
	assert_gt(stream.data.size(), 0, "tower_place should have audio data")

func test_generate_tower_upgrade_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_upgrade(1)
	assert_not_null(stream, "tower_upgrade should return a stream")
	assert_gt(stream.data.size(), 0, "tower_upgrade should have audio data")

func test_generate_tower_upgrade_pitch_increases_with_tier() -> void:
	var stream_t1 := _gen.generate_tower_upgrade(1)
	var stream_t2 := _gen.generate_tower_upgrade(2)
	var stream_t3 := _gen.generate_tower_upgrade(3)
	# Higher tiers produce more data (longer duration from higher starting pitch sweep)
	# or at minimum different data
	assert_ne(stream_t1.data, stream_t2.data, "tier 1 and 2 should differ")
	assert_ne(stream_t2.data, stream_t3.data, "tier 2 and 3 should differ")

func test_generate_tower_sell_returns_valid_stream() -> void:
	var stream := _gen.generate_tower_sell()
	assert_not_null(stream, "tower_sell should return a stream")
	assert_gt(stream.data.size(), 0, "tower_sell should have audio data")

func test_generate_enemy_hit_returns_valid_stream() -> void:
	var stream := _gen.generate_enemy_hit()
	assert_not_null(stream, "enemy_hit should return a stream")
	assert_gt(stream.data.size(), 0, "enemy_hit should have audio data")

func test_generate_enemy_escape_returns_valid_stream() -> void:
	var stream := _gen.generate_enemy_escape(0.0)
	assert_not_null(stream, "enemy_escape should return a stream")
	assert_gt(stream.data.size(), 0, "enemy_escape should have audio data")

func test_generate_enemy_escape_scales_with_escalation() -> void:
	var stream_low := _gen.generate_enemy_escape(0.0)
	var stream_high := _gen.generate_enemy_escape(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation should produce longer sound")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: Set `"selected": "res://tests/test_sfx_generator.gd"` in `.gutconfig.json` and run GUT.
Expected: FAIL — methods `generate_tower_place`, `generate_tower_upgrade`, `generate_tower_sell`, `generate_enemy_hit`, `generate_enemy_escape` do not exist.

- [ ] **Step 3: Implement tower & enemy sound generation**

Add to `core/audio/sfx_generator.gd` after the `_generate_wave` method (after line 121):

```gdscript
func generate_tower_place() -> AudioStreamWAV:
	var samples := SynthEngine.generate_square(180.0, 0.12, SAMPLE_RATE)
	samples = SynthEngine.apply_filter_lowpass(samples, 400.0, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.5, 0.04, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_tower_upgrade(tier: int) -> AudioStreamWAV:
	var base_freq := 440.0 + (tier - 1) * 110.0
	var target_freq := base_freq * 1.5
	# Two-step chirp: sweep up, then sweep up again
	var step1 := _generate_sweep(base_freq, target_freq, 0.15)
	var step2 := _generate_sweep(target_freq, target_freq * 1.33, 0.1)
	# Concatenate steps
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


## Generates a sine frequency sweep from freq_start to freq_end over duration.
## Uses sample-by-sample phase accumulation (same pattern as generate_hero_summon).
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


## Generates a square wave frequency sweep from freq_start to freq_end over duration.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: GUT with `test_sfx_generator.gd` selected.
Expected: All new tests PASS. All existing tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat(audio): add tower & enemy sound generation with TDD"
```

---

## Task 2: SFXGenerator — Escalation Sounds (Wave Events & Stingers)

**Files:**
- Modify: `core/audio/sfx_generator.gd` (append after Task 1 additions)
- Modify: `tests/test_sfx_generator.gd` (append tests)

**Reference:** Spec Section 2 (escalation) & Section 3 (wave events, stingers)

- [ ] **Step 1: Write failing tests for escalation sounds**

Add to `tests/test_sfx_generator.gd`:

```gdscript
# --- Wave event sounds ---

func test_generate_wave_start_returns_valid_stream() -> void:
	var stream := _gen.generate_wave_start(0.0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_wave_start_scales_with_escalation() -> void:
	var stream_low := _gen.generate_wave_start(0.0)
	var stream_high := _gen.generate_wave_start(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation wave start should be longer")

func test_generate_wave_complete_returns_valid_stream() -> void:
	var stream := _gen.generate_wave_complete(0.0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_wave_complete_scales_with_escalation() -> void:
	var stream_low := _gen.generate_wave_complete(0.0)
	var stream_high := _gen.generate_wave_complete(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation wave complete should be longer")

func test_generate_lives_lost_returns_valid_stream() -> void:
	var stream := _gen.generate_lives_lost(0.0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_lives_lost_scales_with_escalation() -> void:
	var stream_low := _gen.generate_lives_lost(0.0)
	var stream_high := _gen.generate_lives_lost(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation lives_lost should be longer")

# --- Stingers ---

func test_generate_victory_returns_valid_stream() -> void:
	var stream := _gen.generate_victory(0.0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_victory_scales_with_escalation() -> void:
	var stream_low := _gen.generate_victory(0.0)
	var stream_high := _gen.generate_victory(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation victory should be longer")

func test_generate_defeat_returns_valid_stream() -> void:
	var stream := _gen.generate_defeat(0.0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_defeat_scales_with_escalation() -> void:
	var stream_low := _gen.generate_defeat(0.0)
	var stream_high := _gen.generate_defeat(1.0)
	assert_gt(stream_high.data.size(), stream_low.data.size(),
		"high escalation defeat should be longer")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: GUT with `test_sfx_generator.gd` selected.
Expected: FAIL — methods do not exist.

- [ ] **Step 3: Implement escalation sound generation**

Add to `core/audio/sfx_generator.gd`:

```gdscript
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
	# Ascending arpeggio: C5, E5, G5, C6
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
	# Extend final note at high escalation
	if escalation > 0.5:
		var tail := SynthEngine.generate_sine(1046.50, escalation * 0.5, SAMPLE_RATE)
		tail = SynthEngine.apply_adsr(tail, 0.01, 0.05, 0.6, escalation * 0.3, SAMPLE_RATE)
		samples.append_array(tail)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_defeat(escalation: float) -> AudioStreamWAV:
	# Descending: C4, A3, F3
	var freqs := [261.63, 220.00, 174.61]
	var note_dur := 0.15 + escalation * 0.15
	var cutoff := 800.0
	var samples := PackedFloat32Array()
	for freq in freqs:
		var note := SynthEngine.generate_sine(freq, note_dur, SAMPLE_RATE)
		note = SynthEngine.apply_filter_lowpass(note, cutoff, SAMPLE_RATE)
		note = SynthEngine.apply_adsr(note, 0.01, 0.03, 0.7, note_dur * 0.3, SAMPLE_RATE)
		samples.append_array(note)
		cutoff *= 0.7  # Tighten lowpass each note
	# Dissonant drone tail at high escalation
	if escalation > 0.5:
		var drone_dur := escalation * 1.0
		var e3 := SynthEngine.generate_sine(164.81, drone_dur, SAMPLE_RATE)
		var f3 := SynthEngine.generate_sine(174.61, drone_dur, SAMPLE_RATE)
		var drone := SynthEngine.mix(e3, f3, 0.5, 0.5)
		drone = SynthEngine.apply_filter_lowpass(drone, 200.0, SAMPLE_RATE)
		drone = SynthEngine.apply_adsr(drone, 0.05, 0.1, 0.4, drone_dur * 0.5, SAMPLE_RATE)
		samples.append_array(drone)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: GUT with `test_sfx_generator.gd` selected.
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat(audio): add escalation wave events & stinger generation"
```

---

## Task 3: SFXGenerator — Economy Sounds

**Files:**
- Modify: `core/audio/sfx_generator.gd`
- Modify: `tests/test_sfx_generator.gd`

**Reference:** Spec Section 4 — Economy Sounds

- [ ] **Step 1: Write failing tests**

Add to `tests/test_sfx_generator.gd`:

```gdscript
# --- Economy sounds ---

func test_generate_gold_earn_returns_valid_stream() -> void:
	var stream := _gen.generate_gold_earn()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_gold_spend_returns_valid_stream() -> void:
	var stream := _gen.generate_gold_spend()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_diamond_earn_returns_valid_stream() -> void:
	var stream := _gen.generate_diamond_earn()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_cannot_afford_returns_valid_stream() -> void:
	var stream := _gen.generate_cannot_afford()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — methods do not exist.

- [ ] **Step 3: Implement economy sound generation**

Add to `core/audio/sfx_generator.gd`:

```gdscript
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
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat(audio): add economy sound generation (gold, diamonds, cannot afford)"
```

---

## Task 4: SFXGenerator — UI Sounds

**Files:**
- Modify: `core/audio/sfx_generator.gd`
- Modify: `tests/test_sfx_generator.gd`

**Reference:** Spec Section 4 — UI Sounds

- [ ] **Step 1: Write failing tests**

Add to `tests/test_sfx_generator.gd`:

```gdscript
# --- UI sounds ---

func test_generate_ui_click_returns_valid_stream() -> void:
	var stream := _gen.generate_ui_click()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_ui_hover_returns_valid_stream() -> void:
	var stream := _gen.generate_ui_hover()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_ui_panel_open_returns_valid_stream() -> void:
	var stream := _gen.generate_ui_panel_open()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_ui_panel_close_returns_valid_stream() -> void:
	var stream := _gen.generate_ui_panel_close()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — methods do not exist.

- [ ] **Step 3: Implement UI sound generation**

Add to `core/audio/sfx_generator.gd`:

```gdscript
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
	# Sweep lowpass from 200 to 800 Hz by processing in chunks
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
	# Sweep lowpass from 800 to 200 Hz (reverse of open)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat(audio): add UI sound generation (click, hover, panel open/close)"
```

---

## Task 5: SFXGenerator — Minigame Sounds

**Files:**
- Modify: `core/audio/sfx_generator.gd`
- Modify: `tests/test_sfx_generator.gd`

**Reference:** Spec Section 4 — Signal Decode Minigame

- [ ] **Step 1: Write failing tests**

Add to `tests/test_sfx_generator.gd`:

```gdscript
# --- Minigame sounds ---

func test_generate_glyph_tone_returns_valid_stream() -> void:
	var stream := _gen.generate_glyph_tone(0)
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_glyph_tone_different_per_index() -> void:
	var stream0 := _gen.generate_glyph_tone(0)
	var stream1 := _gen.generate_glyph_tone(1)
	var stream2 := _gen.generate_glyph_tone(2)
	assert_ne(stream0.data, stream1.data, "glyph 0 and 1 should differ")
	assert_ne(stream1.data, stream2.data, "glyph 1 and 2 should differ")

func test_generate_glyph_tone_wraps_with_modulo() -> void:
	var stream0 := _gen.generate_glyph_tone(0)
	var stream5 := _gen.generate_glyph_tone(5)
	assert_eq(stream0.data, stream5.data, "index 5 should wrap to same as index 0")

func test_generate_decode_correct_returns_valid_stream() -> void:
	var stream := _gen.generate_decode_correct()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_decode_wrong_returns_valid_stream() -> void:
	var stream := _gen.generate_decode_wrong()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_decode_success_returns_valid_stream() -> void:
	var stream := _gen.generate_decode_success()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_generate_decode_fail_returns_valid_stream() -> void:
	var stream := _gen.generate_decode_fail()
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — methods do not exist.

- [ ] **Step 3: Implement minigame sound generation**

Add to `core/audio/sfx_generator.gd`:

```gdscript
const PENTATONIC_SCALE := [523.25, 587.33, 698.46, 783.99, 880.00]


func generate_glyph_tone(glyph_index: int) -> AudioStreamWAV:
	var freq := PENTATONIC_SCALE[glyph_index % PENTATONIC_SCALE.size()]
	var samples := SynthEngine.generate_sine(freq, 0.1, SAMPLE_RATE)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.015, 0.7, 0.03, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_decode_correct() -> AudioStreamWAV:
	# Glyph's tone + a fifth above (generic, not per-glyph — caller can use glyph_tone instead)
	var base := SynthEngine.generate_sine(660.0, 0.08, SAMPLE_RATE)
	var fifth := SynthEngine.generate_sine(990.0, 0.08, SAMPLE_RATE)
	var samples := SynthEngine.mix(base, fifth, 0.6, 0.3)
	samples = SynthEngine.apply_adsr(samples, 0.003, 0.01, 0.6, 0.02, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_decode_wrong() -> AudioStreamWAV:
	var tone1 := SynthEngine.generate_square(200.0, 0.1, SAMPLE_RATE)
	var tone2 := SynthEngine.generate_square(215.0, 0.1, SAMPLE_RATE)
	var samples := SynthEngine.mix(tone1, tone2, 0.5, 0.5)
	samples = SynthEngine.apply_adsr(samples, 0.002, 0.01, 0.5, 0.03, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_decode_success() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for freq in PENTATONIC_SCALE:
		var note := SynthEngine.generate_sine(freq, 0.04, SAMPLE_RATE)
		note = SynthEngine.apply_adsr(note, 0.002, 0.005, 0.7, 0.01, SAMPLE_RATE)
		samples.append_array(note)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)


func generate_decode_fail() -> AudioStreamWAV:
	var samples := _generate_sweep(400.0, 200.0, 0.15)
	# Use saw-like character by mixing with saw
	var saw := SynthEngine.generate_saw(300.0, 0.15, SAMPLE_RATE)
	samples = SynthEngine.mix(samples, saw, 0.7, 0.3)
	samples = SynthEngine.apply_adsr(samples, 0.005, 0.02, 0.5, 0.05, SAMPLE_RATE)
	return SynthEngine.samples_to_stream(samples, SAMPLE_RATE)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/audio/sfx_generator.gd tests/test_sfx_generator.gd
git commit -m "feat(audio): add minigame sound generation (glyph tones, decode feedback)"
```

---

## Task 6: AudioManager — Volume Control, New Play Methods, Pool Size

**Files:**
- Modify: `core/audio/audio_manager.gd`
- Create: `tests/test_audio_manager.gd`

**Reference:** Spec Section 1 — AudioManager Public Methods & Per-Sound Volume Control

- [ ] **Step 1: Write failing tests for AudioManager**

Create `tests/test_audio_manager.gd`:

```gdscript
extends GutTest

var _manager: Node


func before_each() -> void:
	_manager = load("res://core/audio/audio_manager.gd").new()
	add_child_autofree(_manager)


func test_sfx_pool_size_is_twelve() -> void:
	# Pool is created in _ready, count SFX AudioStreamPlayer children
	# Note: _bg_player is only created on-demand, not in _ready, so count == pool size
	var count := 0
	for child in _manager.get_children():
		if child is AudioStreamPlayer:
			count += 1
	assert_eq(count, 12, "SFX pool should have 12 players")


func test_play_sfx_accepts_volume_parameter() -> void:
	# Verify _play_sfx signature accepts volume — calling with volume should not error
	var stream := _manager._sfx_gen.generate_ui_click()
	# This should not crash
	_manager._play_sfx(stream, 0.5)
	pass_test("_play_sfx accepts volume parameter")


func test_play_tower_place_exists() -> void:
	assert_true(_manager.has_method("play_tower_place"), "play_tower_place should exist")

func test_play_tower_upgrade_exists() -> void:
	assert_true(_manager.has_method("play_tower_upgrade"), "play_tower_upgrade should exist")

func test_play_tower_sell_exists() -> void:
	assert_true(_manager.has_method("play_tower_sell"), "play_tower_sell should exist")

func test_play_enemy_hit_exists() -> void:
	assert_true(_manager.has_method("play_enemy_hit"), "play_enemy_hit should exist")

func test_play_enemy_escape_exists() -> void:
	assert_true(_manager.has_method("play_enemy_escape"), "play_enemy_escape should exist")

func test_play_wave_start_exists() -> void:
	assert_true(_manager.has_method("play_wave_start"), "play_wave_start should exist")

func test_play_wave_complete_exists() -> void:
	assert_true(_manager.has_method("play_wave_complete"), "play_wave_complete should exist")

func test_play_lives_lost_exists() -> void:
	assert_true(_manager.has_method("play_lives_lost"), "play_lives_lost should exist")

func test_play_victory_exists() -> void:
	assert_true(_manager.has_method("play_victory"), "play_victory should exist")

func test_play_defeat_exists() -> void:
	assert_true(_manager.has_method("play_defeat"), "play_defeat should exist")

func test_play_gold_earn_exists() -> void:
	assert_true(_manager.has_method("play_gold_earn"), "play_gold_earn should exist")

func test_play_gold_spend_exists() -> void:
	assert_true(_manager.has_method("play_gold_spend"), "play_gold_spend should exist")

func test_play_diamond_earn_exists() -> void:
	assert_true(_manager.has_method("play_diamond_earn"), "play_diamond_earn should exist")

func test_play_cannot_afford_exists() -> void:
	assert_true(_manager.has_method("play_cannot_afford"), "play_cannot_afford should exist")

func test_play_ui_click_exists() -> void:
	assert_true(_manager.has_method("play_ui_click"), "play_ui_click should exist")

func test_play_ui_hover_exists() -> void:
	assert_true(_manager.has_method("play_ui_hover"), "play_ui_hover should exist")

func test_play_ui_panel_open_exists() -> void:
	assert_true(_manager.has_method("play_ui_panel_open"), "play_ui_panel_open should exist")

func test_play_ui_panel_close_exists() -> void:
	assert_true(_manager.has_method("play_ui_panel_close"), "play_ui_panel_close should exist")

func test_play_glyph_tone_exists() -> void:
	assert_true(_manager.has_method("play_glyph_tone"), "play_glyph_tone should exist")

func test_play_decode_correct_exists() -> void:
	assert_true(_manager.has_method("play_decode_correct"), "play_decode_correct should exist")

func test_play_decode_wrong_exists() -> void:
	assert_true(_manager.has_method("play_decode_wrong"), "play_decode_wrong should exist")

func test_play_decode_success_exists() -> void:
	assert_true(_manager.has_method("play_decode_success"), "play_decode_success should exist")

func test_play_decode_fail_exists() -> void:
	assert_true(_manager.has_method("play_decode_fail"), "play_decode_fail should exist")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: GUT with `test_audio_manager.gd` selected.
Expected: FAIL — pool size is 8, methods don't exist, `_play_sfx` doesn't accept volume.

- [ ] **Step 3: Update AudioManager — pool size and volume parameter**

In `core/audio/audio_manager.gd`:

**Line 7** — change pool size:
```gdscript
# Old:
const SFX_POOL_SIZE := 8
# New:
const SFX_POOL_SIZE := 12
```

**Lines 157-168** — add volume parameter to `_play_sfx`:
```gdscript
# Old signature:
func _play_sfx(stream: AudioStreamWAV) -> void:
# New signature:
func _play_sfx(stream: AudioStreamWAV, volume: float = 1.0) -> void:
```

Inside `_play_sfx`, after finding the player and before `player.play()`, add:
```gdscript
	player.volume_db = linear_to_db(volume)
```

- [ ] **Step 4: Add all new play methods to AudioManager**

**Caching strategy:** Static sounds (no parameters or fixed parameters) use the existing `_sfx_cache` LRU. Generate once, cache by string key. Frequent sounds like `enemy_hit`, `ui_click`, `gold_earn` MUST be cached — they fire many times per second. Escalation-parameterized sounds (wave_start, victory, defeat, etc.) are generated fresh since they fire at most once per wave and the escalation value changes each time.

Add after the existing `play_ability_activate()` method (after line 84):

```gdscript
# --- Gameplay SFX ---

func play_tower_place() -> void:
	var stream: AudioStreamWAV = _get_or_generate("tower_place", func() -> AudioStreamWAV:
		return _sfx_gen.generate_tower_place())
	_play_sfx(stream)


func play_tower_upgrade(tier: int) -> void:
	var key := "tower_upgrade_%d" % tier
	var stream: AudioStreamWAV = _get_or_generate(key, func() -> AudioStreamWAV:
		return _sfx_gen.generate_tower_upgrade(tier))
	_play_sfx(stream)


func play_tower_sell() -> void:
	var stream: AudioStreamWAV = _get_or_generate("tower_sell", func() -> AudioStreamWAV:
		return _sfx_gen.generate_tower_sell())
	_play_sfx(stream)


func play_enemy_hit() -> void:
	var stream: AudioStreamWAV = _get_or_generate("enemy_hit", func() -> AudioStreamWAV:
		return _sfx_gen.generate_enemy_hit())
	_play_sfx(stream, 0.6)


func play_enemy_escape(escalation: float) -> void:
	var stream := _sfx_gen.generate_enemy_escape(escalation)
	_play_sfx(stream)


func play_wave_start(escalation: float) -> void:
	var stream := _sfx_gen.generate_wave_start(escalation)
	_play_sfx(stream)


func play_wave_complete(escalation: float) -> void:
	var stream := _sfx_gen.generate_wave_complete(escalation)
	_play_sfx(stream)


func play_lives_lost(escalation: float) -> void:
	var stream := _sfx_gen.generate_lives_lost(escalation)
	_play_sfx(stream)


func play_victory(escalation: float) -> void:
	var stream := _sfx_gen.generate_victory(escalation)
	_play_sfx(stream)


func play_defeat(escalation: float) -> void:
	var stream := _sfx_gen.generate_defeat(escalation)
	_play_sfx(stream)


# --- Economy SFX (all cached — frequent calls) ---

func play_gold_earn() -> void:
	var stream: AudioStreamWAV = _get_or_generate("gold_earn", func() -> AudioStreamWAV:
		return _sfx_gen.generate_gold_earn())
	_play_sfx(stream)


func play_gold_spend() -> void:
	var stream: AudioStreamWAV = _get_or_generate("gold_spend", func() -> AudioStreamWAV:
		return _sfx_gen.generate_gold_spend())
	_play_sfx(stream)


func play_diamond_earn() -> void:
	var stream: AudioStreamWAV = _get_or_generate("diamond_earn", func() -> AudioStreamWAV:
		return _sfx_gen.generate_diamond_earn())
	_play_sfx(stream)


func play_cannot_afford() -> void:
	var stream: AudioStreamWAV = _get_or_generate("cannot_afford", func() -> AudioStreamWAV:
		return _sfx_gen.generate_cannot_afford())
	_play_sfx(stream)


# --- UI SFX (all cached — very frequent calls) ---

func play_ui_click() -> void:
	var stream: AudioStreamWAV = _get_or_generate("ui_click", func() -> AudioStreamWAV:
		return _sfx_gen.generate_ui_click())
	_play_sfx(stream)


func play_ui_hover() -> void:
	var stream: AudioStreamWAV = _get_or_generate("ui_hover", func() -> AudioStreamWAV:
		return _sfx_gen.generate_ui_hover())
	_play_sfx(stream, 0.4)


func play_ui_panel_open() -> void:
	var stream: AudioStreamWAV = _get_or_generate("ui_panel_open", func() -> AudioStreamWAV:
		return _sfx_gen.generate_ui_panel_open())
	_play_sfx(stream)


func play_ui_panel_close() -> void:
	var stream: AudioStreamWAV = _get_or_generate("ui_panel_close", func() -> AudioStreamWAV:
		return _sfx_gen.generate_ui_panel_close())
	_play_sfx(stream)


# --- Minigame SFX (glyph tones cached per index) ---

func play_glyph_tone(glyph_index: int) -> void:
	var key := "glyph_tone_%d" % (glyph_index % SfxGenerator.PENTATONIC_SCALE.size())
	var stream: AudioStreamWAV = _get_or_generate(key, func() -> AudioStreamWAV:
		return _sfx_gen.generate_glyph_tone(glyph_index))
	_play_sfx(stream)


func play_decode_correct() -> void:
	var stream: AudioStreamWAV = _get_or_generate("decode_correct", func() -> AudioStreamWAV:
		return _sfx_gen.generate_decode_correct())
	_play_sfx(stream)


func play_decode_wrong() -> void:
	var stream: AudioStreamWAV = _get_or_generate("decode_wrong", func() -> AudioStreamWAV:
		return _sfx_gen.generate_decode_wrong())
	_play_sfx(stream)


func play_decode_success() -> void:
	var stream: AudioStreamWAV = _get_or_generate("decode_success", func() -> AudioStreamWAV:
		return _sfx_gen.generate_decode_success())
	_play_sfx(stream)


func play_decode_fail() -> void:
	var stream: AudioStreamWAV = _get_or_generate("decode_fail", func() -> AudioStreamWAV:
		return _sfx_gen.generate_decode_fail())
	_play_sfx(stream)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: GUT with `test_audio_manager.gd` selected.
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add core/audio/audio_manager.gd tests/test_audio_manager.gd
git commit -m "feat(audio): AudioManager pool 8→12, volume control, 25 new play methods"
```

---

## Task 7: AudioEventRouter — Core Logic

**Files:**
- Create: `core/audio/audio_event_router.gd`
- Create: `tests/test_audio_event_router.gd`

**Reference:** Spec Section 1 (architecture), Section 2 (escalation), Section 5 (wiring)

- [ ] **Step 1: Write failing tests for AudioEventRouter**

Create `tests/test_audio_event_router.gd`:

```gdscript
extends GutTest

var _router: Node


func before_each() -> void:
	_router = load("res://core/audio/audio_event_router.gd").new()
	add_child_autofree(_router)


# --- Escalation calculation ---

func test_initial_escalation_is_zero() -> void:
	assert_eq(_router.get_escalation(), 0.0)

func test_escalation_campaign_wave_1_of_20() -> void:
	_router._update_escalation(1, 20)
	assert_almost_eq(_router.get_escalation(), 0.05, 0.01)

func test_escalation_campaign_wave_10_of_20() -> void:
	_router._update_escalation(10, 20)
	assert_almost_eq(_router.get_escalation(), 0.5, 0.01)

func test_escalation_campaign_wave_20_of_20() -> void:
	_router._update_escalation(20, 20)
	assert_almost_eq(_router.get_escalation(), 1.0, 0.01)

func test_escalation_endless_mode_caps_at_30() -> void:
	_router._is_endless_mode = true
	_router._update_escalation(50, 10)  # total_waves ignored in endless
	assert_almost_eq(_router.get_escalation(), 1.0, 0.01)

func test_escalation_endless_wave_15() -> void:
	_router._is_endless_mode = true
	_router._update_escalation(15, 10)
	assert_almost_eq(_router.get_escalation(), 0.5, 0.01)


# --- Rate limiting ---

func test_hit_rate_limiting_allows_first_hit() -> void:
	assert_true(_router._can_play_hit())

func test_hit_rate_limiting_blocks_after_max() -> void:
	for i in 6:
		_router._can_play_hit()  # Consume 6 hits
	assert_false(_router._can_play_hit(), "7th hit within window should be blocked")

func test_gold_rate_limiting_allows_first() -> void:
	assert_true(_router._can_play_gold_earn())

func test_gold_rate_limiting_blocks_after_max() -> void:
	for i in 3:
		_router._can_play_gold_earn()  # Consume 3
	assert_false(_router._can_play_gold_earn(), "4th gold earn within window should be blocked")


# --- Economy audio suppression ---

func test_suppress_economy_audio_default_false() -> void:
	assert_false(_router._suppress_economy_audio)

func test_suppress_economy_audio_toggle() -> void:
	_router.suppress_economy_audio(true)
	assert_true(_router._suppress_economy_audio)
	_router.suppress_economy_audio(false)
	assert_false(_router._suppress_economy_audio)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement AudioEventRouter**

Create `core/audio/audio_event_router.gd`:

```gdscript
extends Node
## Routes game events to AudioManager play calls.
## Computes escalation factor and handles rate limiting.

const MAX_HITS_PER_SECOND := 6
const MAX_GOLD_EARNS_PER_SECOND := 3
const ENDLESS_ESCALATION_CAP := 30.0

var _escalation := 0.0
var _suppress_economy_audio := false
var _prev_lives_lost: int = 0  # Track cumulative lives_lost to detect new losses
var _is_endless_mode := false

# Rate limiting trackers
var _hit_timestamps: Array[float] = []
var _gold_earn_timestamps: Array[float] = []


func get_escalation() -> float:
	return _escalation


func suppress_economy_audio(suppressed: bool) -> void:
	_suppress_economy_audio = suppressed


func setup(wave_manager: Node, endless_mode: bool = false) -> void:
	_is_endless_mode = endless_mode
	_prev_lives_lost = 0
	# WaveManager is not an autoload — passed explicitly
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_complete.connect(_on_wave_complete)

	# GameManager and EconomyManager are autoloads — access directly
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	EconomyManager.diamonds_changed.connect(_on_diamonds_changed)


func _update_escalation(wave_number: int, total_waves: int) -> void:
	if _is_endless_mode:
		# Endless mode: cap at wave 30 regardless of total_waves
		_escalation = clampf(float(wave_number) / ENDLESS_ESCALATION_CAP, 0.0, 1.0)
	else:
		# Campaign mode: scale by total waves in the level
		_escalation = clampf(float(wave_number) / maxf(float(total_waves), 1.0), 0.0, 1.0)


func _can_play_hit() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	_hit_timestamps = _hit_timestamps.filter(func(t: float) -> bool: return now - t < 1.0)
	if _hit_timestamps.size() >= MAX_HITS_PER_SECOND:
		return false
	_hit_timestamps.append(now)
	return true


func _can_play_gold_earn() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	_gold_earn_timestamps = _gold_earn_timestamps.filter(func(t: float) -> bool: return now - t < 1.0)
	if _gold_earn_timestamps.size() >= MAX_GOLD_EARNS_PER_SECOND:
		return false
	_gold_earn_timestamps.append(now)
	return true


# --- Signal handlers ---

func _on_wave_started(wave_number: int, total_waves: int) -> void:
	_update_escalation(wave_number, total_waves)
	AudioManager.play_wave_start(_escalation)
	AudioManager.set_music_intensity(_escalation)


func _on_wave_complete(wave_number: int) -> void:
	AudioManager.play_wave_complete(_escalation)


func _on_state_changed(new_state: int, _old_state: int) -> void:
	AudioManager.set_music_state(new_state)


func _on_lives_changed(_new_lives: int, lives_lost: int) -> void:
	# lives_lost is cumulative, not a delta — only play when it increases
	if lives_lost > _prev_lives_lost:
		AudioManager.play_lives_lost(_escalation)
	_prev_lives_lost = lives_lost


func _on_level_completed(_level_id: String, _stars: int) -> void:
	AudioManager.play_victory(_escalation)


func _on_level_failed(_level_id: String) -> void:
	AudioManager.play_defeat(_escalation)


func _on_gold_changed(new_gold: int, delta: int) -> void:
	if _suppress_economy_audio:
		return
	if delta > 0:
		if _can_play_gold_earn():
			AudioManager.play_gold_earn()
	elif delta < 0:
		AudioManager.play_gold_spend()


func _on_diamonds_changed(_new_diamonds: int, delta: int) -> void:
	if _suppress_economy_audio:
		return
	if delta > 0:
		AudioManager.play_diamond_earn()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: GUT with `test_audio_event_router.gd` selected.
Expected: Escalation calculation tests, rate limiting tests, and suppression tests PASS. Signal handler tests that call AudioManager will only work in integration (autoload needed), so the unit tests above focus on the calculable logic.

- [ ] **Step 5: Commit**

```bash
git add core/audio/audio_event_router.gd tests/test_audio_event_router.gd
git commit -m "feat(audio): add AudioEventRouter with escalation, rate limiting, signal handlers"
```

---

## Task 8: Wire AudioEventRouter into AudioManager

**Files:**
- Modify: `core/audio/audio_manager.gd`

**Reference:** Spec Section 1 — AudioEventRouter is a child of AudioManager

- [ ] **Step 1: Add event_router property and instantiation**

In `core/audio/audio_manager.gd`, add a public variable near the top (after line 5):

```gdscript
var event_router: Node  # AudioEventRouter — initialized in _ready
```

In `_ready()` (around line 33, after MusicSystem and SFXGenerator init), add:

```gdscript
	event_router = load("res://core/audio/audio_event_router.gd").new()
	event_router.name = "AudioEventRouter"
	add_child(event_router)
```

- [ ] **Step 2: Add set_music_intensity public method**

Add to `core/audio/audio_manager.gd` near the other music methods:

```gdscript
func set_music_intensity(value: float) -> void:
	_music_system.set_intensity(value)
```

This avoids external code accessing private `_music_system` directly.

- [ ] **Step 3: Run all audio tests to verify no regressions**

Run: GUT with all `test_audio_*` and `test_sfx_*` and `test_music_*` tests.
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add core/audio/audio_manager.gd
git commit -m "feat(audio): wire AudioEventRouter as child of AudioManager, add set_music_intensity"
```

---

## Task 9: Integration — game.gd Gameplay Audio

**Files:**
- Modify: `scenes/game.gd`

**Reference:** Spec Section 5 — Direct Audio Calls table

Key insertion points in `scenes/game.gd`:
- Tower placement: after line ~818 (end of `_try_place_tower`)
- Tower upgrade: after line ~1408 (upgrade applied in `_on_upgrade_tower_requested`)
- Tower sell: after line ~1384 (gold added in `_on_sell_tower_requested`)
- Enemy hit: inside `_deal_damage_to_enemy` (line ~1058)
- Enemy escape: inside `_on_enemy_reached_exit` (line ~1104)
- Cannot afford: at line ~775 (afford check fails in `_try_place_tower`)

- [ ] **Step 1: Add tower placement audio**

In `_try_place_tower()`, after the tower is successfully placed (after the line that adds the tower to the scene tree), add:

```gdscript
	AudioManager.play_tower_place()
```

- [ ] **Step 2: Add tower upgrade audio**

In `_on_upgrade_tower_requested()`, after the upgrade is applied, add:

```gdscript
	AudioManager.play_tower_upgrade(tower.current_tier)
```

- [ ] **Step 3: Add tower sell audio**

In `_on_sell_tower_requested()`, after gold is added back, add:

```gdscript
	AudioManager.play_tower_sell()
```

- [ ] **Step 4: Add cannot afford audio**

In `_try_place_tower()`, in the `if not EconomyManager.can_afford(cost)` branch, add `AudioManager.play_cannot_afford()` BEFORE the `return`:

```gdscript
	if not EconomyManager.can_afford(cost):
		AudioManager.play_cannot_afford()
		return
```

In `_on_upgrade_tower_requested()`, same pattern — BEFORE the `return` on the afford check (line ~1405):

```gdscript
	if not EconomyManager.can_afford(cost):
		AudioManager.play_cannot_afford()
		return
```

- [ ] **Step 5: Add enemy hit audio**

In `_deal_damage_to_enemy()`, after damage is applied, add:

```gdscript
	if AudioManager.event_router != null:
		if AudioManager.event_router._can_play_hit():
			AudioManager.play_enemy_hit()
```

Note: uses the rate limiter to cap at 6 hit sounds/sec.

- [ ] **Step 6: Add enemy escape audio**

In `_on_enemy_reached_exit()`, add:

```gdscript
	var esc := AudioManager.event_router.get_escalation() if AudioManager.event_router != null else 0.0
	AudioManager.play_enemy_escape(esc)
```

- [ ] **Step 7: Commit**

```bash
git add scenes/game.gd
git commit -m "feat(audio): wire gameplay audio in game.gd (tower, enemy, economy)"
```

---

## Task 10: Integration — game_loop.gd Router Setup & Economy Suppression

**Files:**
- Modify: `core/game_loop.gd`

**Reference:** Spec Section 5 — setup and economy signal guards

- [ ] **Step 1: Wire AudioEventRouter setup in GameLoop**

In `game_loop.gd`'s `setup()` method (line ~64), after all manager wiring, add:

```gdscript
	if AudioManager.event_router != null:
		var is_endless := GameManager.current_level_id == "endless"
		AudioManager.event_router.setup(wm, is_endless)
```

- [ ] **Step 2: Add economy audio suppression around reset**

In `start_level()` (line ~75), wrap the `reset_match_economy()` call:

```gdscript
	if AudioManager.event_router != null:
		AudioManager.event_router.suppress_economy_audio(true)
	EconomyManager.reset_match_economy()
	if AudioManager.event_router != null:
		AudioManager.event_router.suppress_economy_audio(false)
```

- [ ] **Step 3: Run existing game tests to verify no regressions**

Run: GUT with all tests. Ensure no tests break from the new code paths.
Expected: All existing tests PASS (the new code is guarded by null checks).

- [ ] **Step 4: Commit**

```bash
git add core/game_loop.gd
git commit -m "feat(audio): wire AudioEventRouter in GameLoop, suppress economy audio on reset"
```

---

## Task 11: Integration — Signal Decode Minigame Audio

**Files:**
- Modify: `ui/hud/signal_decode_minigame.gd`

**Reference:** Spec Section 4 — Signal Decode Minigame sounds

- [ ] **Step 1: Add glyph display tones**

Find the code where glyphs are displayed to the player (the sequence display phase). When each glyph is shown, add:

```gdscript
	AudioManager.play_glyph_tone(glyph_index)
```

- [ ] **Step 2: Add input feedback sounds**

Find the input handling code where the player taps a glyph. On correct input:

```gdscript
	AudioManager.play_decode_correct()
```

On wrong input:

```gdscript
	AudioManager.play_decode_wrong()
```

- [ ] **Step 3: Add completion sounds**

Find where decode succeeds (near `decode_succeeded` signal emission):

```gdscript
	AudioManager.play_decode_success()
```

Find where decode fails (timeout or wrong sequence):

```gdscript
	AudioManager.play_decode_fail()
```

- [ ] **Step 4: Commit**

```bash
git add ui/hud/signal_decode_minigame.gd
git commit -m "feat(audio): add Signal Decode minigame audio feedback"
```

---

## Task 12: Integration — UI Audio (All UI Files)

**Files to modify** (add `AudioManager.play_ui_click()` to button press handlers):

**Menus:**
- `ui/menus/main_menu.gd` — 6 buttons (Campaign, Endless, Daily Challenge, Tower Lab, Diamond Shop, Settings)
- `ui/menus/pause_menu.gd` — 6 buttons (Resume, Settings, Restart, Quit + 2 confirm)
- `ui/menus/level_complete.gd` — 3 buttons (Double Diamonds, Continue, Restart)
- `ui/menus/level_failed.gd` — 2 buttons (Retry, Quit)
- `ui/menus/settings_menu.gd` — Back button
- `ui/menus/daily_challenge_screen.gd` — Play, Back buttons

**HUD:**
- `ui/hud/hud.gd` — Send wave button
- `ui/hud/top_bar.gd` — Speed cycle, pause buttons
- `ui/tower_ui/tower_button.gd` — Tower selection (has `_on_pressed()`)
- `ui/hud/tower_upgrade_panel.gd` — Upgrade choice, targeting cycle, sell buttons
- `ui/hud/ability_bar.gd` — Ability buttons, hero summon

**Meta:**
- `ui/meta/campaign_map.gd` — Region tabs, difficulty selector
- `ui/meta/level_node.gd` — Level selection (has `_on_pressed()`)
- `ui/meta/tower_lab.gd` — Tower tabs, skill buttons, global upgrade buttons
- `ui/meta/diamond_shop.gd` — Purchase buttons, ad button

**Other:**
- `ui/story/dialogue_overlay.gd` — Advance button
- `ui/hud/wave_reward_ui.gd` — Card selection buttons

**Pattern:** For each button's `pressed.connect()` lambda or callback method, add `AudioManager.play_ui_click()` as the first line. For buttons that use dedicated `_on_pressed()` methods, add it at the top of the method.

Example — a lambda connection:
```gdscript
# Before:
btn.pressed.connect(func() -> void: campaign_selected.emit())
# After:
btn.pressed.connect(func() -> void:
	AudioManager.play_ui_click()
	campaign_selected.emit()
)
```

Example — a dedicated method:
```gdscript
# Before:
func _on_pressed() -> void:
	tower_selected.emit(_tower_type)
# After:
func _on_pressed() -> void:
	AudioManager.play_ui_click()
	tower_selected.emit(_tower_type)
```

- [ ] **Step 1: Add UI click audio to menu files**

Modify all 6 menu files listed above. Add `AudioManager.play_ui_click()` to every button press handler.

- [ ] **Step 2: Add UI click audio to HUD files**

Modify all 5 HUD files listed above.

- [ ] **Step 3: Add UI click audio to meta screen files**

Modify all 4 meta screen files listed above.

- [ ] **Step 4: Add UI click audio to remaining files**

Modify `dialogue_overlay.gd` and `wave_reward_ui.gd`.

- [ ] **Step 5: Add panel open/close audio where applicable**

For panels that show/hide (tower_upgrade_panel, pause_menu, settings overlays):
- On show/open: `AudioManager.play_ui_panel_open()`
- On hide/close: `AudioManager.play_ui_panel_close()`

- [ ] **Step 6: Commit**

```bash
git add ui/
git commit -m "feat(audio): add UI click and panel sounds to all 19 UI files"
```

---

## Task 13: Final Verification

**Files:** None (testing only)

- [ ] **Step 1: Run full test suite**

Run all GUT tests to ensure no regressions:
```
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```
Expected: All 867+ existing tests PASS. All ~40-50 new tests PASS.

- [ ] **Step 2: Verify test count increased**

Check that test count is now ~910-920 (867 + ~45 new).

- [ ] **Step 3: Manual verification checklist**

Open the game in Godot editor and verify:
- [ ] Main menu buttons make click sounds
- [ ] Tower placement makes a thunk
- [ ] Tower firing still works (existing)
- [ ] Tower upgrade makes a rising chirp
- [ ] Tower sell makes a descending tone
- [ ] Enemy deaths still sound (existing)
- [ ] Enemy hits make subtle crunches (not overwhelming)
- [ ] Wave start plays an alert (louder in later waves)
- [ ] Wave complete plays a relief tone
- [ ] Gold earn/spend makes clink sounds
- [ ] Cannot afford buzzes
- [ ] Signal decode minigame has glyph tones
- [ ] Victory/defeat play appropriate stingers
- [ ] Music intensity builds through waves
- [ ] Volume sliders still work
- [ ] No audio plays during match reset

- [ ] **Step 4: Commit any fixes from manual testing**

```bash
git add -A
git commit -m "fix(audio): adjustments from manual playtesting"
```
