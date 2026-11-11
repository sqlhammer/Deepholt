extends GutTest

# Telemetry for the haul (015, D-198's chute events): chutes and
# winches built, with how many trips the builder had started, so
# pre-alpha criterion 1 (a chute before the 5th expedition) can be
# counted; items sent down; crates lifted and lowered; things made;
# map opens; and all of it in the summary.

const SaveDirs = preload("res://tests/save_dirs.gd")
const Worlds = preload("res://tests/worlds.gd")
const DIR: String = SaveDirs.TEST_ROOT + "/telemetry_haul"
const CHUTE_HOLE: Vector2i = Vector2i(2, 0)
const WINCH_HOLE: Vector2i = Vector2i(-2, 0)

var _world: World
var _actor: Actor
var _telemetry: Telemetry


# The Surface and -1 and -2: on the Surface, floor around the origin
# with two holes, each with open floor below it on -1.
func before_each() -> void:
	SaveDirs.remove_tree(DIR)
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	var surface: LevelTiles = _world.level_at(0).level_tiles
	for x in range(-3, 4):
		surface.set_top(x, 0, TileKind.TOP.OPEN)
	for hole: Vector2i in [CHUTE_HOLE, WINCH_HOLE]:
		surface.set_ground(hole.x, hole.y, TileKind.GROUND.HOLE)
		_world.level_at(1).level_tiles.set_top(hole.x, hole.y, TileKind.TOP.OPEN)
	_world.level_at(1).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_actor = Actor.create(Global.actor_packed_scene, "Hauler", WorldPos.new(0, 0, 0),
		_world.level_at(0), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_telemetry = Telemetry.new()
	_telemetry.dir = DIR
	_telemetry.rolling_path = SaveDirs.TEST_ROOT + "/telemetry_haul_logs/recent.jsonl"
	add_child_autofree(_telemetry)
	_telemetry.watch_world(_world)
	_telemetry.watch_actor(_actor)
	_telemetry.begin({"build": "test"})


func after_each() -> void:
	SaveDirs.remove_tree(DIR)


func _events(name: StringName) -> Array:
	var path: String = DIR.path_join("%s%s.jsonl" % [Telemetry.SESSION_PREFIX, _telemetry.session])
	var found: Array = []
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event.event == name: found.append(event)
	return found


# Down to -1 and back up: one trip (D-208).
func _trip() -> void:
	_actor.move_to(WorldPos.new(0, 0, 1), &"test")
	_actor.move_to(WorldPos.new(0, 0, 0), &"test")


func _build(kind: int, hole: Vector2i) -> void:
	_actor.pack.add(&"timber", 12)
	_actor.pack.add(&"stone", 20)
	_world.place_requested.emit(_actor, kind, WorldPos.new(hole.x, hole.y, 0))


func test_a_chute_built_records_the_trips_before_it() -> void:
	_trip()
	_trip()
	_build(ObjectKind.OBJECT.CHUTE, CHUTE_HOLE)
	var built: Array = _events(&"built")
	assert_eq(built.size(), 1, "one built")
	assert_eq(built[0].data.kind, "CHUTE", "a chute")
	assert_eq(int(built[0].data.trips_started), 2, "after two trips: before the 5th")
	assert_eq(int(_events(&"trip_started")[1].data.trip), 2, "trips are numbered")


func test_items_down_a_chute_are_recorded() -> void:
	_build(ObjectKind.OBJECT.CHUTE, CHUTE_HOLE)
	_actor.move_to(WorldPos.new(1, 0, 0), &"test")
	_actor.facing = Vector2i.RIGHT
	_actor.pack.add(&"stone", 6)
	_world.drop_requested.emit(_actor, &"stone", 6)
	var chuted: Array = _events(&"chuted")
	assert_eq(chuted.size(), 1, "one use")
	assert_eq(int(chuted[0].data.count), 6, "six items")
	assert_eq(int(chuted[0].data.to_depth), 1, "landing on -1")


func test_a_winch_built_and_cranked_is_recorded() -> void:
	_build(ObjectKind.OBJECT.WINCH, WINCH_HOLE)
	assert_eq(_events(&"built")[0].data.kind, "WINCH", "a winch")
	_actor.move_to(WorldPos.new(-1, 0, 0), &"test")
	_actor.facing = Vector2i.LEFT
	for i in 150:
		_world.crank(_actor, 0.1)
	for i in 50:
		_world.crank(_actor, 0.1)
	var winched: Array = _events(&"winched")
	assert_eq(winched.size(), 2, "lifted and lowered")
	assert_true(winched[0].data.up, "up first")
	assert_false(winched[1].data.up, "then down")


func test_making_and_map_opens_are_recorded() -> void:
	_actor.pack.add(&"timber", 1)
	_world.craft_requested.emit(_actor, &"torch")
	_telemetry.record_map_opened(1)
	assert_eq(_events(&"crafted")[0].data.recipe, "torch", "the torch made")
	assert_eq(int(_events(&"map_opened")[0].data.depth), 1, "the map, on -1")


func test_the_summary_counts_the_haul() -> void:
	_trip()
	_build(ObjectKind.OBJECT.CHUTE, CHUTE_HOLE)
	_telemetry.record_map_opened(0)
	_telemetry.end()
	var summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(
		"%s%s.summary.json" % [Telemetry.SESSION_PREFIX, _telemetry.session])))
	assert_eq(int(summary.haul.built.CHUTE), 1, "one chute")
	assert_eq(int(summary.haul.first_chute_after_trips), 1, "after one trip")
	assert_eq(int(summary.haul.map_opens), 1, "one map open")


func test_an_npcs_building_isnt_a_players() -> void:
	_world.place_requested.emit(null, ObjectKind.OBJECT.CHUTE,
		WorldPos.new(CHUTE_HOLE.x, CHUTE_HOLE.y, 0))
	assert_eq(_events(&"built").size(), 0, "generation or no actor: not counted")


# --- 016: stations and smelting (criterion 4) ---

func test_a_smelter_built_says_where_its_builders_home_is() -> void:
	_actor.pack.add(&"timber", 6)
	_world.place_requested.emit(_actor, ObjectKind.OBJECT.BED, WorldPos.new(-3, 0, 0))
	_actor.pack.add(&"stone", 16)
	_actor.pack.add(&"timber", 8)
	_world.place_requested.emit(_actor, Building.SMELTER_FROM_TIMBER, WorldPos.new(3, 0, 0))
	var built: Array = _events(&"built")
	assert_eq(built.map(func(e: Dictionary) -> String: return e.data.kind), ["BED", "SMELTER"],
		"the bed and the smelter")
	assert_eq(int(built[1].data.home_depth), 0, "home is the bed's level")


func test_a_smelter_with_no_bed_says_so() -> void:
	_actor.pack.add(&"stone", 16)
	_actor.pack.add(&"timber", 8)
	_world.place_requested.emit(_actor, Building.SMELTER_FROM_TIMBER, WorldPos.new(3, 0, 0))
	assert_eq(int(_events(&"built")[0].data.home_depth), -1, "no bed")


func test_what_a_smelter_makes_is_recorded_with_its_level() -> void:
	_world.place_requested.emit(null, ObjectKind.OBJECT.SMELTER, WorldPos.new(1, 0, 0))
	var smelter: Fixture = _world.level_at(0).level_fixtures.of_kind(ObjectKind.OBJECT.SMELTER)[0]
	smelter.machine.load_items(&"copper_ore", 3)
	smelter.machine.load_items(&"coal", 1)
	_world.advance_time(10.0)
	var smelted: Array = _events(&"smelted")
	assert_eq(smelted.size(), 1, "one batch")
	assert_eq(smelted[0].data.item, "copper_ingot", "an ingot")
	assert_eq(int(smelted[0].data.depth), 0, "on the Surface")


func test_making_says_where_and_at_what() -> void:
	_actor.pack.add(&"stone", 3)
	_actor.pack.add(&"timber", 1)
	_world.craft_requested.emit(_actor, &"flint_pickaxe")
	var crafted: Dictionary = _events(&"crafted")[0].data
	assert_eq(crafted.station, "hand", "by hand")
	assert_eq(int(crafted.depth), 0, "on the Surface")
