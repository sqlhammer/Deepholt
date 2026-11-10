extends GutTest

# What the debug log hears in a running game, and the bug capture
# (D-193 to D-197): moves with their causes, jumps nothing explains,
# the world's answers, saves, input; the capture folder, the pad's
# held combo, Y waiting on the trigger, and F3's switches.

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/debug_capture"
const CAPTURES: String = SaveDirs.TEST_ROOT + "/debug_captures"

var _game: Node


func before_each() -> void:
	Log.enabled = true
	Log.clear()
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	_game.new_game = true
	add_child_autofree(_game)
	_game.bug_capture.capture_dir = CAPTURES


func after_each() -> void:
	Input.action_release(&"capture_trigger")
	Log.clear()
	SaveDirs.remove_tree(SAVES_ROOT)
	SaveDirs.remove_tree(CAPTURES)


func _events(name: StringName) -> Array[Dictionary]:
	return Log.recent().filter(func(e: Dictionary) -> bool: return e.event == name)


func _actor() -> Actor:
	return _game.active_actor


# --- moves ---

func test_a_test_run_starts_no_session_file() -> void:
	assert_eq(Log.session_path(), "", "only the game's own run writes one")
	assert_not_null(_game.get_node_or_null("LogDriver"), "but the game listens")


func test_move_to_is_logged_with_its_cause_and_caller() -> void:
	var actor: Actor = _actor()
	Log.clear()
	assert_true(actor.move_to(WorldPos.new(0, 0, 1), &"ladder"), "down")
	var found: Array[Dictionary] = _events(&"move_to")
	assert_eq(found.size(), 1, "one move_to")
	assert_eq(found[0].data.cause, &"ladder", "its cause")
	assert_eq(found[0].data.actor, actor.actor_id, "by actor id")
	assert_eq(found[0].data.to, [0, 0, 1], "where to")
	assert_true(found[0].data.ok, "and that it happened")
	assert_string_contains(str(found[0].data.by), "test_debug_capture.gd", "who called it")
	assert_eq(_events(&"changed_level").size(), 1, "the level change too")


func test_a_refused_move_to_is_logged_as_refused() -> void:
	Log.clear()
	assert_false(_actor().move_to(WorldPos.new(0, 0, 99), &"ramp"), "no level at 99")
	assert_false(_events(&"move_to")[0].data.ok, "logged, not ok")


func test_a_jump_nothing_explains_is_logged() -> void:
	var actor: Actor = _actor()
	await get_tree().physics_frame
	await get_tree().physics_frame
	Log.clear()
	actor.position += Vector2(10 * TileSpace.TILE_PIXELS, 0)
	await get_tree().physics_frame
	var found: Array[Dictionary] = _events(&"jump")
	assert_eq(found.size(), 1, "one jump")
	assert_false(found[0].data.explained, "nothing explained it")
	assert_eq(found[0].data.actor, actor.actor_id, "whose")


func test_a_move_to_is_not_a_jump() -> void:
	await get_tree().physics_frame
	Log.clear()
	_actor().move_to(WorldPos.new(0, 0, 1), &"ramp")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(_events(&"jump").size(), 0, "explained by the move_to")


func test_each_tile_step_is_logged() -> void:
	var actor: Actor = _actor()
	Log.clear()
	var from: WorldPos = actor.current_WorldPos
	actor._move(Vector2(TileSpace.TILE_PIXELS, 0))
	if actor.current_WorldPos.equals(from): actor._move(Vector2(-2 * TileSpace.TILE_PIXELS, 0))
	assert_gt(_events(&"stepped").size(), 0, "a step")


# --- the world, saves ---

func test_the_worlds_refusals_are_logged_by_name() -> void:
	Log.clear()
	var actor: Actor = _actor()
	_game.world.breach_requested.emit(actor, actor.current_WorldPos, 0.0)
	var found: Array[Dictionary] = _events(&"breach_refused")
	assert_eq(found.size(), 1, "the refusal")
	assert_true(found[0].data.reason is String, "its reason by name: %s" % found[0].data.reason)
	assert_eq(found[0].data.actor, actor.actor_id, "whose")


func test_a_save_is_logged_with_what_asked() -> void:
	Log.clear()
	assert_true(_game.save_game(&"quick_save"), "saved")
	var found: Array[Dictionary] = _events(&"saved")
	assert_eq(found.size(), 1, "logged")
	assert_eq(found[0].data.reason, &"quick_save", "what asked")
	assert_eq(found[0].data.result, "NONE", "and how it went")


# --- input ---

func test_an_action_is_logged_once_when_pressed_and_once_when_released() -> void:
	var driver: LogDriver = _game.get_node("LogDriver")
	Log.clear()
	var press: InputEventAction = InputEventAction.new()
	press.action = &"hotbar_2"
	press.pressed = true
	driver.record(press)
	driver.record(press)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"hotbar_2"
	release.pressed = false
	driver.record(release)
	assert_eq(_events(&"pressed").size(), 1, "pressed once, though sent twice")
	assert_eq(_events(&"released").size(), 1, "released")
	assert_eq(_events(&"pressed")[0].data.action, &"hotbar_2", "which")


# --- the capture (D-194, D-197) ---

func test_a_capture_writes_its_folder() -> void:
	Log.event(Log.WORLD, &"breached", {"actor": 1})
	var folder: String = _game.bug_capture.capture()
	assert_ne(folder, "", "made")
	for name: String in ["log.jsonl", "log.txt", "world.save", "info.json"]:
		assert_true(FileAccess.file_exists(folder.path_join(name)), name)
	var jsonl: String = FileAccess.get_file_as_string(folder.path_join("log.jsonl"))
	assert_string_contains(jsonl, "\"breached\"", "the recent events")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("info.json")))
	assert_eq(info.save, "saved", "the world saved into it")
	assert_eq(info.actors.size(), 1, "every actor's place")
	assert_eq(int(info.world_seed), _game.world.world_seed, "the seed")
	assert_has(info, "build", "the build")
	var loaded: SaveGame.SlotLoad = SaveGame.load_slot(folder)
	assert_eq(loaded.source, SaveGame.SOURCE.SAVE, "its save loads")
	if loaded.loaded != null: loaded.loaded.world.free()


func test_the_capture_leaves_the_players_own_save_alone() -> void:
	_game.save_game(&"quick_save")
	var slot: String = _game.current_save_slot
	var before: int = FileAccess.get_modified_time(slot.path_join("world.save"))
	var backups: bool = FileAccess.file_exists(slot.path_join("world.save.bak"))
	_game.bug_capture.capture()
	assert_eq(FileAccess.get_modified_time(slot.path_join("world.save")), before, "untouched")
	assert_eq(FileAccess.file_exists(slot.path_join("world.save.bak")), backups, "no new backup")


func test_only_the_twenty_newest_captures_are_kept() -> void:
	for i in range(25):
		DirAccess.make_dir_recursive_absolute(CAPTURES.path_join("capture-2000%04d" % i))
	_game.bug_capture.capture()
	var left: PackedStringArray = DirAccess.get_directories_at(CAPTURES)
	assert_eq(left.size(), 20, "twenty")
	assert_false(left.has("capture-20000000"), "the oldest gone")


func test_two_captures_in_a_second_get_their_own_folders() -> void:
	var first: String = _game.bug_capture.capture()
	var second: String = _game.bug_capture.capture()
	assert_ne(first, second, "two folders")


# --- the pad's combo (D-195) ---

func test_the_combo_captures_once_after_two_seconds_held() -> void:
	var capture: BugCapture = _game.bug_capture
	watch_signals(capture)
	capture.hold(1.0, true)
	assert_signal_not_emitted(capture, "captured", "not at one second")
	capture.hold(1.1, true)
	assert_signal_emit_count(capture, "captured", 1, "at two")
	capture.hold(5.0, true)
	assert_signal_emit_count(capture, "captured", 1, "once per hold")
	capture.hold(0.1, false)
	capture.hold(2.0, true)
	assert_signal_emit_count(capture, "captured", 2, "again after letting go")


func test_y_waits_while_the_left_trigger_is_held() -> void:
	assert_false(InputHandler.capture_combo_held(), "not held")
	Input.action_press(&"capture_trigger")
	assert_true(InputHandler.capture_combo_held(), "held: Y's actions wait")
	Input.action_release(&"capture_trigger")


func test_the_capture_bindings() -> void:
	var key: InputEventKey = InputMap.action_get_events(&"capture_bug")[0]
	assert_eq([key.physical_keycode, key.ctrl_pressed], [KEY_F9, true], "Ctrl+F9")
	var trigger: InputEventJoypadMotion = InputMap.action_get_events(&"capture_trigger")[0]
	assert_eq(trigger.axis, JOY_AXIS_TRIGGER_LEFT, "the left trigger")
	var button: InputEventJoypadButton = InputMap.action_get_events(&"capture_button")[0]
	assert_eq(button.button_index, JOY_BUTTON_Y, "Y")


# --- F3 (D-196) ---

func test_f3_switches_a_channel_and_shows_it() -> void:
	var overlay: Node = _game.get_node("DebugOverlay")
	overlay.switch_channel(Log.CHANNELS.find(Log.INPUT))
	assert_false(Log.is_on(Log.INPUT), "off")
	assert_string_contains(overlay.log_text(), "input off", "shown")
	overlay.switch_channel(Log.CHANNELS.find(Log.INPUT))
	assert_true(Log.is_on(Log.INPUT), "on again")


func test_ctrl_and_a_number_never_picks_a_hotbar_slot() -> void:
	var handler: InputHandler = null
	for child: Node in _game.get_children():
		if child is InputHandler: handler = child
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_3
	key.keycode = KEY_3
	key.pressed = true
	key.ctrl_pressed = true
	handler._hotbar_input(key)
	assert_eq(_actor().hotbar.selected_tool, 0, "left to F3")
