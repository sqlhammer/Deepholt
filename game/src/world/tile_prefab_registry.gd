extends Node

# Indexes every authored tile prefab on disk at startup, keyed by the stable id
# each one carries. Looking one up by an id nothing answers to is an error at
# the lookup, not a silent null somewhere further along.


const PREFAB_DIRECTORY: String = "res://content/tile_prefab/"

var _prefabs: Dictionary = {}


func _ready() -> void:
	_scan(PREFAB_DIRECTORY)


func get_prefab(id: StringName) -> TilePrefab:
	if not _prefabs.has(id):
		push_error("No tile prefab with id '%s'." % id)
		return null
	return _prefabs[id]


func _scan(directory: String) -> void:
	for file_name in DirAccess.get_files_at(directory):
		# an exported build hands back the .remap name, not the .tres
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"): continue
		var resource_path: String = directory + resource_name
		_register(ResourceLoader.load(resource_path), resource_path)


func _register(prefab: TilePrefab, resource_path: String) -> void:
	if prefab == null:
		push_error("'%s' is not a tile prefab." % resource_path)
		return
	if prefab.id == &"":
		push_error("Tile prefab '%s' has no id." % resource_path)
		return
	if _prefabs.has(prefab.id):
		push_error("Duplicate tile prefab id '%s' at '%s'." % [prefab.id, resource_path])
		return
	_prefabs[prefab.id] = prefab
















