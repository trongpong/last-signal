extends GutTest

func test_game_camera_zoom_limits() -> void:
	var cam := GameCamera.new()
	add_child(cam)
	cam.setup(2.0, Vector2(2560, 1440))
	# Initial zoom should fit full map
	assert_almost_eq(cam.zoom.x, 0.5, 0.01, "Initial zoom should be 1/map_scale")
	# Zoom in should not exceed 1.0
	cam.zoom_by(10.0)
	assert_almost_eq(cam.zoom.x, 1.0, 0.01, "Max zoom should be 1.0")
	# Zoom out should not go below fit-all
	cam.zoom_by(-10.0)
	assert_almost_eq(cam.zoom.x, 0.5, 0.01, "Min zoom should be 1/map_scale")
	cam.queue_free()
