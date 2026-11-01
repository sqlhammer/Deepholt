extends Node


@onready var game_viewport: SubViewport = $GameViewport

var view: View
# The folder every save slot sits in. Set it before _ready to point
# the game elsewhere; tests do, so they never touch real saves.
var saves_root: String = SaveGame.SAVES_DIR
var save_slots: PackedStringArray
var current_save_slot: String
var active_actor: Actor:
	get: return _active_actor
var _active_actor: Actor
var _input_handlers: Array[InputHandler] = []

enum REFUSAL_REASON {
	NONE,
	LOAD_FAILED_NO_OP,
}


func get_view_camera() -> Camera2D:
	return $GameViewport/ViewCamera


func get_level_renderer() -> LevelRenderer:
	return $GameViewport/LevelRenderer


func refresh_current_view() -> void:
	for _lvl in get_tree().get_nodes_in_group("levels"):
		if _lvl is not Level: continue
		if _lvl.depth == view.shown_depth:
			get_level_renderer().show_level(_lvl.level_tiles)
			break


func grant_player_capabilities(actor: Actor) -> void:
	var dig_scene: PackedScene = Global.get_capability_packedscene(Global.CAPABILITY.DIG)
	var dig_capability: CapabilityDig = dig_scene.instantiate()
	dig_capability.actor = actor
	actor.get_node("Capabilities").add_child(dig_capability)


func set_user_control(actor: Actor) -> void:
	_active_actor = actor
	
	# Attach input handling to the player
	var input: InputHandler = InputHandler.new()
	input.setup(actor, mouse_world_position, self)
	add_child(input)
	_input_handlers.append(input)
	
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
	if current_save_slot == "": 
		# Create a slot if none exist yet.
		# This should not happen after we have a game menu because
		# a game should not be created without creating and setting vars for
		# the slot for it to save to.
		SaveGame.setup(saves_root)
		_set_current_save_slot()
		if current_save_slot == "": return false
	
	var levels: Array[Level] = []
	for level in get_tree().get_nodes_in_group("levels"):
		if level is Level: levels.append(level)
	
	var actors: Array[Node] = get_tree().get_nodes_in_group("actors")
	var result = SaveGame.save_game(current_save_slot, levels, actors, active_actor, saves_root)
	if result != SaveGame.REFUSAL_REASON.NONE:
		return false
	
	return true


# Core principle: we don't want to update existing objects. Instead, we will
# build new objects and replace them if they have already loaded into the game.
# This will prevent merge issues
func load_game() -> REFUSAL_REASON:
	if current_save_slot == "": 
		return REFUSAL_REASON.LOAD_FAILED_NO_OP
	
	var game_data: Dictionary = SaveGame.load_game(current_save_slot)
	if not game_data: return REFUSAL_REASON.LOAD_FAILED_NO_OP
	# The data holds nodes nothing else frees; refusing it frees them
	if not _is_valid_game_data(game_data):
		SaveGame.free_game_data(game_data)
		return REFUSAL_REASON.LOAD_FAILED_NO_OP
	
	
	# Pause game and handle visual transition/loading indicator
	
	
	# clean up objects
	_free_actors()
	_free_levels()
	_free_inputhandlers()
	
	# load levels
	var _lvls: Array[Level] = _get_levels_from_save_data(game_data)
	_attach_levels(_lvls)
	
	# Trigger the view to refresh the tiles
	if not view: _create_view()
	refresh_current_view()
	
	# load objects
	
	
	# load actors
	_load_actors(game_data.actors)
	
	$DebugOverlay.show_load_problems(game_data.get("problems", []).size())
	return REFUSAL_REASON.NONE


func _is_valid_game_data(game_data: Dictionary) -> bool:
	if not game_data.has("format_version"): return false
	if not game_data.has("levels"): return false
	if not game_data.has("actors"): return false
	if game_data.actors.size() < 1: return false
	
	return true


func save_and_quit_to_desktop() -> void:
	_prepare_then_quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_prepare_then_quit()


func _ready() -> void:
	_set_current_save_slot()
	if load_game() == REFUSAL_REASON.NONE: return
	
	_spawn_levels()
	_create_view()
	_spawn_player("DefaultName")


func _prepare_then_quit() -> void:
	save_game()
	get_tree().quit()


func _create_view() -> void:
	view = View.new()
	view.name = "View"
	add_child(view)
	$GameViewport/LevelRenderer.watch(view)
	$GameViewport/FixtureRenderer.watch(view)
	$DebugOverlay.watch_view(view)


# Every level is built from its depth's recipe (D-084); the scene only
# decides where they live.
func _spawn_levels() -> void:
	_attach_levels(LevelGenerator.generate_levels(World.level_recipes))


func _attach_levels(levels: Array[Level]) -> void:
	for level: Level in levels:
		$Levels.add_child(level)
		level.level_tiles.tiles_replaced.emit(level.level_tiles)


func _set_current_save_slot() -> void:
	save_slots = SaveGame.get_save_slots(saves_root)
	if save_slots.size() > 0:
		current_save_slot = save_slots[0]


func _get_levels_from_save_data(data: Dictionary) -> Array[Level]:
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
	# Nothing may reach the freed player, a save least of all
	_active_actor = null


func _free_inputhandlers() -> void:
	for handler in _input_handlers:
		if is_instance_valid(handler): handler.free()
	_input_handlers.clear()


func _spawn_player(_name: String) -> void:
	var tile: WorldPos = Spawning.spawn_tile_for(null, _levels(), _actors())
	if tile == null:
		push_error("Nowhere to spawn %s." % _name)
		return
	var actor = Actor.create(Global.actor_packed_scene, _name, tile, _level_at(tile.depth), ActorKind.ACTOR.PLAYER)
	
	_create_actor(actor)
	set_user_control(actor)


func _levels() -> Array[Level]:
	var levels: Array[Level] = []
	for child in $Levels.get_children():
		if child is Level: levels.append(child)
	return levels


func _level_at(depth: int) -> Level:
	for level: Level in _levels():
		if level.depth == depth: return level
	return null


func _players() -> Array[Actor]:
	var actors: Array[Actor] = []
	for child in $GameViewport/Actors/Players.get_children():
		if child is Actor: actors.append(child)
	return actors


func _actors() -> Array[Actor]:
	var actors: Array[Actor] = []
	for node in get_tree().get_nodes_in_group("actors"):
		if node is Actor: actors.append(node as Actor)
	return actors


func _create_actor(actor: Actor) -> Actor:
	match actor.actor_kind:
		ActorKind.ACTOR.NULL:
			$GameViewport/Actors/NPCs.add_child(actor)
		ActorKind.ACTOR.PLAYER:
			actor.add_to_group("players")
			$GameViewport/Actors/Players.add_child(actor)
			grant_player_capabilities(actor)
	
	view.track(actor)
	actor.actor_worldpos_changed.connect(_on_actor_moved)

	return actor


# Any actor changing level saves the game (D-110). The signal comes
# once the actor has arrived, so the save has it on the new level.
func _on_actor_moved(_actor: Actor, old_pos: WorldPos, new_pos: WorldPos) -> void:
	if old_pos == null or new_pos == null: return
	if old_pos.depth == new_pos.depth: return
	save_game()


# Each saved actor joins the game on its saved tile. One stuck on a
# tile that's no longer passable is moved to the spawn first, before
# anything listens to it: a move across a depth would save the world
# this load is still building (D-115, D-119). Then exactly one player
# is given to the user.
func _load_actors(actors: Dictionary) -> void:
	for key in actors:
		# skip header data
		if actors[key] is not Dictionary: continue
		if not actors[key].has("actor_obj"): continue
	
		var actor: Actor = actors[key].actor_obj
		_move_if_stuck(actor)
		_create_actor(actor)
	
	var local_actor_id: Variant = actors.get("local_actor_id", -1)
	if local_actor_id is not int: local_actor_id = -1
	var local: Actor = _local_player(local_actor_id)
	if local: set_user_control(local)


# By the path a new player takes, avoiding the actors already placed
# (D-091). With nowhere to go, it stays where it is, loudly.
func _move_if_stuck(actor: Actor) -> void:
	var stuck: WorldPos = actor.current_WorldPos
	var tiles: LevelTiles = actor.current_level.level_tiles
	if TileKind.is_passable(tiles.get_top(stuck.x, stuck.y), tiles.get_ground(stuck.x, stuck.y)):
		return
	
	var target: WorldPos = Spawning.spawn_tile_for(null, _levels(), _actors())
	if target == null or not actor.move_to(target):
		push_error("%s is stuck on %s, which is impassable, with nowhere to go." % [
			actor.actor_name, stuck])
		return
	push_warning("%s was on %s, which is impassable; moved to the world spawn at %s." % [
		actor.actor_name, stuck, target])


# The player the save names as local (D-115). A missing id, or one
# that names no loaded player, falls back to the lowest-id player,
# with a warning.
func _local_player(local_actor_id: int) -> Actor:
	var players: Array[Actor] = _players()
	if players.is_empty():
		push_error("The save has no player to control.")
		return null
	
	var lowest: Actor = players[0]
	for player: Actor in players:
		if player.actor_id == local_actor_id: return player
		if player.actor_id < lowest.actor_id: lowest = player
	
	push_warning("The save's local actor %d isn't a loaded player; %s (%d) is local instead." % [
		local_actor_id, lowest.actor_name, lowest.actor_id])
	return lowest



















