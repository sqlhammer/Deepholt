extends GutTest

# Two worlds in one process (D-118: nothing may assume there is
# exactly one). Same depths, each with an actor, both in the tree:
# whatever happens in one leaves the other untouched (slice 004
# outcomes 5 and 7).

const OPEN: Vector2i = Vector2i(2, -3)
const ROCK: Vector2i = Vector2i(5, 5)

var _first: World
var _second: World
var _first_actor: Actor
var _second_actor: Actor


# A world with depths 0 and 1, rock but for OPEN on each, and a player
# standing on OPEN at the Surface.
func _world_with_actor(actor_name: String) -> World:
	var world: World = add_child_autofree(World.new())
	# Blank -2 too: an actor arriving on -1 would otherwise generate the
	# real -2 under this blank -1 (D-143)
	for depth in [0, 1, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		level.level_tiles.set_top(OPEN.x, OPEN.y, TileKind.TOP.OPEN)
		world.add_level(level)
	var actor: Actor = Actor.create(Global.actor_packed_scene, actor_name,
		WorldPos.new(OPEN.x, OPEN.y, 0), world.level_at(0), ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	return world


func before_each() -> void:
	_first = _world_with_actor("First")
	_second = _world_with_actor("Second")
	_first_actor = _first.players()[0]
	_second_actor = _second.players()[0]


func test_each_world_holds_its_own_levels_and_actor() -> void:
	assert_ne(_first.level_at(0), _second.level_at(0), "two Surfaces")
	assert_eq(_first_actor.current_level.world, _first, "the first actor is in the first world")
	assert_eq(_second_actor.current_level.world, _second, "and the second in the second")
	assert_eq(_first_actor.actor_id, _second_actor.actor_id,
		"each world numbers its own actors, so both are its first")


func test_a_dig_in_one_world_leaves_the_other_untouched() -> void:
	watch_signals(_second)
	_first.dig_requested.emit(_first_actor, WorldPos.new(ROCK.x, ROCK.y, 0))
	assert_eq(_first.level_at(0).level_tiles.get_top(ROCK.x, ROCK.y), TileKind.TOP.OPEN,
		"dug in the first")
	assert_eq(_second.level_at(0).level_tiles.get_top(ROCK.x, ROCK.y), TileKind.TOP.MINABLE_ROCK,
		"still rock in the second")
	assert_signal_not_emitted(_second, "tile_dug", "and the second world heard nothing")


# The dig capability reaches the gatekeeper through its actor (D-126):
# a dig held to completion opens its own world's tile.
func test_a_held_dig_goes_to_the_diggers_world() -> void:
	for actor: Actor in [_first_actor, _second_actor]:
		var capability: CapabilityDig = Global.get_capability_packedscene(
			Global.CAPABILITY.DIG).instantiate()
		capability.actor = actor
		actor.get_node("Capabilities").add_child(capability)
	_first_actor.aim(Vector2.ZERO, Vector2.UP)
	var target: WorldPos = _first_actor._get_target_tile()
	watch_signals(_second)
	_first_actor.primary_action(true)
	var ticks: int = 0
	while _first.level_at(0).level_tiles.get_top(target.x, target.y) != TileKind.TOP.OPEN and ticks < 600:
		_first_actor._physics_process(1.0 / 60.0)
		ticks += 1
	assert_eq(_first.level_at(0).level_tiles.get_top(target.x, target.y), TileKind.TOP.OPEN,
		"the first world's tile opened")
	assert_eq(_second.level_at(0).level_tiles.get_top(target.x, target.y), TileKind.TOP.MINABLE_ROCK,
		"the second's didn't")
	assert_signal_not_emitted(_second, "dig_requested", "nothing was asked of the second world")


func test_a_depth_change_in_one_world_stays_in_that_world() -> void:
	assert_true(_first_actor.move_to(WorldPos.new(OPEN.x, OPEN.y, 1)), "the first actor goes down")
	assert_eq(_first_actor.current_level, _first.level_at(1), "onto its own world's -1")
	assert_eq(_second_actor.depth, 0, "the second actor didn't move")
	assert_eq(_second_actor.current_level, _second.level_at(0), "and is on its own Surface")


func test_a_depth_set_finds_the_level_in_the_actors_own_world() -> void:
	_second_actor.depth = 1
	assert_eq(_second_actor.current_level, _second.level_at(1), "the second world's -1, not the first's")


func test_a_fixture_placed_in_one_world_leaves_the_other_untouched() -> void:
	var counter: int = _second.fixture_ids.peek()
	watch_signals(_second)
	_first.place_requested.emit(_first_actor, ObjectKind.OBJECT.WORLD_SPAWN, WorldPos.new(OPEN.x, OPEN.y, 1))
	assert_eq(_first.level_at(1).level_fixtures.at(OPEN).size(), 1, "placed in the first")
	assert_eq(_second.level_at(1).level_fixtures.at(OPEN).size(), 0, "not in the second")
	assert_eq(_second.fixture_ids.peek(), counter, "the second's counter is untouched")
	assert_signal_not_emitted(_second, "fixture_placed", "and it heard nothing")


func test_the_same_signal_on_two_worlds_reaches_only_its_own() -> void:
	watch_signals(_first)
	_second.remove_requested.emit(null, 4242)
	assert_signal_not_emitted(_first, "request_refused", "the first world wasn't asked")


# --- freeing a world (outcome 7) ---

func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func test_freeing_a_world_out_of_the_tree_leaves_no_orphans() -> void:
	var before: int = _orphans()
	var world: World = LevelGenerator.generate_world(0)
	var level: Level = world.level_at(0)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Gone", WorldPos.new(0, 0, 0),
		level, ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	assert_gt(_orphans(), before, "a world out of the tree is all orphans")
	world.free()
	assert_eq(_orphans(), before, "freed, it leaves none")
	assert_false(is_instance_valid(level), "its levels went with it")
	assert_false(is_instance_valid(actor), "and its actors")


func test_freeing_one_world_leaves_the_other_whole() -> void:
	_first.free()
	assert_true(is_instance_valid(_second_actor), "the other world's actor")
	assert_true(is_instance_valid(_second.level_at(0)), "and its levels are still there")
	assert_true(_second_actor.move_to(WorldPos.new(OPEN.x, OPEN.y, 1)), "and it still works")


# --- nothing searches the tree (trap 2, outcome 7) ---

# The lookups that assume one world in the tree. A grep, kept as a
# test so it runs every time rather than once.
const TREE_SEARCHES: Array[String] = [
	"get_nodes_in_group(", "get_first_node_in_group(", "add_to_group(", "is_in_group(",
	"groups=[",
]


func _files_under(directory: String, extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.get_extension() in extensions:
			found.append(directory.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(directory):
		found.append_array(_files_under(directory.path_join(sub), extensions))
	return found


func test_no_game_code_searches_the_tree_for_levels_or_actors() -> void:
	var files: Array[String] = _files_under("res://src", ["gd", "tscn"])
	files.append_array(_files_under("res://scenes", ["gd", "tscn"]))
	assert_gt(files.size(), 10, "the source was found")
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for search: String in TREE_SEARCHES:
			assert_false(text.contains(search), "%s uses %s" % [path, search])
