# Slice 002 — Go down

> Three hand-made levels: the Surface, a ramp down to −1, a ladder down to −2, and −2 visibly
> wider than −1. You descend and the world changes around you while your `(x, y)` does not.

## Mode

Asked before each checklist section starts, and recorded there. Not carried over from
slice 001.

## Where we are

Slice 001 is done ([log](./log/001-dig-one-tile.md)). One moleperson walks and digs on a
hand-made Surface, and keeps starting there ([D-083](../docs/design-decisions.md)). `World` is the only runtime writer of tiles, by request signal
([D-078](../docs/design-decisions.md)), and the screen learns about changes from the tile data,
not from the dig ([D-065](../docs/design-decisions.md)).

**All eight levels already exist.** `game.gd` spawns one `Level` per row of
`level_bounds.tres` under `$Levels`, every one at the scene origin. Only Surface has a prefab.
The other seven are solid default rock out to their radius. Nothing has ever stood on them.

**Changing depth already has its pieces, and none have been used.**
- `Actor.depth` is a setter: it looks up the new level and points collision at it. Position is
  untouched, so `(x, y)` is kept for free.
- `LevelRenderer.show_level` disconnects from the old level's tiles and builds the new one's
  textures.
- `CapabilityDig` resets when the target tile changes, and `WorldPos.equals` compares depth, so a
  dig in progress should reset on a depth change ([D-072](../docs/design-decisions.md)).

What's missing is everything that *asks* for a depth change, and everything that has to follow
one: the screen, the camera, `F3`, and whatever else is drawn.

Radii as built (`level_bounds.tres`): Surface 90, −1 Rootshelf 64, −2 Greyseam 81. So −2 is
already wider than −1 in the data. Nothing on screen shows it.

## What should be true when you stop

By hand, in a running game (levels and start per [D-083](../docs/design-decisions.md)):

1. Launch, and you are on the hand-made Surface, as now. A ramp down is in the level, and you
   can tell at a glance it's a way down, not rock or floor.
2. Take the ramp. You are on −1: its hand-made layout, the same `(x, y)` in `F3`, depth −1. Take
   it back up and you're on the Surface where you left.
3. On −1, a hole in the floor, which you can't walk onto. A ladder stands beneath it on −2,
   recognizable at a glance. Use it from beside the hole. You are on −2, standing at the ladder:
   −2's hand-made layout, the hole's `(x, y)`, depth −2. Climbing back up puts you beside the
   hole, not in it ([D-089](../docs/design-decisions.md)).
4. Dig on −2. The tile opens on −2. Climb back up: the corridor you dug on −1 before going down
   is still dug, and nothing you dug on −2 shows up on −1. Go up the ramp: a tile you dug on the
   Surface at the start is still dug too.
5. Walk out from the ladder in one direction on −1 until the edge stops you. Do the same on −2
   from the foot of the ladder. On −2 you get noticeably further, and `F3`'s `x` says how much.
6. Try to use the ladder from where there is no ladder, or from the wrong side of it, and walk
   at the ramp from the wrong side. Something deliberate happens. Not a crash, and not a silent
   depth change.
7. `F3` tells you both what depth the actor is on and what depth the screen is showing. When
   they disagree you can see it.
8. Quit, relaunch. All three levels are back to their hand-made state. Nothing persists yet, and
   that is correct.

Separately, automated, without a running scene where possible:
- an actor changing depth keeps its `(x, y)`;
- a ramp whose two ends don't line up across the levels fails to load, and so does a ladder
  with no hole directly above it;
- a hole with no ladder beneath it can't be walked onto or travelled through;
- a dig on one depth changes only that depth's tiles;
- the screen follows the locally controlled actor's depth, and **not** another actor's;
- an actor on a depth that isn't being shown is not drawn.

## What you're deciding

- **What a ramp is in the data, and how an actor uses it.** Not an object
  ([D-083](../docs/design-decisions.md)), so it's part of the terrain: a top kind, or a pair of
  them (the top end on the Surface, the bottom end on −1). Open questions inside that:
  - **Does it have a direction?** A top-down ramp you walk *onto* probably goes down when
    entered from one side and is just floor (or a wall) from the others. A ramp that triggers
    from any side is simpler and odder.
  - **Walk-on or interact?** "Not an object" suggests walking: you go down a slope by walking.
    That's exactly where trap 5's bounce lives.
  - **Is the ramp more than one tile?** A one-tile ramp is a trapdoor with different art. Wider
    or longer reads more like a slope, and costs more alignment checking.
  - **Is it the cave mouth?** The design's Surface reaches −1 through cave mouths, built out in
    M4 ([pre-alpha-scope §2](../docs/pre-alpha-scope.md)). If it's meant to become a cave
    mouth, its shape now is the one M4 inherits, so it's worth sketching cave mouths first.
- ~~**What a ladder is in the data.**~~ Decided: an object on the lower level, under a hole
  (ground kind `HOLE`) on the level above. A hole with no ladder is a dead tile
  ([D-089](../docs/design-decisions.md)). Ladders are the first **objects**, so they bring the
  next fork with them.
- **Objects on a level.** They go through their own gatekeeper, not `World`
  ([D-090](../docs/design-decisions.md)). Still open:
  - **The gatekeeper:** its name, and whether it's an autoload (like `World`) or a node in the
    game scene.
  - **The per-level store:** keyed by `WorldPos`? One object per tile, or several? Does it live
    on `Level` next to `LevelTiles`? Whatever it is, it announces its own changes (D-065's
    pattern), and presentation draws from it.
  - **How objects are drawn:** sprites, not the tile shader. Drawn only for the shown depth
    (trap 2 applies to objects as much as to actors).
  - **How a ladder is authored:** prefabs are text grids of tiles. A ladder needs either an
    object grid or character in the prefab, or placement from the recipe
    ([D-084](../docs/design-decisions.md)).
  - **The seam:** the hole is a tile (`World`), and the ladder is an object (the new
    gatekeeper). "Is this climbable?" asks both. Decide which one answers it.
- **How an actor uses a ladder.** From above, the hole can't be stood on, so it's used from
  beside it: face it and interact, or walk into it? From below, standing on the ladder's tile, or
  facing it? Reach like digging ([D-073](../docs/design-decisions.md))? And going up, **which**
  tile beside the hole do you arrive on: the side you face, a fixed side set on the ladder, or
  the first open one? Gamepad interact is
  A ([ui-ux §3](../docs/ui-ux-and-controls.md)); the keyboard binding isn't set.
- **Whether climbing is instant.** A feel question, like digging was. The design says a ladder
  carries the player "slowly" ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md))
  and the first session has you "trudge back up the ladder twice. Feel it." Instant is a fine
  stepping stone. Decide the real answer by looking.
- **Who changes an actor's depth, and how anything else learns it did.** The actor can set its
  own depth today. The alternative mirrors tiles: a request to `World`, which checks the move is
  legal (a ramp or ladder here, open floor at the other end) and then announces it. Either way,
  the ramp and the ladder should both end in the **same** depth-change path
  ([D-083](../docs/design-decisions.md)); only what triggers it differs. Separately: an
  announcement on the actor (`depth_changed`) that presentation listens to. Keep *who may* and
  *who learns* apart, as with tiles.
- **Where "the depth being shown" lives.** There is no simulation-wide current depth, because
  nothing may own *the* player ([D-045](../docs/design-decisions.md)). The depth on screen is
  presentation state that follows the locally controlled actor. What holds it, and what tells
  the renderer, camera, `F3` and actor drawing to follow, is yours. `game.gd` currently wires
  the renderer once, at spawn.
- **Where a depth's prefab is named.** `game.gd` hard-codes `if _depth == 0: surface_start`. With
  three prefabs that becomes a table: on the `LevelBound` rows, a separate resource, or a
  dictionary in `game.gd`.
- **What −1 and −2 are made of.** See *Already settled* on stone kinds. Optional: −1 Rootshelf
  is soft stone and root mats, and dirt is half added (diggable, with a hardness, but no grid
  character, no art cell and no `F3` character). Finish it here, or leave it.

## Already settled

- **The shared origin.** `(x, y)` at depth 3 is directly below `(x, y)` at depth 2, and that is
  non-negotiable ([world-runtime §2](../docs/tech/world-runtime-and-persistence.md),
  [world-and-generation §1](../docs/world-and-generation.md)). **Binds what a ladder is**:
  whatever you pick, its ends sit at the same `(x, y)`.
- **Residency.** Every level's tile data stays resident for the whole session; there is no
  streaming ([D-035](../docs/design-decisions.md)). Only the current depth's render quad needs
  to exist ([D-063](../docs/design-decisions.md)). **Binds** the sketch's "resident, loaded, or
  something else": resident data, one renderer re-pointed. A level being off screen is not a
  reason for its data to change or go away.
- **No player singleton** — simulation takes an actor as a parameter; presentation may hold the
  locally controlled one ([D-045](../docs/design-decisions.md)). **Binds** where the shown depth
  lives: not in `World`, not in `Global`.
- **A built renderer learns from the truth, with no history.** A renderer created or re-pointed
  on a depth change builds from that level's tile data ([D-065](../docs/design-decisions.md)).
  Digs that happened while a level was off screen need no replaying.
- **Deeper stone kinds wait for procgen.** Below the Surface, kinds are named when procedural
  generation introduces them in M3; until then the appendix's numbers are targets
  ([tuning-appendix §4](../docs/tuning-appendix.md), [D-081](../docs/design-decisions.md)).
  **Binds** what −1 and −2 are made of: the kinds that exist. So −2 digs exactly as fast as
  Surface. If that reads wrong once you're standing on it, it's a new `D-nnn`, not a quiet
  addition.
- **Levels and start:** Surface (where the actor starts), a ramp to −1, a ladder to −2. The ramp
  is not an object ([D-083](../docs/design-decisions.md)). **Binds** how many prefabs, and that
  the two connections share one depth-change path.
- **Breaching is not planned for this slice.** Breaching a floor is the M1 verb and the hard tool gate on
  descent ([digging-and-structure §1](../docs/systems/digging-and-structure.md),
  [D-012](../docs/design-decisions.md)). Here the ramp, the ladder and its hole are authored. Making a hole
  yourself, building a ladder, and the "can't climb above 150% load" rule
  ([D-030](../docs/design-decisions.md)) all need inventory or tools that don't exist yet.
  Designing ahead for them is welcome; building them is a scope call for this slice.
- **No rendering of the level below.** Open shafts showing a dimmed view of the level beneath is
  deferred ([D-011](../docs/design-decisions.md)). The hole draws as whatever its art says.
- **The edge stops an actor like rock** ([D-070](../docs/design-decisions.md)), and the
  outermost ring can be dug ([D-080](../docs/design-decisions.md)). Outcome 4 relies on both.
- [Source layout, naming, tabs, signals over direct calls](../docs/coding-standards.md). From
  the 001 log: typed `signal.emit(a, b)`, not `emit_signal("name", [a, b])`.

## Traps

### 1. A "current depth" that isn't attached to anyone

**The trap.** The quickest version is a `current_depth` on `World` (or `Global`), set when the
actor climbs and read by the renderer, `F3` and the camera. It works with one actor. It is a
player singleton with another name: the first time a second actor exists, on another depth,
"current" means nothing, and every reader has quietly assumed it means "the one I'm
controlling" ([D-045](../docs/design-decisions.md)'s smell test: "a function needing actor state
that takes no actor argument").

The quieter version is in presentation: the renderer listening to *every* actor's depth change.
Correct with one actor; with two, the screen flips whenever anyone climbs.

**What holds it.** The simulation never asks what depth is shown. Presentation follows one
specific actor, the one it was given at spawn ([D-069](../docs/design-decisions.md)), and only
that one. The automated check is a second actor changing depth while the screen stays put.

### 2. Actors on other depths are still drawn

**The trap.** Every actor is a child of `GameViewport/Actors`, whatever its depth. Today that's
one actor, so it's invisible. The moment anything else exists on another level (a test actor,
later a worker, a co-op partner), it draws on top of whatever level is shown, at its `(x, y)`,
standing in rock. That's the same failure as trap 1 from the other side: presentation has to
filter by the shown depth, not assume everyone is here.

### 3. Moving a level node breaks the shared origin

**The trap.** Every level sits at the scene origin, and that is load-bearing:
`World.get_worldpos_from_global_position` goes through `level.to_local()`, and the actor's
position is just pixels. Offsetting levels per depth, to stack them visually or to
lay them out side by side for debugging, makes the same pixel a different `(x, y)` on each
level. Climbing still "works", and you arrive in the wrong place, off by the offset.

Keep every `Level` at the origin. The test that catches it: change an actor's depth, and its
`current_WorldPos` keeps its `x` and `y`.

### 4. The ramp and ladder line up in the prefab, not in the world

**The trap.** A prefab is stamped at an anchor ([D-060](../docs/design-decisions.md)). Two
prefabs authored so a ramp or ladder sits at the same place relative to each grid's marker only line
up in the world if both are stamped at the same anchor. Check alignment on **world tiles after
stamping**, never on grid characters.

Related edges:
- each connection's `(x, y)` must be inside **both** levels' bounds. −1 is the narrowest of the
  three (radius 64), so it constrains both: the ramp has to sit within 64 of the axis even
  though the Surface goes out to 90, and a ladder at `x = 70` is fine on −2 (81) and outside −1;
- **passability now reads ground as well as top.** A hole is ground `HOLE` under an open top
  ([D-089](../docs/design-decisions.md)); checking only the top lets an actor walk straight
  onto it. And **a new top kind is a wall until passability learns about it.** Only `OPEN` is
  passable
  ([D-068](../docs/design-decisions.md)), an allowlist on purpose. Add a ramp or ladder kind and
  the actor can't step onto it. That's the allowlist working, not a bug; passability and
  diggability ([D-080](../docs/design-decisions.md)) each need a deliberate answer for every
  new kind;
- whatever is at the other end has to be passable. If it's rock, the actor arrives with its feet
  box inside rock, and `TileCollision.move_box` only checks the destination, so it may not be
  able to walk out. Fail the load if the landing isn't open, and re-check when the climb is
  requested, in case it's been changed since (the same reason `World` re-checks a dig,
  [D-078](../docs/design-decisions.md)).

### 5. Arriving on a ramp can send you straight back

**The trap.** If walking onto a ramp (or ladder) tile changes depth, you arrive standing on the
other end, which is also a trigger tile, and go back next tick. You bounce forever. Since the
ramp is not an object ([D-083](../docs/design-decisions.md)) and probably walk-on, this one is
live, not hypothetical. The fixes: trigger only on *entering* the tile, with arrival by depth
change not counting as entering; or arrive *beside* the other end rather than on it, which
gives up "your `(x, y)` doesn't change" for the ramp; or a direction, so the bottom end only
triggers when walked into from the downhill side. Interact-to-use doesn't have this problem.

A walk-on ramp has a second edge: the stick is still held on arrival, so the actor keeps
walking on −1 in the same direction. Fine if −1's layout expects it, a surprise if the landing
faces a wall.

The same family: interact and dig on the same button, or a dig held across a depth change. The
dig should reset ([D-072](../docs/design-decisions.md), since `WorldPos.equals` compares depth),
but `action_intent` stays held, so the actor starts digging the tile it faces on arrival.
Decide whether that's acceptable.

### 6. The renderer swap

- **The `QuadMesh` is a shared resource.** `show_level` resizes it in place. With one renderer
  re-pointed that's fine. If you make a second `LevelRenderer` from the same scene, it shares the
  mesh, and showing a level on one resizes the other. Tick *Local to Scene*, or create a new
  `QuadMesh` per renderer.
- **The hitch.** Building a level's textures through the reads costs about 92 ms at Surface
  (radius 90) and 580 ms at the Crush ([D-065](../docs/design-decisions.md)). At −1 and −2 it
  should be under 100 ms, but it lands on every climb. Measure it; whether it's felt is the
  question, and a bulk read is the documented fix.
- **The camera is fine for free.** It follows actor position, which doesn't change. Worth
  knowing so nothing gets "fixed" that isn't broken.

### 7. "Visibly wider" isn't visible

**The trap.** The view is about 32 × 20 tiles. −1 is 129 tiles across and −2 is 163, and both
default to solid rock right to the edge. (The Surface isn't in the comparison: at 90 it's wider
than both, so the trip down narrows the world before −2 widens it again.) You can't see either edge from the ladder, and you
can't reach it without digging 60-odd tiles. Outcome 4 only works if the prefabs are
**authored for it**: an open corridor from the ladder to the edge, in the same direction, on
both levels. On −2 it carries on past where −1's stopped. That's a content decision as much as a
code one, and it's cheap to get wrong by making the levels pretty and forgetting the comparison
they exist for.

### 8. Generation that won't survive a save

Saves are slice 004, but two things built in this slice decide whether they'll work.

- **Tile kind ids are forever.** A save stores `TileKind` values as bytes. Reorder or insert into
  a GDScript enum and every old save reads as the wrong kinds. The ramp and ladder kinds added in
  this slice are the first new ones since 001: give kinds explicit numbers, and never renumber or
  reuse one. Prefab ids are already stable ([D-061](../docs/design-decisions.md)).
- **Generation must be deterministic.** The generator ([D-084](../docs/design-decisions.md))
  should take a `RandomNumberGenerator` seeded from the level's seed, never the global `randi()`,
  and must not depend on node or dictionary iteration order. Also, `hash()`, which makes
  `world_seed` and `level_seed` today, isn't promised to give the same answer across Godot
  versions: save the resulting numbers, not the seed string. Fixed placements alone use no
  randomness, so this is invisible until rules arrive. That's why it's worth getting right now.

### 9. From the 001 log

GUT silently skips a test file that fails to parse. Changing `Actor.setup`'s signature, the
depth setter, or `show_level` will break callers in tests. Run the whole suite after any
signature change, and treat an "Ignoring script" warning as a failure.
