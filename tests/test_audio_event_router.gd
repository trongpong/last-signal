extends GutTest

var _router: Node


func before_each() -> void:
	_router = load("res://core/audio/audio_event_router.gd").new()
	add_child_autofree(_router)


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
	_router._update_escalation(50, 10)
	assert_almost_eq(_router.get_escalation(), 1.0, 0.01)

func test_escalation_endless_wave_15() -> void:
	_router._is_endless_mode = true
	_router._update_escalation(15, 10)
	assert_almost_eq(_router.get_escalation(), 0.5, 0.01)

func test_hit_rate_limiting_allows_first_hit() -> void:
	assert_true(_router.can_play_hit())

func test_hit_rate_limiting_blocks_after_max() -> void:
	for i in 6:
		_router.can_play_hit()
	assert_false(_router.can_play_hit(), "7th hit within window should be blocked")

func test_gold_rate_limiting_allows_first() -> void:
	assert_true(_router._can_play_gold_earn())

func test_gold_rate_limiting_blocks_after_max() -> void:
	for i in 3:
		_router._can_play_gold_earn()
	assert_false(_router._can_play_gold_earn(), "4th gold earn within window should be blocked")

func test_suppress_economy_audio_default_false() -> void:
	assert_false(_router._suppress_economy_audio)

func test_suppress_economy_audio_toggle() -> void:
	_router.suppress_economy_audio(true)
	assert_true(_router._suppress_economy_audio)
	_router.suppress_economy_audio(false)
	assert_false(_router._suppress_economy_audio)
