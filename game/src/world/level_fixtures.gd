class_name LevelFixtures
extends RefCounted

# The fixtures on one level (D-100, D-103), filed by tile, several to a
# tile. Storage only: it decides nothing, and announces every change --
# generation, placing, removing, later burial -- as fixture_changed,
# the way LevelTiles announces tile_changed (D-065). Whether a change is
# allowed is the Objects gatekeeper's business.

signal fixture_changed(fixture: Fixture, added: bool)

# Keyed by Vector2i, a value type: two equal coordinates are one key.
# (A WorldPos is a reference, so two equal ones would be two keys.)
# Each value is an Array of Fixture; a tile with none has no key.
var _by_tile: Dictionary[Vector2i, Array] = {}


func add(fixture: Fixture) -> void:
	var key: Vector2i = _key(fixture.tile)
	if not _by_tile.has(key):
		_by_tile[key] = []
	_by_tile[key].append(fixture)
	fixture_changed.emit(fixture, true)


# Removes the fixture with this id, and returns it; null if there is
# none.
func remove(id: int) -> Fixture:
	var fixture: Fixture = find(id)
	if fixture == null: return null
	var key: Vector2i = _key(fixture.tile)
	_by_tile[key].erase(fixture)
	if _by_tile[key].is_empty():
		_by_tile.erase(key)
	fixture_changed.emit(fixture, false)
	return fixture


func find(id: int) -> Fixture:
	for key: Vector2i in _by_tile:
		for fixture: Fixture in _by_tile[key]:
			if fixture.id == id: return fixture
	return null


# The fixtures on one tile, in the order they were added. A new array:
# changing it doesn't change the store.
func at(tile: Vector2i) -> Array[Fixture]:
	var found: Array[Fixture] = []
	if _by_tile.has(tile):
		found.assign(_by_tile[tile])
	return found


func has_kind_at(tile: Vector2i, kind: int) -> bool:
	for fixture: Fixture in at(tile):
		if fixture.kind == kind: return true
	return false


# Every fixture on the level, in the order they were added within each
# tile and the order tiles were first used: the same every run.
func all() -> Array[Fixture]:
	var found: Array[Fixture] = []
	for key: Vector2i in _by_tile:
		found.append_array(_by_tile[key])
	return found


func of_kind(kind: int) -> Array[Fixture]:
	var found: Array[Fixture] = []
	for fixture: Fixture in all():
		if fixture.kind == kind: found.append(fixture)
	return found


func _key(tile: WorldPos) -> Vector2i:
	return Vector2i(tile.x, tile.y)
