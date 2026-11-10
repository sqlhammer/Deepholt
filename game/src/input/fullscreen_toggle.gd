class_name FullscreenToggle
extends Node

# F11 (D-191): between exclusive full screen, the launch default, and
# a window. Exclusive, because Windows draws its taskbar over a
# borderless full-screen window. The window opens at the project's
# window size, shrunk to fit the screen's usable area if it must, and
# centered there. Presentation: the window, not the world.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle()
		get_viewport().set_input_as_handled()


# Any full-screen mode goes to a window; a window (maximized or not)
# goes to exclusive full screen.
static func next_mode(current: DisplayServer.WindowMode) -> DisplayServer.WindowMode:
	if current == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return DisplayServer.WINDOW_MODE_WINDOWED
	return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# The window's size: the project's, kept in shape and shrunk to fit
# inside `usable` if it's bigger.
static func window_size_for(wanted: Vector2i, usable: Vector2i) -> Vector2i:
	var shrink: float = minf(1.0, minf(float(usable.x) / wanted.x, float(usable.y) / wanted.y))
	return Vector2i((Vector2(wanted) * shrink).floor())


func toggle() -> void:
	var mode: DisplayServer.WindowMode = next_mode(DisplayServer.window_get_mode())
	DisplayServer.window_set_mode(mode)
	if mode != DisplayServer.WINDOW_MODE_WINDOWED: return
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var wanted: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/window_width_override", 1280),
		ProjectSettings.get_setting("display/window/size/window_height_override", 800))
	var size: Vector2i = window_size_for(wanted, usable.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
