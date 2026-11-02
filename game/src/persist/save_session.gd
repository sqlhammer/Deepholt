class_name SaveSession
extends RefCounted

# What a save holds that isn't the world's (D-130): which actor is
# local, the tuning profile, and the two playtime clocks (D-120). A
# new header field that isn't the world's becomes a field here, so no
# call to SaveGame.save_game changes.
#
# The local actor is presentation's choice (D-045, D-115), saved
# beside the world as an id; SaveGame never chooses one.

# -1 for none
var local_actor_id: int = -1
var tuning_profile_id: String = ""
var active_play_time: float = 0.0
var total_play_time: float = 0.0


func _init(p_local_actor_id: int = -1, p_tuning_profile_id: String = "",
		p_active_play_time: float = 0.0, p_total_play_time: float = 0.0) -> void:
	local_actor_id = p_local_actor_id
	tuning_profile_id = p_tuning_profile_id
	active_play_time = p_active_play_time
	total_play_time = p_total_play_time
