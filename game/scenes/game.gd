extends Node


func _ready() -> void:
	
	# Begin: debugging
	var player = preload("res://src/entity/player.tscn").instantiate()
	$GameViewport.add_child(player)
	
	var level_res = preload("res://src/world/level.tscn")
	var level = level_res.instantiate()
	level.setup(0, TilePrefabRegistry.get_prefab(&"surface_start"))
	$GameViewport.add_child(level)
	$GameViewport/LevelRenderer.show_level(level.level_tiles)
	# C-4 only: puts the level's centre in the middle of the view, so
	# the prefab's pocket is on screen. Placing the level properly
	# against world (0, 0) is CHECKLIST C's "whole level" step.
	$GameViewport/LevelRenderer.position = Vector2(256, 160)
	level = level_res.instantiate()
	level.setup(1)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(2)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(3)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(4)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(5)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(6)
	level.visible = false
	$GameViewport.add_child(level)
	level = level_res.instantiate()
	level.setup(7)
	level.visible = false
	$GameViewport.add_child(level)
	# End: debugging
	
	pass
