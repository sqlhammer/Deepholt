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
const TOOL_DIR := "res://src/entity/tools/"
const SAVES_DIR: String = "user://saves"
const SAVE_BASE_NAME: String = "world.save"
const ALLOW_OBJECTS: bool = false
const COMPRESSION_MODE: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD


# saves_root is the folder every slot must sit inside. It's SAVES_DIR
# for the game; tests pass their own, so they never touch real saves.
static func save_game(slot_path: String, levels: Array[Level], 
	actors: Array[Node], active_actor: Actor, 
	saves_root: String = SAVES_DIR) -> REFUSAL_REASON:
	
	# Validate input path
	if not _is_inside(slot_path, saves_root):
		push_error("Failed to save outside of save path. Requested: %s | Must begin with: %s" % [slot_path, saves_root])
		return REFUSAL_REASON.SAVE_FAILED
	
	# Serialize data
	var game_data: Dictionary = {}
	game_data["format_version"] = FORMAT_VERSION
	var level_data: Dictionary = _serialize_levels(levels)
	game_data["levels"] = level_data
	var actor_data: Dictionary = _serialize_actors(actors, active_actor)
	game_data["actors"] = actor_data
	
	# Write data to tmp
	var tmp_save_path: String = slot_path.path_join("%s.tmp" % SAVE_BASE_NAME)
	var result: bool = _overwrite_data(FORMAT_VERSION, game_data, tmp_save_path)
	if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	# Backup old save
	var save_path: String = slot_path.path_join(SAVE_BASE_NAME)
	if FileAccess.file_exists(save_path):
		result = _rename_file(save_path, "%s.bak" % SAVE_BASE_NAME, true)
		if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	# Rename tmp to normal save
	result = _rename_file(tmp_save_path, SAVE_BASE_NAME, false)
	if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	return REFUSAL_REASON.NONE


static func load_game(slot_path: String) -> Dictionary:
	var raw_file_data: Dictionary = get_save_data(slot_path)
	# Nothing read: the read has already said why. Not an upgrade
	# failure, which is what an empty result would be blamed on below.
	if not raw_file_data: return {}
	var file_data = _upgrade_file_data_to_latest_format_version(raw_file_data)
	if not file_data: 
		push_error("Load game aborted: Failed to upgrade save file data to current format version.")
		return {}
	
	# Every section is checked before any node is built. A refusal
	# after levels or actors exist would orphan them
	if not file_data.has("format_version"): return {}
	if not file_data.get("levels") is Dictionary: return {}
	if not file_data.levels: return {}
	if not file_data.get("actors") is Dictionary: return {}
	if not file_data.actors: return {}

	# Header data
	var game_data: Dictionary = {}
	game_data["format_version"] = file_data.format_version

	# Levels
	game_data["levels"] = _deserialize_levels(file_data.levels)
	# Loaded fixtures went straight in; now they're checked, with the
	# world's ramps and ladders, and reported, never dropped (D-113).
	var loaded: Array[Level] = []
	loaded.assign(game_data.levels.values())
	game_data["problems"] = load_problems(loaded)
	for problem: String in game_data.problems:
		push_warning(problem)

	# Objects


	# NPCs


	# Actors
	# Actors stand on the levels this load built, not on whatever is
	# in the tree, which is the world being replaced.
	game_data["actors"] = _deserialize_actors(file_data.actors, game_data.levels)
	
	return game_data


# What's wrong with a loaded world, one line per problem: the checks
# generation runs, on the fixtures and the levels as they came out of
# the save. A report only; nothing is changed (D-113).
static func load_problems(levels: Array[Level]) -> Array[String]:
	return Objects.placement_problems(levels) 		+ LevelGenerator.ramp_problems(levels) 		+ LevelGenerator.ladder_problems(levels)


# Frees every node a load built: its levels, and its actors. For a
# caller that refuses loaded data instead of putting it in the tree.
static func free_game_data(game_data: Dictionary) -> void:
	var levels: Variant = game_data.get("levels")
	if levels is Dictionary:
		for key in levels:
			if levels[key] is Node: levels[key].free()
	var actors: Variant = game_data.get("actors")
	if actors is Dictionary:
		for key in actors:
			var entry: Variant = actors[key]
			if entry is Dictionary and entry.get("actor_obj") is Node:
				entry.actor_obj.free()


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
	
	return slots


static func get_save_data(slot_path: String) -> Dictionary:
	var file_path: String = slot_path.path_join(SAVE_BASE_NAME)
	var data: Dictionary = _get_file_data(file_path)
	return data


static func _load_tool(path: Variant) -> ToolData:
	if not path is String: return null
	var clean: String = (path as String).simplify_path()
	if not clean.begins_with(TOOL_DIR):
		push_warning("Tool path outside %s: %s" % [TOOL_DIR, clean])
		return null
	if not ResourceLoader.exists(clean):
		push_warning("Tool path not found: %s" % clean)
		return null
	var res := load(clean)
	if not res is ToolData:
		push_warning("Not a ToolData: %s" % clean)
		return null
	return res


static func _serialize_levels(levels: Array[Level]) -> Dictionary:
	# Levels (move into it's own func)
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


static func _serialize_actors(actors: Array[Node], active_actor: Actor) -> Dictionary:
	var data: Dictionary = {}
	
	for actor in actors:
		var actor_data: Dictionary = _serialize_actor(actor, active_actor)
		if not actor_data: continue
		data[actor.actor_name] = _serialize_actor(actor, active_actor)
	
	return data


static func _serialize_actor(actor: Actor, active_actor: Actor) -> Dictionary:
	var actor_data: Dictionary = {}
	if not _is_savable_actor_object(actor): return {}
	
	actor_data["is_active"] = ( actor == active_actor )
	
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


# levels is the loaded levels by depth; each actor is put on its own.
static func _deserialize_actors(p_actors: Dictionary, levels: Dictionary) -> Dictionary:
	var actors: Dictionary = {}

	for key in p_actors:
		if not _is_valid_actor_entry(p_actors[key]): continue
		var actor: Actor = _deserialize_actor(p_actors[key], levels)
		if not actor: continue
		actors[key] = {}
		actors[key]["actor_obj"] = actor
		actors[key]["is_active"] = p_actors[key].is_active
		actors[key]["worldpos"] = actor.current_WorldPos
	
	return actors


# Must have already passed _is_valid_actor_entry
static func _deserialize_actor(p_actor: Dictionary, levels: Dictionary) -> Actor:
	var actor_name: String = p_actor.actor_name
	var pos: Dictionary = p_actor.worldpos
	var level: Level = levels.get(pos.depth)
	if level == null:
		push_warning("Actor %s is on depth %d, which didn't load; skipped." % [actor_name, pos.depth])
		return null
	var worldpos: WorldPos = WorldPos.new(pos.x, pos.y, pos.depth)
	var actor: Actor = Actor.create(Global.actor_packed_scene, actor_name, worldpos, level)
	
	var facing: Dictionary = p_actor.facing
	actor.facing = Vector2i(facing.x, facing.y)
	
	return actor


static func _deserialize_levels(p_levels: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	
	for level_key in p_levels:
		if not _is_valid_level_entry(level_key, p_levels[level_key]): continue
		# A depth with no recipe row is refused here. Level.set_depth
		# would clamp it onto the last level without a word.
		if not World.level_recipes.has_recipe(level_key):
			push_warning("Saved depth %d has no recipe row; skipped." % level_key)
			continue
		var level: Level = _deserialize_level(level_key, p_levels[level_key])
		if not level: continue
		levels[level_key] = level
	
	return levels


# p_level must already have passed _is_valid_level_entry.
static func _deserialize_level(p_depth: int, p_level: Dictionary) -> Level:
	# Build layer arrays
	var layers: Dictionary = {}
	if p_level.has("tiles"):
		layers = _deserialize_tile_layers(p_level)
	
	# Build level
	var level_recipe: LevelRecipe = World.level_recipes.get_recipe(p_depth)
	var level: Level = LevelGenerator.generate_level(level_recipe)
	# Never use _set_level_seed() because it recomputes the seed. The save is the source of truth
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
	
	for key in tiles:
		if tiles[key] is not PackedByteArray: continue
		var bytes: PackedByteArray = tiles[key]
		layers[key] = bytes.decompress(layer_size, COMPRESSION_MODE)
	
	return layers


static func _serialize_tile_layers(level_data: Dictionary, level: Level) -> void:
	# Level and Dictionary are byref, therefore their updates don't need to be returned
	if not level_data.has("tiles"): level_data["tiles"] = {}
	var tiles: Dictionary = level_data["tiles"]
	for key in level.level_tiles.LAYER:
		var _key: String = str(key).to_lower()
		if _key == "none": continue
		
		var data: PackedByteArray = level.level_tiles.get(_key)
		tiles[_key] = data.compress(COMPRESSION_MODE)


static func _get_file_data(file_path: String) -> Dictionary:
	var dict_data: Dictionary = {}
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(error_string(FileAccess.get_open_error()) + " - " + file_path)
		return {}
	
	# Store and retrieve the format_version separately from the remainder of
	# the data so that it's format can change and be detected before reading it
	var version: Variant = file.get_var()
	if version is Dictionary and version.has("format_version"):
		dict_data["format_version"] = version["format_version"]
	
	var data: Variant = file.get_var()
	if data is Dictionary:
		for key in data:
			dict_data[key] = data[key]
	
	return dict_data


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
	if bound["radius"] < 0: return false
	# The key and the bound both name the depth; a save where they
	# differ has been edited or damaged, and neither can be trusted.
	if bound["depth"] != key: return false

	if entry.has("fixtures") and not _is_valid_fixtures_entry(entry["fixtures"]):
		return false

	if not entry.has("tiles"): return true
	var tiles: Variant = entry["tiles"]
	if not tiles is Dictionary: return false
	for layer: String in ["ground", "top", "ore"]:
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
	if actor.get("is_active") is not bool: return false
	if actor.get("actor_name") is not String: return false
	
	if actor.get("worldpos") is not Dictionary: return false
	if actor.worldpos.get("x") is not int: return false
	if actor.worldpos.get("y") is not int: return false
	if actor.worldpos.get("depth") is not int: return false
	
	if actor.get("facing") is not Dictionary: return false
	if actor.facing.get("x") is not int: return false
	if actor.facing.get("y") is not int: return false
	
	# Equipped is optional but should be String, if exists
	if actor.get("equipped"):
		if actor.equipped is not String: return false
	
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
	
	# Store the format_version separately from the remainder of
	# the data so that it's format can change and be detected before reading it
	var version: Dictionary = { "format_version": format_version }
	if f.store_var(version, ALLOW_OBJECTS):
		if f.store_var(data, ALLOW_OBJECTS):
			return true
	
	return false


# only one version, so far, stubbed method
static func _upgrade_file_data_to_latest_format_version(file_data: Dictionary) -> Dictionary:
	var upgraded_data: Dictionary
	upgraded_data = file_data
	return upgraded_data
























