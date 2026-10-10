extends Node2D
class_name Actor

signal actor_worldpos_changed (actor: Actor, old_pos: WorldPos, new_pos: WorldPos)
signal action_begun(verb: String)
signal action_ended(verb: String)

var current_WorldPos: WorldPos
var actor_name: String = "Actor"
var move_intent: Vector2 = Vector2.ZERO
var action_intent: bool = false
var aim_vector: Vector2 = Vector2.ZERO
var current_level: Level
var facing: Vector2i = Vector2i(0,1) # Default = Down

@export var speed: float = 85.0
@export var feet_box: Rect2 = Rect2(-5, 1, 10, 6)

# TODO: Temporary equip. Refactor later.
var equipped: ToolData = preload("res://src/entity/tools/flint_pickaxe.tres")

const facing_frames: Dictionary = {
	"UP": 1,
	"DOWN": 19,
	"LEFT": 28,
	"RIGHT": 10,
}

# Which level the actor is on. Pixels can't say this, so it is
# stored, and current_WorldPos is computed from it and position.
# -1 is no level: an actor must be given its depth by setup().
var _depth: int = -1
var depth: int:
	get: return _depth
	set(value): set_depth(value)


static func create(scene: PackedScene, p_name: String, world_pos: WorldPos) -> Actor:
	var actor: Actor = scene.instantiate() as Actor
	return actor.setup(p_name, world_pos)


func _ready() -> void:
	assert(depth >= 0, "actor entered the tree without setup()")
	
	# setup() already did this. Recomputing covers position being
	# changed between setup() and add_child().
	current_WorldPos = get_current_WorldPos()


func move(p_move_intent: Vector2) -> void:
	# The _physics_process will move the actor until the intent is reset
	move_intent = p_move_intent


func _move(_motion: Vector2) -> void:
	var tiles: LevelTiles = current_level.level_tiles
	var moved: Rect2 = TileCollision.move_box(tiles, get_world_box(), _motion)
	
	# Adjust position to account for the position of the corner of the feet_box
	position += moved.position - get_world_box().position
	
	_update_WorldPos()


func stop() -> void:
	move_intent = Vector2.ZERO


func aim(p_aim: Vector2, p_move: Vector2) -> void:
	aim_vector = p_aim
	
	# Set facing based on aim
	var was_set: bool = _set_facing(p_aim)
	
	# If aim is in the deadzone, set facing from move
	# leave it the same if not moving
	if not was_set:
		was_set = _set_facing(p_move)


func primary_action(p_action_intent: bool) -> void:
	var prior_intent: bool = action_intent
	
	# The _physics_process will trigger the actor's action until the intent is reset
	action_intent = p_action_intent
	
	if prior_intent != action_intent:
		if action_intent: emit_signal("action_begun", equipped.verb)
		else: emit_signal("action_ended", equipped.verb)


func _primary_action(delta: float) -> void:
	if not action_intent: 
		return
	
	var verb: String = equipped.verb
	match verb:
		"dig": _dig(delta, _get_target_tile())


func _get_target_tile() -> WorldPos:
	var here: WorldPos = current_WorldPos
	return WorldPos.new(here.x + facing.x, here.y + facing.y, here.depth)


func _dig(delta: float, target_tile: WorldPos) -> void: 
	var capability: CapabilityDig = get_node_or_null("Capabilities/CapabilityDig")
	if capability: capability.dig(delta, equipped.speed, target_tile, current_level)


func _physics_process(delta: float) -> void:
	_move(move_intent * speed * delta)
	_primary_action(delta)


func setup(p_name: String, world_pos: WorldPos) -> Actor:
	var old_pos: WorldPos = current_WorldPos
	depth = world_pos.depth
	position = TileSpace.tile_center(Vector2i(world_pos.x, world_pos.y))
	current_WorldPos = get_current_WorldPos()
	actor_worldpos_changed.emit(self, old_pos, current_WorldPos)
	actor_name = p_name
	name = "Actor%s" % p_name
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
	current_level = World.get_level_by_depth(depth)
	assert(current_level != null, "Actor depth was change/set while current_level was NULL.")


func _set_facing(p_vector: Vector2) -> bool:
	if p_vector == Vector2.ZERO:
		return false  # no input here: let the next source decide
	facing = TileSpace.snap_facing(facing, p_vector)
	_update_facing_sprite()
	return true  # input present: it owns facing this tick


func _update_facing_sprite() -> void:
	# TODO: Replace later with walking animation
	var sprite: Sprite2D = $Sprite2D
	match facing:
		Vector2i(0,-1): sprite.frame = facing_frames["UP"]
		Vector2i(0,1): sprite.frame = facing_frames["DOWN"]
		Vector2i(-1,0): sprite.frame = facing_frames["LEFT"]
		Vector2i(1,0): sprite.frame = facing_frames["RIGHT"]

















