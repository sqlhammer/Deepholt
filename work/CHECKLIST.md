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
- [ ] Test: each recipe row's depth matches its position in the table (D-086).
- [ ] Recipes replace `level_bounds.tres` as the per-depth list; `World` and `Level` read bounds
  through them.
- [ ] Ramp and ladder kinds get explicit, never-reused ids (trap 8).
- [ ] The generator draws randomness only from a `RandomNumberGenerator` seeded per level (trap 8).
- [ ] `LevelGenerator` builds every level from its recipe's fixed placements; `game.gd` calls it.
- [ ] Test: a recipe naming a missing prefab id fails loudly.
- [x] **Decide (optional):** finish dirt — grid character, art cell, `F3` character — or leave it.
  Finished, and the Surface start prefab is dirt (Agent mode, [D-087](../docs/design-decisions.md)).
- [ ] Author −1's prefab: its hand-made layout, open floor where the ramp will land, and an open
  corridor from where the ladder will be out to the edge in one direction (trap 7).
- [ ] Author −2's prefab: its own layout, the same corridor direction, reaching further to its
  own edge.
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

## D. The ladder in the data

*Mode: ask before starting.*

- [ ] **Decide:** what a ladder is in the data — the same kind of thing as the ramp, or a
  different one (an object) — and how its two ends are linked.
- [ ] The ladder and its hole are authored into the −1 and −2 prefabs, at the same world `(x, y)`.
- [ ] Art: the ladder (and the hole, if it's its own thing) is distinguishable at a glance. [3]
- [ ] `F3` names it.
- [ ] The same load checks as the ramp: ends line up, inside both levels, landing open. Shared
  with the ramp's if the ladder is the same kind of thing.
- [ ] Test: each of those load failures.

## E. Climbing

*Mode: ask before starting.*

- [ ] **Decide:** how an actor uses a ladder — walk on, or face and interact; same tile or
  adjacent; keyboard binding (trap 5).
- [ ] Use the ladder and arrive on −2, same `(x, y)`, `F3` agreeing. [3]
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
