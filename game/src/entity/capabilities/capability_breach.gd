extends Node
class_name CapabilityBreach

# Breaching a floor into a hole (D-151, D-152, D-153): held while
# facing an open floor tile, the floor gives way when progress, at the
# tool's power per second, reaches the breach's work. The world's
# tile gatekeeper makes the change; this only does the work and asks.

const verb: String = "breach"

var progress: float = 0.0
var work: float = 0.0
var current_tile: WorldPos
var actor: Actor
# The tile a refusal was already asked about, so an under-tier tool
# hears "too weak" once, not every tick.
var _refused_tile: WorldPos


# The gatekeeper is the actor's world, reached through its level
# (D-126). An actor never changes world, so it is listened to once.
func _ready() -> void:
	var world: World = actor.current_level.world
	world.tile_breached.connect(_on_tile_breached)
	world.breach_refused.connect(_on_breach_refused)


# One tick of breaching `target` with `tool`. Only a pick breaches
# (D-174): anything else is refused at once, like a weak tool.
func breach(delta: float, tool: ToolData, target: WorldPos, level: Level) -> void:
	var tool_power: float = tool.power
	if current_tile == null or not current_tile.equals(target):
		reset()
		current_tile = target
	var world: World = level.world
	# Asked before any work: a floor this tool can't break, or a tile
	# that isn't floor, is refused at once, not after five seconds
	if world.breach_problem(target, tool_power, actor) != World.BREACH_REFUSAL.NONE:
		progress = 0.0
		if _refused_tile == null or not _refused_tile.equals(target):
			_refused_tile = target
			world.breach_requested.emit(actor, target, tool_power)
		return
	work = Digging.breach_work(world.tuning, Digging.floor_hardness(world.tuning, target.depth))
	progress += tool_power * delta
	if progress >= work:
		world.breach_requested.emit(actor, target, tool_power)


# Released, or a new target: the work done so far is lost, as a dig's
# is (D-072).
func reset() -> void:
	progress = 0.0
	work = 0.0
	current_tile = null
	_refused_tile = null


func _on_tile_breached(p_actor: Actor, _tile: WorldPos) -> void:
	if p_actor == actor: reset()


func _on_breach_refused(p_actor: Actor, _tile: WorldPos, _reason: World.BREACH_REFUSAL) -> void:
	if p_actor == actor: progress = 0.0
