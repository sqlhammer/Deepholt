class_name ItemRegistry
extends RefCounted

# Every item on disk, by its stable id (D-157, content-schema §1).
# Loaded once, on first use, from content/items/. A static class rather
# than an autoload: the items are fixed design data, like the level
# recipes, and nothing about them is world state (D-118, D-124).

const ITEM_DIRECTORY: String = "res://content/items/"

static var _items: Dictionary[StringName, Item] = {}
static var _loaded: bool = false


# The item with this id, or null, loudly, if this build has none.
static func get_item(id: StringName) -> Item:
	var item: Item = find(id)
	if item == null: push_error("No item with id '%s'." % id)
	return item


# The item with this id, or null, quietly: for a caller that reports
# an unknown id itself, such as a load.
static func find(id: StringName) -> Item:
	_load()
	return _items.get(id)


static func ids() -> Array[StringName]:
	_load()
	var found: Array[StringName] = []
	found.assign(_items.keys())
	return found


static func _load() -> void:
	if _loaded: return
	_loaded = true
	for file_name in DirAccess.get_files_at(ITEM_DIRECTORY):
		# an exported build hands back the .remap name, not the .tres
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"): continue
		_register(ResourceLoader.load(ITEM_DIRECTORY + resource_name), resource_name)


static func _register(item: Item, file_name: String) -> void:
	if item == null:
		push_error("'%s' is not an item." % file_name)
		return
	if item.id == &"":
		push_error("Item '%s' has no id." % file_name)
		return
	if _items.has(item.id):
		push_error("Duplicate item id '%s' in '%s'." % [item.id, file_name])
		return
	_items[item.id] = item
