extends Camera2D
class_name ViewCamera


var actor: Actor


# Lock the view camera to the character, on whole pixels. At a
# fractional offset the viewport's pixel centers can land exactly on
# a boundary between two texels, where nearest sampling is a coin
# flip, and columns of the level draw doubled: the flicker seen when
# walking along x.
func _process(_delta: float) -> void:
	if not actor: return

	position = actor.position.round()
