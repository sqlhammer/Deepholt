extends GutTest

# TilePrefabRegistry -- indexes the authored prefabs under res://content/ by
# their stable ids at startup. These tests are what prove the on-disk .tres
# format actually parses and reaches a level, rather than only the inline
# grids the loader tests use.


func test_the_authored_surface_prefab_is_registered_by_its_id() -> void:
	var prefab: TilePrefab = TilePrefabRegistry.get_prefab(&"surface_start")

	assert_not_null(prefab, "the authored surface prefab should be indexed")
	assert_eq(prefab.id, &"surface_start", "it keeps the id it was authored with")
	assert_ne(prefab.top, "", "its top grid survived the round trip through .tres")


func test_an_unknown_id_is_an_error_rather_than_a_silent_null() -> void:
	var prefab: TilePrefab = TilePrefabRegistry.get_prefab(&"no_such_prefab")

	assert_push_error("No tile prefab with id 'no_such_prefab'.", "Expected error found")
	assert_null(prefab, "an id nothing answers to returns nothing")


func test_the_authored_surface_prefab_stamps_into_a_level() -> void:
	var prefab: TilePrefab = TilePrefabRegistry.get_prefab(&"surface_start")
	var level_bounds = LevelBound.new(0, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)

	var ok: bool = LevelGridLoader.stamp(tiles, prefab, Vector2i.ZERO)

	assert_true(ok, "the authored prefab should pass every load check")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "its marker is standable open space")


# --- registering: what gets refused ---

# A fresh registry, not the autoload, so refused and accepted
# prefabs here never touch the game's real index. It isn't added to
# the tree, so it doesn't scan the disk.
func _fresh_registry() -> Node:
	var registry: Node = load("res://src/world/tile_prefab_registry.gd").new()
	autofree(registry)
	return registry


func _prefab(id: StringName) -> TilePrefab:
	return TilePrefab.from_grids(id, "0", "0", "0")


func test_a_new_prefab_is_registered_by_its_id() -> void:
	var registry: Node = _fresh_registry()
	var prefab: TilePrefab = _prefab(&"test_room")
	registry._register(prefab, "res://test_room.tres")
	assert_eq(registry.get_prefab(&"test_room"), prefab, "found by the id it carries")


func test_something_that_is_not_a_prefab_is_refused() -> void:
	var registry: Node = _fresh_registry()
	registry._register(null, "res://not_a_prefab.tres")
	assert_push_error("'res://not_a_prefab.tres' is not a tile prefab.",
		"a file that doesn't load as a prefab is an error")
	assert_eq(registry._prefabs.size(), 0, "and nothing is registered")


func test_a_prefab_without_an_id_is_refused() -> void:
	var registry: Node = _fresh_registry()
	registry._register(_prefab(&""), "res://no_id.tres")
	assert_push_error("Tile prefab 'res://no_id.tres' has no id.",
		"a prefab must carry an id")
	assert_eq(registry._prefabs.size(), 0, "and nothing is registered")


func test_a_duplicate_id_is_refused_and_the_first_kept() -> void:
	var registry: Node = _fresh_registry()
	var first: TilePrefab = _prefab(&"room")
	registry._register(first, "res://room_a.tres")
	registry._register(_prefab(&"room"), "res://room_b.tres")
	assert_push_error("Duplicate tile prefab id 'room' at 'res://room_b.tres'.",
		"two prefabs can't share an id")
	assert_eq(registry.get_prefab(&"room"), first, "the first one registered stays")
