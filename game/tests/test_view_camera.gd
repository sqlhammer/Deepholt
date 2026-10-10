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


# At a fractional camera offset the viewport's pixel centers can land
# exactly on texel boundaries, and columns of the level draw doubled
# (the x-axis flicker). The camera stays on whole pixels.
func test_camera_follows_on_whole_pixels() -> void:
	var camera: ViewCamera = autofree(ViewCamera.new())
	var actor: Actor = autofree(Actor.new())
	camera.actor = actor
	for position: Vector2 in [Vector2(40.5, -24.0), Vector2(40.25, 8.75), Vector2(-3.5, -0.4)]:
		actor.position = position
		camera._process(0.0)
		assert_eq(camera.position, position.round(),
			"actor at %s puts the camera on %s" % [position, position.round()])


# The camera covers the level; the actor's sprite can still sit at a
# fractional position, so the game viewport snaps what it draws.
func test_the_game_viewport_draws_on_whole_pixels() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	autofree(game)
	var view: SubViewport = game.get_node("GameViewport")
	assert_true(view.snap_2d_transforms_to_pixel,
		"GameViewport snaps 2D transforms to whole pixels")
