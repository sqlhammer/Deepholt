extends Node


func _ready() -> void:
	
	# Begin: debugging
	var level = preload("res://src/world/level.tscn").instantiate()
	self.add_child(level)
	var player = preload("res://src/entity/player.tscn").instantiate()
	self.add_child(player)
	# End: debugging
	
	pass
