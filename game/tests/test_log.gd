extends GutTest

# The debug log (D-193, D-196, D-197): events in memory, cheap, in
# order, switchable, written by a thread, pruned; nothing in a release
# build; the engine's own errors included.

const SaveDirs = preload("res://tests/save_dirs.gd")
const DIR: String = SaveDirs.TEST_ROOT + "/log"


func before_each() -> void:
	Log.enabled = true
	Log.clear()


func after_each() -> void:
	Log.stop_session()
	Log.unhook_engine()
	Log.enabled = OS.is_debug_build()
	Log.keep_error_text = OS.is_debug_build()
	Log.clear()
	SaveDirs.remove_tree(DIR)


func _events(name: StringName) -> Array[Dictionary]:
	return Log.recent().filter(func(e: Dictionary) -> bool: return e.event == name)


func test_an_event_is_kept_with_its_time_frame_and_data() -> void:
	Log.event(Log.WORLD, &"breached", {"actor": 3, "tile": [46, 2, 1]})
	var found: Array[Dictionary] = _events(&"breached")
	assert_eq(found.size(), 1, "kept")
	assert_eq(found[0].channel, Log.WORLD, "its channel")
	assert_eq(found[0].data, {"actor": 3, "tile": [46, 2, 1]}, "its data")
	assert_almost_eq(found[0].t, Time.get_ticks_msec(), 1000, "its time")
	assert_eq(found[0].frame, Engine.get_physics_frames(), "its frame")


func test_events_come_back_oldest_first_even_after_the_ring_wraps() -> void:
	for i in range(Log.CAPACITY + 5): Log.event(Log.PERF, &"n", {"i": i})
	var all: Array[Dictionary] = Log.recent()
	assert_eq(all.size(), Log.CAPACITY, "the ring holds its capacity")
	assert_eq(all[0].data.i, 5, "the five oldest are gone")
	assert_eq(all[-1].data.i, Log.CAPACITY + 4, "the newest last")


func test_only_the_window_comes_back() -> void:
	Log.event(Log.PERF, &"now")
	assert_eq(Log.recent(0).size(), 1, "this millisecond's")
	assert_eq(Log.recent(-1000).size(), 0, "nothing from the future")


func test_a_channel_switched_off_records_nothing() -> void:
	Log.set_on(Log.INPUT, false)
	Log.event(Log.INPUT, &"pressed")
	assert_eq(_events(&"pressed").size(), 0, "off")
	Log.toggle(Log.INPUT)
	Log.event(Log.INPUT, &"pressed")
	assert_eq(_events(&"pressed").size(), 1, "back on")


func test_every_channel_is_on_by_default() -> void:
	for channel: StringName in Log.CHANNELS:
		assert_true(Log.is_on(channel), "%s on (D-196)" % channel)
	assert_eq(Log.CHANNELS.size(), 7, "seven channels")


func test_a_release_build_records_nothing() -> void:
	Log.enabled = false
	Log.event(Log.WORLD, &"breached")
	assert_eq(Log.start_session(DIR), "", "no session file")
	Log.enabled = true
	assert_eq(_events(&"breached").size(), 0, "nothing kept")


func test_a_call_costs_microseconds() -> void:
	var started: int = Time.get_ticks_usec()
	for i in range(10000):
		Log.event(Log.MOVES, &"stepped", {"actor": 1, "from": [i, 0, 1], "to": [i + 1, 0, 1]})
	var each: float = float(Time.get_ticks_usec() - started) / 10000.0
	gut.p("%.2f us a call" % each)
	assert_lt(each, 20.0, "well under a frame's worth")


func test_the_session_file_is_written_by_the_thread_and_finished_at_stop() -> void:
	var path: String = Log.start_session(DIR)
	assert_true(path.begins_with(DIR.path_join(Log.SESSION_PREFIX)), "named for the session")
	for i in range(100): Log.event(Log.MOVES, &"stepped", {"i": i})
	Log.flush()
	Log.stop_session()
	var text: String = FileAccess.get_file_as_string(path)
	assert_string_contains(text, "session_started", "the start")
	assert_string_contains(text, "stepped", "the steps")
	assert_eq(text.count("stepped"), 100, "all of them, at stop")
	assert_eq(Log.session_path(), "", "no session after stop")


func test_lines_are_readable_and_json_round_trips() -> void:
	Log.event(Log.MOVES, &"move_to", {"actor": 1, "cause": &"ramp"})
	var entry: Dictionary = _events(&"move_to")[0]
	var line: String = Log.line(entry)
	assert_string_contains(line, "moves", "the channel")
	assert_string_contains(line, "move_to", "the event")
	assert_string_contains(line, "cause=ramp", "the data")
	var back: Dictionary = JSON.parse_string(Log.json_line(entry))
	assert_eq(back.event, "move_to", "JSON keeps the event")


func test_old_session_logs_and_captures_are_pruned() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for i in range(35):
		FileAccess.open(DIR.path_join("%s2026%04d.log" % [Log.SESSION_PREFIX, i]), FileAccess.WRITE)
	FileAccess.open(DIR.path_join("godot.log"), FileAccess.WRITE)
	Log.prune(DIR, Log.SESSION_PREFIX, 30)
	var left: PackedStringArray = DirAccess.get_files_at(DIR)
	assert_eq(left.size(), 31, "30 sessions and the other file")
	assert_false(left.has("%s2026%04d.log" % [Log.SESSION_PREFIX, 4]), "the oldest gone")
	assert_true(left.has("%s2026%04d.log" % [Log.SESSION_PREFIX, 34]), "the newest kept")
	assert_true(left.has("godot.log"), "other names untouched")
	DirAccess.make_dir_recursive_absolute(DIR.path_join("capture-a/inner"))
	FileAccess.open(DIR.path_join("capture-a/inner/x.txt"), FileAccess.WRITE)
	DirAccess.make_dir_recursive_absolute(DIR.path_join("capture-b"))
	Log.prune(DIR, "capture-", 1)
	assert_false(DirAccess.dir_exists_absolute(DIR.path_join("capture-a")), "a folder, whole")
	assert_true(DirAccess.dir_exists_absolute(DIR.path_join("capture-b")), "the newest kept")


func test_the_engines_errors_and_warnings_reach_the_log() -> void:
	Log.hook_engine()
	push_warning("A test warning for the log.")
	assert_push_warning("A test warning")
	var found: Array[Dictionary] = _events(&"warning")
	assert_eq(found.size(), 1, "the warning")
	assert_string_contains(found[0].data.text, "A test warning", "its text")
	assert_eq(found[0].channel, Log.ERRORS, "on the errors channel")
	assert_string_contains(found[0].data.at, "test_log.gd", "where the script raised it")


# D-209: outside a debug build an error keeps where it was raised,
# never what it said, which can name an actor; the counts never keep
# text at all.
func test_outside_a_debug_build_errors_keep_their_place_not_their_text() -> void:
	Log.keep_error_text = false
	Log.hook_engine()
	# From one line twice: one place
	for i in range(2): push_warning("Kestrel was on a tile it couldn't stand on.")
	assert_push_warning_count(2, "both raised")
	var found: Array[Dictionary] = _events(&"warning")
	assert_eq(found.size(), 2, "both logged")
	assert_false(found[0].data.has("text"), "no message")
	assert_string_contains(found[0].data.at, "test_log.gd", "the place")
	var counts: Dictionary = Log.error_counts()
	assert_false(JSON.stringify(counts).contains("Kestrel"), "no name in the counts")
	assert_eq(counts.counts[&"warning"], 2, "counted by type")
	var site: String = counts.sites.keys()[0]
	assert_true(site.begins_with("warning at test_log.gd:"), "and by place: %s" % site)
	assert_eq(counts.sites[site], 2, "twice from there")
	assert_false(counts.has("first"), "no list of texts any more")


func test_the_caller_names_where_the_call_came_from() -> void:
	var lines: Array[String] = Log.caller(1)
	assert_gt(lines.size(), 0, "a stack in a debug build")
	assert_string_contains(lines[0], "test_log.gd", "this file first")
	assert_eq(Log.pos(WorldPos.new(1, 2, 3)), [1, 2, 3], "a tile as an array")
	assert_eq(Log.pos(null), [], "none as empty")
	assert_eq(Log.actor_id(null), -1, "no actor")


func test_godot_keeps_thirty_logs_too() -> void:
	assert_eq(ProjectSettings.get_setting("debug/file_logging/max_log_files"), 30, "D-197")
