extends GutTest

# The dark on screen (D-146, D-148, D-149). Visibility builds one
# state per tile of the shown level: Lit if lit, else Sensed if the
# followed actor senses it, else Remembered if memory says so, else
# Unknown. The Surface is lit throughout (D-144). Light floods from
# braziers and is never saved.

const Worlds = preload("res://tests/worlds.gd")
const STATE = Visibility.STATE

var _world: World
var _view: View
var _vis: Visibility


# A blank world with a corridor on -1 along y = 0, from -20 to 20.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	for x in range(-20, 21):
		_world.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_view = add_child_autofree(View.new())
	_vis = add_child_autofree(Visibility.new())
	_vis.watch(_view)
	_view.visibility = _vis


func _actor(x: int, depth: int = 1, kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(x, 0, depth),
		_world.level_at(depth), kind)
	_world.add_actor(actor)
	return actor


func _radius() -> int:
	return _world.tuning.sense_radius


func _brazier(x: int, depth: int = 1, id: int = 900) -> Fixture:
	var brazier: Fixture = Fixture.new(ObjectKind.OBJECT.BRAZIER, WorldPos.new(x, 0, depth), id)
	_world.level_at(depth).level_fixtures.add(brazier)
	return brazier


# --- the rule ---

func test_the_followed_actors_ring_is_sensed_and_the_rest_unknown() -> void:
	_view.follow(_actor(0))
	assert_eq(_vis.state_at(0, 0), STATE.SENSED, "where it stands")
	assert_eq(_vis.state_at(_radius(), 0), STATE.SENSED, "to the radius")
	assert_eq(_vis.state_at(0, -1), STATE.SENSED, "the wall's face")
	assert_eq(_vis.state_at(0, -2), STATE.UNKNOWN, "rock behind the wall")


func test_walked_past_tunnel_is_remembered() -> void:
	var actor: Actor = _actor(-10)
	_view.follow(actor)
	actor.move_to(WorldPos.new(10, 0, 1))
	assert_eq(_vis.state_at(-10, 0), STATE.REMEMBERED, "where it was")
	assert_eq(_vis.state_at(10, 0), STATE.SENSED, "where it is")


func test_lit_wins_over_sensed() -> void:
	_brazier(2)
	_view.follow(_actor(0))
	assert_eq(_vis.state_at(2, 0), STATE.LIT, "by the brazier")
	assert_eq(_vis.state_at(-_radius(), 0), STATE.SENSED, "out of its reach")


func test_the_surface_is_lit_throughout() -> void:
	_view.show_world(_world, 0)
	assert_eq(_vis.state_at(0, 0), STATE.LIT, "the axis")
	assert_eq(_vis.state_at(30, -30), STATE.LIT, "and inside rock")


func test_build_is_the_rule_on_its_own() -> void:
	var level: Level = _world.level_at(1)
	level.level_tiles.remember([Vector2i(5, 0)] as Array[Vector2i])
	var bytes: PackedByteArray = Visibility.build(level,
		[Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], [Vector2i(2, 0)] as Array[Vector2i])
	var tiles: LevelTiles = level.level_tiles
	assert_eq(bytes[tiles.get_index(5, 0)], STATE.REMEMBERED, "memory")
	assert_eq(bytes[tiles.get_index(1, 0)], STATE.SENSED, "sensed")
	assert_eq(bytes[tiles.get_index(2, 0)], STATE.LIT, "sensed and lit: lit")
	assert_eq(bytes[tiles.get_index(9, 0)], STATE.UNKNOWN, "nothing")


# During a fade the followed actor is already below (D-142): the level
# still on screen shows only memory.
func test_no_ring_on_a_level_the_followed_actor_has_left() -> void:
	_world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	var actor: Actor = _actor(0)
	_view.transitions = true
	_view.follow(actor)
	actor.move_to(WorldPos.new(0, 0, 2))
	assert_true(_view.is_transitioning(), "the fade still shows -1")
	assert_eq(_vis.state_at(0, 0), STATE.REMEMBERED, "remembered, not sensed")


func test_new_memory_rebuilds_the_states() -> void:
	_view.show_world(_world, 1)
	watch_signals(_vis)
	_world.level_at(1).level_tiles.remember([Vector2i(15, 0)] as Array[Vector2i])
	assert_signal_emitted(_vis, "states_changed")
	assert_eq(_vis.state_at(15, 0), STATE.REMEMBERED, "drawn once remembered")


# 004's trap: a freed or replaced world must not keep driving it.
func test_a_new_world_is_followed_and_the_old_one_isnt() -> void:
	_view.show_world(_world, 1)
	var other: World = add_child_autofree(Worlds.with_levels([0, 1]))
	var old_tiles: LevelTiles = _world.level_at(1).level_tiles
	_view.show_world(other, 1)
	watch_signals(_vis)
	old_tiles.remember([Vector2i(3, 0)] as Array[Vector2i])
	assert_signal_not_emitted(_vis, "states_changed", "the old world is not heard")
	assert_eq(_vis.shown_tiles(), other.level_at(1).level_tiles, "the new one is shown")


# --- light (D-149) ---

func test_light_floods_from_a_brazier_and_stops_at_rock() -> void:
	_brazier(0)
	var lit: Array[Vector2i] = Light.lit_tiles(_world.level_at(1), _world.tuning)
	var reach: int = _world.tuning.brazier_light_radius
	assert_has(lit, Vector2i(reach, 0), "to its radius")
	assert_does_not_have(lit, Vector2i(reach + 1, 0), "no further")
	assert_has(lit, Vector2i(0, -1), "the wall's face")
	assert_does_not_have(lit, Vector2i(0, -2), "never through rock")


func test_moving_a_brazier_moves_its_light() -> void:
	var brazier: Fixture = _brazier(-15)
	_view.show_world(_world, 1)
	assert_eq(_vis.state_at(-15, 0), STATE.LIT, "lit where it stands")
	_world.move_requested.emit(null, brazier.id, WorldPos.new(15, 0, 1))
	assert_ne(_vis.state_at(-15, 0), STATE.LIT, "dark where it was")
	assert_eq(_vis.state_at(15, 0), STATE.LIT, "lit where it went")


func test_a_brazier_placed_or_removed_relights() -> void:
	_view.show_world(_world, 1)
	_brazier(8, 1, 901)
	assert_eq(_vis.state_at(8, 0), STATE.LIT, "placed")
	_world.level_at(1).level_fixtures.remove(901)
	assert_ne(_vis.state_at(8, 0), STATE.LIT, "removed")


func test_light_follows_a_swapped_in_world() -> void:
	_view.show_world(_world, 1)
	var other: World = add_child_autofree(Worlds.with_levels([0, 1]))
	for x in range(-3, 4):
		other.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	other.level_at(1).level_fixtures.add(
		Fixture.new(ObjectKind.OBJECT.BRAZIER, WorldPos.new(0, 0, 1), 1))
	_view.show_world(other, 1)
	assert_eq(_vis.state_at(0, 0), STATE.LIT, "the new world's brazier")


func test_nothing_about_light_is_saved() -> void:
	_brazier(0)
	var data: Dictionary = SaveGame._serialize_levels(_world.levels())
	assert_eq(data[1]["tiles"].keys(), SaveGame.TILE_LAYERS, "only the tile layers")
	assert_false(data[1].has("light"), "no light entry")


# --- the hand-made levels ---

func _generated_with(depth: int) -> World:
	var world: World = add_child_autofree(LevelGenerator.generate_world(0))
	if world.level_at(depth) == null: LevelGenerator.generate_into(world, depth)
	return world


func test_the_home_cave_has_a_brazier() -> void:
	var level: Level = _generated_with(1).level_at(1)
	var braziers: Array[Fixture] = level.level_fixtures.of_kind(ObjectKind.OBJECT.BRAZIER)
	assert_eq(braziers.size(), 1, "one, in Rootshelf's home cave")
	if braziers.size() == 1:
		assert_true(braziers[0].tile.equals(WorldPos.new(2, -2, 1)), "at %s" % braziers[0].tile)


# Outcome 5: Greyseam's brazier lights one copper vein; others in the
# same cave are dark.
func test_greyseams_brazier_lights_some_copper_and_not_the_rest() -> void:
	var level: Level = _generated_with(2).level_at(2)
	var lit: Array[Vector2i] = Light.lit_tiles(level, level.world.tuning)
	var tiles: LevelTiles = level.level_tiles
	assert_eq(tiles.get_ore(-9, 5), TileKind.ORE.COPPER, "copper west of the brazier")
	assert_has(lit, Vector2i(-9, 5), "in its light")
	assert_eq(tiles.get_ore(1, -1), TileKind.ORE.COPPER, "copper across the cave")
	assert_does_not_have(lit, Vector2i(1, -1), "in the dark")


# --- what else is drawn (D-148) ---

func test_an_npc_is_drawn_only_where_sensed_or_lit() -> void:
	_view.follow(_actor(0))
	var near: Actor = _actor(2, 1, ActorKind.ACTOR.NULL)
	var far: Actor = _actor(18, 1, ActorKind.ACTOR.NULL)
	_view.track(near)
	_view.track(far)
	assert_true(near.visible, "in the ring")
	assert_false(far.visible, "in the dark")


func test_fixtures_are_dimmed_or_hidden_with_their_tile() -> void:
	var renderer: FixtureRenderer = add_child_autofree(FixtureRenderer.new())
	renderer.watch(_view)
	renderer.watch_visibility(_vis)
	var level: LevelFixtures = _world.level_at(1).level_fixtures
	_world.level_at(1).level_tiles.set_ground(5, -1, TileKind.GROUND.ROCK)
	level.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(1, 0, 1), 11))
	level.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(19, 0, 1), 12))
	_world.level_at(1).level_tiles.remember([Vector2i(-19, 0)] as Array[Vector2i])
	level.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(-19, 0, 1), 13))
	_view.follow(_actor(0))
	assert_true(renderer.sprite_for(11).visible, "sensed: drawn")
	assert_not_null(renderer.sprite_for(11).material, "greyed")
	assert_false(renderer.sprite_for(12).visible, "unknown: hidden")
	assert_true(renderer.sprite_for(13).visible, "remembered: drawn")
	assert_ne(renderer.sprite_for(13).material, renderer.sprite_for(11).material,
		"at the other brightness")


func test_the_renderer_draws_the_states() -> void:
	# As game.tscn builds one: a quad and the level shader
	var renderer: LevelRenderer = LevelRenderer.new()
	renderer.mesh = QuadMesh.new()
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = load("res://src/render/level_tiles.gdshader")
	renderer.material = shader_material
	add_child_autofree(renderer)
	renderer.watch(_view)
	renderer.watch_visibility(_vis)
	_view.follow(_actor(0))
	assert_eq(renderer.drawn_state_at(0, 0), STATE.SENSED, "the ring")
	assert_eq(renderer.drawn_state_at(0, -2), STATE.UNKNOWN, "black rock")
