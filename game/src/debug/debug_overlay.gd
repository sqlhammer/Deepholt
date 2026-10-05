extends CanvasLayer

# How many tiles out from an actor the tile window reaches, so a radius of 5
# draws an 11 x 11 square.
@export var tile_window_radius: int = 5

var debug_text : Dictionary = {}

# Actors whose tile readout is shown. Polled on the timer rather
# than fed by events, so the readout is always what the world
# holds now -- including tiles that change while nobody moves.
# Keyed by instance id, not by the Actor: a freed object can't be
# looked up as a key, but instance_from_id just returns null. The
# title is kept so the section can still be removed after the
# actor is gone and its name can't be read.
var watched_actors: Dictionary[int, String] = {}


func _ready() -> void:
	$Timer.timeout.connect(_refresh_watched_actors)
	Global.connect("debug_event",set_section)
	set_section("World Seed",str(World.world_seed)) # World emits prior to this being ready. Once we implement a loading screen, World seed will update later and we can remove this.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug_overlay()


func _toggle_debug_overlay() -> void:
	self.visible = not self.visible
	_refresh_watched_actors()


func set_section(title: String, text: String, remove: bool = false) -> void:
	if remove:
		remove_section(title)
	else:
		_register_section(title, text)
	
	_update_section(debug_text)


func remove_section(title: String) -> void:
	debug_text.erase(title)
	_update_section(debug_text)


func _update_section(dict: Dictionary) -> void:
	if dict == null: return
	$DebugRichTextLabel.text = ""
	
	for key in debug_text:
		var _txt = $DebugRichTextLabel.text
		$DebugRichTextLabel.text = _txt + "[b]%s[/b]: %s\n\n" % [key, debug_text[key].text]


func _register_section(title: String, text: String) -> void:
	var display_group: int = _get_group(title)
	debug_text[title] = { "text": text, "group": display_group }
	_sort_debug_dictionary()


func _get_group(title: String) -> int:
	var group: int = 99
	
	# The Player title include the player's name
	# Strip it out for a proper match for grouping
	if title.substr(0,8) == "Player: ": title = "Player: "
	
	match title:
		"World Seed": return 0
		"Level Seed": return 0
		"Player: ": return 10
	
	return group


func _sort_debug_dictionary() -> void:
	var keys: Array = debug_text.keys()
	keys.sort_custom(func(a, b) -> bool:
		return debug_text[a].group < debug_text[b].group)
	
	var sorted: Dictionary = {}
	for key in keys:
		sorted[key] = debug_text[key]
	debug_text = sorted


func watch(actor: Actor) -> void:
	watched_actors[actor.get_instance_id()] = actor.actor_name
	_refresh_watched_actors()


func _refresh_watched_actors() -> void:
	for id: int in watched_actors.keys():
		var actor: Actor = instance_from_id(id) as Actor
		if actor == null:
			# A freed actor's section goes with it.
			remove_section(watched_actors[id])
			watched_actors.erase(id)
		elif visible:
			set_section("Player: %s" % actor.actor_name, _tile_readout(actor.current_WorldPos))


# What the world believes about the tiles around one actor, read straight out
# of the level's arrays. The window is drawn in the same characters the prefab
# grids are authored in, so standing on a prefab's anchor should print back
# the grid that was typed into it.
func _tile_readout(pos: WorldPos) -> String:
	if pos == null: return "no position"

	var tiles: LevelTiles = _find_level_tiles(pos.depth)
	if tiles == null: return "no level resident at depth %d" % pos.depth

	var index: int = tiles.get_index(pos.x, pos.y)
	var origin_index: int = tiles.get_index(0, 0)
	var where: String = "(%d, %d) depth %d [%s]  index %d of %d" % [
		pos.x, pos.y, pos.depth, World.depth_to_display(pos.depth), index, tiles.ground.size()]
	var layers: String = "ground %s  top %s  ore %s" % [
		_kind_name(TileKind.GROUND, tiles.get_ground(pos.x, pos.y)),
		_kind_name(TileKind.TOP, tiles.get_top(pos.x, pos.y)),
		_kind_name(TileKind.ORE, tiles.get_ore(pos.x, pos.y))]
	var origin: String = "origin (0, 0) index %d" % origin_index

	return "\n%s\n%s\n%s\n[code]%s[/code]" % [where, layers, origin, _tile_window(tiles, pos)]


func _tile_window(tiles: LevelTiles, pos: WorldPos) -> String:
	var rows: PackedStringArray = []
	var min_y: int = pos.y - tile_window_radius
	var max_y: int = pos.y + tile_window_radius
	var min_x: int = pos.x - tile_window_radius
	var max_x: int = pos.x + tile_window_radius

	for y in range(min_y, max_y + 1):
		var row: String = ""
		for x in range(min_x, max_x + 1):
			row = row + _tile_char(tiles, x, y, pos)
		rows.append(row)

	return "\n".join(rows)


# Blank is outside the arrays entirely and '~' is inside them but outside the
# level's radial bounds -- the two sentinels of D-059, which is the only way
# to see what a radial bound does at tile granularity before anything draws.
func _tile_char(tiles: LevelTiles, x: int, y: int, actor_pos: WorldPos) -> String:
	var top: int = tiles.get_top(x, y)
	if top == LevelTiles.SENTINEL_OUT_OF_ARRAY: return " "
	if top == LevelTiles.SENTINEL_OUT_OF_BOUNDS: return "~"
	if x == actor_pos.x and y == actor_pos.y: return "@"
	if x == 0 and y == 0: return "0"

	var ore: int = tiles.get_ore(x, y)
	if ore != TileKind.ORE.NONE and ore != TileKind.ORE.NULL:
		return _kind_name(TileKind.ORE, ore).substr(0, 1).to_lower()

	if top == TileKind.TOP.OPEN: return "."
	if top == TileKind.TOP.MINABLE_ROCK: return "#"
	return "?"


func _find_level_tiles(depth: int) -> LevelTiles:
	for level: Level in get_tree().get_nodes_in_group("levels"):
		if level.depth == depth: return level.level_tiles
	return null


func _kind_name(table: Dictionary, id: int) -> String:
	if id == LevelTiles.SENTINEL_OUT_OF_ARRAY: return "OUT OF ARRAY"
	if id == LevelTiles.SENTINEL_OUT_OF_BOUNDS: return "OUT OF BOUNDS"

	for key in table:
		if table[key] == id: return key
	return "UNKNOWN (%d)" % id








