# Slice 001 checklist

Working list for [NOW.md](./NOW.md). Ordered so something is on screen early, not by code
dependency. **Decide** items are forks to talk through before building past them; each outcome
becomes a `D-nnn`. Numbers in brackets are the brief's by-hand outcomes.

## A. Tile data — no scene ✅

- [x] Ore is a third byte array alongside ground and top ([D-054](../docs/design-decisions.md)).
- [x] The kinds from [D-051](../docs/design-decisions.md) and [D-052](../docs/design-decisions.md) exist as a table.
- [x] A level's tile data can be created, written and read by coordinate, per [D-048](../docs/design-decisions.md).
- [x] Test: write a tile on each layer, read it back.
- [x] Reads outside the array return 255; inside the array but outside radial bounds return 254. No kind on any layer uses either ([D-057](../docs/design-decisions.md), [D-059](../docs/design-decisions.md)).
- [x] Test: reads past each edge of the array return 255, and a read in a corner outside the radius returns 254.

## B. Loading a grid

- [x] Grid characters per [D-056](../docs/design-decisions.md).
- [x] An unrecognised character fails the load ([D-055](../docs/design-decisions.md)). Ragged
  lines no longer do: a prefab covers only what it was authored to cover, and unmentioned tiles
  keep the level's default ([D-062](../docs/design-decisions.md), superseding that half of D-055).
- [x] Ore under anything but `#` fails the load ([D-056](../docs/design-decisions.md)) — where the
  top grid states the tile. Over a tile it never mentions, ore is legal, since the default is
  minable rock ([D-062](../docs/design-decisions.md)).
- [x] Test: unrecognised-character and ore-over-stated-non-minable each fail to load.
- [x] A prefab's layer grids stamp into level data, with the marker landing on the anchor rather than world `(0, 0)` ([D-060](../docs/design-decisions.md)).
- [x] Test: a small inline grid loads; spot-check tiles on all four sides of the anchor, including negative coordinates.
- [x] Test: for each grid, no anchor marker fails to load and two fail to load ([D-050](../docs/design-decisions.md), [D-053](../docs/design-decisions.md)).
- [x] Test: a prefab stamps at a non-zero anchor, and layers of different shapes align by their markers.
- [x] Prefabs are `.tres` resources with stable ids, indexed by a registry autoload ([D-061](../docs/design-decisions.md)).
- [x] Test: the authored prefab loads from disk by id and stamps into a level.
- [x] The slice's hand-made level file **is authored**.

## C. Pixels ✅

- [x] **Decide:** how tile data is encoded into textures ([D-065](../docs/design-decisions.md)).
  Includes how a changed tile reaches the screen, which section E's dig verb consumes.
- [x] **Decide:** how an id becomes pixels — atlas lookup, and combining ground and top.
  Atlas lookup ([D-064](../docs/design-decisions.md)); combining layers ([D-066](../docs/design-decisions.md)).
- [x] **Decide:** how much of a level one quad covers ([D-063](../docs/design-decisions.md)).
- [x] Placeholder atlas: rock ground, rock, copper.
- [x] Launch: the hand-made level is on screen, and rock, copper and open floor are distinguishable at a glance at the intended scale. [1]
- [x] Move the view across tiles and watch the edges, not just a still frame.
  Pan: arrow keys, WASD or left stick, Shift to hurry
  ([debug_pan.gd](../game/src/debug/debug_pan.gd), throwaway until section D's actor).

## D. An actor ✅

*Mode: Self Coded.*

- [x] **Decide:** what an actor is ([D-068](../docs/design-decisions.md)).
- [x] **Decide:** how input reaches an actor ([D-069](../docs/design-decisions.md)).
- [x] A moleperson stands in open space; keyboard and gamepad both move them. [2]
- [x] They cannot walk into rock or copper, and blocking is answered from tile data ([D-046](../docs/design-decisions.md)). [2]
- [x] `F3` shows the actor's position and the depth the world calls it. [6]
  The readout itself is built — coordinate, array index, the three layers by name, and an
  11 × 11 tile window in the prefab's own characters. It reports whatever position the actor
  has, so this lands the moment the actor stops returning a constant.
- [x] **Decide:** what happens at the edge of the level — after looking at a corner of the radial bounds at tile granularity.
  It stops the actor like rock; how the outside looks is deferred ([D-070](../docs/design-decisions.md)).

## E. Digging

*Mode: Self Coded.*

- [x] **Decide:** who may change a tile, and how anything else learns it changed. Before the dig verb exists.
  `World`, by request signal; the screen learns from `LevelTiles` ([D-078](../docs/design-decisions.md)).
  The screen's half is settled: it learns from the tile data, not from the dig verb
  ([D-065](../docs/design-decisions.md)).
- [ ] **Decide:** the rules for digging what cannot be dug.
- [ ] Test: changing a tile through the mutation path and reading it back.
- [ ] Test: each cannot-dig rule.
- [ ] Face rock or copper, press dig, and the tile becomes open floor on screen. [3]
- [x] **Decide:** whether digging is instant. No: a tile is dug by holding the button over time.
  Already settled in [tuning-appendix §4](../docs/tuning-appendix.md) (`dig_seconds = rock_hardness /
  tool_power`) and [content-schema §5](../docs/tech/content-schema.md) (the right tool digs in
  0.5–0.7 s). An instant dig is only a stepping stone while building.
- [ ] **Decide, by looking:** how long a dig takes in this slice, which has no tools yet.
- [ ] Dig a four-to-five tile corridor and walk down it; it stays dug. [4]
- [ ] Dig out to the edge of the level and walk to it; it does what section D decided, deliberately. [5]
  Moved here from D: Surface is solid rock out to its edge, so the edge can't be reached by hand
  until digging exists.


### E. TODOs from review (2026-10-07)

- [x] **The tile never opens.** On completion `CapabilityDig` emits `World.ore_mined` and resets,
  but nothing sets the top to `OPEN` or clears the ore ([D-066](../docs/design-decisions.md)).
  Unblocked by [D-078](../docs/design-decisions.md); dug ore is discarded until M1 ([D-079](../docs/design-decisions.md)).
  *Mode: Educational Assistant* — walkthrough in `work/lesson/E-open-a-dug-tile.md`.
  Steps 1–4 built by Derik; step 5 (the renderer) in Agent mode. Opens in the data and on
  screen; checking it by hand is outcome [3] below.
- [x] **Signal misnamed and missing its argument.** Declared `ore_mined(world_pos)`, emitted with
  nothing, and fires for plain rock too. Something like `tile_dug.emit(target_tile)`.
- [x] **Progress never resets on release or target change**
  ([D-071](../docs/design-decisions.md), [D-072](../docs/design-decisions.md)). `dig()` only runs
  while held, so it never learns of a release. The capability needs to remember its last target
  and get a `stop()` (or "not held this tick") call from the actor.
- [x] **Target-change reset never fires ([D-072](../docs/design-decisions.md)).** `dig()` resets
  only when `current_tile != null`, but nothing ever assigns `current_tile`, so it stays `null`.
  Release resets (via `action_ended`); moving to a new tile while holding doesn't.
  Fixed: `dig()` now records `current_tile` after the check, so the next tick compares against it.
- [x] **`tile_density` keeps its last value.** A kind not in `MINABLE_DENSITY` leaves the previous
  tile's density in place. Return the density instead of storing it.
- [x] **Hard-coded `2`/`3` in `_is_diggable`.** Use `TileKind.TOP.MINABLE_ROCK` etc.;
  `MINABLE_DENSITY` repeats the ids again.
- [x] **`print(progress)`** runs every tick.
- [ ] **Hardness per tile kind conflicts with a settled doc.**
  [tuning-appendix §4](../docs/tuning-appendix.md) makes hardness per stratum
  (`dig_seconds = rock_hardness / tool_power`); the code makes it per tile kind (rock 5,
  dirt 2). Same formula and timing (5 / 10 = 0.5 s). Either record a D-entry for the change or
  follow the doc's numbers.
- [x] **`ToolData` + `equipped` is the M1 tools system arriving early** — a stub
  [pre-alpha-scope §4](../docs/pre-alpha-scope.md) rules out. Either record that tools come into
  pre-alpha with this slice, or use a plain dig-speed number on the capability until M1.
  Kept as one fixed tool; tools are not expanded in pre-alpha ([D-077](../docs/design-decisions.md)).
- [x] `get_node("Capabilities/CapabilityDig")` errors when missing rather than returning `null`,
  so `if capability:` never helps. Use `get_node_or_null`, or look it up once in `_ready`.
- [x] `var aim` in `InputHandler` is untyped — add `: Vector2`.
- [x] `actor.tscn`'s root node is still in the `players` group.
- [x] **Facing ([D-075](../docs/design-decisions.md), [D-076](../docs/design-decisions.md)).**
  `Actor.facing` exists (starts down) but nothing uses it: the target is still worked out from the
  raw aim, so a zero aim targets the actor's own tile. Facing should be updated from aim when aim
  is outside the dead zone, otherwise from movement, otherwise kept; snapped 4-way with
  hysteresis (10–15° past 45°). The target tile is then feet tile + facing.
- [x] **Facing, remaining.** Facing state works (aim, else movement, else hold; the sprite
  follows), but:
  - `_primary_action` builds the target as `WorldPos.new(facing.x, facing.y, depth)`, which
    is an absolute tile (facing down always digs tile (0, 1)). Call `_get_target_tile()`,
    which adds facing to the feet tile;
  - no hysteresis yet: `_set_facing` switches at exactly 45°, so aiming near a diagonal flips
    the target and resets progress ([D-072](../docs/design-decisions.md)). Switch only
    10–15° past the boundary ([D-075](../docs/design-decisions.md)).
- [x] **`_get_target_tile` still doubles depth.** `target_tile.depth += current_WorldPos.depth`
  adds depth to a `WorldPos` that already has it. Hidden on Surface (0 + 0); wrong from depth 1.
- [x] **Mouse aim dead zone ([D-075](../docs/design-decisions.md)).** `_get_aim` returns the
  feet-to-mouse vector at any length; within about half a tile (8 px) of the feet it should
  return `Vector2.ZERO` so facing holds.
- [x] **`InputHandler` sits inside `GameViewport`, so `game.gd` pushes events into it.** Events
  are pushed untransformed, so any node in the viewport reading a mouse event's position gets
  a wrong one. The handler draws nothing; as a child of `Game` (outside the viewport) its
  `_input` fires directly and the `push_input` workaround can go.

## F. Done

- [x] Quit and relaunch: the level is back to its hand-made state. [7]
- [x] `scripts/test.ps1` passes.
- [x] By hand: outcomes 1–7 walked through in one sitting.
- [ ] Claude drafts `log/001-dig-one-tile.md`; Derik corrects it.

## Later: known bugs

Logged to fix later, not part of the current work.

- [x] **Pixel flickering when moving along the x axis** (reported 2026-10-10, recording:
  `C:\Users\derik\OneDrive\Documents\Snagit\2026-10-10_07-40-27.mp4`; frames
  `C:\Users\derik\Downloads\bad frame.png` and `good frame.png`).
  **Most likely cause, from the frames:** the bad frame has evenly spaced vertical stripes (a
  tile's dark border drawn doubled) across the screen; the good frame, at a slightly different
  camera x, has none. That pattern fits the camera sitting at a fractional x, which puts the
  viewport's pixel centers exactly on world-pixel boundaries where nearest sampling is a coin
  flip. Only x because walking horizontally leaves y whole. **Likely fix:** keep the camera on
  whole pixels (`position = actor.position.round()`, or *Snap 2D Transforms to Pixel*), and
  snap the actor's sprite too. **Confirmed and fixed (Agent mode):** captured the game viewport
  with the actor at x + 0, 0.25, 0.5 and 0.75: only the half-pixel offset broke the 16 px tile
  repeat (66 columns). `ViewCamera` now follows `actor.position.round()`, and `GameViewport`
  has `snap_2d_transforms_to_pixel` on; the same capture then shows 0 broken columns at every
  offset. Pinned by tests in `test_view_camera.gd`.
  Other places to look if that isn't it:
  - the actor moves in fractional pixels (85 px/s × delta), and the camera follows its exact
    position, so the whole world sits at a fractional offset inside the 512 × 320 viewport and
    rounds differently frame to frame. The project has no pixel-snap settings
    (Rendering → 2D → *Snap 2D Transforms to Pixel* / *Snap 2D Vertices to Pixel*);
  - the camera follows in `_process` while the actor moves in `_physics_process`, so the two
    can be a frame apart;
  - the upscale shader's one-screen-pixel blend at texel edges, at the non-integer window scale;
  - x only: vertical edges in the tile art (tile borders, the actor's outline) would show
    horizontal sub-pixel movement more than horizontal edges do.
