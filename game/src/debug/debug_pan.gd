extends Camera2D

# THROWAWAY -- moves the view with the arrow keys or left stick, so tile
# edges can be watched in motion at 2.5x. The upscale shader is verified
# by panning, not by screenshot (art-and-camera s3). Delete when section
# D's actor carries the camera.

# Deliberately not a whole number of pixels per frame: a speed that is
# would hide the edge crawl this exists to show.
@export var pan_speed: float = 37.3

# Held Shift multiplies the speed, to reach the level's rim (about 90
# tiles out at Surface) without waiting forty seconds.
@export var fast_pan_multiplier: float = 8.0


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down")
	var speed: float = pan_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed = pan_speed * fast_pan_multiplier
	var step: Vector2 = direction * speed * delta
	position += step
