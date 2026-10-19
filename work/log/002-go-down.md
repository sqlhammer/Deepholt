# 002 — Go down

**Draft by Claude, 2026-10-18. Derik corrects.** The correction pass is the point: change
anything that isn't how it felt from your side.

> Three hand-made levels: the Surface, a ramp down to −1, a ladder down to −2, and −2 visibly
> wider than −1. You descend and the world changes around you while your `(x, y)` does not.

**Result:** all eight by-hand outcomes walked through in one sitting (Derik). The suite passes
with no skipped files; coverage 98.9% (1119 of 1132 probed lines). The slice grew from "two
levels and a ladder" to three levels, a level generator, and the first placed objects.

---

## What got decided

Twenty-six decisions, D-083 to D-108. Grouped by the questions the slice ended up asking:

**Which levels, and how they're built.** The actor still starts on the Surface; a ramp leads to
−1 and a ladder to −2 ([D-083](../../docs/design-decisions.md)). `game.gd` no longer knows which
prefab goes where: a `LevelGenerator` builds every level from a per-depth `LevelRecipe` (D-084),
which holds the level's `LevelBound` (D-085) in one recipe table (D-086), found by depth (D-088).
Prefabs hold content; recipes hold placement. A prefab's ground, top and ore grids must cover
exactly the same tiles (D-102, superseding half of D-062). Dirt was finished, and the Surface
start is dirt (D-087).

**What "current depth" means.** There isn't one in the simulation. An actor changes its own depth
and announces it as an ordinary tile change (D-093); a presentation `View` follows the local actor
and owns the depth on screen (D-094). Everything that draws follows the `View`.

**What connects levels.** A ramp is a directional pair of ground kinds (D-095, D-096), triggered
by the dominant axis of how far you actually moved (D-097, D-098), with walls on three sides
(D-099). A hole is a ground kind; a ladder is an object on the lower level, under it (D-089). A
ladder is used with interact (D-101), polled on the physics tick (D-106), and from above a hole
with a ladder shows the ladder's top (D-107). A held dig carries across; level changes are instant
for now (D-108).

**What an object is.** Objects get their own gatekeeper, separate from `World` (D-090): an
`Objects` autoload, a per-level `LevelFixtures`, a fourth `objects` grid in prefabs, and a `Ladder`
rule beside `Ramp` (D-100). The names, signals, refusal reasons, conflict table and ids followed
(D-103, D-104).

**Where you spawn.** A spawn point is an object (D-091). The world's default is placed at random,
seeded, within 8 tiles of the start placement, never on a ramp; `Level.anchor` is gone (D-092,
D-105). A second player spreads out ring by ring.

---

## What surprised

**"No stubs" wasn't a rule anyone made.** It came from one risk row about the worker layer in
pre-alpha-scope §8. Claude generalized it into CLAUDE.md, then cited it as if it were §4, and it
kept narrowing decisions you wanted to see in context. Removed; the standing instruction is now
"design the broader system, then build a small slice".

**Designing the whole first made the narrow decisions easy.** "Where is a depth's prefab named"
turned into a sketch of RimWorld-style generation, and the recipe, the table and the spawn all
fell out of it in a few minutes each. Fixtures went the same way: eleven names and rules in one
sitting, then the build.

**A lookup change made every tile read 8× slower, silently.** D-088 changed the recipe lookup
from an index to a search. `LevelTiles` checked bounds by asking `World` (allocating a `WorldPos`
on every read), so a depth change went from 92 ms to 750 ms at the Surface. Only measuring found
it. The fix also exposed a latent bug: `LevelTiles` ignored its own bounds, and one test had been
reading outside its radius-1 level all along.

**`for x in array` gives elements, not indices.** The `get_bounds` rewrite indexed the array with
a `LevelBound`; every tile read errored, and the suite crawled for over ten minutes rather than
failing.

**Several rules only showed up by hand.** The ramp's sides were "plain floor" until walking
across one felt wrong (D-099). The ladder was invisible from above until standing at the hole
(D-107). The feet box straddling two tiles made "keep your exact spot" refuse the climb up the
ramp, which the tests caught before anyone climbed it.

**Page Up / Page Down never reached the game on your laptop.** The debug key worked in tests and
did nothing by hand; rebinding to `-` / `=` fixed it.

**The hole check had three bugs stacked.** It compared a grid character to a kind name (so it
never ran); fixed alone, it would have crashed on unmentioned tiles; fixed again, it would have
rejected every hole (`ORE.NULL` vs `ORE.NONE`). The tests found them in order.

**Coverage reported 7%.** `match top_kind: # allowlist` has a trailing comment, so the coverage
tool didn't recognize the `match`, put probes between its arms, and broke the parse of `TileKind`
in its copy. The tool was fixed, not the code.

**The tooling around Claude cost time.** Heredocs ate backslashes and broke on quotes; the Write
tool drops the tab on blank lines, so scripted edits stopped matching; new `class_name`s need
Godot's class cache refreshed; the editor can write its copy of `project.godot` back over an
outside edit.

**Agent mode on a branch, reviewed as a PR, worked.** Sections D and E were built remotely (you
had no Godot) in 18 small commits, merged as PR #1, then checked by hand.

---

## What to do differently

1. **Measure after changing anything on the tile read path.** Every tile read runs through
   `LevelTiles`; a change that looks like a lookup detail can multiply a depth change's cost. The
   hitch numbers in the checklist are the baseline.
2. **Run the game by hand per section, not per slice.** The ramp walls and the ladder top were
   feel decisions that tests couldn't make. Earlier hand checks would have found them before the
   code around them settled.
3. **When a rule changes, rewrite the tests that encoded the old one, by name.** D-102 broke
   exactly the three tests that stated D-062; renaming them to say the new rule kept the suite a
   record of decisions rather than a pile of assertions.
4. **(Claude) Cite constraints from their source, and don't generalize them into instructions.**
   The "no stubs" rule did damage because it read as settled.
5. **(Claude) Script edits from files, not heredocs, and match whitespace-tolerantly.** The edit
   helper in the scratchpad does this now.
6. **Keep "decided" and "decided by looking" apart in the checklist.** It made it obvious which
   items could be done remotely and which had to wait for the game.

---

## Open, carried forward

- **Level-change transitions** (D-108): wanted, deferred. NEXT.md has where they go.
- **Up or down, when on a ladder and facing a hole with another ladder under it** (D-106): not
  decided; can't happen until shafts can sit side by side. Code order says up.
- **Moving a fixture** (a bed, later): discussed, not recorded. `Fixture.tile` should become
  read-only; a move goes through the store and the gatekeeper; how a move is announced (as a
  removal and a placement, or as its own event) is the open choice.
- **`LevelFixtures.add` accepts the same fixture twice.** A one-line guard was offered.
- **`F3`'s tile window prints a hole as `.`**; the readout names it.
- **The temporary hole at (0, 2) in `surface_start`** is still there, on purpose.
