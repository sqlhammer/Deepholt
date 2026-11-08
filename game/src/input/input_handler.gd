extends Node
class_name InputHandler

var actor: Actor
var mouse_world_position: Callable
var current_device_scheme: DEVICE_SCHEME = DEVICE_SCHEME.GAMEPAD
# While a level change fades, the actor is stopped and input isn't
# read (D-142). Keys still held when it ends are read again then.
var paused: bool = false

# The game-wide keys. The handler only asks; the game decides what a
# save or a load is (R-P10).
signal quick_save_requested
signal load_requested
signal save_and_quit_requested

# Inside this distance from the feet the mouse's direction is
# mostly noise, so it counts as no aim and facing holds.
const MOUSE_DEAD_ZONE_PX: float = TileSpace.TILE_PIXELS / 2.0


enum DEVICE_SCHEME {
	NONE,
	GAMEPAD,
	MOUSE_AND_KEYBOARD,
}

func setup(p_actor: Actor, p_mouse_world_position: Callable) -> void:
	actor = p_actor
	name = "InputHandler%s" % p_actor.actor_name
	mouse_world_position = p_mouse_world_position


# The view's fade started: stop the actor, so it neither walks nor
# digs on a level the player can't see yet.
func pause() -> void:
	paused = true
	if actor == null: return
	actor.move(Vector2.ZERO)
	actor.primary_action(false)
	actor.breach(false)


func resume() -> void:
	paused = false


func _input(event: InputEvent) -> void:
	_update_device_scheme(event)
	
	if event.is_action_pressed("quick_save"):
		quick_save_requested.emit()
	if event.is_action_pressed("load"):
		load_requested.emit()
	if event.is_action_pressed("save_and_quit_to_desktop"):
		save_and_quit_requested.emit()


func _physics_process(_delta: float) -> void:
	if actor == null or actor is not Actor:
		return
	if paused: return
	
	var move: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	actor.move(move)
	actor.aim(_get_aim(), move)
	actor.primary_action(Input.is_action_pressed("primary_action"))
	# Its own input (D-153); InputMap has it once project.godot does
	if InputMap.has_action("breach"):
		actor.breach(Input.is_action_pressed("breach"))
	# A one-shot, polled here on the physics tick rather than handled
	# as an event, so the depth change it can cause happens on the same
	# tick as movement and digging (D-106). Read only here: reading it
	# in _process as well could count one press twice.
	if Input.is_action_just_pressed("interact"):
		actor.interact()


func _get_aim() -> Vector2:
	var aim: Vector2 = Vector2.ZERO
	
	if current_device_scheme == DEVICE_SCHEME.GAMEPAD:
		aim = Input.get_vector(
		"aim_left","aim_right","aim_up","aim_down")
		return aim
	
	if current_device_scheme == DEVICE_SCHEME.MOUSE_AND_KEYBOARD:
		var mouse_pos: Vector2 = mouse_world_position.call()
		aim = mouse_pos - actor.get_world_box().get_center()
		if aim.length() < MOUSE_DEAD_ZONE_PX:
			return Vector2.ZERO
		return aim.normalized()
	
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




































