class_name LogDriver
extends Node

# The debug log's work that needs a frame (D-193, D-196): wakes the
# writer once a frame, records each action as it's pressed or
# released, and frames over budget. Presentation: it reads input and
# frame times, never the world.

# A frame this long is over budget: three frames at 60 a second
const SLOW_FRAME_MSEC: float = 50.0

# The actions watched: every one the game defines, not Godot's ui_*
var _actions: Array[StringName] = []
# Which are down, so only a change is logged: a stick held past its
# deadzone sends motion every frame
var _down: Dictionary[StringName, bool] = {}


func _ready() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"): _actions.append(action)


func _process(delta: float) -> void:
	if delta * 1000.0 > SLOW_FRAME_MSEC:
		Log.event(Log.PERF, &"slow_frame", {"msec": snappedf(delta * 1000.0, 0.1),
			"process_msec": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
			"physics_msec": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				0.1)})
	Log.flush()


func _input(event: InputEvent) -> void:
	record(event)


# Logs each action this event presses or releases. Mouse motion
# presses nothing and is skipped before the search.
func record(event: InputEvent) -> void:
	if event is InputEventMouseMotion or not Log.is_on(Log.INPUT): return
	for action: StringName in _actions:
		if not event.is_action(action): continue
		var pressed: bool = event.is_action_pressed(action, true)
		if pressed == _down.get(action, false): continue
		_down[action] = pressed
		Log.event(Log.INPUT, &"pressed" if pressed else &"released", {"action": action,
			"device": event.get_class().trim_prefix("InputEvent")})
