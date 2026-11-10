class_name BugCapture
extends Node

# A bug report in one folder (D-194, D-195, D-197): Ctrl+F9, or the
# left trigger and Y held together for two seconds on a pad. The
# folder holds the last ten minutes of the debug log, as JSON lines
# and readable; a save of the running world, written by the normal
# save code with the folder as its root, so the player's own saves
# are untouched; a screenshot; and the facts of the build and the
# session. The 20 newest are kept. Debug builds only: the game adds
# this only when the log is on.

signal captured(folder: String)

const CAPTURE_DIR: String = "user://captures"
const PREFIX: String = "capture-"
const KEEP: int = 20
const HOLD_SECONDS: float = 2.0

# The game: its world, its session and its input handlers are read
# when a capture is made. Handed in, as F3's is.
var game: Node
# Where captures go; tests point it elsewhere
var capture_dir: String = CAPTURE_DIR
var _held: float = 0.0
var _fired: bool = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"capture_bug"):
		capture()
		get_viewport().set_input_as_handled()


# The pad's combo: both held, for two seconds, once per hold.
func _process(delta: float) -> void:
	hold(delta, Input.is_action_pressed(&"capture_trigger")
		and Input.is_action_pressed(&"capture_button"))


func hold(delta: float, both_down: bool) -> void:
	if not both_down:
		_held = 0.0
		_fired = false
		return
	_held += delta
	if _held >= HOLD_SECONDS and not _fired:
		_fired = true
		capture()


# Writes the folder and returns its path, or "" if it couldn't be
# made.
func capture() -> String:
	var folder: String = capture_dir.path_join("%s%s" % [PREFIX,
		SaveGame.file_timestamp(int(Time.get_unix_time_from_system()))])
	# Two in one second get their own folders
	var suffix: int = 2
	var base: String = folder
	while DirAccess.dir_exists_absolute(folder):
		folder = "%s-%d" % [base, suffix]
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Couldn't make the bug capture folder %s." % folder)
		return ""
	Log.event(Log.SAVE, &"capture", {"folder": ProjectSettings.globalize_path(folder)})
	var entries: Array[Dictionary] = Log.recent()
	_write_lines(folder.path_join("log.jsonl"), entries, Log.json_line)
	_write_lines(folder.path_join("log.txt"), entries, Log.line)
	var saved: String = _save(folder)
	var shot: bool = _screenshot(folder.path_join("screenshot.png"))
	var info: Dictionary = facts()
	info["save"] = saved
	info["screenshot"] = shot
	info["log_entries"] = entries.size()
	var file: FileAccess = FileAccess.open(folder.path_join("info.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(info, "\t"))
	Log.prune(capture_dir, PREFIX, KEEP)
	captured.emit(folder)
	return folder


func _write_lines(path: String, entries: Array[Dictionary], format: Callable) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	for entry: Dictionary in entries: file.store_line(format.call(entry))


# "saved", or why not.
func _save(folder: String) -> String:
	if game == null or game.world == null: return "no world"
	var result: SaveGame.REFUSAL_REASON = SaveGame.save_game(folder, game.world, game.session_now(),
		capture_dir)
	return "saved" if result == SaveGame.REFUSAL_REASON.NONE else String(
		SaveGame.REFUSAL_REASON.find_key(result))


# False when there's nothing to grab: headless, there's no screen,
# and asking errors.
func _screenshot(path: String) -> bool:
	if DisplayServer.get_name() == "headless": return false
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty(): return false
	return image.save_png(path) == OK


# The build, the machine and the session, as a capture records them.
func facts() -> Dictionary:
	var info: Dictionary = {
		"build": ProjectSettings.get_setting("application/config/version", ""),
		"godot": Engine.get_version_info().string,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"window_mode": DisplayServer.window_get_mode(),
		"session_log": ProjectSettings.globalize_path(Log.session_path()),
		"captured_at_msec": Time.get_ticks_msec(),
	}
	if game == null: return info
	var devices: Array = []
	for child: Node in game.get_children():
		if child is InputHandler and is_instance_valid(child.actor):
			devices.append({"actor": child.actor.actor_id,
				"scheme": InputHandler.DEVICE_SCHEME.find_key(child.current_device_scheme)})
	info["input"] = devices
	var world: World = game.world
	if world != null:
		info["world_seed"] = world.world_seed
		info["tuning"] = world.tuning.id if world.tuning != null else ""
		var actors: Array = []
		for actor: Actor in world.actors():
			actors.append({"id": actor.actor_id, "name": actor.actor_name,
				"kind": actor.actor_kind, "at": Log.pos(actor.current_WorldPos)})
		info["actors"] = actors
	var session: SaveSession = game.session_now()
	info["active_play_seconds"] = session.active_play_time
	info["total_play_seconds"] = session.total_play_time
	return info
