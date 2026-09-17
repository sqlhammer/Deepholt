class_name LevelGridLoader
extends RefCounted


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


static func load(tiles: LevelTiles, ground_grid: String, top_grid: String, ore_grid: String) -> bool:
	# Validate characters in grids
	if not are_valid_characters(ground_grid,GROUND_CHARS): return false
	if not are_valid_characters(top_grid,TOP_CHARS): return false
	if not are_valid_characters(ore_grid,ORE_CHARS): return false
	
	# Validate origins
	if not _has_valid_origin(ground_grid): return false
	if not _has_valid_origin(top_grid): return false
	if not _has_valid_origin(ore_grid): return false
	
	# Validate that all ore are under minable top layers
	if _has_ore_outside_of_minable_tiles(top_grid, ore_grid): return false
	
	# Load tiles
	tiles = _load_tile_layer(tiles,"ground",ground_grid,GROUND_CHARS)
	tiles = _load_tile_layer(tiles,"top",top_grid,TOP_CHARS)
	tiles = _load_tile_layer(tiles,"ore",ore_grid,ORE_CHARS)
	
	return true


static func _has_ore_outside_of_minable_tiles(top_grid: String, ore_grid: String) -> bool:
	var i: int = -1
	for key in top_grid:
		i = i + 1
		var tile_char: String = ore_grid[i]
		if Global.contains_whitespace(key): continue # newlines don't compare correctly
		if key == "0": continue # skip origins
		if key != "#" and tile_char != ".":
			return true
	return false


static func _has_valid_origin(grid: String) -> bool:
	if grid.count("0") != 1: return false
	return true


static func _find_origin(grid: String) -> Vector2i:
	var col: int = 0
	var row: int = 0

	for tile in grid:
		if Global.contains_whitespace(tile): # next row
			row = row + 1
			col = 0
			continue
		if tile == "0":
			return Vector2i(col, row)
		col = col + 1

	return Vector2i.ZERO # unreachable; origin is validated before this runs


static func _load_tile_layer(tiles: LevelTiles, layer_name: String, grid: String, characters: Dictionary) -> LevelTiles:
	var origin: Vector2i = _find_origin(grid)
	var col: int = 0
	var row: int = 0
	
	for tile in grid:
		if Global.contains_whitespace(tile): # next row
			row = row + 1
			col = 0
			continue
	
		# world coords are relative to this grid's own origin marker,
		# not the level's corner (D-053)
		var x: int = col - origin.x
		var y: int = row - origin.y
		tiles.call("set_%s" % layer_name,x,y,characters.get(tile))
		col = col + 1
	
	return tiles


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







