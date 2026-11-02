class_name SaveSession
extends RefCounted

# What a save holds that isn't the world's (D-130): which actor is
# local, and the two playtime clocks (D-120). A new header field that
# isn't the world's becomes a field here, so no call to
# SaveGame.save_game changes. The tuning profile is the world's
# (D-135), so its id comes from the world, not from here.
#
# The local actor is presentation's choice (D-045, D-115), saved
# beside the world as an id; SaveGame never chooses one.
#
# A loaded session holds -1 for anything the save left out (D-131).

# -1 for none
var local_actor_id: int = -1
var active_play_time: float = 0.0
var total_play_time: float = 0.0


func _init(p_local_actor_id: int = -1, p_active_play_time: float = 0.0,
		p_total_play_time: float = 0.0) -> void:
	local_actor_id = p_local_actor_id
	active_play_time = p_active_play_time
	total_play_time = p_total_play_time
