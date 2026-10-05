extends Node

var actor_packed_scene: PackedScene = preload("res://src/entity/actor.tscn")
var level_packed_scene: PackedScene = preload("res://src/world/level.tscn")


signal debug_event (title: String, text: String, remove: bool)


func contains_whitespace(text: String) -> bool:
	var regex = RegEx.new()
	# \\s matches spaces, tabs, and newlines
	regex.compile("\\s") 
	
	var result = regex.search(text)
	return result != null





