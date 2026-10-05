extends Node2D
class_name Actor

signal actor_worldpos_changed (actor: Actor, old_pos: WorldPos, new_pos: WorldPos)

var current_WorldPos: WorldPos
var actor_name: String = "Actor"
var move_intent: Vector2 = Vector2.ZERO
var current_level: Level
@export var speed: float = 85.0
@export var feet_box: Rect2 = Rect2(-5, 1, 10, 6)

# Which level the actor is on. Pixels can't say this, so it is
# stored, and current_WorldPos is computed from it and position.
# -1 is no level: an actor must be given its depth by setup().
var _depth: int = -1
var depth: int:
	get: return _depth
	set(value): set_depth(value)

func _ready() -> void:
	assert(depth >= 0, "actor entered the tree without setup()")
	# setup() already did this. Recomputing covers position being
	# changed between setup() and add_child().
	current_WorldPos = get_current_WorldPos()
	current_level = World.get_level(depth)


func move(_move_intent: Vector2) -> void:
	# The _physics_process will move the actor until the intent is reset
	move_intent = _move_intent


func stop() -> void:
	move_intent = Vector2.ZERO


func _physics_process(delta: float) -> void:
	var tiles: LevelTiles = current_level.level_tiles
	var motion = move_intent * speed * delta
	var moved: Rect2 = TileCollision.move_box(tiles, get_world_box(), motion)
	
	# Adjust position to account for the position of the corner of the feet_box
	position += moved.position - get_world_box().position
	
	_update_WorldPos()


static func create(scene: PackedScene, p_name: String, world_pos: WorldPos) -> Actor:
	var actor: Actor = scene.instantiate() as Actor
	return actor.setup(p_name, world_pos)


func setup(p_name: String, world_pos: WorldPos) -> Actor:
	var old_pos: WorldPos = current_WorldPos
	depth = world_pos.depth
	position = TileSpace.tile_center(Vector2i(world_pos.x, world_pos.y))
	current_WorldPos = get_current_WorldPos()
	actor_worldpos_changed.emit(self, old_pos, current_WorldPos)
	actor_name = p_name
	name = "Player%s" % p_name
	return self


func get_current_WorldPos() -> WorldPos:
	var g_pos = get_world_box().get_center()
	return World.get_worldpos_from_global_position(g_pos, current_level)


func _update_WorldPos() -> void:
	var new_pos: WorldPos = get_current_WorldPos()
	var old_pos: WorldPos = current_WorldPos
	
	if old_pos == null: return
	
	if not old_pos.equals(new_pos):
		current_WorldPos = new_pos
		actor_worldpos_changed.emit(self, old_pos, new_pos)


func get_world_box() -> Rect2:
	return Rect2(position + feet_box.position, feet_box.size)


# Make feet_box visible while debugging
func _draw() -> void:
	#if OS.is_debug_build():
		#draw_rect(feet_box, Color(1, 0, 1, 0.6), false)
	pass


func set_depth(p_depth: int) -> void:
	_depth = p_depth
	current_level = World.get_level(depth)
	assert(current_level != null, "Actor depth was change/set while current_level was NULL.")








