extends Node


@onready var game_viewport: SubViewport = $GameViewport

# What is on screen: follows the locally controlled actor (D-094).
var view: View
var save_slots: PackedStringArray
var current_save_slot: String


enum REFUSAL_REASON {
	NONE,
	LOAD_FAILED_NO_OP,
}


func _ready() -> void:
	SaveGame.setup()
	save_slots = SaveGame.get_save_slots()
	if save_slots.size() > 0:
		current_save_slot = save_slots[0]
	_spawn_levels()
	_create_view()
	_spawn_player("DefaultName")


func _create_view() -> void:
	view = View.new()
	view.name = "View"
	add_child(view)
	$GameViewport/LevelRenderer.watch(view)
	$GameViewport/FixtureRenderer.watch(view)
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
	input.setup(actor, mouse_world_position, self)
	add_child(input)
	
	# The screen shows this actor's depth, and follows it (D-094)
	view.follow(actor)

	# Lock camera to player (actor)
	var view_camera: ViewCamera = get_view_camera()
	view_camera.actor = actor
	
	# Attach debug overlay
	$DebugOverlay.watch(actor)


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


func save_game() -> bool:
	var levels: Array[Level] = []
	for level in get_tree().get_nodes_in_group("levels"):
		if level is Level: levels.append(level)
	
	var result = SaveGame.save_game(current_save_slot, levels)
	if result != SaveGame.REFUSAL_REASON.NONE:
		return false
	
	return true


# Core principle: we don't want to update existing objects. Instead, we will
# build new objects and replace them if they have already loaded into the game.
# This will prevent merge issues and it will set us up for the future when
# the game is not loaded on start-up but is, instead, loaded after the main menu.
func load_game() -> REFUSAL_REASON:
	if current_save_slot == "": return REFUSAL_REASON.LOAD_FAILED_NO_OP
	
	var game_data: Dictionary = SaveGame.load_game(current_save_slot)
	if not game_data.has("format_version"): return REFUSAL_REASON.LOAD_FAILED_NO_OP
	if not game_data.has("levels"): return REFUSAL_REASON.LOAD_FAILED_NO_OP
	
	
	# clean up objects dependent on level
	_free_actors()
	
	# load levels
	_free_levels()
	var _lvls: Array[Level] = _get_levels_from_save_data(game_data)
	_attach_levels(_lvls)
	
	# Trigger the view to refresh the tiles
	# TODO: Make a func for this
	for _lvl in _lvls:
		if _lvl.depth == view.shown_depth:
			$GameViewport/LevelRenderer.show_level(_lvl.level_tiles)
	
	# load objects
	
	
	# load NPCs
	
	
	# load actors
	_spawn_player("DefaultName") #TODO: Replace with actual loaded actor later
	
	
	return REFUSAL_REASON.NONE


# Every level is built from its depth's recipe (D-084); the scene only
# decides where they live.
func _spawn_levels() -> void:
	_attach_levels(LevelGenerator.generate_levels(World.level_recipes))


func _attach_levels(levels: Array[Level]) -> void:
	for level: Level in levels:
		$Levels.add_child(level)
		level.level_tiles.tiles_replaced.emit(level.level_tiles)


func _get_levels_from_save_data(data: Dictionary) -> Array[Level]:
	# TODO: Rethink this. All it's doing is changing from Dict to Array
	
	if not data.has("levels"): return []
	var levels: Array[Level] = []
	
	for key in data.levels:
		levels.append(data.levels[key])
	
	return levels


func _free_levels() -> void:
	for level in get_tree().get_nodes_in_group("levels"):
		if level is not Level: continue
		level.free()


func _free_actors() -> void:
	for actor in get_tree().get_nodes_in_group("actors"):
		if actor is not Actor: continue
		actor.free()


# A new player appears at the world's default spawn, or the nearest
# free tile to it (D-091). Players have no spawn points of their own
# yet; beds bring them.
func _spawn_player(_name: String) -> void:
	var tile: WorldPos = Spawning.spawn_tile_for(null, _levels(), _players())
	if tile == null:
		push_error("Nowhere to spawn %s." % _name)
		return

	_create_player(_name, tile)


func _levels() -> Array[Level]:
	var levels: Array[Level] = []
	for child in $Levels.get_children():
		if child is Level: levels.append(child)
	return levels


func _players() -> Array[Actor]:
	var actors: Array[Actor] = []
	for child in $GameViewport/Actors/Players.get_children():
		if child is Actor: actors.append(child)
	return actors


func _create_player(_name: String, tile: WorldPos) -> Actor:
	# Create player
	var actor: Actor = Actor.create(Global.actor_packed_scene, _name, tile)
	actor.add_to_group("players")
	$GameViewport/Actors/Players.add_child(actor)
	view.track(actor)
	
	grant_player_capabilities(actor)
	set_user_control(actor)
	
	return actor






















