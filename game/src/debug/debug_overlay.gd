extends CanvasLayer

var debug_text : Dictionary = {}


func _ready() -> void:
	Global.connect("debug_event",set_section)
	
	#Global.emit_signal("debug_event","Test","55 FPS") # temp


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle_debug_overlay()


func _toggle_debug_overlay() -> void:
	self.visible = not self.visible


func set_section(title: String, text: String, remove: bool = false) -> void:
	if remove:
		remove_section(title)
	else:
		_register_section(title, text)
	
	_update_section(debug_text)


func remove_section(title: String) -> void:
	debug_text.erase(title)
	_update_section(debug_text)


func _update_section(dict: Dictionary) -> void:
	if dict == null: return
	
	debug_text.sort()
	$DebugRichTextLabel.text = ""
	
	for key in debug_text:
		$DebugRichTextLabel.text = "[b]%s[/b]: %s\n" % [key, debug_text[key]]


func _register_section(title: String, text: String) -> void:
	debug_text[title] = text












