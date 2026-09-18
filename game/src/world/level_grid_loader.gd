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
	"0": TileKind.GROUND.ROCK,
}

const TOP_CHARS: Dictionary = {
	".": TileKind.TOP.OPEN,
	"#": TileKind.TOP.MINABLE_ROCK,
	"0": TileKind.TOP.OPEN,
}

const ORE_CHARS: Dictionary = {
	".": TileKind.ORE.NONE,
	"c": TileKind.ORE.COPPER,
	"0": TileKind.ORE.NONE,
}

const ORIGIN_CHAR: String = "0"
const MINABLE_ROCK_CHAR: String = "#"


static func stamp(tiles: LevelTiles, prefab: TilePrefab, anchor: Vector2i) -> bool:
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

	# Validate that all ore is inside minable rock
	if _has_ore_outside_of_minable_rock(top_tiles, ore_tiles): return false

	# Stamp tiles
	_stamp_layer(tiles.set_ground, ground_tiles, GROUND_CHARS, anchor)
	_stamp_layer(tiles.set_top, top_tiles, TOP_CHARS, anchor)
	_stamp_layer(tiles.set_ore, ore_tiles, ORE_CHARS, anchor)

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
		setter.call(x, y, characters[grid_tiles[coord]])


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
