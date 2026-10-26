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


# saves_root is the folder every slot must sit inside. It's SAVES_DIR
# for the game; tests pass their own, so they never touch real saves.
static func save_game(slot_path: String, levels: Array[Level],
		saves_root: String = SAVES_DIR) -> REFUSAL_REASON:
	# Validate input path
	if not _is_inside(slot_path, saves_root):
		push_error("Failed to save outside of save path. Requested: %s | Must begin with: %s" % [slot_path, saves_root])
		return REFUSAL_REASON.SAVE_FAILED
	
	# Serialize data
	var data: Dictionary = serialize(levels)
	
	# Write data to tmp
	var tmp_save_path: String = slot_path.path_join("%s.tmp" % SAVE_BASE_NAME)
	var result: bool = _overwrite_data(data,tmp_save_path)
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


static func load_game() -> REFUSAL_REASON:
	
	return REFUSAL_REASON.NONE


static func setup() -> void:
	_create_slot_directory_if_missing()


static func serialize(levels: Array[Level]) -> Dictionary:
	var data: Dictionary = {}
	data["format_version"] = FORMAT_VERSION
	
	var levels_data: Dictionary = {}
	for level in levels:
		if not _is_savable_level_object(level): continue
		
		# Build level data. The bound is the one source of depth: the
		# key and bound.depth are the same number by construction.
		var bound: LevelBound = level.level_tiles.level_bound
		var level_data: Dictionary = {}
		level_data["level_seed"] = level.level_seed
		level_data["bound"] = {}
		level_data["bound"]["depth"] = bound.depth
		level_data["bound"]["radius"] = bound.radius
		
		_serialize_tile_layers(level_data, level)
		
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
			layers = _deserialize_tile_layers(level_data)
		
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
	
	return slots
 

static func _serialize_tile_layers(level_data: Dictionary, level: Level) -> void:
	# Level and Dictionary are byref, therefore their updates don't need to be returned
	if not level_data.has("tiles"): level_data["tiles"] = {}
	var tiles: Dictionary = level_data["tiles"]
	for key in level.level_tiles.LAYER:
		var _key: String = str(key).to_lower()
		if _key == "none": continue
		
		var data: PackedByteArray = level.level_tiles.get(_key)
		tiles[_key] = data.compress(COMPRESSION_MODE)


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


static func _is_savable_level_object(obj: Variant) -> bool:
	# Null checks
	if not obj is Level: 
		return false
	if obj.level_tiles == null or \
		not obj.level_tiles is LevelTiles:
			return false
	if obj.level_tiles.level_bound == null or \
		not obj.level_tiles.level_bound is LevelBound:
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


static func _create_slot_directory_if_missing() -> void:
	var slot_dir = SAVES_DIR.path_join("slot-001")
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_recursive_absolute(slot_dir)


static func _overwrite_data(data: Dictionary, file_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null: return false
	
	if f.store_var(data, ALLOW_OBJECTS):
		return true
	
	return false



























