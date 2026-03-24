extends GutTest

var _manager: Node


func before_each() -> void:
	_manager = load("res://core/audio/audio_manager.gd").new()
	add_child_autofree(_manager)


func test_sfx_pool_size_is_twelve() -> void:
	var count := 0
	for child in _manager.get_children():
		if child is AudioStreamPlayer:
			count += 1
	assert_eq(count, 12, "SFX pool should have 12 players")


func test_play_sfx_accepts_volume_parameter() -> void:
	var stream := _manager._sfx_generator.generate_ui_click()
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
