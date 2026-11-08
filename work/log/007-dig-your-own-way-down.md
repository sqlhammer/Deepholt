# 007 — Dig your own way down

*Written by Claude, 2026-11-08.*

> Stand beside the floor, breach it into a hole, switch to build mode, and set a ladder in it.
> Climb down to a level nobody built a way into. Your flint can break the Surface's floor and
> −1's, but not −2's.

**Result:** built in Agent mode on the `slice-007` branch, in five commits: the plan, the breach,
the bindings, build mode with placing, and this log. The suite passes: 846 tests in 43
scripts, no skipped files, no leak warning. Coverage is 97.5% (006 closed at 97.4%). **The
by-hand outcomes haven't been walked.** Claude didn't launch the game, because a launch reads,
writes and prunes the real save slot. This log was written before anyone breached a floor on
screen.

---

## What got decided

Six decisions, D-150 to D-155, each put to Derik:

- **Digging rules live in a static `Digging` class that takes the profile** (D-150). This
  settled Derik's question from 006: `hardness_of` and `dig_hardness` left the profile.
- **A floor's hardness is its level's,** with the appendix's breach formula and its numbers in
  the profile (D-151).
- **A breach opens a hole and clears the landing below,** whole or not at all. Only plain floor
  with both ends clear can be breached, and nobody falls (D-152).
- **Breaching has its own input, held** (D-153).
- **Build mode follows ui-ux, and a ladder is aimed at a hole you can see** (D-154).
- **Build mode is `B`, because `E` is already interact, and breach holds pad X** until tools can
  be swapped, which ui-ux reserves X for (D-155). Both collisions surfaced while adding the
  bindings, not in planning.

**Choices made while building, not put to Derik.** He may want to look at these:

- **The capability asks the world before working.** `World.breach_problem` is a read-only check.
  A refused breach is reported once, at the first press, not after five seconds and not every
  tick.
- **`RefusalNotice`** is the first thing that shows a refusal to the player: a line at the bottom
  of the screen for 2.5 s, for the followed actor's breach and placement refusals only. Its
  wording is Claude's.
- **`BuildCursor`** is one presentation node for the local player, in the game viewport. The
  mouse points at a tile; the right stick steps one tile, then every 0.15 s while held. Both are
  clamped to the same disc. Its preview calls `FixturePlacement.problem` (the gatekeeper's own
  rule) plus "Sensed or Lit".
- **Validity is drawn as a solid frame and a check, or a dashed frame and a cross,** green or
  red.
- **A world swap turns build mode off,** since the cursor's actor goes with the old world.
- **Not built from ui-ux §7:** dimming the world and showing a grid in build mode, the pad's B
  to leave it, and the cursor's audible tick. The game has no sound yet.
- **The breach numbers are 8 and 1.2** (the appendix's), and the cursor radius is 5. All three
  are profile numbers.

---

## What surprised

**Both new bindings collided with something.** `E` was interact in this game, though the design
doc had interact on the right mouse button. Pad X was reserved for a tool swap that doesn't
exist yet. The plan named the keys from the design doc without checking `project.godot`. Both
became D-155, but the question should have come up in planning.

**The breach rule fit in the gatekeeper's existing shape.** It's a request, a read-only problem
check, an apply-whole and one outcome, the same shape as the dig. The two-level change was safe
because every check runs before anything is written.

**Rounding a clamped diagonal can leave the disc.** A cursor clamped to radius 5 at 45° rounded
to (4, 4), 5.66 tiles out. A test asserting "a disc, not a square" caught it; truncation is now
the fallback.

**(Claude) The Godot editor was open when `project.godot` needed editing.** It was checked
before writing, and Derik closed the editor. The tooling memory's warning paid for itself.

---

## What to do differently

1. **Check the real bindings, not the design doc's, when a plan names keys.** One grep of
   `project.godot` in planning would have found both collisions.
2. **Grep for dead code before the coverage run.** `target()` and `reason()` on the cursor were
   written ahead of a use that never came. Coverage found them; reading the diff should have.
3. **A cursor or any input clamp wants a diagonal in its test.** Straight lines hide rounding.

---

## Open, carried forward

- **By hand, for Derik:** breach −1's floor (about 5 s) and try −2's (refused, with why);
  toggle build mode with `B` / `Y`, move the cursor with both inputs, read it in the dark; place
  a ladder in your hole, climb down and back, save, relaunch; and the Surface's old hole is gone
  on a `--new-game`.
- **ui-ux §7's build-mode dimming and grid, pad B to leave, and the cursor's tick** aren't
  built.
- **Pad X will be contested** when tools can be swapped (D-155).
- **Nothing removes a placed ladder,** and placing costs nothing. Both wait for items and the
  hammer.
- **Lit tiles still aren't remembered,** from 006.
