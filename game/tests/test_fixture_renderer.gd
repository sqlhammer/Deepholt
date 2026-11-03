extends GutTest

# FixtureRenderer -- a sprite per fixture on the shown level (D-100),
# following the View (D-094). The world spawn is drawn by nothing
# (D-091); a kind with no art is an error, not a silent gap.

const SPOT: Vector2i = Vector2i(2, -3)

var _world: World
var _levels: Array[Level] = []


func before_each() -> void:
	_levels.clear()
	_world = add_child_autofree(World.new())
	# Blank -2 too: an actor arriving on -1 would otherwise generate the
	# real -2 under this blank -1 (D-143)
	for depth in [0, 1, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		_world.add_level(level)
		level.level_tiles.set_top(SPOT.x, SPOT.y, TileKind.TOP.OPEN)
		_levels.append(level)


func _renderer() -> FixtureRenderer:
	var renderer: FixtureRenderer = FixtureRenderer.new()
	add_child_autofree(renderer)
	return renderer


func _ladder(depth: int, id: int, tile: Vector2i = SPOT) -> Fixture:
	return Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(tile.x, tile.y, depth), id)


func _following_actor_at(depth: int) -> Array:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(SPOT.x, SPOT.y, depth), _world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	var view: View = View.new()
	add_child_autofree(view)
	view.follow(actor)
	return [actor, view]


func test_a_fixture_on_the_shown_level_gets_a_sprite_rising_from_its_tile() -> void:
	_levels[1].level_fixtures.add(_ladder(1, 7))
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	var sprite: Sprite2D = renderer.sprite_for(7)
	assert_not_null(sprite, "drawn")
	if sprite:
		assert_eq(sprite.position, Vector2(32, -56), "bottom on tile (2, -3)'s bottom: rises 8 px north")
		assert_eq(sprite.texture.get_size(), Vector2(16, 24), "16 x 24 (D-105)")


func test_a_fixture_added_while_shown_appears_and_removed_disappears() -> void:
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	_levels[1].level_fixtures.add(_ladder(1, 3))
	assert_not_null(renderer.sprite_for(3), "added")
	_levels[1].level_fixtures.remove(3)
	assert_null(renderer.sprite_for(3), "removed")


# D-138: a move is the same fixture, so the sprite goes with it.
func test_a_fixture_moved_on_the_shown_level_moves_its_sprite() -> void:
	_levels[1].level_fixtures.add(_ladder(1, 4))
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	_levels[1].level_fixtures.move(4, WorldPos.new(SPOT.x + 1, SPOT.y, 1))
	var sprite: Sprite2D = renderer.sprite_for(4)
	assert_not_null(sprite, "still drawn")
	if sprite: assert_eq(sprite.position, Vector2(48, -56), "on tile (3, -3) now")
	assert_eq(renderer._sprites.size(), 1, "one sprite, not two")


func test_removing_one_of_two_fixtures_on_a_tile_removes_only_its_sprite() -> void:
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	_levels[1].level_fixtures.add(_ladder(1, 1))
	_levels[1].level_fixtures.add(_ladder(1, 2))
	_levels[1].level_fixtures.remove(1)
	assert_null(renderer.sprite_for(1), "the removed one")
	assert_not_null(renderer.sprite_for(2), "the other stays")


func test_a_fixture_on_another_depth_is_not_drawn_until_the_view_goes_there() -> void:
	_levels[1].level_fixtures.add(_ladder(1, 5))
	var pair: Array = _following_actor_at(0)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(pair[1])
	assert_null(renderer.sprite_for(5), "not drawn while the Surface is shown")
	pair[0].move_to(WorldPos.new(SPOT.x, SPOT.y, 1))
	assert_not_null(renderer.sprite_for(5), "drawn once -1 is shown")


func test_changes_on_a_level_no_longer_shown_are_ignored() -> void:
	var pair: Array = _following_actor_at(0)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(pair[1])
	pair[0].move_to(WorldPos.new(SPOT.x, SPOT.y, 1))
	_levels[0].level_fixtures.add(_ladder(0, 9))
	assert_null(renderer.sprite_for(9), "the Surface isn't shown: nothing drawn on -1")


func test_the_world_spawn_has_no_sprite() -> void:
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	_levels[1].level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN, WorldPos.new(0, 0, 1), 4))
	assert_null(renderer.sprite_for(4), "invisible on purpose (D-091)")
	assert_eq(renderer.get_child_count(), 0, "no node made for it")


func test_a_kind_with_no_art_is_an_error() -> void:
	var renderer: FixtureRenderer = _renderer()
	renderer.show_fixtures(_levels[1].level_fixtures)
	_levels[1].level_fixtures.add(Fixture.new(200, WorldPos.new(0, 0, 1), 6))
	assert_push_error("No art for fixture kind 200.")
	assert_null(renderer.sprite_for(6), "nothing drawn")


func test_every_kind_has_art_or_is_invisible() -> void:
	for kind: int in ObjectKind.OBJECT.values():
		if kind == ObjectKind.OBJECT.NULL: continue
		assert_true(FixtureRenderer.TEXTURES.has(kind) or kind in FixtureRenderer.INVISIBLE,
			"%s has art or is invisible on purpose" % ObjectKind.OBJECT.find_key(kind))


func test_the_game_draws_fixtures_below_actors() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	# Keep its slot lookup out of the real saves folder
	game.saves_root = "user://test_saves/fixture_renderer"
	add_child_autofree(game)
	var viewport: Node = game.get_node("GameViewport")
	assert_lt(viewport.get_node("FixtureRenderer").get_index(), viewport.get_node("World").get_index(),
		"fixtures draw before the world's actors, so actors stand over a ladder")


func test_moving_to_another_level_clears_the_old_levels_sprites() -> void:
	_levels[0].level_fixtures.add(_ladder(0, 11))
	var pair: Array = _following_actor_at(0)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(pair[1])
	assert_not_null(renderer.sprite_for(11), "the Surface's ladder is drawn")
	pair[0].move_to(WorldPos.new(SPOT.x, SPOT.y, 1))
	assert_null(renderer.sprite_for(11), "and gone once -1 is shown")


func test_a_shown_depth_with_no_level_is_an_error() -> void:
	var renderer: FixtureRenderer = _renderer()
	renderer._on_shown_depth_changed(View.NO_DEPTH, 99)
	assert_push_error("No level at depth 99 to draw fixtures for.")


# --- ladder tops (D-107): a ladder below shows in the hole above ---

func _hole_over_spot() -> void:
	_levels[0].level_tiles.set_ground(SPOT.x, SPOT.y, TileKind.GROUND.HOLE)


func _surface_view_renderer() -> Array:
	var pair: Array = _following_actor_at(0)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(pair[1])
	return [pair[0], renderer]


func test_a_hole_with_a_ladder_below_shows_its_top() -> void:
	_hole_over_spot()
	_levels[1].level_fixtures.add(_ladder(1, 21))
	var renderer: FixtureRenderer = _surface_view_renderer()[1]
	var top: Sprite2D = renderer.top_sprite_for(21)
	assert_not_null(top, "a ladder top in the hole")
	if top:
		assert_eq(top.position, Vector2(32, -48), "on tile (2, -3), not rising")
		assert_eq(top.texture.get_size(), Vector2(16, 16), "one tile")


func test_a_dead_hole_shows_no_top() -> void:
	_hole_over_spot()
	var renderer: FixtureRenderer = _surface_view_renderer()[1]
	assert_eq(renderer._top_sprites.size(), 0, "no ladder below, nothing drawn")


func test_a_ladder_placed_below_adds_its_top_and_removing_it_takes_it_away() -> void:
	_hole_over_spot()
	var renderer: FixtureRenderer = _surface_view_renderer()[1]
	_levels[1].level_fixtures.add(_ladder(1, 22))
	assert_not_null(renderer.top_sprite_for(22), "appears when the ladder is placed")
	_levels[1].level_fixtures.remove(22)
	assert_null(renderer.top_sprite_for(22), "and goes when it's removed: the hole reads as dead")


func test_a_ladder_moved_below_moves_its_top() -> void:
	_hole_over_spot()
	var other: Vector2i = SPOT + Vector2i(1, 0)
	_levels[0].level_tiles.set_top(other.x, other.y, TileKind.TOP.OPEN)
	_levels[0].level_tiles.set_ground(other.x, other.y, TileKind.GROUND.HOLE)
	_levels[1].level_fixtures.add(_ladder(1, 23))
	var renderer: FixtureRenderer = _surface_view_renderer()[1]
	_levels[1].level_fixtures.move(23, WorldPos.new(other.x, other.y, 1))
	var top: Sprite2D = renderer.top_sprite_for(23)
	assert_not_null(top, "the top follows the ladder")
	if top: assert_eq(top.position, Vector2(48, -48), "into the other hole")


func test_a_ladder_below_with_no_hole_over_it_shows_no_top() -> void:
	_levels[1].level_fixtures.add(_ladder(1, 23))
	var renderer: FixtureRenderer = _surface_view_renderer()[1]
	assert_null(renderer.top_sprite_for(23), "no way down drawn on solid floor")


func test_tops_are_only_for_the_level_below_the_shown_one() -> void:
	_hole_over_spot()
	_levels[1].level_fixtures.add(_ladder(1, 24))
	var parts: Array = _surface_view_renderer()
	parts[0].move_to(WorldPos.new(SPOT.x, SPOT.y, 1))
	assert_null(parts[1].top_sprite_for(24), "down on -1, the Surface's hole isn't shown")
	_levels[1].level_fixtures.add(_ladder(1, 25))
	assert_null(parts[1].top_sprite_for(25), "-1 isn't 'below' any more: its changes draw no tops")


func test_the_hand_made_hole_on_minus_one_shows_the_ladder_top() -> void:
	_world = add_child_autofree(LevelGenerator.generate_world(0))
	LevelGenerator.generate_into(_world, 2)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(14, -1, 1), _world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	var view: View = View.new()
	add_child_autofree(view)
	view.follow(actor)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(view)
	var ladder: Fixture = _world.level_at(2).level_fixtures.of_kind(ObjectKind.OBJECT.LADDER)[0]
	var top: Sprite2D = renderer.top_sprite_for(ladder.id)
	assert_not_null(top, "from -1, the hole at (14, -2) shows its ladder")
	if top: assert_eq(top.position, Vector2(14, -2) * 16.0, "in the hole")
