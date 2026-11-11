class_name TuningProfile
extends Resource

# Every tuning number in one swappable resource (D-037), one .tres
# per profile under DIR, named by its id. The world holds the one it
# runs under (`world.tuning`, D-135), and simulation reaches it
# through a level, like everything else (D-126). A save records the
# id, and a load runs the world under the profile the save names, or
# the default (D-136).
#
# The numbers live in the .tres, not here: a number written into a
# script is a bug even when it's right (D-037). Each default below is
# a zero that no profile should keep.

const DIR: String = "res://content/tuning/"
const DEFAULT_ID: String = "default"

@export var id: String = ""

## Simulation

# The depths a new world is generated with, before any actor is
# spawned (D-143).
@export var levels_to_generate_on_new_game: Array[int] = []

# How often the game saves while playing, in seconds (D-110).
@export var autosave_interval_seconds: float = 0.0

# How fast an actor walks, in level pixels per second.
@export var walk_speed: float = 0.0

# How hard each diggable top kind is to dig, keyed by its TileKind.TOP
# id: the tuning appendix's hardness (D-081). Dig seconds = hardness /
# tool power, so flint (16) digs rock (6) in 0.375 s.
@export var hardness: Dictionary[int, float] = {}

# A tile holding ore takes this much longer to dig than the same tile
# without it (tuning appendix, section 4).
@export var ore_dig_multiplier: float = 0.0

# How well each tool class digs each top kind (D-168): class ->
# (TileKind.TOP id -> multiplier on the tool's power). A kind a class
# doesn't list is x1. So the shovel (x2 on dirt) digs dirt twice as
# fast as its power alone would.
@export var tool_multipliers: Dictionary[int, Dictionary] = {}

# The least tool power that digs each ore at all, keyed by its
# TileKind.ORE id (D-217): iron needs more than flint has. An ore it
# doesn't list needs nothing.
@export var ore_tool_power_needed: Dictionary[int, float] = {}

# What digging yields (D-156): stone per rock wall, and the range of
# ore an ore vein gives.
@export var rock_wall_stone: int = 0
@export var ore_yield_min: int = 0
@export var ore_yield_max: int = 0

# Each level's floor hardness, by depth: its stratum's number from the
# tuning appendix (D-151).
@export var floor_hardness_by_depth: Array[float] = []

# A breach takes hardness x this / tool power seconds, and needs a
# tool at least hardness x the gate multiplier strong (tuning
# appendix §4, D-151).
@export var breach_time_multiplier: float = 0.0
@export var breach_tool_multiplier: float = 0.0

# How far a player senses, in steps through open space (D-145).
@export var sense_radius: int = 0

# How far a brazier's light reaches, in steps through open space
# (D-149).
@export var brazier_light_radius: int = 0

# How much a pack carries before its load counts as over 100%, in kg
# (D-013, tuning appendix §3). Not a cap: a pack can go past it
# (D-158).
@export var carry_capacity_kg: float = 0.0

# The load curve (D-030, tuning appendix §2): walking speed's
# multiplier at each load, as (load, multiplier) points, load being a
# share of capacity; straight lines between them; and the multiplier
# past the last point.
@export var load_speed_points: Array[Vector2] = []
@export var load_speed_beyond: float = 0.0

# Past this load, no ladder can be climbed (D-030, D-159).
@export var ladder_load_limit: float = 0.0

# How long a climb takes, up or down (D-233, tuning appendix §2): the
# seconds unloaded, and the multiplier on them past each load, as
# (load, multiplier) points: past the first load the first multiplier,
# and so on. A load under every point climbs at x1.
@export var ladder_climb_seconds: float = 0.0
@export var climb_load_steps: Array[Vector2] = []

# What placing a ladder costs, item id -> count (D-156): four timber.
@export var ladder_cost: Dictionary[StringName, int] = {}

# Yields and automatic pickup fill a pack only to this share of its
# capacity (D-160): past it is the take key's, on purpose.
@export var auto_fill_limit: float = 0.0
# How far a player picks drops up from, in tiles around it (D-160): 1
# is its own tile and the eight around it.
@export var pickup_reach: int = 0

# What a new game's first player starts with, item id -> count
# (D-156): the ten timber a ladder is built from.
@export var starting_items: Dictionary[StringName, int] = {}

# How far a support holds a ceiling up, in tiles (Chebyshev), by depth
# (D-163, digging-and-structure §2). Zero is no ceiling at all: the
# Surface is open sky, so nothing there is judged.
@export var support_radius_by_depth: Array[int] = []

# How long a failing region has before it falls, in seconds (D-166).
@export var collapse_countdown_seconds: float = 0.0

# The Surface (D-180): the rock disc around the ramp; the road's
# length from its start to the ramp, its legs' lengths, its width; the
# share of the meadow that's dirt; the share of open grass with a
# tree, and how far trees stand off the road and the spawn.
@export var surface_rock_radius: int = 0
@export var surface_road_length: float = 0.0
@export var surface_road_bend_min: float = 0.0
@export var surface_road_bend_max: float = 0.0
@export var surface_road_width: int = 0
@export var surface_dirt_share: float = 0.0
@export var surface_tree_share: float = 0.0
@export var surface_tree_clearance: int = 0

# Natural caves (D-184): how many a level with caves gets, and how
# far, in tiles, each keeps from the fixed rooms and the others.
@export var cave_count_min: int = 0
@export var cave_count_max: int = 0
@export var cave_spacing: int = 0

# Ore in the rock (D-183, D-187): for each TileKind.ORE id, its share
# of a level's minable rock, by depth (an entry per depth; a missing
# one is none); and the size of a vein, in tiles.
@export var ore_shares: Dictionary[int, Array] = {}
@export var vein_size_min: int = 0
@export var vein_size_max: int = 0

# The way down from a level that has one (D-215, D-229): how far its
# ramp's chamber lies from the level's landing, in tiles, and the
# width range of the tunnel carved between them.
@export var descent_distance_min: int = 0
@export var descent_distance_max: int = 0
@export var tunnel_width_min: int = 0
@export var tunnel_width_max: int = 0

# A CRUSHED region (D-218): the radius range of the circles its blob
# is built from, how many circles, and how far its center keeps from
# the level's landing, in tiles.
@export var crushed_radius_min: int = 0
@export var crushed_radius_max: int = 0
@export var crushed_lobes: int = 0
@export var crushed_distance_min: int = 0

# Felling a tree (D-181): the work an axe does, at its power per
# second (48 at flint's 16 is 3 s), and the timber it gives.
@export var tree_work: float = 0.0
@export var tree_timber: int = 0

# What placing a timber prop costs, item id -> count (D-165): two
# timber.
@export var prop_cost: Dictionary[StringName, int] = {}

# What a chute costs, item id -> count (D-220): two timber, since down
# is the cheap direction.
@export var chute_cost: Dictionary[StringName, int] = {}

# The hand winch (D-224, D-225): what it costs, item id -> count; how
# many seconds one player's cranking takes to lift its crate a level
# and to lower it; and how much the crate holds, in kg. Two players
# cranking add their rates.
@export var winch_cost: Dictionary[StringName, int] = {}
@export var winch_lift_seconds: float = 0.0
@export var winch_lower_seconds: float = 0.0
@export var crate_capacity_kg: float = 0.0

# The torch (D-221): how long one burns while lit, in seconds, and how
# far its light reaches, in steps through open space, carried or
# dropped.
@export var torch_burn_seconds: float = 0.0
@export var torch_light_radius: int = 0

## Presentation

# How long a level change's fade through black lasts, out and back in
# (D-142). Zero switches at once.
@export var level_change_fade_seconds: float = 0.0

# How bright a Sensed tile's grey is, 1 being the art's own brightness
# (D-146).
@export var sensed_brightness: float = 0.0

# How bright a Remembered tile's grey is (D-146).
@export var remembered_brightness: float = 0.0

# How far build mode's cursor reaches from the player, in tiles
# (ui-ux §2.1, D-154). The mouse and the stick share it.
@export var build_cursor_radius: int = 0


# The profile with this id, or null if this build has none.
static func find(profile_id: String) -> TuningProfile:
	if profile_id.is_empty() or not profile_id.is_valid_filename(): return null
	var path: String = DIR.path_join(profile_id + ".tres")
	if not ResourceLoader.exists(path): return null
	var profile: Resource = load(path)
	return profile as TuningProfile


static func default_profile() -> TuningProfile:
	return find(DEFAULT_ID)


# The profile with this id, or the default with a warning when this
# build doesn't have it (D-136). `what` names whose choice it was.
static func find_or_default(profile_id: String, what: String) -> TuningProfile:
	var profile: TuningProfile = find(profile_id)
	if profile != null: return profile
	push_warning("%s names tuning profile \"%s\", which this build doesn't have; using \"%s\"." % [
		what, profile_id, DEFAULT_ID])
	return default_profile()

