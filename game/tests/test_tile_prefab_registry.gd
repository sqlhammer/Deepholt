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
