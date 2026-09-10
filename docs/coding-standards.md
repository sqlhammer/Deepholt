# Coding standards

Rules enforced by code review rather than automated tooling. Add to this list as new
standards come up; reference the relevant entry from a review comment rather than
re-explaining the rationale each time.

# Test ability

- Optimize for readability and ease of troubleshooting
- Break out node trees into independently runnable and testable scenes
- Minimize coupling and direct dependencies between scenes and export configuration variables where it makes editor usability and testing easier

# Naming standards
Begin by complying with the naming standards published [here](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).Then, treat the below requirements as superceding mandates.

- Generic naming such as, Button_1, is never used. Instead, descriptive names will be used for all variables, functions, scenes, nodes, etc. For example, Button_1, could become, SaveButton.
- Abbreviations are avoided in favor of using fully qualified words/names.
- Variables are strongly typed for any method signatures
- Void functions are explicitly labeled as void
- Method/function parameters that involved concatonation or math with more than two components will be first resolved in a local variable and then the local variable will be passed into the method/function.

# Project Structure

- Minimize the use of direct method calls between Nodes. Instead, favor the use of signals for communication
- Every project's starting node is named Game and is the generic Node type
- On ready, the Game script will call a method in the SceneHandler to load the openning scene
- Purpose-specific configuration files are used, when appropriate, to keep game configuration abstracted away from scene code
- When using inheritance, always leverage class_names rather than ```extends "res://"``` formats
- Decorate all classes, scripts, and methods with plain language comments explaining the purpose behind each component
- When marking spawn locations or important locations, prefer to use Marker2D or Marker3D node types
- Use AnimationPlayers for animations rather than code-based frame cycling.

## No player singleton

**Rule:** Simulation code must take an actor — or a set of actors — as a parameter. No
global, autoload, or accessor resolves to "the" character.

**Allowed:** presentation-layer code (camera, HUD, input routing) may hold a `LocalActor`
reference to the locally controlled actor. This is restricted to `game/src/render/` and
`game/src/debug/` — see the source layout in
[M0-01](../work/chunks/M0/M0-01-project-skeleton.md).

**Not allowed, anywhere in `game/src/world/`, `game/src/sim/`, `game/src/entity/`, or
`game/src/persist/`:**
- A global named `player`, an autoload registered as `Player` (or similar) in
  `project.godot`.
- `get_player()`, `Player.` member access, `PlayerSingleton`, `class_name Player`.
- The two Godot-idiomatic singletons in disguise: `get_first_node_in_group("player")` and
  `get_node("/root/Player")`.
- A function needing actor state that takes no actor argument.
- `if actor == player` or equivalent identity checks against an implicit "the" character.

**Why:** a singleton is an assumption baked into every call site, and it collapses six
distinct questions — union of all actors, any actor, per actor, nearest actor, one specific
actor, N actors — into a single accessor that nothing can help disentangle later. See
[D-045](design-decisions.md) for the full rationale.

**Review smell tests:** a global named `player`; a function needing actor state that takes
no actor argument; `if actor == player` in gameplay code; any singleton access outside
presentation.
