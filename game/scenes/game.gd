extends Node


func _ready() -> void:
	
	# Begin: debugging
	var player = preload("res://src/entity/player.tscn").instantiate()
	self.add_child(player)
	
	var level_res = preload("res://src/world/level.tscn")
	var level = level_res.instantiate()
	level.setup(0)
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(1)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(2)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(3)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(4)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(5)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(6)
	level.visible = false
	self.add_child(level)
	level = level_res.instantiate()
	level.setup(7)
	level.visible = false
	self.add_child(level)
	# End: debugging
	
	pass
