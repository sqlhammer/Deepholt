extends Node
class_name InputHandler

var actor: Actor
var mouse_world_position: Callable
var current_device_scheme: DEVICE_SCHEME = DEVICE_SCHEME.GAMEPAD
# While a level change fades, the actor is stopped and input isn't
# read (D-142). Keys still held when it ends are read again then.
var paused: bool = false
# Build mode's cursor (D-154). While it's active, the mouse or the
# right stick moves the cursor instead of aiming, and primary places.
var build: BuildCursor
# The inventory overlay (D-162). While it's open, walking still works,
# and drop one / drop the stack act on it; nothing digs, breaches,
# builds or interacts (slice 009 trap 6).
var inventory: InventoryOverlay
# The support overlay (D-163): toggled with its key, whatever else is
# open.
var support_overlay: SupportOverlay
# The hotbar on screen (D-170): a click on a slot selects it, and a
# click there never also digs or places.
var hotbar_hud: HotbarHud

# The game-wide keys. The handler only asks; the game decides what a
# save or a load is (R-P10).
signal quick_save_requested
signal load_requested
signal save_and_quit_requested

# Inside this distance from the feet the mouse's direction is
# mostly noise, so it counts as no aim and facing holds.
const MOUSE_DEAD_ZONE_PX: float = TileSpace.TILE_PIXELS / 2.0


enum DEVICE_SCHEME {
	NONE,
	GAMEPAD,
	MOUSE_AND_KEYBOARD,
}

func setup(p_actor: Actor, p_mouse_world_position: Callable) -> void:
	actor = p_actor
	name = "InputHandler%s" % p_actor.actor_name
	mouse_world_position = p_mouse_world_position


# The view's fade started: stop the actor, so it neither walks nor
# digs on a level the player can't see yet.
func pause() -> void:
	paused = true
	if actor == null: return
	actor.move(Vector2.ZERO)
	actor.primary_action(false)
	actor.breach(false)


func resume() -> void:
	paused = false


func _input(event: InputEvent) -> void:
	_update_device_scheme(event)
	
	if event.is_action_pressed("quick_save"):
		quick_save_requested.emit()
	if event.is_action_pressed("load"):
		load_requested.emit()
	if event.is_action_pressed("save_and_quit_to_desktop"):
		save_and_quit_requested.emit()
	_hotbar_input(event)


# The hotbar's keys (D-170): 1-8 pick a slot, the bumpers and the wheel
# step along. Read as events, not polled on the physics tick: a wheel
# notch presses and releases within one frame, which polling can miss.
func _hotbar_input(event: InputEvent) -> void:
	if actor == null or paused: return
	for i in range(Hotbar.SLOTS):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)
			return
	if event.is_action_pressed("hotbar_prev"): step_slot(-1)
	elif event.is_action_pressed("hotbar_next"): step_slot(1)


# A slot chosen by its key or a click. With the inventory open it's
# where the focused entry goes (D-172, slice 011 trap 7); in build mode
# it's a build slot; otherwise a tool slot.
func select_slot(slot: int) -> void:
	if actor == null or paused: return
	if inventory != null and inventory.is_open:
		inventory.assign_to(slot)
	elif build != null and build.active:
		actor.hotbar.select_build(slot)
	else:
		actor.hotbar.select_tool(slot)


# One slot along. With the inventory choosing a slot to assign to,
# the choice moves instead; otherwise the open inventory keeps the
# selection as it is.
func step_slot(step: int) -> void:
	if inventory != null and inventory.is_open:
		if inventory.assigning: inventory.step_assign(step)
	elif build != null and build.active:
		actor.hotbar.step_build(step)
	else:
		actor.hotbar.step_tool(step)


# Whether the mouse is on the hotbar, where a click selects a slot
# and must not also dig or place.
func _mouse_on_hotbar() -> bool:
	if hotbar_hud == null or current_device_scheme != DEVICE_SCHEME.MOUSE_AND_KEYBOARD:
		return false
	return hotbar_hud.slot_at(hotbar_hud.get_viewport().get_mouse_position()) != -1


# In build mode the cursor takes the aim, facing follows walking, and
# primary places once per press. A dig or breach held when the mode
# was entered stops (slice 007 trap 5).
func _build_mode(move: Vector2, delta: float) -> void:
	actor.aim(Vector2.ZERO, move)
	actor.primary_action(false)
	actor.breach(false)
	if current_device_scheme == DEVICE_SCHEME.MOUSE_AND_KEYBOARD:
		build.point_at(mouse_world_position.call())
	else:
		build.step(Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down"), delta)
	if Input.is_action_just_pressed("primary_action") and not _mouse_on_hotbar(): build.place()


# The reserved quick key (ui-ux §2.5, D-165): a timber prop at the
# cursor in build mode, otherwise on the tile faced. The world answers
# either way, with a placement or a refusal the notice shows.
func _quick_prop() -> void:
	if build != null and build.active:
		build.place(ObjectKind.OBJECT.TIMBER_PROP)
		return
	var here: WorldPos = actor.current_WorldPos
	var faced: WorldPos = WorldPos.new(here.x + actor.facing.x, here.y + actor.facing.y, here.depth)
	actor.current_level.world.place_requested.emit(actor, ObjectKind.OBJECT.TIMBER_PROP, faced)


func _inventory_mode(move: Vector2) -> void:
	actor.aim(Vector2.ZERO, move)
	actor.primary_action(false)
	actor.breach(false)
	# Choosing a slot to assign to (D-172): A puts it there, B cancels,
	# and nothing else in the inventory acts, so A doesn't also drop
	if inventory.assigning:
		if Input.is_action_just_pressed("assign_confirm"): inventory.confirm_assign()
		elif Input.is_action_just_pressed("assign_cancel"): inventory.cancel_assign()
		return
	if Input.is_action_just_pressed("ui_up"): inventory.move_focus(-1)
	if Input.is_action_just_pressed("ui_down"): inventory.move_focus(1)
	if Input.is_action_just_pressed("ui_left"): inventory.switch_section(-1)
	if Input.is_action_just_pressed("ui_right"): inventory.switch_section(1)
	if Input.is_action_just_pressed("inventory_assign"): inventory.begin_assign()
	if Input.is_action_just_pressed("drop_one"): inventory.drop_one()
	if Input.is_action_just_pressed("drop_stack"): inventory.drop_stack()


func _physics_process(delta: float) -> void:
	if actor == null or actor is not Actor:
		return
	if paused: return
	
	var move: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	actor.move(move)
	if support_overlay != null and Input.is_action_just_pressed("support_overlay"):
		support_overlay.toggle()
	if inventory != null and Input.is_action_just_pressed("inventory"):
		inventory.toggle()
		if inventory.is_open and build != null: build.set_active(false)
	if inventory != null and inventory.is_open:
		_inventory_mode(move)
		return
	# The take key: everything in reach, whatever the load (D-160)
	if Input.is_action_just_pressed("take"):
		actor.current_level.world.take_requested.emit(actor)
	if build != null and Input.is_action_just_pressed("build_mode"): build.toggle()
	if Input.is_action_just_pressed("quick_prop"): _quick_prop()
	if build != null and build.active:
		_build_mode(move, delta)
	else:
		actor.aim(_get_aim(), move)
		actor.primary_action(Input.is_action_pressed("primary_action") and not _mouse_on_hotbar())
		# Its own input, so a held dig never becomes a breach (D-153)
		actor.breach(Input.is_action_pressed("breach"))
	# A one-shot, polled here on the physics tick rather than handled
	# as an event, so the depth change it can cause happens on the same
	# tick as movement and digging (D-106). Read only here: reading it
	# in _process as well could count one press twice.
	if Input.is_action_just_pressed("interact"):
		actor.interact()
	# Pad A interacts first, and takes only with nothing to interact
	# with (D-167). A ladder too heavy to climb is still something to
	# interact with, so A refuses the climb rather than taking (slice
	# 011 trap 5).
	if Input.is_action_just_pressed("interact_or_take"): interact_or_take()


# Pad A (D-167): a ladder is used, even one too heavy to climb, which
# refuses; with nothing to interact with, everything in reach is
# taken, and the notice says what.
func interact_or_take() -> void:
	if actor.has_interaction(): actor.interact()
	else: actor.current_level.world.take_requested.emit(actor)


func _get_aim() -> Vector2:
	var aim: Vector2 = Vector2.ZERO
	
	if current_device_scheme == DEVICE_SCHEME.GAMEPAD:
		aim = Input.get_vector(
		"aim_left","aim_right","aim_up","aim_down")
		return aim
	
	if current_device_scheme == DEVICE_SCHEME.MOUSE_AND_KEYBOARD:
		var mouse_pos: Vector2 = mouse_world_position.call()
		aim = mouse_pos - actor.get_world_box().get_center()
		if aim.length() < MOUSE_DEAD_ZONE_PX:
			return Vector2.ZERO
		return aim.normalized()
	
	return aim


func _update_device_scheme(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		current_device_scheme = DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	elif event is InputEventJoypadButton:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD
	# Only a real push counts: a drifting stick would otherwise
	# keep stealing aim from the mouse.
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD




































