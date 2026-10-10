# 001 — Dig one tile

**Draft by Claude, 2026-10-10. Derik corrects.** The correction pass is the point: change
anything that isn't how it felt from your side.

> The smallest thing that is actually Deepholt. You face a wall, you remove it, and the world is
> different and stays different.

**Result:** all seven by-hand outcomes walked through in one sitting (Derik). 248 automated tests
pass. Three decisions are still open (see the end).

---

## What got decided

Thirty-five decisions, D-045 to D-079. Grouped by the questions the brief asked:

**What a tile is.** A level is flat byte arrays in simulation, one per layer, and they are the
only truth ([D-047](../../docs/design-decisions.md), [D-048](../../docs/design-decisions.md)):
ground, top, and ore as a third array rather than a kind (D-052, D-054). Reads outside the data
return two sentinels, settled at 255 and 254 after a first try at 999/998 that didn't fit in a
byte (D-057 to D-059). Hand-made content is a text-grid prefab with an anchor marker, stored as
a `.tres` with a stable id (D-049 to D-056, D-060 to D-062).

**How the world reaches the screen.** A data texture read by a shader, not `TileMapLayer`
(D-046): one quad per level (D-063), one R8 texture per layer built through the reads (D-065),
art found through a per-layer table (D-064), layers painted in order (D-066), and tile `(x, y)`
covering pixels `16x` to `16x + 16` (D-067).

**Who may change a tile, and how anything learns it changed.** `World` is the only runtime
writer, by request signal: it re-checks, changes through `LevelTiles`, then announces (D-078).
The screen learns from the tile data, not from the dig (D-065). Dug ore is discarded until M1
(D-079).

**What an actor is.** A plain `Node2D`, not a physics body: a feet box colliding against tile
data one axis at a time, a stored depth, and movement by intent (D-068).

**How input reaches an actor.** An `InputHandler` in presentation, given its actor by the
spawner, polling held state every tick (D-069). Aim and facing: 4-way, with a dead zone,
hysteresis and movement as the fallback (D-073 to D-076).

**Whether digging is instant.** No. Already settled in the tuning appendix: digging takes time
while held. Progress belongs to the digging actor and resets on release or on a new target
(D-071, D-072). Reach is one tile, 4-way (D-073, D-074).

**The edge.** It stops an actor like rock; how it looks is deferred (D-070).

**An exception on record.** One fixed tool (`ToolData`, a stone pickaxe) stays in pre-alpha, a
deliberate, bounded exception to "no stubs" (D-077).

---

## What surprised

**The working agreement changed mid-slice.** Section D started under "no spoilers" and finished
under explicit modes (Self Coded, Educational Assistant, Agent), with nothing hidden. Sections
D and E ran mostly Self Coded, with the dig's tile-opening work as Educational Assistant and the
renderer step and the flicker fix in Agent mode.

**Several decisions were made in code first and recorded after.** D-068 (what an actor is) and
D-069 (how input reaches it) were written up once the code existed. The brief's "decide before
building" didn't hold for those two; it did for digging (D-071 onward), which was decided in
conversation first.

**The tests found real bugs, repeatedly**, most of them one line long and each capable of
breaking everything downstream:

- `get_level_by_depth` returned the still-`null` variable instead of the match: 52 failures
  from one line.
- `World.dig_tile` took one argument where `tile_dug` sent two.
- A `print` format string with two `%s` and one value.
- Signals emitted with one array where two or three arguments were declared, more than once.
- A target tile built from `facing` alone, so facing down always dug tile (0, 1).
- `_get_target_tile` sharing the actor's own `WorldPos` object and doubling its depth.
- A target-change reset that never fired, because `current_tile` was never assigned.

**GUT skips a test file that fails to parse, with only a warning.** It happened twice: after
`tile_center` moved and after `InputHandler.setup` gained a parameter, whole files silently
stopped running. "Passing" meant "the files that loaded passed".

**Godot shared state bit harder than expected:** a `WorldPos` is an object, so assigning it
shares it; a `QuadMesh` resource is shared between instances unless made local to the scene.

**Coverage was measurable without a tool.** Godot has none built in. Instrumenting a scratch
copy of the project put coverage at 84% midway through the slice, and the gap-filling pass took
it to 99.5%. The 6% file (`capability_dig.gd`) was where the `current_tile` bug lived.

**The x-axis flicker was the camera between pixels.** Capturing the game viewport at fractional
offsets showed only `x + 0.5` breaking the tile pattern (66 columns), where nearest sampling
lands on texel boundaries. Rounding the camera and snapping the viewport fixed it, measured.

**A brief miss.** NOW.md listed *whether digging is instant* as open, when the tuning appendix
and content schema had already settled it. That belonged under *Already settled*.

---

## What to do differently

1. **Run the whole suite after any rename or signature change**, and treat a GUT "Ignoring
   script" warning as a failure. A test file that can't load is the worst kind of green.
2. **Record a decision when it's made, not after the code.** If it's made in code, write the
   D-entry in the same sitting.
3. **Prefer typed signals and calls** (`signal.emit(a, b)`, `signal.connect(f)`) over
   `emit_signal("name", [a, b])`. Most of the argument-count bugs above would have been caught
   at parse time, or never written.
4. **Keep a single owner for every rule.** "Diggable" ended up in four places before being
   pulled into `TileKind`; the agreement test now guards it.
5. **Check the docs for settled answers before writing a brief.** (Claude.)
6. **Be careful with search-and-replace across the repo.** One reached the vendored GUT addon
   and broke a line there.
7. **Branches in a shared working copy carry your next commits with them.** Two of Derik's
   commits landed on the test branch because it was checked out; nothing was lost, but it's
   easy to miss.

---

## Closed at the end of the slice

- **What can't be dug** is recorded as built ([D-080](../../docs/design-decisions.md)),
  including that the outermost ring of rock can be dug.
- **Dig time and hardness.** The placeholder speed (2.0, so 2.5 s on rock) was replaced with the
  documented tuning: the tool is a flint pickaxe at power 16, hardness belongs to tile kinds
  (rock 6, dirt 4, ore 1.5×), and the tuning appendix was rewritten to match
  ([D-081](../../docs/design-decisions.md)). Bare hands is power 8, for M1.
- **Still open from D-081:** the appendix's numbers miss the 0.5–0.7 s band at −5 and −7; to be
  resolved when those strata are built.
