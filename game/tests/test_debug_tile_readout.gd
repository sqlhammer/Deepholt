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


# surface_start's top grid is '#..' / '#0.' / '###' around its anchor, with
# copper in the two '#' tiles of the left column. Read from the anchor, those
# nine tiles should appear in the middle of a field of default minable rock.
func test_window_prints_back_the_authored_grid_around_the_anchor() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))

	assert_string_contains(readout, "####c..####", "the row north of the anchor")
	assert_string_contains(readout, "####c@.####", "the anchor's own row, with the actor on it")
	assert_string_contains(readout, "###########", "the row south of the anchor is all rock")


func test_readout_names_the_tile_under_the_actor() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))

	assert_string_contains(readout, "ground ROCK", "the anchor stands on rock ground")
	assert_string_contains(readout, "top OPEN", "the anchor itself is open space")
	assert_string_contains(readout, "ore NONE", "and carries no ore")


# The array index of world (0, 0) is the centre element, (r * width + r).
# Surface has radius 90, so width 181 and centre 16380.
func test_readout_reports_the_array_index_of_the_origin() -> void:
	var readout: String = _overlay._tile_readout(WorldPos.new(0, 0, 0))

	assert_string_contains(readout, "origin (0, 0) index 16380", "the origin sits at the array's centre")
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
