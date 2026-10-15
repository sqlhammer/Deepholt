# Slice 002 checklist

Working list for [NOW.md](./NOW.md). Ordered so something is on screen early, not by code
dependency: a debug key changes depth before ramps or ladders exist, so *what follows a depth
change* is settled and visible before *what a ramp or ladder is*. **Decide** items are forks to
talk through before building past them; each outcome becomes a `D-nnn`. Numbers in brackets are
the brief's by-hand outcomes.

Slice 001's checklist is in git history (last at `29daf8f`).

## A. Three levels on disk

*Mode: ask before starting.*

- [x] **Decide:** which levels, and where the actor starts.
  Surface (start, unchanged), ramp to −1, ladder to −2; the ramp is not an object
  ([D-083](../docs/design-decisions.md)).
- [x] **Decide:** where a depth's prefab is named (replaces `game.gd`'s `if _depth == 0`).
  A level generator, driven by a `LevelRecipe` per depth ([D-084](../docs/design-decisions.md)).
- [x] **Decide:** whether a recipe absorbs `LevelBound`. It contains one; bounds stay their own
  type so saves never need a recipe ([D-085](../docs/design-decisions.md)).
- [x] **Decide:** how recipes are stored and found by depth. One table resource, mirroring
  `LevelBoundTable` ([D-086](../docs/design-decisions.md)).
- [x] Test: each recipe row's depth matches its position in the table (D-086).
  `test_level_recipes.gd`; rows are found by depth ([D-088](../docs/design-decisions.md)).
- [x] Recipes replace `level_bounds.tres` as the per-depth list; `World` and `Level` read bounds
  through them. `World.level_recipes` (`level_recipes.tres`); `LevelBoundTable` is gone (Agent mode).
- [x] Ramp kinds get explicit, never-reused ids; the hole is the existing ground `HOLE` (5), and
  the ladder is an object, so it gets a stable object type id instead (trap 8,
  [D-089](../docs/design-decisions.md)). Every existing id is pinned by a test
  (`test_tile_kind.gd`); `ObjectKind.OBJECT.LADDER` is 1. **Ramp ids wait for section C**,
  because the ramp's shape (one kind or a pair) is still open.
- [x] The generator draws randomness only from a `RandomNumberGenerator` seeded per level (trap 8).
  `LevelGenerator.rng_for(level)`; nothing draws from it until rules exist.
- [x] `LevelGenerator` builds every level from its recipe's fixed placements; `game.gd` calls it.
  Placements are `PrefabPlacement` (prefab id + anchor) on `LevelRecipe.fixed_placements`.
- [x] Test: a recipe naming a missing prefab id fails loudly. (`test_level_generator.gd`)
- [x] **Decide (optional):** finish dirt — grid character, art cell, `F3` character — or leave it.
  Finished, and the Surface start prefab is dirt (Agent mode, [D-087](../docs/design-decisions.md)).
- [x] Author −1's prefab: its hand-made layout, open floor where the ramp will land, and an open
  corridor from where the ladder will be out to the edge in one direction (trap 7).
  `rootshelf_home` (Agent mode): a dirt cave under the Surface's start room, a ladder room at
  x 12–16, y −2–2, and a corridor east along y = 0 to the edge at x = 64.
- [x] Author −2's prefab: its own layout, the same corridor direction, reaching further to its
  own edge. `greyseam_landing`: the same ladder room, the corridor on to x = 81, a small chamber
  at x ≈ 64 where −1's corridor ended, and a copper-veined cavern around the origin.
  **The ladder goes at (14, −2)** on both levels: hole on −1, ladder on −2.
- [x] **Decide:** where a level's spawn point comes from. A spawn-point object, placed at new-game
  time on a random passable tile within the recipe's radius of the start placement
  ([D-091](../docs/design-decisions.md)).
- [x] Both load by id through the registry and stamp into their levels; the Surface still does.
  Placed by the −1 and −2 recipes at anchor (0, 0); pinned in `test_hand_made_levels.gd`.
- [x] The actor still spawns on the Surface; `test_game.gd`'s spawn tests still pass unchanged.

## B. Changing depth, before ramps and ladders

*Mode: Agent.*

A throwaway debug key (like slice 001's `debug_pan.gd`) moves the locally controlled actor one
depth up or down. It exists to put a depth change on screen and is deleted once the ramp and
ladder work.

- [x] **Decide:** who changes an actor's depth, and how anything else learns it did. One path,
  which the ramp and the ladder will both ask for (D-083). The actor, by
  `change_depth(target)`; announced through `actor_worldpos_changed` ([D-093](../docs/design-decisions.md)).
- [x] **Decide:** where the shown depth lives, and what follows it (trap 1). A presentation
  `View` that follows the local actor ([D-094](../docs/design-decisions.md)).
- [x] Debug key changes the actor's depth; the screen redraws the new level around the same
  `(x, y)`. `-` down, `=` up (`src/debug/debug_depth.gd`); a blocked landing is refused and says
  so in `F3`. Working by hand (Derik).
- [x] `F3` shows the actor's depth and the shown depth, separately. [7] ("Shown depth" section)
- [x] Test: changing an actor's depth keeps its `x` and `y` (trap 3). (`test_depth_change.gd`)
- [x] Test: the screen follows the locally controlled actor's depth, and not another actor's.
- [x] Actors not on the shown depth are not drawn (trap 2). `View.track`.
- [x] Test: an actor on another depth is hidden, and shown again when the view moves to its depth.
- [x] `QuadMesh` made local to the scene, or created per renderer (trap 6). Local to scene.
- [x] Measure the hitch on a depth change at Surface, −1 and −2. Record the numbers; decide
  whether it's felt. **Headless, `show_level`: Surface ≈ 750 ms, −1 ≈ 400 ms, −2 ≈ 680 ms** —
  8× D-065's 92 ms. Cause: every tile read builds a `WorldPos` and asks `World.is_in_bounds`,
  which now searches the recipe table (D-088). Also a latent bug there: `LevelTiles` ignores its
  own `level_bound` and checks `World`'s radius for its depth.
- [x] Fix the read path: `LevelTiles` checks bounds against its own `level_bound`, squared, with
  no allocation and no lookup (Agent mode). **Re-measured: Surface ≈ 90 ms, −1 ≈ 47 ms,
  −2 ≈ 76 ms, the Crush ≈ 490 ms**, back to D-065's numbers. Fixing it exposed a loader test
  that read outside its own radius-1 level; it now uses radius 2.
- [x] **Decide, by hand:** is a 50–90 ms pause on a depth change felt? If so, a bulk read for
  building textures is D-065's documented fix. Not noticeable (Derik); no bulk read.
- [x] Dig, debug-key down, dig, debug-key back up: each level kept its own dig. [4, without the
  ramp and ladder] By hand (Derik).
- [x] Test: a dig on one depth changes only that depth's tiles.

## C. The ramp

*Mode: Agent.*

- [x] **Decide:** what a ramp is in the tile data — one kind or a top/bottom pair, one tile or
  several, directional or not — and whether it's meant to become a cave mouth. A directional pair
  of ground kinds, one tile each; a cave mouth is a prefab around one ([D-095](../docs/design-decisions.md)).
- [x] **Decide:** how an actor uses it — walk-on or interact — and how arrival avoids the bounce
  (trap 5). Walk-on; the direction stops the bounce (D-095).
- [x] **Decide:** whether a ramp tile is passable and whether it's diggable (trap 4). Passable,
  not diggable: it's ground under an `OPEN` top (D-095).
- [x] Eight ground ids, interleaved by pair (`RAMP_DOWN_N` 6, `RAMP_UP_N` 7 … `RAMP_UP_W` 13),
  pinned by the ids test; grid letters `n e s w` (down) and `N E S W` (up) ([D-096](../docs/design-decisions.md)).
- [x] **Decide:** exactly when walking onto a ramp counts, and where the Surface ramp goes.
  Tile changes onto it with the movement's dominant axis downhill (down end) or uphill (up end);
  facing plays no part ([D-097](../docs/design-decisions.md)); the actual movement this
  tick, not the intent ([D-098](../docs/design-decisions.md)). Surface ramp at (6, 0), going east (D-096).
- [x] The ramp is authored into the Surface and −1 prefabs at the same world `(x, y)`, within −1's
  radius. `e` at (6, 0) in `surface_start`, `E` at (6, 0) in `rootshelf_home`.
- [x] Art: recognizable at a glance as a way down. [1] Eight cells, shading dark downhill, with a
  chevron pointing the way the end takes you. Checked in the running game (Derik).
- [x] `F3` names it: the readout's ground line (`RAMP_DOWN_E`), and its letter in the tile window.
- [x] A ramp whose ends don't line up, that falls outside either level's bounds, or whose landing
  isn't passable fails to load, checked on world tiles after stamping (trap 4).
- [x] Test: each of those load failures. `LevelGenerator.ramp_problems`, reported with
  `push_error` after every level is built; the levels still load (`test_ramps.gd`).
- [x] Take the ramp down: −1's layout, same `(x, y)`, depth −1. Take it back up. [2] By hand (Derik).
- [x] Walk at the ramp from the wrong side: it stops you like a wall (D-099). [6] By hand (Derik).
- [x] Test: no bounce — arriving by ramp doesn't send the actor straight back.
- [x] A ramp end's other three sides stop an actor like a wall; only its one open side can be
  crossed, in or out ([D-099](../docs/design-decisions.md)). Arriving by ramp stands the actor at
  the ramp tile's center, so its feet never straddle a closed side.

## D. Holes, objects and the ladder

*Mode: Educational Assistant* (holes) — lessons in `work/lesson/D-00-index.md` onward. The rest
*Agent*, on branch `slice-002-fixtures-and-ladder` (2026-10-15).

- [x] **Decide:** what a ladder is in the data. An object on the lower level, under a hole
  (ground `HOLE`) on the level above; a hole with no ladder is dead
  ([D-089](../docs/design-decisions.md)).
- [x] **Decide:** who may change objects. Their own gatekeeper, not `World`
  ([D-090](../docs/design-decisions.md)).
- [x] Passability reads ground: a `HOLE` can't be walked onto (trap 4). `TileKind.is_passable`
  (Derik), used by `TileCollision`.
- [x] Test: an actor can't walk onto a hole, from any side. (`test_holes.gd`)
- [x] Art: a hole cell for ground `HOLE`; `F3` names it. The readout says `ground HOLE`; the tile
  window still prints a hole as `.`.
- [x] Fix: `h` under a solid or unmentioned top is rejected (Derik).
- [x] The temporary `h` at (0, 2) in `surface_start` is kept on purpose (Derik); the `F3` test
  expects it.
- [x] **Decide:** the gatekeeper's name and form. An `Objects` autoload ([D-100](../docs/design-decisions.md)).
- [x] **Decide:** the per-level store. `LevelFixtures` on each `Level`, by tile, several per tile;
  a `Fixture` is plain data ([D-103](../docs/design-decisions.md)).
- [x] **Decide:** how a ladder is authored. A fourth prefab grid, `objects` (D-100), sparse and
  exempt from the alignment rule ([D-102](../docs/design-decisions.md)).
- [x] **Decide:** which side answers "is this climbable?". A `Ladder` rule (D-100).
- [x] **Decide:** the hole's ground grid character. `h` (Derik, 2026-10-12).
- [x] **Decide:** names, signals, refusal reasons, conflicts, ids, how `stamp` reaches the store
  ([D-103](../docs/design-decisions.md), [D-104](../docs/design-decisions.md)).
- [x] `Fixture` and `LevelFixtures`; every change announced as `fixture_changed` (`test_level_fixtures.gd`).
- [x] The `Objects` gatekeeper: request and outcome signals, `placement_problem`, the conflict
  table, `next_id()` (`test_objects.gd`).
- [x] Prefabs' `objects` grid; `stamp(..., fixtures)` places fixtures (`test_level_grid_loader.gd`).
- [x] Presentation draws fixtures for the shown depth only (`FixtureRenderer`, `test_fixture_renderer.gd`).
- [x] Test: an object on a depth that isn't shown isn't drawn.

### D. Spawn points, the first object (D-091)

- [x] `PrefabPlacement.spawn_radius` (0 = none; `surface_start` has 8) ([D-092](../docs/design-decisions.md)).
- [x] `ObjectKind.OBJECT.WORLD_SPAWN = 2`, pinned by the ids test (D-092).
- [x] Remove `Level.anchor` and `setup`'s `prefab`/`anchor` parameters; tests stamp through the
  loader or the generator (D-092).
- [x] The generator places the world's default spawn: a disc of the radius, passable, not a ramp,
  allowed by the fixture rules; row-then-column, one RNG per level ([D-105](../docs/design-decisions.md)).
- [x] Test: the same world seed gives the same spawn; never on a blocked tile, a hole or a ramp;
  no candidate fails loudly (`test_world_spawn.gd`).
- [x] An actor's spawn is its own spawn point if it has one, else the world default (`Spawning`).
- [x] Spreading out: a ring search for a passable tile no actor's feet box is in.
- [x] Test: two actors spawned together don't overlap (`test_spawning.gd`, `test_game.gd`).
- [x] `F3` shows the world spawn (D-105: only that one).
- [x] The player spawns at the world default; `test_game.gd`'s spawn tests follow it.

### D. The ladder

- [x] Art: the ladder sprite, 16 × 24 (D-105). [3] Not yet seen in the running game.
- [x] The hole is authored into −1 and the ladder placed on −2, at (14, −2).
- [x] A ladder with no hole directly above it, or outside the upper level's bounds, is reported at
  load (`LevelGenerator.ladder_problems`).
- [x] Test: each of those load failures; and a hole with no ladder loads fine.

## E. Climbing

*Mode: Agent*, on branch `slice-002-fixtures-and-ladder`.

- [x] **Decide:** how an actor uses a ladder. Interact (`E` / A): facing the hole from above,
  standing on the ladder below ([D-101](../docs/design-decisions.md)).
- [x] **Decide:** which tile beside the hole climbing up arrives on. The faced side if open, else
  the first open neighbor N, E, S, W (D-101).
- [x] An `interact` action (`E`, gamepad A), polled on the physics tick ([D-106](../docs/design-decisions.md)).
- [x] Test: climbing down needs a ladder beneath the hole; a bare hole refuses (`test_ladder.gd`).
- [x] Test: a ramp or climb is refused when the landing has been closed since load
  (`test_ramps.gd`, `test_climbing.gd`).
- [x] Test: a dig in progress resets on a depth change (`test_capability_dig.gd`).
- [x] Test: every level of the slice is reachable on foot (`test_hand_made_levels.gd`).
- [x] Delete the section B debug key.
- [ ] By hand: use the ladder from beside the hole and arrive on −2 at (14, −2), `F3` agreeing. [3]
- [ ] By hand: climb up and arrive beside the hole, on open floor. [3]
- [ ] By hand: climb back up. The corridor dug on −1 before going down is still there; up the
  ramp, the Surface's dig is too. [4]
- [ ] By hand: interact where there's no ladder, or facing away, does nothing. [6]
- [ ] **Decide, by looking:** what a held dig button does on arrival (the dig restarts, but you
  start digging what you face).
- [ ] **Decide, by looking:** whether climbing is instant, and if not, how long it takes. Same
  question for the ramp.

## F. Wider

*Mode: ask before starting.*

- [ ] Walk the corridor to the edge on −1; note `x`. Climb down; walk the same corridor; you get
  further, and `F3`'s `x` says how much. [5]

## G. Done

- [ ] Quit and relaunch: all three levels are back to their hand-made state. [8]
- [ ] `scripts/test.ps1` passes, with no "Ignoring script" warnings.
- [ ] `python scripts/coverage.py` run; uncovered lines looked at.
- [ ] By hand: outcomes 1–8 walked through in one sitting.
- [ ] Claude drafts `log/002-go-down.md`; Derik corrects it.
- [ ] Claude re-sketches [NEXT.md](./NEXT.md).

## Optional, if it starts to hurt

- [ ] `test_game.gd` loads `game.tscn` per test and builds all eight levels; section B adds more
  of these. The read-only tests could share one game in `before_all`.
