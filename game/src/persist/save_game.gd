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
const ALLOW_OBJECTS: bool = false
const COMPRESSION_MODE: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD


static func save_game(slot_path: String, levels: Array[Level]) -> REFUSAL_REASON:
	# Serialize data
	var data: Dictionary = serialize(levels)
	
	# Write data to tmp
	var tmp_save_path: String = slot_path.path_join("world.save.tmp")
	var result: bool = _overwrite_data(data,tmp_save_path)
	if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	# Backup old save
	var save_path: String = slot_path.path_join("world.save")
	if FileAccess.file_exists(save_path):
		result = _rename_file(save_path, "world.save.bak", true)
		if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	# Rename tmp to normal save
	result = _rename_file(tmp_save_path, "world.save", false)
	if result == false: return REFUSAL_REASON.SAVE_FAILED
	
	return REFUSAL_REASON.NONE


static func load_game() -> REFUSAL_REASON:
	
	return REFUSAL_REASON.NONE


static func setup() -> void:
	_create_save_directory_if_missing()


static func serialize(levels: Array[Level]) -> Dictionary:
	var data: Dictionary = {}
	data["format_version"] = FORMAT_VERSION
	
	var levels_data: Dictionary = {}
	for level in levels:
		# Null checks
		if not level is Level:
			continue
		if level.level_tiles == null or \
			not level.level_tiles is LevelTiles:
				continue
		if level.level_tiles.level_bound == null or \
			not level.level_tiles.level_bound is LevelBound:
				continue
		
		# Build level data. The bound is the one source of depth: the
		# key and bound.depth are the same number by construction.
		var bound: LevelBound = level.level_tiles.level_bound
		var level_data: Dictionary = {}
		level_data["level_seed"] = level.level_seed
		level_data["bound"] = {}
		level_data["bound"]["depth"] = bound.depth
		level_data["bound"]["radius"] = bound.radius
		
		level_data["tiles"] = {}
		level_data["tiles"]["ground"] = level.level_tiles.ground.compress(COMPRESSION_MODE)
		level_data["tiles"]["top"] = level.level_tiles.top.compress(COMPRESSION_MODE)
		level_data["tiles"]["ore"] = level.level_tiles.ore.compress(COMPRESSION_MODE)
		
		# Add the level to the save data
		levels_data[bound.depth] = level_data
	
	data["levels"] = levels_data
	
	return data


static func deserialize(data: Dictionary) -> Array[Level]:
	if not data.has("levels"): return []
	if not data["levels"] is Dictionary: return []
	if not data.levels: return []

	var levels_data: Dictionary = data["levels"]
	var levels: Array[Level] = []

	for key: Variant in levels_data:
		# Validate input data
		if not _is_valid_level_entry(key, levels_data[key]): continue
		var level_data: Dictionary = levels_data[key]
		var bound: Dictionary = level_data["bound"]

		# Build layer arrays
		var layers: Dictionary = {}
		if level_data.has("tiles"):
			var tiles: Dictionary = level_data["tiles"]
			var layer_size: int = LevelTiles.array_size(bound["radius"])
			if tiles.has("ground"):
				var ground: PackedByteArray = tiles["ground"]
				layers["ground"] = ground.decompress(layer_size, COMPRESSION_MODE)
			if tiles.has("top"):
				var top: PackedByteArray = tiles["top"]
				layers["top"] = top.decompress(layer_size, COMPRESSION_MODE)
			if tiles.has("ore"):
				var ore: PackedByteArray = tiles["ore"]
				layers["ore"] = ore.decompress(layer_size, COMPRESSION_MODE)
		
		# Build level
		var level: Level = Level.new()
		level.setup(bound["depth"])
		# Never use _set_level_seed() because it recomputes the seed. The save is the source of truth
		level.level_seed = level_data["level_seed"]
		var result: LevelTiles.REFUSAL_REASON = level.level_tiles.bulk_load_tile_arrays(layers)
		if result != LevelTiles.REFUSAL_REASON.NONE:
			level.free()
			continue
		
		levels.append(level)
	
	return levels


static func get_save_slots() -> PackedStringArray:
	var slots: PackedStringArray = []
	var save_dir = DirAccess.open(SAVES_DIR)
	if save_dir:
		var subdirs: PackedStringArray = save_dir.get_directories()
		for dir in subdirs:
			if Global.is_regex_match(dir, r"slot-\d\d\d"):
				var full_slot_path: String = SAVES_DIR.path_join(dir)
				slots.append(full_slot_path)
	else:
		push_warning("An error occurred when trying to access the path: %s." % SAVES_DIR)
	
	# TODO: Look for world.save files in the directories because calling them valid slots
	
	return slots


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

	if not entry.has("tiles"): return true
	var tiles: Variant = entry["tiles"]
	if not tiles is Dictionary: return false
	for layer: String in ["ground", "top", "ore"]:
		if tiles.has(layer) and not tiles[layer] is PackedByteArray: return false

	return true


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


static func _create_save_directory_if_missing() -> void:
	var save_dir = DirAccess.open(SAVES_DIR)
	if not save_dir:
		DirAccess.make_dir_absolute(SAVES_DIR)


static func _overwrite_data(data: Dictionary, file_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null: return false
	
	if f.store_var(data, ALLOW_OBJECTS):
		return true
	
	return false



























