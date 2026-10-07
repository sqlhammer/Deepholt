extends Node
class_name InputHandler

var actor: Actor
var mouse_world_position: Callable
var current_device_scheme: DEVICE_SCHEME = DEVICE_SCHEME.GAMEPAD

enum DEVICE_SCHEME {
	NONE,
	GAMEPAD,
	MOUSE_AND_KEYBOARD,
}

func setup(p_actor: Actor, p_mouse_world_position: Callable) -> void:
	actor = p_actor
	name = "InputHandler%s" % p_actor.actor_name
	mouse_world_position = p_mouse_world_position


func _input(event: InputEvent) -> void:
	_update_device_scheme(event)


func _physics_process(_delta: float) -> void:
	actor.move(Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"))
	
	actor.primary_action(Input.is_action_pressed("primary_action"), _get_aim())


func _get_aim() -> Vector2:
	var aim: Vector2 = Vector2.ZERO
	
	if current_device_scheme == DEVICE_SCHEME.GAMEPAD:
		aim = Input.get_vector(
		"aim_left","aim_right","aim_up","aim_down")
		return aim
	
	if current_device_scheme == DEVICE_SCHEME.MOUSE_AND_KEYBOARD:
		var mouse_pos: Vector2 = mouse_world_position.call()
		aim = mouse_pos - actor.get_world_box().get_center()
		return aim
	
	return aim


func _update_device_scheme(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		current_device_scheme = DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	elif event is InputEventJoypadButton:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD
	# Only a real push counts: a drifting stick would otherwise
	# keep stealing aim from the mouse.
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD




















