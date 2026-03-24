# Audio Improvements Design — Last Signal

**Date:** 2026-03-24
**Status:** Approved

## Goals

Increase audio coverage from ~7% (4 event types) to near-complete coverage (~50+ event types). All new audio is 100% procedural (matching existing sci-fi synth aesthetic). Sounds escalate in drama as the game progresses. Both "game feel" (interaction feedback) and "ambience" (emotional moments) are addressed equally.

## Design Decisions

- **100% procedural** — no audio files. Extend existing SynthEngine.
- **UI sounds** — clean with a hint of sci-fi character. Not sterile, not theatrical.
- **Signal Decode minigame** — tonally interesting (pentatonic glyph tones) but understated.
- **Big moments** — escalating drama. Early waves are modest; late waves are intense. Audio rewards progression.

---

## 1. Architecture

### New Component: AudioEventRouter

A new Node, added as a child of AudioManager. Connects to existing game signals and translates game events into audio calls.

```
GameManager ──signal──┐
WaveManager ──signal──┤
EconomyManager─signal─┤──► AudioEventRouter ──► AudioManager.play_*()
Enemy ────────signal──┤         │
UI scenes ────signal──┘         ├── reads wave_number, game progress
                                ├── computes escalation_factor (0.0–1.0)
                                └── decides what to play & how intense
```

**How it works:**
- `setup(wave_manager: WaveManager)` is called once when GameLoop initializes. Connects to WaveManager (passed explicitly, since it is not an autoload) and to GameManager/EconomyManager (accessed directly as autoloads).
- For UI sounds, individual UI scenes call `AudioManager.play_ui_*()` directly (thin convenience methods).
- Escalation factor is passed to SFXGenerator methods that support scaling.
- No new signals needed — hooks into signals that already exist but have no audio listeners.

**What stays the same:**
- AudioManager remains the public API (gains ~15 new methods).
- SynthEngine untouched. Frequency sweeps are implemented as inline sample-by-sample loops in SFXGenerator methods (same pattern as the existing `generate_hero_summon()` which already does this).
- MusicSystem untouched (but AudioEventRouter calls `set_intensity()` based on wave progress).
- Existing `play_tower_fire()` and `play_enemy_death()` unchanged.

### New AudioManager Public Methods

```gdscript
# Gameplay
play_tower_place()
play_tower_upgrade(tier: int)
play_tower_sell()
play_enemy_hit()
play_enemy_escape(escalation: float)
play_wave_start(escalation: float)
play_wave_complete(escalation: float)
play_lives_lost(escalation: float)
play_victory(escalation: float)
play_defeat(escalation: float)

# Economy
play_gold_earn()
play_gold_spend()
play_diamond_earn()
play_cannot_afford()

# UI
play_ui_click()
play_ui_hover()
play_ui_panel_open()
play_ui_panel_close()

# Minigame
play_glyph_tone(glyph_index: int)
play_decode_correct()
play_decode_wrong()
play_decode_success()
play_decode_fail()
```

### Per-Sound Volume Control

`_play_sfx()` gains an optional volume parameter: `_play_sfx(stream: AudioStreamWAV, volume: float = 1.0)`. Sets `player.volume_db = linear_to_db(volume)` before playing. This enables per-sound volume levels (e.g., enemy hit at 0.6, hover at 0.4) without baking volume into waveform samples.

### SFX Pool Size

Increase from 8 to 12 AudioStreamPlayers to handle overlapping hit sounds, UI sounds, and economy sounds during intense waves.

---

## 2. Escalation System

Escalation factor drives how dramatic sounds become as the game progresses.

### Calculation

```gdscript
# Campaign mode
escalation = clamp(float(current_wave) / max(total_waves, 1), 0.0, 1.0)

# Endless mode (no total_waves cap)
escalation = clamp(float(current_wave) / 30.0, 0.0, 1.0)
```

Maxes out at wave 30 in endless mode.

### What Escalation Affects

| Sound | Low escalation (0.0) | High escalation (1.0) |
|-------|---------------------|----------------------|
| Wave start | Single short beep (0.1s) | Layered alarm chord with rising pitch (0.4s) |
| Wave complete | Soft confirmation tone (0.2s) | Triumphant two-note chord (0.5s) |
| Victory | Clean major chord (0.5s) | Sweeping arpeggio with harmonics (1.5s) |
| Defeat | Flat low buzz (0.5s) | Deep descending drone with dissonance (2.0s) |
| Lives lost | Quick warning pip (0.1s) | Harsh alarm with rumble sub-bass (0.3s) |
| Enemy escape | Soft blip (0.15s) | Urgent warning tone (0.3s) |

### How It Scales Technically

- **Duration:** `base_duration + (escalation * extra_duration)`
- **Harmonic richness:** more overtones layered at higher escalation
- **Frequency range:** wider pitch sweeps at higher escalation
- **Volume:** slight boost (up to +20%) at higher escalation

### What Does NOT Escalate

Tower fire, placement, upgrade, sell. UI clicks/hovers. Economy sounds. Minigame sounds. These stay consistent for reliability.

### AudioEventRouter Tracking

AudioEventRouter listens to `wave_started(wave_number, total_waves)` to update `current_wave` and `total_waves`. It passes the computed escalation float to SFXGenerator methods that support it.

---

## 3. Sound Design — Gameplay SFX

All procedural, using existing SynthEngine waveforms.

### Tower Interactions

| Sound | Waveform | Frequency | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Tower place | Square | 180Hz | 0.12s | Low-mid "thunk." Fast attack, heavy lowpass. Feels like locking into a grid slot. |
| Tower upgrade | Sine sweep | 440→660Hz + 660→880Hz | 0.15s + 0.1s | Rising two-step chirp. Higher tiers = higher starting pitch. |
| Tower sell | Square descend | 180→100Hz | 0.1s | Reverse of placement — descending, quick fade. Unlocking from grid. |

### Enemy Feedback

| Sound | Waveform | Frequency | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Enemy hit | Noise burst | N/A | 0.03s | Heavy lowpass at 300Hz. Subtle crunch. 60% volume to avoid cacophony. |
| Enemy escape | Sine descend | 600→200Hz | 0.15–0.3s (escalation) | Warning — "something got through." |

### Wave Events

| Sound | Low Escalation | High Escalation |
|-------|---------------|-----------------|
| Wave start | Saw 330Hz, 0.1s | Layered saw 330+440+550Hz chord, 0.4s with slow attack |
| Wave complete | Sine major third (440+550Hz), 0.2s | Add 660Hz, extend to 0.5s |
| Lives lost | Square 150Hz + noise burst, 0.1s | Add sub-bass 60Hz rumble, extend to 0.3s |

### Stingers (Escalation-Driven)

| Sound | Low Escalation | High Escalation |
|-------|---------------|-----------------|
| Victory | Ascending sine arpeggio C5→E5→G5→C6, each 0.12s (0.5s total) | Double duration, add saw harmonics, extend final note to 0.5s with slow release (1.5s total) |
| Defeat | Descending sine C4→A3→F3, each 0.15s, lowpass tightening (0.5s total) | Add dissonant minor second (E3+F3), extend drone tail (2.0s total) |

### Rate Limiting

- **Enemy hit:** max 6 sounds per second globally. AudioEventRouter tracks last hit timestamp, skips if too frequent.
- **Gold earn:** max 3 clinks per second (see Economy section).

---

## 4. Sound Design — Economy, UI & Minigame

### Economy Sounds

| Sound | Waveform | Frequency | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Gold earn | Sine | 1200Hz | 0.04s | Bright short "clink." Sharp attack/release. |
| Gold spend | Sine descend | 900→700Hz | 0.05s | Softer descending "clink." Same family, "going out" feel. |
| Diamond earn | Sine double-tap | 1800Hz + 2200Hz | 0.03s + 0.02s gap + 0.03s | Shimmery. Rarer and more precious than gold. |
| Cannot afford | Square | 120Hz | 0.08s | Flat low buzz. Quick "nope." No sustain. |

**Gold earn rate limiting:** max 3 clinks per second. When gold arrives in rapid bursts (wave-end rewards), play only periodic clinks.

### UI Sounds

| Sound | Waveform | Frequency | Duration | Volume | Character |
|-------|----------|-----------|----------|--------|-----------|
| Button click | Sine | 800Hz | 0.03s | 100% | Clean electronic "pip." |
| Button hover | Sine | 600Hz | 0.015s | 40% | Barely there — felt more than heard. |
| Panel open | Noise sweep | LP 200→800Hz | 0.1s | 100% | Rising filtered noise. Subtle "whoosh." |
| Panel close | Noise sweep | LP 800→200Hz | 0.08s | 100% | Reverse, quicker than open. |

### Signal Decode Minigame

| Sound | Waveform | Frequency | Duration | Character |
|-------|----------|-----------|----------|-----------|
| Glyph tone | Sine | Pentatonic: C5(523), D5(587), F5(698), G5(784), A5(880) | 0.1s | Each glyph maps to a pitch via `glyph_index % PENTATONIC_SCALE.size()`. If glyph count changes, wraps with modulo. Creates a musical memory game feel. |
| Correct input | Sine + fifth | Glyph's tone + fifth above | 0.08s | Confirms without interrupting. Quiet harmony. |
| Wrong input | Square pair | 200Hz + 215Hz | 0.1s | Beating frequency = instant "wrong" feel. |
| Decode success | Sine run | All 5 pentatonic notes ascending | 0.04s each = 0.2s | Quick ascending run. Playful resolution. |
| Decode fail | Saw descend | 400→200Hz | 0.15s | Chromatic slide. Brief disappointment. |

---

## 5. Integration & Wiring

### AudioEventRouter Signal Connections

Connected in `setup(wave_manager: WaveManager)`. GameManager and EconomyManager are autoloads accessed directly; WaveManager is passed as a parameter since it is created locally in game.gd:

```gdscript
# Game state
GameManager.state_changed       → _on_state_changed
GameManager.lives_changed       → _on_lives_changed
GameManager.level_completed     → _on_level_completed
GameManager.level_failed        → _on_level_failed

# Waves
wave_manager.wave_started        → _on_wave_started
wave_manager.wave_complete       → _on_wave_complete

# Economy
EconomyManager.gold_changed     → _on_gold_changed
EconomyManager.diamonds_changed → _on_diamonds_changed
```

### Economy Signal Guards

`_on_gold_changed(new_gold: int, delta: int)` must handle edge cases:
- **delta > 0** → `play_gold_earn()` (with rate limiting)
- **delta < 0** → `play_gold_spend()`
- **delta == 0** → ignore (no-op)
- **Match reset guard:** When `reset_match_economy()` zeroes gold, it emits `gold_changed(0, -old_gold)`. AudioEventRouter uses a `_suppress_economy_audio: bool` flag. GameLoop sets `AudioManager.event_router.suppress_economy_audio(true)` before calling `reset_match_economy()`, then `suppress_economy_audio(false)` after. The `_on_gold_changed` handler checks this flag and skips audio when suppressed.

`_on_diamonds_changed(new_diamonds: int, delta: int)`:
- **delta > 0** → `play_diamond_earn()`
- **delta < 0** → ignore (diamond spending has no distinct sound; the purchase action itself provides feedback)

### Direct Audio Calls (No Central Signal)

These game events don't have a global signal, so audio calls are added directly in the relevant code:

| Event | Where to add call | Method |
|-------|-------------------|--------|
| Tower place | game.gd — tower placement logic | `AudioManager.play_tower_place()` |
| Tower upgrade | game.gd — upgrade application | `AudioManager.play_tower_upgrade(tier)` |
| Tower sell | game.gd — tower sell logic | `AudioManager.play_tower_sell()` |
| Enemy hit | game.gd — `_deal_damage_to_enemy()` | `AudioManager.play_enemy_hit()` |
| Enemy escape | game.gd — `_on_enemy_reached_exit()` handler | `AudioManager.play_enemy_escape(escalation)` |
| Cannot afford | game.gd — tower placement/upgrade affordability checks | `AudioManager.play_cannot_afford()` |
| UI click | Each UI scene's button handlers | `AudioManager.play_ui_click()` |
| UI hover | Each UI scene's hover handlers | `AudioManager.play_ui_hover()` |
| Panel open/close | Panel show/hide methods | `AudioManager.play_ui_panel_open/close()` |
| Minigame sounds | signal_decode_minigame.gd internal logic | `AudioManager.play_glyph_tone(index)` etc. |

AudioEventRouter exposes `get_escalation() -> float` publicly. Since enemy hit and escape audio calls live in game.gd (not enemy.gd), game.gd accesses escalation via `AudioManager.event_router.get_escalation()`. The enemy system remains audio-free — only the game orchestrator touches audio, consistent with how `play_tower_fire` is already called from game.gd.

### Music System Enhancement

AudioEventRouter calls `MusicSystem.set_intensity(escalation)` on each `wave_started`, so music tension naturally builds with wave progression.

---

## 6. Testing Strategy

### New Test File: `test_audio_event_router.gd`

- Signal connections established after `setup()`
- Escalation calculation: wave 1/20 → 0.05, wave 10/20 → 0.5, wave 20/20 → 1.0
- Endless mode escalation caps at 1.0 after wave 30
- Hit sound rate limiting (max 6/sec)
- Gold earn rate limiting (max 3/sec)

### Extended: `test_sfx_generator.gd`

- Each new `generate_*()` returns valid AudioStreamWAV (not null, has data)
- Tower upgrade pitch increases with tier parameter
- Escalation parameter produces longer duration at 1.0 vs 0.0
- Glyph tones produce different frequencies for different indices
- Victory/defeat stingers scale duration with escalation

### Extended: `test_music_system.gd`

- `set_intensity()` with escalation values maps correctly to layer volumes

### New Test File: `test_audio_manager.gd`

- SFX pool size is 12
- All new `play_*()` methods exist and don't error
- Audio bus setup still works

### Not Tested (Manual Playtesting)

- Subjective sound quality
- Exact waveform sample values (too brittle)
- UI button wiring

### Estimated New Tests: ~40-50

---

## File Summary

### New Files
- `core/audio/audio_event_router.gd` — Event router node
- `tests/test_audio_event_router.gd` — Router tests
- `tests/test_audio_manager.gd` — AudioManager integration tests

### Modified Files
- `core/audio/audio_manager.gd` — New play methods, pool size 8→12, instantiate router
- `core/audio/sfx_generator.gd` — New generate methods (gameplay, economy, UI, minigame)
- `scenes/game.gd` — Add tower place/upgrade/sell/hit/escape/cannot-afford audio calls
- `ui/hud/signal_decode_minigame.gd` — Add minigame audio calls
- UI scene files — Add click/hover/panel audio calls
- `tests/test_sfx_generator.gd` — Extended with new method tests
- `tests/test_music_system.gd` — Extended with intensity tests

### Untouched Files
- `core/audio/synth_engine.gd`
- `core/audio/music_layer.gd`
- `core/audio/music_system.gd`
