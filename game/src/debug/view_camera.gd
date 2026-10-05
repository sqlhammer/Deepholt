extends Camera2D
class_name ViewCamera


var actor: Actor


# Lock the view camera to the character
func _process(_delta: float) -> void:
	if not actor: return
	
	position = actor.position
