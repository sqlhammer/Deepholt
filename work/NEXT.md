# Next

Sketches, not commitments. Slice 002 is done ([log](./log/002-go-down.md)) and 003 is in
progress. 004 was decided during 003; the order past it should fall out of what 003 and 004
teach. Cheap to throw away; expect them to change.

---

## 003 — It persists

Save a dug world, quit, reload, and your corridor is still there, on every level, with the ladder
and the spawn where they were.

Moved ahead of the dark, which was 003 in the last sketch. Slice 002 roughly doubled the state a
save has to hold: fixtures and their ids, the id counter, the world spawn, each level's shape. The
dark would add a persistent "remembered" bit per tile ([D-033](../docs/design-decisions.md)).
Every slice that adds state before saves exist adds a retrofit, and the save notes below have
been piling up since slice 002's generation discussion. Better to settle the format while there
is still little to put in it. It's also the first time excavation survives a session, which is
the first time it feels like tenancy rather than a sandbox.

## 004 — A world you can hold

Press F6 and the whole mountain is swapped for the saved one in a single move. A damaged save
leaves the running world exactly as it was, and ids carry on from where the world left them.

Inserted ahead of the dark after the slice 003 review, where every save/load bug traced back to
one assumption: that the tree holds exactly one world. Its shape is already decided
([D-118](../docs/design-decisions.md#d-118--the-world-is-a-node-that-owns-its-levels-and-id-counters-handed-by-reference)):
the world becomes a node that owns its levels and its id counters, and is handed to whatever needs
it by reference, never looked up. It's mostly a change of shape, so most of what can be checked by
hand is how a load behaves. That is the slice's playable edge, and it should be stated plainly in
the brief rather than padded out. Fuller than a sketch, because the decisions came first; it
becomes `NOW.md` when 003 closes.

**What should be true when you stop** (by hand, unless marked):
- Dig on two levels, F5, dig more, F6: the screen, F3 and every level show the saved world, and
  nothing of the replaced one.
- F6 on a truncated save: nothing changes. Not the screen, not F3, not the ids.
- F3 shows the running world, and its next fixture id and next actor id. Loading twice in a row
  shows the same numbers both times. They don't restart, and they don't climb.
- The ramp, the hole and the ladder still work both ways; digs stay on their own level.
- *Automated:* two worlds in one process, at the same depths, each with an actor. A dig, a depth
  change and a fixture placed in one leave the other untouched.
- *Automated:* generating a second world doesn't change the first world's counters.
- *Automated:* freeing a world leaves no orphan nodes. No code in `src/` searches the tree for
  levels.

**Already settled:**
- The world's shape, the counters, the gatekeepers on the instance, helpers that hold no state
  made static, recipes kept global, two worlds possible (D-118).
- One front door per kind of change: tiles
  ([D-078](../docs/design-decisions.md#d-078--world-is-the-only-thing-that-changes-tiles-at-runtime)),
  fixtures ([D-090](../docs/design-decisions.md#d-090--objects-get-their-own-gatekeeper-separate-from-world)).
- Simulation takes what it acts on as a parameter
  ([D-045](../docs/design-decisions.md#d-045--no-player-singleton-carves-out-the-presentation-layer)).
- An actor is handed its starting level
  ([D-117](../docs/design-decisions.md#d-117--an-actor-is-handed-the-level-it-starts-on-depth-changes-still-look-theirs-up)).
  This slice replaces its remaining lookup on a depth change.
- Every level stays resident
  ([D-035](../docs/design-decisions.md#d-035--no-tile-streaming-system-the-whole-world-stays-resident)).

**What you'll be deciding:**
- **How each consumer gets the world.** A field set on the actor at setup, a reference on each
  level (`level.world`), through the view for the renderers, or a mix.
- **What a gatekeeper is now.** Methods on the world node, signals on it, or child nodes under it
  (a tile gate and a fixture gate). And how a capability that emits today (`dig_requested`) reaches
  it.
- **What's left of the `World` and `Objects` autoloads.** Deleted, or reduced to recipes and the
  static helpers, and under what names.
- **Who builds a world.** `LevelGenerator` returning a world, `SaveGame` returning a world, and who
  swaps it in and re-points the view, renderers, input and F3.
- **Where the world node sits in the scene,** and what that does to coordinates (trap below).

**Traps:**
- **The name `World` is taken.** An autoload's name shadows a `class_name` of the same name, so a
  world node class called `World` can't coexist with the autoload. Rename one first, on purpose.
- **Lookups creep back in.** `get_parent()`, `owner`, `get_first_node_in_group`: each is a tree
  search in disguise, and each works fine until there are two worlds.
- **Signals on a replaced world.** Godot drops a node's connections when it is freed, so anything
  connected to the old world's gatekeepers goes silent after a swap. A swap has to re-point the
  listeners, and a test has to prove it.
- **Freeing during a callback.** The F6 handler already frees itself mid-`_input` (review bug 8).
  A swap started from input should be deferred to the end of the frame.
- **Coordinates only line up by accident.** `$Levels` sits under the game root, and actors sit
  inside `GameViewport`. `actor.position` is passed as a global position into `level.to_local`,
  which is only correct because every transform between them is the identity. Moving the levels
  under a world node keeps that true only if the world node is at the origin too.
- **Test churn.** Most tests put levels in the tree and rely on the lookup. Expect a large,
  mechanical change; grep the run for `Ignoring` and `Parse Error` (GUT skips files that fail to
  parse).
- **Taken from 003** (trimmed 2026-10-30; the
  [003 checklist](./CHECKLIST.md#moved-to-slice-004-d-118) has the detail). These were part of
  003's job, and this slice must deliver them:
  - Continue builds the world from the save, rather than generating and overlaying.
  - A loaded level is built from its saved bound, which fixes the level lost when a radius changes
    (review bug 4).
  - `is_in_bounds` reads the level's own bound.
  - Both id counters are saved, restored and in the header, with a test that after a load the next
    fixture id is greater than every loaded one.
  - The actor id counter gets its real home. 003 gives it a temporary one, which gets redone
    here.

## 005 — The dark

Dark vision, a light radius, and rock you cannot see past. The first half of *the dark is home,
the sun is the hazard* (pillar [P3](../docs/game-overview.md)) — inverted from the genre default.

Changes what "readable" means: slice 001 made rock and floor distinguishable, slice 002 added
holes, ramps and ladder tops that have to read at a glance, and this one takes most of the screen
away and asks again. Tunnel memory's remembered bit is persistent, so it lands in a save format
that already exists. Likely the first slice where the render route from 001 (D-046) either holds
up or gets replaced.

## 006 — Dig your own way down

Breach a floor to make a hole, and build a ladder in it. The first runtime use of the `Objects`
gatekeeper (it has only ever placed things during generation), and the first of the vertical
logistics ladder you build rather than find ([vertical-logistics §2](../docs/systems/vertical-logistics-and-power.md)).
Breaching is the M1 verb and the one hard tool gate on descent
([digging-and-structure §1](../docs/systems/digging-and-structure.md)); building needs at least a
placement mode. Probably too big as one slice; the split should fall out of 003 and 005.

---

### Save notes (for 003)

From slice 002's level-generation discussion (2026-10-11) and what 002 built:

- **Save the result, not the recipe.** Store the tiles (about 3 MB uncompressed for the whole
  mountain, world-runtime §1). Regenerating from seed + recipe and replaying digs means any later
  change to a recipe or prefab silently changes old worlds. Recipes matter only at new-game time.
- **Save each level's `LevelBound` with it,** so loading never needs a recipe (D-085).
- **Tile kind ids and fixture kind ids are forever;** a save is numbers of both (trap 8, D-104).
- **Save the fixtures, their ids, and `Objects`' id counter,** so ids stay unique after a load
  (D-104). The world spawn is a fixture, so it is saved like any other.
- **Save seeds as numbers, not strings.** `hash()` isn't promised stable across Godot versions.
- **Version the format from the first save,** and record `tuning_profile_id`
  ([D-037](../docs/design-decisions.md): one swappable resource for every tuning number, named in
  each save so playtest feedback is traceable). Not built yet; decide in 003 whether to build it.
- **Don't save derived data** — support, light, chambers are recomputed on load
  ([world-runtime §3](../docs/tech/world-runtime-and-persistence.md)).
- **Where actors are is saved;** where they *spawn* is only used for new players and deaths
  (D-091).

---

Still unplaced and eventually required: the support rule — excavated space has to be held up or it
fails (pillar [P4](../docs/game-overview.md)) — the rate machine that lets a hoist
haul while you are three levels away, procgen beyond the recipe's fixed placements (D-084's rules
and tags). None of them are next.

---

## Deferred from 002

- **Level-change transitions** ([D-108](../docs/design-decisions.md)). Ramps and ladders are
  instant for now; a transition time and visual effects are wanted later. It goes between the
  request and `Actor.change_depth`, not into the `Ramp` or `Ladder` rules, and must say what a held
  dig does during it.
- **Moving a fixture** (a bed, M6). Discussed in 002, not recorded: make `Fixture.tile` read-only,
  move through the store and the gatekeeper, and decide whether a move is announced as a removal
  plus a placement or as its own event.
- **Up or down when both apply on a ladder** (D-106, not decided). Needs side-by-side shafts and
  −3.

## Carry-forward

Found during slices 001 and 002, not recorded anywhere else. Bring into planning; none of it is
decided.

- **Hardness is still called `density` in code** (`TileKind.MINABLE_DENSITY`). Renaming it to
  match the tuning appendix is an optional tidy-up (D-081).
- **The appendix's own numbers miss the 0.5–0.7 s band at −5 and −7** (D-081, open). The content
  validator that would catch this ([content-schema §5](../docs/tech/content-schema.md)) isn't
  built.
- **`dig_refused` and `Objects.request_refused` carry reasons that nothing reads yet.** They're
  there for feedback (sound, UI) when that arrives.
- **The test suite is slow because of `test_game.gd`.** Each of its tests loads `game.tscn`, which
  builds all eight levels; the read-only tests could share one game in `before_all`.
- **`LevelFixtures.add` accepts the same fixture twice.** A one-line guard would make it an error.
- **`F3`'s tile window prints a hole as `.`** (the readout names it).
- **The temporary hole at (0, 2) in `surface_start`** is kept on purpose; take it out when it has
  served its purpose.
- **Coverage at the end of slice 002: 98.9%** (`python scripts/coverage.py`).
