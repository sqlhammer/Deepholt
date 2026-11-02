extends RefCounted
class_name SaveGame

enum REFUSAL_REASON {
	NONE,
	SAVE_FAILED,
	LOAD_FAILED,
	FILE_WRITE_FAILED,
}

# The save format this build writes and reads. Raised with a migration
# from the version before (world-runtime §7, D-116).
const FORMAT_VERSION: int = 1
const SAVES_DIR: String = "user://saves"
const SAVE_BASE_NAME: String = "world.save"
const ALLOW_OBJECTS: bool = false
const COMPRESSION_MODE: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD
# Every tile layer a save holds, by the name it's saved under and the
# LevelTiles property it's read from (D-112). One list, so the save,
# the load and the checks can't disagree (R-P8).
const TILE_LAYERS: Array[String] = ["ground", "top", "ore"]
# The largest radius a saved bound may have. Well past every recipe's
# (207 at most), and an edited save can't make the load allocate
# gigabytes: at this radius a layer is about 4 MB (R-P9).
const MAX_SAVED_RADIUS: int = 1024
const BACKUP_NAME: String = SAVE_BASE_NAME + ".bak"
# The kinds of file a slot keeps beside its save (D-111, D-123), each
# pruned on its own (D-134).
enum KEPT_KIND {
	OLD_WORLD, # world.<time>.save, moved aside by a new game
	OLD_BACKUP, # world.backup.<time>.save, its backup
	BROKEN, # world.broken.<time>.save, a refused save
}
# How many of each kind pruning keeps, newest first (D-134). Each kind
# has its own count; a kind missing here is never pruned.
const KEEP_PER_KIND: Dictionary[KEPT_KIND, int] = {
	KEPT_KIND.OLD_WORLD: 3,
	KEPT_KIND.OLD_BACKUP: 3,
	KEPT_KIND.BROKEN: 3,
}
# A kept file's name: an optional label, the UTC time (D-123), and the
# -n move_aside adds when two share a second. Nothing else matches,
# so world.save and world.save.bak can't be pruned.
const KEPT_NAME_PATTERN: String = r"^world\.(?:(backup|broken)\.)?(\d{8}T\d{6}Z)(?:-(\d+))?\.save$"
# The header keys a save is refused without, and the type each must be
# (D-121, D-122). Every other key loads as its default.
const REQUIRED_HEADER: Dictionary = {
	"world_seed": TYPE_INT,
	"game_version": TYPE_STRING,
	"saved_at": TYPE_INT,
	"saved_at_utc_offset": TYPE_INT,
}

# Where a launch's world comes from (D-111).
enum SOURCE {
	NEW, # the slot holds no save
	SAVE, # world.save loaded
	BACKUP, # world.save refused or missing, and the backup loaded
	REFUSED, # nothing loaded: the game must not start
}


# What loading a slot found: the world, where it came from, and why
# each file that was tried and refused was refused.
class SlotLoad:
	var source: SaveGame.SOURCE = SaveGame.SOURCE.NEW
	# What loaded; null if nothing did
	var loaded: LoadedGame
	# The loaded world, outside the tree (D-127); null if none loaded
	var world: World:
		get: return loaded.world if loaded else null
	# One line per refused file: its path, then why
	var refusals: Array[String] = []
	# Where a refused world.save was moved to, if the backup loaded
	var broken_path: String = ""


# The header a save is refused without (D-121, D-122), typed. The
# format version is the one the file was written in, not the one it
# was migrated to: F3 shows it.
class Header:
	var format_version: int
	var world_seed: int
	var game_version: String
	var saved_at: int
	var saved_at_utc_offset: int
	# The profile the file names, which may not be the one the world
	# runs under: one this build lacks falls back to the default
	# (D-136). The world's is `world.tuning`.
	var tuning_profile_id: String


# What a load hands back (D-131): what a save took in, the world and a
# session, with the header and the load's problems. A clock the save
# left out is -1 in the session, and so is a missing local actor.
class LoadedGame:
	# Built outside the tree (D-127)
	var world: World
	var session: SaveSession
	var header: Header
	# One line per problem the checks found; reported, never fixed
	# (D-113)
	var problems: Array[String] = []

	# Frees the world, and with it its levels and actors. For a caller
	# that refuses the load instead of putting it in the tree.
	func free_world() -> void:
		if is_instance_valid(world): world.free()
		world = null


# saves_root is the folder every slot must sit inside. It's SAVES_DIR
# for the game; tests pass their own, so they never touch real saves.
# The world gives its levels, actors, seed and counters; the session
# what isn't the world's (D-130).
static func save_game(slot_path: String, world: World, session: SaveSession,
		saves_root: String = SAVES_DIR) -> REFUSAL_REASON:
	# Validate input path
	if not _is_inside(slot_path, saves_root):
		push_error("Failed to save outside of save path. Requested: %s | Must begin with: %s" % [slot_path, saves_root])
		return REFUSAL_REASON.SAVE_FAILED

	# Serialize
	var game_data: Dictionary = _serialize_all(world, session)

	# Write data to tmp
	var tmp_save_path: String = slot_path.path_join("%s.tmp" % SAVE_BASE_NAME)
	var result: bool = _overwrite_data(FORMAT_VERSION, game_data, tmp_save_path)
	if result == false: return REFUSAL_REASON.SAVE_FAILED

	# Backup old save
	var save_path: String = slot_path.path_join(SAVE_BASE_NAME)
	if FileAccess.file_exists(save_path):
		result = _rename_file(save_path, BACKUP_NAME, true)
		if result == false: return REFUSAL_REASON.SAVE_FAILED

	# Rename tmp to normal save
	result = _rename_file(tmp_save_path, SAVE_BASE_NAME, false)
	if result == false: return REFUSAL_REASON.SAVE_FAILED

	return REFUSAL_REASON.NONE


# Loads a slot's world.save, falling back to its backup (D-111). A
# world.save refused while the backup loads is moved aside, kept for
# troubleshooting. With both refused, nothing is moved or written.
static func load_slot(slot_path: String) -> SlotLoad:
	var result: SlotLoad = SlotLoad.new()
	var save_path: String = slot_path.path_join(SAVE_BASE_NAME)
	var backup_path: String = slot_path.path_join(BACKUP_NAME)
	var has_save: bool = FileAccess.file_exists(save_path)
	var has_backup: bool = FileAccess.file_exists(backup_path)
	if not has_save and not has_backup: return result

	if has_save:
		result.loaded = load_file(save_path, result.refusals)
		if result.loaded:
			result.source = SOURCE.SAVE
			return result

	# A missing world.save with a backup is a crash between the two
	# renames of a write: a fallback, never a new game.
	if has_backup:
		result.loaded = load_file(backup_path, result.refusals)
		if result.loaded and has_save:
			result.broken_path = move_aside(save_path, "broken",
				int(Time.get_unix_time_from_system()))
			# Left in place, the broken save would be rotated over the
			# good backup by the next write
			if result.broken_path == "":
				result.refusals.append("%s couldn't be moved aside" % save_path)
				result.loaded.free_world()
				result.loaded = null
		if result.loaded:
			result.source = SOURCE.BACKUP
			return result

	result.source = SOURCE.REFUSED
	return result


# The slot's world.save, or null if it's refused.
static func load_game(slot_path: String) -> LoadedGame:
	return load_file(slot_path.path_join(SAVE_BASE_NAME))


# One save file's world, or null if it's refused, with a line saying
# why appended to refusals: the file's path, then the reason.
static func load_file(file_path: String, refusals: Array[String] = []) -> LoadedGame:
	var why: Array[String] = []
	var loaded: LoadedGame = _load_file(file_path, why)
	if why: refusals.append("%s %s" % [file_path, why[0]])
	return loaded


# Every check on the file runs before any node is built. What can only
# be found by building (a level that won't load, no placeable actor)
# frees the one world built so far, so nothing is orphaned. why gets
# the reason for a refusal.
static func _load_file(file_path: String, why: Array[String]) -> LoadedGame:
	var raw_file_data: Dictionary = _get_file_data(file_path, why)
	if not raw_file_data: return null

	var saved_version: int = raw_file_data.format_version
	if saved_version > FORMAT_VERSION:
		why.append("is format version %d, newer than this build's %d" % [
			saved_version, FORMAT_VERSION])
		return null
	var file_data: Dictionary = _upgrade_file_data_to_latest_format_version(raw_file_data)
	if not file_data:
		why.append("is format version %d, which has no migration to %d" % [
			saved_version, FORMAT_VERSION])
		return null

	# An int, not merely present: earlier saves held strings for
	# saved_at
	for key: String in REQUIRED_HEADER:
		if typeof(file_data.get(key)) != REQUIRED_HEADER[key]:
			why.append("has no %s" % key)
			return null
	if not file_data.get("levels") is Dictionary or not file_data.levels:
		why.append("has no levels")
		return null
	if not file_data.get("actors") is Dictionary or not file_data.actors:
		why.append("has no actors")
		return null

	var loaded: LoadedGame = LoadedGame.new()
	loaded.header = _deserialize_header(file_data, saved_version)
	loaded.session = _deserialize_session(file_data)

	# The world, built whole outside the tree (D-127), under the profile
	# the save names (D-136). Everything below goes into it, so a
	# refusal frees this one node and nothing else.
	var world: World = World.new(
		TuningProfile.find_or_default(loaded.header.tuning_profile_id, "The save"))
	world.world_seed = file_data.world_seed
	loaded.world = world

	# Levels
	_deserialize_levels(file_data.levels, world)
	# All or nothing: a world missing a level isn't the world that was
	# saved, so the file is refused and the backup tried (R-B3). Each
	# skipped level has said why in its own warning.
	var missing: Array = file_data.levels.keys().filter(
		func(depth: Variant) -> bool: return world.level_at(depth) == null)
	if missing:
		why.append("has levels that couldn't be loaded: %s" % [missing])
		loaded.free_world()
		return null
	# Loaded fixtures went straight in; now they're checked, with the
	# world's ramps and ladders, and reported, never dropped (D-113).
	loaded.problems = load_problems(world.levels())
	for problem: String in loaded.problems:
		push_warning(problem)

	# Actors stand on the levels this load built, not on whatever is
	# in the tree, which is the world being replaced.
	if _deserialize_actors(file_data.actors, world).is_empty():
		why.append("has no actor that could be placed")
		loaded.free_world()
		return null

	# Last, after anything that could draw an id (D-130)
	_restore_counters(world, file_data)

	return loaded


# The required keys, already checked for type (D-121, D-122).
static func _deserialize_header(file_data: Dictionary, saved_version: int) -> Header:
	var header: Header = Header.new()
	header.format_version = saved_version
	header.world_seed = file_data.world_seed
	header.game_version = file_data.game_version
	header.saved_at = file_data.saved_at
	header.saved_at_utc_offset = file_data.saved_at_utc_offset
	# Optional (D-121)
	var profile: Variant = file_data.get("tuning_profile_id")
	header.tuning_profile_id = profile if profile is String else TuningProfile.DEFAULT_ID
	return header


# What the save held that isn't the world's (D-130, D-131). Each key
# is optional, and one that's missing or of the wrong type loads as
# its default (D-121): -1 for the local actor and for each clock, so
# the game can tell "not saved" from a zero (D-120).
static func _deserialize_session(file_data: Dictionary) -> SaveSession:
	var stats: Variant = file_data.get("stats")
	if not stats is Dictionary: stats = {}
	return SaveSession.new(
		_header_int(file_data, "local_actor_id", -1),
		_number_or(stats, "active_play_time", -1.0),
		_number_or(stats, "total_play_time", -1.0))


static func _number_or(data: Dictionary, key: String, default: float) -> float:
	var value: Variant = data.get(key)
	if value is float or value is int: return float(value)
	return default


# The world's counters, from the header, then moved past every id the
# load brought back, so a stale or hand-edited counter can never hand
# out an id already in use. A save with no counters (slice 003) gets
# them from the ids alone (D-130, slice 004 trap 6).
static func _restore_counters(world: World, file_data: Dictionary) -> void:
	world.fixture_ids.restore(_header_int(file_data, "next_fixture_id", IdAllocator.FIRST_ID))
	world.fixture_ids.claim(highest_fixture_id(world.levels()))
	world.actor_ids.restore(_header_int(file_data, "next_actor_id", IdAllocator.FIRST_ID))
	for actor: Actor in world.actors():
		world.actor_ids.claim(actor.actor_id)


# An optional int in the header, or its default when it's missing or
# isn't an int (D-121).
static func _header_int(file_data: Dictionary, key: String, default: int) -> int:
	var value: Variant = file_data.get(key)
	return value if value is int else default


# Renames a slot's file to world.<label>.<timestamp>.save beside it,
# or world.<timestamp>.save with no label, never over another file
# (D-111, D-123). The new path, or "" if the rename failed.
static func move_aside(file_path: String, label: String, unix_time: int) -> String:
	var stem: String = "world.%s" % file_timestamp(unix_time)
	if label: stem = "world.%s.%s" % [label, file_timestamp(unix_time)]
	var dir: String = file_path.get_base_dir()
	var target: String = dir.path_join(stem + ".save")
	var n: int = 2
	while FileAccess.file_exists(target):
		target = dir.path_join("%s-%d.save" % [stem, n])
		n += 1
	var err: Error = DirAccess.rename_absolute(file_path, target)
	if err != OK:
		push_error("Couldn't move %s aside: %s" % [file_path, error_string(err)])
		return ""
	return target


# Deletes the oldest kept files of each kind past that kind's count
# in `keep` (D-134). Only names that match KEPT_NAME_PATTERN are
# touched. Returns the paths deleted.
static func prune_kept(slot_path: String,
		keep: Dictionary[KEPT_KIND, int] = KEEP_PER_KIND) -> Array[String]:
	var regex: RegEx = RegEx.create_from_string(KEPT_NAME_PATTERN)
	var by_kind: Dictionary = {}
	for file: String in DirAccess.get_files_at(slot_path):
		var found: RegExMatch = regex.search(file)
		if found == null: continue
		var kind: KEPT_KIND = _kept_kind(found.get_string(1))
		var n: int = int(found.get_string(3)) if found.get_string(3) else 1
		# Sorts oldest first: the time, then the -n
		var order: String = "%s-%06d" % [found.get_string(2), n]
		if not by_kind.has(kind): by_kind[kind] = []
		by_kind[kind].append([order, file])

	var deleted: Array[String] = []
	for kind: KEPT_KIND in by_kind:
		if not keep.has(kind): continue
		var files: Array = by_kind[kind]
		files.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var excess: int = files.size() - maxi(keep[kind], 0)
		for i: int in range(excess):
			var path: String = slot_path.path_join(files[i][1])
			var err: Error = DirAccess.remove_absolute(path)
			if err != OK:
				push_warning("Couldn't prune %s: %s" % [path, error_string(err)])
				continue
			deleted.append(path)
	return deleted


static func _kept_kind(label: String) -> KEPT_KIND:
	match label:
		"backup": return KEPT_KIND.OLD_BACKUP
		"broken": return KEPT_KIND.BROKEN
	return KEPT_KIND.OLD_WORLD


# A UTC time as YYYYMMDDTHHMMSSZ, for file names (D-123).
static func file_timestamp(unix_time: int) -> String:
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d%02d%02dT%02d%02d%02dZ" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


# What's wrong with a loaded world, one line per problem: the checks
# generation runs, on the fixtures and the levels as they came out of
# the save. A report only; nothing is changed (D-113).
static func load_problems(levels: Array[Level]) -> Array[String]:
	return FixturePlacement.problems(levels) \
		+ LevelGenerator.ramp_problems(levels) \
		+ LevelGenerator.ladder_problems(levels)


static func setup(saves_root: String = SAVES_DIR) -> void:
	_create_slot_directory_if_missing(saves_root)


static func get_save_slots(saves_root: String = SAVES_DIR) -> PackedStringArray:
	var slots: PackedStringArray = []
	var save_dir = DirAccess.open(saves_root)
	if save_dir:
		var subdirs: PackedStringArray = save_dir.get_directories()
		for dir in subdirs:
			if Global.is_regex_match(dir, r"^slot-\d{3}$"):
				var full_slot_path: String = saves_root.path_join(dir)
				slots.append(full_slot_path)
	else:
		push_warning("An error occurred when trying to access the path: %s." % saves_root)
	
	# get_directories() promises no order, and launch continues the
	# first slot (R-P6).
	slots.sort()
	return slots


static func get_save_data(slot_path: String) -> Dictionary:
	var file_path: String = slot_path.path_join(SAVE_BASE_NAME)
	var why: Array[String] = []
	var data: Dictionary = _get_file_data(file_path, why)
	return data


static func _serialize_all(world: World, session: SaveSession) -> Dictionary:
	# Serialize data
	## Header | Mandatory
	var game_data: Dictionary = {}
	game_data["format_version"] = FORMAT_VERSION
	game_data["world_seed"] = world.world_seed
	game_data["game_version"] = Global.get_game_version()
	# One clock read, so the time and its offset agree (D-122)
	var now: Dictionary = Global.get_real_time()
	game_data["saved_at"] = now.unix
	game_data["saved_at_utc_offset"] = now.utc_offset

	## Header | Optional
	# The profile the world runs under (D-135)
	game_data["tuning_profile_id"] = world.tuning.id
	if session.local_actor_id != -1:
		game_data["local_actor_id"] = session.local_actor_id
	# The world's counters (D-130), restored last on load
	game_data["next_fixture_id"] = world.fixture_ids.peek()
	game_data["next_actor_id"] = world.actor_ids.peek()

	# Stats
	game_data["stats"] = _serialize_stats(session.active_play_time, session.total_play_time)

	## Levels
	game_data["levels"] = _serialize_levels(world.levels())

	## Actors
	game_data["actors"] = _serialize_actors(world.actors())

	return game_data


static func _serialize_stats(active_play_time: float, total_play_time: float) -> Dictionary:
	# A zero isn't written, and neither is a loaded session's -1 for
	# "not saved" (D-120, D-131)
	var data: Dictionary = {}
	if active_play_time > 0.0:
		data["active_play_time"] = active_play_time
	if total_play_time > 0.0:
		data["total_play_time"] = total_play_time
	return data


static func _serialize_levels(levels: Array[Level]) -> Dictionary:
	# Levels (move into its own func)
	var levels_data: Dictionary = {}
	for level in levels:
		if level is not Level: continue
		levels_data[level.depth] = _serialize_level(level)
	
	return levels_data


static func _serialize_level(level: Level) -> Dictionary:
	if not _is_savable_level_object(level): return {}
	
	var bound: LevelBound = level.level_tiles.level_bound
	var level_data: Dictionary = {}
	level_data["level_seed"] = level.level_seed
	level_data["bound"] = {}
	level_data["bound"]["depth"] = bound.depth
	level_data["bound"]["radius"] = bound.radius
	
	_serialize_tile_layers(level_data, level)
	level_data["fixtures"] = _serialize_fixtures(level.level_fixtures)
	
	return level_data


# One entry per fixture: its kind id, tile and id, all plain ints. The
# depth is the level's, so it isn't repeated. Kind ids are numbers and
# never reused, so an old save's kinds mean the same (D-104).
static func _serialize_fixtures(fixtures: LevelFixtures) -> Array:
	var data: Array = []
	for fixture: Fixture in fixtures.all():
		data.append({
			"kind": fixture.kind,
			"x": fixture.tile.x,
			"y": fixture.tile.y,
			"id": fixture.id,
		})
	return data


static func _serialize_actors(actors: Array[Actor]) -> Dictionary:
	var data: Dictionary = {}
	
	for actor in actors:
		var actor_data: Dictionary = _serialize_actor(actor)
		if not actor_data: continue
		data[actor.actor_id] = actor_data
	
	return data


static func _serialize_actor(actor: Actor) -> Dictionary:
	var actor_data: Dictionary = {}
	if not _is_savable_actor_object(actor): return {}
	
	actor_data["actor_kind"] = actor.actor_kind
	
	# the actor_name is the key one layer up but we need it here, as well
	# to make iterating over actor objects easier when deserializing
	actor_data["actor_name"] = actor.actor_name
	
	actor_data["worldpos"] = {}
	actor_data.worldpos["x"] = actor.current_WorldPos.x
	actor_data.worldpos["y"] = actor.current_WorldPos.y
	actor_data.worldpos["depth"] = actor.current_WorldPos.depth
	
	actor_data["facing"] = {}
	actor_data.facing["x"] = actor.facing.x
	actor_data.facing["y"] = actor.facing.y
	
	return actor_data


# Builds each saved actor on its level in `world`, and adds it to the
# world. Returns the actors built.
static func _deserialize_actors(p_actors: Dictionary, world: World) -> Array[Actor]:
	var actors: Array[Actor] = []

	for key in p_actors:
		# Actors are keyed by their id. This also skips the header's
		# local_actor_id, and a save keyed the old way, by name.
		if key is not int: continue
		if not _is_valid_actor_entry(p_actors[key]): continue
		var actor: Actor = _deserialize_actor(p_actors[key], key, world)
		if not actor: continue
		world.add_actor(actor)
		actors.append(actor)

	return actors


# Must have already passed _is_valid_actor_entry
static func _deserialize_actor(p_actor: Dictionary, p_actor_id: int, world: World) -> Actor:
	var actor_name: String = p_actor.actor_name
	var pos: Dictionary = p_actor.worldpos
	var level: Level = world.level_at(pos.depth)
	if level == null:
		push_warning("Actor %s is on depth %d, which didn't load; skipped." % [actor_name, pos.depth])
		return null
	var worldpos: WorldPos = WorldPos.new(pos.x, pos.y, pos.depth)
	var actor: Actor = Actor.create(Global.actor_packed_scene, actor_name, worldpos, level, p_actor.actor_kind, p_actor_id)

	var facing: Dictionary = p_actor.facing
	actor.facing = Vector2i(facing.x, facing.y)

	return actor


# Builds each saved level and adds it to `world`. A level that can't
# be built is skipped, with a warning; the caller refuses the save.
static func _deserialize_levels(p_levels: Dictionary, world: World) -> void:
	# A level the save holds only in part is generated first, drawing
	# fixture ids. Every saved id is claimed before that, so a
	# generated fixture can't take an id a saved one has.
	_claim_saved_fixture_ids(p_levels, world.fixture_ids)
	for level_key in p_levels:
		if not _is_valid_level_entry(level_key, p_levels[level_key]): continue
		# A depth with no recipe row is refused here. Level.set_depth
		# would clamp it onto the last level without a word.
		if not LevelRecipes.TABLE.has_recipe(level_key):
			push_warning("Saved depth %d has no recipe row; skipped." % level_key)
			continue
		var level: Level = _deserialize_level(level_key, p_levels[level_key], world)
		if not level: continue
		world.add_level(level)


# Every fixture id in the save that a well-formed entry holds.
static func _claim_saved_fixture_ids(p_levels: Dictionary, fixture_ids: IdAllocator) -> void:
	for level_key in p_levels:
		var entry: Variant = p_levels[level_key]
		if not entry is Dictionary: continue
		if not _is_valid_fixtures_entry(entry.get("fixtures", [])): continue
		for fixture: Dictionary in entry.get("fixtures", []):
			fixture_ids.claim(fixture.id)


# p_level must already have passed _is_valid_level_entry. The level is
# built to its saved bound, which wins over the recipe's, so a level
# whose radius was tuned isn't lost (D-112, R-B4).
static func _deserialize_level(p_depth: int, p_level: Dictionary, world: World) -> Level:
	# Build layer arrays
	var layers: Dictionary = {}
	if p_level.has("tiles"):
		layers = _deserialize_tile_layers(p_level)

	var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(p_depth)
	var bound: LevelBound = LevelBound.new(p_depth, recipe.bound.name, p_level.bound.radius)

	# Build level. A level the save holds whole is built from the save
	# alone: generating it would draw fixture ids and place a world
	# spawn only for the save to replace them (R-P2). One missing a
	# layer or its fixtures, from before they were saved, is generated
	# first, to the saved bound, so the missing parts keep what was
	# generated.
	var level: Level
	if _holds_whole_level(p_level, layers):
		level = Global.level_packed_scene.instantiate()
		level.setup(p_depth, world.world_seed, bound)
	else:
		var shaped: LevelRecipe = LevelRecipe.new(bound)
		shaped.fixed_placements = recipe.fixed_placements
		level = LevelGenerator.generate_level(shaped, world.world_seed, world.fixture_ids)
	# The save is the source of truth: its seed, never one recomputed
	level.level_seed = p_level["level_seed"]

	var result: LevelTiles.REFUSAL_REASON
	result = level.level_tiles.bulk_load_tile_arrays(layers)
	if result != LevelTiles.REFUSAL_REASON.NONE:
		level.free()
		return

	# The saved fixtures replace the generated ones. A save with no
	# fixtures entry, from before they were saved, keeps what was
	# generated, as a missing tile layer does.
	if p_level.has("fixtures"):
		level.level_fixtures = _deserialize_fixtures(p_depth, p_level.fixtures)

	return level


# Whether a saved level has every tile layer and its fixtures, so
# nothing in it has to come from generation.
static func _holds_whole_level(p_level: Dictionary, layers: Dictionary) -> bool:
	if not p_level.has("fixtures"): return false
	for layer: String in TILE_LAYERS:
		if not layers.has(layer): return false
	return true


# The highest fixture id in these levels, or -1 if they hold none. A
# load moves the world's counter past it (D-130).
static func highest_fixture_id(levels: Array[Level]) -> int:
	var highest: int = -1
	for level: Level in levels:
		for fixture: Fixture in level.level_fixtures.all():
			highest = maxi(highest, fixture.id)
	return highest


# p_fixtures must already have passed _is_valid_level_entry. Each goes
# straight into the store with its saved id, without the placement
# rules (D-113). Only a second fixture with an id already on the level
# is left out: the store can't hold two, and one id must name one
# fixture.
static func _deserialize_fixtures(p_depth: int, p_fixtures: Array) -> LevelFixtures:
	var fixtures: LevelFixtures = LevelFixtures.new()
	for entry: Dictionary in p_fixtures:
		if fixtures.find(entry.id) != null:
			push_warning("Saved fixture id %d is on depth %d twice; the second is skipped." % [
				entry.id, p_depth])
			continue
		fixtures.add(Fixture.new(entry.kind, WorldPos.new(entry.x, entry.y, p_depth), entry.id))
	return fixtures


static func _deserialize_tile_layers(level_data: Dictionary) -> Dictionary:
	var layers: Dictionary = {}
	var tiles: Dictionary = level_data["tiles"]
	var bound: Dictionary = level_data["bound"]
	var layer_size: int = LevelTiles.array_size(bound["radius"])
	
	for layer: String in TILE_LAYERS:
		if tiles.get(layer) is not PackedByteArray: continue
		var bytes: PackedByteArray = tiles[layer]
		layers[layer] = bytes.decompress(layer_size, COMPRESSION_MODE)
	
	return layers


static func _serialize_tile_layers(level_data: Dictionary, level: Level) -> void:
	# Level and Dictionary are byref, therefore their updates don't need
	# to be returned
	if not level_data.has("tiles"): level_data["tiles"] = {}
	var tiles: Dictionary = level_data["tiles"]
	for layer: String in TILE_LAYERS:
		var data: PackedByteArray = level.level_tiles.get(layer)
		tiles[layer] = data.compress(COMPRESSION_MODE)


# The file's two parts, its version and its data, merged. {} if either
# can't be read, with the reason appended to why.
static func _get_file_data(file_path: String, why: Array[String]) -> Dictionary:
	var dict_data: Dictionary = {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err: Error = FileAccess.get_open_error()
		push_error(error_string(err) + " - " + file_path)
		why.append("can't be opened (%s)" % error_string(err))
		return {}

	# Store and retrieve the format_version separately from the remainder
	# of the data so that its format can change and be detected before
	# reading it
	var version: Variant = _read_var(file)
	if not version is Dictionary or not version.get("format_version") is int:
		why.append("is unreadable: it has no format version")
		return {}
	dict_data["format_version"] = version["format_version"]

	var data: Variant = _read_var(file)
	if not data is Dictionary:
		why.append("is cut short or unreadable")
		return {}
	# The header's version is the one checked, so the body's copy
	# (save_game writes one) mustn't replace it (R-B10)
	for key in data:
		if key == "format_version": continue
		dict_data[key] = data[key]

	return dict_data


# The next value in the file, or null if it's cut short. get_var
# reads a 4-byte length and then that many bytes; checking the length
# against what's left first refuses a truncated file quietly, where
# get_var would print engine errors decoding it.
static func _read_var(file: FileAccess) -> Variant:
	var start: int = file.get_position()
	var left: int = file.get_length() - start
	if left < 4: return null
	var length: int = file.get_32()
	if length > left - 4: return null
	file.seek(start)
	return file.get_var(ALLOW_OBJECTS)


# Whether one saved level has every field deserialize reads, each of
# the type it expects. A save is a file anyone can edit or truncate,
# so a wrong type must skip the level, not stop the load with a script
# error. Tiles and any layer in them are optional (D-112).
static func _is_valid_level_entry(key: Variant, entry: Variant) -> bool:
	if not key is int: return false
	if not entry is Dictionary: return false
	if not entry.get("level_seed") is int: return false

	var bound: Variant = entry.get("bound")
	if not bound is Dictionary: return false
	if not bound.get("depth") is int: return false
	if not bound.get("radius") is int: return false
	if bound["radius"] < 0 or bound["radius"] > MAX_SAVED_RADIUS: return false
	# The key and the bound both name the depth; a save where they
	# differ has been edited or damaged, and neither can be trusted.
	if bound["depth"] != key: return false

	if entry.has("fixtures") and not _is_valid_fixtures_entry(entry["fixtures"]):
		return false

	if not entry.has("tiles"): return true
	var tiles: Variant = entry["tiles"]
	if not tiles is Dictionary: return false
	for layer: String in TILE_LAYERS:
		if tiles.has(layer) and not tiles[layer] is PackedByteArray: return false

	return true


# Whether a level's saved fixtures are an Array of entries, each with
# an int kind, x, y and id. Whether each one is allowed where it is
# is the load report's question, not this one's (D-113).
static func _is_valid_fixtures_entry(fixtures: Variant) -> bool:
	if not fixtures is Array: return false
	for entry: Variant in fixtures:
		if not entry is Dictionary: return false
		for field: String in ["kind", "x", "y", "id"]:
			if not entry.get(field) is int: return false
	return true


static func _is_valid_actor_entry(actor: Variant) -> bool:
	if actor is not Dictionary: return false
	if actor.get("actor_kind") is not int: return false
	if actor.get("actor_name") is not String: return false
	
	if actor.get("worldpos") is not Dictionary: return false
	if actor.worldpos.get("x") is not int: return false
	if actor.worldpos.get("y") is not int: return false
	if actor.worldpos.get("depth") is not int: return false
	
	if actor.get("facing") is not Dictionary: return false
	if actor.facing.get("x") is not int: return false
	if actor.facing.get("y") is not int: return false
	
	return true


static func _is_savable_level_object(obj: Variant) -> bool:
	if obj is not Level: 
		return false
	if obj.level_tiles == null or \
		obj.level_tiles is not LevelTiles:
			return false
	if obj.level_tiles.level_bound == null or \
		obj.level_tiles.level_bound is not LevelBound:
			return false

	return true


static func _is_savable_actor_object(obj: Variant) -> bool:
	if obj is not Actor: 
		return false
	if obj.current_WorldPos == null or \
		obj.current_WorldPos is not WorldPos:
			return false
	if obj.facing == null or \
		obj.facing is not Vector2i:
			return false
	
	return true


# Whether path is a folder strictly inside root. Simplified first, so
# "root/../elsewhere" can't climb out; compared with a trailing slash,
# so "user://saves-old" isn't taken for "user://saves".
static func _is_inside(path: String, root: String) -> bool:
	var simple_path: String = path.simplify_path()
	var simple_root: String = root.simplify_path().trim_suffix("/")
	return simple_path.begins_with(simple_root + "/")


static func _rename_file(file_path: String, new_name: String, overwrite: bool = false) -> bool:
	var dir: String = file_path.get_base_dir()
	var destination_file_path: String = dir.path_join(new_name)
	var err: Error
	
	# Check for destination file name existance
	var file_exists: bool = FileAccess.file_exists(destination_file_path)
	
	# Delete previous file, if appropriate
	if file_exists:
		if overwrite:
			err = DirAccess.remove_absolute(destination_file_path)
			if err != OK:
				push_error("Delete failed: %s" % error_string(err))
				return false
		else:
			push_error("Failed to rename '%s' to '%s', new file already exists." % [file_path, destination_file_path])
			return false
	
	# Rename file
	err = DirAccess.rename_absolute(file_path, dir.path_join(new_name))
	if err != OK:
		push_error("Rename failed: %s" % error_string(err))
		return false
	
	return true


static func _create_slot_directory_if_missing(saves_root: String = SAVES_DIR) -> void:
	var slot_dir = saves_root.path_join("slot-001")
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_recursive_absolute(slot_dir)


static func _overwrite_data(format_version: int, data: Dictionary, file_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null: return false
	
	# Store the format_version separately from the remainder of the data
	# so that its format can change and be detected before reading it
	var version: Dictionary = { "format_version": format_version }
	if f.store_var(version, ALLOW_OBJECTS):
		if f.store_var(data, ALLOW_OBJECTS):
			return true
	
	return false


# Brings a save up to FORMAT_VERSION one step at a time, each the
# migration from the version before (world-runtime §7). {} if a step
# is missing.
static func _upgrade_file_data_to_latest_format_version(file_data: Dictionary) -> Dictionary:
	var data: Dictionary = file_data
	var version: int = data.format_version
	while version < FORMAT_VERSION:
		var step: Callable = _migration_from(version)
		if not step.is_valid(): return {}
		data = step.call(data)
		version += 1
	return data


# The migration from a version to the one after it.
static func _migration_from(version: int) -> Callable:
	match version:
		0: return SaveGame._migrate_0_to_1
	return Callable()


# No save was ever written as version 0. The first migration is a
# no-op, written before one is needed (world-runtime §7).
static func _migrate_0_to_1(data: Dictionary) -> Dictionary:
	return data
























