class_name Fixture
extends RefCounted

# One thing placed on a level (D-100, D-103): a kind, a tile and an id.
# Plain data, not a node: presentation draws from it, and the level's
# LevelFixtures is the only copy of the truth.
#
# Set once, in _init, and never reassigned. The store files a fixture
# under its tile; changing `tile` afterwards would leave the two
# disagreeing, and lookups would quietly miss it.

var kind: int
var tile: WorldPos
var id: int


func _init(p_kind: int, p_tile: WorldPos, p_id: int) -> void:
	kind = p_kind
	# A copy: a WorldPos is shared by reference, and a caller changing
	# theirs mustn't move the fixture.
	tile = WorldPos.new(p_tile.x, p_tile.y, p_tile.depth)
	id = p_id


func _to_string() -> String:
	return "%s %s #%d" % [ObjectKind.OBJECT.find_key(kind), tile, id]
