class_name Telemetry
extends Node

# Play-test telemetry (D-198 to D-208, logging-and-telemetry §2): how
# the game plays on a tester's machine. Only a build with the
# `playtest` feature tag records (D-201); nothing leaves the machine
# unless the tester sends the zip (D-199); nothing identifies the
# tester (D-204).
#
# Per session, in `dir`: the events as JSON lines, written as they
# happen, and a summary at the end (D-205); one zip of the folder,
# refreshed at the end and after a crash (D-206). A crash is a session
# still marked open at the next launch; its last two minutes come
# from the debug log's rolling file (D-203, D-207).
#
# Heard, not called: the world's refusals and generations, each
# player's level changes. Trips are per player, every player (D-045):
# from going below the depth it started the session on to coming back
# up to it (D-208).
#
# The haul (015, D-198's chute events): chutes and winches built, with
# how many trips their builder had started by then, so pre-alpha
# criterion 1 (a chute before the 5th expedition) can be counted;
# items sent down chutes; crates lifted and lowered; things made; and
# map opens.

const DIR: String = "user://telemetry"
const ZIP_NAME: String = "deepholt-telemetry.zip"
const MARKER_NAME: String = "open.json"
const SESSION_PREFIX: String = "session-"
const CRASH_PREFIX: String = "crash-"
# Frame times in 1 ms buckets; the last holds everything slower
const BUCKETS: int = 251
const MINUTE_SECONDS: float = 60.0
# How often the open marker records how long the session has run,
# so a crash's length is known to within this
const MARK_EVERY_SECONDS: float = 10.0

var dir: String = DIR
# The debug log's rolling file, which becomes a crash's record
var rolling_path: String = Log.LOG_DIR.path_join("recent.jsonl")

var session: String = ""
var ended: bool = false
var _file: FileAccess
var _started_msec: int = 0
var _since_mark: float = 0.0
# Per player id: the depth it started on, and its trip if one is open
var _trips: Dictionary[int, Dictionary] = {}
var _finished_trips: Array[Dictionary] = []
var _refusals: Dictionary[String, int] = {}
var _minute: PackedInt32Array = PackedInt32Array()
var _total: PackedInt32Array = PackedInt32Array()
var _minute_seconds: float = 0.0
var _minutes: int = 0
var _saves: PackedFloat32Array = PackedFloat32Array()
var _loads: PackedFloat32Array = PackedFloat32Array()
var _generations: PackedFloat32Array = PackedFloat32Array()
var _crashed: Dictionary = {}
# The haul's counts, for the summary
var _built: Dictionary[String, int] = {}
var _chute_uses: int = 0
var _chute_items: int = 0
var _lifts: int = 0
var _lowers: int = 0
var _kilos_lifted: float = 0.0
var _crafted: Dictionary[String, int] = {}
var _map_opens: int = 0
# The trips each player started before its first chute, or -1 before
# one is built: criterion 1
var _first_chute_after: int = -1


# A build tagged `playtest` records; nothing else does (D-201).
static func wanted() -> bool:
	return OS.has_feature("playtest")


func _init() -> void:
	_minute.resize(BUCKETS)
	_total.resize(BUCKETS)


# --- a session ---

# Opens this session's file. A session the last launch left open
# crashed: it's recorded, its last minutes kept, and the zip remade.
func begin(facts: Dictionary) -> void:
	if session != "": return
	DirAccess.make_dir_recursive_absolute(dir)
	_crashed = _find_crash()
	session = SaveGame.file_timestamp(int(Time.get_unix_time_from_system()))
	_file = FileAccess.open(dir.path_join("%s%s.jsonl" % [SESSION_PREFIX, session]), FileAccess.WRITE)
	_started_msec = Time.get_ticks_msec()
	record(&"session_started", facts)
	if not _crashed.is_empty():
		record(&"crashed", _crashed)
		write_zip()
	_mark()


# Writes the summary, closes the file, clears the open marker and
# remakes the zip, in that order (trap 4). Once.
func end(facts: Dictionary = {}) -> void:
	if session == "" or ended: return
	ended = true
	for id: int in _trips:
		if _trips[id].has("open"): _close_trip(id, null, false)
	if _minute_seconds > 0.0: _end_minute()
	var length: float = (Time.get_ticks_msec() - _started_msec) / 1000.0
	var ended_facts: Dictionary = facts.duplicate()
	ended_facts["length_seconds"] = snappedf(length, 0.1)
	record(&"session_ended", ended_facts)
	var summary_file: FileAccess = FileAccess.open(dir.path_join("%s%s.summary.json" % [
		SESSION_PREFIX, session]), FileAccess.WRITE)
	# Closed before the zip reads it, or the zip takes it empty
	if summary_file != null:
		summary_file.store_string(JSON.stringify(summary(length, facts), "\t"))
		summary_file.close()
	if _file != null: _file.close()
	_file = null
	DirAccess.remove_absolute(dir.path_join(MARKER_NAME))
	write_zip()


# Ended however the game stops, a quit through the tree included.
func _exit_tree() -> void:
	end()


# One event, appended to the session's file at once: rare enough
# (trips, refusals, a minute's frames) that the game never feels it.
func record(event: StringName, data: Dictionary = {}) -> void:
	if _file == null: return
	_file.store_line(JSON.stringify({"t": Time.get_ticks_msec() - _started_msec, "event": event,
		"data": data}))
	_file.flush()


# --- what it hears ---

func watch_world(world: World) -> void:
	world.dig_refused.connect(func(a: Actor, _t: WorldPos, r: int) -> void:
		_refused(a, "dig", World.DIG_REFUSAL.find_key(r)))
	world.breach_refused.connect(func(a: Actor, _t: WorldPos, r: int) -> void:
		_refused(a, "breach", World.BREACH_REFUSAL.find_key(r)))
	world.chop_refused.connect(func(a: Actor, _t: WorldPos, r: int) -> void:
		_refused(a, "chop", World.CHOP_REFUSAL.find_key(r)))
	world.request_refused.connect(func(a: Actor, verb: int, _t: WorldPos, r: int) -> void:
		_refused(a, String(World.FIXTURE_VERB.find_key(verb)).to_lower(),
			World.FIXTURE_REFUSAL.find_key(r)))
	world.climb_refused.connect(func(a: Actor, _t: WorldPos) -> void:
		_refused(a, "climb", "TOO_HEAVY"))
	world.crank_refused.connect(func(a: Actor, r: int) -> void:
		_refused(a, "crank", World.CRANK_REFUSAL.find_key(r)))
	world.craft_refused.connect(func(a: Actor, _id: StringName, r: int) -> void:
		_refused(a, "craft", World.CRAFT_REFUSAL.find_key(r)))
	world.fixture_placed.connect(_on_fixture_placed)
	world.items_chuted.connect(_on_items_chuted)
	world.crate_arrived.connect(_on_crate_arrived)
	world.crafted.connect(func(a: Actor, recipe: Recipe) -> void:
		if not _is_player(a): return
		_crafted[String(recipe.id)] = _crafted.get(String(recipe.id), 0) + 1
		record(&"crafted", {"recipe": recipe.id}))
	# Announced before the world records how long it took: read after
	world.level_added.connect(func(level: Level) -> void:
		var depth: int = level.depth
		(func() -> void:
			if is_instance_valid(world) and world.last_generation_msec >= 0.0:
				_generations.append(world.last_generation_msec)
				record(&"level_generated", {"depth": depth,
					"msec": snappedf(world.last_generation_msec, 0.1)})).call_deferred())


# A player's trips (D-208), from the depth it's on now.
func watch_actor(actor: Actor) -> void:
	if actor.actor_kind != ActorKind.ACTOR.PLAYER or _trips.has(actor.actor_id): return
	_trips[actor.actor_id] = {"start_depth": actor.depth, "actor": weakref(actor)}
	actor.actor_worldpos_changed.connect(_on_moved)


# The map opened (D-226), on the level it shows.
func record_map_opened(depth: int) -> void:
	_map_opens += 1
	record(&"map_opened", {"depth": depth})


static func _is_player(actor: Actor) -> bool:
	return is_instance_valid(actor) and actor.actor_kind == ActorKind.ACTOR.PLAYER


# How many trips a player has started this session.
func trips_started(actor: Actor) -> int:
	return _trips.get(actor.actor_id, {}).get("count", 0) if _is_player(actor) else 0


# A chute or winch a player built, with its trips so far (criterion 1).
func _on_fixture_placed(actor: Actor, fixture: Fixture) -> void:
	if not _is_player(actor): return
	if fixture.kind != ObjectKind.OBJECT.CHUTE and fixture.kind != ObjectKind.OBJECT.WINCH: return
	var kind: String = ObjectKind.OBJECT.find_key(fixture.kind)
	_built[kind] = _built.get(kind, 0) + 1
	var trips: int = trips_started(actor)
	if fixture.kind == ObjectKind.OBJECT.CHUTE and _first_chute_after < 0: _first_chute_after = trips
	record(&"built", {"kind": kind, "depth": fixture.tile.depth, "trips_started": trips})


func _on_items_chuted(actor: Actor, top: WorldPos, landed: WorldPos, id: StringName,
		count: int) -> void:
	if not _is_player(actor): return
	_chute_uses += 1
	_chute_items += count
	record(&"chuted", {"from_depth": top.depth, "to_depth": landed.depth, "item": id, "count": count})


func _on_crate_arrived(actor: Actor, winch: Fixture, crate: Fixture, at_top: bool) -> void:
	if not _is_player(actor): return
	var kilos: float = crate.contents.total_weight if crate.contents != null else 0.0
	if at_top:
		_lifts += 1
		_kilos_lifted += kilos
	else:
		_lowers += 1
	record(&"winched", {"up": at_top, "depth": winch.tile.depth, "kilos": snappedf(kilos, 0.1)})


func record_save(reason: StringName, msec: float, ok: bool) -> void:
	_saves.append(msec)
	record(&"saved", {"reason": reason, "msec": snappedf(msec, 0.1), "ok": ok})


func record_load(msec: float, source: String) -> void:
	_loads.append(msec)
	record(&"loaded", {"msec": snappedf(msec, 0.1), "source": source})


func _refused(actor: Actor, verb: String, reason: Variant) -> void:
	if not is_instance_valid(actor) or actor.actor_kind != ActorKind.ACTOR.PLAYER: return
	var key: String = "%s:%s" % [verb, reason]
	_refusals[key] = _refusals.get(key, 0) + 1
	record(&"refused", {"verb": verb, "reason": reason})


func _on_moved(actor: Actor, old_pos: WorldPos, new_pos: WorldPos) -> void:
	if old_pos == null or new_pos == null or old_pos.depth == new_pos.depth: return
	var trip: Dictionary = _trips.get(actor.actor_id, {})
	if trip.is_empty(): return
	if not trip.has("open") and new_pos.depth > trip.start_depth:
		trip["count"] = trip.get("count", 0) + 1
		trip["open"] = true
		trip["started_msec"] = Time.get_ticks_msec()
		trip["deepest"] = new_pos.depth
		trip["overloaded_seconds"] = 0.0
		record(&"trip_started", {"from_depth": old_pos.depth, "to_depth": new_pos.depth,
			"trip": trip.count})
	elif trip.has("open"):
		trip.deepest = maxi(trip.deepest, new_pos.depth)
		if new_pos.depth <= trip.start_depth: _close_trip(actor.actor_id, actor, true)


func _close_trip(id: int, actor: Actor, finished: bool) -> void:
	var trip: Dictionary = _trips[id]
	if actor == null: actor = trip.actor.get_ref()
	var ended_trip: Dictionary = {
		"seconds_below": snappedf((Time.get_ticks_msec() - trip.started_msec) / 1000.0, 0.1),
		"deepest": trip.deepest,
		"kilos_home": snappedf(actor.pack.total_weight, 0.1) if finished and actor != null else 0.0,
		"overloaded_seconds": snappedf(trip.overloaded_seconds, 0.1),
		"finished": finished,
	}
	_finished_trips.append(ended_trip)
	record(&"trip_ended", ended_trip)
	trip.erase("open")


# --- time: frames, overload on a trip, the open marker ---

func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if session == "" or ended: return
	var bucket: int = mini(int(delta * 1000.0), BUCKETS - 1)
	_minute[bucket] += 1
	_total[bucket] += 1
	_minute_seconds += delta
	if _minute_seconds >= MINUTE_SECONDS: _end_minute()
	for id: int in _trips:
		var trip: Dictionary = _trips[id]
		if not trip.has("open"): continue
		var actor: Actor = trip.actor.get_ref()
		if actor != null and actor.load_ratio() > 1.0: trip.overloaded_seconds += delta
	_since_mark += delta
	if _since_mark >= MARK_EVERY_SECONDS: _mark()


func _end_minute() -> void:
	var stats: Dictionary = percentiles(_minute)
	stats["minute"] = _minutes
	record(&"frames", stats)
	_minutes += 1
	_minute_seconds = 0.0
	_minute.fill(0)


# p50, p95 and p99 frame times in milliseconds, read from the buckets'
# upper edges, and how many frames.
static func percentiles(buckets: PackedInt32Array) -> Dictionary:
	var count: int = 0
	for n: int in buckets: count += n
	var stats: Dictionary = {"frames": count}
	for q: float in [0.5, 0.95, 0.99]:
		var need: float = q * count
		var seen: int = 0
		var at: int = 0
		for i in range(buckets.size()):
			seen += buckets[i]
			at = i
			if seen >= need and seen > 0: break
		stats["p%d" % int(q * 100)] = at + 1 if at < BUCKETS - 1 else BUCKETS - 1
	var slowest: int = 0
	for i in range(buckets.size()):
		if buckets[i] > 0: slowest = i
	stats["max_bucket"] = slowest + 1 if slowest < BUCKETS - 1 else BUCKETS - 1
	return stats


# The session is open, and how long it has run: what a crash leaves.
func _mark() -> void:
	_since_mark = 0.0
	var file: FileAccess = FileAccess.open(dir.path_join(MARKER_NAME), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"session": session,
		"seconds": snappedf((Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1)}))


# --- after a crash ---

# The last session's marker, if it's still there: that session never
# ended. Its last two minutes are copied in from the rolling file.
func _find_crash() -> Dictionary:
	var marker: String = dir.path_join(MARKER_NAME)
	if not FileAccess.file_exists(marker): return {}
	var found: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker))
	DirAccess.remove_absolute(marker)
	var crashed: Dictionary = found if found is Dictionary else {}
	var name: String = String(crashed.get("session", "unknown"))
	crashed["last_minutes"] = false
	if FileAccess.file_exists(rolling_path):
		var copied: Error = DirAccess.copy_absolute(rolling_path,
			dir.path_join("%s%s.jsonl" % [CRASH_PREFIX, name]))
		crashed["last_minutes"] = copied == OK
	return crashed


# --- the summary and the zip ---

func summary(length_seconds: float, facts: Dictionary = {}) -> Dictionary:
	var below: float = 0.0
	var home: float = 0.0
	var overloaded: float = 0.0
	var deepest: int = 0
	var finished: int = 0
	for trip: Dictionary in _finished_trips:
		below += trip.seconds_below
		home += trip.kilos_home
		overloaded += trip.overloaded_seconds
		deepest = maxi(deepest, trip.deepest)
		if trip.finished: finished += 1
	var result: Dictionary = facts.duplicate()
	result.merge({
		"session": session,
		"length_seconds": snappedf(length_seconds, 0.1),
		"crashed_before": _crashed,
		"trips": {"count": _finished_trips.size(), "finished": finished,
			"unfinished": _finished_trips.size() - finished, "seconds_below": snappedf(below, 0.1),
			"deepest": deepest, "kilos_home": snappedf(home, 0.1),
			"overloaded_seconds": snappedf(overloaded, 0.1), "each": _finished_trips},
		"refusals": _refusals,
		"frames": percentiles(_total),
		"saves": _timings(_saves),
		"loads": _timings(_loads),
		"generations": _timings(_generations),
		"errors": Log.error_counts(),
		"haul": {"built": _built, "first_chute_after_trips": _first_chute_after,
			"chute_uses": _chute_uses, "chute_items": _chute_items, "winch_lifts": _lifts,
			"winch_lowers": _lowers, "kilos_lifted": snappedf(_kilos_lifted, 0.1),
			"crafted": _crafted, "map_opens": _map_opens},
	}, true)
	return result


static func _timings(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var total: float = 0.0
	var most: float = 0.0
	for v: float in values:
		total += v
		most = maxf(most, v)
	return {"count": values.size(), "mean_msec": snappedf(total / values.size(), 0.1),
		"max_msec": snappedf(most, 0.1)}


# The whole folder, the open marker and the zip aside, into one zip:
# written beside it and renamed over it.
func write_zip() -> void:
	var temporary: String = dir.path_join(ZIP_NAME + ".tmp")
	var packer: ZIPPacker = ZIPPacker.new()
	if packer.open(temporary) != OK:
		push_error("Couldn't write the telemetry zip at %s." % temporary)
		return
	for name: String in DirAccess.get_files_at(dir):
		if name == ZIP_NAME or name == MARKER_NAME or name.ends_with(".tmp"): continue
		packer.start_file(name)
		packer.write_file(FileAccess.get_file_as_bytes(dir.path_join(name)))
		packer.close_file()
	packer.close()
	DirAccess.rename_absolute(temporary, dir.path_join(ZIP_NAME))
