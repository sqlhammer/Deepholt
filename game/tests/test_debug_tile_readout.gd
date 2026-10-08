extends GutTest

# The debug overlay's tile readout is the only window into tile data until
# something draws, so what it prints has to be trustworthy. The property under
# test: standing on a prefab's anchor prints back the grid that was authored
# into it, in the same characters.


var _overlay: CanvasLayer


func before_each() -> void:
	var level: Level = preload("res://src/world/level.tscn").instantiate()
	level.setup(0, TilePrefabRegistry.get_prefab(&"surface_start"))
	add_child_autofree(level)

	_overlay = preload("res://src/debug/debug_overlay.tscn").instantiate()
	add_child_autofree(_overlay)


func test_window_prints_back_the_authored_grid_around_the_anchor() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))
	
	assert_string_contains(readout, "###########", "five rows should contain this")
	assert_string_contains(readout, "####c######", "three rows north of the anchor")
	assert_string_contains(readout, "#####......", "one and two rows north of the anchor")
	assert_string_contains(readout, "####c@.....", "anchor row")
	assert_string_contains(readout, "#####cc####", "two rows south of anchor")


func test_readout_names_the_tile_under_the_actor() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))

	assert_string_contains(readout, "ground ROCK", "the anchor stands on rock ground")
	assert_string_contains(readout, "top OPEN", "the anchor itself is open space")
	assert_string_contains(readout, "ore NONE", "and carries no ore")


# The array index of world (0, 0) is the center element, (r * width + r).
# Surface has radius 90, so width 181 and center 16380.
func test_readout_reports_the_array_index_of_the_origin() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))

	assert_string_contains(readout, "origin (0, 0) index 16380", "the origin sits at the array's center")
	assert_string_contains(readout, "index 16380 of 32761", "and that is where the actor is standing")


# A level that was never given a prefab is solid default rock, and the readout
# should say so rather than failing to find anything to report.
func test_a_level_with_no_prefab_reads_as_solid_rock() -> void:
	var level: Level = preload("res://src/world/level.tscn").instantiate()
	level.setup(3)
	add_child_autofree(level)

	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 3))

	assert_string_contains(readout, "top MINABLE_ROCK", "an unauthored level is minable rock throughout")
	assert_string_contains(readout, "depth 3 [-3]", "and it knows what depth it is calling that")


func test_a_depth_with_no_resident_level_says_so() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 5))

	assert_string_contains(readout, "no level resident at depth 5",
		"a depth nothing is loaded for is reported, not guessed at")


# The overlay polls the actors it watches rather than waiting for
# them to move, so a fresh actor shows up without taking a step.
func test_a_watched_actor_shows_before_it_moves() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, 0))
	autofree(actor)
	_overlay.visible = true
	_overlay.watch(actor)
	assert_true(_overlay.debug_text.has("Player: TestPlayer"),
		"watching an actor adds its section straight away")


func test_a_hidden_overlay_does_not_build_readouts() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, 0))
	autofree(actor)
	_overlay.visible = false
	_overlay.watch(actor)
	assert_false(_overlay.debug_text.has("Player: TestPlayer"),
		"nothing is read while F3 is off")


func test_a_freed_actor_loses_its_section() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, 0))
	_overlay.visible = true
	_overlay.watch(actor)
	assert_true(_overlay.debug_text.has("Player: TestPlayer"),
		"the section exists before the actor is freed")
	actor.free()
	_overlay._refresh_watched_actors()
	assert_false(_overlay.debug_text.has("Player: TestPlayer"),
		"a freed actor's readout is removed, not left stale")
	assert_eq(_overlay.watched_actors.size(), 0,
		"and it is no longer watched")


# --- showing and hiding ---

func test_toggling_flips_visibility() -> void:
	_overlay.visible = false
	_overlay.toggle_debug_overlay()
	assert_true(_overlay.visible, "off becomes on")
	_overlay.toggle_debug_overlay()
	assert_false(_overlay.visible, "on becomes off")


func test_toggling_on_shows_a_watched_actor_straight_away() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, 0))
	autofree(actor)
	_overlay.visible = false
	_overlay.watch(actor)
	_overlay.toggle_debug_overlay()
	assert_true(_overlay.debug_text.has("Player: TestPlayer"),
		"turning F3 on fills the readout without waiting for the timer")


func test_the_toggle_action_toggles_the_overlay() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"toggle_debug"
	press.pressed = true
	_overlay.visible = false
	_overlay._input(press)
	assert_true(_overlay.visible, "pressing toggle_debug shows it")


func test_other_input_leaves_the_overlay_alone() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"primary_action"
	press.pressed = true
	_overlay.visible = false
	_overlay._input(press)
	assert_false(_overlay.visible, "other actions don't toggle it")


# --- sections ---

func test_a_section_shows_in_the_label() -> void:
	_overlay.set_section("Weather", "dry")
	var label: RichTextLabel = _overlay.get_node("DebugRichTextLabel")
	assert_string_contains(label.text, "[b]Weather[/b]: dry",
		"a section is drawn as a bold title and its text")


func test_a_section_can_be_removed_through_set_section() -> void:
	_overlay.set_section("Weather", "dry")
	_overlay.set_section("Weather", "", true)
	assert_false(_overlay.debug_text.has("Weather"), "remove = true drops it")
	var label: RichTextLabel = _overlay.get_node("DebugRichTextLabel")
	assert_false(label.text.contains("Weather"), "and it leaves the label")


func test_sections_are_grouped_seeds_first_then_players_then_the_rest() -> void:
	_overlay.set_section("Weather", "dry")
	_overlay.set_section("Player: TestPlayer", "here")
	_overlay.set_section("Level Seed", "42")
	var order: Array = _overlay.debug_text.keys()
	assert_lt(order.find("Level Seed"), order.find("Player: TestPlayer"),
		"seeds (group 0) before players (group 10)")
	assert_lt(order.find("Player: TestPlayer"), order.find("Weather"),
		"players before anything ungrouped (group 99)")


func test_an_unknown_title_falls_in_the_last_group() -> void:
	assert_eq(_overlay._get_group("Weather"), 99, "unrecognised titles sort last")


# --- fallbacks for kinds the readout doesn't know ---

const UNKNOWN_KIND: int = 200


func test_an_unknown_top_kind_draws_as_a_question_mark() -> void:
	var tiles: LevelTiles = _overlay._find_level_tiles(0)
	tiles.set_top(3, 3, UNKNOWN_KIND)
	assert_eq(_overlay._tile_char(tiles, 3, 3, WorldPos.new(0, 0, 0)), "?",
		"a kind with no character shows as ?")


func test_an_unknown_kind_is_named_with_its_id() -> void:
	assert_eq(_overlay._kind_name(TileKind.TOP, UNKNOWN_KIND), "UNKNOWN (200)",
		"a kind missing from the table is named by its number")
