extends Node


@onready var game_viewport: SubViewport = $GameViewport

# What is on screen: follows the locally controlled actor (D-094).
var view: View


func _ready() -> void:
	_spawn_levels()
	_create_view()
	_spawn_player("DefaultName", 0)


func _create_view() -> void:
	view = View.new()
	view.name = "View"
	add_child(view)
	$GameViewport/LevelRenderer.watch(view)
	$DebugOverlay.watch_view(view)


func get_view_camera() -> Camera2D:
	return $GameViewport/ViewCamera


func grant_player_capabilities(actor: Actor) -> void:
	var dig_scene: PackedScene = Global.get_capability_packedscene(Global.CAPABILITY.DIG)
	var dig_capability: CapabilityDig = dig_scene.instantiate()
	dig_capability.actor = actor
	actor.get_node("Capabilities").add_child(dig_capability)


func set_user_control(actor: Actor) -> void:
	# Attach input handling to the player
	var input: InputHandler = InputHandler.new()
	input.setup(actor, mouse_world_position)
	add_child(input)
	
	# The screen shows this actor's depth, and follows it (D-094)
	view.follow(actor)

	# Lock camera to player (actor)
	var view_camera: ViewCamera = get_view_camera()
	view_camera.actor = actor
	
	# Attach debug overlay
	$DebugOverlay.watch(actor)

	# Throwaway: '-' / '=' change depth until ramps and
	# ladders do (slice 002, section B)
	var debug_depth: DebugDepth = DebugDepth.new()
	debug_depth.setup(actor)
	add_child(debug_depth)


# Where the mouse points in world space (level pixels).
# Presentation: it needs the display rect and the game viewport's camera.
func mouse_world_position() -> Vector2:
	var display: TextureRect = $Display/UpscaleDisplay
	var _view: SubViewport = $GameViewport
	var view_size: Vector2 = Vector2(_view.size)
	var scale: float = minf(display.size.x / view_size.x,
		display.size.y / view_size.y)
	var letterbox: Vector2 = (display.size - view_size * scale) / 2.0
	var view_px: Vector2 = (display.get_local_mouse_position() - letterbox) / scale
	return _view.get_canvas_transform().affine_inverse() * view_px


# Every level is built from its depth's recipe (D-084); the scene only
# decides where they live.
func _spawn_levels() -> void:
	for level: Level in LevelGenerator.generate_levels(World.level_recipes):
		$Levels.add_child(level)


func _spawn_player(_name: String, _depth: int = 0) -> void:
	var level: Level = World.get_level_by_depth(_depth)
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
	view.track(actor)
	
	grant_player_capabilities(actor)
	set_user_control(actor)
	
	return actor






















