## Shared UI utility helpers.

class_name UIHelpers
extends RefCounted

static func get_safe_margin() -> float:
	var screen_size := DisplayServer.screen_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	var left: float = safe_area.position.x
	var right: float = maxf(screen_size.x - safe_area.end.x, 0.0)
	return clampf(maxf(left, right), 16.0, 48.0)
