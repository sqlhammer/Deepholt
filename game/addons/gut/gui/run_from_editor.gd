# ------------------------------------------------------------------------------
# This is the entry point when running tests from the editor.
#
# This script should conform to, or ignore, the strictest warning settings.
# ------------------------------------------------------------------------------
extends Node2D

var GutLoader : Object

func _init() -> void:
	GutLoader = load("res://addons/gut/gut_loader.gd")


@warning_ignore("unsafe_method_access")
func _ready() -> void:
	_post_ready.call_deferred()


func _post_ready():
	# Molepeople: the real project pins content scaling to a 512x320 viewport
	# stretched 2.5x for the Steam Deck target. GUT's panels assume normal
	# desktop scale, so left alone they render blown up and clipped when this
	# scene runs as the test-execution window. This override is scoped to
	# this scene only -- the game's actual scenes never hit this code path.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1280, 800)

	var runner : Node = load("res://addons/gut/gui/GutRunner.tscn").instantiate()
	get_tree().root.add_child(runner)
	runner.run_from_editor()
