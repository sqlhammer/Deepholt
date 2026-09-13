extends CanvasLayer

var debug_text : Dictionary = {}


func _ready() -> void:
	Global.connect("debug_event",set_section)
	set_section("World Seed",str(World.world_seed)) # World emits prior to this being ready. Once we implement a loading screen, World seed will update later and we can remove this.


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
	
	debug_text.sort() # TODO: Change this method of sorting so that information is grouped more logically
	$DebugRichTextLabel.text = ""
	
	for key in debug_text:
		var _txt = $DebugRichTextLabel.text
		$DebugRichTextLabel.text = _txt + "[b]%s[/b]: %s\n" % [key, debug_text[key]]


func _register_section(title: String, text: String) -> void:
	debug_text[title] = text


func _on_timer_timeout() -> void:
	set_player_positions()


func set_player_positions() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if not players: return
	
	for player: Player in players:
		set_section(player.player_name,str(player.current_WorldPos))








