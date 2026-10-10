extends GutTest

# The one tool in pre-alpha (D-077): a flint pickaxe, the lowest tier
# the tuning appendix defines (D-081). Dig seconds = hardness / power.

const FLINT_PICKAXE: String = "res://src/entity/tools/flint_pickaxe.tres"


func test_the_pickaxe_is_flint_tier() -> void:
	var tool: ToolData = load(FLINT_PICKAXE)
	assert_eq(tool.tool_name, "Flint Pickaxe", "named for its tier")
	assert_eq(tool.verb, "dig", "it digs")
	assert_eq(tool.tier, 1, "flint is the first tier")
	assert_eq(tool.speed, 16.0, "flint's power from the tuning appendix")


func test_flint_digs_surface_stone_in_0_375_seconds() -> void:
	var tool: ToolData = load(FLINT_PICKAXE)
	var rock: float = TileKind.get_tile_density(TileKind.TOP.MINABLE_ROCK)
	assert_almost_eq(rock / tool.speed, 0.375, 0.0001, "6 / 16")


func test_actors_start_with_the_flint_pickaxe() -> void:
	var actor: Actor = autofree(Global.actor_packed_scene.instantiate())
	assert_eq(actor.equipped.resource_path, FLINT_PICKAXE, "the fixed pre-alpha tool")
