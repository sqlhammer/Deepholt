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
# The scheme in use changed (D-223): what's on screen names its keys
# only.
signal device_scheme_changed(scheme: DEVICE_SCHEME)

# On the CRAFT tab, confirm held keeps making (D-222): after this long,
# then once every REPEAT. Feel, not tuning.
const MAKE_HOLD_SECONDS: float = 0.4
const MAKE_REPEAT_SECONDS: float = 0.15

var _make_held: float = 0.0

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
	actor.crank(false)


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
	# Ctrl+1 to Ctrl+7 are F3's log switches (D-196), not slots
	if event is InputEventKey and event.ctrl_pressed: return
	for i in range(Hotbar.SLOTS):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)
			return
	# LB and RB switch the open inventory's tab (D-222); the wheel
	# scrolls its grid instead, on the board itself
	if inventory != null and inventory.is_open and event is InputEventJoypadButton \
			and (event.is_action_pressed("hotbar_prev") or event.is_action_pressed("hotbar_next")):
		inventory.switch_tab()
		return
	if event.is_action_pressed("hotbar_prev"): step_slot(-1)
	elif event.is_action_pressed("hotbar_next"): step_slot(1)


# A slot chosen by its key or a click. With the inventory open it's
# where the focused thing goes (D-178, slice 011 trap 7); in build mode
# it's a build slot; otherwise a tool slot.
func select_slot(slot: int) -> void:
	if actor == null or paused: return
	if inventory != null and inventory.is_open:
		inventory.assign_to(slot)
	elif build != null and build.active:
		actor.hotbar.select_build(slot)
	else:
		actor.hotbar.select_tool(slot)


# One slot along. The open inventory keeps the selection as it is.
func step_slot(step: int) -> void:
	if inventory != null and inventory.is_open: return
	if build != null and build.active:
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
	actor.crank(false)
	# The focus over the grid and the bars (D-175)
	if Input.is_action_just_pressed("ui_up"): inventory.move(Vector2i.UP)
	if Input.is_action_just_pressed("ui_down"): inventory.move(Vector2i.DOWN)
	if Input.is_action_just_pressed("ui_left"): inventory.move(Vector2i.LEFT)
	if Input.is_action_just_pressed("ui_right"): inventory.move(Vector2i.RIGHT)
	if Input.is_action_just_pressed("inventory_tab"): inventory.switch_tab()
	# Pick up, put down, cancel, drop, sort (D-177, D-178). The mouse's
	# clicks are the board's own. On the CRAFT tab, confirm makes, and
	# held keeps making.
	if Input.is_action_just_pressed("inventory_pick"): inventory.pick_or_place()
	_hold_to_make(get_physics_process_delta_time())
	if Input.is_action_just_pressed("inventory_cancel"): inventory.cancel()
	if Input.is_action_just_pressed("drop_one") and not capture_combo_held(): inventory.drop_one()
	if Input.is_action_just_pressed("drop_stack"): inventory.drop_stack()
	if Input.is_action_just_pressed("inventory_sort"): inventory.sort()


# Confirm held on the CRAFT tab makes again after a moment, then at a
# steady pace, while the inputs last (D-222).
func _hold_to_make(delta: float) -> void:
	if inventory.tab != InventoryOverlay.TAB.CRAFT or not Input.is_action_pressed("inventory_pick"):
		_make_held = 0.0
		return
	var before: float = _make_held
	_make_held += delta
	if _make_held < MAKE_HOLD_SECONDS: return
	var steps_before: int = floori(maxf(before - MAKE_HOLD_SECONDS, -1.0) / MAKE_REPEAT_SECONDS)
	var steps_now: int = floori((_make_held - MAKE_HOLD_SECONDS) / MAKE_REPEAT_SECONDS)
	if steps_now > steps_before: inventory.make()


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
	if build != null and Input.is_action_just_pressed("build_mode") and not capture_combo_held():
		build.toggle()
	if Input.is_action_just_pressed("quick_prop"): _quick_prop()
	# L or D-pad up: the light in its slot, lit or put out (D-228)
	if Input.is_action_just_pressed("toggle_light"): actor.toggle_light()
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
	# Interact held cranks a winch (D-225): E, or pad A, which is also
	# interact. Build mode leaves the winch alone.
	var held: bool = Input.is_action_pressed("interact") or Input.is_action_pressed("interact_or_take")
	actor.crank(held and not (build != null and build.active))


# Pad A (D-167): a crate faced that holds something is emptied, even
# at the top of a winch's hole, where holding A on goes on to crank
# (D-224, D-225); a ladder is used, even one too heavy to climb, which
# refuses; with nothing to interact with, everything in reach is
# taken, and the notice says what.
func interact_or_take() -> void:
	var world: World = actor.current_level.world
	var crate: Fixture = world.crate_faced(actor)
	if crate != null and not crate.contents.is_empty(): world.take_requested.emit(actor)
	elif actor.has_interaction(): actor.interact()
	else: world.take_requested.emit(actor)


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


# The left trigger is held: Y is half of the bug capture's combo, so
# its own actions wait (D-195).
static func capture_combo_held() -> bool:
	return Input.is_action_pressed(&"capture_trigger")


func _update_device_scheme(event: InputEvent) -> void:
	var was: DEVICE_SCHEME = current_device_scheme
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		current_device_scheme = DEVICE_SCHEME.MOUSE_AND_KEYBOARD
	elif event is InputEventJoypadButton:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD
	# Only a real push counts: a drifting stick would otherwise
	# keep stealing aim from the mouse.
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		current_device_scheme = DEVICE_SCHEME.GAMEPAD
	if current_device_scheme != was:
		Log.event(Log.INPUT, &"device", {"actor": Log.actor_id(actor),
			"scheme": DEVICE_SCHEME.find_key(current_device_scheme)})
		device_scheme_changed.emit(current_device_scheme)




































