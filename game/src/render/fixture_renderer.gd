class_name FixtureRenderer
extends Node2D

# Draws the fixtures of the level on screen (D-100): a sprite per
# fixture, built from the level's LevelFixtures, the way LevelRenderer
# draws tiles from LevelTiles. Presentation only. Follows the View
# (D-094), so it only ever holds sprites for the shown depth, and
# rebuilds when the depth changes rather than keeping every level's.

# Kinds drawn with a texture. Positioned so the sprite's bottom edge
# sits on its tile's bottom edge: a 16 x 24 ladder rises 8 px north
# (D-105).
const TEXTURES: Dictionary = {
	ObjectKind.OBJECT.LADDER: preload("res://src/render/ladder.png"),
}

# Kinds deliberately not drawn (D-091: the world spawn is invisible to
# players). Kept apart from "no texture", which is an error: a new kind
# without art should be loud, the way a tile without art draws MISSING.
const INVISIBLE: Array[int] = [ObjectKind.OBJECT.WORLD_SPAWN]

var _fixtures: LevelFixtures
# Fixture id -> its sprite, so removal finds the right one even when
# two fixtures share a tile.
var _sprites: Dictionary[int, Sprite2D] = {}


func watch(view: View) -> void:
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	if view.shown_depth != View.NO_DEPTH:
		_on_shown_depth_changed(View.NO_DEPTH, view.shown_depth)


func _on_shown_depth_changed(_old_depth: int, new_depth: int) -> void:
	var level: Level = World.get_level_by_depth(new_depth)
	if level == null:
		push_error("No level at depth %d to draw fixtures for." % new_depth)
		return
	show_fixtures(level.level_fixtures)


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
	_fixtures = fixtures
	_fixtures.fixture_changed.connect(_on_fixture_changed)


func _on_fixture_changed(fixture: Fixture, added: bool) -> void:
	if added:
		_add_sprite(fixture)
	else:
		_remove_sprite(fixture.id)


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
