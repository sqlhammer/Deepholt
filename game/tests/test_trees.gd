extends GutTest

# Trees and the axe (D-181, D-182): a tree is a fixture that blocks
# walking; holding the action facing one with an axe fells it in the
# profile's work at the axe's power, for the profile's timber, which
# overflows to the ground like a dig. Anything but an axe is refused,
# at once and once.

const TREE_TILE: Vector2i = Vector2i(1, 0)
const TICK: float = 0.1

var _world: World
var _level: Level
var _actor: Actor
var _dig: CapabilityDig
var _tree: Fixture


func before_each() -> void:
	_world = add_child_autofree(World.new())
	_level = Global.level_packed_scene.instantiate()
	_level.setup(0)
	_world.add_level(_level)
	for x in range(-2, 4):
		_level.level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
		_level.level_tiles.set_ground(x, 0, TileKind.GROUND.GRASS)
	_tree = Fixture.new(ObjectKind.OBJECT.TREE, _at(TREE_TILE), _world.fixture_ids.allocate())
	_level.level_fixtures.add(_tree)
	_actor = Actor.create(Global.actor_packed_scene, "Feller", WorldPos.new(0, 0, 0), _level,
		ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_actor.facing = Vector2i(1, 0)
	_dig = Global.get_capability_packedscene(Global.CAPABILITY.DIG).instantiate()
	_dig.actor = _actor
	_actor.get_node("Capabilities").add_child(_dig)
	watch_signals(_world)


func _at(tile: Vector2i) -> WorldPos:
	return WorldPos.new(tile.x, tile.y, 0)


func _hold(seconds: float) -> void:
	for i in range(roundi(seconds / TICK)):
		_dig.dig(TICK, _actor.tool(), _at(TREE_TILE), _level)


func _give_axe() -> void:
	_actor.pack.add(&"flint_axe", 1)


# --- the axe (D-182) ---

func test_the_axe_is_a_tool_of_its_own_class() -> void:
	var axe: Item = ItemRegistry.get_item(&"flint_axe")
	assert_true(axe.is_tool(), "a tool")
	assert_eq(axe.tool.tool_class, ToolData.CLASS.AXE, "an axe")
	assert_eq(axe.tool.power, 16.0, "flint")
	assert_eq(axe.weight_kg, 2.5, "the brief's weight")
	assert_not_null(axe.icon, "with an icon")
	assert_true(Digging.chops(axe.tool), "it chops")
	assert_false(Digging.breaches(axe.tool), "it doesn't breach")


func test_the_axe_is_a_poor_digger() -> void:
	var tuning: TuningProfile = TuningProfile.default_profile()
	var axe: ToolData = ItemRegistry.get_item(&"flint_axe").tool
	assert_eq(Digging.dig_power(tuning, axe, TileKind.TOP.MINABLE_ROCK), 4.0, "rock x0.25")
	assert_eq(Digging.dig_power(tuning, axe, TileKind.TOP.MINABLE_DIRT), 8.0, "dirt x0.5")
	assert_eq(Digging.dig_power(tuning, axe, TileKind.TOP.RUBBLE), 8.0, "rubble x0.5")


# --- trees (D-181) ---

func test_a_tree_blocks_walking_and_never_stands_on_a_ramp() -> void:
	assert_true(ObjectKind.blocks_walking(ObjectKind.OBJECT.TREE), "blocks")
	assert_true(_level.level_tiles.is_blocked(TREE_TILE.x, TREE_TILE.y), "its tile is blocked")
	_level.level_tiles.set_ground(-2, 0, TileKind.GROUND.RAMP_DOWN_E)
	assert_eq(FixturePlacement.problem(ObjectKind.OBJECT.TREE, Vector2i(-2, 0), _level.level_tiles,
		_level.level_fixtures, null), World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE, "not on a ramp")
	assert_eq(FixturePlacement.problem(ObjectKind.OBJECT.TREE, TREE_TILE, _level.level_tiles,
		_level.level_fixtures, null), World.FIXTURE_REFUSAL.TILE_OCCUPIED, "one to a tile")
	assert_not_null(FixtureRenderer.TEXTURES.get(ObjectKind.OBJECT.TREE), "it has art")


func test_the_axe_fells_a_tree_in_three_seconds_for_four_timber() -> void:
	_give_axe()
	_hold(2.9)
	assert_signal_not_emitted(_world, "tree_felled", "not yet at 2.9 s")
	_hold(0.1)
	assert_signal_emitted(_world, "tree_felled", "felled at 3 s")
	assert_eq(_actor.pack.count_of(&"timber"), 4, "four timber")
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(), 0, "the tree is gone")
	assert_false(_level.level_tiles.is_blocked(TREE_TILE.x, TREE_TILE.y), "its tile walkable")
	assert_signal_emitted(_world, "fixture_removed", "removed like any fixture")


func test_anything_but_an_axe_is_refused_at_once_and_once() -> void:
	_actor.pack.add(&"flint_pickaxe", 1)
	_hold(5.0)
	assert_signal_emit_count(_world, "chop_refused", 1, "once, not every tick")
	assert_eq(get_signal_parameters(_world, "chop_refused")[2], World.CHOP_REFUSAL.NEEDS_AXE,
		"needs an axe")
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(), 1, "still standing")
	_actor.pack.remove(&"flint_pickaxe", 1)
	_hold(5.0)
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(), 1, "bare hands neither")


func test_the_timber_overflows_to_the_ground() -> void:
	_give_axe()
	_actor.pack.add(&"stone", 18)
	_hold(3.0)
	assert_eq(_actor.pack.count_of(&"timber"), 1, "what fits: 1 timber to the 60 kg")
	assert_eq(_level.level_drops.at(TREE_TILE), {&"timber": 3}, "the rest where the tree stood")


func test_switching_away_loses_the_work() -> void:
	_give_axe()
	_hold(2.0)
	_dig.dig(TICK, _actor.tool(), _at(Vector2i(2, 0)), _level)
	_hold(2.0)
	assert_signal_not_emitted(_world, "tree_felled", "the work started over")


func test_the_notice_says_an_axe_is_needed() -> void:
	var notice: RefusalNotice = add_child_autofree(RefusalNotice.new())
	var view: View = add_child_autofree(View.new())
	view.follow(_actor)
	notice.watch(view)
	_world.chop_refused.emit(_actor, _at(TREE_TILE), World.CHOP_REFUSAL.NEEDS_AXE)
	assert_eq(notice.text, "Chopping needs an axe.", "the brief's words")


func test_a_request_for_no_tree_is_refused() -> void:
	_give_axe()
	_world.chop_requested.emit(_actor, _at(Vector2i(-1, 0)))
	assert_eq(get_signal_parameters(_world, "chop_refused")[2], World.CHOP_REFUSAL.NO_TREE,
		"nothing to fell")


func test_a_tree_round_trips_through_a_save() -> void:
	var data: Dictionary = SaveGame._serialize_levels([_level])
	var world: World = autofree(World.new())
	SaveGame._deserialize_levels(data, world)
	assert_eq(world.level_at(0).level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(), 1,
		"the tree came back")
