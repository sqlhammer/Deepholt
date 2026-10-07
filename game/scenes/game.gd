extends Node


@onready var game_viewport: SubViewport = $GameViewport


func _ready() -> void:
	_spawn_levels()
	_spawn_player("DefaultName", 0)


func get_view_camera() -> Camera2D:
	return $GameViewport/ViewCamera


func _spawn_levels() -> void:
	for level in World.level_bounds.rows:
		_spawn_level(level.depth)


func _spawn_level(_depth: int) -> void:
	var level = Global.level_packed_scene.instantiate()
	var prefab: TilePrefab = null
	if _depth == 0: 
		prefab = TilePrefabRegistry.get_prefab(&"surface_start")
	level.setup(_depth, prefab)
	$Levels.add_child(level)


func _spawn_player(_name: String, _depth: int = 0) -> void:
	var level: Level = get_level(_depth)
	if not level: 
		push_error("Level (%d) not found. Could not spawn player." % _depth)
		return
	
	_create_player(_name, level)


func _create_player(_name: String, _level: Level) -> Actor:
	# Create player
	var actor_spawn_world_pos: WorldPos = WorldPos.new(_level.anchor.x, _level.anchor.y, _level.depth)
	var actor: Actor = Actor.create(Global.actor_packed_scene, _name, actor_spawn_world_pos)
	actor.add_to_group("players")
	$GameViewport/Actors/Players.add_child(actor)
	
	grant_player_capabilities(actor)
	set_user_control(actor)
	
	return actor


func grant_player_capabilities(actor: Actor) -> void:
	var dig_scene: PackedScene = Global.get_capability_packedscene(Global.CAPABILITY.DIG)
	var dig_capability: CapabilityDig = dig_scene.instantiate()
	actor.get_node("Capabilities").add_child(dig_capability)


func set_user_control(actor: Actor) -> void:
	# Attach input handling to the player
	var input: InputHandler = InputHandler.new()
	input.setup(actor, mouse_world_position)
	$GameViewport/Actors/Players.add_child(input)
	
	# Lock camera to player (actor)
	$GameViewport/LevelRenderer.show_level(get_level(actor.depth).level_tiles)
	var view_camera: ViewCamera = get_view_camera()
	view_camera.actor = actor
	
	# Attach debug overlay
	$DebugOverlay.watch(actor)


func get_level(_depth: int) -> Level:
	var level: Level = null
	for lvl in get_tree().get_nodes_in_group("levels"):
		if lvl.depth == _depth:
			level = lvl
			break
	return level


# Where the mouse points in world space (level pixels).
# Presentation: it needs the display rect and the game viewport's camera.
func mouse_world_position() -> Vector2:
	var display: TextureRect = $Display/UpscaleDisplay
	var view: SubViewport = $GameViewport
	var view_size: Vector2 = Vector2(view.size)
	var scale: float = minf(display.size.x / view_size.x,
		display.size.y / view_size.y)
	var letterbox: Vector2 = (display.size - view_size * scale) / 2.0
	var view_px: Vector2 = (display.get_local_mouse_position() - letterbox) / scale
	return view.get_canvas_transform().affine_inverse() * view_px


# This is needed so that my _input funcs inside the viewport 
# fire for input that the Game scene owns.
func _unhandled_input(event: InputEvent) -> void:
	game_viewport.push_input(event)













