extends GutTest

# FixtureRenderer -- a sprite per fixture on the shown level (D-100),
# following the View (D-094). The world spawn is drawn by nothing
# (D-091); a kind with no art is an error, not a silent gap.

const SPOT: Vector2i = Vector2i(2, -3)

var _levels: Array[Level] = []


func before_each() -> void:
	_levels.clear()
	for depth in [0, 1]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)
		level.level_tiles.set_top(SPOT.x, SPOT.y, TileKind.TOP.OPEN)
		_levels.append(level)


func _renderer() -> FixtureRenderer:
	var renderer: FixtureRenderer = FixtureRenderer.new()
	add_child_autofree(renderer)
	return renderer


func _ladder(depth: int, id: int, tile: Vector2i = SPOT) -> Fixture:
	return Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(tile.x, tile.y, depth), id)


func _following_actor_at(depth: int) -> Array:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(SPOT.x, SPOT.y, depth))
	add_child_autofree(actor)
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
	pair[0].change_depth(WorldPos.new(SPOT.x, SPOT.y, 1))
	assert_not_null(renderer.sprite_for(5), "drawn once -1 is shown")


func test_changes_on_a_level_no_longer_shown_are_ignored() -> void:
	var pair: Array = _following_actor_at(0)
	var renderer: FixtureRenderer = _renderer()
	renderer.watch(pair[1])
	pair[0].change_depth(WorldPos.new(SPOT.x, SPOT.y, 1))
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
	add_child_autofree(game)
	var viewport: Node = game.get_node("GameViewport")
	assert_lt(viewport.get_node("FixtureRenderer").get_index(), viewport.get_node("Actors").get_index(),
		"fixtures draw before actors, so actors stand over a ladder")
