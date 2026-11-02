extends CanvasLayer

# How many tiles out from an actor the tile window reaches, so a
# radius of 5 draws an 11 x 11 square.
@export var tile_window_radius: int = 5
var game: Node

var debug_text : Dictionary = {}

# Actors whose tile readout is shown. Polled on the timer rather
# than fed by events, so the readout is always what the world
# holds now -- including tiles that change while nobody moves.
# Keyed by instance id, not by the Actor: a freed object can't be
# looked up as a key, but instance_from_id just returns null. The
# title is kept so the section can still be removed after the
# actor is gone and its name can't be read.
var watched_actors: Dictionary[int, String] = {}
# The world on screen, as the view announces it (D-129). Every level
# the overlay reads comes from here; nothing searches the tree.
var world: World

func _ready() -> void:
	$Timer.timeout.connect(_refresh_watched_actors)
	Global.debug_event.connect(set_section)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		toggle_debug_overlay()


func toggle_debug_overlay() -> void:
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
	debug_text[title] = { "text": text, "group": _get_group(title) }
	_sort_debug_dictionary()


func _get_group(title: String) -> int:
	var group: int = 99
	
	# The Player title include the player's name
	# Strip it out for a proper match for grouping
	if title.substr(0,8) == "Player: ": title = "Player: "
	
	match title:
		"World Seed": return 0
		"Level Seed": return 0
		WORLD_SPAWN_SECTION: return 0
		NEXT_IDS_SECTION: return 0
		LOAD_PROBLEMS_SECTION: return 0
		SAVE_SECTION: return 0
		SAVE_TIME_SECTION: return 0
		LOAD_TIME_SECTION: return 0
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
	watched_actors[actor.get_instance_id()] = _get_player_debug_title(actor)
	_refresh_watched_actors()


func _get_player_debug_title(actor: Actor) -> String:
	return "Player: %s" % actor.actor_name


func _refresh_watched_actors() -> void:
	for id: int in watched_actors.keys():
		var actor: Actor = instance_from_id(id) as Actor
		if actor == null:
			# A freed actor's section goes with it.
			remove_section(watched_actors[id])
			watched_actors.erase(id)
		elif visible:
			set_section(watched_actors[id], _tile_readout(actor.current_WorldPos))
	if visible:
		set_section(WORLD_SPAWN_SECTION, world_spawn_text())
		set_section(NEXT_IDS_SECTION, next_ids_text())


const WORLD_SPAWN_SECTION: String = "World spawn"
const NEXT_IDS_SECTION: String = "Next ids"


# The ids the shown world hands out next (D-118). Polled, so it
# follows a placement or a new actor, and a load shows whether the
# counters carried on (slice 004, outcome 3).
func next_ids_text() -> String:
	# A load that gives nobody control leaves the view, and so this,
	# on the freed world
	if not is_instance_valid(world): return "no world"
	return "fixture #%d  actor #%d" % [world.fixture_ids.peek(), world.actor_ids.peek()]


# Where the world's default spawn is (D-091, D-105): the one fixture
# players can't see. Read from the levels' stores, as spawning does.
# Says so plainly when there isn't exactly one, rather than erroring:
# the overlay is how you'd find that out.
func world_spawn_text() -> String:
	var spawns: Array[Fixture] = []
	if not is_instance_valid(world): return "none"
	for level: Level in world.levels():
		spawns.append_array(level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN))
	if spawns.is_empty():
		return "none"
	if spawns.size() > 1:
		return "%d of them (expected one)" % spawns.size()
	var tile: WorldPos = spawns[0].tile
	return "(%d, %d) depth %d [%s]  #%d" % [
		tile.x, tile.y, tile.depth, DepthName.of(tile.depth), spawns[0].id]


# What the world believes about the tiles around one actor, read
# straight out of the level's arrays. The window is drawn in the same
# characters the prefab grids are authored in, so standing on a
# prefab's anchor should print back the grid that was typed into it.
func _tile_readout(pos: WorldPos) -> String:
	if pos == null: return "no position"

	var tiles: LevelTiles = _find_level_tiles(pos.depth)
	if tiles == null: return "no level resident at depth %d" % pos.depth

	var index: int = tiles.get_index(pos.x, pos.y)
	var origin_index: int = tiles.get_index(0, 0)
	var where: String = "(%d, %d) depth %d [%s]  index %d of %d" % [
		pos.x, pos.y, pos.depth, DepthName.of(pos.depth), index, tiles.ground.size()]
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


# Blank is outside the arrays entirely and '~' is inside them but
# outside the level's radial bounds -- the two sentinels of D-059,
# which is the only way to see what a radial bound does at tile
# granularity before anything draws.
func _tile_char(tiles: LevelTiles, x: int, y: int, actor_pos: WorldPos) -> String:
	var top: int = tiles.get_top(x, y)
	if top == TileKind.SENTINEL_OUT_OF_ARRAY: return " "
	if top == TileKind.SENTINEL_OUT_OF_BOUNDS: return "~"
	if x == actor_pos.x and y == actor_pos.y: return "@"
	if x == 0 and y == 0: return "0"

	var ore: int = tiles.get_ore(x, y)
	if ore != TileKind.ORE.NONE and ore != TileKind.ORE.NULL:
		return _kind_name(TileKind.ORE, ore).substr(0, 1).to_lower()

	if top == TileKind.TOP.OPEN:
		return _ground_char(tiles.get_ground(x, y))
	if top == TileKind.TOP.MINABLE_ROCK: return "#"
	if top == TileKind.TOP.MINABLE_DIRT: return "%"
	return "?"


func _find_level_tiles(depth: int) -> LevelTiles:
	if not is_instance_valid(world): return null
	var level: Level = world.level_at(depth)
	return level.level_tiles if level != null else null


func _kind_name(table: Dictionary, id: int) -> String:
	if id == TileKind.SENTINEL_OUT_OF_ARRAY: return "OUT OF ARRAY"
	if id == TileKind.SENTINEL_OUT_OF_BOUNDS: return "OUT OF BOUNDS"

	for key in table:
		if table[key] == id: return key
	return "UNKNOWN (%d)" % id


const LOAD_PROBLEMS_SECTION: String = "Load problems"


# How many problems the last load reported (D-113). Each is also a
# warning in the log; this is how you'd notice there were any.
func show_load_problems(count: int) -> void:
	set_section(LOAD_PROBLEMS_SECTION, str(count))


const SAVE_SECTION: String = "Save"


# Where this session's world came from, and the format version it was
# saved in; a new world shows the version it will be saved in
# (outcome 7). A refused slot has no version to show.
func show_load_source(source: SaveGame.SOURCE, format_version: int) -> void:
	set_section(SAVE_SECTION, load_source_text(source, format_version))


const SAVE_TIME_SECTION: String = "Last save"
const LOAD_TIME_SECTION: String = "Last load"


# Over about a frame (16 ms), a timer save is felt mid-play (D-110).
func show_save_time(msec: float) -> void:
	set_section(SAVE_TIME_SECTION, "%.1f ms" % msec)


func show_load_time(msec: float) -> void:
	set_section(LOAD_TIME_SECTION, "%.1f ms" % msec)


static func load_source_text(source: SaveGame.SOURCE, format_version: int) -> String:
	match source:
		SaveGame.SOURCE.NEW: return "new, format %d" % format_version
		SaveGame.SOURCE.SAVE: return "loaded, format %d" % format_version
		SaveGame.SOURCE.BACKUP: return "loaded from the backup, format %d" % format_version
	return "refused: nothing loaded"


const VIEW_SECTION: String = "Shown depth"


# The depth on screen, next to each watched actor's own depth, so a
# disagreement between the two is visible (outcome 7).
func watch_view(view: View) -> void:
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	view.shown_world_changed.connect(_on_shown_world_changed)
	_on_shown_world_changed(view.shown_world, view.shown_depth)


func _on_shown_world_changed(p_world: World, depth: int) -> void:
	world = p_world
	if world != null:
		set_section("World Seed", str(world.world_seed))
		set_section(NEXT_IDS_SECTION, next_ids_text())
	_on_shown_depth_changed(View.NO_DEPTH, depth)


func _on_shown_depth_changed(_old_depth: int, new_depth: int) -> void:
	if new_depth == View.NO_DEPTH:
		set_section(VIEW_SECTION, "none")
		return
	set_section(VIEW_SECTION, "%d [%s]" % [new_depth, DepthName.of(new_depth)])


# Open floor prints '.', unless its ground is a ramp or a hole: then
# the letter it is authored with (D-096), so the window reads like the
# grid.
func _ground_char(ground: int) -> String:
	if not TileKind.is_ramp(ground) and ground != TileKind.GROUND.HOLE:
		return "."
	for character: String in LevelGridLoader.GROUND_CHARS:
		if LevelGridLoader.GROUND_CHARS[character] == ground:
			return character
	return "."


func _on_active_play_timer() -> void:
	if not game: return
	set_section("Active Play Time", game.get_active_play_time())


func _on_total_play_timer() -> void:
	if not game: return
	var time: String = game.get_total_play_time()
	set_section("Total Play Time", time)


func connect_timers(active_play_timer: Timer, total_play_timer: Timer) -> void:
	if active_play_timer.has_signal("timeout"):
		active_play_timer.timeout.connect(_on_active_play_timer)
	if total_play_timer.has_signal("timeout"):
		total_play_timer.timeout.connect(_on_total_play_timer)




























