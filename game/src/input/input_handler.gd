extends Node
class_name InputHandler

var actor: Actor


func setup(p_actor: Actor) -> void:
	actor = p_actor
	name = "InputHandler%s" % p_actor.actor_name


func _physics_process(_delta: float) -> void:
	actor.move(Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"))

