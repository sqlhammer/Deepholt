extends CharacterBody2D
class_name Actor

signal actor_worldpos_changed (actor: Actor, old_pos: WorldPos, new_pos: WorldPos)

var current_WorldPos: WorldPos
var actor_name: String = "Actor"
var move_intent: Vector2 = Vector2.ZERO
@export var speed: float = 85.0

# Which level the actor is on. Pixels can't say this, so it is
# stored, and current_WorldPos is computed from it and position.
# -1 is no level: an actor must be given its depth by setup().
var depth: int = -1


func _ready() -> void:
	assert(depth >= 0, "actor entered the tree without setup()")
	# setup() already did this. Recomputing covers position being
	# changed between setup() and add_child().
	current_WorldPos = get_current_WorldPos()


func _physics_process(delta: float) -> void:
	self.move_and_collide(move_intent * speed * delta)
	_update_WorldPos()


static func create(scene: PackedScene, world_pos: WorldPos) -> Actor:
	var actor: Actor = scene.instantiate() as Actor
	return actor.setup(world_pos)


func setup(world_pos: WorldPos) -> Actor:
	var old_pos: WorldPos = current_WorldPos
	depth = world_pos.depth
	position = TileSpace.tile_center(Vector2i(world_pos.x, world_pos.y))
	current_WorldPos = get_current_WorldPos()
	actor_worldpos_changed.emit(self, old_pos, current_WorldPos)
	return self


func get_current_WorldPos() -> WorldPos:
	# position is relative to the parent. This is only correct if the player's 
	# parent is the level node, so that the level's origin is the player's origin. 
	# If it isn't, use level_node.to_local(global_position) instead of position.
	var tile: Vector2i = Vector2i((position / TileSpace.TILE_PIXELS).floor())
	return WorldPos.new(tile.x, tile.y, depth)


func _update_WorldPos() -> void:
	var new_pos: WorldPos = get_current_WorldPos()
	var old_pos: WorldPos = current_WorldPos
	
	if old_pos == null: return
	
	if not old_pos.equals(new_pos):
		current_WorldPos = new_pos
		actor_worldpos_changed.emit(self, old_pos, new_pos)


func move() -> void:
	
	pass














