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


func is_regex_match(data: String, pattern: String) -> bool:
	var result: bool = false
	
	# 1. Initialize the RegEx object
	var regex = RegEx.new()

	# 2. Compile your pattern (using r"..." creates a raw string literal to avoid extra escaping)
	regex.compile(pattern) 
	
	# 3. Search the string
	var regex_result = regex.search(data)
	
	# 4. Check if a match was found (returns null if no match)
	if regex_result:
		result = true
		print("Match found!")
		print("Full match: ", regex_result.get_string()) # Prints: player-9823
		print("Captured ID: ", regex_result.get_string(1)) # Prints: 9823
	else:
		print("No match.")
	
	return result







































