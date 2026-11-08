extends Node

var actor_packed_scene: PackedScene = preload("res://src/entity/actor.tscn")
var level_packed_scene: PackedScene = preload("res://src/world/level.tscn")

# Small number that is less than a pixel but larger than a float
# rounding error Used in coordinate math to ensure that exclusive
# edges will round down with floor()
const epsilon: float = 0.001

signal debug_event (title: String, text: String, remove: bool)

enum CAPABILITY {
	NONE,
	DIG,
	BREACH,
}

func get_capability_packedscene(capability: CAPABILITY) -> PackedScene:
	var scene: PackedScene
	match capability:
		CAPABILITY.DIG: scene = load("res://src/entity/capabilities/capability_dig.tscn")
		CAPABILITY.BREACH: scene = load("res://src/entity/capabilities/capability_breach.tscn")
	return scene

func contains_whitespace(text: String) -> bool:
	var regex = RegEx.new()
	# \\s matches spaces, tabs, and newlines
	regex.compile("\\s") 
	
	var result = regex.search(text)
	return result != null


func is_regex_match(data: String, pattern: String) -> bool:
	var regex = RegEx.new()
	if regex.compile(pattern) != OK:
		push_error("Invalid regex pattern: %s" % pattern)
		return false

	return regex.search(data) != null


func format_duration(seconds: float) -> String:
	var secs: int = maxi(0, floori(seconds))
	var days: int = floori(secs / 86400.0)
	var hours: int = floori((secs % 86400) / 3600.0)
	var minutes: int = floori((secs % 3600) / 60.0)
	var formatted_seconds: int = secs % 60
	if days > 0:
		return "%dd %02d:%02d:%02d" % [days, hours, minutes, formatted_seconds]
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, formatted_seconds]
	return "%02d:%02d" % [minutes, formatted_seconds]


func get_game_version() -> String:
	return ProjectSettings.get_setting("application/config/version", "")


# Now, as Unix seconds (always UTC) and the system's offset from UTC
# in minutes. The offset includes daylight saving on Windows too.
func get_real_time() -> Dictionary:
	return {
		"unix": int(Time.get_unix_time_from_system()),
		"utc_offset": Time.get_time_zone_from_system().bias,
	}


# Pass a saved offset for the writer's local time, the system's for
# the reader's, or none for UTC.
func format_unix_time(unix: int, offset_minutes: int = 0) -> String:
	return Time.get_datetime_string_from_unix_time(unix + offset_minutes * 60, true)



























