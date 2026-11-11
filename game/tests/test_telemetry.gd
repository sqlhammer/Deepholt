extends GutTest

# Play-test telemetry (D-198 to D-208): only playtest builds record;
# a session's events and summary; trips by D-208's definition, with
# time overloaded and kilos home; refusals; frame-time percentiles; a
# crash found at the next launch with its last minutes; the zip;
# nothing identifying; the presets carry the tag.

const SaveDirs = preload("res://tests/save_dirs.gd")
const Worlds = preload("res://tests/worlds.gd")
const DIR: String = SaveDirs.TEST_ROOT + "/telemetry"
const ROLLING: String = SaveDirs.TEST_ROOT + "/telemetry_logs/recent.jsonl"

var _world: World
var _actor: Actor
var _telemetry: Telemetry


func before_each() -> void:
	SaveDirs.remove_tree(DIR)
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	_world.level_at(0).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_world.level_at(0).level_tiles.set_ground(0, 0, TileKind.GROUND.ROCK)
	_actor = Actor.create(Global.actor_packed_scene, "Tester", WorldPos.new(0, 0, 0),
		_world.level_at(0), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_telemetry = _new_telemetry()


func after_each() -> void:
	SaveDirs.remove_tree(DIR)
	SaveDirs.remove_tree(ROLLING.get_base_dir())


func _new_telemetry() -> Telemetry:
	var telemetry: Telemetry = Telemetry.new()
	telemetry.dir = DIR
	telemetry.rolling_path = ROLLING
	add_child_autofree(telemetry)
	return telemetry


func _start() -> void:
	_telemetry.watch_world(_world)
	_telemetry.watch_actor(_actor)
	_telemetry.begin({"build": "test"})


func _events(name: StringName = &"") -> Array:
	var path: String = DIR.path_join("%s%s.jsonl" % [Telemetry.SESSION_PREFIX, _telemetry.session])
	var found: Array = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if name == &"" or event.event == name: found.append(event)
	return found


func _session_summary() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join("%s%s.summary.json" % [
		Telemetry.SESSION_PREFIX, _telemetry.session])))


# To (0, 0) on `depth`, opened for it, by move_to, as a ramp would.
func _go(depth: int) -> void:
	var tiles: LevelTiles = _world.level_at(depth).level_tiles
	tiles.set_top(0, 0, TileKind.TOP.OPEN)
	tiles.set_ground(0, 0, TileKind.GROUND.ROCK)
	assert_true(_actor.move_to(WorldPos.new(0, 0, depth), &"ramp"), "to %d" % depth)


# --- which builds ---

func test_only_a_playtest_build_records() -> void:
	assert_false(Telemetry.wanted(), "not the editor or a test run")


func test_both_presets_carry_the_playtest_tag() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "the presets exist")
	var names: Array = []
	for section: String in presets.get_sections():
		# Only the presets themselves: not their options, nor the
		# editor's own sections (it writes `runnable_presets` on export)
		if not section.begins_with("preset.") or section.ends_with(".options"): continue
		names.append(presets.get_value(section, "platform"))
		assert_string_contains(presets.get_value(section, "custom_features"), "playtest",
			"%s is a playtest build" % presets.get_value(section, "name"))
		assert_string_contains(presets.get_value(section, "exclude_filter"), "tests/*",
			"without the tests")
	assert_eq(names, ["Windows Desktop", "Linux"], "Windows and Linux (D-201)")


# --- a session ---

func test_a_session_writes_its_events_summary_and_zip() -> void:
	_start()
	_telemetry.end({"active_play_seconds": 12.0})
	assert_eq(_events(&"session_started").size(), 1, "started")
	assert_eq(_events(&"session_ended").size(), 1, "ended")
	assert_eq(_session_summary().active_play_seconds, 12.0, "the summary, with the facts given")
	assert_false(FileAccess.file_exists(DIR.path_join(Telemetry.MARKER_NAME)), "closed")
	var zip: ZIPReader = ZIPReader.new()
	assert_eq(zip.open(DIR.path_join(Telemetry.ZIP_NAME)), OK, "the zip")
	var inside: PackedStringArray = zip.get_files()
	zip.close()
	assert_true(inside.has("%s%s.jsonl" % [Telemetry.SESSION_PREFIX, _telemetry.session]), "events")
	assert_true(inside.has("%s%s.summary.json" % [Telemetry.SESSION_PREFIX, _telemetry.session]),
		"summary")
	assert_false(inside.has(Telemetry.MARKER_NAME), "not the marker")
	zip.open(DIR.path_join(Telemetry.ZIP_NAME))
	var zipped: Dictionary = JSON.parse_string(zip.read_file("%s%s.summary.json" % [
		Telemetry.SESSION_PREFIX, _telemetry.session]).get_string_from_utf8())
	zip.close()
	assert_eq(zipped.active_play_seconds, 12.0, "the summary whole inside it, not empty")


func test_end_happens_once_and_on_leaving_the_tree() -> void:
	_start()
	remove_child(_telemetry)
	assert_true(_telemetry.ended, "leaving the tree ends it")
	_telemetry.end()
	assert_eq(_events(&"session_ended").size(), 1, "once")
	add_child(_telemetry)


# --- trips (D-208) ---

func test_a_trip_runs_from_going_below_to_coming_back_up() -> void:
	_start()
	_go(1)
	_go(2)
	_actor.pack.add(&"stone", 4)
	_go(1)
	assert_eq(_events(&"trip_ended").size(), 0, "still below where it started")
	_go(0)
	var trips: Array = _events(&"trip_ended")
	assert_eq(_events(&"trip_started").size(), 1, "one trip")
	assert_eq(trips.size(), 1, "ended at the starting depth")
	assert_eq(int(trips[0].data.deepest), 2, "the deepest level")
	assert_true(trips[0].data.finished, "finished")
	assert_almost_eq(float(trips[0].data.kilos_home), _actor.pack.total_weight, 0.1, "kilos home")


func test_the_start_depth_is_where_the_player_began_not_the_surface() -> void:
	_go(1)
	_start()
	_go(2)
	_go(1)
	assert_eq(_events(&"trip_ended").size(), 1, "a trip from -1 down and back")
	_go(0)
	assert_eq(_events(&"trip_started").size(), 1, "going above the start isn't a trip")


func test_a_session_ending_below_leaves_its_trip_unfinished() -> void:
	_start()
	_go(1)
	_telemetry.end()
	var trips: Array = _events(&"trip_ended")
	assert_eq(trips.size(), 1, "closed at the end")
	assert_false(trips[0].data.finished, "unfinished")
	assert_eq(int(_session_summary().trips.unfinished), 1, "counted so")


func test_time_overloaded_counts_only_on_a_trip() -> void:
	_start()
	_actor.pack.add(&"stone", 40)
	assert_gt(_actor.load_ratio(), 1.0, "overloaded")
	_telemetry.tick(1.0)
	_go(1)
	_telemetry.tick(2.0)
	_go(0)
	assert_almost_eq(float(_events(&"trip_ended")[0].data.overloaded_seconds), 2.0, 0.01,
		"the two seconds below")


func test_an_npc_makes_no_trips() -> void:
	var npc: Actor = Actor.create(Global.actor_packed_scene, "Npc", WorldPos.new(0, 0, 0),
		_world.level_at(0), ActorKind.ACTOR.NULL)
	_world.add_actor(npc)
	_start()
	_telemetry.watch_actor(npc)
	npc.move_to(WorldPos.new(0, 0, 1), &"ramp")
	assert_eq(_events(&"trip_started").size(), 0, "players only")


# --- friction, health ---

func test_refusals_are_counted_by_verb_and_reason() -> void:
	_start()
	_world.breach_requested.emit(_actor, _actor.current_WorldPos, 0.0)
	_world.breach_requested.emit(_actor, _actor.current_WorldPos, 0.0)
	_telemetry.end()
	var refusals: Dictionary = _session_summary().refusals
	assert_eq(refusals.size(), 1, "one kind")
	var key: String = refusals.keys()[0]
	assert_true(key.begins_with("breach:"), "the verb: %s" % key)
	assert_eq(int(refusals[key]), 2, "twice")


func test_frames_go_into_percentiles_each_minute() -> void:
	_start()
	for i in range(90): _telemetry.tick(0.010)
	for i in range(9): _telemetry.tick(0.030)
	_telemetry.tick(0.200)
	assert_eq(_events(&"frames").size(), 0, "not a minute yet")
	for i in range(4000): _telemetry.tick(0.016)
	assert_eq(_events(&"frames").size(), 1, "a minute")
	var stats: Dictionary = Telemetry.percentiles(PackedInt32Array([0, 0, 5, 0, 0, 1]))
	assert_eq(stats.p50, 3, "half within 3 ms")
	assert_eq(stats.p99, 6, "the slow one")
	assert_eq(stats.max_bucket, 6, "the slowest")
	assert_eq(stats.frames, 6, "six frames")


func test_saves_and_loads_are_timed() -> void:
	_start()
	_telemetry.record_save(&"autosave", 12.0, true)
	_telemetry.record_save(&"quit", 20.0, true)
	_telemetry.record_load(150.0, "SAVE")
	_telemetry.end()
	var summary: Dictionary = _session_summary()
	assert_eq(int(summary.saves.count), 2, "two saves")
	assert_eq(summary.saves.max_msec, 20.0, "the slowest")
	assert_eq(summary.loads.mean_msec, 150.0, "the load")


# --- a crash (D-203, D-207) ---

func test_a_session_left_open_is_a_crash_with_its_last_minutes() -> void:
	_start()
	var crashed_session: String = _telemetry.session
	_telemetry.tick(Telemetry.MARK_EVERY_SECONDS)
	# The process dies: no end. The log's rolling file is what's left
	DirAccess.make_dir_recursive_absolute(ROLLING.get_base_dir())
	var rolling: FileAccess = FileAccess.open(ROLLING, FileAccess.WRITE)
	rolling.store_line("{\"event\":\"breached\"}")
	rolling.close()
	_telemetry.session = ""
	_telemetry.ended = true
	var next: Telemetry = _new_telemetry()
	next.begin({})
	_telemetry = next
	var crashes: Array = _events(&"crashed")
	assert_eq(crashes.size(), 1, "found at the next launch")
	assert_eq(crashes[0].data.session, crashed_session, "which session")
	assert_true(crashes[0].data.last_minutes, "its last minutes kept")
	assert_true(FileAccess.file_exists(DIR.path_join("%s%s.jsonl" % [Telemetry.CRASH_PREFIX,
		crashed_session])), "as a crash file")
	var zip: ZIPReader = ZIPReader.new()
	zip.open(DIR.path_join(Telemetry.ZIP_NAME))
	assert_true(zip.get_files().has("%s%s.jsonl" % [Telemetry.CRASH_PREFIX, crashed_session]),
		"in the zip made at once")
	zip.close()


func test_the_rolling_file_holds_the_last_two_minutes() -> void:
	Log.enabled = true
	Log.clear()
	Log.start_rolling(ROLLING)
	Log.event(Log.WORLD, &"breached", {"actor": 1})
	Log.flush()
	Log.stop_session()
	var text: String = FileAccess.get_file_as_string(ROLLING)
	assert_string_contains(text, "breached", "written by the writer thread")
	assert_eq(Log.rolling_path(), "", "stopped")
	Log.enabled = OS.is_debug_build()
	Log.clear()


# --- nothing identifying (D-204) ---

func test_no_identity_is_recorded() -> void:
	# As a playtest build runs: errors keep their place, not their text,
	# and a warning naming the player reaches neither the summary nor
	# the rolling crash file (D-209)
	Log.enabled = true
	Log.clear()
	Log.keep_error_text = false
	Log.hook_engine()
	Log.start_rolling(ROLLING)
	_start()
	_go(1)
	push_warning("Tester was on a tile it couldn't stand on.")
	assert_push_warning("Tester was on")
	_go(0)
	_telemetry.end()
	Log.flush()
	Log.stop_session()
	Log.unhook_engine()
	Log.keep_error_text = OS.is_debug_build()
	Log.clear()
	var everything: String = FileAccess.get_file_as_string(DIR.path_join("%s%s.jsonl" % [
		Telemetry.SESSION_PREFIX, _telemetry.session])) + JSON.stringify(_session_summary()) 		+ FileAccess.get_file_as_string(ROLLING)
	assert_string_contains(JSON.stringify(_session_summary().errors), "warning at test_telemetry.gd",
		"the warning counted by place")
	for word: String in ["Tester", OS.get_environment("USERNAME"), "install_id", "tester_code"]:
		if word == "": continue
		assert_false(everything.contains(word), "no %s" % word)
