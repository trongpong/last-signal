extends GutTest

## Tests for core/audio/music_layer.gd and core/audio/music_system.gd

var _system: MusicSystem


func before_each() -> void:
	_system = MusicSystem.new()
	add_child_autofree(_system)


# --- MusicSystem state tests ---

func test_initial_state_all_silent() -> void:
	var active := _system.get_active_layers()
	assert_eq(active.size(), 0, "All layers should be silent initially")


func test_set_game_state_building_activates_base() -> void:
	_system.set_game_state(Enums.GameState.BUILDING)
	var active := _system.get_active_layers()
	assert_true(active.has("base"), "Building state should activate base layer")
	assert_false(active.has("combat"), "Building state should not activate combat layer")
	assert_false(active.has("boss"), "Building state should not activate boss layer")


func test_set_game_state_menu_silences_all() -> void:
	_system.set_game_state(Enums.GameState.BUILDING)
	_system.set_game_state(Enums.GameState.MENU)
	var active := _system.get_active_layers()
	assert_eq(active.size(), 0, "Menu state should silence all layers")


func test_set_game_state_wave_active_activates_combat_layers() -> void:
	_system.set_game_state(Enums.GameState.WAVE_ACTIVE)
	var active := _system.get_active_layers()
	assert_true(active.has("base"), "Wave active should have base layer")
	assert_true(active.has("combat"), "Wave active should have combat layer")
	assert_false(active.has("boss"), "Wave active without boss should not have boss layer")


func test_set_game_state_victory_base_low() -> void:
	_system.set_game_state(Enums.GameState.WAVE_ACTIVE)
	_system.set_game_state(Enums.GameState.VICTORY)
	var active := _system.get_active_layers()
	assert_true(active.has("base"), "Victory should have base layer at low volume")
	assert_false(active.has("combat"), "Victory should not have combat layer")


func test_set_game_state_defeat_base_low() -> void:
	_system.set_game_state(Enums.GameState.WAVE_ACTIVE)
	_system.set_game_state(Enums.GameState.DEFEAT)
	var active := _system.get_active_layers()
	assert_true(active.has("base"), "Defeat should have base layer at low volume")


func test_set_boss_active_activates_boss_layer() -> void:
	_system.set_game_state(Enums.GameState.WAVE_ACTIVE)
	_system.set_boss_active(true)
	var active := _system.get_active_layers()
	assert_true(active.has("boss"), "Boss active should add boss layer")
	assert_false(active.has("combat"), "Boss active should silence combat layer")
	assert_false(active.has("intensity"), "Boss active should silence intensity layer")


func test_set_boss_inactive_removes_boss_layer() -> void:
	_system.set_game_state(Enums.GameState.WAVE_ACTIVE)
	_system.set_boss_active(true)
	_system.set_boss_active(false)
	var active := _system.get_active_layers()
	assert_false(active.has("boss"), "Boss inactive should remove boss layer")
	assert_true(active.has("combat"), "Boss inactive during wave should restore combat layer")


func test_set_intensity_updates_value() -> void:
	_system.set_intensity(0.75)
	assert_almost_eq(_system.intensity, 0.75, 0.001)


func test_set_intensity_clamped() -> void:
	_system.set_intensity(2.0)
	assert_almost_eq(_system.intensity, 1.0, 0.001)
	_system.set_intensity(-0.5)
	assert_almost_eq(_system.intensity, 0.0, 0.001)


func test_set_region_updates_key() -> void:
	_system.set_region(2)
	assert_eq(_system.current_key, "D")
	_system.set_region(4)
	assert_eq(_system.current_key, "A")


func test_set_region_unknown_does_not_change_key() -> void:
	_system.set_region(1)
	_system.set_region(99)
	assert_eq(_system.current_key, "C", "Unknown region should not change key")


func test_all_region_keys_defined() -> void:
	for region_id in [1, 2, 3, 4, 5]:
		_system.set_region(region_id)
		assert_ne(_system.current_key, "", "Region %d should have a key" % region_id)


# --- MusicLayer tests ---

func test_music_layer_initial_volume() -> void:
	var layer := MusicLayer.new()
	add_child_autofree(layer)
	assert_almost_eq(layer.target_volume, 0.0, 0.001)


func test_music_layer_fade_in_sets_target() -> void:
	var layer := MusicLayer.new()
	add_child_autofree(layer)
	layer.fade_in(0.8)
	assert_almost_eq(layer.target_volume, 0.8, 0.001)


func test_music_layer_fade_out_sets_target_zero() -> void:
	var layer := MusicLayer.new()
	add_child_autofree(layer)
	layer.fade_in(1.0)
	layer.fade_out()
	assert_almost_eq(layer.target_volume, 0.0, 0.001)


func test_music_layer_fade_in_clamps() -> void:
	var layer := MusicLayer.new()
	add_child_autofree(layer)
	layer.fade_in(5.0)
	assert_almost_eq(layer.target_volume, 1.0, 0.001)
