class_name TilePrefab
extends Resource

# An authored block of tiles, placed into a level by stamping it at a world
# coordinate. A prefab is not a level: it covers only what it was authored to
# cover, and every tile it does not mention keeps the level's default.
# The '0' marker is the prefab's own anchor, not world (0, 0) -- the three
# layer grids line up with each other by their markers.


@export var id: StringName
@export_multiline var ground: String
@export_multiline var top: String
@export_multiline var ore: String


# Builds a prefab in code rather than loading one from disk, so a test can
# state its grids inline without touching the filesystem.
static func from_grids(p_id: StringName, p_ground: String, p_top: String, p_ore: String) -> TilePrefab:
	var prefab: TilePrefab = TilePrefab.new()
	prefab.id = p_id
	prefab.ground = p_ground
	prefab.top = p_top
	prefab.ore = p_ore
	return prefab
