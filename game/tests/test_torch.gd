extends GutTest

# The torch (D-221, D-228): a light item in the light slot beside the
# hotbar, lit and put out with L or D-pad up. It burns about four
# minutes, only while lit; one burnt out is used up and the next
# lights. Lit, it is one more source in the light flood, moving with
# its carrier, so ore around shows its kind; put away, it's grey
# again. Dropped while lit, it burns on the ground until it's gone.

const Worlds = preload("res://tests/worlds.gd")

var _world: World
var _actor: Actor
var _tuning: TuningProfile


# A corridor along y = 0 on -1, the player at its west end, with copper
# in the wall at (3, 1).
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	_tuning = _world.tuning
	var tiles: LevelTiles = _world.level_at(1).level_tiles
	for x in range(0, 16):
		tiles.set_top(x, 0, TileKind.TOP.OPEN)
	tiles.set_ore(3, 1, TileKind.ORE.COPPER)
	_actor = Actor.create(Global.actor_packed_scene, "Carrier", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)


func _burn(seconds: float, step: float = 1.0) -> void:
	for i in roundi(seconds / step):
		_actor._physics_process(step)


# --- the item and its slot ---

func test_a_torch_is_a_light_item() -> void:
	var torch: Item = ItemRegistry.get_item(&"torch")
	assert_true(Hotbar.LIGHT_TAG in torch.tags, "tagged as a light")
	assert_not_null(torch.icon, "with an icon")


func test_the_light_slot_takes_a_torch_and_empties_without_one() -> void:
	assert_eq(_actor.hotbar.light, &"", "empty to begin")
	_actor.pack.add(&"torch", 2)
	assert_eq(_actor.hotbar.light, &"torch", "the slot takes it")
	_actor.pack.remove(&"torch", 2)
	assert_eq(_actor.hotbar.light, &"", "and lets it go")


# --- lighting and burning ---

func test_lighting_starts_a_full_burn_and_putting_out_keeps_it() -> void:
	_actor.pack.add(&"torch", 1)
	assert_true(_actor.toggle_light(), "lit")
	assert_eq(_actor.hotbar.light_left, _tuning.torch_burn_seconds, "a full burn")
	_burn(10.0)
	assert_false(_actor.toggle_light(), "put out")
	_burn(30.0)
	assert_almost_eq(_actor.hotbar.light_left, _tuning.torch_burn_seconds - 10.0, 0.01,
		"it burns only while lit")


func test_nothing_to_light_lights_nothing() -> void:
	assert_false(_actor.toggle_light(), "no torch, no light")


func test_a_burnt_out_torch_is_used_up_and_the_next_lights() -> void:
	_actor.pack.add(&"torch", 2)
	_actor.toggle_light()
	_burn(_tuning.torch_burn_seconds)
	assert_eq(_actor.pack.count_of(&"torch"), 1, "one used up")
	assert_true(_actor.hotbar.lit, "the next is lit")
	assert_almost_eq(_actor.hotbar.light_left, _tuning.torch_burn_seconds, 1.0, "with a full burn")
	_burn(_tuning.torch_burn_seconds)
	assert_eq(_actor.pack.count_of(&"torch"), 0, "the last used up")
	assert_false(_actor.hotbar.lit, "and it's dark")
	assert_eq(_actor.hotbar.light, &"", "the slot empty")


# --- the light it gives ---

func test_a_lit_torch_lights_around_its_carrier() -> void:
	_actor.pack.add(&"torch", 1)
	var level: Level = _world.level_at(1)
	assert_eq(Light.carried_lit_tiles(level, _world.players(), _tuning), [] as Array[Vector2i],
		"unlit, nothing")
	_actor.toggle_light()
	var lit: Array[Vector2i] = Light.carried_lit_tiles(level, _world.players(), _tuning)
	assert_true(lit.has(Vector2i(3, 1)), "the copper face is lit")
	assert_false(lit.has(Vector2i(_tuning.torch_light_radius + 2, 0)), "not past its reach")


func test_the_light_moves_with_its_carrier() -> void:
	_actor.pack.add(&"torch", 1)
	_actor.toggle_light()
	_actor.move_to(WorldPos.new(12, 0, 1), &"test")
	var lit: Array[Vector2i] = Light.carried_lit_tiles(_world.level_at(1), _world.players(), _tuning)
	assert_false(lit.has(Vector2i(3, 1)), "the copper behind is dark again")
	assert_true(lit.has(Vector2i(12, 0)), "and the carrier's tile is lit")


# Trap 5: one small flood per carried light, never the level.
func test_the_flood_stays_within_the_lights_radius() -> void:
	_actor.pack.add(&"torch", 1)
	_actor.toggle_light()
	var reach: int = 2 * _tuning.torch_light_radius + 3
	var lit: Array[Vector2i] = Light.carried_lit_tiles(_world.level_at(1), _world.players(), _tuning)
	assert_lt(lit.size(), reach * reach, "a handful of tiles")


func _followed_screen() -> Visibility:
	var view: View = add_child_autofree(View.new())
	var visibility: Visibility = add_child_autofree(Visibility.new())
	visibility.watch(view)
	view.follow(_actor)
	return visibility


func test_ore_shows_its_kind_while_the_torch_is_lit_and_greys_when_put_away() -> void:
	_actor.pack.add(&"torch", 1)
	var screen: Visibility = _followed_screen()
	assert_eq(screen.state_at(3, 1), Visibility.STATE.SENSED, "sensed: a grey lump")
	_actor.toggle_light()
	assert_eq(screen.state_at(3, 1), Visibility.STATE.LIT, "lit: copper")
	_actor.toggle_light()
	assert_eq(screen.state_at(3, 1), Visibility.STATE.SENSED, "put away: grey again")


# --- dropped lit, a breadcrumb ---

func _torches_on(depth: int) -> Array[Fixture]:
	return _world.level_at(depth).level_fixtures.of_kind(ObjectKind.OBJECT.TORCH)


func test_a_torch_dropped_lit_burns_on_the_ground() -> void:
	_actor.pack.add(&"torch", 3)
	_actor.toggle_light()
	_burn(40.0)
	_world.drop_requested.emit(_actor, &"torch", 1)
	var dropped: Array[Fixture] = _torches_on(1)
	assert_eq(dropped.size(), 1, "one burning torch on the ground")
	assert_almost_eq(dropped[0].time_left, _tuning.torch_burn_seconds - 40.0, 0.01,
		"with what it had left")
	assert_eq(_actor.pack.count_of(&"torch"), 2, "out of the pack")
	assert_true(_actor.hotbar.lit, "the next is lit in hand")
	assert_eq(_actor.hotbar.light_left, _tuning.torch_burn_seconds, "fresh")
	assert_eq(Light.radius_of(ObjectKind.OBJECT.TORCH, _tuning), _tuning.torch_light_radius,
		"it lights like one carried")


func test_a_torch_on_the_ground_burns_out_and_is_gone() -> void:
	_actor.pack.add(&"torch", 1)
	_actor.toggle_light()
	_world.drop_requested.emit(_actor, &"torch", 1)
	assert_false(_actor.hotbar.lit, "the last one dropped: dark in hand")
	_world.advance_time(_tuning.torch_burn_seconds - 1.0)
	assert_eq(_torches_on(1).size(), 1, "still burning")
	_world.advance_time(1.0)
	assert_eq(_torches_on(1).size(), 0, "burnt out")


func test_unlit_torches_drop_as_items() -> void:
	_actor.pack.add(&"torch", 2)
	_world.drop_requested.emit(_actor, &"torch", 2)
	assert_eq(_torches_on(1).size(), 0, "nothing burning")
	assert_eq(_world.level_at(1).level_drops.at(Vector2i.ZERO), {&"torch": 2}, "two torches")


# --- saving ---

func test_the_light_slot_and_its_burn_are_saved() -> void:
	_actor.pack.add(&"torch", 2)
	_actor.toggle_light()
	_burn(15.0)
	var back: Hotbar = Hotbar.from_save(_actor.hotbar.to_save())
	assert_eq(back.light, &"torch", "the slot")
	assert_true(back.lit, "lit")
	assert_almost_eq(back.light_left, _tuning.torch_burn_seconds - 15.0, 0.01, "the burn left")


func test_a_burning_torch_on_the_ground_is_saved() -> void:
	_actor.pack.add(&"torch", 1)
	_actor.toggle_light()
	_world.drop_requested.emit(_actor, &"torch", 1)
	var saved: Array = SaveGame._serialize_fixtures(_world.level_at(1).level_fixtures)
	var back: Fixture = SaveGame._deserialize_fixtures(1, saved).of_kind(ObjectKind.OBJECT.TORCH)[0]
	assert_almost_eq(back.time_left, _tuning.torch_burn_seconds, 0.01, "with its time")


# --- on screen ---

func test_the_hotbar_shows_the_light_slot() -> void:
	var view: View = add_child_autofree(View.new())
	var hud: HotbarHud = add_child_autofree(HotbarHud.new())
	hud.watch(view)
	view.follow(_actor)
	assert_eq(hud.light_text(), "", "empty")
	_actor.pack.add(&"torch", 3)
	assert_eq(hud.light_text(), "3", "three, unlit")
	_actor.toggle_light()
	assert_eq(hud.light_text(), "3 lit %ds" % ceili(_tuning.torch_burn_seconds), "lit, and its burn")
	assert_true(FixtureRenderer.TEXTURES.has(ObjectKind.OBJECT.TORCH), "a dropped one is drawn")
