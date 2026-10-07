extends Node

var actor_packed_scene: PackedScene = preload("res://src/entity/actor.tscn")
var level_packed_scene: PackedScene = preload("res://src/world/level.tscn")

# Small number that is less than a pixel but larger than a float rounding error
# Used in coordinate math to ensure that exclusive edges will round down with floor()
const epsilon: float = 0.001

signal debug_event (title: String, text: String, remove: bool)

enum CAPABILITY {
	NONE,
	DIG
}

func get_capability_packedscene(capability: CAPABILITY) -> PackedScene:
	var scene: PackedScene
	match capability:
		CAPABILITY.DIG: scene = load("res://src/entity/capabilities/capability_dig.tscn")
	return scene

func contains_whitespace(text: String) -> bool:
	var regex = RegEx.new()
	# \\s matches spaces, tabs, and newlines
	regex.compile("\\s") 
	
	var result = regex.search(text)
	return result != null





