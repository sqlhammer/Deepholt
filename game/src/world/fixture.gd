class_name Fixture
extends RefCounted

# One thing placed on a level (D-100, D-103): a kind, a tile and an
# id. Plain data, not a node: presentation draws from it, and the
# level's LevelFixtures is the only copy of the truth.
#
# `tile` is read-only (D-138). The store files a fixture under its
# tile, so only the store moves one (LevelFixtures.move, receive);
# changing it anywhere else would leave the two disagreeing, and
# lookups would quietly miss it.

var kind: int
# A copy each time: a WorldPos is shared by reference, and a caller
# changing theirs mustn't move the fixture.
var tile: WorldPos:
	get: return WorldPos.new(_tile.x, _tile.y, _tile.depth)
	set(_value): push_error("Fixture #%d's tile is read-only; move it through its world (D-138)." % id)
var id: int
# What a fixture that holds items holds (a crate, D-224), or null for
# one that holds nothing. It travels with the fixture when it moves
# between levels, and is saved with it.
var contents: Pack = null
# Seconds left before a fixture that burns down is gone (a dropped
# torch, D-221); below zero for one that doesn't. Saved with it.
var time_left: float = -1.0

var _tile: WorldPos


func _init(p_kind: int, p_tile: WorldPos, p_id: int) -> void:
	kind = p_kind
	id = p_id
	_set_tile(p_tile)


# For LevelFixtures only, as it re-files the fixture.
func _set_tile(p_tile: WorldPos) -> void:
	_tile = WorldPos.new(p_tile.x, p_tile.y, p_tile.depth)


func _to_string() -> String:
	return "%s %s #%d" % [ObjectKind.OBJECT.find_key(kind), _tile, id]
