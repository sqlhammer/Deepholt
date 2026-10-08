extends GutTest

# Global (autoload): small shared helpers and the capability scene
# lookup.


func test_text_with_whitespace_is_detected() -> void:
	assert_true(Global.contains_whitespace("two words"), "a space")
	assert_true(Global.contains_whitespace("tab\there"), "a tab")
	assert_true(Global.contains_whitespace("line\nbreak"), "a newline")


func test_text_without_whitespace_is_not() -> void:
	assert_false(Global.contains_whitespace("surface_start"), "no whitespace")
	assert_false(Global.contains_whitespace(""), "empty text has none")


func test_the_dig_capability_scene_is_found() -> void:
	var scene: PackedScene = Global.get_capability_packedscene(Global.CAPABILITY.DIG)
	assert_not_null(scene, "DIG has a scene")
	if scene:
		var node: Node = scene.instantiate()
		autofree(node)
		assert_true(node is CapabilityDig, "and it is the dig capability")


func test_no_capability_has_no_scene() -> void:
	assert_null(Global.get_capability_packedscene(Global.CAPABILITY.NONE),
		"NONE has no scene")
