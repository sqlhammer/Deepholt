extends Node2D
class_name Player

signal player_worldpos_changed (old_pos: WorldPos, new_pos: WorldPos)

var current_WorldPos: WorldPos
var player_name: String = "Player 1"


func _ready() -> void:
	current_WorldPos = WorldPos.new(5,2,0) #debugging


func _physics_process(_delta: float) -> void:
	_update_WorldPos()


func get_current_WorldPos() -> WorldPos:
	# this func is stubbed
	return WorldPos.new(0,1,0) 


func _update_WorldPos() -> void:
	var new_pos: WorldPos = get_current_WorldPos()
	var old_pos: WorldPos = current_WorldPos
	
	if old_pos == null: return
	
	if not old_pos.equals(new_pos):
		emit_signal("player_worldpos_changed",[old_pos,new_pos])
		current_WorldPos = new_pos

