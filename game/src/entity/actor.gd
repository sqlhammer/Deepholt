extends Node2D
class_name Actor

signal actor_worldpos_changed (actor: Actor, old_pos: WorldPos, new_pos: WorldPos)
signal action_begun(verb: String)
signal action_ended(verb: String)
signal move_intent_changed(move_intent: Vector2)

var current_WorldPos: WorldPos
var actor_name: String = "Actor"
var move_intent: Vector2 = Vector2.ZERO
var action_intent: bool = false
var aim_vector: Vector2 = Vector2.ZERO
var current_level: Level
var facing: Vector2i = Vector2i(0,1) # Default = Down

@onready var animation_player: AnimationPlayer = $AnimationPlayer

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

enum DIRECTION {
	NONE,
	UP,
	DOWN,
	LEFT,
	RIGHT,
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
	
	move_intent_changed.connect(_on_move_intent_changed)


func move(p_move_intent: Vector2) -> void:
	# The _physics_process will move the actor until the intent is reset
	var old_intent: Vector2 = move_intent
	move_intent = p_move_intent
	if old_intent != move_intent:
		move_intent_changed.emit(move_intent)


func _move(_motion: Vector2) -> void:
	var tiles: LevelTiles = current_level.level_tiles
	var moved: Rect2 = TileCollision.move_box(tiles, get_world_box(), _motion)
	
	# Adjust position to account for the position of the corner of the feet_box
	var actual_motion: Vector2 = moved.position - get_world_box().position
	position += actual_motion
	
	var tile_before: WorldPos = current_WorldPos
	_update_WorldPos()
	if tile_before != null and not current_WorldPos.equals(tile_before):
		_take_ramp(actual_motion)


# Stepping onto a ramp in its trigger direction changes depth (D-095,
# D-097). The ramp decides where to go from how far the actor really
# moved (D-098); the actor makes the move (D-093).
func _take_ramp(actual_motion: Vector2) -> void:
	var target: WorldPos = Ramp.target_for(current_level.level_tiles, current_WorldPos, actual_motion)
	if target != null:
		change_depth(target)


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


# The interact button (D-101). Today it only uses ladders: the Ladder
# rule says where, and the actor moves itself (D-093). Returns whether
# anything happened.
func interact() -> bool:
	var target: WorldPos = Ladder.target_for(current_WorldPos, facing)
	if target == null: return false
	return change_depth(target)


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


# A depth change is announced like any other change of tile (D-093):
# through actor_worldpos_changed, whose WorldPos carries the depth.
# Before the actor has a first position (during setup) there is no
# old tile, so nothing is announced.
func set_depth(p_depth: int) -> void:
	_depth = p_depth
	current_level = World.get_level_by_depth(depth)
	assert(current_level != null, "Actor depth was change/set while current_level was NULL.")
	_update_WorldPos()


# Moves the actor onto a tile on another level (D-093). Whatever sends
# the actor (a ramp, a ladder) decides the target; the actor only
# checks it can stand there, with the same test walking uses. Position
# is set before depth so the change is announced once, with the final
# tile. Returns false, changing nothing, if there is no level there or
# the landing is blocked.
func change_depth(target: WorldPos) -> bool:
	var level: Level = World.get_level_by_depth(target.depth)
	if level == null: return false

	var landing: Variant = _landing_on(level.level_tiles, target)
	if landing == null: return false

	position = landing
	set_depth(target.depth)
	return true


# Where the actor stands on arriving at `target`, or null if it can't.
# Onto the same (x, y) it keeps its exact spot if its feet fit there.
# Onto a ramp it always stands at the tile's center, so its feet never
# straddle one of the ramp's closed sides (D-099). Otherwise it stands
# at the tile's center, which only needs that one tile open.
func _landing_on(tiles: LevelTiles, target: WorldPos) -> Variant:
	var same_tile: bool = current_WorldPos != null \
		and target.x == current_WorldPos.x and target.y == current_WorldPos.y
	var onto_ramp: bool = TileKind.is_ramp(tiles.get_ground(target.x, target.y))
	var here_box: Rect2 = Rect2(position + feet_box.position, feet_box.size)
	if same_tile and not onto_ramp and TileCollision.fits(tiles, here_box):
		return position
	var center: Vector2 = TileSpace.tile_center(Vector2i(target.x, target.y))
	if TileCollision.fits(tiles, Rect2(center + feet_box.position, feet_box.size)):
		return center
	return null


func _set_facing(p_vector: Vector2) -> bool:
	if p_vector == Vector2.ZERO:
		return false  # no input here: let the next source decide
	facing = TileSpace.snap_facing(facing, p_vector)
	
	# if walking, don't update the sprite, the animation player is doing that
	if move_intent.is_zero_approx():
		_update_facing_sprite()
	
	return true  # input present: it owns facing this tick


func _update_facing_sprite() -> void:
	var sprite: Sprite2D = $Sprite2D
	match facing:
		Vector2i(0,-1): sprite.frame = facing_frames["UP"]
		Vector2i(0,1): sprite.frame = facing_frames["DOWN"]
		Vector2i(-1,0): sprite.frame = facing_frames["LEFT"]
		Vector2i(1,0): sprite.frame = facing_frames["RIGHT"]


func _walk(dir: DIRECTION) -> void:
	match dir:
		DIRECTION.UP: animation_player.play("WALK_UP")
		DIRECTION.DOWN: animation_player.play("WALK_DOWN")
		DIRECTION.LEFT: animation_player.play("WALK_LEFT")
		DIRECTION.RIGHT: animation_player.play("WALK_RIGHT")


func _on_move_intent_changed(p_move_intent: Vector2) -> void:
	if p_move_intent == Vector2.ZERO: 
		animation_player.play("RESET")
		return
	
	match p_move_intent:
		Vector2(0,-1): _walk(DIRECTION.UP)
		Vector2(0,1): _walk(DIRECTION.DOWN)
		Vector2(-1,0): _walk(DIRECTION.LEFT)
		Vector2(1,0): _walk(DIRECTION.RIGHT)











