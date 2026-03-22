class_name GameCamera
extends Camera2D

var _map_scale: float = 1.0
var _world_size: Vector2 = Vector2(1280, 720)
var _min_zoom: float = 1.0
var _max_zoom: float = 1.0
var _is_panning: bool = false
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

func setup(map_scale: float, world_size: Vector2) -> void:
	_map_scale = map_scale
	_world_size = world_size
	_min_zoom = 1.0 / map_scale
	_max_zoom = 1.0
	zoom = Vector2(_min_zoom, _min_zoom)
	position = world_size * 0.5
	_clamp_position()

func zoom_by(amount: float) -> void:
	var new_zoom: float = clampf(zoom.x + amount * 0.1, _min_zoom, _max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_position()

func pan_by(delta: Vector2) -> void:
	position -= delta / zoom.x
	_clamp_position()

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var damping: float = _shake_timer / _shake_duration if _shake_duration > 0.0 else 0.0
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity) * damping,
			randf_range(-_shake_intensity, _shake_intensity) * damping
		)
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO
			_shake_timer = 0.0

func _clamp_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return  # Skip in headless/test environments
	var half_view: Vector2 = vp_size / (2.0 * zoom.x)
	position.x = clampf(position.x, half_view.x, _world_size.x - half_view.x)
	position.y = clampf(position.y, half_view.y, _world_size.y - half_view.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(-1.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
	elif event is InputEventMouseMotion and _is_panning:
		var motion := event as InputEventMouseMotion
		pan_by(motion.relative)
	elif event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		zoom_by((mag.factor - 1.0) * 5.0)
