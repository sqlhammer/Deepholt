extends RefCounted

# Builds worlds for tests. Preloaded, with no class_name, so adding to
# it needs no re-import (as save_dirs.gd). Nothing here is in the
# tree: a test adds the world itself (add_child_autofree) when it
# needs _ready or _physics_process, or autofrees it otherwise.


# A world holding a blank level (solid minable rock) at each depth.
# A profile may be given; the default is used otherwise.
static func with_levels(depths: Array, world_seed: int = 0, tuning: TuningProfile = null) -> World:
	var world: World = World.new(tuning)
	world.world_seed = world_seed
	for depth: int in depths:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth, world_seed)
		world.add_level(level)
	return world


# A generated world, from the real recipes.
static func generated(world_seed: int = 0) -> World:
	return LevelGenerator.generate_world(world_seed)

# A ladder on the level at `depth`, under the hole above it: what a
# player builds. Generation places none (D-185); the tests that climb
# the hand-made hole at (14, -2) put one there first.
static func place_ladder(world: World, depth: int, tile: Vector2i = Vector2i(14, -2)) -> Fixture:
	var ladder: Fixture = Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(tile.x, tile.y, depth),
		world.fixture_ids.allocate())
	world.level_at(depth).level_fixtures.add(ladder)
	return ladder
