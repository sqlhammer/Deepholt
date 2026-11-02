extends RefCounted

# Builds worlds for tests. Preloaded, with no class_name, so adding to
# it needs no re-import (as save_dirs.gd). Nothing here is in the
# tree: a test adds the world itself (add_child_autofree) when it
# needs _ready or _physics_process, or autofrees it otherwise.


# A world holding a blank level (solid minable rock) at each depth.
static func with_levels(depths: Array, world_seed: int = 0) -> World:
	var world: World = World.new()
	world.world_seed = world_seed
	for depth: int in depths:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth, world_seed)
		world.add_level(level)
	return world


# A generated world, from the real recipes.
static func generated(world_seed: int = 0) -> World:
	return LevelGenerator.generate_world(world_seed)
