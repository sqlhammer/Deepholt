class_name Log
extends RefCounted

# The debug log (D-193, logging-and-telemetry §1): what just happened,
# for Derik and Claude. Any file calls Log.event(channel, name, data).
# A call only appends to memory: a ring buffer reaching ten minutes
# back (D-197), for a capture, and a queue for the session file. A
# background thread formats the queue and writes it, so logging never
# waits on the disk. Debug builds only: a release build returns at
# once. Actors are named by id: nothing here knows of "the" player
# (D-045).
#
# Shared with other threads (the writer, and the engine's Logger
# callbacks, which can come from any thread): the ring, the queue and
# the switches. Every touch of them is behind _mutex.

const MOVES: StringName = &"moves"
const WORLD: StringName = &"world"
const INPUT: StringName = &"input"
const SAVE: StringName = &"save"
const SUPPORT: StringName = &"support"
const PERF: StringName = &"perf"
const ERRORS: StringName = &"errors"
# In F3's order; Ctrl+1 to Ctrl+7 switch them there (D-196)
const CHANNELS: Array[StringName] = [MOVES, WORLD, INPUT, SAVE, SUPPORT, PERF, ERRORS]

# How far back a capture reaches (D-197), and a cap on the ring so a
# flood can't grow it without bound: 100 events a second for the
# whole window.
const WINDOW_MSEC: int = 10 * 60 * 1000
const CAPACITY: int = 60000
# Session logs kept (D-197): this session's and the 29 before it
const KEEP_SESSIONS: int = 30
const LOG_DIR: String = "user://logs"
const SESSION_PREFIX: String = "session-"

# A crash's record (D-207): the last two minutes, rewritten this often
const ROLLING_WINDOW_MSEC: int = 2 * 60 * 1000
const ROLLING_EVERY_MSEC: int = 5000

# On in a debug build, and in a playtest build for a crash's last
# minutes (D-203, D-207); off in any other release build. Tests switch
# it to check that.
static var enabled: bool = OS.is_debug_build() or OS.has_feature("playtest")

static var _mutex: Mutex = Mutex.new()
static var _off: Dictionary[StringName, bool] = {}
static var _ring: Array[Dictionary] = []
# Where the next event goes once the ring is full
static var _head: int = 0
# Events waiting for the writer; only filled while a session runs
static var _pending: Array[Dictionary] = []
static var _thread: Thread
static var _wake: Semaphore
static var _quitting: bool = false
static var _session_path: String = ""
# The rolling crash file, "" when there's none (D-207)
static var _rolling_path: String = ""
# The engine hook, kept to take it off again
static var _hook: EngineHook
# Engine errors and warnings this run, for telemetry's health counts:
# how many of each type, and how many from each place (never the
# message, D-209)
static var _error_counts: Dictionary[StringName, int] = {}
# How often each place raised one, keyed "type at file:line function"
static var _error_sites: Dictionary[String, int] = {}
# Whether an error event keeps its message. Only in a debug build:
# a message can name an actor, and a playtest build's crash file goes
# to Derik with the tester's telemetry, which names no one (D-204,
# D-209). Where it was raised is always kept. Tests switch it.
static var keep_error_text: bool = OS.is_debug_build()


# --- recording ---

# One event. `data` holds ids, tiles as arrays, reasons by name; it's
# kept as given, so pass values, not live objects.
static func event(channel: StringName, name: StringName, data: Dictionary = {}) -> void:
	if not enabled: return
	var entry: Dictionary = {"t": Time.get_ticks_msec(), "frame": Engine.get_physics_frames(),
		"channel": channel, "event": name, "data": data}
	_mutex.lock()
	if not _off.has(channel):
		if _ring.size() < CAPACITY:
			_ring.append(entry)
		else:
			_ring[_head] = entry
			_head = (_head + 1) % CAPACITY
		if _thread != null: _pending.append(entry)
	_mutex.unlock()


# The events from the last `window_msec`, oldest first.
static func recent(window_msec: int = WINDOW_MSEC) -> Array[Dictionary]:
	var since: int = Time.get_ticks_msec() - window_msec
	var found: Array[Dictionary] = []
	_mutex.lock()
	var count: int = _ring.size()
	for i in range(count):
		var entry: Dictionary = _ring[(_head + i) % count] if count == CAPACITY else _ring[i]
		if entry.t >= since: found.append(entry)
	_mutex.unlock()
	return found


# Forgets everything recorded, and switches every channel back on.
static func clear() -> void:
	_mutex.lock()
	_ring.clear()
	_pending.clear()
	_head = 0
	_off.clear()
	_error_counts.clear()
	_error_sites.clear()
	_mutex.unlock()


static func is_on(channel: StringName) -> bool:
	_mutex.lock()
	var on: bool = not _off.has(channel)
	_mutex.unlock()
	return on


static func set_on(channel: StringName, on: bool) -> void:
	_mutex.lock()
	if on: _off.erase(channel)
	else: _off[channel] = true
	_mutex.unlock()


static func toggle(channel: StringName) -> void:
	set_on(channel, not is_on(channel))


# --- values for data ---

static func pos(at: WorldPos) -> Array:
	return [at.x, at.y, at.depth] if at != null else []


static func actor_id(actor: Actor) -> int:
	return actor.actor_id if is_instance_valid(actor) else -1


# Where the call came from, outermost last, skipping `skip` frames of
# the logging itself. Empty in a release build or with no script on
# the stack.
static func caller(skip: int = 1, depth: int = 6) -> Array[String]:
	var lines: Array[String] = []
	for backtrace: ScriptBacktrace in Engine.capture_script_backtraces():
		for i in range(skip, mini(backtrace.get_frame_count(), skip + depth)):
			lines.append("%s:%d %s" % [backtrace.get_frame_file(i).get_file(),
				backtrace.get_frame_line(i), backtrace.get_frame_function(i)])
		break
	return lines


# --- lines ---

# One event as a readable line: seconds since launch, the frame, the
# channel, the event and its data as key=value.
static func line(entry: Dictionary) -> String:
	var parts: PackedStringArray = []
	var data: Dictionary = entry.data
	for key: Variant in data:
		parts.append("%s=%s" % [key, data[key]])
	return "%9.3f f%-7d %-7s %-16s %s" % [entry.t / 1000.0, entry.frame, entry.channel,
		entry.event, " ".join(parts)]


static func json_line(entry: Dictionary) -> String:
	return JSON.stringify(entry)


# --- the session file ---

# Starts writing this session's file in `dir`, pruning the oldest so
# KEEP_SESSIONS remain with it. Returns the file's path, "" in a
# release build. Only the game's own run starts one; tests don't.
static func start_session(dir: String = LOG_DIR) -> String:
	if not enabled: return ""
	if _session_path != "": return _session_path
	if _thread != null:
		push_error("The log's session file must start before its rolling file.")
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	prune(dir, SESSION_PREFIX, KEEP_SESSIONS - 1)
	_session_path = dir.path_join("%s%s.log" % [SESSION_PREFIX,
		SaveGame.file_timestamp(int(Time.get_unix_time_from_system()))])
	_start_writer()
	event(SAVE, &"session_started", {"file": ProjectSettings.globalize_path(_session_path)})
	return _session_path


# Keeps `path` holding the last two minutes, rewritten every few
# seconds by the writer thread, for a crash's record (D-207). Playtest
# builds start it; nothing else does.
static func start_rolling(path: String) -> void:
	if not enabled or _rolling_path != "": return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_rolling_path = path
	if _thread == null: _start_writer()


static func rolling_path() -> String:
	return _rolling_path


static func _start_writer() -> void:
	_quitting = false
	_wake = Semaphore.new()
	_thread = Thread.new()
	_thread.start(_write_loop)


static func session_path() -> String:
	return _session_path


# Wakes the writer for what's queued. Called once a frame; cheap when
# there's nothing.
static func flush() -> void:
	if _thread == null: return
	_mutex.lock()
	var waiting: bool = not _pending.is_empty()
	_mutex.unlock()
	if waiting: _wake.post()


# Writes what's left and stops the writer: at quit, or the last lines
# are lost.
static func stop_session() -> void:
	if _thread == null: return
	_mutex.lock()
	_quitting = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()
	_thread = null
	_session_path = ""
	_rolling_path = ""


# The writer thread: waits to be woken, takes the whole queue, writes
# it to the session file if there is one, rewrites the rolling file
# when it's due, and stops once told to and drained.
static func _write_loop() -> void:
	var file: FileAccess = null
	if _session_path != "": file = FileAccess.open(_session_path, FileAccess.WRITE)
	var rolled_at: int = -ROLLING_EVERY_MSEC
	while true:
		_wake.wait()
		_mutex.lock()
		var batch: Array[Dictionary] = _pending
		_pending = []
		var done: bool = _quitting
		_mutex.unlock()
		if file != null:
			for entry: Dictionary in batch: file.store_line(line(entry))
			file.flush()
		if _rolling_path != "" and (done or Time.get_ticks_msec() - rolled_at >= ROLLING_EVERY_MSEC):
			_roll()
			rolled_at = Time.get_ticks_msec()
		if done: break
	if file != null: file.close()


# The last two minutes into the rolling file, whole: written beside it
# and renamed over it, so a crash mid-write leaves the last good one.
static func _roll() -> void:
	var temporary: String = _rolling_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return
	for entry: Dictionary in recent(ROLLING_WINDOW_MSEC): file.store_line(json_line(entry))
	file.close()
	DirAccess.rename_absolute(temporary, _rolling_path)


# Deletes the oldest files or folders in `dir` whose names start with
# `prefix`, so `keep` remain. Names carry a UTC time, so name order is
# age order.
static func prune(dir: String, prefix: String, keep: int) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null: return
	var names: Array[String] = []
	for name: String in access.get_files() + access.get_directories():
		if name.begins_with(prefix): names.append(name)
	names.sort()
	for i in range(maxi(0, names.size() - keep)):
		_remove_tree(dir.path_join(names[i]))


static func _remove_tree(path: String) -> void:
	var access: DirAccess = DirAccess.open(path)
	if access != null:
		for name: String in access.get_files(): DirAccess.remove_absolute(path.path_join(name))
		for name: String in access.get_directories(): _remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


# --- the engine's own errors and warnings ---

# Every engine error and warning, push_error and push_warning among
# them, goes to the errors channel too.
static func hook_engine() -> void:
	if not enabled or _hook != null: return
	_hook = EngineHook.new()
	OS.add_logger(_hook)


static func unhook_engine() -> void:
	if _hook == null: return
	OS.remove_logger(_hook)
	_hook = null


# What the engine has raised this run, while hooked: a count per type,
# and per place raised. For telemetry's health (D-202); no message
# text, which can name an actor (D-209).
static func error_counts() -> Dictionary:
	_mutex.lock()
	var counts: Dictionary = {"counts": _error_counts.duplicate(), "sites": _error_sites.duplicate()}
	_mutex.unlock()
	return counts


static func _count_error(type: StringName, at: String) -> void:
	_mutex.lock()
	_error_counts[type] = _error_counts.get(type, 0) + 1
	var site: String = "%s at %s" % [type, at]
	_error_sites[site] = _error_sites.get(site, 0) + 1
	_mutex.unlock()


class EngineHook extends Logger:
	const TYPES: Array[StringName] = [&"error", &"warning", &"script_error", &"shader_error"]

	# May come from any thread; Log.event locks what it shares.
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		# The script line that raised it, when there is one: push_error's
		# own file is the engine's C++
		var at: String = "%s:%d %s" % [file.get_file(), line, function]
		for backtrace: ScriptBacktrace in script_backtraces:
			if backtrace.get_frame_count() > 0:
				at = "%s:%d %s" % [backtrace.get_frame_file(0).get_file(), backtrace.get_frame_line(0),
					backtrace.get_frame_function(0)]
				break
		# Never log the log's own trouble: it would log itself (trap 2)
		if at.begins_with("log.gd:") or file.ends_with("/log.gd"): return
		var type: StringName = TYPES[clampi(error_type, 0, TYPES.size() - 1)]
		Log._count_error(type, at)
		var data: Dictionary = {"at": at}
		if Log.keep_error_text: data["text"] = rationale if rationale != "" else code
		Log.event(ERRORS, type, data)

	func _log_message(_message: String, _error: bool) -> void:
		pass
