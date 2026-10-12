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
- [ ] Author −1's prefab: its hand-made layout, open floor where the ramp will land, and an open
  corridor from where the ladder will be out to the edge in one direction (trap 7).
- [ ] Author −2's prefab: its own layout, the same corridor direction, reaching further to its
  own edge.
- [x] **Decide:** where a level's spawn point comes from. A spawn-point object, placed at new-game
  time on a random passable tile within the recipe's radius of the start placement
  ([D-091](../docs/design-decisions.md)).
- [ ] Both load by id through the registry and stamp into their levels; the Surface still does.
- [ ] The actor still spawns on the Surface; `test_game.gd`'s spawn tests still pass unchanged.

## B. Changing depth, before ramps and ladders

*Mode: ask before starting.*

A throwaway debug key (like slice 001's `debug_pan.gd`) moves the locally controlled actor one
depth up or down. It exists to put a depth change on screen and is deleted once the ramp and
ladder work.

- [ ] **Decide:** who changes an actor's depth, and how anything else learns it did. One path,
  which the ramp and the ladder will both ask for (D-083).
- [ ] **Decide:** where the shown depth lives, and what follows it (trap 1).
- [ ] Debug key changes the actor's depth; the screen redraws the new level around the same
  `(x, y)`.
- [ ] `F3` shows the actor's depth and the shown depth, separately. [7]
- [ ] Test: changing an actor's depth keeps its `x` and `y` (trap 3).
- [ ] Test: the screen follows the locally controlled actor's depth, and not another actor's.
- [ ] Actors not on the shown depth are not drawn (trap 2).
- [ ] Test: an actor on another depth is hidden, and shown again when the view moves to its depth.
- [ ] `QuadMesh` made local to the scene, or created per renderer (trap 6).
- [ ] Measure the hitch on a depth change at Surface, −1 and −2. Record the numbers; decide
  whether it's felt.
- [ ] Dig, debug-key down, dig, debug-key back up: each level kept its own dig. [4, without the
  ramp and ladder]
- [ ] Test: a dig on one depth changes only that depth's tiles.

## C. The ramp

*Mode: ask before starting.*

- [ ] **Decide:** what a ramp is in the tile data — one kind or a top/bottom pair, one tile or
  several, directional or not — and whether it's meant to become a cave mouth.
- [ ] **Decide:** how an actor uses it — walk-on or interact — and how arrival avoids the bounce
  (trap 5).
- [ ] **Decide:** whether a ramp tile is passable and whether it's diggable (trap 4: a new kind
  is a wall and undiggable until decided otherwise).
- [ ] The ramp is authored into the Surface and −1 prefabs at the same world `(x, y)`, within −1's
  radius.
- [ ] Art: recognizable at a glance as a way down. [1]
- [ ] `F3` names it.
- [ ] A ramp whose ends don't line up, that falls outside either level's bounds, or whose landing
  isn't passable fails to load, checked on world tiles after stamping (trap 4).
- [ ] Test: each of those load failures.
- [ ] Take the ramp down: −1's layout, same `(x, y)`, depth −1. Take it back up. [2]
- [ ] Walk at the ramp from the wrong side: something deliberate happens. [6]
- [ ] Test: no bounce — arriving by ramp doesn't send the actor straight back.

## D. Holes, objects and the ladder

*Mode: ask before starting.*

- [x] **Decide:** what a ladder is in the data. An object on the lower level, under a hole
  (ground `HOLE`) on the level above; a hole with no ladder is dead
  ([D-089](../docs/design-decisions.md)).
- [x] **Decide:** who may change objects. Their own gatekeeper, not `World`
  ([D-090](../docs/design-decisions.md)).
- [ ] Passability reads ground: a `HOLE` can't be walked onto (trap 4).
- [ ] Test: an actor can't walk onto a hole, from any side.
- [ ] Art: a hole cell for ground `HOLE`; `F3` names it.
- [ ] **Decide:** the object gatekeeper's name, and autoload or scene node (D-090, open).
- [ ] **Decide:** the per-level object store: keyed how, one or many per tile, where it lives.
- [ ] **Decide:** how a ladder is authored: an object grid or character in the prefab, or
  placed by the recipe.
- [ ] **Decide:** which side answers "is this climbable?": the hole tile, the ladder object, or
  both.
- [ ] The object store announces changes; presentation draws objects for the shown depth only.
- [ ] Test: an object on a depth that isn't shown isn't drawn.

### D. Spawn points, the first object (D-091)

Built straight after the object store and gatekeeper above: the spawn point is the simplest
object (no sprite, no link across levels), so it settles the store's shape before the ladder.

- [ ] `PrefabPlacement.spawn_radius` (0 = none; `surface_start` has 8) ([D-092](../docs/design-decisions.md)).
- [ ] `ObjectKind.OBJECT.WORLD_SPAWN = 2`, pinned by the ids test (D-092).
- [ ] Remove `Level.anchor` and `setup`'s `prefab`/`anchor` parameters; tests stamp through the
  loader or the generator (D-092).
- [ ] The generator places the world's default spawn point: passable tiles within the radius, in
  row-then-column order, one picked with `rng_for`. No candidate fails loudly.
- [ ] Test: the same world seed gives the same spawn; the spawn is never on a blocked tile or a
  hole; an all-rock radius fails loudly.
- [ ] An actor's spawn is its own spawn point if it has one, else the world default.
- [ ] Spreading out: a ring search for a passable tile no actor's feet box is in.
- [ ] Test: two actors spawned together don't overlap.
- [ ] `F3` shows spawn points.
- [ ] The player spawns at the world default; `test_game.gd`'s spawn tests follow it (they assume
  the anchor today).

### D. The ladder

- [ ] Art: the ladder sprite, distinguishable at a glance. [3]
- [ ] The hole is authored into −1 and the ladder placed on −2, at the same world `(x, y)`.
- [ ] A ladder with no hole directly above it fails to load; so does one outside either level's
  bounds.
- [ ] Test: each of those load failures; and a hole with no ladder loads fine.

## E. Climbing

*Mode: ask before starting.*

- [ ] **Decide:** how an actor uses a ladder: from beside the hole above, and from the ladder's
  tile below; interact or walk into it; keyboard binding (trap 5).
- [ ] **Decide:** which tile beside the hole climbing up arrives on (D-089).
- [ ] Use the ladder from beside the hole and arrive on −2 at the hole's `(x, y)`, `F3`
  agreeing. [3]
- [ ] Climb up and arrive beside the hole, on open floor. [3]
- [ ] Test: climbing down needs a ladder beneath the hole; a bare hole refuses.
- [ ] Climb back up. The corridor dug on −1 before going down is still there; up the ramp, the
  Surface's dig is too. [4]
- [ ] Using a ladder where there isn't one, or from the wrong side, does something deliberate.
  [6]
- [ ] Test: a ramp or climb is refused when the landing has been closed since load (re-checked at
  request time).
- [ ] Test: a dig in progress resets on a depth change; decide what a held dig button does on
  arrival.
- [ ] **Decide, by looking:** whether climbing is instant, and if not, how long it takes. Same
  question for the ramp.
- [ ] Delete the section B debug key.

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
