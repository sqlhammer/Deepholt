extends Node


func _ready() -> void:
	# Build surface / starting level
	var level = Global.level_packed_scene.instantiate()
	level.setup(0, TilePrefabRegistry.get_prefab(&"surface_start"))
	$Levels.add_child(level)
	
	$GameViewport/LevelRenderer.show_level(level.level_tiles)
	$GameViewport/ViewCamera.position = TileSpace.tile_center(Vector2i.ZERO)
	
	# Create player
	var actor_spawn_world_pos: WorldPos = WorldPos.new(level.anchor.x, level.anchor.y, level.depth)
	var actor: Actor = Actor.create(Global.actor_packed_scene, actor_spawn_world_pos)
	$GameViewport/Actors/Players.add_child(actor)
	
	# Attach input handling to the player
	var input: InputHandler = InputHandler.new()
	input.setup(actor)
	$GameViewport/Actors/Players.add_child(input)
	
	# Lock camera to player (actor)
	var view_camera: ViewCamera = get_view_camera()
	view_camera.actor = actor
	
	# Attach debug overlay
	$DebugOverlay.watch(actor)
	
	# Create all levels except for the surface
	level = Global.level_packed_scene.instantiate()
	level.setup(1)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(2)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(3)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(4)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(5)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(6)
	$Levels.add_child(level)
	
	level = Global.level_packed_scene.instantiate()
	level.setup(7)
	$Levels.add_child(level)


func get_view_camera() -> Camera2D:
	return $GameViewport/ViewCamera









