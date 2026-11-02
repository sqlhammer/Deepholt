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
@export var tuning_profile_id: String
# Where this session's world came from (D-111): F3 shows it
var load_source: SaveGame.SOURCE = SaveGame.SOURCE.NEW
# Set when neither save in the slot loaded: the game hasn't started,
# and saving would write over the files the player needs back
var _saving_refused: bool = false
# --new-game, after -- on the command line or in the editor's run
# arguments, starts a fresh world (D-111). Set it before _ready to
# choose; tests do.
var new_game: bool = OS.get_cmdline_user_args().has("--new-game")
var _autosave_timer: Timer
# How long the last save and the last load took, from the game's side:
# the whole world, read or written
var last_save_msec: float = -1.0
var last_load_msec: float = -1.0

# How often the game saves while playing (D-110). A tuning number: the
# first to move into the tuning profile when it's built (D-116).
const AUTOSAVE_INTERVAL_SECONDS: float = 300.0

enum REFUSAL_REASON {
	NONE,
	LOAD_FAILED_NO_OP,
	# Saves were found and none could be loaded (D-111)
	LOAD_REFUSED,
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
	# The view only announces a depth that changed, so a load onto the
	# depth already shown would leave the fixtures drawn from the old
	# world, and listening to it (R-B9)
	if view.shown_depth != View.NO_DEPTH:
		$GameViewport/FixtureRenderer.show_depth(view.shown_depth)


func grant_player_capabilities(actor: Actor) -> void:
	var dig_scene: PackedScene = Global.get_capability_packedscene(Global.CAPABILITY.DIG)
	var dig_capability: CapabilityDig = dig_scene.instantiate()
	dig_capability.actor = actor
	actor.get_node("Capabilities").add_child(dig_capability)


func set_user_control(actor: Actor) -> void:
	_active_actor = actor
	
	# Attach input handling to the player
	var input: InputHandler = InputHandler.new()
	input.setup(actor, mouse_world_position)
	input.quick_save_requested.connect(save_game)
	input.load_requested.connect(load_game)
	input.save_and_quit_requested.connect(save_and_quit_to_desktop)
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
	if _saving_refused: return false
	if current_save_slot == "":
		# Create a slot if none exist yet.
		# This should not happen after we have a game menu because
		# a game should not be created without creating and setting vars for
		# the slot for it to save to.
		SaveGame.setup(saves_root)
		_set_current_save_slot()
		if current_save_slot == "": return false
	
	# Levels
	var levels: Array[Level] = []
	for level in get_tree().get_nodes_in_group("levels"):
		if level is Level: levels.append(level)
	
	# Actors
	var actors: Array[Node] = get_tree().get_nodes_in_group("actors")
	
	# Game Stats
	var active_play_time: float = $ActivePlayTimer.seconds
	var total_play_time: float = $TotalPlayTimer.seconds
	
	# Save, timed: F3 shows whether it's short enough to go unfelt
	# mid-play (D-110)
	var started: int = Time.get_ticks_usec()
	var result = SaveGame.save_game(current_save_slot, levels, actors, active_actor, WorldAutoload.world_seed, tuning_profile_id, active_play_time, total_play_time, saves_root)
	last_save_msec = (Time.get_ticks_usec() - started) / 1000.0
	$DebugOverlay.show_save_time(last_save_msec)
	if result != SaveGame.REFUSAL_REASON.NONE:
		return false
	
	return true


# Core principle: we don't want to update existing objects. Instead, we will
# build new objects and replace them if they have already loaded into the game.
# This will prevent merge issues
func load_game() -> REFUSAL_REASON:
	if current_save_slot == "": 
		return REFUSAL_REASON.LOAD_FAILED_NO_OP
	
	var started: int = Time.get_ticks_usec()
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(current_save_slot)
	if slot.source == SaveGame.SOURCE.NEW: return REFUSAL_REASON.LOAD_FAILED_NO_OP
	if slot.source == SaveGame.SOURCE.REFUSED:
		_report_refused_slot(slot)
		return REFUSAL_REASON.LOAD_REFUSED
	var game_data: Dictionary = slot.game_data
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
	Objects.reserve_ids_through(SaveGame.highest_fixture_id(_lvls))
	
	# Trigger the view to refresh the tiles
	if not view: _create_view()
	refresh_current_view()
	
	# load objects
	
	
	# load actors
	var raw_id: Variant = game_data.get("local_actor_id", -1)
	var local_actor_id: int = int(raw_id) if raw_id is int or raw_id is float else -1
	_load_actors(game_data.actors, local_actor_id)
	
	# load stats
	if game_data.has("stats"):
		if game_data.stats.has("active_play_time"):
			$ActivePlayTimer.setup(game_data.stats.active_play_time)
		if game_data.stats.has("total_play_time"):
			$TotalPlayTimer.setup(game_data.stats.total_play_time)
	
	
	$DebugOverlay.show_load_problems(game_data.get("problems", []).size())
	load_source = slot.source
	last_load_msec = (Time.get_ticks_usec() - started) / 1000.0
	$DebugOverlay.show_load_time(last_load_msec)
	if slot.source == SaveGame.SOURCE.BACKUP: _report_backup_load(slot)
	$DebugOverlay.show_load_source(load_source, game_data.format_version)
	return REFUSAL_REASON.NONE


# Loud, and it stays loud: an error, a message that stays on screen,
# and F3 (D-111).
func _report_backup_load(slot: SaveGame.SlotLoad) -> void:
	var text: String = "Loaded the backup save, %s.\n" % _shown_path(
		current_save_slot.path_join(SaveGame.BACKUP_NAME))
	if slot.refusals:
		text += "The save was refused: %s.\n" % _shown_refusal(slot.refusals[0])
	else:
		text += "There was no world.save beside it.\n"
	if slot.broken_path:
		text += "It's kept as %s." % _shown_path(slot.broken_path)
	push_error(text)
	show_notice(text)


func _report_refused_slot(slot: SaveGame.SlotLoad) -> void:
	var text: String = "No save could be loaded, so the game hasn't started.\n"
	for refusal: String in slot.refusals:
		text += "%s.\n" % _shown_refusal(refusal)
	text += "Both files are left as they were. Launch with --new-game to move them aside and start a new world."
	push_error(text)
	show_notice(text)


# A path as the player finds it on disk, not as user://
func _shown_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _shown_refusal(refusal: String) -> String:
	return refusal.replace(current_save_slot, _shown_path(current_save_slot))


# A message that stays on screen for the rest of the session, over the
# game, whether F3 is up or not.
func show_notice(text: String) -> void:
	var label: Label = get_node_or_null("SaveNotice/Label")
	if label == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "SaveNotice"
		layer.layer = 100
		add_child(layer)
		label = Label.new()
		label.name = "Label"
		label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		layer.add_child(label)
	label.text = text


# The notice on screen, or "" if there's none.
func notice_text() -> String:
	var label: Label = get_node_or_null("SaveNotice/Label")
	return label.text if label else ""


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
	$DebugOverlay.game = self
	$DebugOverlay.connect_timers($ActivePlayTimer, $TotalPlayTimer)
	$ActivePlayTimer.start() # TODO: When we have a main menu, don't start until the game has loaded and is playable
	
	_set_current_save_slot()
	if new_game:
		if not _move_old_world_aside():
			_refuse_to_start()
			return
	else:
		var loaded: REFUSAL_REASON = load_game()
		if loaded == REFUSAL_REASON.NONE:
			_start_autosave()
			return
		# No world, and no saving: the refused files stay as they are
		if loaded == REFUSAL_REASON.LOAD_REFUSED:
			_refuse_to_start()
			return

	load_source = SaveGame.SOURCE.NEW
	$DebugOverlay.show_load_source(load_source, SaveGame.FORMAT_VERSION)
	_spawn_levels()
	_create_view()
	_spawn_player("DefaultName")
	_start_autosave()


func _refuse_to_start() -> void:
	_saving_refused = true
	load_source = SaveGame.SOURCE.REFUSED
	$DebugOverlay.show_load_source(load_source, -1)


# A new game keeps the old world beside it, never under it, before
# anything is generated: world.save becomes world.<time>.save, and its
# backup world.backup.<time>.save (D-111, D-123). Refused saves are
# moved the same way. False if a file couldn't be moved: the game
# mustn't start over a world it couldn't keep.
func _move_old_world_aside() -> bool:
	if current_save_slot == "": return true
	var now: int = int(Time.get_unix_time_from_system())
	var moves: Dictionary = {SaveGame.SAVE_BASE_NAME: "", SaveGame.BACKUP_NAME: "backup"}
	for file: String in moves:
		var path: String = current_save_slot.path_join(file)
		if not FileAccess.file_exists(path): continue
		if SaveGame.move_aside(path, moves[file], now) == "":
			var text: String = "Couldn't move %s aside for a new game, so the game hasn't started." % [
				_shown_path(path)]
			push_error(text)
			show_notice(text)
			return false
	return true


# Saves on a timer while playing (D-110). Pausable, so a paused game
# doesn't save, and only started once there's a world.
func _start_autosave() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SECONDS
	_autosave_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)
	_autosave_timer.start()


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
	_attach_levels(LevelGenerator.generate_levels(LevelRecipes.TABLE))


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


# Out of the tree now, freed at the end of the frame: the debug load
# key reaches here from inside a handler's own _input, and freeing the
# handler there would free it with its code still running (R-B8).
func _free_inputhandlers() -> void:
	for handler in _input_handlers:
		if not is_instance_valid(handler): continue
		if handler.get_parent(): handler.get_parent().remove_child(handler)
		handler.queue_free()
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
func _load_actors(actors: Dictionary, local_actor_id: int) -> void:
	for key in actors:
		# skip header data
		if actors[key] is not Dictionary: continue
		if not actors[key].has("actor_obj"): continue
	
		var actor: Actor = actors[key].actor_obj
		_move_if_stuck(actor)
		_create_actor(actor)
	
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


func get_active_play_time() -> String:
	return $ActivePlayTimer._to_string()


func get_total_play_time() -> String:
	return $TotalPlayTimer._to_string()
















