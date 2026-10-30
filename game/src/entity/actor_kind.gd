class_name ActorKind
extends RefCounted

# Type ids foractors. A save will store these numbers, so -- like TileKind -- 
# every id is explicit, never reordered, and never reused once retired.

const ACTOR: Dictionary = {
	"NULL": 0,
	"PLAYER": 1,
}
