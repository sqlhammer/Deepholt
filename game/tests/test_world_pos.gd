extends GutTest


func test_stores_constructor_values() -> void:
	var pos: WorldPos = WorldPos.new(3, -5, 2)
	assert_eq(pos.x, 3, "x should match the constructor argument")
	assert_eq(pos.y, -5, "y should match the constructor argument")
	assert_eq(pos.depth, 2, "depth should match the constructor argument")


func test_hash_value_differs_for_different_depth() -> void:
	var surface: WorldPos = WorldPos.new(4, 4, 0)
	var rootshelf: WorldPos = WorldPos.new(4, 4, 1)
	assert_ne(surface.hash_value(), rootshelf.hash_value(),
		"same column on two different depths should not collide")




