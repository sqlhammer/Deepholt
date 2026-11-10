extends GutTest

# F11 and the launch mode (D-191): exclusive full screen at launch, so
# Windows' taskbar can't sit over the game; F11 to a window and back.


func test_the_game_launches_in_exclusive_full_screen() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/mode"),
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "exclusive, not borderless")


func test_f11_is_bound() -> void:
	var keys: Array = InputMap.action_get_events(&"toggle_fullscreen").filter(
		func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_eq(keys.size(), 1, "one key")
	assert_eq((keys[0] as InputEventKey).physical_keycode, KEY_F11, "F11")


func test_full_screen_goes_to_a_window_and_back() -> void:
	assert_eq(FullscreenToggle.next_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN),
		DisplayServer.WINDOW_MODE_WINDOWED, "exclusive to a window")
	assert_eq(FullscreenToggle.next_mode(DisplayServer.WINDOW_MODE_FULLSCREEN),
		DisplayServer.WINDOW_MODE_WINDOWED, "borderless to a window")
	for mode: DisplayServer.WindowMode in [DisplayServer.WINDOW_MODE_WINDOWED,
			DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_MINIMIZED]:
		assert_eq(FullscreenToggle.next_mode(mode), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
			"%d to exclusive full screen" % mode)


func test_the_window_keeps_its_size_or_shrinks_to_fit_the_screen() -> void:
	assert_eq(FullscreenToggle.window_size_for(Vector2i(1280, 800), Vector2i(1920, 1032)),
		Vector2i(1280, 800), "fits: as set")
	assert_eq(FullscreenToggle.window_size_for(Vector2i(1280, 800), Vector2i(1366, 728)),
		Vector2i(1164, 728), "a short laptop screen: shrunk, kept in shape")
