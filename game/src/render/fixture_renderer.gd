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
}

# Kinds deliberately not drawn (D-091: the world spawn is invisible to
# players). Kept apart from "no texture", which is an error: a new
# kind without art should be loud, the way a tile without art draws
# MISSING.
const INVISIBLE: Array[int] = [ObjectKind.OBJECT.WORLD_SPAWN]

const LADDER_TOP: Texture2D = preload("res://src/render/ladder_top.png")

var _fixtures: LevelFixtures
# Fixture id -> its sprite, so removal finds the right one even when
# two fixtures share a tile.
var _sprites: Dictionary[int, Sprite2D] = {}

# The level below's fixtures, the shown level's tiles, and the ladder
# tops drawn in its holes, by the ladder's id (D-107).
var _below: LevelFixtures
var _shown_tiles: LevelTiles
var _top_sprites: Dictionary[int, Sprite2D] = {}


# The world whose fixtures are drawn, set only by the view's signal
var _world: World


# Follows the view's depth and world (D-094, D-129).
func watch(view: View) -> void:
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	view.shown_world_changed.connect(_on_shown_world_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


func _on_shown_world_changed(world: World, depth: int) -> void:
	_world = world
	show_depth(depth)


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
	sprite.position = tile_corner - Vector2(0, rise)
	sprite.name = "Fixture%d" % fixture.id
	add_child(sprite)
	_sprites[fixture.id] = sprite


func _remove_sprite(id: int) -> void:
	if not _sprites.has(id): return
	_sprites[id].queue_free()
	_sprites.erase(id)


func sprite_for(id: int) -> Sprite2D:
	return _sprites.get(id)


# Draws a ladder top in each of `shown_tiles`' holes that has a ladder
# under it in `below` (D-107). `below` is null for the deepest level.
func show_ladder_tops(shown_tiles: LevelTiles, below: LevelFixtures) -> void:
	_listen_below(below)
	_shown_tiles = shown_tiles
	for id: int in _top_sprites.keys():
		_remove_top(id)
	if below == null: return
	for ladder: Fixture in below.of_kind(ObjectKind.OBJECT.LADDER):
		_add_top(ladder)


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
	sprite.position = Vector2(ladder.tile.x, ladder.tile.y) * TileSpace.TILE_PIXELS
	sprite.name = "LadderTop%d" % ladder.id
	add_child(sprite)
	_top_sprites[ladder.id] = sprite


func _remove_top(id: int) -> void:
	if not _top_sprites.has(id): return
	_top_sprites[id].queue_free()
	_top_sprites.erase(id)


func top_sprite_for(ladder_id: int) -> Sprite2D:
	return _top_sprites.get(ladder_id)
