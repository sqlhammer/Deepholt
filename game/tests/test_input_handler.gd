extends GutTest

# InputHandler turns held movement actions into its actor's
# move_intent, every physics tick. Held movement is state, not an
# event: the intent stays while a key is held and is zero once it
# is released.

const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"]

var _actor: Actor
var _handler: InputHandler


func before_each() -> void:
	_actor = autofree(Actor.new())
	_handler = autofree(InputHandler.new())
	_handler.setup(_actor)


func after_each() -> void:
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)


func test_setup_gives_the_handler_its_actor() -> void:
	assert_eq(_handler.actor, _actor, "the handler drives the actor it was given")


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
