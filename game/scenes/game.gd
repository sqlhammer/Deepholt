extends Node


@onready var game_viewport: SubViewport = $GameViewport

var view: View
# The world being played, inside GameViewport at the origin (D-128).
# Handed by reference to whatever needs it; nothing looks it up.
var world: World
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
# A new world's seed, hashed. One fixed seed until there is a menu to
# choose one.
const WORLD_SEED_TEXT: String = "Default Seed"

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
	input.load_requested.connect(_on_load_requested)
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


# Where the mouse points in world space (level pixels). Presentation:
# it needs the display rect and the game viewport's camera.
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
	
	# What isn't the world's (D-130)
	var local_actor_id: int = active_actor.actor_id if active_actor else -1
	var session: SaveSession = SaveSession.new(local_actor_id, tuning_profile_id,
		$ActivePlayTimer.seconds, $TotalPlayTimer.seconds)

	# Save, timed: F3 shows whether it's short enough to go unfelt
	# mid-play (D-110)
	var started: int = Time.get_ticks_usec()
	var result: SaveGame.REFUSAL_REASON = SaveGame.save_game(current_save_slot, world, session,
		saves_root)
	last_save_msec = (Time.get_ticks_usec() - started) / 1000.0
	$DebugOverlay.show_save_time(last_save_msec)
	if result != SaveGame.REFUSAL_REASON.NONE:
		return false
	
	return true


# The F6 key. It arrives from inside an input handler's _input, so the
# world is built now and swapped in at the end of the frame, when no
# handler or actor code is running (D-129, trap 4).
func _on_load_requested() -> void:
	load_game(true)


# Nothing running is changed: a new world is built to one side and the
# old one replaced whole (D-118). In phases (R-S1): SaveGame validates
# the file and builds the world outside the tree; then it is swapped
# in; then the view re-points everything that draws to it (D-129). A
# refusal stops before the swap, so the running world, the screen, F3
# and the ids are as they were. `defer_swap` puts the swap at the end
# of the frame.
func load_game(defer_swap: bool = false) -> REFUSAL_REASON:
	if current_save_slot == "":
		return REFUSAL_REASON.LOAD_FAILED_NO_OP

	# Validate and build
	var started: int = Time.get_ticks_usec()
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(current_save_slot)
	if slot.source == SaveGame.SOURCE.NEW: return REFUSAL_REASON.LOAD_FAILED_NO_OP
	if slot.source == SaveGame.SOURCE.REFUSED:
		_report_refused_slot(slot)
		return REFUSAL_REASON.LOAD_REFUSED
	var loaded: SaveGame.LoadedGame = slot.loaded
	var session: SaveSession = loaded.session

	# Swap, then re-point
	if defer_swap:
		_swap_in_loaded_world.call_deferred(loaded.world, session.local_actor_id)
	else:
		_swap_in_loaded_world(loaded.world, session.local_actor_id)

	# A clock the save left out is -1, and keeps its count (D-120)
	if session.active_play_time >= 0.0:
		$ActivePlayTimer.setup(session.active_play_time)
	if session.total_play_time >= 0.0:
		$TotalPlayTimer.setup(session.total_play_time)

	$DebugOverlay.show_load_problems(loaded.problems.size())
	load_source = slot.source
	last_load_msec = (Time.get_ticks_usec() - started) / 1000.0
	$DebugOverlay.show_load_time(last_load_msec)
	if slot.source == SaveGame.SOURCE.BACKUP: _report_backup_load(slot)
	$DebugOverlay.show_load_source(load_source, loaded.header.format_version)
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
	# Mid-session (F6), the running world carries on (D-111)
	if world != null:
		text = "No save could be loaded; the world you're in is unchanged.\n"
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


func save_and_quit_to_desktop() -> void:
	_prepare_then_quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_prepare_then_quit()


func _ready() -> void:
	$DebugOverlay.game = self
	$DebugOverlay.connect_timers($ActivePlayTimer, $TotalPlayTimer)
	# TODO: When we have a main menu, don't start until the game has
	# loaded and is playable.
	$ActivePlayTimer.start()
	
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
	_swap_world(LevelGenerator.generate_world(hash(WORLD_SEED_TEXT)))
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


# The one way a world comes in, at launch, for a new game and on a
# load (D-129): input goes, the old world is freed with everything in
# it, and the new one is added. The view is told the new world at its
# spawn's depth, and through it the renderers and F3, whether or not
# a player is then given control (D-132).
func _swap_world(new_world: World) -> void:
	_free_inputhandlers()
	_free_world()
	_attach_world(new_world)
	if view == null: _create_view()
	view.show_world(world, Spawning.world_spawn_depth(world.levels()))


# A loaded world's swap. It arrives with its actors (D-127). One stuck
# on a tile that's no longer passable is moved to the spawn before the
# game listens to it: a move across a depth would save the world
# mid-swap (D-115, D-119). Then exactly one player is given to the
# user.
func _swap_in_loaded_world(new_world: World, local_actor_id: int) -> void:
	_swap_world(new_world)
	for actor: Actor in world.actors():
		_move_if_stuck(actor)
	for actor: Actor in world.actors():
		_take_actor(actor)
	var local: Actor = _local_player(local_actor_id)
	if local: set_user_control(local)


# Puts a world built outside the tree at the origin inside the game
# viewport (D-128), drawn after the renderers so its actors stand over
# the level.
func _attach_world(new_world: World) -> void:
	world = new_world
	game_viewport.add_child(world)
	game_viewport.move_child(world, $GameViewport/FixtureRenderer.get_index() + 1)


func _set_current_save_slot() -> void:
	save_slots = SaveGame.get_save_slots(saves_root)
	if save_slots.size() > 0:
		current_save_slot = save_slots[0]


# Frees the world, and with it every level and actor in it (D-128).
func _free_world() -> void:
	if world != null:
		world.free()
		world = null
	# Nothing may reach the freed player, a save least of all
	_active_actor = null


# Freed at the end of the frame, in case this is reached from inside a
# handler's own _input: freeing it there would free it with its code
# still running (R-B8). Until then it is cut off from its actor and
# from input, and left in the tree, so it is never an orphan.
func _free_inputhandlers() -> void:
	for handler in _input_handlers:
		if not is_instance_valid(handler): continue
		handler.actor = null
		handler.set_process_input(false)
		handler.set_physics_process(false)
		handler.queue_free()
	_input_handlers.clear()


func _spawn_player(_name: String) -> void:
	var tile: WorldPos = Spawning.spawn_tile_for(null, world.levels(), world.actors())
	if tile == null:
		push_error("Nowhere to spawn %s." % _name)
		return
	var actor = Actor.create(Global.actor_packed_scene, _name, tile, world.level_at(tile.depth), ActorKind.ACTOR.PLAYER)

	_create_actor(actor)
	set_user_control(actor)


func _create_actor(actor: Actor) -> Actor:
	world.add_actor(actor)
	return _take_actor(actor)


# Gives an actor already in the world what the game adds: a player's
# capabilities, the view, and the save on a level change.
func _take_actor(actor: Actor) -> Actor:
	if actor.actor_kind == ActorKind.ACTOR.PLAYER:
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


# By the path a new player takes, avoiding the actors already placed
# (D-091). With nowhere to go, it stays where it is, loudly.
func _move_if_stuck(actor: Actor) -> void:
	var stuck: WorldPos = actor.current_WorldPos
	var tiles: LevelTiles = actor.current_level.level_tiles
	if TileKind.is_passable(tiles.get_top(stuck.x, stuck.y), tiles.get_ground(stuck.x, stuck.y)):
		return
	
	var target: WorldPos = Spawning.spawn_tile_for(null, world.levels(), world.actors())
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
	var players: Array[Actor] = world.players()
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
















