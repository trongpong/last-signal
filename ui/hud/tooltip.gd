class_name Tooltip
extends PanelContainer

var _label: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_label)
	custom_minimum_size = Vector2(180, 0)

func show_at(text: String, pos: Vector2) -> void:
	_label.text = text
	global_position = pos + Vector2(12, 12)
	# Clamp to screen bounds
	var screen_size := get_viewport_rect().size
	if global_position.x + size.x > screen_size.x:
		global_position.x = pos.x - size.x - 12
	if global_position.y + size.y > screen_size.y:
		global_position.y = pos.y - size.y - 12
	visible = true

func hide_tooltip() -> void:
	visible = false
