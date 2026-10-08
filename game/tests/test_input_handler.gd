extends GutTest

# InputHandler turns held movement actions into its actor's
# move_intent, every physics tick. Held movement is state, not an
# event: the intent stays while a key is held and is zero once it
# is released. It also picks the aim device from the last input
# seen, and turns the mouse into an aim direction with a dead zone.

const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"]

var _actor: Actor
var _handler: InputHandler
# Where the fake mouse points, in world pixels. The handler reads it
# through the Callable it is given, as it reads game.gd's in play.
var _mouse_at: Vector2 = Vector2.ZERO


func before_each() -> void:
	# From the scene, not Actor.new(): aim() turns the sprite, so the
	# actor needs its Sprite2D child.
	_actor = autofree(Global.actor_packed_scene.instantiate())
	_handler = autofree(InputHandler.new())
	_handler.setup(_actor, func() -> Vector2: return _mouse_at)


func after_each() -> void:
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)


func test_setup_gives_the_handler_its_actor() -> void:
	assert_eq(_handler.actor, _actor, "the handler drives the actor it was given")


# --- choosing the aim device ---

func _joy_motion(value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = value
	return event


func test_mouse_motion_switches_aim_to_the_mouse() -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.GAMEPAD
	_handler._input(InputEventMouseMotion.new())
	assert_eq(_handler.current_device_scheme,
		InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD, "moving the mouse aims with it")


func test_a_joypad_button_switches_aim_to_the_gamepad() -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	_handler._input(InputEventJoypadButton.new())
	assert_eq(_handler.current_device_scheme,
		InputHandler.DEVICE_SCHEME.GAMEPAD, "pressing a pad button aims with the pad")


func test_a_real_stick_push_switches_aim_to_the_gamepad() -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	_handler._input(_joy_motion(0.9))
	assert_eq(_handler.current_device_scheme,
		InputHandler.DEVICE_SCHEME.GAMEPAD, "a firm push takes aim")


func test_stick_drift_does_not_steal_aim_from_the_mouse() -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	_handler._input(_joy_motion(0.2))
	assert_eq(_handler.current_device_scheme,
		InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD, "a drifting stick is ignored")


func test_keyboard_input_does_not_change_the_aim_device() -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.GAMEPAD
	_handler._input(InputEventKey.new())
	assert_eq(_handler.current_device_scheme,
		InputHandler.DEVICE_SCHEME.GAMEPAD, "keys move, they don't aim")


# --- mouse aim ---

func _use_mouse_at(offset_from_feet: Vector2) -> void:
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	_mouse_at = _actor.get_world_box().get_center() + offset_from_feet


func test_mouse_aim_points_from_the_feet_to_the_mouse() -> void:
	_use_mouse_at(Vector2(40, 0))
	assert_almost_eq(_handler._get_aim(), Vector2.RIGHT, Vector2(0.001, 0.001),
		"a mouse to the right of the feet aims right, as a unit direction")


func test_mouse_aim_inside_the_dead_zone_is_no_aim() -> void:
	_use_mouse_at(Vector2(InputHandler.MOUSE_DEAD_ZONE_PX - 1.0, 0))
	assert_eq(_handler._get_aim(), Vector2.ZERO,
		"within half a tile of the feet the mouse doesn't aim (D-075)")


func test_mouse_aim_just_outside_the_dead_zone_aims() -> void:
	_use_mouse_at(Vector2(0, InputHandler.MOUSE_DEAD_ZONE_PX + 1.0))
	assert_almost_eq(_handler._get_aim(), Vector2.DOWN, Vector2(0.001, 0.001),
		"just past half a tile, the mouse aims")


func test_no_input_means_no_intent() -> void:
	_actor.move_intent = Vector2(1, 1)
	_handler._physics_process(0.0)
	assert_eq(_actor.move_intent, Vector2.ZERO,
		"releasing everything clears the intent")


func test_each_action_points_its_own_way() -> void:
	var expected: Dictionary = {
		&"move_left": Vector2.LEFT,
		&"move_right": Vector2.RIGHT,
		&"move_up": Vector2.UP,
		&"move_down": Vector2.DOWN,
	}
	for action: StringName in expected:
		Input.action_press(action)
		_handler._physics_process(0.0)
		assert_almost_eq(_actor.move_intent, expected[action], Vector2(0.001, 0.001),
			"%s should point %s" % [action, expected[action]])
		Input.action_release(action)


func test_intent_holds_while_the_key_is_held() -> void:
	Input.action_press(&"move_right")
	for tick in range(3):
		_handler._physics_process(0.0)
	assert_almost_eq(_actor.move_intent, Vector2.RIGHT, Vector2(0.001, 0.001),
		"a held key keeps its intent on every tick, not just the first")


func test_diagonals_are_not_faster() -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	_handler._physics_process(0.0)
	assert_almost_eq(_actor.move_intent.length(), 1.0, 0.001,
		"two keys together are capped at length 1, not 1.41")
	assert_gt(_actor.move_intent.x, 0.0, "and still point right")
	assert_gt(_actor.move_intent.y, 0.0, "and down")


func test_opposite_keys_cancel() -> void:
	Input.action_press(&"move_left")
	Input.action_press(&"move_right")
	_handler._physics_process(0.0)
	assert_eq(_actor.move_intent, Vector2.ZERO, "left and right together go nowhere")


func test_no_aim_device_means_no_aim() -> void:
	# A mouse far enough away to aim, if the mouse were the device.
	_use_mouse_at(Vector2(40, 0))
	_handler.current_device_scheme = InputHandler.DEVICE_SCHEME.NONE
	assert_eq(_handler._get_aim(), Vector2.ZERO,
		"with no aim device chosen, there is no aim, so facing holds")
