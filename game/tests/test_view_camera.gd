extends GutTest

# ViewCamera follows whichever actor it is given, and does nothing
# when it has none.


func test_camera_moves_to_its_actor() -> void:
	var camera: ViewCamera = autofree(ViewCamera.new())
	var actor: Actor = autofree(Actor.new())
	actor.position = Vector2(40, -24)
	camera.actor = actor
	camera._process(0.0)
	assert_eq(camera.position, Vector2(40, -24), "the camera sits on the actor")


func test_camera_without_an_actor_stays_put() -> void:
	var camera: ViewCamera = autofree(ViewCamera.new())
	camera.position = Vector2(8, 8)
	camera._process(0.0)
	assert_eq(camera.position, Vector2(8, 8), "no actor, no movement")
