extends Timer

var seconds: float:
	get: return _seconds
var _seconds: float = 0.0


func _on_timeout() -> void:
	_seconds += wait_time


func _to_string() -> String:
	return Global.format_duration(seconds)


func setup(p_secs: float) -> void:
	_seconds = p_secs













