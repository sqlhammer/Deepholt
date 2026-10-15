class_name LevelGridLoader
extends RefCounted

# Stamps an authored TilePrefab into a level's tile data. The prefab's '0'
# marker lands on the anchor coordinate given, and every tile is placed
# relative to it -- so the same prefab can be stamped anywhere.
#
# A malformed prefab is an all-or-nothing failure: nothing is written unless
# every check passes. A prefab that simply does not mention a tile is not
# malformed; that tile keeps the level's default.


const GROUND_CHARS: Dictionary = {
	"r": TileKind.GROUND.ROCK,
	"d": TileKind.GROUND.DIRT,
	"0": TileKind.GROUND.ROCK,
	# Ramps by downhill direction: lowercase the down end, uppercase
	# the up end (D-096).
	"n": TileKind.GROUND.RAMP_DOWN_N,
	"N": TileKind.GROUND.RAMP_UP_N,
	"e": TileKind.GROUND.RAMP_DOWN_E,
	"E": TileKind.GROUND.RAMP_UP_E,
	"s": TileKind.GROUND.RAMP_DOWN_S,
	"S": TileKind.GROUND.RAMP_UP_S,
	"w": TileKind.GROUND.RAMP_DOWN_W,
	"W": TileKind.GROUND.RAMP_UP_W,
	"h": TileKind.GROUND.HOLE,
}

const TOP_CHARS: Dictionary = {
	".": TileKind.TOP.OPEN,
	"#": TileKind.TOP.MINABLE_ROCK,
	"%": TileKind.TOP.MINABLE_DIRT,
	"0": TileKind.TOP.OPEN,
}

const ORE_CHARS: Dictionary = {
	".": TileKind.ORE.NONE,
	"c": TileKind.ORE.COPPER,
	"0": TileKind.ORE.NONE,
}

# The objects grid is sparse: only what it mentions gets a fixture.
const OBJECT_CHARS: Dictionary = {
	".": ObjectKind.OBJECT.NULL,
	"L": ObjectKind.OBJECT.LADDER,
	"0": ObjectKind.OBJECT.NULL,
}

const ORIGIN_CHAR: String = "0"
const MINABLE_ROCK_CHAR: String = "#"


# `fixtures` is the level's fixture store, needed only when the prefab
# has an objects grid (D-104). A prefab with fixtures and no store to
# put them in fails to load rather than dropping them.
static func stamp(tiles: LevelTiles, prefab: TilePrefab, anchor: Vector2i,
		fixtures: LevelFixtures = null) -> bool:
	# Validate characters in grids
	if not are_valid_characters(prefab.ground,GROUND_CHARS): return false
	if not are_valid_characters(prefab.top,TOP_CHARS): return false
	if not are_valid_characters(prefab.ore,ORE_CHARS): return false
	
	# Validate anchors
	if not _has_valid_anchor(prefab.ground): return false
	if not _has_valid_anchor(prefab.top): return false
	if not _has_valid_anchor(prefab.ore): return false
	
	# Grids line up with each other by their anchor markers, so every grid is
	# read into coordinates measured from its own marker.
	var ground_tiles: Dictionary = _to_anchored_tiles(prefab.ground)
	var top_tiles: Dictionary = _to_anchored_tiles(prefab.top)
	var ore_tiles: Dictionary = _to_anchored_tiles(prefab.ore)
	
	# Validate that each grid has all of the same coords
	if not _grid_coords_align_and_are_complete(ground_tiles, top_tiles, ore_tiles): return false
	# Validate that all ore is inside minable rock
	if _has_ore_outside_of_minable_rock(top_tiles, ore_tiles): return false
	# Validate that all holes don't have anything on top of them
	if _has_invalid_hole_placement(ground_tiles,top_tiles, ore_tiles): return false

	# Validate fixtures. The objects grid is exempt from the alignment
	# check (D-102): it only mentions the tiles that hold something.
	var object_tiles: Dictionary = {}
	if not prefab.objects.strip_edges().is_empty():
		if not are_valid_characters(prefab.objects, OBJECT_CHARS): return false
		if not _has_valid_anchor(prefab.objects): return false
		object_tiles = _to_anchored_tiles(prefab.objects)
		if not _fixtures_stand_on_floor(object_tiles, ground_tiles, top_tiles): return false
		if fixtures == null and _has_fixtures(object_tiles):
			push_error("Prefab '%s' has fixtures, but no fixture store was given." % prefab.id)
			return false

	# Stamp tiles
	_stamp_layer(tiles.set_ground, ground_tiles, GROUND_CHARS, anchor)
	_stamp_layer(tiles.set_top, top_tiles, TOP_CHARS, anchor)
	_stamp_layer(tiles.set_ore, ore_tiles, ORE_CHARS, anchor)

	# Stamp fixtures, in the grid's row-then-column order, so the same
	# prefab hands out ids in the same order every run (trap 8).
	for coord: Vector2i in object_tiles:
		var kind: int = OBJECT_CHARS[object_tiles[coord]]
		if kind == ObjectKind.OBJECT.NULL: continue
		var tile: WorldPos = WorldPos.new(coord.x + anchor.x, coord.y + anchor.y,
			tiles.level_bound.depth)
		fixtures.add(Fixture.new(kind, tile, Objects.next_id()))

	return true


static func _has_fixtures(object_tiles: Dictionary) -> bool:
	for coord: Vector2i in object_tiles:
		if OBJECT_CHARS[object_tiles[coord]] != ObjectKind.OBJECT.NULL: return true
	return false


# A fixture stands on floor an actor could stand on. A tile the tile
# grids don't mention keeps the level's default, minable rock, so a
# fixture there would be inside rock. Cross-level rules (a ladder needs
# a hole above it) are checked once every level is built.
static func _fixtures_stand_on_floor(object_tiles: Dictionary, ground_tiles: Dictionary,
		top_tiles: Dictionary) -> bool:
	for coord: Vector2i in object_tiles:
		var character: String = object_tiles[coord]
		if OBJECT_CHARS[character] == ObjectKind.OBJECT.NULL: continue
		if not top_tiles.has(coord) or not ground_tiles.has(coord):
			push_warning("LevelGridLoader Violation: fixture '%s' at %s is on a tile the tile grids don't describe." % [character, coord])
			return false
		var top: int = TOP_CHARS[top_tiles[coord]]
		var ground: int = GROUND_CHARS[ground_tiles[coord]]
		if not TileKind.is_passable(top, ground):
			push_warning("LevelGridLoader Violation: fixture '%s' at %s is not on open floor." % [character, coord])
			return false
	return true


# Ore may only sit inside minable rock. A coordinate the top grid never
# mentions defaults to minable rock, so ore there is allowed; ore over a top
# character that is anything but '#' is not.
static func _has_ore_outside_of_minable_rock(top_tiles: Dictionary, ore_tiles: Dictionary) -> bool:
	for coord in ore_tiles:
		var ore_char: String = ore_tiles[coord]
		if ORE_CHARS[ore_char] == TileKind.ORE.NONE: continue
		if not top_tiles.has(coord): continue
		if top_tiles[coord] != MINABLE_ROCK_CHAR:
			push_warning("LevelGridLoader Violation: Ore discovered outside of minable rock.")
			return true
	return false


# A hole may only sit under TileKind.TOP.OPEN and have TileKind.ORE.NULL
static func _has_invalid_hole_placement(ground_tiles: Dictionary, top_tiles: Dictionary, ore_tiles: Dictionary) -> bool:
	for coord in ground_tiles:
		if ground_tiles[coord] != "h": continue # h = HOLE
		var top_char: String = top_tiles[coord]
		var ore_char: String = ore_tiles[coord]
		if TOP_CHARS[top_char] == TileKind.TOP.OPEN \
			and ORE_CHARS[ore_char] == TileKind.ORE.NONE: continue
		
		push_warning("LevelGridLoader Violation: Hole discovered with invalid top (%s) or ore (%s)." % [top_char, ore_char])
		return true
	return false


static func _has_valid_anchor(grid: String) -> bool:
	if grid.count(ORIGIN_CHAR) != 1: return false
	return true


# Reads a grid into a dictionary of Vector2i -> character, with coordinates
# measured from the grid's own anchor marker rather than its corner.
static func _to_anchored_tiles(grid: String) -> Dictionary:
	var tiles: Dictionary = {}
	var anchor: Vector2i = Vector2i.ZERO
	var lines: PackedStringArray = grid.split("\n")

	for row in lines.size():
		# trailing whitespace only, so a carriage return is not a column
		var line: String = lines[row].strip_edges(false, true)
		for col in line.length():
			var coord: Vector2i = Vector2i(col, row)
			var character: String = line[col]
			if character == ORIGIN_CHAR:
				anchor = coord
			tiles[coord] = character

	var anchored_tiles: Dictionary = {}
	for coord in tiles:
		anchored_tiles[coord - anchor] = tiles[coord]
	return anchored_tiles


static func _stamp_layer(setter: Callable, grid_tiles: Dictionary, characters: Dictionary, anchor: Vector2i) -> void:
	for coord in grid_tiles:
		var x: int = coord.x + anchor.x
		var y: int = coord.y + anchor.y
		setter.call(x, y, characters[grid_tiles[coord]], true)


static func _grid_coords_align_and_are_complete(ground_tiles: Dictionary, top_tiles: Dictionary, ore_tiles: Dictionary) -> bool:
	# If sizes match, then we don't need to check each tile map
	if not (ground_tiles.size() == top_tiles.size() and top_tiles.size() == ore_tiles.size()):
		return false
	
	# Verify that all coords exist in the other grids
	for g in ground_tiles:
		if not (top_tiles.has(g) and ore_tiles.has(g)):
			return false
	
	return true


static func are_valid_characters(grid: String, allowed_chars: Dictionary) -> bool:
	var pattern: String = "[^" # ^ means this is an allow list
	for key in allowed_chars:
		pattern = pattern + key
	pattern = pattern + "\\s]" # \\s means any type of whitespace, including newlines

	var regex = RegEx.new()
	regex.compile(pattern)
	var result = regex.search(grid)

	if result:
		push_error("Found invalid character: '%s' at index %d" % [result.get_string(), result.get_start()])
		return false

	return true


static func regex_escape(character: String) -> String:
	if character.length() > 1: return ""
	match character:
		"]": return "\\]"
		"-": return "\\-"
		"\\": return "\\\\"
	return character
