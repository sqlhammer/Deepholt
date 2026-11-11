class_name FixtureRenderer
extends Node2D

# Draws the fixtures of the level on screen (D-100): a sprite per
# fixture, built from the level's LevelFixtures, the way LevelRenderer
# draws tiles from LevelTiles. Presentation only. Follows the View
# (D-094), so it only ever holds sprites for the shown depth, and
# rebuilds when the depth changes rather than keeping every level's.
#
# It also looks one level down: a ladder lives on the lower level, so
# from above its hole would look dead. For each ladder on the level
# below, a ladder top is drawn in the hole over it (D-107).

# Kinds drawn with a texture. Positioned so the sprite's bottom edge
# sits on its tile's bottom edge: a 16 x 24 ladder rises 8 px north
# (D-105).
const TEXTURES: Dictionary = {
	ObjectKind.OBJECT.LADDER: preload("res://src/render/ladder.png"),
	ObjectKind.OBJECT.BRAZIER: preload("res://src/render/brazier.png"),
	ObjectKind.OBJECT.TIMBER_PROP: preload("res://src/render/timber_prop.png"),
	ObjectKind.OBJECT.TREE: preload("res://src/render/tree.png"),
	ObjectKind.OBJECT.CHUTE: preload("res://src/render/chute.png"),
	ObjectKind.OBJECT.WINCH: preload("res://src/render/winch.png"),
	ObjectKind.OBJECT.CRATE: preload("res://src/render/crate.png"),
	ObjectKind.OBJECT.TORCH: preload("res://src/render/torch_lit.png"),
}

# The bar over a winch while its crate is on the way (D-225): how far,
# in the colors of a cursor's valid placement.
const CRANK_BAR_COLOR: Color = Color(0.45, 0.95, 0.5)
const CRANK_BAR_BACK: Color = Color(0.0, 0.0, 0.0, 0.6)
# Drawn over the actors: under them, the cranking player's own head
# hid it (Derik, walking 015)
const CRANK_BAR_Z: int = 20
# The foot of a winch's hole while its crate is up (D-232): brown
# corners, each this many pixels long
const LANDING_COLOR: Color = Color(0.55, 0.36, 0.18)
const LANDING_CORNER: float = 4.0

var _bars: Node2D

# Kinds deliberately not drawn (D-091: the world spawn is invisible to
# players). Kept apart from "no texture", which is an error: a new
# kind without art should be loud, the way a tile without art draws
# MISSING.
const INVISIBLE: Array[int] = [ObjectKind.OBJECT.WORLD_SPAWN]

const LADDER_TOP: Texture2D = preload("res://src/render/ladder_top.png")

# Sprites are sorted with the actors (D-214). An actor is on a tile
# when its feet's center is, 4 px below its origin (Actor.feet_box);
# so a sprite's origin sits 4 px above its tile's top edge, and an
# actor on the tile north of it sorts behind, any on its own tile or
# south in front. Drawn where it was by an equal and opposite offset.
const SORT_ABOVE_TILE: float = 4.0

var _fixtures: LevelFixtures
# Fixture id -> its sprite, so removal finds the right one even when
# two fixtures share a tile.
var _sprites: Dictionary[int, Sprite2D] = {}

# The level below's fixtures, the shown level's tiles, and the ladder
# tops drawn in its holes, by the ladder's id (D-107).
var _below: LevelFixtures
var _shown_tiles: LevelTiles
var _shown_depth: int = View.NO_DEPTH
var _top_sprites: Dictionary[int, Sprite2D] = {}


# The world whose fixtures are drawn, set only by the view's signal
var _world: World

# In the dark, a fixture is drawn like its tile (D-148): greyed and
# dimmed when Sensed or Remembered, hidden when Unknown, as it is when
# Lit. Without a Visibility every fixture is drawn as Lit.
const GREY: Shader = preload("res://src/render/grey.gdshader")
var _visibility: Visibility
var _sensed_material: ShaderMaterial
var _remembered_material: ShaderMaterial


func _ready() -> void:
	_bars = Node2D.new()
	_bars.name = "CrankBars"
	_bars.z_index = CRANK_BAR_Z
	_bars.draw.connect(_draw_bars)
	add_child(_bars)


# Follows the view's depth and world (D-094, D-129).
func watch(view: View) -> void:
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	view.shown_world_changed.connect(_on_shown_world_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


# Draws each sprite in its tile's state, whenever the states change.
func watch_visibility(visibility: Visibility) -> void:
	_visibility = visibility
	visibility.states_changed.connect(_apply_states)
	_apply_states()


func _apply_states() -> void:
	for sprite: Sprite2D in _sprites.values():
		_apply_state(sprite)
	for sprite: Sprite2D in _top_sprites.values():
		_apply_state(sprite)


# The state of the tile the sprite stands on (for a ladder top, the
# hole), as a material, or hidden.
func _apply_state(sprite: Sprite2D) -> void:
	var tile: Vector2i = sprite.get_meta("tile")
	# Under rubble a fixture is buried: kept, but out of sight (D-166)
	if _shown_tiles != null and _shown_tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN:
		sprite.visible = false
		return
	if _visibility == null:
		sprite.visible = true
		return
	match _visibility.state_at(tile.x, tile.y):
		Visibility.STATE.LIT:
			sprite.visible = true
			sprite.material = null
		Visibility.STATE.SENSED:
			sprite.visible = true
			sprite.material = _grey(true)
		Visibility.STATE.REMEMBERED:
			sprite.visible = true
			sprite.material = _grey(false)
		_:
			sprite.visible = false


# The shared grey material for a state, at the shown world's
# brightness (D-146).
func _grey(sensed: bool) -> ShaderMaterial:
	if _sensed_material == null:
		_sensed_material = ShaderMaterial.new()
		_sensed_material.shader = GREY
		_remembered_material = ShaderMaterial.new()
		_remembered_material.shader = GREY
	var tuning: TuningProfile = _world.tuning if is_instance_valid(_world) else null
	_sensed_material.set_shader_parameter("brightness",
		tuning.sensed_brightness if tuning != null else 1.0)
	_remembered_material.set_shader_parameter("brightness",
		tuning.remembered_brightness if tuning != null else 1.0)
	return _sensed_material if sensed else _remembered_material


func _on_shown_world_changed(world: World, depth: int) -> void:
	if is_instance_valid(_world) and _world.level_added.is_connected(_on_level_added):
		_world.level_added.disconnect(_on_level_added)
	_world = world
	if _world != null: _world.level_added.connect(_on_level_added)
	show_depth(depth)


# The level below the shown one can be generated after the shown one
# is drawn (D-143). Its ladders' tops are drawn once it arrives.
func _on_level_added(level: Level) -> void:
	if level.depth != _shown_depth + 1 or _shown_tiles == null: return
	show_ladder_tops(_shown_tiles, level.level_fixtures)


func _on_shown_depth_changed(_old_depth: int, new_depth: int) -> void:
	show_depth(new_depth)


# Draws the level at this depth, and the ladder tops from the one
# below, from the shown world's levels. Also when a new world is
# shown at the depth already shown.
func show_depth(depth: int) -> void:
	var level: Level = _world.level_at(depth) if _world != null else null
	if level == null:
		push_error("No level at depth %d to draw fixtures for." % depth)
		return
	_shown_depth = depth
	show_fixtures(level.level_fixtures)
	var below: Level = _world.level_at(depth + 1)
	show_ladder_tops(level.level_tiles, below.level_fixtures if below != null else null)


func show_fixtures(fixtures: LevelFixtures) -> void:
	_listen_to(fixtures)
	for id: int in _sprites.keys():
		_remove_sprite(id)
	for fixture: Fixture in fixtures.all():
		_add_sprite(fixture)


# Stops listening to the level shown before. Without the disconnect, a
# fixture placed on the old level would be drawn onto the new one, at
# the same coordinates (as LevelRenderer._listen_to).
func _listen_to(fixtures: LevelFixtures) -> void:
	if _fixtures == fixtures: return
	if _fixtures != null and _fixtures.fixture_changed.is_connected(_on_fixture_changed):
		_fixtures.fixture_changed.disconnect(_on_fixture_changed)
		_fixtures.fixture_moved.disconnect(_on_fixture_moved)
	_fixtures = fixtures
	_fixtures.fixture_changed.connect(_on_fixture_changed)
	_fixtures.fixture_moved.connect(_on_fixture_moved)


func _on_fixture_changed(fixture: Fixture, added: bool) -> void:
	if added:
		_add_sprite(fixture)
	else:
		_remove_sprite(fixture.id)


# The same fixture on another tile of the shown level (D-138).
func _on_fixture_moved(fixture: Fixture, _from: WorldPos) -> void:
	_remove_sprite(fixture.id)
	_add_sprite(fixture)


func _add_sprite(fixture: Fixture) -> void:
	if fixture.kind in INVISIBLE: return
	if not TEXTURES.has(fixture.kind):
		push_error("No art for fixture kind %d." % fixture.kind)
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = TEXTURES[fixture.kind]
	sprite.centered = false
	# Bottom-left of the sprite on the bottom-left of its tile (D-067).
	var tile_corner: Vector2 = Vector2(fixture.tile.x, fixture.tile.y) * TileSpace.TILE_PIXELS
	var rise: float = sprite.texture.get_height() - TileSpace.TILE_PIXELS
	_place(sprite, tile_corner - Vector2(0, rise), fixture.tile.y)
	sprite.name = "Fixture%d" % fixture.id
	sprite.set_meta("tile", Vector2i(fixture.tile.x, fixture.tile.y))
	add_child(sprite)
	_sprites[fixture.id] = sprite
	_apply_state(sprite)


# Drawn with its top-left at `top_left`, sorted by its tile's row.
func _place(sprite: Sprite2D, top_left: Vector2, row: int) -> void:
	sprite.position = Vector2(top_left.x, row * TileSpace.TILE_PIXELS - SORT_ABOVE_TILE)
	sprite.offset = Vector2(0, top_left.y - sprite.position.y)


# Where a sprite is drawn: its top-left corner, offset included.
static func top_left_of(sprite: Sprite2D) -> Vector2:
	return sprite.position + sprite.offset


func _remove_sprite(id: int) -> void:
	if not _sprites.has(id): return
	_sprites[id].queue_free()
	_sprites.erase(id)


func sprite_for(id: int) -> Sprite2D:
	return _sprites.get(id)


# --- the crank bar (D-225) ---

# The winches on the shown level whose crate is on its way, each with
# how far: what the bar draws.
func cranking() -> Dictionary[Fixture, float]:
	var found: Dictionary[Fixture, float] = {}
	if _fixtures == null or not is_instance_valid(_world): return found
	for winch: Fixture in _fixtures.of_kind(ObjectKind.OBJECT.WINCH):
		var progress: float = _world.crank_progress(winch)
		if progress > 0.0: found[winch] = progress
	return found


func _process(_delta: float) -> void:
	queue_redraw()
	if _bars != null: _bars.queue_redraw()


# The bars, on their own node over the actors.
func _draw_bars() -> void:
	var bars: Dictionary[Fixture, float] = cranking()
	for winch: Fixture in bars:
		var corner: Vector2 = Vector2(winch.tile.x, winch.tile.y) * TileSpace.TILE_PIXELS
		# Just above the winch's posts, which rise 8 px over the tile
		var top: Vector2 = corner - Vector2(0, 12)
		var filled: float = (TileSpace.TILE_PIXELS - 2) * bars[winch]
		_bars.draw_rect(Rect2(top, Vector2(TileSpace.TILE_PIXELS, 3)), CRANK_BAR_BACK)
		_bars.draw_rect(Rect2(top + Vector2(1, 1), Vector2(filled, 1)), CRANK_BAR_COLOR)


# --- where a lifted crate comes back down (D-232) ---

# The tiles of the shown level under a winch whose crate is up: where
# each crate will come down. Only those the player can see or
# remembers.
func crate_landings() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not is_instance_valid(_world): return found
	var above: Level = _world.level_at(_shown_depth - 1)
	if above == null: return found
	for winch: Fixture in above.level_fixtures.of_kind(ObjectKind.OBJECT.WINCH):
		var crate: Fixture = _world.crate_of(winch)
		if crate == null or crate.tile.depth != winch.tile.depth: continue
		var tile: Vector2i = Vector2i(winch.tile.x, winch.tile.y)
		if _visibility != null and _visibility.state_at(tile.x, tile.y) == Visibility.STATE.UNKNOWN:
			continue
		found.append(tile)
	return found


# On the floor, under the actors: this node's own drawing is behind its
# sprites and everything sorted with them.
func _draw() -> void:
	var size: float = TileSpace.TILE_PIXELS
	var length: float = LANDING_CORNER
	for tile: Vector2i in crate_landings():
		var a: Vector2 = Vector2(tile) * size + Vector2(1, 1)
		var b: Vector2 = a + Vector2(size - 2, size - 2)
		for corner: Vector2 in [a, Vector2(b.x, a.y), Vector2(a.x, b.y), b]:
			var across: float = length if corner.x == a.x else -length
			var down: float = length if corner.y == a.y else -length
			draw_line(corner, corner + Vector2(across, 0), LANDING_COLOR, 1.0)
			draw_line(corner, corner + Vector2(0, down), LANDING_COLOR, 1.0)


# Draws a ladder top in each of `shown_tiles`' holes that has a ladder
# under it in `below` (D-107). `below` is null for the deepest level.
func show_ladder_tops(shown_tiles: LevelTiles, below: LevelFixtures) -> void:
	_listen_below(below)
	_listen_to_tiles(shown_tiles)
	_shown_tiles = shown_tiles
	for id: int in _top_sprites.keys():
		_remove_top(id)
	if below == null: return
	for ladder: Fixture in below.of_kind(ObjectKind.OBJECT.LADDER):
		_add_top(ladder)


# Redraws when the shown level's tiles change, so a collapse buries
# fixtures and clearing the rubble brings them back (D-166).
func _listen_to_tiles(tiles: LevelTiles) -> void:
	if _shown_tiles == tiles: return
	if _shown_tiles != null and _shown_tiles.tile_changed.is_connected(_on_tile_changed):
		_shown_tiles.tile_changed.disconnect(_on_tile_changed)
	tiles.tile_changed.connect(_on_tile_changed)


func _on_tile_changed(_x: int, _y: int, layer: LevelTiles.LAYER, _tiles: LevelTiles) -> void:
	if layer == LevelTiles.LAYER.TOP: _apply_states()


# The same disconnect as _listen_to, for the level below: without it,
# a ladder placed two levels down would draw a top on the shown level.
func _listen_below(below: LevelFixtures) -> void:
	if _below == below: return
	if _below != null and _below.fixture_changed.is_connected(_on_below_changed):
		_below.fixture_changed.disconnect(_on_below_changed)
		_below.fixture_moved.disconnect(_on_below_moved)
	_below = below
	if _below != null:
		_below.fixture_changed.connect(_on_below_changed)
		_below.fixture_moved.connect(_on_below_moved)


func _on_below_moved(fixture: Fixture, _from: WorldPos) -> void:
	if fixture.kind != ObjectKind.OBJECT.LADDER: return
	_remove_top(fixture.id)
	_add_top(fixture)


func _on_below_changed(fixture: Fixture, added: bool) -> void:
	if fixture.kind != ObjectKind.OBJECT.LADDER: return
	if added:
		_add_top(fixture)
	else:
		_remove_top(fixture.id)


# Only in a hole: a ladder without one is a load error (D-089), and a
# top drawn on solid floor would show a way down that isn't there. The
# hole is checked when the top is drawn; nothing fills holes yet, so
# nothing re-checks it after.
func _add_top(ladder: Fixture) -> void:
	if _shown_tiles.get_ground(ladder.tile.x, ladder.tile.y) != TileKind.GROUND.HOLE: return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = LADDER_TOP
	sprite.centered = false
	_place(sprite, Vector2(ladder.tile.x, ladder.tile.y) * TileSpace.TILE_PIXELS, ladder.tile.y)
	sprite.name = "LadderTop%d" % ladder.id
	sprite.set_meta("tile", Vector2i(ladder.tile.x, ladder.tile.y))
	add_child(sprite)
	_top_sprites[ladder.id] = sprite
	_apply_state(sprite)


func _remove_top(id: int) -> void:
	if not _top_sprites.has(id): return
	_top_sprites[id].queue_free()
	_top_sprites.erase(id)


func top_sprite_for(ladder_id: int) -> Sprite2D:
	return _top_sprites.get(ladder_id)
