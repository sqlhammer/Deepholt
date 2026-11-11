class_name MapOverlay
extends ScaledHud

# The map (ui-ux §6, D-226, D-227): one level at a time, the levels
# above and below ghosted under it so their alignment shows, and the
# vertical anchors, ladders, holes, ramps, chutes and winches, at full
# brightness on every level they pass through, since levels share one
# origin (world-and-generation §1). Only what the world's players
# remember is drawn (D-145, D-147): never a tile nobody has seen, so
# never a cave nobody found or a crushed region's insides (015 trap 6).
# Every player is a dot on the level they're on, the viewer's own
# highlighted. It doesn't pause the game.
#
# Presentation, for the local player (D-045). View or M opens and
# closes it; LB / RB, the wheel or Page Up / Down change the level.

signal open_changed(open: bool)

# One HUD pixel per tile; the deepest level drawn so far, -4, is 259
# tiles across, which fits the frame
const TILE: int = 1
const BOARD_SIZE: Vector2 = Vector2(300, 300)
const HEADER: int = 14

const BACK: Color = Color(0.05, 0.05, 0.06, 0.92)
const FLOOR: Color = Color(0.62, 0.58, 0.52)
const SOLID: Color = Color(0.26, 0.25, 0.24)
const RUBBLE: Color = Color(0.36, 0.28, 0.27)
# The levels above and below, under the shown one
const GHOST: Color = Color(0.45, 0.6, 0.85, 0.28)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.85)
const DIM_TEXT: Color = Color(0.7, 0.7, 0.65)
const ANCHOR_COLORS: Dictionary[StringName, Color] = {
	&"ladder": Color(1.0, 0.85, 0.3),
	&"hole": Color(0.95, 0.95, 0.95),
	&"ramp": Color(0.35, 0.9, 0.95),
	&"chute": Color(1.0, 0.55, 0.2),
	&"winch": Color(0.45, 0.95, 0.5),
}
const PLAYER: Color = Color(0.85, 0.85, 0.9)
const VIEWER: Color = Color(1.0, 0.9, 0.45)
# A level's picture is rebuilt at most this often while memory grows
# under an open map: a step can remember a dozen tiles, and a rebuild
# reads the whole level. Feel, not tuning.
const REBUILD_SECONDS: float = 0.25

var is_open: bool = false
# The depth shown; set to the viewer's on opening
var shown_depth: int = 0
# Whether the keys named are a pad's (D-223)
var gamepad: bool = true

var _view: View
var _panel: PanelContainer
var _board: Control
# Each level's picture, by depth, rebuilt when its memory or tiles
# change, and only while the map is open
var _pictures: Dictionary[int, ImageTexture] = {}
var _stale: Dictionary[int, bool] = {}
var _heard: Dictionary[int, LevelTiles] = {}
var _since_build: float = 0.0


func _init() -> void:
	super()
	name = "MapOverlay"
	layer = 86
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	_board = Control.new()
	_board.custom_minimum_size = BOARD_SIZE
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	_panel.add_child(_board)


func watch(view: View) -> void:
	_view = view
	view.shown_world_changed.connect(_on_shown_world_changed)


# Another world's levels: every picture is for the old one.
func _on_shown_world_changed(_world_shown: World, _depth: int) -> void:
	_pictures.clear()
	_stale.clear()
	_heard.clear()
	set_open(false)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	var was: bool = is_open
	is_open = value and _world() != null
	_panel.visible = is_open
	if is_open and not was:
		var viewer: Actor = _viewer()
		shown_depth = viewer.depth if viewer != null else _view.shown_depth
	if is_open != was: open_changed.emit(is_open)
	_board.queue_redraw()


func set_gamepad(value: bool) -> void:
	gamepad = value
	_board.queue_redraw()


# One level up (-1) or down (+1), within the levels that exist.
func step_level(step: int) -> void:
	if not is_open: return
	var world: World = _world()
	var next: int = shown_depth + step
	if world.level_at(next) == null: return
	shown_depth = next
	_board.queue_redraw()


func _world() -> World:
	if _view == null or not is_instance_valid(_view.shown_world): return null
	return _view.shown_world


func _viewer() -> Actor:
	if _view == null or not is_instance_valid(_view.actor): return null
	return _view.actor


# --- what's on it ---

# The anchors drawn on the level at `depth`: its own ladders, holes,
# ramps, chutes and winches, those on the level above that lead down
# into it, and those on the level below that lead up into it, each
# where its own level remembers it. One entry per tile and kind:
# {tile: Vector2i, kind: StringName}.
static func anchors(world: World, depth: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary[String, bool] = {}
	for level_depth: int in [depth - 1, depth, depth + 1]:
		var level: Level = world.level_at(level_depth)
		if level == null: continue
		var tiles: LevelTiles = level.level_tiles
		for kind: int in TileKind.RAMPS:
			var down: bool = TileKind.RAMPS[kind].down
			if (level_depth < depth and not down) or (level_depth > depth and down): continue
			for tile: Vector2i in LevelGenerator.tiles_with_ground(tiles, kind):
				_add_anchor(found, seen, tiles, tile, &"ramp")
		if level_depth <= depth:
			for tile: Vector2i in LevelGenerator.tiles_with_ground(tiles, TileKind.GROUND.HOLE):
				_add_anchor(found, seen, tiles, tile, &"hole")
			for fixture: Fixture in level.level_fixtures.of_kind(ObjectKind.OBJECT.CHUTE):
				_add_anchor(found, seen, tiles, Vector2i(fixture.tile.x, fixture.tile.y), &"chute")
			for fixture: Fixture in level.level_fixtures.of_kind(ObjectKind.OBJECT.WINCH):
				_add_anchor(found, seen, tiles, Vector2i(fixture.tile.x, fixture.tile.y), &"winch")
		if level_depth >= depth:
			for fixture: Fixture in level.level_fixtures.of_kind(ObjectKind.OBJECT.LADDER):
				_add_anchor(found, seen, tiles, Vector2i(fixture.tile.x, fixture.tile.y), &"ladder")
	return found


static func _add_anchor(found: Array[Dictionary], seen: Dictionary[String, bool],
		tiles: LevelTiles, tile: Vector2i, kind: StringName) -> void:
	if not tiles.is_remembered(tile.x, tile.y): return
	var key: String = "%s %s" % [tile, kind]
	if seen.has(key): return
	seen[key] = true
	found.append({"tile": tile, "kind": kind})


# Every player on the level at `depth`, as {tile, viewer}.
static func dots(world: World, depth: int, viewer: Actor) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for player: Actor in world.players():
		if player.depth != depth or player.current_WorldPos == null: continue
		found.append({"tile": Vector2i(player.current_WorldPos.x, player.current_WorldPos.y),
			"viewer": player == viewer})
	return found


# The color a level's tile is drawn: floor or solid where remembered,
# nothing where no one has seen it. Ore isn't drawn: a remembered tile
# shows no ore in play either (D-146).
static func tile_color(tiles: LevelTiles, x: int, y: int) -> Color:
	if not tiles.is_remembered(x, y): return Color(0, 0, 0, 0)
	var top: int = tiles.get_top(x, y)
	if top == TileKind.TOP.OPEN: return FLOOR
	if top == TileKind.TOP.RUBBLE or top == TileKind.TOP.CRUSHED: return RUBBLE
	return SOLID


# A level's picture: one pixel per tile, row-major like its layers.
# Built from bytes in one pass, as Visibility builds its states.
static func picture(tiles: LevelTiles) -> Image:
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var bytes: PackedByteArray = []
	bytes.resize(width * width * 4)
	var remembered: PackedByteArray = tiles.remembered_only
	var top: PackedByteArray = tiles.top
	var floor_bytes: PackedByteArray = _rgba(FLOOR)
	var solid_bytes: PackedByteArray = _rgba(SOLID)
	var rubble_bytes: PackedByteArray = _rgba(RUBBLE)
	for index: int in range(width * width):
		if remembered[index] == 0: continue
		var color: PackedByteArray = solid_bytes
		if top[index] == TileKind.TOP.OPEN: color = floor_bytes
		elif top[index] == TileKind.TOP.RUBBLE or top[index] == TileKind.TOP.CRUSHED: color = rubble_bytes
		var at: int = index * 4
		bytes[at] = color[0]
		bytes[at + 1] = color[1]
		bytes[at + 2] = color[2]
		bytes[at + 3] = 255
	return Image.create_from_data(width, width, false, Image.FORMAT_RGBA8, bytes)


static func _rgba(color: Color) -> PackedByteArray:
	return PackedByteArray([color.r8, color.g8, color.b8, 255])


# The header: the shown level and the keys, the current scheme's only
# (D-223).
func header_text() -> String:
	var world: World = _world()
	var level: Level = world.level_at(shown_depth) if world != null else null
	var name: String = level.level_tiles.level_bound.name if level != null else ""
	var keys: String = "LB/RB: level  View: close" if gamepad \
		else "Wheel/PgUp/PgDn: level  M: close"
	return "%s %s   %s" % [DepthName.of(shown_depth), name, keys]


# --- drawing ---

func _process(delta: float) -> void:
	# Players move and memory grows while it's open: it doesn't pause
	if not is_open: return
	_since_build += delta
	_board.queue_redraw()


func _texture_for(level: Level) -> ImageTexture:
	var depth: int = level.depth
	if _heard.get(depth) != level.level_tiles:
		_heard[depth] = level.level_tiles
		level.level_tiles.memory_changed.connect(func(_t: LevelTiles) -> void: _stale[depth] = true)
		level.level_tiles.tile_changed.connect(
			func(_x: int, _y: int, _l: LevelTiles.LAYER, _t: LevelTiles) -> void: _stale[depth] = true)
		_stale[depth] = true
	var due: bool = _stale.get(depth, true) and _since_build >= REBUILD_SECONDS
	if due or not _pictures.has(depth):
		_pictures[depth] = ImageTexture.create_from_image(picture(level.level_tiles))
		_stale[depth] = false
		_since_build = 0.0
	return _pictures[depth]


func _draw_board() -> void:
	if not is_open: return
	var world: World = _world()
	if world == null: return
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	_board.draw_rect(Rect2(Vector2(-4, -4), BOARD_SIZE + Vector2(8, 8)), BACK)
	_board.draw_string(font, Vector2(0, font_size), header_text(), HORIZONTAL_ALIGNMENT_LEFT,
		BOARD_SIZE.x, font_size, TEXT_COLOR)
	# Every level shares the origin: the board's middle under the header
	var origin: Vector2 = Vector2(BOARD_SIZE.x / 2.0, HEADER + (BOARD_SIZE.y - HEADER) / 2.0)
	for ghost_depth: int in [shown_depth - 1, shown_depth + 1]:
		var ghost: Level = world.level_at(ghost_depth)
		if ghost != null: _draw_level(ghost, origin, GHOST)
	var level: Level = world.level_at(shown_depth)
	if level == null: return
	_draw_level(level, origin, Color.WHITE)
	for anchor: Dictionary in anchors(world, shown_depth):
		var at: Vector2 = origin + Vector2(anchor.tile) * TILE
		_board.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), ANCHOR_COLORS[anchor.kind])
	for dot: Dictionary in dots(world, shown_depth, _viewer()):
		var size: float = 5.0 if dot.viewer else 3.0
		var at: Vector2 = origin + Vector2(dot.tile) * TILE - Vector2(size, size) / 2.0
		_board.draw_rect(Rect2(at, Vector2(size, size)), VIEWER if dot.viewer else PLAYER)


func _draw_level(level: Level, origin: Vector2, tint: Color) -> void:
	var radius: int = level.level_tiles.level_bound.radius
	var corner: Vector2 = origin - Vector2(radius, radius) * TILE
	var texture: ImageTexture = _texture_for(level)
	_board.draw_texture_rect(texture, Rect2(corner, texture.get_size() * TILE), false, tint)
